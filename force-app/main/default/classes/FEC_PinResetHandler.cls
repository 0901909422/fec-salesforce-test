public without sharing class FEC_PinResetHandler {
    
    public class CardInfoResponse{
        @AuraEnabled public String cardNumber;
        @AuraEnabled public String cifNumber;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String mobile;
        @AuraEnabled public Decimal processActionCount;
    }
    
    
    
    @AuraEnabled
    public static CardInfoResponse getCardInfo(String customerCaseId){
        try {
            
            List<Case> cases = [SELECT Id, FEC_Account_or_Contract__r.FEC_Account_Number__c  , FEC_CIF_Number__c ,FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c, FEC_Phone_Number__c,  FEC_Process_Action_Count__c
                                FROM Case
                                WHERE Id = :customerCaseId
                                LIMIT 1]
                
            ;
            if(cases.isEmpty()){
                throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
            }
            
            CardInfoResponse response = new CardInfoResponse();
            response.cardNumber = cases[0].FEC_Account_or_Contract__r.FEC_Account_Number__c ;
            response.cifNumber = cases[0].FEC_CIF_Number__c  ;
            response.nationalId = cases[0].FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
            response.mobile = cases[0].FEC_Phone_Number__c;
            response.processActionCount =
                cases[0].FEC_Process_Action_Count__c != null
                ? cases[0].FEC_Process_Action_Count__c
                : 0;
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static FEC_PINReissueServiceCallout.PINResponse resetPin(String caseId, string nationalId, string mobile){
        try {
            
            List<Case> caselst = [
                        SELECT
                            Id,
                            FEC_Process_Action_Count__c
                        FROM Case
                        WHERE Id = :caseId
                        ];
            if (caselst.isEmpty()) {
                throw new FEC_APIServiceException(String.format(System.Label.FEC_MSG_Not_Found, new List<String>{'Case Id'}));
            }
            
            Case selectedCase = caselst.get(0);
            String transactionId = String.valueOf(UUID.randomUUID());
            FEC_PINReissueServiceCallout.PINResponse response = FEC_PINReissueServiceCallout.callPINReissue(nationalId,transactionId, mobile);
            FEC_PINReissueServiceCallout.logApiResponse();
            
            if (response.RespCode != '1' && selectedCase.FEC_Process_Action_Count__c > 0) {
                selectedCase.FEC_Process_Action_Count__c -= 1;
            } else if (response.RespCode == '1') {
                selectedCase.FEC_Process_Action_Count__c =
                    (selectedCase.FEC_Process_Action_Count__c == null ? 0 :
                    selectedCase.FEC_Process_Action_Count__c) + 1;
            }
            
            update selectedCase;
            System.debug(response);
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}