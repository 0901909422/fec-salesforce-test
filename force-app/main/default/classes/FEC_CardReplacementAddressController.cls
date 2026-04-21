public with sharing class FEC_CardReplacementAddressController {
    @AuraEnabled
    public static List<FEC_Address_Info__c> getAddressInfos(String caseId) {
        try {
            Case objCase = [SELECT Id, FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId];
            return [
                SELECT Id,
                    FEC_Address_Type__c,
                    FEC_Address__c,
                    FEC_Mailing_Address__c
                FROM FEC_Address_Info__c
                WHERE FEC_Customer_History__c = :objCase.FEC_Account_or_Contract__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static ReplaceCardResult checkProcessAction(String caseId) {
        try {
            ReplaceCardResult result = new ReplaceCardResult();
            List<String> inValidBlockCode = new List<String>{'F', 'S', 'G', 'N'};
            List<String> inValidBlockCode1 = new List<String>{'F', 'G', 'N'};
            Case objCase = [
                SELECT Id, 
                    FEC_Interaction__c,
                    FEC_Account_or_Contract__r.FEC_Block_Code__c,
                    FEC_Account_or_Contract__r.FEC_Block_Code_1__c
                FROM Case 
                WHERE Id = :caseId
            ];
            if ((String.isNotBlank(objCase.FEC_Account_or_Contract__r.FEC_Block_Code__c)
                    && inValidBlockCode.contains(objCase.FEC_Account_or_Contract__r.FEC_Block_Code__c))
                || (String.isNotBlank(objCase.FEC_Account_or_Contract__r.FEC_Block_Code_1__c)
                    && inValidBlockCode1.contains(objCase.FEC_Account_or_Contract__r.FEC_Block_Code_1__c))) {
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
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static UpdateResult cardReplacement(String recordId, String method, String cardBlockCode, String last4CardNumber, Decimal replacementFee) {
        UpdateResult result = new UpdateResult();
        try {
            Case objCasse = [
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
            String replacementFeeFlag = replacementFee != null ? '1' : '0';
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
            FEC_CommonUltils.createProcessActionHistory(
                method,
                objCasse,
                result.success
            );
        } catch (Exception ex) {
            FEC_CommonUltils.logException(
                'FEC_CardReplacementAddressController', 
                'cardReplacement', 
                ex.getMessage(),
                ex.getStackTraceString()
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
}