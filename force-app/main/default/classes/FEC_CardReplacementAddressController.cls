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
                result.strMsg = 'Yêu cầu thay thế thẻ sẽ được chuyển đến CS D2C xử lý.';
            } else {
                List<Case> cases = [
                    SELECT Id 
                    FROM Case 
                    WHERE FEC_Interaction__c = :objCase.FEC_Interaction__c
                        AND (FEC_SubCode__r.FEC_Code__c = 'RC09.01'
                        OR FEC_SubCode__r.FEC_Code__c = 'RC09.02')
                ];
                if (!cases.isEmpty()) {
                    result.isShowAction = false;
                    result.strMsg = 'Yêu cầu thay thế thẻ sẽ được chuyển đến CS Support xử lý.';
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

    public class ReplaceCardResult {
        @AuraEnabled
        public Boolean isShowAction { get; set; }
        @AuraEnabled
        public String strMsg { get; set; }
    }
}