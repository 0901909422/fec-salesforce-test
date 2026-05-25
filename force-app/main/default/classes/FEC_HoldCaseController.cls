public with sharing class FEC_HoldCaseController {

    // ─────────────────────────────────────────────────────
    // DTO: HoldCaseModel
    // ─────────────────────────────────────────────────────
    public class HoldCaseModel {
        @AuraEnabled public Id      caseId;
        @AuraEnabled public String  nfuReason;
        @AuraEnabled public String  nfuCode;
        @AuraEnabled public Integer holdDuration;
    }

    public class NfuInfoResult {
        @AuraEnabled public String nfuStatus;
        @AuraEnabled public String nfuCode;
        @AuraEnabled public String nfuStartedDate;
        @AuraEnabled public String nfuExpiryDate;
        @AuraEnabled public String nfuReason;
        @AuraEnabled public Boolean isSuccess;
    }

    // ─────────────────────────────────────────────────────
    // DTO: ResponseModel
    // ─────────────────────────────────────────────────────
    public class ResponseModel {
        @AuraEnabled public String  status;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      recordId;
        @AuraEnabled public Boolean isSuccess;
        // tungnm37: NFU info để hiển thị trong Case Information
        @AuraEnabled public String  nfuStatus;
        @AuraEnabled public String  nfuCode;
        @AuraEnabled public String  nfuStartedDate;
        @AuraEnabled public String  nfuExpiryDate;
        @AuraEnabled public String  nfuReason;
        @AuraEnabled public String  collectionsResponse;

        public ResponseModel success(Id recId, String msg) {
            this.status    = FEC_ConstantCommon.STATUS_SUCCESS;
            this.message   = msg;
            this.recordId  = recId;
            this.isSuccess = true;
            return this;
        }

        public ResponseModel error(String msg) {
            this.status    = FEC_ConstantCommon.CASE_STATUS_ERROR;
            this.message   = msg;
            this.isSuccess = false;
            return this;
        }
    }

    // ─────────────────────────────────────────────────────
    // DTO: NFUReasonModel
    // ─────────────────────────────────────────────────────
    public class NFUReasonModel {
        @AuraEnabled public String  nfuCode;
        @AuraEnabled public Decimal nfuDuration;
        @AuraEnabled public String  nfuReasonVN;
        @AuraEnabled public String  nfuReasonEN;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String  holdCaseType;
        @AuraEnabled public String  subCode;

        public NFUReasonModel() {}
    }

    // ─────────────────────────────────────────────────────
    // METHOD: getNFUReasons
    // tungnm37 fix: nhận caseId + optional NOC IDs (khi Case chưa save NOC)
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static List<NFUReasonModel> getNFUReasons(
        String caseId,
        Id productTypeId,
        Id categoryId,
        Id subCategoryId,
        Id subCodeId
    ) {

        if (String.isBlank(caseId)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'caseId'}));
        }

        try {
            Id nocId;

            // tungnm37: nếu có NOC IDs từ LWC (Case chưa save) → dùng trực tiếp
            if (productTypeId != null && categoryId != null && subCategoryId != null) {
                List<FEC_Nature_of_Case__c> nocs;
                if (subCodeId != null) {
                    nocs = [
                        SELECT Id FROM FEC_Nature_of_Case__c
                        WHERE FEC_Product_Type__c = :productTypeId
                          AND FEC_Category__c     = :categoryId
                          AND FEC_Sub_Category__c = :subCategoryId
                          AND FEC_Sub_Code__c     = :subCodeId
                        WITH SECURITY_ENFORCED LIMIT 1
                    ];
                } else {
                    nocs = [
                        SELECT Id FROM FEC_Nature_of_Case__c
                        WHERE FEC_Product_Type__c = :productTypeId
                          AND FEC_Category__c     = :categoryId
                          AND FEC_Sub_Category__c = :subCategoryId
                          AND FEC_Sub_Code__c     = null
                        WITH SECURITY_ENFORCED LIMIT 1
                    ];
                }
                if (!nocs.isEmpty()) nocId = nocs[0].Id;
            }

            // tungnm37: fallback → lấy NOC từ Case record (Case đã save)
            if (nocId == null) {
                List<Case> cases = [
                    SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c,
                           FEC_Current_Case_Stage__c
                    FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED LIMIT 1
                ];
                if (!cases.isEmpty() && cases[0].FEC_Product_Type__c != null) {
                    Case c = cases[0];
                    List<FEC_Nature_of_Case__c> nocs = [
                        SELECT Id FROM FEC_Nature_of_Case__c
                        WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
                          AND FEC_Category__c     = :c.FEC_Category__c
                          AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
                          AND FEC_Sub_Code__c     = :c.FEC_SubCode__c
                        WITH SECURITY_ENFORCED LIMIT 1
                    ];
                    if (!nocs.isEmpty()) nocId = nocs[0].Id;
                }
            }

            // tungnm37: lấy Current Stage từ Case để filter config
            Id currentStageId = null;
            List<Case> caseForStage = [SELECT FEC_Current_Case_Stage__c FROM Case WHERE Id = :caseId LIMIT 1];
            if (!caseForStage.isEmpty()) currentStageId = caseForStage[0].FEC_Current_Case_Stage__c;

            // tungnm37: fallback 3 → lấy NOC từ Case Stage (khi Case chưa save NOC nhưng đã có Stage)
            if (nocId == null && currentStageId != null) {
                List<FEC_Case_Stage__c> stages = [
                    SELECT FEC_Nature_of_Cases__c FROM FEC_Case_Stage__c
                    WHERE Id = :currentStageId LIMIT 1
                ];
                if (!stages.isEmpty() && stages[0].FEC_Nature_of_Cases__c != null) {
                    nocId = stages[0].FEC_Nature_of_Cases__c;
                }
            }

            // tungnm37: fallback 4 → query config trực tiếp theo Stage (không cần nocId)
            // Trường hợp: Case chưa save NOC, Stage chưa gắn NOC, nhưng button đã hiện
            // → tìm config theo Stage để lấy NFU codes
            List<FEC_Hold_Case_Config__c> configs;
            // tungnm37: chỉ check FEC_Case_Stage__c, không cần FEC_Nature_of_Cases__c
            if (currentStageId != null) {
                configs = [
                    SELECT FEC_NFU_Code__c, FEC_Active__c, Hold_Case_Type__c
                    FROM FEC_Hold_Case_Config__c
                    WHERE FEC_Active__c = true
                      AND Hold_Case_Type__c = 'Manual'
                      AND FEC_Case_Stage__c = :currentStageId
                    WITH SECURITY_ENFORCED
                ];
            } else {
                return new List<NFUReasonModel>();
            }

            if (configs.isEmpty()) return new List<NFUReasonModel>();

            Map<String, FEC_Hold_Case_Config__c> configMap = new Map<String, FEC_Hold_Case_Config__c>();
            Set<String> nfuCodes = new Set<String>();

            for (FEC_Hold_Case_Config__c cfg : configs) {
                if (String.isBlank(cfg.FEC_NFU_Code__c)) continue;
                for (String code : cfg.FEC_NFU_Code__c.split(',')) {
                    String trimmed = code.trim();
                    if (!String.isBlank(trimmed)) {
                        nfuCodes.add(trimmed);
                        configMap.put(trimmed, cfg);
                    }
                }
            }

            if (nfuCodes.isEmpty()) return new List<NFUReasonModel>();

            List<FEC_Hold_Case__c> holdCases = [
                SELECT FEC_NFU_Code__c, FEC_NFU_Reason_VN__c, FEC_NFU_Reason_EN__c, FEC_NFU_Duration__c
                FROM FEC_Hold_Case__c
                WHERE FEC_NFU_Code__c IN :nfuCodes
                WITH SECURITY_ENFORCED
            ];

            if (holdCases.isEmpty()) return new List<NFUReasonModel>();

            List<NFUReasonModel> result = new List<NFUReasonModel>();
            for (FEC_Hold_Case__c hc : holdCases) {
                FEC_Hold_Case_Config__c cfg = configMap.get(hc.FEC_NFU_Code__c);
                NFUReasonModel m = new NFUReasonModel();
                m.nfuCode      = hc.FEC_NFU_Code__c;
                m.nfuDuration  = hc.FEC_NFU_Duration__c;
                m.nfuReasonVN  = hc.FEC_NFU_Reason_VN__c;
                m.nfuReasonEN  = hc.FEC_NFU_Reason_EN__c;
                m.isActive     = cfg != null ? cfg.FEC_Active__c : false;
                m.holdCaseType = cfg != null ? cfg.Hold_Case_Type__c : '';
                result.add(m);
            }
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    /**
     * Gọi API Mark NFU (FEC_MarkNFU) rồi trả về NFU info từ Case.
     * Non-cacheable vì có HTTP callout.
     * Dùng khi Routing Action = "Resolve" | "Route to".
     */
    @AuraEnabled
    public static NfuInfoResult callMarkNFUAndGetInfo(String caseId) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'caseId'})
            );
        }

        try {
            // 1. Query Case lấy ContractNumber
            Case c = [
                SELECT Id,
                    FEC_Account_Contract_Number_Text__c,
                    FEC_SubCode__c,
                    FEC_NFU_Status__c,
                    FEC_NFU_Started_Date__c,
                    FEC_NFU_Expiry_Date__c,
                    FEC_NFU_Reason__c
                FROM Case
                WHERE Id = :caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('[callMarkNFUAndGetInfo] Case: ' + JSON.serialize(c));
            // 2. Lấy NFU Code từ Config theo subCode
            List<FEC_Hold_Case_Config__c> configs = [
                SELECT FEC_NFU_Code__c
                FROM FEC_Hold_Case_Config__c
                WHERE FEC_Nature_of_Cases__r.FEC_Sub_Code__c = :c.FEC_SubCode__c
                AND   FEC_Active__c   = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
             System.debug('[callMarkNFUAndGetInfo] configs: ' + JSON.serialize(configs));
            if (configs.isEmpty() || String.isBlank(configs[0].FEC_NFU_Code__c)) {
                NfuInfoResult failed = new NfuInfoResult();
                failed.isSuccess = false;
                failed.nfuReason = System.Label.FEC_Reason_Error;
                return failed;
            }

            String nfuCode = configs[0].FEC_NFU_Code__c.split(',')[0].trim();

             System.debug('[callMarkNFUAndGetInfo] nfuCode to send: ' + nfuCode);

            // 2. Gọi API Mark NFU
            String userEmail = [
                SELECT Email FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ].Email;
           
            FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();
            req.ContractNumber = c.FEC_Account_Contract_Number_Text__c;
            req.NFUReasonCode  = nfuCode;
            req.NFUUpdatedBy   = userEmail;
            System.debug('[callMarkNFUAndGetInfo] MarkNFURequest: ' + JSON.serialize(req));

            FEC_MarkNFU.MarkNFUResult markResult = FEC_MarkNFU.markNFU(req);
            System.debug('[callMarkNFUAndGetInfo] MarkNFUResult: ' + JSON.serialize(markResult));
            NfuInfoResult result = new NfuInfoResult();

            if (!markResult.success) {
                result.isSuccess = false;
                result.nfuReason = markResult.errorMessage;
                return result;
            }

            Case refreshed = [
                SELECT FEC_NFU_Status__c,
                    FEC_NFU_Code__c,
                    FEC_NFU_Started_Date__c,
                    FEC_NFU_Expiry_Date__c,
                    FEC_NFU_Reason__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        
            if (String.isBlank(refreshed.FEC_NFU_Status__c)) {
                result.isSuccess = false;
                return result;
            }

            result.isSuccess      = true;
            result.nfuStatus      = refreshed.FEC_NFU_Status__c;
            result.nfuCode        = refreshed.FEC_NFU_Code__c;
            result.nfuStartedDate = refreshed.FEC_NFU_Started_Date__c != null
                ? refreshed.FEC_NFU_Started_Date__c.format()
                : '';
            result.nfuExpiryDate  = refreshed.FEC_NFU_Expiry_Date__c != null
                ? refreshed.FEC_NFU_Expiry_Date__c.format()
                : '';
            result.nfuReason      = refreshed.FEC_NFU_Reason__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('callMarkNFUAndGetInfo error: ' + e.getMessage());
        }
    }

    private static final String RESULT_ALREADY_MARKED = 'ALREADY_MARKED';
    private static final String RESULT_SUCCESS        = 'SUCCESS';
    private static final String RESULT_ERROR          = 'ERROR';
    private static final String NFU_STATUS_YES        = 'Yes';
    private static final String DESC_ALREADY_MARKED   = 'Contract has already marked as NFU';
    private static final String DESC_SUCCESS            = 'Success';

    // ─────────────────────────────────────────────────────
    // METHOD: saveHoldCase
    // tungnm37: gọi API MarkNFU trước, sau đó mới DML (không dùng Savepoint vì callout)
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static ResponseModel saveHoldCase(
        Id      caseId,
        String  nfuReason,
        String  nfuCode,
        Integer holdDuration,
        Integer attemptNumber
    ) {
        HoldCaseModel model = new HoldCaseModel();
        model.caseId       = caseId;
        model.nfuReason    = nfuReason;
        model.nfuCode      = nfuCode;
        model.holdDuration = holdDuration;

        validateModel(model);

        Integer attempt = attemptNumber == null || attemptNumber < 1 ? 1 : attemptNumber;

        try {
            // tungnm37: query Case lấy ContractNumber
            Case c = [
                SELECT Id, Status, FEC_Account_Contract_Number_Text__c
                FROM Case
                WHERE Id = :model.caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            // tungnm37: lấy email user hiện tại
            String userEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;
            String nfuReasonLabel = resolveNfuReasonLabel(model.nfuCode);

            // tungnm37: gọi API MarkNFU TRƯỚC khi DML (callout không được sau savepoint/DML)
            FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();
            req.ContractNumber = c.FEC_Account_Contract_Number_Text__c;
            req.NFUReasonCode  = model.nfuCode;
            req.NFUUpdatedBy   = userEmail;

            FEC_MarkNFU.MarkNFUResult markResult = FEC_MarkNFU.markNFU(req);
            System.debug('[saveHoldCase] caseId=' + caseId + ' attempt=' + attempt
                + ' MarkNFU=' + JSON.serialize(markResult));

            DateTime expiryDate = parseNfuDateTime(markResult != null ? markResult.nfuTillDate : null);
            DateTime startedDate = parseNfuDateTime(markResult != null ? markResult.nfuStartDate : null);

            // tungnm37: TH1 - Contract đã được mark NFU trước đó (code 203)
            // Description = Contract has already marked as NFU
            if (isTh1AlreadyMarked(markResult)) {
                updateCaseAfterManualHold(
                    c.Id,
                    RESULT_ALREADY_MARKED,
                    model.nfuCode,
                    nfuReasonLabel,
                    startedDate,
                    expiryDate,
                    System.Label.FEC_STOP_IMPACT_ALREADY_MARKED_MSG,
                    null
                );
                ResponseModel resp = new ResponseModel();
                resp.status    = RESULT_ALREADY_MARKED;
                resp.message   = System.Label.FEC_STOP_IMPACT_ALREADY_MARKED_MSG;
                resp.isSuccess = true;
                resp.recordId  = c.Id;
                populateResponseFromCase(resp, c.Id);
                return resp;
            }

            // tungnm37: TH2 - Thành công → update Case Status = On Hold
            // Description = Success
            if (isTh2Success(markResult)) {
                DateTime startedNow = DateTime.now();
                updateCaseAfterManualHold(
                    c.Id,
                    RESULT_SUCCESS,
                    model.nfuCode,
                    nfuReasonLabel,
                    startedNow,
                    expiryDate,
                    System.Label.FEC_MSG_SUCCESS,
                    FEC_ConstantCommon.CASE_STATUS_ON_HOLD
                );
                ResponseModel resp = new ResponseModel();
                resp.status    = RESULT_SUCCESS;
                resp.message   = System.Label.FEC_MSG_SUCCESS;
                resp.isSuccess = true;
                resp.recordId  = c.Id;
                populateResponseFromCase(resp, c.Id);
                return resp;
            }

            // tungnm37: TH3 - API lỗi → trả về error (không cần rollback vì chưa DML)
            // response khác Contract has already marked as NFU / Success → ghi ERROR lên Case sau lần thử thứ 3
            ResponseModel resp = new ResponseModel();
            resp.status    = RESULT_ERROR;
            resp.message   = String.isNotBlank(markResult != null ? markResult.errorMessage : null)
                ? markResult.errorMessage
                : System.Label.FEC_MSG_ERROR;
            resp.isSuccess = false;
            resp.recordId  = c.Id;

            if (attempt >= 3) {
                updateCaseAfterManualHold(
                    c.Id,
                    RESULT_ERROR,
                    null,
                    null,
                    null,
                    null,
                    System.Label.FEC_MSG_ERROR,
                    null
                );
            }

            return resp;

        } catch (Exception e) {
            return new ResponseModel().error(e.getMessage());
        }
    }

    /** Ghi ERROR lên Case khi LWC hết 3 lần thử (fallback khi callout exception). */
    @AuraEnabled
    public static void persistManualHoldCaseError(Id caseId) {
        if (caseId == null) {
            return;
        }
        updateCaseAfterManualHold(
            caseId,
            RESULT_ERROR,
            null,
            null,
            null,
            null,
            System.Label.FEC_MSG_ERROR,
            null
        );
    }

    @TestVisible
    private static Boolean isTh1AlreadyMarked(FEC_MarkNFU.MarkNFUResult markResult) {
        if (markResult == null) {
            return false;
        }
        if (markResult.code == FEC_ConstantCommon.SUCCESS_CODE_203) {
            return true;
        }
        return String.isNotBlank(markResult.description)
            && markResult.description.toLowerCase().contains(DESC_ALREADY_MARKED.toLowerCase());
    }

    @TestVisible
    private static Boolean isTh2Success(FEC_MarkNFU.MarkNFUResult markResult) {
        if (markResult == null) {
            return false;
        }
        if (isTh1AlreadyMarked(markResult)) {
            return false;
        }
        if (String.isNotBlank(markResult.description)
            && markResult.description.trim().equalsIgnoreCase(DESC_SUCCESS)) {
            return true;
        }
        return markResult.success == true;
    }

    @TestVisible
    private static String resolveNfuReasonLabel(String nfuCode) {
        if (String.isBlank(nfuCode)) {
            return '';
        }
        List<FEC_Hold_Case__c> rows = [
            SELECT FEC_NFU_Reason_VN__c
            FROM FEC_Hold_Case__c
            WHERE FEC_NFU_Code__c = :nfuCode
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return rows.isEmpty() ? nfuCode : rows[0].FEC_NFU_Reason_VN__c;
    }

    @TestVisible
    private static void updateCaseAfterManualHold(
        Id caseId,
        String resultType,
        String nfuCode,
        String nfuReasonLabel,
        DateTime startedDate,
        DateTime expiryDate,
        String collectionsResponse,
        String caseStatus
    ) {
        if (resultType == RESULT_ERROR) {
            Case errorPatch = new Case(
                Id = caseId,
                FEC_NFU_Description_Result__c = resultType
            );
            if (String.isNotBlank(collectionsResponse)) {
                errorPatch.FEC_Collections_Response__c = collectionsResponse;
            }
            saveCasePatch(errorPatch);
            return;
        }

        Case patch = new Case(
            Id = caseId,
            FEC_NFU_Description_Result__c = resultType
        );

        if (String.isNotBlank(collectionsResponse)) {
            patch.FEC_Collections_Response__c = collectionsResponse;
        }

        if (String.isNotBlank(caseStatus)) {
            patch.Status = caseStatus;
        }

        patch.FEC_NFU_Status__c = NFU_STATUS_YES;
        patch.FEC_NFU_Code__c = nfuCode;
        patch.FEC_NFU_Reason__c = nfuReasonLabel;
        patch.FEC_NFU_Started_Date__c = startedDate;
        patch.FEC_NFU_Expiry_Date__c = expiryDate;
        saveCasePatch(patch);
    }

    /** Giống FEC_AutoHoldCaseService — tránh FLS chặn ghi Case patch. */
    private static void saveCasePatch(Case patch) {
        Database.SaveResult sr = Database.update(patch, false, AccessLevel.SYSTEM_MODE);
        if (!sr.isSuccess()) {
            String err = sr.getErrors().isEmpty()
                ? 'Update Case failed'
                : sr.getErrors()[0].getMessage();
            System.debug('[saveHoldCase] saveCasePatch FAILED caseId=' + patch.Id + ' err=' + err);
            throw new AuraHandledException(err);
        }
        System.debug('[saveHoldCase] saveCasePatch OK caseId=' + patch.Id
            + ' result=' + patch.FEC_NFU_Description_Result__c);
    }

    @TestVisible
    private static void populateResponseFromCase(ResponseModel resp, Id caseId) {
        // tungnm37: query NFU info từ Case để hiển thị trong Case Information
        Case refreshed = [
            SELECT FEC_NFU_Status__c, FEC_NFU_Code__c,
                   FEC_NFU_Started_Date__c, FEC_NFU_Expiry_Date__c,
                   FEC_NFU_Reason__c
            FROM Case
            WHERE Id = :caseId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        resp.nfuStatus      = refreshed.FEC_NFU_Status__c;
        resp.nfuCode        = refreshed.FEC_NFU_Code__c;
        resp.nfuStartedDate = refreshed.FEC_NFU_Started_Date__c != null
            ? refreshed.FEC_NFU_Started_Date__c.format()
            : '';
        resp.nfuExpiryDate  = refreshed.FEC_NFU_Expiry_Date__c != null
            ? refreshed.FEC_NFU_Expiry_Date__c.format()
            : '';
        resp.nfuReason      = refreshed.FEC_NFU_Reason__c;
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
            System.debug('[FEC_HoldCaseController] parseNfuDateTime failed: ' + ex.getMessage());
            return null;
        }
    }

    // ─────────────────────────────────────────────────────
    // HELPER: check duplicate theo caseId + nfuCode
    // ─────────────────────────────────────────────────────
    private static Boolean isNFUCodeExist(String nfuCode, Id caseId) {
        return ![
            SELECT Id
            FROM FEC_Hold_Case__c
            WHERE FEC_NFU_Code__c = :nfuCode
            LIMIT 1
        ].isEmpty();
    }

    // ─────────────────────────────────────────────────────
    // HELPER: validate model
    // ─────────────────────────────────────────────────────
    @TestVisible
    private static void validateModel(HoldCaseModel model) {
        if (model == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Model'}));
        }
        if (model.caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }
        if (String.isBlank(model.nfuReason)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'NFU Reason'}));
        }
        if (String.isBlank(model.nfuCode)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'NFU Code'}));
        }
    }
}