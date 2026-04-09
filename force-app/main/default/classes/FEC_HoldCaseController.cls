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

    // ─────────────────────────────────────────────────────
    // DTO: ResponseModel
    // ─────────────────────────────────────────────────────
    public class ResponseModel {
        @AuraEnabled public String  status;
        @AuraEnabled public String  message;
        @AuraEnabled public Id      recordId;
        @AuraEnabled public Boolean isSuccess;

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
    // ─────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<NFUReasonModel> getNFUReasons(String subCode) {

        if (String.isBlank(subCode)) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'subCode'}));
        }

        try {
            // 1. Query Config → lấy NFU Codes + metadata
            List<FEC_Hold_Case_Config__c> configs = [
                SELECT FEC_NFU_Code__c,
                       FEC_Active__c,
                       Hold_Case_Type__c	
                FROM FEC_Hold_Case_Config__c
                WHERE FEC_Sub_Code__c = :subCode
                AND   FEC_Active__c   = true
                WITH SECURITY_ENFORCED
            ];

            if (configs.isEmpty()) {
                return new List<NFUReasonModel>();
            }

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

            if (nfuCodes.isEmpty()) {
                return new List<NFUReasonModel>();
            }

            List<FEC_Hold_Case__c> holdCases = [
                SELECT FEC_NFU_Code__c,
                       FEC_NFU_Reason_VN__c,
                       FEC_NFU_Reason_EN__c,
                       FEC_NFU_Duration__c
                FROM FEC_Hold_Case__c
                WHERE FEC_NFU_Code__c IN :nfuCodes
                WITH SECURITY_ENFORCED
            ];

            if (holdCases.isEmpty()) {
                return new List<NFUReasonModel>();
            }

            List<NFUReasonModel> result = new List<NFUReasonModel>();

            for (FEC_Hold_Case__c hc : holdCases) {
                FEC_Hold_Case_Config__c cfg = configMap.get(hc.FEC_NFU_Code__c);

                NFUReasonModel m  = new NFUReasonModel();
                m.nfuCode         = hc.FEC_NFU_Code__c;
                m.nfuDuration     = hc.FEC_NFU_Duration__c;
                m.nfuReasonVN     = hc.FEC_NFU_Reason_VN__c;
                m.nfuReasonEN     = hc.FEC_NFU_Reason_EN__c;
                m.isActive        = cfg != null ? cfg.FEC_Active__c         : false;
                m.holdCaseType    = cfg != null ? cfg.Hold_Case_Type__c	 : '';
                m.subCode         = subCode;

                result.add(m);
            }

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────
    // METHOD: saveHoldCase
    // ─────────────────────────────────────────────────────
    @AuraEnabled
    public static ResponseModel saveHoldCase(
        Id      caseId,
        String  nfuReason,
        String  nfuCode,
        Integer holdDuration
    ) {
        HoldCaseModel model = new HoldCaseModel();
        model.caseId       = caseId;
        model.nfuReason    = nfuReason;
        model.nfuCode      = nfuCode;
        model.holdDuration = holdDuration;

        validateModel(model);

        Savepoint sp = Database.setSavepoint();

        try {
            Case c = [
                SELECT Id, Status
                FROM Case
                WHERE Id = :model.caseId
                LIMIT 1
            ];

            c.Status = FEC_ConstantCommon.CASE_STATUS_ON_HOLD;
            update c;

            return new ResponseModel().success(c.Id, System.Label.FEC_Succes_Hold_Case);

        } catch (Exception e) {
            Database.rollback(sp);
            return new ResponseModel().error(e.getMessage());
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