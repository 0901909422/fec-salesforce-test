/**
 * Auto Hold Case: sau khi tạo Routing Action History, match NOC → Hold Case Config (Auto)
 * → gọi Mark NFU qua FEC_AutoHoldCaseApi.markNFU (retry tối đa 3 lần)
 * → cập nhật Case (+ FEC_NFU_Description_Result__c khi field đã deploy).
 */
public with sharing class FEC_AutoHoldCaseService {
    public static final String RESULT_PENDING = 'PENDING';
    public static final String RESULT_ALREADY_MARKED = 'ALREADY_MARKED';
    public static final String RESULT_SUCCESS = 'SUCCESS';
    public static final String RESULT_ERROR = 'ERROR';

    private static final Integer MAX_ATTEMPTS = 3;
    private static final String NFU_STATUS_YES = 'Yes';
    private static final String HOLD_CASE_TYPE_AUTO = 'Auto';

    public static void enqueueAfterRoutingHistory(Id routingHistoryId) {
        if (routingHistoryId == null) {
            return;
        }
        System.enqueueJob(new FEC_AutoHoldCaseQueueable(routingHistoryId));
    }

    /**
     * Submit không qua Routing Action (creation stage / không có dropdown routing):
     * tạo Routing Action History tối thiểu rồi enqueue Auto Hold Case.
     */
    public static void enqueueAfterCaseSubmit(Id caseId, String currentStatusBeforeSubmit) {
        if (caseId == null) {
            return;
        }

        List<Case> caseRows = [
            SELECT FEC_Final_Status__c, FEC_Stage_Name__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            return;
        }

        Case endCase = caseRows[0];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseId,
            FEC_Routing_Action__c = 'Submit',
            FEC_Current_Status__c = currentStatusBeforeSubmit,
            FEC_Changed_Status__c = endCase.FEC_Final_Status__c,
            FEC_Stage_Name__c = endCase.FEC_Stage_Name__c
        );
        Database.insert(history, AccessLevel.SYSTEM_MODE);
        enqueueAfterRoutingHistory(history.Id);
    }

    public static void processAutoHoldCase(Id routingHistoryId) {
        if (routingHistoryId == null) {
            return;
        }

        List<FEC_Routing_Action_History__c> histories = [
            SELECT
                Id,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Case__c,
                FEC_Case__r.FEC_Product_Type__c,
                FEC_Case__r.FEC_Category__c,
                FEC_Case__r.FEC_SubCategory__c,
                FEC_Case__r.FEC_SubCode__c,
                FEC_Case__r.FEC_Current_Case_Stage__c,
                FEC_Case__r.FEC_Account_Contract_Number_Text__c
            FROM FEC_Routing_Action_History__c
            WHERE Id = :routingHistoryId
            LIMIT 1
        ];
        if (histories.isEmpty() || histories[0].FEC_Case__c == null) {
            return;
        }

        FEC_Routing_Action_History__c history = histories[0];
        Case relatedCase = history.FEC_Case__r;
        if (
            relatedCase.FEC_Product_Type__c == null ||
            relatedCase.FEC_Category__c == null ||
            relatedCase.FEC_SubCategory__c == null
        ) {
            return;
        }

        Id nocId = resolveNatureOfCaseId(relatedCase);
        if (nocId == null) {
            return;
        }

        FEC_Hold_Case_Config__c config = findMatchingAutoConfig(
            nocId,
            relatedCase.FEC_Current_Case_Stage__c,
            history.FEC_Current_Status__c,
            history.FEC_Changed_Status__c
        );
        if (config == null || String.isBlank(config.FEC_NFU_Code__c)) {
            return;
        }

        String nfuCode = config.FEC_NFU_Code__c.trim();
        FEC_Hold_Case__c holdCaseMaster = findHoldCaseMaster(nfuCode);
        if (holdCaseMaster == null) {
            return;
        }

        Id caseId = history.FEC_Case__c;
        markCasePending(caseId);

        String userEmail = [
            SELECT Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].Email;

        FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();
        req.ContractNumber = relatedCase.FEC_Account_Contract_Number_Text__c;
        req.NFUReasonCode = nfuCode;
        req.NFUUpdatedBy = userEmail;

        FEC_MarkNFU.MarkNFUResult lastResult;
        for (Integer attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            lastResult = FEC_AutoHoldCaseApi.markNFU(req);

            if (lastResult != null && lastResult.code == FEC_ConstantCommon.SUCCESS_CODE_203) {
                updateCaseAfterApi(
                    caseId,
                    RESULT_ALREADY_MARKED,
                    nfuCode,
                    holdCaseMaster.FEC_NFU_Reason_VN__c,
                    parseNfuDateTime(lastResult.nfuStartDate),
                    parseNfuDateTime(lastResult.nfuTillDate),
                    config,
                    System.Label.FEC_STOP_IMPACT_ALREADY_MARKED_MSG
                );
                return;
            }

            if (lastResult != null && lastResult.success) {
                updateCaseAfterApi(
                    caseId,
                    RESULT_SUCCESS,
                    nfuCode,
                    holdCaseMaster.FEC_NFU_Reason_VN__c,
                    DateTime.now(),
                    parseNfuDateTime(lastResult.nfuTillDate),
                    config,
                    System.Label.FEC_MSG_SUCCESS
                );
                return;
            }
        }

        updateCaseAfterApi(
            caseId,
            RESULT_ERROR,
            null,
            null,
            null,
            null,
            null,
            System.Label.FEC_MSG_ERROR
        );
    }

    @TestVisible
    private static Id resolveNatureOfCaseId(Case c) {
        List<FEC_Nature_of_Case__c> nocs;
        if (c.FEC_SubCode__c != null) {
            nocs = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
                  AND FEC_Category__c = :c.FEC_Category__c
                  AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
                  AND FEC_Sub_Code__c = :c.FEC_SubCode__c
                ORDER BY LastModifiedDate DESC
            ];
        } else {
            nocs = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
                  AND FEC_Category__c = :c.FEC_Category__c
                  AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
                  AND FEC_Sub_Code__c = NULL
                ORDER BY LastModifiedDate DESC
            ];
        }
        if (nocs.isEmpty()) {
            return null;
        }
        if (nocs.size() == 1) {
            return nocs[0].Id;
        }

        Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocs).keySet();
        List<FEC_Hold_Case_Config__c> configs = [
            SELECT FEC_Nature_of_Cases__c
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND Hold_Case_Type__c = :HOLD_CASE_TYPE_AUTO
              AND FEC_Active__c = TRUE
              AND FEC_Case_Stage__c = :c.FEC_Current_Case_Stage__c
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].FEC_Nature_of_Cases__c != null) {
            return configs[0].FEC_Nature_of_Cases__c;
        }
        return nocs[0].Id;
    }

    @TestVisible
    private static FEC_Hold_Case_Config__c findMatchingAutoConfig(
        Id nocId,
        Id caseStageId,
        String currentStatus,
        String changedStatus
    ) {
        if (nocId == null || caseStageId == null) {
            return null;
        }

        List<FEC_Hold_Case_Config__c> configs = [
            SELECT
                Id,
                FEC_NFU_Code__c,
                FEC_Case_Stage__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Auto_Hold_Duration_Minutes__c,
                FEC_Auto_Hold_Release_Case_Status__c
            FROM FEC_Hold_Case_Config__c
            WHERE (FEC_Nature_of_Cases__c = :nocId OR FEC_Nature_of_Cases__c = NULL)
              AND Hold_Case_Type__c = :HOLD_CASE_TYPE_AUTO
              AND FEC_Active__c = TRUE
              AND FEC_Case_Stage__c = :caseStageId
        ];

        for (FEC_Hold_Case_Config__c cfg : configs) {
            if (
                statusConfigContains(cfg.FEC_Current_Status__c, currentStatus) &&
                statusConfigContains(cfg.FEC_Changed_Status__c, changedStatus)
            ) {
                return cfg;
            }
        }
        return null;
    }

    @TestVisible
    private static Boolean statusConfigContains(String configValue, String historyValue) {
        if (String.isBlank(configValue) || String.isBlank(historyValue)) {
            return false;
        }
        String normalizedHistory = normalizeStatusKey(historyValue);
        if (String.isBlank(normalizedHistory)) {
            return false;
        }
        for (String token : configValue.split(',')) {
            if (normalizeStatusKey(token) == normalizedHistory) {
                return true;
            }
        }
        return normalizeStatusKey(configValue).contains(normalizedHistory);
    }

    @TestVisible
    private static String normalizeStatusKey(String raw) {
        if (String.isBlank(raw)) {
            return '';
        }
        return raw.trim()
            .replaceAll(FEC_ConstantCommon.PATTERN_CLEAN_TEXT, '')
            .toLowerCase();
    }

    @TestVisible
    private static FEC_Hold_Case__c findHoldCaseMaster(String nfuCode) {
        List<FEC_Hold_Case__c> rows = [
            SELECT FEC_NFU_Code__c, FEC_NFU_Reason_VN__c
            FROM FEC_Hold_Case__c
            WHERE FEC_NFU_Code__c = :nfuCode
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static void markCasePending(Id caseId) {
        Database.update(
            new Case(
                Id = caseId,
                FEC_NFU_Description_Result__c = RESULT_PENDING
            ),
            AccessLevel.SYSTEM_MODE
        );
    }

    @TestVisible
    private static void updateCaseAfterApi(
        Id caseId,
        String resultType,
        String nfuCode,
        String nfuReason,
        DateTime startedDate,
        DateTime expiryDate,
        FEC_Hold_Case_Config__c matchedHoldConfig,
        String collectionsResponse
    ) {
        Case patch = new Case(
            Id = caseId,
            FEC_NFU_Description_Result__c = resultType
        );

        if (String.isNotBlank(collectionsResponse)) {
            patch.FEC_Collections_Response__c = collectionsResponse;
        }

        if (resultType == RESULT_ERROR) {
            Database.update(patch, AccessLevel.SYSTEM_MODE);
            return;
        }

        patch.FEC_NFU_Status__c = NFU_STATUS_YES;
        patch.FEC_NFU_Code__c = nfuCode;
        patch.FEC_NFU_Reason__c = nfuReason;
        patch.FEC_NFU_Started_Date__c = startedDate;
        patch.FEC_NFU_Expiry_Date__c = expiryDate;
        Database.SaveResult sr = Database.update(patch, AccessLevel.SYSTEM_MODE);
        if (sr.isSuccess() && matchedHoldConfig != null) {
            FEC_AutoHoldCaseHistoryService.createFromSuccessfulAutoHold(
                caseId,
                matchedHoldConfig,
                startedDate,
                expiryDate
            );
        }
    }

    @TestVisible
    private static DateTime parseNfuDateTime(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            String normalized = raw.replace('T', ' ').replace('Z', '');
            Integer dotIdx = normalized.indexOf('.');
            if (dotIdx > 0) {
                normalized = normalized.substring(0, dotIdx);
            }
            if (normalized.length() > 19) {
                normalized = normalized.substring(0, 19);
            }
            return DateTime.valueOfGmt(normalized);
        } catch (Exception ex) {
            System.debug('[FEC_AutoHoldCaseService] parseNfuDateTime failed: ' + ex.getMessage());
            return null;
        }
    }
}
