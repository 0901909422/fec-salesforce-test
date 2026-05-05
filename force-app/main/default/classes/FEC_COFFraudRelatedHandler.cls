public with sharing class FEC_COFFraudRelatedHandler {
    
    @AuraEnabled
    public static String getCategory(String categoryId) {
        if (String.isBlank(categoryId)) {
            return null;
        }
        
        List<FEC_Category__c> categories = [
        SELECT Name
        FROM FEC_Category__c
        WHERE Id = :categoryId
        LIMIT 1
    ];
        
        return categories.isEmpty() ? null : categories[0].Name;
    }
    
    @AuraEnabled
    public static void updateCase(
        String recordId,
    String complaintTypeValue,
    String complaintSourceValue
    ) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('recordId is required');
        }
        
        Case cs = new Case(
            Id = recordId,
        FEC_Complain_Type__c = complaintTypeValue,
        FEC_Complaint_Source__c = complaintSourceValue
            );
        
        try {
            update cs;
        } catch (Exception e) {
            throw new AuraHandledException('Update Case failed: ' + e.getMessage());
        }
    }
}