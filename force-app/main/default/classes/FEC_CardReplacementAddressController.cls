public with sharing class FEC_CardReplacementAddressController {
    @AuraEnabled
    public static List<FEC_Address_Info__c> getAddressInfos(String caseId) {
        try {
            Case objCase = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId];
            return [
                SELECT Id,
                    FEC_Address_Type__c,
                    FEC_Full_Address__c,
                    FEC_Mailing_Address__c
                FROM FEC_Address_Info__c
                WHERE FEC_Customer_History__c = :objCase.FEC_Account_or_Contract__c
                    AND FEC_Case__c = null
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static FEC_Address_Info__c getAddressInfo(String addressId) {
        return [
            SELECT Id,
                FEC_Address__c
            FROM FEC_Address_Info__c
            WHERE Id = :addressId
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceOptionsForAddress() {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        for (FEC_Province__c p : [
            SELECT Id, Name, FEC_Name_VN__c
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = '2'
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = p.Id;
            o.label = String.isNotBlank(p.FEC_Name_VN__c) ? p.FEC_Name_VN__c : p.Name;
            opts.add(o);
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getWardOptionsForProvinceCode(String provinceId) {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        for (FEC_District__c d : [
            SELECT Id, Name, FEC_Name_VN__c
            FROM FEC_District__c
            WHERE FEC_Country__r.FEC_Code__c = '2'
                AND FEC_Province__c = :provinceId
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = d.Id;
            o.label = String.isNotBlank(d.FEC_Name_VN__c) ? d.FEC_Name_VN__c : d.Name;
            opts.add(o);
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static String getCountryId() {
        List<FEC_Country__c> countries = [SELECT Id FROM FEC_Country__c WHERE FEC_Code__c = '2' LIMIT 1];
        return !countries.isEmpty() ? countries.get(0).Id : null;
    }

    @AuraEnabled
    public static ReplaceCardResult checkProcessAction(String caseId) {
        ReplaceCardResult result = new ReplaceCardResult();
        try {
            List<String> inValidBlockCode = new List<String>{'F', 'S', 'G', 'N'};
            List<String> inValidBlockCode1 = new List<String>{'F', 'G', 'N'};
            Case objCase = [
                SELECT Id, 
                    FEC_Interaction__c,
                    FEC_Account_Number__c
                FROM Case 
                WHERE Id = :caseId
            ];
            Boolean isSuccess = false;
            String blockCode;
            String blockCode1;
            FEC_CardLockUnLockController.ResponseResult cardStatus = FEC_CardLockUnLockController.getCardStatus(caseId);
            blockCode = cardStatus?.currentBlockCode;
            if (String.isBlank(blockCode)) {
                // getCardStatus exception
                return result;
            }

            FEC_EmeaAccountInqService.EmeaInput input = new FEC_EmeaAccountInqService.EmeaInput();
            input.context    = FEC_ConstantCommon.REQUESTOR_CONTEXT;
            input.name       = UserInfo.getUserId();
            input.org        = FEC_ConstantCommon.REQUESTOR_ORG;
            input.account    = objCase.FEC_Account_Number__c;
            input.dualInd    = FEC_ConstantCommon.SUCCESS_STATUS_CODE;
            input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA;

            FEC_EmeaAccountInqService.EmeaResult emeaRes = FEC_EmeaAccountInqService.callAccountInquiry(input);
            blockCode1 = emeaRes?.blkCd1;

            if (String.isNotBlank(blockCode) || String.isNotBlank(blockCode1)) {
                isSuccess = true;
            }

            if (isSuccess && (inValidBlockCode.contains(blockCode) || inValidBlockCode1.contains(blockCode1))) {
                result.isShowAction = false;
                result.strMsg = System.Label.FEC_MSG_CARD_REPLACEMENT_CS_D2C;
            } else {
                List<Case> cases = [
                    SELECT Id 
                    FROM Case 
                    WHERE FEC_Interaction__c = :objCase.FEC_Interaction__c
                        AND (FEC_SubCode__r.FEC_Code__c = :FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_MOBILE
                        OR FEC_SubCode__r.FEC_Code__c = :FEC_ConstantCommon.SUB_CODE_PROCESS_UPDATE_ADDRESS)
                ];
                if (!cases.isEmpty()) {
                    result.isShowAction = false;
                    result.strMsg = System.Label.FEC_MSG_CARD_REPLACEMENT_CS_SUPPORT;
                }
            }
            if (String.isBlank(result.strMsg)) {
                result.isShowAction = true;
            }
        } catch (Exception e) {
            FEC_CommonUltils.logException(
                'FEC_CardReplacementAddressController', 
                'checkProcessAction', 
                e.getMessage(),
                e.getStackTraceString()
            );
        }
        return result;
    }

    public static UpdateResult cardReplacement(String recordId, String method, String cardBlockCode, String last4CardNumber, String replacementFee) {
        UpdateResult result = new UpdateResult();
        Case objCasse;
        try {
            objCasse = [
                SELECT Id,
                    FEC_National_ID_Passport_ID__c,
                    FEC_Case_Phone_Number__c,
                    FEC_Process_Action_Count__c,
                    FEC_Current_Case_Stage__c,
                    FEC_Current_Case_Stage__r.Name,
                    FEC_Account_Number__c
                FROM Case
                WHERE Id = :recordId
            ];
            String transactionId = FEC_CommonUltils.generateTransactionUUID();
            String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
            String replacementFeeFlag = String.isNotBlank(replacementFee) ? '1' : '0';
            FEC_ReplacementCardCallout.ReplaceCardResponse response = FEC_ReplacementCardCallout.callReplaceCard(
                transactionId,
                requestorId,
                cardBlockCode,
                last4CardNumber,
                replacementFeeFlag,
                objCasse.FEC_Account_Number__c
            );
            FEC_ReplacementCardCallout.logApiResponse();
            
            if (FEC_ReplacementCardCallout.isSuccess(response)) {
                result.success = true;
                objCasse.FEC_Process_Action_Count__c = -1;
            } else {
                result.success = false;
                if (objCasse.FEC_Process_Action_Count__c == null) {
                    objCasse.FEC_Process_Action_Count__c = 0;
                }
                objCasse.FEC_Process_Action_Count__c += 1;
            }

            FEC_CaseTriggerHandler.isExecuting = true;
            update objCasse;
            result.actionCount = objCasse.FEC_Process_Action_Count__c;
        } catch (Exception ex) {
            result.success = false;
            FEC_CommonUltils.logException(
                'FEC_CardReplacementAddressController', 
                'cardReplacement', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
        } finally {
            FEC_CommonUltils.createProcessActionHistory(
                method,
                objCasse,
                result.success
            );
        }
        return result;
    }

    public class ReplaceCardResult {
        @AuraEnabled
        public Boolean isShowAction { get; set; }
        @AuraEnabled
        public String strMsg { get; set; }
    }

    public class UpdateResult {
        @AuraEnabled
        public Boolean success { get; set; }
        @AuraEnabled
        public Decimal actionCount { get; set; }
    }

    public class PicklistOptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}