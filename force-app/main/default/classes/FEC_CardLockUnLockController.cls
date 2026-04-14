public with sharing class FEC_CardLockUnLockController {

    @AuraEnabled
    public static CardBlockDTO getCardBlockData(String recordId) {
        CardBlockDTO cardBlock = new CardBlockDTO();
        try {
            Case objCasse = [
                SELECT Id,
                    FEC_Current_Card_Status__c,
                    FEC_Card_Block_Reason__c,
                    FEC_New_Block_Code__c
                FROM Case
                WHERE Id = :recordId
            ];
            List<FEC_Additional_Info__c> additionalInfos = [
                SELECT Id,
                    FEC_Verify_Information__c,
                    FEC_Callback__c
                FROM FEC_Additional_Info__c
                WHERE FEC_Case__c = :recordId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            cardBlock.caseId = objCasse.Id;
            cardBlock.currentCardStatus = objCasse.FEC_Current_Card_Status__c;
            cardBlock.cardBlockReason = objCasse.FEC_Card_Block_Reason__c;
            cardBlock.newBlockCode = objCasse.FEC_New_Block_Code__c;
            if (!additionalInfos.isEmpty()) {
                FEC_Additional_Info__c additionalInfo = additionalInfos.get(0);
                cardBlock.additionalInfoId = additionalInfo.Id;
                cardBlock.verifyInformation = additionalInfo.FEC_Verify_Information__c;
                cardBlock.callback = additionalInfo.FEC_Callback__c;
            }
        } catch (Exception ex) {
            FEC_CommonUltils.logException(
                'FEC_CardLockUnLockController', 
                'getCardLockUnlockData', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
        }
        return cardBlock;
    }
    
    @AuraEnabled
    public static String blockCard(String recordId, String blockCode) {
        try {
            if (String.isBlank(recordId)) {
                return '';
            }
            Case objCasse = [
                SELECT Id,
                    FEC_Account_Number__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c
                FROM Case
                WHERE Id = :recordId
            ];
            String cardNumber = objCasse.FEC_Account_or_Contract__r?.FEC_Card_Number__c?.right(4);
            
            String transId = FEC_CommonUltils.generateTransactionId();
            String requestorId = FEC_ConstantCommon.API_REQUESTOR_ID;
            String funcCode = 'B'; // Function indicator: "B" for block, "U" for unblock.

            FEC_CardLockUnLockCallout.ValidationResult validateResult = FEC_CardLockUnLockCallout.validateRequest(
                transId,
                requestorId,
                blockCode,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c
            );
            if (!validateResult.isValid) {
                return validateResult.errorMessage;
            }
            FEC_CardLockUnLockCallout.LockUnlockResponse response = FEC_CardLockUnLockCallout.callLockUnlockCard(
                transId,
                requestorId,
                blockCode,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c
            );
            // Log API response
            FEC_CardLockUnLockCallout.logApiResponse();

            if (String.isNotBlank(response.errorCode) || !FEC_CardLockUnLockCallout.isSuccess(response)) {
                return 'FAIL';
            }
            return 'SUCCESS';
        } catch (Exception ex) {
            FEC_CommonUltils.logException(
                'FEC_CardLockUnLockController', 
                'blockCard', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
            return System.Label.FEC_MSG_Exception;
        }
    }

    public static UpdateResult unblockCard(String recordId, String method) {
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
            String funcCode = 'U'; // Function indicator: "B" for block, "U" for unblock.

            FEC_CardLockUnLockCallout.ValidationResult validateResult = FEC_CardLockUnLockCallout.validateRequest(
                transId,
                requestorId,
                objCasse.FEC_New_Block_Code__c,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c
            );
            if (!validateResult.isValid) {
                result.success = false;
                return result;
            }
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
                'unblockCard', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
        }
        return result;
    }

    public class CardBlockDTO {
        @AuraEnabled
        public String caseId { get; set; }
        @AuraEnabled
        public String additionalInfoId { get; set; }
        @AuraEnabled
        public String currentCardStatus { get; set; }
        @AuraEnabled
        public String cardBlockReason { get; set; }
        @AuraEnabled
        public String newBlockCode { get; set; }
        @AuraEnabled
        public String verifyInformation { get; set; }
        @AuraEnabled
        public String callback { get; set; }
    }

    public class UpdateResult {
        @AuraEnabled
        public Boolean success { get; set; }
        @AuraEnabled
        public Decimal actionCount { get; set; }
    }
}