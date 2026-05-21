public without sharing class FEC_CaseAssignmentAutoDistributeService {
    private static final String METHOD_CONTINUOUS = 'Continuous';
    private static final String METHOD_TIME_BASED = 'Time-Based';

    /** Giới hạn vòng lặp Bung Public Group / sub-group trong queue. */
    private static final Integer MAX_PUBLIC_GROUP_EXPAND_ITERATIONS = 25;

    /** Giới hạn bậc Bung UserRole con (khớp UX queue: role + các role phía dưới trong cây). */
    private static final Integer MAX_USER_ROLE_DESCENDANTS_DEPTH = 80;

    /**
     * Số Case/update mỗi lần DML batch; nếu vượt sẽ chạy Database.Batchable (FEC_CaseAssignmentApplyOwnerBatch)
     * để mỗi transaction có governor SOQL/trigger riêng — tránh Too many SOQL khi bulk update Case.
     */
    public static final Integer ASSIGNMENT_CASE_DML_CHUNK_SIZE = 8;

    /**
     * Trong một transaction Apex, map ParentRoleId -> danh sách UserRole.Id con.
     * Lazy-load một lần để tránh vòng lặp SOQL/trừ vào chỉ được 101 query (đặt biệt executeNow nhiều assignment).
     */
    private static Map<Id, List<Id>> userRoleChildrenByParentMemo;

    /**
     * Theo transaction: kết quả bung queue — tránh repeat SOQL khi executeNow xử lý nhiều assignment cùng tập queue.
     */
    private static Map<String, Set<Id>> queueRecipientUserIdsMemo;

    public static void executeNow() {
        DateTime nowTime = System.now();

        List<FEC_Case_Assignment__c> activeAssignments = [
            SELECT
                Id,
                FEC_Assignment_Method__c,
                FEC_Scheduled_Time__c,
                FEC_Time_Slots__c,
                FEC_Business_Hours__c,
                FEC_Business_Hours__r.TimeZoneSidKey
            FROM FEC_Case_Assignment__c
            WHERE FEC_Status__c = :FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE
        ];
        if (activeAssignments.isEmpty()) {
            return;
        }

        Set<Id> assignmentIdsActive = new Set<Id>();
        for (FEC_Case_Assignment__c row : activeAssignments) {
            assignmentIdsActive.add(row.Id);
        }
        Map<Id, Datetime> lastLogUtcByAssignmentId =
            fetchLatestAssignmentLogCreatedDateByAssignments(assignmentIdsActive);

        List<Id> dueAssignmentIds = new List<Id>();
        for (FEC_Case_Assignment__c assignmentRecord : activeAssignments) {
            Datetime latestLogUtc = lastLogUtcByAssignmentId.get(assignmentRecord.Id);
            if (!isDueToRun(assignmentRecord, nowTime, latestLogUtc)) {
                continue;
            }
            if (hasLogInCurrentMinute(assignmentRecord, nowTime)) {
                continue;
            }
            dueAssignmentIds.add(assignmentRecord.Id);
        }

        /*
         * Một synchronous transaction chỉ được enqueue tối đa ~50 Queueable — không được gọi
         * enqueueJob trong loop theo số assignment. Một queue job duy nhất nhận full list và
         * chain từng assignment (FEC_CaseAssignmentAutoDistQueueJob).
         */
        if (!dueAssignmentIds.isEmpty()) {
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(dueAssignmentIds));
        }
    }

    /**
     * Phân bổ ngay cho một Case Assignment (không chờ scheduled job): bỏ qua cửa Continuous / Time-Based
     * và bỏ qua giới hạn “một lần trong cùng phút”. Chỉ chạy khi FEC_Status__c = Active.
     * Trả về số Case đã gán (logic giữ nguyên executeSingleAssignment).
     */
    public static Integer executeImmediatelyForAssignmentId(Id assignmentId) {
        if (assignmentId == null) {
            return 0;
        }
        List<FEC_Case_Assignment__c> assignmentRows = [
            SELECT
                Id,
                Name,
                FEC_Assignment_Method__c,
                FEC_Scheduled_Time__c,
                FEC_Time_Slots__c,
                FEC_Select_Queues__c,
                FEC_Role__c,
                FEC_Scale__c,
                FEC_Status__c,
                FEC_Business_Hours__c,
                FEC_Business_Hours__r.TimeZoneSidKey
            FROM FEC_Case_Assignment__c
            WHERE Id = :assignmentId
            LIMIT 1
        ];
        if (assignmentRows.isEmpty()) {
            return 0;
        }
        FEC_Case_Assignment__c assignmentRecord = assignmentRows[0];
        if (assignmentRecord.FEC_Status__c != FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE) {
            return 0;
        }
        Integer logCount = [
            SELECT COUNT()
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentId
        ];
        Integer runNumber = logCount + 1;
        Integer assignedCount = executeSingleAssignment(assignmentRecord, runNumber);
        if (assignedCount == 0) {
            insertAssignmentRunLog(
                assignmentRecord.Id,
                assignmentRecord.Name,
                runNumber,
                0,
                new Map<Id, Integer>()
            );
        }
        return assignedCount;
    }

    /**
     * Chẩn đoán từng bước vì executeImmediately/job trả 0 không có log chi tiết.
     * Sandbox / Execute Anonymous:
     *   for (String s : FEC_CaseAssignmentAutoDistributeService.diagnoseAssignment(Id.valueOf('a1YAf000...'))) System.debug(s);
     */
    public static List<String> diagnoseAssignment(Id assignmentId) {
        List<String> lines = new List<String>();
        if (assignmentId == null) {
            lines.add('STOP: assignmentId null');
            return lines;
        }
        List<FEC_Case_Assignment__c> assignmentRows = [
            SELECT
                Id,
                Name,
                FEC_Assignment_Method__c,
                FEC_Select_Queues__c,
                FEC_Role__c,
                FEC_Scale__c,
                FEC_Status__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :assignmentId
            LIMIT 1
        ];
        if (assignmentRows.isEmpty()) {
            lines.add('STOP: không tìm thấy FEC_Case_Assignment__c');
            return lines;
        }
        FEC_Case_Assignment__c assignmentRecord = assignmentRows[0];
        lines.add('Header.Name=' + assignmentRecord.Name + ' Status=' + assignmentRecord.FEC_Status__c +
            ' Method=' + assignmentRecord.FEC_Assignment_Method__c);

        if (assignmentRecord.FEC_Status__c != FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE) {
            lines.add('STOP: chỉ phân khi FEC_Status__c = Active (executeImmediately cũng return 0).');
            return lines;
        }

        Set<String> queueNames = splitToSet(assignmentRecord.FEC_Select_Queues__c);
        lines.add('[1] tên queue (sau split): ' + queueNames.size() + ' -> ' + String.join(new List<String>(queueNames), ', '));
        if (queueNames.isEmpty()) {
            lines.add('STOP: FEC_Select_Queues__c trống');
            return lines;
        }

        Map<Id, Group> queueById = new Map<Id, Group>([
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue' AND Name IN :queueNames
        ]);
        lines.add('[2] Group Type=Queue khớp tên: ' + queueById.size());
        if (queueById.isEmpty()) {
            lines.add('STOP: không có queue với đúng Name (kiểm tra khoảng trắng / chính tả).');
            return lines;
        }

        List<FEC_Case_Assignment_NOC__c> nocList = [
            SELECT
                FEC_Product_Type__c,
                FEC_Product_Type__r.Name,
                FEC_Category__c,
                FEC_Category__r.Name,
                FEC_Sub_Category__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Code__c,
                FEC_Sub_Code__r.Name
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentRecord.Id
        ];
        lines.add('[3] NOC rows: ' + nocList.size());
        if (nocList.isEmpty()) {
            lines.add('STOP: không có NOC — executeSingleAssignment return 0');
            return lines;
        }

        Set<String> nocExactKeys = new Set<String>();
        Set<String> nocWithoutSubCodeKeys = new Set<String>();
        for (FEC_Case_Assignment_NOC__c noc : nocList) {
            String baseKey = buildKey(
                noc.FEC_Product_Type__c,
                noc.FEC_Product_Type__r == null ? null : noc.FEC_Product_Type__r.Name,
                noc.FEC_Category__c,
                noc.FEC_Category__r == null ? null : noc.FEC_Category__r.Name,
                noc.FEC_Sub_Category__c,
                noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.Name
            );
            if (noc.FEC_Sub_Code__c == null) {
                nocWithoutSubCodeKeys.add(baseKey);
            } else {
                nocExactKeys.add(baseKey + '|' + normalizeKeyPart(
                    noc.FEC_Sub_Code__c,
                    noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.Name
                ));
            }
        }

        List<Case> candidateCases = [
            SELECT
                Id,
                FEC_Product_Type__c,
                FEC_Product_Type__r.Name,
                FEC_Category__c,
                FEC_Category__r.Name,
                FEC_SubCategory__c,
                FEC_SubCategory__r.Name,
                FEC_SubCode__c,
                FEC_SubCode__r.Name
            FROM Case
            WHERE OwnerId IN :queueById.keySet() AND IsClosed = FALSE
        ];
        lines.add('[4] Case mở trong queue: ' + candidateCases.size());

        Integer targetCaseCount = 0;
        for (Case c : candidateCases) {
            String baseKey = buildKey(
                c.FEC_Product_Type__c,
                c.FEC_Product_Type__r == null ? null : c.FEC_Product_Type__r.Name,
                c.FEC_Category__c,
                c.FEC_Category__r == null ? null : c.FEC_Category__r.Name,
                c.FEC_SubCategory__c,
                c.FEC_SubCategory__r == null ? null : c.FEC_SubCategory__r.Name
            );
            String exactKey = baseKey + '|' + normalizeKeyPart(
                c.FEC_SubCode__c,
                c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.Name
            );
            if (nocExactKeys.contains(exactKey) || nocWithoutSubCodeKeys.contains(baseKey)) {
                targetCaseCount++;
            }
        }
        lines.add('[5] Case khớp NOC (cùng buildKey với execute): ' + targetCaseCount);
        if (targetCaseCount == 0) {
            lines.add('STOP: không Case nào khớp NOC — đối chiếu lookup/diễn giải Tier trên Case vs NOC.');
            return lines;
        }

        Map<String, Integer> roleScaleMap = parseRoleScale(
            assignmentRecord.FEC_Role__c,
            assignmentRecord.FEC_Scale__c
        );
        lines.add('[6] roleScaleMap keys normalized (trim + collapse space + lowercase), count=' +
            roleScaleMap.size() + ': ' +
            String.join(new List<String>(roleScaleMap.keySet()), ' | '));
        if (roleScaleMap.isEmpty()) {
            lines.add('STOP: FEC_Role__c parse không ra role');
            return lines;
        }

        Set<Id> queueUserIds = resolveQueueMembersToUserIds(queueById.keySet());
        lines.add('[7] user Id từ queue (bung): ' + queueUserIds.size());
        if (queueUserIds.isEmpty()) {
            lines.add('STOP: queue không ra user — thêm User / Role / Public Group.');
            return lines;
        }

        List<User> candidateRoleUsers = [
            SELECT Id, Name, Email, UserRole.Name
            FROM User
            WHERE Id IN :queueUserIds AND IsActive = TRUE AND UserRoleId != NULL
            ORDER BY Name
        ];
        List<User> eligibleUsers = filterUsersMatchingRoleScale(candidateRoleUsers, roleScaleMap);
        lines.add('[8] eligible (UserRole.Name sau normalize khớp key [6]): ' + eligibleUsers.size());
        if (eligibleUsers.isEmpty()) {
            Set<String> roleNamesSeen = new Set<String>();
            for (User uSample : candidateRoleUsers) {
                roleNamesSeen.add(
                    uSample.UserRole == null ? '(null)' : uSample.UserRole.Name
                );
            }
            lines.add('HINT UserRole.Name (user có role trong queue): ' +
                String.join(new List<String>(roleNamesSeen), ' | '));
            lines.add('Không khớp key [6] — chỉnh FEC_Role__c (đúng tên Role, khoảng trắng) hoặc UserRole.');
            return lines;
        }

        Set<Id> onVacationUserIds = getUserIdsWithActiveResourceAbsence(System.now());
        lines.add('[8a] User có nghỉ phép hiệu lực (Absence, RelatedRecordId): ' + onVacationUserIds.size());
        Integer eligibleBeforeVacation = eligibleUsers.size();
        eligibleUsers = removeUsersWhoseIdInSet(eligibleUsers, onVacationUserIds);
        lines.add(
            '[8b] eligible sau loại trừ nghỉ phép: ' + eligibleUsers.size() +
                ' (trước đó ' + eligibleBeforeVacation + ')'
        );
        if (eligibleUsers.isEmpty()) {
            lines.add('STOP: không còn user eligible sau khi loại người đang nghỉ phép.');
            return lines;
        }

        lines.add('OK: đủ Case target + eligible user; nếu execute vẫn 0 → xem validation/DML khi update Case.');
        return lines;
    }

    private static final String DEFAULT_ASSIGNMENT_TIMEZONE_SID = 'Asia/Ho_Chi_Minh';

    private static String assignmentTimezoneSid(FEC_Case_Assignment__c assignmentRecord) {
        if (
            assignmentRecord != null &&
            assignmentRecord.FEC_Business_Hours__r != null &&
            String.isNotBlank(assignmentRecord.FEC_Business_Hours__r.TimeZoneSidKey)
        ) {
            return assignmentRecord.FEC_Business_Hours__r.TimeZoneSidKey;
        }
        return DEFAULT_ASSIGNMENT_TIMEZONE_SID;
    }

    private static String formatAssignmentRunLogName(String assignmentName, Integer runNumber) {
        String baseName = String.isBlank(assignmentName) ? 'Assignment' : assignmentName.trim();
        Integer run = runNumber == null || runNumber < 1 ? 1 : runNumber;
        return baseName + ' - ' + String.valueOf(run).leftPad(5, '0');
    }

    /**
     * Picklist từng gõ nhầm \"Continous\"; bản ghi cũ có thể vẫn giữ giá trị đó.
     */
    private static String normalizedAssignmentMethod(FEC_Case_Assignment__c assignmentRecord) {
        String raw = assignmentRecord == null ? null : assignmentRecord.FEC_Assignment_Method__c;
        if (String.isBlank(raw)) {
            return METHOD_CONTINUOUS;
        }
        String trimmed = raw.trim();
        if (trimmed.equalsIgnoreCase('Continous')) {
            return METHOD_CONTINUOUS;
        }
        return trimmed;
    }

    /**
     * Một Aggregate query cho toàn Active assignment — tránh N lần subquery trong vòng executeNow.
     */
    private static Map<Id, Datetime> fetchLatestAssignmentLogCreatedDateByAssignments(
        Set<Id> assignmentIds
    ) {
        Map<Id, Datetime> out = new Map<Id, Datetime>();
        if (assignmentIds == null || assignmentIds.isEmpty()) {
            return out;
        }
        for (AggregateResult ar : [
            SELECT FEC_Case_Assignment_Name__c aidKey, MAX(CreatedDate) lastCreatedUtc
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c IN :assignmentIds
            GROUP BY FEC_Case_Assignment_Name__c
        ]) {
            Id aid = (Id) ar.get('aidKey');
            Datetime lc = (Datetime) ar.get('lastCreatedUtc');
            if (aid != null && lc != null) {
                out.put(aid, lc);
            }
        }
        return out;
    }

    /**
     * Continuous:FEC_Scheduled_Time__c = khoảng thời gian (phút) tối thiểu sau lần ghi FEC_Case_Assignment_Logs__c gần nhất mới được chạy tiếp
     * (schedule ngoài chỉ polling ~vài phút — không căn modulus theo đồng hồ cả ngày).
     * Execute Immediately không gọi hàm này (chạy ngay được).
     */
    private static Boolean isDueToRun(
        FEC_Case_Assignment__c assignmentRecord,
        DateTime nowTime,
        Datetime latestSuccessfulLogUtc
    ) {
        String method = normalizedAssignmentMethod(assignmentRecord);
        String tz = assignmentTimezoneSid(assignmentRecord);

        if (method == METHOD_CONTINUOUS) {
            Integer scheduledMinutes =
                assignmentRecord.FEC_Scheduled_Time__c == null
                    ? 30
                    : assignmentRecord.FEC_Scheduled_Time__c.intValue();
            if (scheduledMinutes <= 0) {
                scheduledMinutes = 30;
            }

            /* Lần đầu hoặc chưa có log thành công trước đó — không chặn theo cooldown. */
            if (latestSuccessfulLogUtc == null) {
                return true;
            }
            return nowTime >= latestSuccessfulLogUtc.addMinutes(scheduledMinutes);
        }

        if (method == METHOD_TIME_BASED) {
            if (String.isBlank(assignmentRecord.FEC_Time_Slots__c)) {
                return false;
            }
            String currentHm = nowTime.format('HH:mm', tz);
            for (String slot : assignmentRecord.FEC_Time_Slots__c.split(';')) {
                if (slot != null && slot.trim() == currentHm) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Tránh DateTime.newInstance(y,m,d,h,mi,0) gây canh phút theo GMT sai lệch timezone:
     * đối chiếu yyyy-MM-dd HH:mm theo múi của user chạy Apex (Scheduled Job = user submit schedule).
     */
    private static Boolean hasLogInCurrentMinute(
        FEC_Case_Assignment__c assignmentRecord,
        DateTime nowTime
    ) {
        if (assignmentRecord == null || assignmentRecord.Id == null || nowTime == null) {
            return false;
        }
        String tz = assignmentTimezoneSid(assignmentRecord);
        Id assignmentId = assignmentRecord.Id;
        String minuteKey = nowTime.format('yyyy-MM-dd HH:mm', tz);
        DateTime probeStart = nowTime.addMinutes(-3);
        List<FEC_Case_Assignment_Logs__c> recentLogs = [
            SELECT CreatedDate
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentId AND CreatedDate >= :probeStart
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        for (FEC_Case_Assignment_Logs__c logRow : recentLogs) {
            if (logRow.CreatedDate.format('yyyy-MM-dd HH:mm', tz) == minuteKey) {
                return true;
            }
        }
        return false;
    }

    /**
     * User có bản ghi nghỉ phép đang hiệu lực: FEC_Start_Date__c < atTime < FEC_End_Date__c,
     * map sang User qua FEC_Service_Resource__r.RelatedRecordId (Service Resource gắn agent).
     */
    private static Set<Id> getUserIdsWithActiveResourceAbsence(DateTime atTime) {
        Set<Id> userIds = new Set<Id>();
        if (atTime == null) {
            atTime = System.now();
        }
        try {
            for (FEC_Service_Resource_Absence__c absenceRow : [
                SELECT FEC_Service_Resource__r.RelatedRecordId
                FROM FEC_Service_Resource_Absence__c
                WHERE
                    FEC_Service_Resource__c != NULL
                    AND FEC_Start_Date__c != NULL
                    AND FEC_End_Date__c != NULL
                    AND FEC_Start_Date__c < :atTime
                    AND FEC_End_Date__c > :atTime
            ]) {
                if (
                    absenceRow.FEC_Service_Resource__r != null &&
                    absenceRow.FEC_Service_Resource__r.RelatedRecordId != null
                ) {
                    userIds.add(absenceRow.FEC_Service_Resource__r.RelatedRecordId);
                }
            }
        } catch (Exception ex) {
            // User chạy Scheduled/Queueable thiếu quyền FS hoặc metadata chưa SB: không chặn phân bổ.
        }
        return userIds;
    }

    private static List<User> removeUsersWhoseIdInSet(List<User> users, Set<Id> excludedUserIds) {
        if (users == null || users.isEmpty()) {
            return users == null ? new List<User>() : users;
        }
        if (excludedUserIds == null || excludedUserIds.isEmpty()) {
            return users;
        }
        List<User> kept = new List<User>();
        for (User u : users) {
            if (!excludedUserIds.contains(u.Id)) {
                kept.add(u);
            }
        }
        return kept;
    }

    private static Integer executeSingleAssignment(FEC_Case_Assignment__c assignmentRecord, Integer runNumber) {
        Set<String> queueNames = splitToSet(assignmentRecord.FEC_Select_Queues__c);
        if (queueNames.isEmpty()) {
            return 0;
        }

        Map<Id, Group> queueById = new Map<Id, Group>([
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Queue' AND Name IN :queueNames
        ]);
        if (queueById.isEmpty()) {
            return 0;
        }

        List<FEC_Case_Assignment_NOC__c> nocList = [
            SELECT
                FEC_Product_Type__c,
                FEC_Product_Type__r.Name,
                FEC_Category__c,
                FEC_Category__r.Name,
                FEC_Sub_Category__c,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Code__c,
                FEC_Sub_Code__r.Name
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentRecord.Id
        ];
        if (nocList.isEmpty()) {
            return 0;
        }

        Set<String> nocExactKeys = new Set<String>();
        Set<String> nocWithoutSubCodeKeys = new Set<String>();
        for (FEC_Case_Assignment_NOC__c noc : nocList) {
            String baseKey = buildKey(
                noc.FEC_Product_Type__c,
                noc.FEC_Product_Type__r == null ? null : noc.FEC_Product_Type__r.Name,
                noc.FEC_Category__c,
                noc.FEC_Category__r == null ? null : noc.FEC_Category__r.Name,
                noc.FEC_Sub_Category__c,
                noc.FEC_Sub_Category__r == null ? null : noc.FEC_Sub_Category__r.Name
            );
            if (noc.FEC_Sub_Code__c == null) {
                nocWithoutSubCodeKeys.add(baseKey);
            } else {
                nocExactKeys.add(baseKey + '|' + normalizeKeyPart(
                    noc.FEC_Sub_Code__c,
                    noc.FEC_Sub_Code__r == null ? null : noc.FEC_Sub_Code__r.Name
                ));
            }
        }

        List<Case> candidateCases = [
            SELECT
                Id,
                OwnerId,
                CreatedDate,
                FEC_Product_Type__c,
                FEC_Product_Type__r.Name,
                FEC_Category__c,
                FEC_Category__r.Name,
                FEC_SubCategory__c,
                FEC_SubCategory__r.Name,
                FEC_SubCode__c,
                FEC_SubCode__r.Name
            FROM Case
            WHERE OwnerId IN :queueById.keySet() AND IsClosed = false
            ORDER BY CreatedDate ASC
        ];

        List<Case> targetCases = new List<Case>();
        for (Case c : candidateCases) {
            String baseKey = buildKey(
                c.FEC_Product_Type__c,
                c.FEC_Product_Type__r == null ? null : c.FEC_Product_Type__r.Name,
                c.FEC_Category__c,
                c.FEC_Category__r == null ? null : c.FEC_Category__r.Name,
                c.FEC_SubCategory__c,
                c.FEC_SubCategory__r == null ? null : c.FEC_SubCategory__r.Name
            );
            String exactKey = baseKey + '|' + normalizeKeyPart(
                c.FEC_SubCode__c,
                c.FEC_SubCode__r == null ? null : c.FEC_SubCode__r.Name
            );
            if (nocExactKeys.contains(exactKey) || nocWithoutSubCodeKeys.contains(baseKey)) {
                targetCases.add(c);
            }
        }
        if (targetCases.isEmpty()) {
            return 0;
        }

        Map<String, Integer> roleScaleMap = parseRoleScale(assignmentRecord.FEC_Role__c, assignmentRecord.FEC_Scale__c);
        if (roleScaleMap.isEmpty()) {
            return 0;
        }

        Set<Id> queueUserIds = resolveQueueMembersToUserIds(queueById.keySet());
        if (queueUserIds.isEmpty()) {
            return 0;
        }

        List<User> candidateRoleUsers = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id IN :queueUserIds AND IsActive = true AND UserRoleId != null
            ORDER BY Name
        ];
        List<User> eligibleUsers = filterUsersMatchingRoleScale(candidateRoleUsers, roleScaleMap);
        if (eligibleUsers.isEmpty()) {
            return 0;
        }

        eligibleUsers = removeUsersWhoseIdInSet(
            eligibleUsers,
            getUserIdsWithActiveResourceAbsence(System.now())
        );
        if (eligibleUsers.isEmpty()) {
            return 0;
        }

        Map<Id, Integer> historicalCountByUser = getHistoricalAssignedCountByUser(
            assignmentRecord.Id,
            eligibleUsers
        );
        Map<Id, Integer> numberByUser = new Map<Id, Integer>();
        List<Id> usersInAssignmentOrder = new List<Id>();
        String allocationMethod = normalizedAssignmentMethod(assignmentRecord);
        if (allocationMethod == METHOD_CONTINUOUS) {
            distributeWeightedLeastLoaded(
                targetCases,
                eligibleUsers,
                roleScaleMap,
                historicalCountByUser,
                numberByUser,
                usersInAssignmentOrder
            );
        } else {
            distributeWeightedSequentialFromHistory(
                targetCases,
                eligibleUsers,
                roleScaleMap,
                historicalCountByUser,
                numberByUser,
                usersInAssignmentOrder
            );
        }
        if (numberByUser.isEmpty()) {
            return 0;
        }

        Integer totalTargets = targetCases.size();
        if (totalTargets <= ASSIGNMENT_CASE_DML_CHUNK_SIZE) {
            registerSkipOwnerChangeRoutingHistoryForCases(targetCases);
            update targetCases;
            insertAssignmentRunLog(
                assignmentRecord.Id,
                assignmentRecord.Name,
                runNumber,
                totalTargets,
                numberByUser,
                usersInAssignmentOrder
            );
            return totalTargets;
        }

        List<Id> caseIdsOrdered = new List<Id>();
        List<Id> newOwnerIdsOrdered = new List<Id>();
        for (Case tc : targetCases) {
            caseIdsOrdered.add(tc.Id);
            newOwnerIdsOrdered.add(tc.OwnerId);
        }

        List<Id> summaryUserIds = new List<Id>();
        List<Integer> summaryCounts = new List<Integer>();
        appendSummaryFromAssignmentOrder(usersInAssignmentOrder, numberByUser, summaryUserIds, summaryCounts);

        Database.executeBatch(
            new FEC_CaseAssignmentApplyOwnerBatch(
                assignmentRecord.Id,
                assignmentRecord.Name,
                runNumber,
                caseIdsOrdered,
                newOwnerIdsOrdered,
                summaryUserIds,
                summaryCounts
            ),
            ASSIGNMENT_CASE_DML_CHUNK_SIZE
        );
        return totalTargets;
    }

    /** Gọi sau khi mọi Case đã được gán Owner — dùng chung path sync và path Batch (apply owner). */
    public static void insertAssignmentRunLog(
        Id assignmentId,
        String assignmentName,
        Integer runNumber,
        Integer totalCasesAssigned,
        Map<Id, Integer> countsByAssignedUserId
    ) {
        insertAssignmentRunLog(
            assignmentId,
            assignmentName,
            runNumber,
            totalCasesAssigned,
            countsByAssignedUserId,
            null
        );
    }

    public static void insertAssignmentRunLog(
        Id assignmentId,
        String assignmentName,
        Integer runNumber,
        Integer totalCasesAssigned,
        Map<Id, Integer> countsByAssignedUserId,
        List<Id> userIdsInAssignmentOrder
    ) {
        if (assignmentId == null || totalCasesAssigned == null || totalCasesAssigned < 0) {
            return;
        }
        FEC_Case_Assignment_Logs__c logRecord = new FEC_Case_Assignment_Logs__c(
            Name = formatAssignmentRunLogName(assignmentName, runNumber),
            FEC_Case_Assignment_Name__c = assignmentId,
            FEC_Number_of_Case__c = totalCasesAssigned
        );
        insert logRecord;

        if (countsByAssignedUserId == null || countsByAssignedUserId.isEmpty()) {
            return;
        }

        Map<Id, User> userRows = new Map<Id, User>(
            [SELECT Id, Email FROM User WHERE Id IN :countsByAssignedUserId.keySet()]
        );

        List<Id> orderedUserIds = buildOrderedUserIdsForLogDetails(
            userIdsInAssignmentOrder,
            countsByAssignedUserId
        );

        List<FEC_Case_Assignment_Log_Detail__c> detailList = new List<FEC_Case_Assignment_Log_Detail__c>();
        for (Id userId : orderedUserIds) {
            User u = userRows.get(userId);
            String emailValue = u != null ? u.Email : null;
            detailList.add(
                new FEC_Case_Assignment_Log_Detail__c(
                    Name = String.isNotBlank(emailValue) ? emailValue : String.valueOf(userId),
                    FEC_Case_Assignment_log_Name__c = logRecord.Id,
                    FEC_Name_User__c = emailValue,
                    FEC_Number_of_Case__c = countsByAssignedUserId.get(userId)
                )
            );
        }
        if (!detailList.isEmpty()) {
            insert detailList;
        }
    }

    /**
     * Bung thành viên queue sang tập Id User có thể nhận phân bổ:
     * - User add trực tiếp
     * - UserRole → user Active có UserRoleId thuộc role đó + các role con (subordinate subtree)
     * - Group (Public Group / subgroup) → BFS GroupMember (tránh nhúng lại đúng Id queue).
     * - Group Salesforce kiểu Role / Role và cấp dưới: GroupMember thường rỗng; lấy UserRole từ Group.RelatedId
     *   (đồng bộ FEC_CaseAssignmentQueueRoleResolver.walkQueueMembership).
     */
    private static Set<Id> resolveQueueMembersToUserIds(Set<Id> queueGroupIds) {
        Set<Id> recipientUserIds = new Set<Id>();
        Set<Id> queueRoleIdsFromMember = new Set<Id>();
        Set<Id> groupFrontier = new Set<Id>();
        Set<Id> visitedNestedGroups = new Set<Id>();

        if (queueGroupIds == null || queueGroupIds.isEmpty()) {
            return recipientUserIds;
        }

        String queueSetCacheKey = buildSortedIdSetKey(queueGroupIds);
        if (
            queueRecipientUserIdsMemo != null &&
            queueRecipientUserIdsMemo.containsKey(queueSetCacheKey)
        ) {
            return new Set<Id>(queueRecipientUserIdsMemo.get(queueSetCacheKey));
        }

        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queueGroupIds
        ]) {
            partitionQueueMembershipRef(
                gm.UserOrGroupId,
                recipientUserIds,
                queueRoleIdsFromMember,
                groupFrontier,
                visitedNestedGroups,
                queueGroupIds
            );
        }

        Integer groupIterations = 0;
        while (!groupFrontier.isEmpty() && groupIterations < MAX_PUBLIC_GROUP_EXPAND_ITERATIONS) {
            groupIterations++;
            Set<Id> toProcess = new Set<Id>();
            for (Id nestedGid : groupFrontier) {
                if (!visitedNestedGroups.contains(nestedGid)) {
                    toProcess.add(nestedGid);
                }
            }
            groupFrontier.clear();
            if (toProcess.isEmpty()) {
                break;
            }
            visitedNestedGroups.addAll(toProcess);

            /* Một SOQL: Type/RelatedId (nhóm Role) + membership — tránh 2 SOQL/lượt BFS. */
            for (Group grp : [
                SELECT Id, Type, RelatedId,
                    (SELECT Id, UserOrGroupId FROM GroupMembers)
                FROM Group
                WHERE Id IN :toProcess
            ]) {
                if (grp.RelatedId != null && grp.RelatedId.getSobjectType() == UserRole.SObjectType) {
                    if ('Role'.equals(grp.Type)) {
                        queueRoleIdsFromMember.add(grp.RelatedId);
                    } else if (grp.Type != null && grp.Type.startsWith('RoleAnd')) {
                        queueRoleIdsFromMember.add(grp.RelatedId);
                    }
                }
                if (grp.GroupMembers != null) {
                    for (GroupMember gm : grp.GroupMembers) {
                        partitionQueueMembershipRef(
                            gm.UserOrGroupId,
                            recipientUserIds,
                            queueRoleIdsFromMember,
                            groupFrontier,
                            visitedNestedGroups,
                            queueGroupIds
                        );
                    }
                }
            }
        }

        Set<Id> resolvedRoleIds = expandUserRoleSubtreeForQueue(queueRoleIdsFromMember);
        if (!resolvedRoleIds.isEmpty()) {
            for (User uRoleUser : [
                SELECT Id
                FROM User
                WHERE UserRoleId IN :resolvedRoleIds AND IsActive = TRUE
            ]) {
                recipientUserIds.add(uRoleUser.Id);
            }
        }

        if (queueRecipientUserIdsMemo == null) {
            queueRecipientUserIdsMemo = new Map<String, Set<Id>>();
        }
        queueRecipientUserIdsMemo.put(queueSetCacheKey, new Set<Id>(recipientUserIds));

        return recipientUserIds;
    }

    private static String buildSortedIdSetKey(Set<Id> idValues) {
        List<Id> sorted = new List<Id>(idValues);
        sorted.sort();
        List<String> parts = new List<String>();
        for (Id oneId : sorted) {
            parts.add(String.valueOf(oneId));
        }
        return String.join(parts, '|');
    }



    private static void partitionQueueMembershipRef(
        Id userOrGroupId,
        Set<Id> recipientUserIds,
        Set<Id> queueRoleIdsFromMember,
        Set<Id> groupFrontier,
        Set<Id> visitedNestedGroups,
        Set<Id> queueGroupIds
    ) {
        if (userOrGroupId == null) {
            return;
        }
        Schema.SObjectType st = userOrGroupId.getSObjectType();
        if (st == User.SObjectType) {
            recipientUserIds.add(userOrGroupId);
        } else if (st == UserRole.SObjectType) {
            queueRoleIdsFromMember.add(userOrGroupId);
        } else if (st == Group.SObjectType) {
            if (queueGroupIds.contains(userOrGroupId)) {
                return;
            }
            if (!visitedNestedGroups.contains(userOrGroupId)) {
                groupFrontier.add(userOrGroupId);
            }
        }
    }

    /** Role gán trên queue: chính role + mọi UserRole có ParentRoleId dẫn xuống subtree. */
    private static Set<Id> expandUserRoleSubtreeForQueue(Set<Id> seedRoleIds) {
        Set<Id> allRoleIds = new Set<Id>();
        if (seedRoleIds == null || seedRoleIds.isEmpty()) {
            return allRoleIds;
        }
        ensureUserRoleChildrenByParentLoaded();
        Set<Id> frontier = new Set<Id>(seedRoleIds);
        Integer depth = 0;
        while (!frontier.isEmpty() && depth < MAX_USER_ROLE_DESCENDANTS_DEPTH) {
            depth++;
            allRoleIds.addAll(frontier);
            Set<Id> next = new Set<Id>();
            for (Id parentRoleId : frontier) {
                List<Id> children = userRoleChildrenByParentMemo.get(parentRoleId);
                if (children == null || children.isEmpty()) {
                    continue;
                }
                for (Id childId : children) {
                    if (!allRoleIds.contains(childId)) {
                        next.add(childId);
                    }
                }
            }
            frontier = next;
        }
        return allRoleIds;
    }

    private static void ensureUserRoleChildrenByParentLoaded() {
        if (userRoleChildrenByParentMemo != null) {
            return;
        }
        userRoleChildrenByParentMemo = new Map<Id, List<Id>>();
        for (UserRole ur : [SELECT Id, ParentRoleId FROM UserRole]) {
            if (ur.ParentRoleId == null) {
                continue;
            }
            if (!userRoleChildrenByParentMemo.containsKey(ur.ParentRoleId)) {
                userRoleChildrenByParentMemo.put(ur.ParentRoleId, new List<Id>());
            }
            userRoleChildrenByParentMemo.get(ur.ParentRoleId).add(ur.Id);
        }
    }

    private static Set<String> splitToSet(String rawValue) {
        Set<String> result = new Set<String>();
        if (String.isBlank(rawValue)) {
            return result;
        }
        for (String item : rawValue.split('[;,\n]')) {
            if (String.isNotBlank(item)) {
                result.add(item.trim());
            }
        }
        return result;
    }

    private static Map<String, Integer> parseRoleScale(String roleRawValue, Decimal fallbackScale) {
        Map<String, Integer> roleScaleMap = new Map<String, Integer>();
        if (String.isBlank(roleRawValue)) {
            return roleScaleMap;
        }

        Integer fallback = fallbackScale == null ? 1 : Integer.valueOf(fallbackScale);
        if (fallback <= 0) {
            fallback = 1;
        }

        for (String item : roleRawValue.split(';')) {
            if (String.isBlank(item)) {
                continue;
            }
            String normalized = item.trim();
            /* Bỏ qua đoạn thừa kiểu "RoleName|scale;0" — token chỉ là số không phải tên Role. */
            if (!normalized.contains('|')) {
                try {
                    Integer.valueOf(normalized);
                    continue;
                } catch (Exception eIgnored) {
                }
            }
            if (normalized.contains('|')) {
                List<String> parts = normalized.split('\\|');
                String roleName = parts.size() > 0 ? parts[0].trim() : null;
                Integer scale = fallback;
                if (parts.size() > 1 && String.isNotBlank(parts[1])) {
                    try {
                        scale = Integer.valueOf(parts[1].trim());
                    } catch (Exception e) {
                        scale = fallback;
                    }
                }
                if (String.isNotBlank(roleName)) {
                    String rk = normalizeRoleKey(roleName);
                    if (String.isNotBlank(rk)) {
                        roleScaleMap.put(rk, scale <= 0 ? 1 : scale);
                    }
                }
            } else {
                String rk = normalizeRoleKey(normalized);
                if (String.isNotBlank(rk)) {
                    roleScaleMap.put(rk, fallback);
                }
            }
        }
        return roleScaleMap;
    }

    /**
     * Khớp FEC_Role__c với UserRole.Name: trim, gom khoảng trắng, lowercase.
     * Tránh trả 0 khi SOQL IN phân biệt hoa/thường hoặc lệch khoảng trắng so với cấu hình.
     */
    private static String normalizeRoleKey(String roleNameOrLabel) {
        if (String.isBlank(roleNameOrLabel)) {
            return '';
        }
        return roleNameOrLabel.trim().replaceAll('\\s+', ' ').toLowerCase();
    }

    private static List<User> filterUsersMatchingRoleScale(
        List<User> candidates,
        Map<String, Integer> roleScaleMap
    ) {
        List<User> eligible = new List<User>();
        if (candidates == null || roleScaleMap == null || roleScaleMap.isEmpty()) {
            return eligible;
        }
        Set<Id> configuredRoleIds = resolveConfiguredUserRoleIds(roleScaleMap);
        for (User u : candidates) {
            if (u.UserRoleId == null) {
                continue;
            }
            String rn = u.UserRole == null ? null : u.UserRole.Name;
            if (
                roleScaleMap.containsKey(normalizeRoleKey(rn)) &&
                configuredRoleIds.contains(u.UserRoleId)
            ) {
                eligible.add(u);
            }
        }
        return eligible;
    }

    private static Set<Id> resolveConfiguredUserRoleIds(Map<String, Integer> roleScaleMap) {
        Set<Id> roleIds = new Set<Id>();
        if (roleScaleMap == null || roleScaleMap.isEmpty()) {
            return roleIds;
        }
        Set<String> normalizedRoleKeys = roleScaleMap.keySet();
        for (UserRole roleRecord : [SELECT Id, Name FROM UserRole]) {
            if (
                String.isNotBlank(roleRecord.Name) &&
                normalizedRoleKeys.contains(normalizeRoleKey(roleRecord.Name))
            ) {
                roleIds.add(roleRecord.Id);
            }
        }
        return roleIds;
    }

    private static void trackUserInAssignmentOrder(List<Id> usersInAssignmentOrder, Id userId) {
        if (usersInAssignmentOrder == null || userId == null) {
            return;
        }
        if (!usersInAssignmentOrder.contains(userId)) {
            usersInAssignmentOrder.add(userId);
        }
    }

    private static void appendSummaryFromAssignmentOrder(
        List<Id> usersInAssignmentOrder,
        Map<Id, Integer> numberByUser,
        List<Id> summaryUserIds,
        List<Integer> summaryCounts
    ) {
        if (numberByUser == null || numberByUser.isEmpty()) {
            return;
        }
        Set<Id> seen = new Set<Id>();
        if (usersInAssignmentOrder != null) {
            for (Id userId : usersInAssignmentOrder) {
                if (userId == null || seen.contains(userId) || !numberByUser.containsKey(userId)) {
                    continue;
                }
                seen.add(userId);
                summaryUserIds.add(userId);
                summaryCounts.add(numberByUser.get(userId));
            }
        }
        for (Id userId : numberByUser.keySet()) {
            if (seen.contains(userId)) {
                continue;
            }
            summaryUserIds.add(userId);
            summaryCounts.add(numberByUser.get(userId));
        }
    }

    private static List<Id> buildOrderedUserIdsForLogDetails(
        List<Id> userIdsInAssignmentOrder,
        Map<Id, Integer> countsByAssignedUserId
    ) {
        List<Id> ordered = new List<Id>();
        if (countsByAssignedUserId == null || countsByAssignedUserId.isEmpty()) {
            return ordered;
        }
        Set<Id> seen = new Set<Id>();
        if (userIdsInAssignmentOrder != null) {
            for (Id userId : userIdsInAssignmentOrder) {
                if (userId == null || seen.contains(userId) || !countsByAssignedUserId.containsKey(userId)) {
                    continue;
                }
                seen.add(userId);
                ordered.add(userId);
            }
        }
        for (Id userId : countsByAssignedUserId.keySet()) {
            if (!seen.contains(userId)) {
                ordered.add(userId);
            }
        }
        return ordered;
    }

    private static Map<Id, Integer> getHistoricalAssignedCountByUser(
        Id assignmentId,
        List<User> eligibleUsers
    ) {
        Map<String, Id> userIdByEmail = new Map<String, Id>();
        Map<Id, Integer> countByUser = new Map<Id, Integer>();
        Set<String> emails = new Set<String>();

        for (User userRecord : eligibleUsers) {
            countByUser.put(userRecord.Id, 0);
            if (String.isNotBlank(userRecord.Email)) {
                String normalizedEmail = userRecord.Email.trim().toLowerCase();
                userIdByEmail.put(normalizedEmail, userRecord.Id);
                emails.add(normalizedEmail);
            }
        }
        if (emails.isEmpty()) {
            return countByUser;
        }

        for (AggregateResult ar : [
            SELECT FEC_Name_User__c userEmail, SUM(FEC_Number_of_Case__c) totalCase
            FROM FEC_Case_Assignment_Log_Detail__c
            WHERE
                FEC_Case_Assignment_log_Name__r.FEC_Case_Assignment_Name__c = :assignmentId
                AND FEC_Name_User__c IN :emails
            GROUP BY FEC_Name_User__c
        ]) {
            String emailValue = (String) ar.get('userEmail');
            if (String.isBlank(emailValue)) {
                continue;
            }
            Id userId = userIdByEmail.get(emailValue.trim().toLowerCase());
            if (userId == null) {
                continue;
            }
            Decimal totalAssigned = (Decimal) ar.get('totalCase');
            countByUser.put(userId, totalAssigned == null ? 0 : Integer.valueOf(totalAssigned));
        }
        return countByUser;
    }

    private static Integer scaleForUser(User userRecord, Map<String, Integer> roleScaleMap) {
        String rn = userRecord.UserRole == null ? null : userRecord.UserRole.Name;
        Integer s = roleScaleMap.get(normalizeRoleKey(rn));
        if (s == null || s <= 0) {
            return 1;
        }
        return s;
    }

    /** Lặp User Id theo tỉ trọng scale trên FEC_Role__c — thứ tự = thứ tự eligible (Name) trên queue. */
    private static List<Id> buildWeightedUserSlots(
        List<User> eligibleUsers,
        Map<String, Integer> roleScaleMap
    ) {
        List<Id> weightedIds = new List<Id>();
        if (eligibleUsers == null || roleScaleMap == null) {
            return weightedIds;
        }
        for (User userRecord : eligibleUsers) {
            Integer scale = scaleForUser(userRecord, roleScaleMap);
            for (Integer slot = 0; slot < scale; slot++) {
                weightedIds.add(userRecord.Id);
            }
        }
        return weightedIds;
    }

    /**
     * Continuous: cân đối lâu dài theo scale — mỗi Case gán cho user có tỉ số đã-gán/scale nhỏ nhất
     * (cnt1/sc1 và cnt2/sc2 so sanh bang tích nguyen cnt1*sc2 vs cnt2*sc1). Trong một lần chạy, cnt trên map tăng dần.
     */
    private static void distributeWeightedLeastLoaded(
        List<Case> targetCases,
        List<User> eligibleUsers,
        Map<String, Integer> roleScaleMap,
        Map<Id, Integer> historicalCountByUser,
        Map<Id, Integer> numberByUser,
        List<Id> usersInAssignmentOrder
    ) {
        if (targetCases == null || eligibleUsers == null || eligibleUsers.isEmpty()) {
            return;
        }
        Integer eligibleCount = eligibleUsers.size();
        /* Tiền tính scale + count vào List — không lookup scale/map lặp lại trong vòng Case×User */
        List<Integer> scaleByIndex = new List<Integer>();
        List<Integer> runCountByIndex = new List<Integer>();
        for (Integer idx = 0; idx < eligibleCount; idx++) {
            User candidateUser = eligibleUsers[idx];
            scaleByIndex.add(scaleForUser(candidateUser, roleScaleMap));
            runCountByIndex.add(getCountValue(historicalCountByUser, candidateUser.Id));
        }

        for (Case targetCaseRecord : targetCases) {
            Integer bestIdx = -1;
            Integer bestCnt = 0;
            Integer bestScale = 1;
            for (Integer idx = 0; idx < eligibleCount; idx++) {
                Integer sc = scaleByIndex[idx];
                Integer cnt = runCountByIndex[idx];
                if (bestIdx < 0) {
                    bestIdx = idx;
                    bestCnt = cnt;
                    bestScale = sc;
                    continue;
                }
                Long lhs = (Long) cnt * bestScale;
                Long rhs = (Long) bestCnt * sc;
                if (lhs < rhs || (lhs == rhs && idx < bestIdx)) {
                    bestIdx = idx;
                    bestCnt = cnt;
                    bestScale = sc;
                }
            }
            if (bestIdx < 0) {
                continue;
            }
            User chosenUser = eligibleUsers[bestIdx];
            Id chosenId = chosenUser.Id;
            targetCaseRecord.OwnerId = chosenId;
            Integer newCnt = bestCnt + 1;
            runCountByIndex[bestIdx] = newCnt;
            historicalCountByUser.put(chosenId, newCnt);
            Integer nextCount =
                numberByUser.containsKey(chosenId) ? numberByUser.get(chosenId) + 1 : 1;
            numberByUser.put(chosenId, nextCount);
            if (nextCount == 1) {
                trackUserInAssignmentOrder(usersInAssignmentOrder, chosenId);
            }
        }
    }

    /**
     * Time-Based và default: một vòng lặp RR có trong số slot = tổng scale; offsets theo log lịch sử để run sau nối tiếp run trước.
     */
    private static void distributeWeightedSequentialFromHistory(
        List<Case> targetCases,
        List<User> eligibleUsers,
        Map<String, Integer> roleScaleMap,
        Map<Id, Integer> historicalCountByUser,
        Map<Id, Integer> numberByUser,
        List<Id> usersInAssignmentOrder
    ) {
        List<Id> weightedSlots = buildWeightedUserSlots(eligibleUsers, roleScaleMap);
        if (
            targetCases == null ||
            weightedSlots.isEmpty()
        ) {
            return;
        }
        Integer totalPriorAcrossEligible = 0;
        if (eligibleUsers != null) {
            for (User u : eligibleUsers) {
                totalPriorAcrossEligible += getCountValue(historicalCountByUser, u.Id);
            }
        }
        Integer pointer = Math.mod(totalPriorAcrossEligible, weightedSlots.size());
        for (Case targetCaseRecord : targetCases) {
            Id newOwnerId = weightedSlots[pointer];
            targetCaseRecord.OwnerId = newOwnerId;
            historicalCountByUser.put(
                newOwnerId,
                getCountValue(historicalCountByUser, newOwnerId) + 1
            );
            Integer nextCount =
                numberByUser.containsKey(newOwnerId) ? numberByUser.get(newOwnerId) + 1 : 1;
            numberByUser.put(newOwnerId, nextCount);
            if (nextCount == 1) {
                trackUserInAssignmentOrder(usersInAssignmentOrder, newOwnerId);
            }
            pointer = Math.mod(pointer + 1, weightedSlots.size());
        }
    }

    private static Integer getCountValue(Map<Id, Integer> countByUser, Id userId) {
        Integer currentValue = countByUser.get(userId);
        return currentValue == null ? 0 : currentValue;
    }

    private static String buildKey(
        Id productTypeId,
        String productTypeName,
        Id categoryId,
        String categoryName,
        Id subCategoryId,
        String subCategoryName
    ) {
        return normalizeKeyPart(productTypeId, productTypeName) + '|' +
            normalizeKeyPart(categoryId, categoryName) + '|' +
            normalizeKeyPart(subCategoryId, subCategoryName);
    }

    private static String normalizeKeyPart(Id idValue, String nameValue) {
        if (String.isNotBlank(nameValue)) {
            return nameValue.trim().toLowerCase();
        }
        if (idValue != null) {
            return String.valueOf(idValue).toLowerCase();
        }
        return '';
    }

    /**
     * Auto distribute đổi Owner hàng loạt — không tạo Routing Action History / notification
     * trong cùng transaction (tránh chiếm quota enqueue của xích AutoDistQueueJob).
     */
    private static void registerSkipOwnerChangeRoutingHistoryForCases(List<Case> cases) {
        if (cases == null) {
            return;
        }
        for (Case c : cases) {
            if (c != null && c.Id != null) {
                FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
            }
        }
    }
}