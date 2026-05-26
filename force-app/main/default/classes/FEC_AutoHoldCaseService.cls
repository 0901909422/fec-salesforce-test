/**
 * Auto Hold Case: sau khi tạo Routing Action History, match NOC → Hold Case Config (Auto)
 * → gọi Mark NFU qua FEC_AutoHoldCaseApi.markNFU (retry tối đa 3 lần)
 * → cập nhật Case (+ FEC_NFU_Description_Result__c khi field đã deploy).
 */
public without sharing class FEC_AutoHoldCaseService {
    public static final String RESULT_PENDING = 'PENDING';
    public static final String RESULT_ALREADY_MARKED = 'ALREADY_MARKED';
    public static final String RESULT_SUCCESS = 'SUCCESS';
    public static final String RESULT_ERROR = 'ERROR';

    private static final Integer MAX_ATTEMPTS = 3;
    private static final Integer MAX_USER_HOLD_CASE_RETRIES = 3;
    private static final String NFU_STATUS_YES = 'Yes';
    private static final String HOLD_CASE_TYPE_AUTO = 'Auto';
    private static final String ROUTING_ACTION_RESOLVE = 'Resolve';
    private static final String ROUTING_ACTION_SUBMIT = 'Submit';
    private static final String ROUTING_ACTION_HOLD_CASE = 'Hold Case';
    /** Prefix FEC_Routing_Action_History__c.FEC_Description__c — lưu NOC Stage 1 cho retry Hold Case. */
    private static final String HOLD_CASE_BASELINE_PREFIX = 'HC_BL:';

    public static void enqueueAfterRoutingHistory(Id routingHistoryId) {
        if (routingHistoryId == null) {
            return;
        }
        if (FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress()) {
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
            SELECT
                Status,
                FEC_Team__c,
                FEC_Stage_Name__c,
                FEC_Current_Case_Stage__c
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
            FEC_Routing_Action__c = ROUTING_ACTION_SUBMIT,
            FEC_Current_Status__c = currentStatusBeforeSubmit,
            FEC_Changed_Status__c = FEC_CaseBusinessService.routingHistoryStatusSnapshot(
                endCase
            ),
            FEC_Stage_Name__c = endCase.FEC_Stage_Name__c,
            FEC_Previous_Stage__c = endCase.FEC_Current_Case_Stage__c
        );
        Database.insert(history, AccessLevel.SYSTEM_MODE);
        enqueueAfterRoutingHistory(history.Id);
    }

    /**
     * Stage 2+ — user bấm Hold Case sau Auto Hold ERROR: enqueue lại Auto Hold tại stage hiện tại
     * (cùng luồng Queueable + FEC_AutoHoldCaseApi như Submit Stage 1).
     */
    @AuraEnabled
    public static Integer getHoldCaseUserRetryCount(Id caseId) {
        Integer count = readHoldCaseProcessActionCount(caseId);
        debugHoldCaseRetryState(caseId, 'getHoldCaseUserRetryCount', count, null);
        return count;
    }

    /** Đã retry Hold Case Auto tối đa — đọc Case.FEC_Process_Action_Count__c (giống Pin Reset / Address Update). */
    public static Boolean isMaxUserHoldCaseRetriesReached(Id caseId) {
        Integer count = readHoldCaseProcessActionCount(caseId);
        Boolean maxReached = count >= MAX_USER_HOLD_CASE_RETRIES;
        debugHoldCaseRetryState(
            caseId,
            'isMaxUserHoldCaseRetriesReached',
            count,
            'maxReached=' + maxReached
        );
        return maxReached;
    }

    @AuraEnabled
    public static void enqueueAutoHoldRetryForCase(
        Id caseId,
        Integer attemptNumber,
        Id stage1ProductTypeId,
        Id stage1CategoryId,
        Id stage1SubCategoryId,
        Id stage1SubCodeId
    ) {
        if (caseId == null) {
            return;
        }
        if (isMaxUserHoldCaseRetriesReached(caseId)) {
            debugHoldCaseRetryState(
                caseId,
                'enqueueAutoHoldRetryForCase:maxReached',
                readHoldCaseProcessActionCount(caseId),
                'attemptNumber=' + attemptNumber
            );
            return;
        }
        if (FEC_BatchCaseHandlingImportService.isBatchImportApplyInProgress()) {
            System.debug(
                LoggingLevel.WARN,
                '[FEC_AutoHoldCaseService] enqueueAutoHoldRetryForCase skipped batch import caseId=' +
                    caseId
            );
            return;
        }
        debugHoldCaseRetryState(
            caseId,
            'enqueueAutoHoldRetryForCase:before',
            readHoldCaseProcessActionCount(caseId),
            'attemptNumber=' + attemptNumber
        );

        List<Case> caseRows = [
            SELECT
                Status,
                FEC_Team__c,
                FEC_Stage_Name__c,
                FEC_Current_Case_Stage__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            return;
        }

        Case c = caseRows[0];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseId,
            FEC_Routing_Action__c = ROUTING_ACTION_HOLD_CASE,
            FEC_Current_Status__c = c.Status,
            FEC_Changed_Status__c = FEC_CaseBusinessService.routingHistoryStatusSnapshot(
                c
            ),
            FEC_Stage_Name__c = c.FEC_Stage_Name__c,
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c,
            FEC_Description__c = serializeHoldCaseStage1Baseline(
                stage1ProductTypeId,
                stage1CategoryId,
                stage1SubCategoryId,
                stage1SubCodeId
            )
        );
        Database.insert(history, AccessLevel.SYSTEM_MODE);
        debugHoldCaseRetryState(
            caseId,
            'enqueueAutoHoldRetryForCase:afterInsert',
            readHoldCaseProcessActionCount(caseId),
            'historyId=' + history.Id + ' attemptNumber=' + attemptNumber
        );
        enqueueAfterRoutingHistory(history.Id);
    }

    /** Cập nhật Changed Status sau Route rồi enqueue Auto Hold (GSR / Route to). */
    public static void syncChangedStatusAndEnqueue(Id routingHistoryId) {
        if (routingHistoryId == null) {
            return;
        }
        List<FEC_Routing_Action_History__c> rows = [
            SELECT Id, FEC_Case__c, FEC_Changed_Status__c
            FROM FEC_Routing_Action_History__c
            WHERE Id = :routingHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].FEC_Case__c == null) {
            return;
        }
        List<Case> endCases = [
            SELECT Status, FEC_Team__c
            FROM Case
            WHERE Id = :rows[0].FEC_Case__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!endCases.isEmpty()) {
            String changedStatus = FEC_CaseBusinessService.routingHistoryStatusSnapshot(
                endCases[0]
            );
            if (rows[0].FEC_Changed_Status__c != changedStatus) {
                FEC_CaseBusinessService.patchRoutingHistoryChangedStatus(
                    routingHistoryId,
                    changedStatus
                );
            }
        }
        enqueueAfterRoutingHistory(routingHistoryId);
    }

    /** Enqueue Auto Hold theo Routing History mới nhất của Case (luồng GSR tạo nhiều history). */
    public static void syncChangedStatusAndEnqueueForCase(Id caseId) {
        if (caseId == null) {
            return;
        }
        List<FEC_Routing_Action_History__c> rows = [
            SELECT Id
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            syncChangedStatusAndEnqueue(rows[0].Id);
        }
    }

    public static void processAutoHoldCase(Id routingHistoryId) {
        if (routingHistoryId == null) {
            return;
        }

        List<FEC_Routing_Action_History__c> histories = [
            SELECT
                Id,
                FEC_Routing_Action__c,
                FEC_Description__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Previous_Stage__c,
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
        Id caseId = history.FEC_Case__c;

        Case relatedCase = history.FEC_Case__r;
        HoldCaseStage1Baseline stage1Baseline = parseHoldCaseStage1Baseline(
            history.FEC_Description__c
        );
        Boolean useStage1Baseline =
            ROUTING_ACTION_HOLD_CASE.equalsIgnoreCase(history.FEC_Routing_Action__c) &&
            stage1Baseline != null &&
            stage1Baseline.hasRequiredNocKeys();

        if (!useStage1Baseline) {
            if (
                relatedCase.FEC_Product_Type__c == null ||
                relatedCase.FEC_Category__c == null ||
                relatedCase.FEC_SubCategory__c == null
            ) {
                completeHoldCaseRetryFailure(history, caseId);
                return;
            }
        }

        Id stageIdForConfig;
        Id nocId;
        if (useStage1Baseline) {
            nocId = resolveNatureOfCaseIdFromNocKeys(
                stage1Baseline.productTypeId,
                stage1Baseline.categoryId,
                stage1Baseline.subCategoryId,
                stage1Baseline.subCodeId,
                relatedCase.FEC_Current_Case_Stage__c
            );
            stageIdForConfig = resolveStage1IdForNature(
                nocId,
                relatedCase.FEC_Current_Case_Stage__c
            );
            if (stageIdForConfig == null) {
                stageIdForConfig = relatedCase.FEC_Current_Case_Stage__c;
            }
        } else {
            stageIdForConfig = resolveStageIdForAutoHoldConfig(history, relatedCase);
            nocId = resolveNatureOfCaseId(relatedCase, stageIdForConfig);
        }

        if (nocId == null) {
            completeHoldCaseRetryFailure(history, caseId);
            return;
        }

        // Retry Hold Case Stage 2: match config giống Submit Stage 1 (cùng NFUReasonCode).
        String configCurrentStatus = history.FEC_Current_Status__c;
        String configChangedStatus = history.FEC_Changed_Status__c;
        if (useStage1Baseline) {
            FEC_Routing_Action_History__c submitHistory = findFirstSubmitRoutingHistory(
                caseId
            );
            if (submitHistory != null) {
                configCurrentStatus = submitHistory.FEC_Current_Status__c;
                configChangedStatus = submitHistory.FEC_Changed_Status__c;
                if (submitHistory.FEC_Previous_Stage__c != null) {
                    stageIdForConfig = submitHistory.FEC_Previous_Stage__c;
                }
            }
        }

        FEC_Hold_Case_Config__c config;
        if (ROUTING_ACTION_RESOLVE.equalsIgnoreCase(history.FEC_Routing_Action__c)) {
            config = findMatchingAutoConfigForResolve(
                nocId,
                history.FEC_Changed_Status__c
            );
            if (config == null) {
                config = findFirstAutoHoldConfigForStage(nocId);
            }
        }
        if (config == null) {
            config = findMatchingAutoConfig(
                nocId,
                configCurrentStatus,
                configChangedStatus
            );
        }
        if (
            config == null &&
            ROUTING_ACTION_HOLD_CASE.equalsIgnoreCase(history.FEC_Routing_Action__c)
        ) {
            config = findFirstAutoHoldConfigForStage(nocId);
        }
        if (config == null || String.isBlank(config.FEC_NFU_Code__c)) {
            completeHoldCaseRetryFailure(history, caseId);
            return;
        }

        String nfuCode = config.FEC_NFU_Code__c.trim();
        FEC_Hold_Case__c holdCaseMaster = findHoldCaseMaster(nfuCode);
        if (holdCaseMaster == null) {
            completeHoldCaseRetryFailure(history, caseId);
            return;
        }

        // Không DML trước callout — Salesforce: "uncommitted work pending" (Manual: API trước DML).
        // UI PENDING: fec_CaseBussiness.refreshAutoHoldCase() set holdCaseResultOverride = PENDING.

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
                    System.Label.FEC_STOP_IMPACT_ALREADY_MARKED_MSG,
                    history.FEC_Routing_Action__c
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
                    System.Label.FEC_MSG_SUCCESS,
                    history.FEC_Routing_Action__c
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
            System.Label.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY,
            history.FEC_Routing_Action__c
        );
    }

    /** Stage cho Auto config — Hold Case retry dùng stage hiện tại; Submit/Route ưu tiên Previous Stage. */
    @TestVisible
    private static Id resolveStageIdForAutoHoldConfig(
        FEC_Routing_Action_History__c history,
        Case relatedCase
    ) {
        if (
            history != null &&
            ROUTING_ACTION_HOLD_CASE.equalsIgnoreCase(history.FEC_Routing_Action__c)
        ) {
            return relatedCase?.FEC_Current_Case_Stage__c;
        }
        if (history?.FEC_Previous_Stage__c != null) {
            return history.FEC_Previous_Stage__c;
        }
        return relatedCase?.FEC_Current_Case_Stage__c;
    }

    @TestVisible
    private static Id resolveNatureOfCaseId(Case c) {
        return resolveNatureOfCaseId(c, c?.FEC_Current_Case_Stage__c);
    }

    @TestVisible
    private static Id resolveNatureOfCaseId(Case c, Id stageIdForConfig) {
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
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].FEC_Nature_of_Cases__c != null) {
            return configs[0].FEC_Nature_of_Cases__c;
        }
        return nocs[0].Id;
    }

    /**
     * Resolve submit: Case → Resolved-Completed; chỉ khớp Stage + Changed Status (không Current).
     * FEC_Hold_Case_Config__c.FEC_Changed_Status__c cần có Resolved-Completed (hoặc status resolved tương ứng).
     */
    @TestVisible
    private static FEC_Hold_Case_Config__c findMatchingAutoConfigForResolve(
        Id nocId,
        String changedStatus
    ) {
        if (nocId == null) {
            return null;
        }

        for (FEC_Hold_Case_Config__c cfg : queryAutoHoldConfigs(nocId)) {
            if (statusConfigContains(cfg.FEC_Changed_Status__c, changedStatus)) {
                return cfg;
            }
        }
        return null;
    }

    /** Resolve: NFU code Auto Hold đầu tiên theo NOC (config thường khai báo Stage 1) khi không khớp Changed = Resolved. */
    @TestVisible
    private static FEC_Hold_Case_Config__c findFirstAutoHoldConfigForStage(Id nocId) {
        if (nocId == null) {
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
              AND FEC_NFU_Code__c != NULL
            LIMIT 1
        ];
        return configs.isEmpty() ? null : configs[0];
    }

    @TestVisible
    private static FEC_Hold_Case_Config__c findMatchingAutoConfig(
        Id nocId,
        String currentStatus,
        String changedStatus
    ) {
        if (nocId == null) {
            return null;
        }

        List<FEC_Hold_Case_Config__c> configs = queryAutoHoldConfigs(nocId);

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

    /** Config Auto cho NOC — không lọc FEC_Case_Stage__c (đồng bộ FEC_HoldCaseStage2DisplayService). */
    private static List<FEC_Hold_Case_Config__c> queryAutoHoldConfigs(Id nocId) {
        return [
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
        ];
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

    /** Hold Case retry (Stage 2+): Queueable thoát sớm — cập nhật ERROR để UI không kẹt PENDING. */
    private static void completeHoldCaseRetryFailure(
        FEC_Routing_Action_History__c history,
        Id caseId
    ) {
        if (
            history == null ||
            caseId == null ||
            !ROUTING_ACTION_HOLD_CASE.equalsIgnoreCase(history.FEC_Routing_Action__c)
        ) {
            return;
        }
        updateCaseAfterApi(
            caseId,
            RESULT_ERROR,
            null,
            null,
            null,
            null,
            null,
            System.Label.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY,
            ROUTING_ACTION_HOLD_CASE
        );
    }

    /**
     * Debug đếm retry user Hold Case Auto — filter log: FEC_AutoHoldCaseService.
     * Level WARN để dễ thấy trong Debug Log khi trace nút ẩn sau click.
     */
    @TestVisible
    private static void debugHoldCaseRetryState(
        Id caseId,
        String source,
        Integer count,
        String extra
    ) {
        List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
        if (caseId != null) {
            histories = [
                SELECT Id, CreatedDate
                FROM FEC_Routing_Action_History__c
                WHERE FEC_Case__c = :caseId
                  AND FEC_Routing_Action__c = :ROUTING_ACTION_HOLD_CASE
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        }
        System.debug(
            LoggingLevel.WARN,
            '[FEC_AutoHoldCaseService] ' +
                source +
                ' caseId=' +
                caseId +
                ' holdCaseRetryCount=' +
                count +
                '/' +
                MAX_USER_HOLD_CASE_RETRIES +
                (String.isNotBlank(extra) ? ' ' + extra : '') +
                ' recentHoldCaseHistories=' +
                histories
        );
    }

    private class HoldCaseStage1Baseline {
        Id productTypeId;
        Id categoryId;
        Id subCategoryId;
        Id subCodeId;

        Boolean hasRequiredNocKeys() {
            return productTypeId != null &&
                categoryId != null &&
                subCategoryId != null;
        }
    }

    /** Routing History Submit đầu tiên — dùng status/stage giống lúc Auto Hold Stage 1. */
    @TestVisible
    private static FEC_Routing_Action_History__c findFirstSubmitRoutingHistory(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<FEC_Routing_Action_History__c> rows = [
            SELECT
                Id,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Previous_Stage__c
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseId
              AND FEC_Routing_Action__c = :ROUTING_ACTION_SUBMIT
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    @TestVisible
    private static String serializeHoldCaseStage1Baseline(
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId
    ) {
        if (productTypeId == null && categoryId == null && subCategoryId == null) {
            return null;
        }
        return HOLD_CASE_BASELINE_PREFIX +
            String.valueOf(productTypeId) +
            ';' +
            String.valueOf(categoryId) +
            ';' +
            String.valueOf(subCategoryId) +
            ';' +
            String.valueOf(subCodeId);
    }

    @TestVisible
    private static HoldCaseStage1Baseline parseHoldCaseStage1Baseline(String raw) {
        if (String.isBlank(raw) || !raw.startsWith(HOLD_CASE_BASELINE_PREFIX)) {
            return null;
        }
        String payload = raw.substring(HOLD_CASE_BASELINE_PREFIX.length());
        List<String> parts = payload.split(';');
        if (parts.size() < 3) {
            return null;
        }
        HoldCaseStage1Baseline b = new HoldCaseStage1Baseline();
        b.productTypeId = parseBaselineIdPart(parts[0]);
        b.categoryId = parseBaselineIdPart(parts[1]);
        b.subCategoryId = parseBaselineIdPart(parts[2]);
        b.subCodeId = parts.size() > 3 ? parseBaselineIdPart(parts[3]) : null;
        return b.hasRequiredNocKeys() ? b : null;
    }

    @TestVisible
    private static Id parseBaselineIdPart(String part) {
        if (String.isBlank(part) || 'null'.equalsIgnoreCase(part.trim())) {
            return null;
        }
        try {
            return Id.valueOf(part.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    @TestVisible
    private static Id resolveNatureOfCaseIdFromNocKeys(
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId,
        Id stageId
    ) {
        if (productTypeId == null || categoryId == null || subCategoryId == null) {
            return null;
        }
        List<FEC_Nature_of_Case__c> nocList;
        if (subCodeId != null) {
            nocList = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :productTypeId
                  AND FEC_Category__c = :categoryId
                  AND FEC_Sub_Category__c = :subCategoryId
                  AND FEC_Sub_Code__c = :subCodeId
                LIMIT 50
            ];
        } else {
            nocList = [
                SELECT Id
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :productTypeId
                  AND FEC_Category__c = :categoryId
                  AND FEC_Sub_Category__c = :subCategoryId
                  AND FEC_Sub_Code__c = NULL
                LIMIT 50
            ];
        }
        if (nocList.isEmpty()) {
            return null;
        }
        if (nocList.size() == 1 || stageId == null) {
            return nocList[0].Id;
        }
        Set<Id> nocIds = new Map<Id, FEC_Nature_of_Case__c>(nocList).keySet();
        List<FEC_Hold_Case_Config__c> configs = [
            SELECT FEC_Nature_of_Cases__c
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
              AND Hold_Case_Type__c = :HOLD_CASE_TYPE_AUTO
              AND FEC_Active__c = TRUE
            LIMIT 1
        ];
        if (!configs.isEmpty() && configs[0].FEC_Nature_of_Cases__c != null) {
            return configs[0].FEC_Nature_of_Cases__c;
        }
        return nocList[0].Id;
    }

    @TestVisible
    private static Id resolveStage1IdForNature(Id nocId, Id currentStageId) {
        if (nocId == null) {
            return null;
        }
        List<FEC_Case_Stage__c> byDefault = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND FEC_Default_Stage__c = TRUE
            LIMIT 1
        ];
        if (!byDefault.isEmpty()) {
            return byDefault[0].Id;
        }
        List<FEC_Case_Stage__c> byName = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND Name LIKE '%Stage 1%'
            LIMIT 1
        ];
        return byName.isEmpty() ? currentStageId : byName[0].Id;
    }

    /** Số lần Hold Case Auto thất bại — Case.FEC_Process_Action_Count__c (-1 / null = chưa fail hoặc đã success). */
    @TestVisible
    private static Integer readHoldCaseProcessActionCount(Id caseId) {
        if (caseId == null) {
            return 0;
        }
        List<Case> rows = [
            SELECT FEC_Process_Action_Count__c
            FROM Case
            WHERE Id = :caseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return 0;
        }
        Decimal raw = rows[0].FEC_Process_Action_Count__c;
        if (raw == null || raw < 0) {
            return 0;
        }
        return Integer.valueOf(raw);
    }

    @TestVisible
    private static void applyHoldCaseProcessActionCount(
        Case patch,
        Id caseId,
        String resultType,
        String routingAction
    ) {
        if (
            patch == null ||
            caseId == null ||
            !ROUTING_ACTION_HOLD_CASE.equalsIgnoreCase(routingAction)
        ) {
            return;
        }
        Integer count = readHoldCaseProcessActionCount(caseId);
        if (RESULT_ERROR.equals(resultType)) {
            patch.FEC_Process_Action_Count__c = count + 1;
        } else if (
            RESULT_SUCCESS.equals(resultType) ||
            RESULT_ALREADY_MARKED.equals(resultType)
        ) {
            patch.FEC_Process_Action_Count__c = -1;
        }
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
        String collectionsResponse,
        String routingAction
    ) {
        Case patch = new Case(
            Id = caseId,
            FEC_NFU_Description_Result__c = resultType
        );

        if (String.isNotBlank(collectionsResponse)) {
            patch.FEC_Collections_Response__c = collectionsResponse;
        }

        applyHoldCaseProcessActionCount(patch, caseId, resultType, routingAction);

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