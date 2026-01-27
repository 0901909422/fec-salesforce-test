public with sharing class FEC_SearchController {
    /**
     * Returns minimal Case context for fec_Search initialization.
     * - Runs in USER MODE and WITH SECURITY ENFORCED to respect security.
     * - Selects only fields needed by the component.
     */
    @AuraEnabled(cacheable=true)
    public static Case getCase(Id caseId) {
        if (caseId == null) {
            return null;
        }

        // Query with field-level security and sharing respected
        Case c;
        try {
            c = [
                SELECT Id, FEC_Channel__c, FEC_National_ID_Passport_ID__c,
                 FEC_Phone_Number__c, FEC_Contract_Number__c, RecordType.Name,
                 FEC_Skip_Search_Internal_Case__c, FEC_Has_Account_or_Contract__c,
                 (SELECT Id FROM Customer_Histories__r)
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (Exception e) {
            // If user lacks field/object access, return null (component remains usable)
            return null;
        }
        return c;
    }

    @AuraEnabled
    public static void createHistory(String value, String fieldName, Id caseId) {
        // Return early if no value or field name
        if (value == null || value.trim() == '' || fieldName == null || fieldName.trim() == '') {
            throw new AuraHandledException('Value and fieldName must be provided.');
        }
        // Build record
        FEC_Customer_History__c rec = new FEC_Customer_History__c();
        
        // Set field based on fieldName parameter
        if (fieldName == 'AccountNumber') {
            rec.FEC_Account_Number__c = value;
        }
        if (fieldName == 'ContractNumber') {
            rec.FEC_Contract_Number__c = value;
        }
        if (fieldName == 'UserId') {
            rec.FEC_User_ID__c = value;
        }
        rec.Name = value;
        rec.FEC_Case__c = caseId;

        // Insert in USER_MODE as per security best practice
        Database.SaveResult sr = Database.insert(rec);
        if (!sr.isSuccess()) {
            Database.Error err = (sr.getErrors() != null && !sr.getErrors().isEmpty()) ? sr.getErrors()[0] : null;
            throw new AuraHandledException(err != null ? err.getMessage() : 'Failed to create FEC_Customer_History__c.');
        } else {
            Case objCase = new Case(
                Id = caseId,
                FEC_Account_or_Contract__c = rec.Id
            );
            update objCase;
        }
    }

    @AuraEnabled
    public static Case createCustomerCase(String fullName, String nationalId) {
        try{
            Case c = new Case();
            c.FEC_Customer_Name__c = fullName;
            c.FEC_National_ID_Passport_ID__c = nationalId;
            c.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Customer_Case').getRecordTypeId();
            insert c;
            return c;
        }   
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}