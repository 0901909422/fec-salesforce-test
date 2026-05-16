public without sharing class FEC_CaseAssignmentAutoDistributeService {
    private static final String METHOD_CONTINUOUS = 'Continuous';
    private static final String METHOD_TIME_BASED = 'Time-Based';

    public static void executeNow() {
        DateTime nowTime = System.now();

        List<FEC_Case_Assignment__c> activeAssignments = [
            SELECT
                Id,
                Name,
                FEC_Assignment_Method__c,
                FEC_Scheduled_Time__c,
                FEC_Time_Slots__c,
                FEC_Select_Queues__c,
                FEC_Role__c,
                FEC_Scale__c
            FROM FEC_Case_Assignment__c
            WHERE FEC_Status__c = :FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE
        ];
        if (activeAssignments.isEmpty()) {
            return;
        }

        Map<Id, Integer> existingLogCountByAssignment = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT FEC_Case_Assignment_Name__c assignmentId, COUNT(Id) total
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c IN :new Map<Id, FEC_Case_Assignment__c>(activeAssignments).keySet()
            GROUP BY FEC_Case_Assignment_Name__c
        ]) {
            existingLogCountByAssignment.put(
                (Id) ar.get('assignmentId'),
                Integer.valueOf(ar.get('total'))
            );
        }

        for (FEC_Case_Assignment__c assignmentRecord : activeAssignments) {
            if (!isDueToRun(assignmentRecord, nowTime)) {
                continue;
            }
            if (hasLogInCurrentMinute(assignmentRecord.Id, nowTime)) {
                continue;
            }
            Integer runNumber = existingLogCountByAssignment.containsKey(assignmentRecord.Id)
                ? existingLogCountByAssignment.get(assignmentRecord.Id) + 1
                : 1;
            Integer assignedCount = executeSingleAssignment(assignmentRecord, runNumber);
            if (assignedCount > 0) {
                existingLogCountByAssignment.put(assignmentRecord.Id, runNumber);
            }
        }
    }

    private static Boolean isDueToRun(FEC_Case_Assignment__c assignmentRecord, DateTime nowTime) {
        if (assignmentRecord.FEC_Assignment_Method__c == METHOD_CONTINUOUS) {
            Integer scheduledMinutes = assignmentRecord.FEC_Scheduled_Time__c == null
                ? 30
                : Integer.valueOf(assignmentRecord.FEC_Scheduled_Time__c);
            if (scheduledMinutes <= 0) {
                scheduledMinutes = 30;
            }
            Integer minutesSinceMidnight = (nowTime.hour() * 60) + nowTime.minute();
            return Math.mod(minutesSinceMidnight, scheduledMinutes) == 0;
        }

        if (assignmentRecord.FEC_Assignment_Method__c == METHOD_TIME_BASED) {
            if (String.isBlank(assignmentRecord.FEC_Time_Slots__c)) {
                return false;
            }
            String currentHm = nowTime.format('HH:mm');
            for (String slot : assignmentRecord.FEC_Time_Slots__c.split(';')) {
                if (slot != null && slot.trim() == currentHm) {
                    return true;
                }
            }
        }
        return false;
    }

    private static Boolean hasLogInCurrentMinute(Id assignmentId, DateTime nowTime) {
        DateTime minuteStart = DateTime.newInstance(
            nowTime.year(),
            nowTime.month(),
            nowTime.day(),
            nowTime.hour(),
            nowTime.minute(),
            0
        );
        DateTime minuteEnd = minuteStart.addMinutes(1);
        Integer countLogs = [
            SELECT COUNT()
            FROM FEC_Case_Assignment_Logs__c
            WHERE
                FEC_Case_Assignment_Name__c = :assignmentId
                AND CreatedDate >= :minuteStart
                AND CreatedDate < :minuteEnd
        ];
        return countLogs > 0;
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

        Set<Id> queueUserIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT GroupId, UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :queueById.keySet()
        ]) {
            if (gm.UserOrGroupId != null && String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                queueUserIds.add(gm.UserOrGroupId);
            }
        }
        if (queueUserIds.isEmpty()) {
            return 0;
        }

        List<User> eligibleUsers = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE
                Id IN :queueUserIds
                AND IsActive = true
                AND UserRoleId != null
                AND UserRole.Name IN :roleScaleMap.keySet()
            ORDER BY Name
        ];
        if (eligibleUsers.isEmpty()) {
            return 0;
        }

        Map<Id, User> userById = new Map<Id, User>(eligibleUsers);
        List<Id> orderedUserIds = new List<Id>();
        for (User userRecord : eligibleUsers) {
            orderedUserIds.add(userRecord.Id);
        }
        if (orderedUserIds.isEmpty()) {
            return 0;
        }

        Map<Id, Integer> historicalCountByUser = getHistoricalAssignedCountByUser(
            assignmentRecord.Id,
            eligibleUsers
        );
        Map<Id, Integer> numberByUser = new Map<Id, Integer>();
        if (assignmentRecord.FEC_Assignment_Method__c == METHOD_CONTINUOUS) {
            distributeEvenly(targetCases, orderedUserIds, historicalCountByUser, numberByUser);
        } else if (assignmentRecord.FEC_Assignment_Method__c == METHOD_TIME_BASED) {
            distributeSequentialByTime(targetCases, orderedUserIds, historicalCountByUser, numberByUser);
        } else {
            distributeWeightedRoundRobin(
                targetCases,
                eligibleUsers,
                roleScaleMap,
                numberByUser
            );
        }
        if (numberByUser.isEmpty()) {
            return 0;
        }
        update targetCases;

        FEC_Case_Assignment_Logs__c logRecord = new FEC_Case_Assignment_Logs__c(
            Name = assignmentRecord.Name + ' - ' + String.valueOf(runNumber),
            FEC_Case_Assignment_Name__c = assignmentRecord.Id,
            FEC_Number_of_Case__c = targetCases.size()
        );
        insert logRecord;

        List<FEC_Case_Assignment_Log_Detail__c> detailList = new List<FEC_Case_Assignment_Log_Detail__c>();
        for (Id userId : numberByUser.keySet()) {
            User u = userById.get(userId);
            String emailValue = u != null ? u.Email : null;
            detailList.add(new FEC_Case_Assignment_Log_Detail__c(
                Name = String.isNotBlank(emailValue) ? emailValue : String.valueOf(userId),
                FEC_Case_Assignment_log_Name__c = logRecord.Id,
                FEC_Name_User__c = emailValue,
                FEC_Number_of_Case__c = numberByUser.get(userId)
            ));
        }
        if (!detailList.isEmpty()) {
            insert detailList;
        }
        return targetCases.size();
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
                    roleScaleMap.put(roleName, scale <= 0 ? 1 : scale);
                }
            } else {
                roleScaleMap.put(normalized, fallback);
            }
        }
        return roleScaleMap;
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

    private static void distributeEvenly(
        List<Case> targetCases,
        List<Id> orderedUserIds,
        Map<Id, Integer> historicalCountByUser,
        Map<Id, Integer> numberByUser
    ) {
        Integer startIndex = 0;
        Integer userSize = orderedUserIds.size();
        for (Case c : targetCases) {
            Integer chosenIndex = startIndex;
            Integer minCount = getCountValue(historicalCountByUser, orderedUserIds[chosenIndex]);
            for (Integer offset = 1; offset < userSize; offset++) {
                Integer candidateIndex = Math.mod(startIndex + offset, userSize);
                Integer candidateCount = getCountValue(historicalCountByUser, orderedUserIds[candidateIndex]);
                if (candidateCount < minCount) {
                    minCount = candidateCount;
                    chosenIndex = candidateIndex;
                }
            }
            Id chosenUserId = orderedUserIds[chosenIndex];
            c.OwnerId = chosenUserId;
            historicalCountByUser.put(chosenUserId, minCount + 1);
            numberByUser.put(
                chosenUserId,
                numberByUser.containsKey(chosenUserId) ? numberByUser.get(chosenUserId) + 1 : 1
            );
            startIndex = Math.mod(chosenIndex + 1, userSize);
        }
    }

    private static void distributeSequentialByTime(
        List<Case> targetCases,
        List<Id> orderedUserIds,
        Map<Id, Integer> historicalCountByUser,
        Map<Id, Integer> numberByUser
    ) {
        Integer totalAssigned = 0;
        for (Id userId : orderedUserIds) {
            totalAssigned += getCountValue(historicalCountByUser, userId);
        }
        Integer pointer = Math.mod(totalAssigned, orderedUserIds.size());

        for (Case c : targetCases) {
            Id chosenUserId = orderedUserIds[pointer];
            c.OwnerId = chosenUserId;
            historicalCountByUser.put(
                chosenUserId,
                getCountValue(historicalCountByUser, chosenUserId) + 1
            );
            numberByUser.put(
                chosenUserId,
                numberByUser.containsKey(chosenUserId) ? numberByUser.get(chosenUserId) + 1 : 1
            );
            pointer = Math.mod(pointer + 1, orderedUserIds.size());
        }
    }

    private static void distributeWeightedRoundRobin(
        List<Case> targetCases,
        List<User> eligibleUsers,
        Map<String, Integer> roleScaleMap,
        Map<Id, Integer> numberByUser
    ) {
        List<Id> weightedUserIds = new List<Id>();
        for (User userRecord : eligibleUsers) {
            Integer scale = roleScaleMap.get(userRecord.UserRole.Name);
            if (scale == null || scale <= 0) {
                scale = 1;
            }
            for (Integer i = 0; i < scale; i++) {
                weightedUserIds.add(userRecord.Id);
            }
        }
        if (weightedUserIds.isEmpty()) {
            return;
        }

        Integer pointer = 0;
        for (Case c : targetCases) {
            Id newOwnerId = weightedUserIds[pointer];
            c.OwnerId = newOwnerId;
            numberByUser.put(
                newOwnerId,
                numberByUser.containsKey(newOwnerId) ? numberByUser.get(newOwnerId) + 1 : 1
            );
            pointer = Math.mod(pointer + 1, weightedUserIds.size());
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
}