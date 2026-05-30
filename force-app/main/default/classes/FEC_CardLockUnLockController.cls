public with sharing class FEC_CardLockUnLockController {

    public static UpdateResult lockUnblockCard(String recordId, String funcCode, String blockCode, String method) {
        UpdateResult result = new UpdateResult();
        Case objCasse;
        try {
            objCasse = [
                SELECT Id,
                    FEC_Account_Number__c,
                    FEC_New_Block_Code__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c,
                    FEC_Process_Action_Count__c,
                    FEC_Current_Case_Stage__c,
                    FEC_Current_Case_Stage__r.Name,
                    FEC_Is_Test_API__c
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
                blockCode,
                funcCode,
                cardNumber,
                objCasse.FEC_Account_Number__c,
                objCasse.FEC_Is_Test_API__c
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
        } catch (Exception ex) {
            result.success = false;
            FEC_CommonUltils.logException(
                'FEC_CardLockUnLockController', 
                'lockUnblockCard', 
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

    @AuraEnabled
    public static ResponseResult getCardStatus(String recordId) {
        ResponseResult result = new ResponseResult();
        try {
            Case objCasse = [
                SELECT Id,
                    FEC_Account_Number__c,
                    FEC_Customer_Name__c,
                    FEC_Current_Card_Status__c,
                    FEC_Account_or_Contract__r.FEC_Card_Number__c
                FROM Case
                WHERE Id = :recordId
            ];
            String transId = FEC_CommonUltils.generateTransactionUUID();
            String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            String vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA_CARD;
            String context = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
            String signOnName = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
            String org = FEC_ConstantCommon.REQUESTOR_ORG_EMEA_CARD;
            String accNumber = objCasse.FEC_Account_Number__c;
            String cusName = objCasse.FEC_Customer_Name__c;
            String rawCard = objCasse.FEC_Account_or_Contract__r?.FEC_Card_Number__c;
            String last4 = String.isNotBlank(rawCard) ? rawCard.trim().right(4) : null;
            FEC_MCMSCARDTOCARDINQEMEA.ResponseWrapper res = FEC_MCMSCARDTOCARDINQEMEA.callService(
                transId,
                requestorId,
                dateTimeStr,
                vmxVersion,
                context,
                signOnName,
                org,
                accNumber,
                cusName
            );
            if (res?.Sys?.Code == 1
            && res.VMXMsgOut?.OUTPUT_AREA?.OUTPUT_DATA != null
            && !res.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA.isEmpty()) {
                for (FEC_MCMSCARDTOCARDINQEMEA.OutputData outputData : res?.VMXMsgOut?.OUTPUT_AREA?.OUTPUT_DATA) {
                    if (String.isBlank(outputData.CARD_NBR)) {
                        System.debug(FEC_ConstantCommon.SKIP_ITEM);
                        continue;
                    }
                    String cardNbr = outputData.CARD_NBR.trim();
                    String cardNbrLast4 = cardNbr.length() >= 4 ? cardNbr.right(4) : cardNbr;

                    if (last4 != null && cardNbrLast4 != last4) {
                        System.debug(FEC_ConstantCommon.NO_MATCH);
                        continue;
                    }
                    if (String.isNotBlank(outputData.BLK_CD)) {
                        result.isSuccess = true;
                        result.currentBlockCode = outputData.BLK_CD;
                        result.currentCardStatus = 'Blocked';
                    }
                    break;
                }
            }
            if (result.isSuccess == null || !result.isSuccess) {
                result.currentCardStatus = 'Not Blocked';
            }
            if (String.isNotBlank(objCasse.FEC_Current_Card_Status__c)) {
                result.currentCardStatus = objCasse.FEC_Current_Card_Status__c;
            }
        } catch (Exception ex) {
            // Log Api
            FEC_CommonUltils.logApiResponse(FEC_MCMSCARDTOCARDINQEMEA.responseLog);
            // Log exception
            FEC_CommonUltils.logException(
                'FEC_CardLockUnLockController', 
                'getCardStatus', 
                ex.getMessage(),
                ex.getStackTraceString()
            );
        }
        return result;
    }


    @AuraEnabled
    public static LockCardResult checkProcessActionCardBlock(String currentBlockCode, String newBlockCode) {
        try {
            LockCardResult result = new LockCardResult();
            List<FEC_Block_Code_Matrix__c> blockCodeMatrixs = [
                SELECT Id, FEC_Action__c
                FROM FEC_Block_Code_Matrix__c
                WHERE (FEC_Current_Block_Code__c = :currentBlockCode
                        OR FEC_Current_Block_Code__c = 'OTHER')
                    AND FEC_New_Block_Code__c = :newBlockCode
                LIMIT 1
            ];
            if (!blockCodeMatrixs.isEmpty()) {
                FEC_Block_Code_Matrix__c blockCodeMatrix = blockCodeMatrixs.get(0);
                if (blockCodeMatrix.FEC_Action__c?.toLowerCase() == 'cs thực hiện') {
                    result.isShowAction = true;
                } else if (blockCodeMatrix.FEC_Action__c?.toLowerCase() == 'd2c thực hiện') {
                    result.isShowAction = false;
                    result.isCancel = false;
                    result.strMsg = System.Label.FEC_MSG_CARD_BLOCK_CS_D2C;
                } else if (blockCodeMatrix.FEC_Action__c?.toLowerCase() == 'không thực hiện') {
                    result.isShowAction = false;
                    result.isCancel = true;
                    result.strMsg = System.Label.FEC_MSG_CARD_BLOCK_CANCEL;
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class UpdateResult {
        @AuraEnabled
        public Boolean success { get; set; }
        @AuraEnabled
        public Decimal actionCount { get; set; }
    }

    public class ResponseResult {
        @AuraEnabled
        public Boolean isSuccess { get; set; }
        @AuraEnabled
        public String currentCardStatus { get; set; }
        @AuraEnabled
        public String currentBlockCode { get; set; }
    }

    public class LockCardResult {
        @AuraEnabled
        public Boolean isShowAction { get; set; }
        @AuraEnabled
        public Boolean isCancel { get; set; }
        @AuraEnabled
        public String strMsg { get; set; }
    }

}