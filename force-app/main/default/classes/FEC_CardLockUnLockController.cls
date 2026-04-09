public with sharing class FEC_CardLockUnLockController {
    
    @AuraEnabled
    public static String blockCard(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                return '';
            }
            Case objCasse = [
                SELECT Id, FEC_New_Block_Code__c, FEC_Account_Number__c,
                    (SELECT Id, FEC_Card_Number__c
                    FROM Customer_Histories__r)
                FROM Case
                WHERE Id = :recordId
            ];
            List<FEC_Customer_History__c> customerHistories = objCasse.Customer_Histories__r;
            String cardNumber;
            if (!customerHistories.isEmpty()) {
                cardNumber = customerHistories.get(0).FEC_Card_Number__c;
            }

            String transId = FEC_CommonUltils.generateTransactionId();
            String requestorId = FEC_ConstantCommon.API_REQUESTOR_ID;
            String funcCode = 'B'; // Function indicator: "B" for block, "U" for unblock.

            FEC_CardLockUnLockCallout.ValidationResult validateResult = FEC_CardLockUnLockCallout.validateRequest(
                transId,
                requestorId,
                objCasse.FEC_New_Block_Code__c,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c
            );
            if (!validateResult.isValid) {
                throw new FEC_APIServiceException(validateResult.errorMessage);
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
                return '';
            }
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}