public with sharing class FEC_PinReplacementController {
    
    public static UpdateResult pinReplacement(String recordId, String method) {
        UpdateResult result = new UpdateResult();
        try {
            Case objCasse = [
                SELECT Id,
                    FEC_National_ID_Passport_ID__c,
                    FEC_Case_Phone_Number__c,
                    FEC_Process_Action_Count__c,
                    FEC_Current_Case_Stage__c,
                    FEC_Current_Case_Stage__r.Name
                FROM Case
                WHERE Id = :recordId
            ];
            String transactionId = FEC_CommonUltils.generateTransactionUUID();
            FEC_PINReissueServiceCallout.PINResponse response = FEC_PINReissueServiceCallout.callPINReissue(
                objCasse.FEC_National_ID_Passport_ID__c,
                transactionId,
                objCasse.FEC_Case_Phone_Number__c
            );
            FEC_PINReissueServiceCallout.logApiResponse();
            
            if (response.isSuccess) {
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
                'FEC_PinReplacementController', 
                'pinReplacement', 
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