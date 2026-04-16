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

}