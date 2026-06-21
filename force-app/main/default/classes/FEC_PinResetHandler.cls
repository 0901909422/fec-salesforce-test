public without sharing class FEC_PinResetHandler {
    
    public class CardInfoResponse{
        @AuraEnabled public String cardNumber;
        @AuraEnabled public String cifNumber;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String mobile;
        @AuraEnabled public Decimal processActionCount;
        @AuraEnabled public Boolean isPinResetSuccess;
    }
    
    
    
    @AuraEnabled
    public static CardInfoResponse getCardInfo(String customerCaseId){
        try {
            
            List<Case> cases = [SELECT Id, FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c , FEC_Account_or_Contract__r.FEC_Primary_Phone__c , FEC_Process_Action_Count__c,FEC_Is_PIN_Reset_Success__c
                FROM Case
                WHERE Id = :customerCaseId
                LIMIT 1]
                
            ;
            if(cases.isEmpty()){
                throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
            }
            
            CardInfoResponse response = new CardInfoResponse();
            response.nationalId = cases[0].FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
            response.mobile = cases[0].FEC_Account_or_Contract__r.FEC_Primary_Phone__c;
            response.processActionCount =
                cases[0].FEC_Process_Action_Count__c != null
                ? cases[0].FEC_Process_Action_Count__c
                : 0;
            response.isPinResetSuccess = cases[0].FEC_Is_PIN_Reset_Success__c;
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static FEC_PINReissueServiceCallout.PINResponse resetPin(String caseId, string nationalId, string mobile, String method) {
        Case selectedCase;
        FEC_PINReissueServiceCallout.PINResponse response;
        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            
            List<Case> caseList = [
                SELECT
                    Id,
                    FEC_Process_Action_Count__c,
                    FEC_Is_Test_API__c,
                    FEC_Is_PIN_Reset_Success__c,
                    FEC_Current_Case_Stage__c,
                    FEC_Current_Case_Stage__r.Name
                FROM Case
                WHERE Id = :caseId
            ];
            
            if (caseList.isEmpty()) {
                throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
            }
            selectedCase = caseList[0];
            
            String transactionId = String.valueOf(UUID.randomUUID());
            response = FEC_PINReissueServiceCallout.callPINReissue(nationalId,transactionId, mobile, selectedCase.FEC_Is_Test_API__c);
            
            Integer count =
                selectedCase.FEC_Process_Action_Count__c == null
                ? 0
                : Integer.valueOf(selectedCase.FEC_Process_Action_Count__c);
            
            Boolean isSuccess = response.RespCode == '0';
            
            if (isSuccess) {
                FEC_CmsVmxIntegrationService.onCmsOperationSuccess(
                    selectedCase.Id,
                    FEC_CmsVmxIntegrationService.OP_PIN_RESET
                );
                selectedCase.FEC_Is_PIN_Reset_Success__c = true;
                if (count > 0) {
                    selectedCase.FEC_Process_Action_Count__c = count - 1;
                }
            } else {
                selectedCase.FEC_Process_Action_Count__c = count + 1;
            }
            
            update selectedCase;
            
            Case checkCase = [
                SELECT FEC_Is_PIN_Reset_Success__c
                FROM Case
                WHERE Id = :selectedCase.Id
            ];
            
            System.debug('AFTER UPDATE: ' + checkCase.FEC_Is_PIN_Reset_Success__c);
            System.debug(response);
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        } finally {
            FEC_PINReissueServiceCallout.logApiResponse();
            FEC_CommonUltils.flushDeferredApiLogs();
            if (selectedCase != null) {
                FEC_CommonUltils.createProcessActionHistory(
                    method,
                    selectedCase,
                    response != null && response.RespCode == '0' ? true : false
                );
            }
        }
    }
    
    
    
}