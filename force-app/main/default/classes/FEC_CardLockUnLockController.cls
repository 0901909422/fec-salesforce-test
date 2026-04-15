public with sharing class FEC_CardLockUnLockController {

    public static UpdateResult lockUnblockCard(String recordId, String funcCode, String method) {
        UpdateResult result = new UpdateResult();
        try {
            Case objCasse = [
                SELECT Id,
                    FEC_Account_Number__c,
                    FEC_New_Block_Code__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c,
                    FEC_Process_Action_Count__c
                FROM Case
                WHERE Id = :recordId
            ];
            String cardNumber = objCasse.FEC_Account_or_Contract__r?.FEC_Card_Number__c?.right(4);
            
            String transId = FEC_CommonUltils.generateTransactionId();
            String requestorId = FEC_ConstantCommon.API_REQUESTOR_ID;
            // Function indicator: "B" for block, "U" for unblock.

            // FEC_CardLockUnLockCallout.ValidationResult validateResult = FEC_CardLockUnLockCallout.validateRequest(
            //     transId,
            //     requestorId,
            //     objCasse.FEC_New_Block_Code__c,
            //     funcCode,
            //     cardNumber,
            //     objCasse.FEC_Account_Number__c
            // );
            // if (!validateResult.isValid) {
            //     result.success = false;
            //     return result;
            // }
            FEC_CardLockUnLockCallout.LockUnlockResponse response = FEC_CardLockUnLockCallout.callLockUnlockCard(
                transId,
                requestorId,
                objCasse.FEC_New_Block_Code__c,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c
            );
            // Log API response
            FEC_CardLockUnLockCallout.logApiResponse();

            if (String.isNotBlank(response.errorCode) || !FEC_CardLockUnLockCallout.isSuccess(response)) {
                result.success = false;
                if (objCasse.FEC_Process_Action_Count__c == null) {
                    objCasse.FEC_Process_Action_Count__c = 0;
                }
                objCasse.FEC_Process_Action_Count__c += 1;
            } else {
                result.success = true;
                objCasse.FEC_Process_Action_Count__c = -1;
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
                'FEC_CardLockUnLockController', 
                'lockUnblockCard', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
        }
        return result;
    }

    public class UpdateResult {
        @AuraEnabled
        public Boolean success { get; set; }
        @AuraEnabled
        public Decimal actionCount { get; set; }
    }
}