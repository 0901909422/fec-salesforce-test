/**
 * SLA cảnh báo DS/TS: eligibility, anchor RAH, elapsed wall-clock, recipients, stamp notification fields.
 */
public without sharing class FEC_CaseDsTsSlaService {

    public static final String SCENARIO_TH1 = 'TH1';
    public static final String SCENARIO_TH2 = 'TH2';

    public static final String PROFILE_TELESALES = 'TELESALES';
    public static final String PROFILE_LG = 'LG';
    public static final String PROFILE_DIRECT_SALES = 'DIRECT_SALES';
    public static final String PROFILE_POS_SALES = 'POS_SALES';

    private static final String ROUTE_TO = FEC_CaseBusinessService.ROUTE_TO;
    private static final String RAH_TYPE_CASE = 'Case';
    private static final Long MS_1MIN = 60L * 1000L;
    private static final Long MS_2MIN = 2L * MS_1MIN;
    private static final Long MS_3MIN = 3L * MS_1MIN;

    private static final Long MS_2H = 2L * 60L * 60L * 1000L;
    private static final Long MS_4H = 4L * 60L * 60L * 1000L;
    private static final Long MS_6H = 6L * 60L * 60L * 1000L;
    private static final Long MS_8H = 8L * 60L * 60L * 1000L;

    /**
     * Ngưỡng production: 2h/4h (Telesales/LG) hoặc 4h/6h/8h (DS/POS) — elapsed = now − anchor (đồng hồ thực).
     * Ngưỡng UAT: 1/2/3 phút. Label FEC_SLA_DS_TS_Use_Test_Thresholds = true.
     */
    @TestVisible
    private static Boolean useOneMinuteTestThresholdsOverride;
    private static Boolean useOneMinuteTestThresholdsOverrideSet = false;

    private static final Set<String> CATEGORY_NAMES = new Set<String>{ 'Complaint', 'Feedback' };

    private static final List<String> QUEUE_LABELS_ORDERED = new List<String>{
        'DQ - Direct Sales',
        'DQ - POS Sales',
        'DQ - Telesales',
        'LG'
    };

    private static final Map<String, String> DEV_NAME_TO_PROFILE = new Map<String, String>{
        'FEC_DQ_Telesales' => PROFILE_TELESALES,
        'FEC_LG' => PROFILE_LG,
        'FEC_DQ_Direct_Sales' => PROFILE_DIRECT_SALES,
        'FEC_DQ_POS_Sales' => PROFILE_POS_SALES
    };

    private static final Map<String, String> LABEL_TO_PROFILE = new Map<String, String>{
        'DQ - Telesales' => PROFILE_TELESALES,
        'LG' => PROFILE_LG,
        'DQ - Direct Sales' => PROFILE_DIRECT_SALES,
        'DQ - POS Sales' => PROFILE_POS_SALES
    };

    private static final Map<String, String> PROFILE_TO_RECIPIENT_LABEL = new Map<String, String>{
        PROFILE_TELESALES => 'FEC_SLA_DS_TS_Recipient_Telesales',
        PROFILE_LG => 'FEC_SLA_DS_TS_Recipient_LG',
        PROFILE_DIRECT_SALES => 'FEC_SLA_DS_TS_Recipient_Direct_Sales',
        PROFILE_POS_SALES => 'FEC_SLA_DS_TS_Recipient_Pos_Sales'
    };

    private static Set<Id> slaOwnerQueueIds;
    private static Map<String, Id> slaQueueIdByDevName;
    private static Map<String, Id> slaQueueIdByLabel;
    private static Set<Id> allQueueOwnerIds;

    private static final Map<String, String> PROFILE_TO_LABEL = new Map<String, String>{
        PROFILE_TELESALES => 'DQ - Telesales',
        PROFILE_LG => 'LG',
        PROFILE_DIRECT_SALES => 'DQ - Direct Sales',
        PROFILE_POS_SALES => 'DQ - POS Sales'
    };

    public class SlaEligibilityContext {
        public Boolean isEligible = false;
        public String scenario;
        public Id notifyQueueId;
        /** @deprecated dùng activeProfiles; giữ profile đầu tiên trong danh sách */
        public String queueProfile;
        public Datetime anchorDatetime;
        /** @deprecated dùng activeProfiles */
        public String matchedQueueLabel;
        public List<String> activeProfiles = new List<String>();
        public Map<String, Datetime> profileToAnchor = new Map<String, Datetime>();
    }

    public static SlaEligibilityContext evaluateEligibility(Case c) {
        SlaEligibilityContext ctx = new SlaEligibilityContext();
        if (c == null || !meetsCommonCriteria(c)) {
            return ctx;
        }
        ctx.activeProfiles = resolveActiveProfiles(c);
        if (ctx.activeProfiles.isEmpty()) {
            return ctx;
        }
        ctx.isEligible = true;
        ctx.queueProfile = ctx.activeProfiles[0];
        if (matchesTh1(c)) {
            ctx.scenario = SCENARIO_TH1;
            ctx.notifyQueueId = c.OwnerId;
            ctx.matchedQueueLabel = resolveQueueLabelForProfile(ctx.queueProfile);
        } else {
            ctx.scenario = SCENARIO_TH2;
            ctx.matchedQueueLabel = resolveQueueLabelForProfile(ctx.queueProfile);
            ctx.notifyQueueId = resolveQueueIdByLabel(ctx.matchedQueueLabel);
        }
        return ctx;
    }

    public static List<String> resolveActiveProfiles(Case c) {
        List<String> profiles = new List<String>();
        if (c == null) {
            return profiles;
        }
        if (matchesTh1(c)) {
            String profile = resolveProfileFromOwnerId(c.OwnerId);
            if (String.isNotBlank(profile)) {
                profiles.add(profile);
            }
            return profiles;
        }
        for (String label : resolveAllMatchedQueueLabels(c.FEC_Assignment_Users__c)) {
            String profile = LABEL_TO_PROFILE.get(label);
            if (String.isNotBlank(profile) && !profiles.contains(profile)) {
                profiles.add(profile);
            }
        }
        return profiles;
    }

    public static Boolean meetsCommonCriteria(Case c) {
        if (c == null) {
            return false;
        }
        if (!isPendingStatus(c.FEC_Case_Status__c)) {
            return false;
        }
        if (!teamContainsDsOrTs(c.FEC_Team__c)) {
            return false;
        }
        String categoryName = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
        if (String.isBlank(categoryName) || !CATEGORY_NAMES.contains(categoryName)) {
            return false;
        }
        // TH1: owner phải là một trong 4 queue DS/TS
        if (matchesTh1(c)) {
            return isQueueOwner(c.OwnerId) && getSlaOwnerQueueIds().contains(c.OwnerId);
        }
        // TH2: đã có assignment tới queue DS/TS (owner có thể là User)
        if (matchesTh2(c)) {
            return true;
        }
        return false;
    }

    public static Boolean matchesTh1(Case c) {
        Decimal count = c.FEC_Assignment_Count__c == null ? 0 : c.FEC_Assignment_Count__c;
        if (count != 0) {
            return false;
        }
        return getSlaOwnerQueueIds().contains(c.OwnerId);
    }

    public static Boolean matchesTh2(Case c) {
        Decimal count = c.FEC_Assignment_Count__c == null ? 0 : c.FEC_Assignment_Count__c;
        if (count <= 0) {
            return false;
        }
        return !resolveAllMatchedQueueLabels(c.FEC_Assignment_Users__c).isEmpty();
    }

    public static Boolean teamContainsDsOrTs(String fecTeam) {
        if (String.isBlank(fecTeam)) {
            return false;
        }
        String norm = fecTeam.replace('_', ' ').trim().toUpperCase();
        if (norm == 'DS' || norm == 'TS' || norm == 'LG') {
            return true;
        }
        if (norm.contains('TELESALE')) {
            return true;
        }
        if (norm.contains('DIRECT') && norm.contains('SALE')) {
            return true;
        }
        if (norm.contains('POS') && norm.contains('SALE')) {
            return true;
        }
        for (String part : fecTeam.split('_')) {
            String token = part != null ? part.trim().toUpperCase() : '';
            if (token == 'DS' || token == 'TS') {
                return true;
            }
        }
        return false;
    }

    public static Set<Id> getSlaOwnerQueueIds() {
        ensureSlaQueuesLoaded();
        return slaOwnerQueueIds;
    }

    public static List<String> resolveAllMatchedQueueLabels(String assignmentUsers) {
        List<String> labels = new List<String>();
        if (String.isBlank(assignmentUsers)) {
            return labels;
        }
        for (String label : QUEUE_LABELS_ORDERED) {
            if (assignmentUsers.contains(label)) {
                labels.add(label);
            }
        }
        return labels;
    }

    /** Giữ tương thích: label đầu tiên khớp (theo thứ tự QUEUE_LABELS_ORDERED). */
    public static String resolveMatchedQueueLabel(String assignmentUsers) {
        List<String> labels = resolveAllMatchedQueueLabels(assignmentUsers);
        return labels.isEmpty() ? null : labels[0];
    }

    public static void bulkResolveAnchors(Map<Id, SlaEligibilityContext> contextsByCaseId) {
        bulkResolveAnchorsPerProfile(contextsByCaseId);
    }

    public static void bulkResolveAnchorsPerProfile(
        Map<Id, SlaEligibilityContext> contextsByCaseId
    ) {
        if (contextsByCaseId == null || contextsByCaseId.isEmpty()) {
            return;
        }
        Set<Id> caseIds = new Set<Id>();
        for (Id caseId : contextsByCaseId.keySet()) {
            SlaEligibilityContext ctx = contextsByCaseId.get(caseId);
            if (ctx != null && ctx.isEligible) {
                caseIds.add(caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return;
        }

        List<FEC_Routing_Action_History__c> histories = [
            SELECT Id, FEC_Case__c, CreatedDate, FEC_Routing_Action_Type__c,
                   FEC_Routing_Action__c, FEC_Assignment__c,
                   FEC_Updated_User_Queue__c, FEC_Updated_User_Queue_ID__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c IN :caseIds
              AND FEC_Routing_Action__c = :ROUTE_TO
            ORDER BY CreatedDate ASC
        ];

        for (Id caseId : contextsByCaseId.keySet()) {
            SlaEligibilityContext ctx = contextsByCaseId.get(caseId);
            if (ctx == null || !ctx.isEligible) {
                continue;
            }
            ctx.profileToAnchor = new Map<String, Datetime>();
            for (String profile : ctx.activeProfiles) {
                String queueLabel = resolveQueueLabelForProfile(profile);
                Id queueId = resolveQueueIdByLabel(queueLabel);
                for (FEC_Routing_Action_History__c rah : histories) {
                    if (rah.FEC_Case__c != caseId) {
                        continue;
                    }
                    if (!rahMatchesProfile(rah, ctx, profile, queueLabel, queueId)) {
                        continue;
                    }
                    if (!ctx.profileToAnchor.containsKey(profile)) {
                        ctx.profileToAnchor.put(profile, rah.CreatedDate);
                    }
                }
            }
            ctx.anchorDatetime = resolvePrimaryAnchorDatetime(ctx);
        }
    }

    public static void setUseOneMinuteTestThresholds(Boolean enabled) {
        useOneMinuteTestThresholdsOverrideSet = true;
        useOneMinuteTestThresholdsOverride = enabled == true;
    }

    public static Boolean isUseOneMinuteTestThresholds() {
        return isOneMinuteTestThresholdsEnabled();
    }

    private static Boolean isOneMinuteTestThresholdsEnabled() {
        if (useOneMinuteTestThresholdsOverrideSet) {
            return useOneMinuteTestThresholdsOverride;
        }
        return 'true'.equalsIgnoreCase(
            String.valueOf(Label.FEC_SLA_DS_TS_Use_Test_Thresholds).trim()
        );
    }

    /** Thời gian trôi (ms) = now − anchor, không dùng Business Hours. */
    public static Long getElapsedMs(Datetime anchorCreatedDate, Datetime nowDt) {
        if (anchorCreatedDate == null || nowDt == null) {
            return null;
        }
        return nowDt.getTime() - anchorCreatedDate.getTime();
    }

    public static Integer resolveNextCaseSlotToStamp(
        Case c,
        List<String> activeProfiles,
        Map<String, Datetime> profileToAnchor,
        Datetime nowDt
    ) {
        if (c == null || activeProfiles == null || activeProfiles.isEmpty()
            || profileToAnchor == null || nowDt == null) {
            return null;
        }
        for (Integer slot = 1; slot <= 3; slot++) {
            if (!isCaseNotificationSlotEmpty(c, slot)) {
                continue;
            }
            if (slot > 1 && isCaseNotificationSlotEmpty(c, slot - 1)) {
                break;
            }
            for (String profile : activeProfiles) {
                Datetime anchor = profileToAnchor.get(profile);
                if (anchor == null) {
                    continue;
                }
                Long elapsedMs = getElapsedMs(anchor, nowDt);
                if (elapsedMs != null
                    && elapsedMs >= thresholdMsForSlot(slot, profile)) {
                    return slot;
                }
            }
        }
        return null;
    }

    public static Set<String> resolveRecipientUserIdsUnion(List<String> activeProfiles) {
        Set<String> userIds = new Set<String>();
        if (activeProfiles == null) {
            return userIds;
        }
        for (String profile : activeProfiles) {
            userIds.addAll(resolveRecipientUserIdsByProfile(profile));
        }
        return userIds;
    }

    public static Integer getDueNotificationSlot(Case c, Long elapsedMs, String queueProfile) {
        if (c == null || elapsedMs == null || String.isBlank(queueProfile)) {
            return null;
        }
        if (queueProfile == PROFILE_TELESALES || queueProfile == PROFILE_LG) {
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)
                && c.FEC_SLA_Notification_1__c == null) {
                return 1;
            }
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)
                && c.FEC_SLA_Notification_2__c == null) {
                return 2;
            }
            return null;
        }
        if (queueProfile == PROFILE_DIRECT_SALES || queueProfile == PROFILE_POS_SALES) {
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)
                && c.FEC_SLA_Notification_1__c == null) {
                return 1;
            }
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)
                && c.FEC_SLA_Notification_2__c == null) {
                return 2;
            }
            if (elapsedMs >= thresholdMsForSlot(3, queueProfile)
                && c.FEC_SLA_Notification_3__c == null) {
                return 3;
            }
            return null;
        }
        return null;
    }

    private static Long thresholdMsForSlot(Integer slot, String queueProfile) {
        if (isOneMinuteTestThresholdsEnabled()) {
            if (queueProfile == PROFILE_TELESALES || queueProfile == PROFILE_LG) {
                if (slot == 1) {
                    return MS_1MIN;
                }
                if (slot == 2) {
                    return MS_2MIN;
                }
            } else if (
                queueProfile == PROFILE_DIRECT_SALES
                || queueProfile == PROFILE_POS_SALES
            ) {
                if (slot == 1) {
                    return MS_1MIN;
                }
                if (slot == 2) {
                    return MS_2MIN;
                }
                if (slot == 3) {
                    return MS_3MIN;
                }
            }
            return null;
        }
        if (queueProfile == PROFILE_TELESALES || queueProfile == PROFILE_LG) {
            if (slot == 1) {
                return MS_2H;
            }
            if (slot == 2) {
                return MS_4H;
            }
        } else if (
            queueProfile == PROFILE_DIRECT_SALES
            || queueProfile == PROFILE_POS_SALES
        ) {
            if (slot == 1) {
                return MS_4H;
            }
            if (slot == 2) {
                return MS_6H;
            }
            if (slot == 3) {
                return MS_8H;
            }
        }
        return null;
    }

    public static Case buildNotificationPatch(Case row, SlaEligibilityContext ctx, Datetime nowDt) {
        if (ctx == null || !ctx.isEligible) {
            if (needsClearNotifications(row)) {
                Case clearPatch = new Case(Id = row.Id);
                clearPatch.FEC_SLA_Notification_1__c = null;
                clearPatch.FEC_SLA_Notification_2__c = null;
                clearPatch.FEC_SLA_Notification_3__c = null;
                return clearPatch;
            }
            return null;
        }
        if (ctx.profileToAnchor == null || ctx.profileToAnchor.isEmpty()) {
            ctx.profileToAnchor = new Map<String, Datetime>();
        }

        Integer slot = resolveNextCaseSlotToStamp(
            row,
            ctx.activeProfiles,
            ctx.profileToAnchor,
            nowDt
        );
        if (slot == null) {
            return null;
        }

        Case patch = new Case(Id = row.Id);
        if (slot == 1) {
            patch.FEC_SLA_Notification_1__c = nowDt;
        } else if (slot == 2) {
            patch.FEC_SLA_Notification_2__c = nowDt;
        } else if (slot == 3) {
            patch.FEC_SLA_Notification_3__c = nowDt;
        }
        return patch;
    }

    public static Boolean needsClearNotifications(Case c) {
        return c != null
            && (c.FEC_SLA_Notification_1__c != null
                || c.FEC_SLA_Notification_2__c != null
                || c.FEC_SLA_Notification_3__c != null);
    }

    /** Custom Label: danh sách User Id phân tách bằng ; hoặc , */
    public static List<Id> parseUserIdsFromLabelValue(String labelValue) {
        List<Id> userIds = new List<Id>();
        if (String.isBlank(labelValue)) {
            return userIds;
        }
        String normalized = labelValue.replace(',', ';');
        for (String part : normalized.split(';')) {
            String token = part != null ? part.trim() : '';
            Id userId = parseUserIdToken(token);
            if (userId != null) {
                userIds.add(userId);
            }
        }
        return userIds;
    }

    private static Id parseUserIdToken(String token) {
        if (String.isBlank(token)) {
            return null;
        }
        try {
            Id recordId = Id.valueOf(token);
            if (recordId.getSobjectType() == User.SObjectType) {
                return recordId;
            }
        } catch (Exception e) {
            // token không phải User Id hợp lệ
        }
        return null;
    }

    public static String getRecipientLabelApiName(String queueProfile) {
        return PROFILE_TO_RECIPIENT_LABEL.get(queueProfile);
    }

    public static List<Id> getRecipientUserIdsForProfile(String queueProfile) {
        if (queueProfile == PROFILE_TELESALES) {
            return parseUserIdsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Telesales);
        }
        if (queueProfile == PROFILE_LG) {
            return parseUserIdsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_LG);
        }
        if (queueProfile == PROFILE_DIRECT_SALES) {
            return parseUserIdsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Direct_Sales);
        }
        if (queueProfile == PROFILE_POS_SALES) {
            return parseUserIdsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Pos_Sales);
        }
        return new List<Id>();
    }

    public static Set<String> resolveRecipientUserIds(SlaEligibilityContext ctx) {
        if (ctx == null) {
            return new Set<String>();
        }
        if (ctx.activeProfiles != null && !ctx.activeProfiles.isEmpty()) {
            return resolveRecipientUserIdsUnion(ctx.activeProfiles);
        }
        if (String.isBlank(ctx.queueProfile)) {
            return new Set<String>();
        }
        return resolveRecipientUserIdsByProfile(ctx.queueProfile);
    }

    public static Set<String> resolveRecipientUserIdsByProfile(String queueProfile) {
        List<Id> configuredUserIds = getRecipientUserIdsForProfile(queueProfile);
        if (configuredUserIds.isEmpty()) {
            return new Set<String>();
        }
        Set<String> userIds = new Set<String>();
        for (User u : [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND Id IN :configuredUserIds
        ]) {
            userIds.add(u.Id);
        }
        return userIds;
    }

    public static String resolveCaseDisplayId(Case c) {
        if (c == null) {
            return '';
        }
        try {
            if (String.isNotBlank(c.FEC_ID_Search__c)) {
                return c.FEC_ID_Search__c;
            }
        } catch (SObjectException e) {
            // Trigger.new từ partial update không query field này
        }
        if (c.Id == null) {
            return '';
        }
        List<Case> rows = [
            SELECT FEC_ID_Search__c
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];
        return rows.isEmpty() || String.isBlank(rows[0].FEC_ID_Search__c)
            ? ''
            : rows[0].FEC_ID_Search__c;
    }

    public static String getApproachingTitle(Case c) {
        return String.format(
            Label.FEC_MSG_SLA_Notif_Title_Approaching,
            new List<String>{ resolveCaseDisplayId(c) }
        );
    }

    public static String getApproachingBody(Case c) {
        return String.format(
            Label.FEC_MSG_SLA_Notif_Body_Approaching,
            new List<String>{ resolveCaseDisplayId(c) }
        );
    }

    private static Boolean rahMatchesProfile(
        FEC_Routing_Action_History__c rah,
        SlaEligibilityContext ctx,
        String profile,
        String queueLabel,
        Id queueId
    ) {
        if (rah == null || ctx == null || String.isBlank(queueLabel)) {
            return false;
        }
        if (!queueMatchesRoutingHistory(rah, queueLabel, queueId)) {
            return false;
        }
        if (ctx.scenario == SCENARIO_TH1) {
            if (rah.FEC_Assignment__c != null) {
                return false;
            }
            if ('Assignment'.equalsIgnoreCase(rah.FEC_Routing_Action_Type__c)) {
                return false;
            }
            return String.isBlank(rah.FEC_Routing_Action_Type__c)
                || RAH_TYPE_CASE.equalsIgnoreCase(rah.FEC_Routing_Action_Type__c);
        }
        return rah.FEC_Assignment__c != null;
    }

    private static Boolean queueMatchesRoutingHistory(
        FEC_Routing_Action_History__c rah,
        String queueLabel,
        Id queueId
    ) {
        if (queueId != null && String.isNotBlank(rah.FEC_Updated_User_Queue_ID__c)) {
            if (rah.FEC_Updated_User_Queue_ID__c == String.valueOf(queueId)) {
                return true;
            }
        }
        return queueTextMatches(rah.FEC_Updated_User_Queue__c, queueLabel);
    }

    private static String resolveQueueLabelForProfile(String profile) {
        return PROFILE_TO_LABEL.get(profile);
    }

    private static Datetime resolvePrimaryAnchorDatetime(SlaEligibilityContext ctx) {
        Datetime primary = null;
        if (ctx.profileToAnchor == null) {
            return null;
        }
        for (String profile : ctx.activeProfiles) {
            Datetime anchor = ctx.profileToAnchor.get(profile);
            if (anchor == null) {
                continue;
            }
            if (primary == null || anchor < primary) {
                primary = anchor;
            }
        }
        return primary;
    }

    private static Boolean isCaseNotificationSlotEmpty(Case c, Integer slot) {
        if (c == null || slot == null) {
            return true;
        }
        if (slot == 1) {
            return c.FEC_SLA_Notification_1__c == null;
        }
        if (slot == 2) {
            return c.FEC_SLA_Notification_2__c == null;
        }
        if (slot == 3) {
            return c.FEC_SLA_Notification_3__c == null;
        }
        return true;
    }

    private static Boolean queueTextMatches(String queueText, String queueLabel) {
        return String.isNotBlank(queueText)
            && String.isNotBlank(queueLabel)
            && queueText.contains(queueLabel);
    }

    private static Boolean isPendingStatus(String status) {
        if (String.isBlank(status)) {
            return false;
        }
        if (status == FEC_ConstantCommon.CASE_STATUS_PENDING) {
            return true;
        }
        return status.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX)
            || status.startsWith('Pending -');
    }

    private static Boolean isQueueOwner(Id ownerId) {
        if (ownerId == null) {
            return false;
        }
        ensureAllQueuesLoaded();
        return allQueueOwnerIds.contains(ownerId);
    }

    private static String resolveProfileFromOwnerId(Id ownerId) {
        ensureSlaQueuesLoaded();
        for (String devName : DEV_NAME_TO_PROFILE.keySet()) {
            if (slaQueueIdByDevName.get(devName) == ownerId) {
                return DEV_NAME_TO_PROFILE.get(devName);
            }
        }
        return null;
    }

    private static String resolveQueueLabelFromOwnerId(Id ownerId) {
        ensureSlaQueuesLoaded();
        for (String label : LABEL_TO_PROFILE.keySet()) {
            if (slaQueueIdByLabel.get(label) == ownerId) {
                return label;
            }
        }
        return null;
    }

    private static Id resolveQueueIdByLabel(String queueLabel) {
        ensureSlaQueuesLoaded();
        return slaQueueIdByLabel.get(queueLabel);
    }

    private static void ensureSlaQueuesLoaded() {
        if (slaOwnerQueueIds != null) {
            return;
        }
        slaOwnerQueueIds = new Set<Id>();
        slaQueueIdByDevName = new Map<String, Id>();
        slaQueueIdByLabel = new Map<String, Id>();
        for (Group g : [
            SELECT Id, DeveloperName, Name
            FROM Group
            WHERE Type = 'Queue'
              AND DeveloperName IN :DEV_NAME_TO_PROFILE.keySet()
        ]) {
            slaOwnerQueueIds.add(g.Id);
            slaQueueIdByDevName.put(g.DeveloperName, g.Id);
            String profile = DEV_NAME_TO_PROFILE.get(g.DeveloperName);
            for (String label : LABEL_TO_PROFILE.keySet()) {
                if (LABEL_TO_PROFILE.get(label) == profile) {
                    slaQueueIdByLabel.put(label, g.Id);
                }
            }
        }
    }

    private static void ensureAllQueuesLoaded() {
        if (allQueueOwnerIds != null) {
            return;
        }
        allQueueOwnerIds = new Set<Id>();
        for (Group g : [SELECT Id FROM Group WHERE Type = 'Queue']) {
            allQueueOwnerIds.add(g.Id);
        }
    }

    /**
     * UAT: chẩn đoán vì sao Case chưa stamp FEC_SLA_Notification_* (chạy Anonymous).
     */
    public static String diagnoseCase(Id caseId) {
        if (caseId == null) {
            return 'caseId null';
        }
        List<Case> rows = [
            SELECT Id, OwnerId, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return 'Case not found: ' + caseId;
        }
        Case c = rows[0];
        List<String> lines = new List<String>();
        lines.add('CaseId=' + c.Id);
        lines.add('FEC_Case_Status__c=' + c.FEC_Case_Status__c);
        lines.add('FEC_Team__c=' + c.FEC_Team__c + ' teamOk=' + teamContainsDsOrTs(c.FEC_Team__c));
        lines.add('OwnerId=' + c.OwnerId + ' isQueue=' + isQueueOwner(c.OwnerId));
        lines.add('Category=' + (c.FEC_Category__r != null ? c.FEC_Category__r.Name : null));
        lines.add('AssignmentCount=' + c.FEC_Assignment_Count__c);
        lines.add('AssignmentUsers=' + c.FEC_Assignment_Users__c);
        lines.add('SlaQueueIdsLoaded=' + getSlaOwnerQueueIds().size());
        lines.add('matchesTh1=' + matchesTh1(c) + ' matchesTh2=' + matchesTh2(c));
        lines.add('meetsCommon=' + meetsCommonCriteria(c));
        lines.add('testThresholds=' + isOneMinuteTestThresholdsEnabled());

        SlaEligibilityContext ctx = evaluateEligibility(c);
        lines.add('eligible=' + ctx.isEligible + ' scenario=' + ctx.scenario);
        lines.add('activeProfiles=' + String.join(ctx.activeProfiles, ';'));

        Map<Id, SlaEligibilityContext> mapCtx = new Map<Id, SlaEligibilityContext>{ caseId => ctx };
        bulkResolveAnchorsPerProfile(mapCtx);
        lines.add('anchorDatetime=' + ctx.anchorDatetime);
        lines.add(
            'unionRecipientCount=' + resolveRecipientUserIdsUnion(ctx.activeProfiles).size()
        );

        Datetime nowDt = System.now();
        for (String profile : ctx.activeProfiles) {
            Datetime anchor = ctx.profileToAnchor != null
                ? ctx.profileToAnchor.get(profile)
                : null;
            Long elapsed = anchor != null ? getElapsedMs(anchor, nowDt) : null;
            lines.add(
                'profile=' + profile
                    + ' anchor=' + anchor
                    + ' elapsedMs=' + elapsed
                    + ' profileDueSlot='
                    + (elapsed != null ? String.valueOf(getProfileDueSlot(elapsed, profile)) : 'null')
            );
        }

        Integer nextSlot = resolveNextCaseSlotToStamp(
            c,
            ctx.activeProfiles,
            ctx.profileToAnchor,
            nowDt
        );
        lines.add('nextCaseSlotToStamp=' + nextSlot);

        Integer rahCount = [
            SELECT COUNT()
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseId AND FEC_Routing_Action__c = :ROUTE_TO
        ];
        lines.add('rahRouteToCount=' + rahCount);
        return String.join(lines, '\n');
    }

    private static Integer getProfileDueSlot(Long elapsedMs, String queueProfile) {
        if (elapsedMs == null || String.isBlank(queueProfile)) {
            return null;
        }
        if (queueProfile == PROFILE_TELESALES || queueProfile == PROFILE_LG) {
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)) {
                return 2;
            }
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)) {
                return 1;
            }
            return null;
        }
        if (queueProfile == PROFILE_DIRECT_SALES || queueProfile == PROFILE_POS_SALES) {
            if (elapsedMs >= thresholdMsForSlot(3, queueProfile)) {
                return 3;
            }
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)) {
                return 2;
            }
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)) {
                return 1;
            }
            return null;
        }
        return null;
    }

}
