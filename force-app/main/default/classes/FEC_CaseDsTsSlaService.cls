/**
 * SLA cảnh báo DS/TS: eligibility, anchor RAH, business hours, recipients, stamp notification fields.
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
    private static final String FEC_BUSINESS_HOURS_NAME = 'FEC Business Hours';

    private static final Long MS_1MIN = 60L * 1000L;
    private static final Long MS_2MIN = 2L * MS_1MIN;
    private static final Long MS_3MIN = 3L * MS_1MIN;

    private static final Long MS_2H = 2L * 60L * 60L * 1000L;
    private static final Long MS_4H = 4L * 60L * 60L * 1000L;
    private static final Long MS_6H = 6L * 60L * 60L * 1000L;
    private static final Long MS_8H = 8L * 60L * 60L * 1000L;

    /**
     * Ngưỡng production: giờ làm việc (2h/4h hoặc 4h/6h/8h).
     * Ngưỡng UAT: 1/2/3 phút (bước tương ứng mỗi 2h).
     * Bật UAT: Custom Label FEC_SLA_DS_TS_Use_Test_Thresholds = true (hoặc setUseOneMinuteTestThresholds trong Anonymous).
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
    private static Id cachedBusinessHoursId;
    private static Boolean businessHoursLookupDone = false;

    public class SlaEligibilityContext {
        public Boolean isEligible = false;
        public String scenario;
        public Id notifyQueueId;
        public String queueProfile;
        public Datetime anchorDatetime;
        public String matchedQueueLabel;
    }

    public static SlaEligibilityContext evaluateEligibility(Case c) {
        SlaEligibilityContext ctx = new SlaEligibilityContext();
        if (c == null || !meetsCommonCriteria(c)) {
            return ctx;
        }
        if (matchesTh1(c)) {
            ctx.isEligible = true;
            ctx.scenario = SCENARIO_TH1;
            ctx.notifyQueueId = c.OwnerId;
            ctx.queueProfile = resolveProfileFromOwnerId(c.OwnerId);
            ctx.matchedQueueLabel = resolveQueueLabelFromOwnerId(c.OwnerId);
            return ctx;
        }
        if (matchesTh2(c)) {
            ctx.isEligible = true;
            ctx.scenario = SCENARIO_TH2;
            ctx.matchedQueueLabel = resolveMatchedQueueLabel(c.FEC_Assignment_Users__c);
            ctx.queueProfile = LABEL_TO_PROFILE.get(ctx.matchedQueueLabel);
            ctx.notifyQueueId = resolveQueueIdByLabel(ctx.matchedQueueLabel);
            return ctx;
        }
        return ctx;
    }

    public static Boolean meetsCommonCriteria(Case c) {
        if (c == null) {
            return false;
        }
        if (!isPendingStatus(c.FEC_Case_Status__c)) {
            return false;
        }
        if (!isQueueOwner(c.OwnerId)) {
            return false;
        }
        if (!teamContainsDsOrTs(c.FEC_Team__c)) {
            return false;
        }
        String categoryName = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
        return String.isNotBlank(categoryName) && CATEGORY_NAMES.contains(categoryName);
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
        return String.isNotBlank(resolveMatchedQueueLabel(c.FEC_Assignment_Users__c));
    }

    public static Boolean teamContainsDsOrTs(String fecTeam) {
        if (String.isBlank(fecTeam)) {
            return false;
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

    public static String resolveMatchedQueueLabel(String assignmentUsers) {
        if (String.isBlank(assignmentUsers)) {
            return null;
        }
        for (String label : QUEUE_LABELS_ORDERED) {
            if (assignmentUsers.contains(label)) {
                return label;
            }
        }
        return null;
    }

    public static void bulkResolveAnchors(Map<Id, SlaEligibilityContext> contextsByCaseId) {
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
                   FEC_Routing_Action__c, FEC_Assignment__c, FEC_Updated_User_Queue__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c IN :caseIds
              AND FEC_Routing_Action__c = :ROUTE_TO
            ORDER BY CreatedDate ASC
        ];

        Map<Id, Datetime> anchorByCase = new Map<Id, Datetime>();
        for (FEC_Routing_Action_History__c rah : histories) {
            SlaEligibilityContext ctx = contextsByCaseId.get(rah.FEC_Case__c);
            if (ctx == null || !ctx.isEligible || !rahMatchesScenario(rah, ctx)) {
                continue;
            }
            if (!anchorByCase.containsKey(rah.FEC_Case__c)) {
                anchorByCase.put(rah.FEC_Case__c, rah.CreatedDate);
            }
        }

        for (Id caseId : anchorByCase.keySet()) {
            SlaEligibilityContext ctx = contextsByCaseId.get(caseId);
            if (ctx != null) {
                ctx.anchorDatetime = anchorByCase.get(caseId);
            }
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

    public static Long getElapsedBusinessMs(Datetime anchorCreatedDate, Datetime nowDt) {
        if (anchorCreatedDate == null || nowDt == null) {
            return null;
        }
        Id bhId = resolveBusinessHoursId();
        if (bhId == null) {
            return null;
        }
        return BusinessHours.diff(bhId, anchorCreatedDate, nowDt);
    }

    public static Integer getDueNotificationSlot(Case c, Long elapsedMs, String queueProfile) {
        if (c == null || elapsedMs == null || String.isBlank(queueProfile)) {
            return null;
        }
        if (queueProfile == PROFILE_TELESALES || queueProfile == PROFILE_LG) {
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)
                && c.FEC_SLA_Notification_2__c == null) {
                return 2;
            }
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)
                && c.FEC_SLA_Notification_1__c == null) {
                return 1;
            }
            return null;
        }
        if (queueProfile == PROFILE_DIRECT_SALES || queueProfile == PROFILE_POS_SALES) {
            if (elapsedMs >= thresholdMsForSlot(3, queueProfile)
                && c.FEC_SLA_Notification_3__c == null) {
                return 3;
            }
            if (elapsedMs >= thresholdMsForSlot(2, queueProfile)
                && c.FEC_SLA_Notification_2__c == null) {
                return 2;
            }
            if (elapsedMs >= thresholdMsForSlot(1, queueProfile)
                && c.FEC_SLA_Notification_1__c == null) {
                return 1;
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
        if (ctx == null || !ctx.isEligible || ctx.anchorDatetime == null) {
            if (needsClearNotifications(row)) {
                Case clearPatch = new Case(Id = row.Id);
                clearPatch.FEC_SLA_Notification_1__c = null;
                clearPatch.FEC_SLA_Notification_2__c = null;
                clearPatch.FEC_SLA_Notification_3__c = null;
                return clearPatch;
            }
            return null;
        }

        Long elapsedMs = getElapsedBusinessMs(ctx.anchorDatetime, nowDt);
        Integer slot = getDueNotificationSlot(row, elapsedMs, ctx.queueProfile);
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

    public static List<String> parseEmailsFromLabelValue(String labelValue) {
        List<String> emails = new List<String>();
        if (String.isBlank(labelValue)) {
            return emails;
        }
        String normalized = labelValue.replace(',', ';');
        for (String part : normalized.split(';')) {
            String email = part != null ? part.trim() : '';
            if (String.isNotBlank(email)) {
                emails.add(email);
            }
        }
        return emails;
    }

    public static String getRecipientLabelApiName(String queueProfile) {
        return PROFILE_TO_RECIPIENT_LABEL.get(queueProfile);
    }

    public static List<String> getRecipientEmailsForProfile(String queueProfile) {
        if (queueProfile == PROFILE_TELESALES) {
            return parseEmailsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Telesales);
        }
        if (queueProfile == PROFILE_LG) {
            return parseEmailsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_LG);
        }
        if (queueProfile == PROFILE_DIRECT_SALES) {
            return parseEmailsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Direct_Sales);
        }
        if (queueProfile == PROFILE_POS_SALES) {
            return parseEmailsFromLabelValue(Label.FEC_SLA_DS_TS_Recipient_Pos_Sales);
        }
        return new List<String>();
    }

    public static Set<String> resolveRecipientUserIds(SlaEligibilityContext ctx) {
        if (ctx == null || String.isBlank(ctx.queueProfile)) {
            return new Set<String>();
        }
        return resolveRecipientUserIdsByProfile(ctx.queueProfile);
    }

    public static Set<String> resolveRecipientUserIdsByProfile(String queueProfile) {
        List<String> emails = getRecipientEmailsForProfile(queueProfile);
        if (emails.isEmpty()) {
            return new Set<String>();
        }
        Set<String> userIds = new Set<String>();
        for (User u : [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND Email IN :emails
        ]) {
            userIds.add(u.Id);
        }
        return userIds;
    }

    public static String getApproachingTitle(Case c) {
        return String.format(
            Label.FEC_MSG_SLA_Notif_Title_Approaching,
            new List<String>{ c.FEC_ID_Search__c }
        );
    }

    public static String getApproachingBody(Case c) {
        return String.format(
            Label.FEC_MSG_SLA_Notif_Body_Approaching,
            new List<String>{ c.FEC_ID_Search__c }
        );
    }

    private static Boolean rahMatchesScenario(FEC_Routing_Action_History__c rah, SlaEligibilityContext ctx) {
        if (rah == null || ctx == null || String.isBlank(ctx.matchedQueueLabel)) {
            return false;
        }
        if (!queueTextMatches(rah.FEC_Updated_User_Queue__c, ctx.matchedQueueLabel)) {
            return false;
        }
        if (ctx.scenario == SCENARIO_TH1) {
            return rah.FEC_Routing_Action_Type__c == RAH_TYPE_CASE
                && rah.FEC_Assignment__c == null;
        }
        return rah.FEC_Assignment__c != null;
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

    private static Id resolveBusinessHoursId() {
        if (businessHoursLookupDone) {
            return cachedBusinessHoursId;
        }
        businessHoursLookupDone = true;
        List<BusinessHours> named = [
            SELECT Id
            FROM BusinessHours
            WHERE Name = :FEC_BUSINESS_HOURS_NAME AND IsActive = TRUE
            LIMIT 1
        ];
        if (!named.isEmpty()) {
            cachedBusinessHoursId = named[0].Id;
            return cachedBusinessHoursId;
        }
        List<BusinessHours> def = [
            SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE LIMIT 1
        ];
        if (!def.isEmpty()) {
            cachedBusinessHoursId = def[0].Id;
        }
        return cachedBusinessHoursId;
    }
}
