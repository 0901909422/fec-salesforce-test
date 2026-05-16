// tungnm37: Controller cho New General Assignment popup
public with sharing class FEC_GeneralAssignmentController {

    // Lấy danh sách Channel active
    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getChannels(String searchTerm) {
        String q = String.isBlank(searchTerm) ? '%' : '%' + searchTerm + '%';
        return [
            SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
              AND (Name LIKE :q OR FEC_Channel_ID__c LIKE :q)
            ORDER BY Name ASC
            LIMIT 20
        ];
    }

    // Lấy danh sách Stage theo NOC
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Stage__c> getStagesByNoc(String nocId) {
        if (String.isBlank(nocId)) return new List<FEC_Case_Stage__c>();
        return [
            SELECT Id, Name, FEC_Code__c
            FROM FEC_Case_Stage__c
            WHERE FEC_Nature_of_Cases__c = :nocId
              AND FEC_Active__c = true
            ORDER BY Name ASC
        ];
    }

    // Lấy danh sách General Assignment Name (từ FEC_Business_Configuration_Tools__c hoặc custom object)
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGeneralAssignmentNames() {
        List<AggregateResult> existing = [
            SELECT FEC_General_Assignment_Name__c name
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_General_Assignment_Name__c != null
            GROUP BY FEC_General_Assignment_Name__c
            LIMIT 50
        ];
        List<Map<String, String>> result = new List<Map<String, String>>();
        for (AggregateResult ar : existing) {
            String n = (String) ar.get('name');
            result.add(new Map<String, String>{ 'label' => n, 'value' => n });
        }
        return result;
    }

    // Save General Assignment
    @AuraEnabled
    public static Id saveGeneralAssignment(
        String nocId,
        String customerType,
        String channelIds,
        String stageId,
        String generalAssignmentName,
        String generalAssignmentCode,
        Boolean active
    ) {
        FEC_General_Assignment_Config__c ga = new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = String.isNotBlank(nocId) ? nocId : null,
            FEC_Customer_Type__c = customerType,
            FEC_Channel__c = channelIds,
            FEC_Case_Stage__c = String.isNotBlank(stageId) ? stageId : null,
            FEC_General_Assignment_Name__c = generalAssignmentName,
            FEC_General_Assignment_Code__c = generalAssignmentCode,
            FEC_Active__c = active != null ? active : true
        );
        insert ga;
        return ga.Id;
    }

    // Get record name for header display
    @AuraEnabled(cacheable=true)
    public static String getRecordName(String recordId) {
        if (String.isBlank(recordId)) return 'General Assignment';
        List<FEC_General_Assignment_Config__c> records = [
            SELECT Name FROM FEC_General_Assignment_Config__c WHERE Id = :recordId LIMIT 1
        ];
        return records.isEmpty() ? 'General Assignment' : records[0].Name;
    }

    // Get GA Code by GA Name
    @AuraEnabled(cacheable=true)
    public static String getGACodeByName(String gaName) {
        if (String.isBlank(gaName)) return '';
        List<FEC_General_Assignment_Config__c> records = [
            SELECT FEC_General_Assignment_Code__c
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_General_Assignment_Name__c = :gaName
              AND FEC_General_Assignment_Code__c != null
            LIMIT 1
        ];
        return records.isEmpty() ? '' : records[0].FEC_General_Assignment_Code__c;
    }

    // Update General Assignment record
    @AuraEnabled
    public static void updateGeneralAssignment(
        String recordId,
        String customerType,
        String channelIds,
        String generalAssignmentName,
        String generalAssignmentCode,
        Boolean active
    ) {
        FEC_General_Assignment_Config__c ga = new FEC_General_Assignment_Config__c(
            Id = recordId,
            FEC_Customer_Type__c = customerType,
            FEC_Channel__c = channelIds,
            FEC_General_Assignment_Name__c = generalAssignmentName,
            FEC_General_Assignment_Code__c = generalAssignmentCode,
            FEC_Active__c = active != null ? active : true
        );
        update ga;
    }

}
