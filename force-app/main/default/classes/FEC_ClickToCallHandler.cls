public without sharing class FEC_ClickToCallHandler {
    public class PhoneWrapper {
        @AuraEnabled public String phoneType;
        @AuraEnabled public String phone;
        
        public PhoneWrapper(String phoneType, String phone) {
            this.phoneType = phoneType;
            this.phone = phone;
        }
    }
    
    
    public class CallResponse {
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String message;
        @AuraEnabled public String status;
        @AuraEnabled public Map<String, Object> requestResult;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PhoneWrapper> getPhoneList(Id caseId) {
        
        List<PhoneWrapper> phoneList = new List<PhoneWrapper>();
        
        if (caseId == null) {
            return phoneList;
        }
        
        Case caseRecord = [
        SELECT Id,
               FEC_Case_Phone_Number__c,
               FEC_Interaction__r.FEC_Phone_Number__c,
               FEC_Account_or_Contract__c
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
    ];
        
        // Interaction Phone
        if (String.isNotBlank(caseRecord.FEC_Interaction__r?.FEC_Phone_Number__c)) {
            phoneList.add(
                new PhoneWrapper(
                'Interaction Phone',
            caseRecord.FEC_Interaction__r.FEC_Phone_Number__c
                )
                );
        }
        
        // Case Phone
        if (String.isNotBlank(caseRecord.FEC_Case_Phone_Number__c)) {
            phoneList.add(
                new PhoneWrapper(
                'Case Phone',
            caseRecord.FEC_Case_Phone_Number__c
                )
                );
        }
        
        if (caseRecord.FEC_Account_or_Contract__c != null) {
            
            // Contact List
            for (FEC_Contact_List__c contact : [
            SELECT FEC_Contact_String__c,
                   FEC_Communication_Type__c
            FROM FEC_Contact_List__c
            WHERE FEC_Customer_History__c = :caseRecord.FEC_Account_or_Contract__c
              AND FEC_Channel__c = 'Phone'
        ]) {
                
                if (String.isNotBlank(contact.FEC_Contact_String__c)) {
                    phoneList.add(
                        new PhoneWrapper(
                        contact.FEC_Communication_Type__c,
                    contact.FEC_Contact_String__c
                        )
                        );
                }
            }
            
            // Registration Phone
            for (FEC_Application_List__c app : [
            SELECT FEC_Registration_Phone__c
            FROM FEC_Application_List__c
            WHERE FEC_Customer_History__c = :caseRecord.FEC_Account_or_Contract__c
        ]) {
                
                if (String.isNotBlank(app.FEC_Registration_Phone__c)) {
                    phoneList.add(
                        new PhoneWrapper(
                        'Registration Phone',
                    app.FEC_Registration_Phone__c
                        )
                        );
                }
            }
        }
        
        return phoneList;
    }
}