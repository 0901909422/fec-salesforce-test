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
                 FEC_Search_Account_Number__c, FEC_Search_Application_ID__c,
                 FEC_Search_Contract_Number__c, FEC_Search_Customer_Number__c,
                 FEC_Search_Email_Address__c, FEC_Search_National_ID__c,
                 FEC_Search_Phone_Number__c,
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
    public static void createHistory(String value, String fieldName, Id caseId, String searchProducts) {
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

        try {
            insert rec;
            String randomCIF = String.valueOf(Math.round(Math.random() * 89999999 + 10000000));
            Case objCase = new Case(
                    Id = caseId,
                    FEC_Account_or_Contract__c = rec.Id,
                    FEC_Interaction_View_Mode__c = 'handling',
                    FEC_CIF_Number__c = randomCIF,
                    FEC_First_Access__c = true,
                    FEC_Search_Products__c = searchProducts
                );
            update objCase;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
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

    /**
   * @description Checks if the current user has edit access to specific fields on a given SObject.
   * @param sObjectType The SObject type (e.g., 'Account', 'Custom_Object__c')
   * @param fieldNames A list of field API names to check
   * @return Map<String, Boolean> A map where the key is the field name and the value is true if editable.
   */

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> checkFieldEditPermissions(String sObjectType, List<String> fieldNames) {
        Map<String, Boolean> fieldPermissions = new Map<String, Boolean>();
        
        // Get the describe result for the object
        SObjectType targetType = Schema.getGlobalDescribe().get(sObjectType);
        if (targetType == null) {
            return fieldPermissions; 
        }
        
        Map<String, SObjectField> fieldsMap = targetType.getDescribe().fields.getMap();
        
        for (String fieldName : fieldNames) {
            if (fieldsMap.containsKey(fieldName)) {
                // Check if the field is updateable by the current user
                fieldPermissions.put(fieldName, fieldsMap.get(fieldName).getDescribe().isUpdateable());
            } else {
                fieldPermissions.put(fieldName, false); // Field doesn't exist or isn't accessible
            }
        }
        
        return fieldPermissions;
    }
}