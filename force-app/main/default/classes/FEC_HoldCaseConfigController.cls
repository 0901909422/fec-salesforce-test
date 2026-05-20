/**
 * @description Controller for FEC_MDM_Hold_Case_Config__c CRUD operations.
 * Supports detail-form view per NOC with Auto/Manual mode.
 */
public with sharing class FEC_HoldCaseConfigController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getConfigsByNoc(Id nocId) {
        if (nocId == null) return new List<Map<String, Object>>();
        List<FEC_MDM_Hold_Case_Config__c> configs = [
            SELECT Id, Name, FEC_Active__c, FEC_Channel__c, FEC_NFU_Code__c,
                   FEC_User__c, FEC_User__r.Name, Hold_Case_Type__c,
                   FEC_Changed_Status__c, FEC_Current_Status__c,
                   FEC_Case_Stage__c, FEC_Case_Stage__r.Name,
                   FEC_Nature_of_Case__c, Process_Change_Status__c, CreatedDate
            FROM FEC_MDM_Hold_Case_Config__c
            WHERE FEC_Nature_of_Case__c = :nocId
            ORDER BY CreatedDate DESC
        ];
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (FEC_MDM_Hold_Case_Config__c c : configs) {
            Map<String, Object> populated = c.getPopulatedFieldsAsMap();
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id', c.Id);
            row.put('Name', c.Name);
            row.put('FEC_Active__c', populated.containsKey('FEC_Active__c') ? c.FEC_Active__c : false);
            row.put('FEC_Channel__c', populated.containsKey('FEC_Channel__c') ? c.FEC_Channel__c : '');
            row.put('FEC_NFU_Code__c', populated.containsKey('FEC_NFU_Code__c') ? c.FEC_NFU_Code__c : '');
            row.put('Hold_Case_Type__c', populated.containsKey('Hold_Case_Type__c') ? c.Hold_Case_Type__c : '');
            row.put('FEC_Changed_Status__c', populated.containsKey('FEC_Changed_Status__c') ? c.FEC_Changed_Status__c : '');
            row.put('FEC_Current_Status__c', populated.containsKey('FEC_Current_Status__c') ? c.FEC_Current_Status__c : '');
            row.put('FEC_Case_Stage__c', populated.containsKey('FEC_Case_Stage__c') ? c.FEC_Case_Stage__c : null);
            row.put('caseStageName', c.FEC_Case_Stage__r != null ? c.FEC_Case_Stage__r.Name : '');
            row.put('FEC_User__c', populated.containsKey('FEC_User__c') ? c.FEC_User__c : null);
            row.put('userName', c.FEC_User__r != null ? c.FEC_User__r.Name : '');
            row.put('FEC_Nature_of_Case__c', populated.containsKey('FEC_Nature_of_Case__c') ? c.FEC_Nature_of_Case__c : null);
            row.put('Process_Change_Status__c', populated.containsKey('Process_Change_Status__c') ? c.Process_Change_Status__c : '');
            results.add(row);
        }
        return results;
    }

    @AuraEnabled
    public static Id saveConfig(FEC_MDM_Hold_Case_Config__c config) {
        if (config.Id == null) {
            if (!FEC_MDM_Hold_Case_Config__c.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException('No permission to create Hold Case Config.');
            }
        } else {
            if (!FEC_MDM_Hold_Case_Config__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException('No permission to update Hold Case Config.');
            }
        }
        try {
            upsert config;
            return config.Id;
        } catch (DmlException dml) {
            String msg = dml.getDmlMessage(0);
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteConfig(Id configId) {
        if (configId == null) {
            throw new AuraHandledException('Config Id cannot be null.');
        }
        if (!FEC_MDM_Hold_Case_Config__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException('No permission to delete Hold Case Config.');
        }
        try {
            delete new FEC_MDM_Hold_Case_Config__c(Id = configId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Get all active NFU Codes for the NFU Code picker.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNfuCodes() {
        List<Map<String, String>> results = new List<Map<String, String>>();
        List<FEC_MDM_NFU_Code__c> codes = [
            SELECT Id, Name, FEC_Reason_VN__c
            FROM FEC_MDM_NFU_Code__c
            WHERE FEC_Active__c = true
            ORDER BY Name ASC
        ];
        for (FEC_MDM_NFU_Code__c c : codes) {
            results.add(new Map<String, String>{
                'code' => c.Name,
                'reasonVN' => c.FEC_Reason_VN__c != null ? c.FEC_Reason_VN__c : ''
            });
        }
        return results;
    }

    /**
     * @description Get Case Status picklist values for Current/Changed Status dropdowns.
     * Includes "ALL" option at the top.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStatusOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        options.add(new Map<String, String>{ 'label' => 'ALL', 'value' => 'ALL' });
        Schema.DescribeFieldResult dfr = Case.Status.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) {
                options.add(new Map<String, String>{ 'label' => pe.getLabel(), 'value' => pe.getValue() });
            }
        }
        return options;
    }

    /**
     * @description Get MDM Channel options with Name as both label and value.
     * Used for Hold Case Config where Channel is stored as Text, not Lookup.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannelNameOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Channel__c> channels = [SELECT Id, Name FROM FEC_MDM_Channel__c ORDER BY Name ASC];
        for (FEC_MDM_Channel__c c : channels) {
            options.add(new Map<String, String>{ 'label' => c.Name, 'value' => c.Name });
        }
        return options;
    }
}