/****************************************************************************************
 * File Name    : Fec_HoldCaseConfigurationController.Apex
 * Author       : Quangdv7
 * Date         : 2026-05-10
 * Description  : Call data object FEC_Hold_Case_Config__c
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0     2026-05-10     Quangdv7             Create
 
****************************************************************************************/

public with sharing class Fec_HoldCaseConfigurationController {

    // ================= GET LIST =================

    @AuraEnabled(cacheable=true)
    public static List<HoldCaseWrapper> getHoldCaseConfigurations(Id recordId) {

        if(recordId == null){
            return new List<HoldCaseWrapper>();
        }

        List<FEC_Hold_Case_Config__c> holdCases = [
            SELECT
                Id,
                Name,
                Hold_Case_Type__c,
                FEC_Channel__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Case_Stage__r.Name,
                FEC_NFU_Code__c,
                FEC_Active__c,
                FEC_Nature_of_Cases__c,
                LastModifiedDate,
                LastModifiedBy.Name
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c = :recordId
            ORDER BY LastModifiedDate DESC
        ];

        List<HoldCaseWrapper> results = new List<HoldCaseWrapper>();

        for(FEC_Hold_Case_Config__c hc : holdCases) {

            HoldCaseWrapper item = new HoldCaseWrapper();

            item.Id             = hc.Id;
            item.name           = hc.Name;
            item.holdCaseType   = hc.Hold_Case_Type__c;
            item.channel        = hc.FEC_Channel__c;
            item.currentStatus  = hc.Hold_Case_Type__c == 'Auto' ? hc.FEC_Current_Status__c : '';
            item.changedStatus  = hc.Hold_Case_Type__c == 'Auto' ? hc.FEC_Changed_Status__c : '';
            item.caseStage = hc.FEC_Case_Stage__r != null? hc.FEC_Case_Stage__r.Name : '';
            item.nfuCode        = hc.FEC_NFU_Code__c;
            item.active         = hc.FEC_Active__c ? 'Yes' : 'No';
            item.lastModifiedDate = FEC_CommonUltils.formatTimestamp(hc.LastModifiedDate, 'dd/MM/yyyy, HH:mm');
            item.lastModifiedBy = hc.LastModifiedBy.Name;

            results.add(item);
        }

        return results;
    }

    // ================= SAVE =================

    @AuraEnabled
    public static Id saveHoldCaseConfig(String payload) {

        if(String.isBlank(payload)) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{'Payload'}
                )
            );
        }

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Id recordId = (Id) data.get('id');
        FEC_Hold_Case_Config__c record;

        /* =========================================
        * UPDATE
        * ========================================= */
        if(recordId != null){

            record = [
                SELECT Id
                FROM FEC_Hold_Case_Config__c
                WHERE Id = :recordId
                LIMIT 1
            ];

        } else {

            /* =========================================
            * CREATE
            * ========================================= */
            record = new FEC_Hold_Case_Config__c();
        }

        record.FEC_Nature_of_Cases__c = (String) data.get('natureOfCaseId');
        record.Hold_Case_Type__c = (String) data.get('holdCaseType');
        record.FEC_Channel__c = (String) data.get('channel');
        record.FEC_Case_Stage__c = (String) data.get('caseStage');
        record.FEC_Current_Status__c = (String) data.get('currentStatus');
        record.FEC_Changed_Status__c = (String) data.get('changedStatus');
        record.FEC_NFU_Code__c = (String) data.get('nfuCode');
        Object activeValue = data.get('active');
        if(activeValue != null){
            record.FEC_Active__c = (Boolean) activeValue;
        }

        upsert record;

        /* =========================================
        * INHERITANCE
        * ========================================= */
        FEC_HoldCaseInheritanceService.process(record.Id);
        return record.Id;
    }

    // ================= CHANNEL =================

    @AuraEnabled(cacheable=true)
    public static List<ChannelWrapper> searchChannels(String keyword) {

        List<ChannelWrapper> results = new List<ChannelWrapper>();

        if(String.isBlank(keyword)) {
            return results;
        }

        List<FEC_Channel__c> channels = [
            SELECT Id, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Vietnamese_name__c LIKE :('%' + keyword + '%')
            LIMIT 10
        ];

        for(FEC_Channel__c item : channels){
            results.add(new ChannelWrapper(item.Id, item.FEC_Channel_Vietnamese_name__c));
        }

        return results;
    }

    // ================= CASE STATUS =================

    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Status__c> searchCaseStatus(String keyword) {

        String key = '%' + keyword + '%';

        return [
            SELECT Id, Name
            FROM FEC_Case_Status__c
            WHERE Name LIKE :key
            LIMIT 10
        ];
    }

    // ================= NFU CODE =================

    @AuraEnabled(cacheable=true)
    public static List<FEC_Hold_Case__c> getNfuCodes() {

        return [
            SELECT Id, FEC_NFU_Code__c, FEC_NFU_Reason_VN__c
            FROM FEC_Hold_Case__c
            ORDER BY FEC_NFU_Code__c ASC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_Hold_Case__c> searchNfuCodes(String keyword) {

        String key = '%' + keyword + '%';

        return [
            SELECT Id, FEC_NFU_Code__c, FEC_NFU_Reason_VN__c
            FROM FEC_Hold_Case__c
            WHERE FEC_NFU_Code__c LIKE :key
            LIMIT 10
        ];
    }

    /* =====================================================
    * LOAD HOLD CASE DETAIL
    * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static FEC_Hold_Case_Config__c getHoldCaseConfigurationDetail(Id recordId) {

        if(recordId == null){
            return null;
        }

        return [
            SELECT
                Id,
                Name,
                Hold_Case_Type__c,
                FEC_Channel__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Case_Stage__c,
                FEC_Case_Stage__r.Name,
                FEC_NFU_Code__c,
                FEC_Active__c,
                FEC_Nature_of_Cases__c,
                LastModifiedDate,
                LastModifiedBy.Name
            FROM FEC_Hold_Case_Config__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    /* =====================================================
    * HOLD CASE CONFIG HISTORY
    * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<HoldCaseConfigHistoryWrapper> getHoldCaseConfigHistory(Id recordId) {

        if(recordId == null){
            return new List<HoldCaseConfigHistoryWrapper>();
        }

        List<FEC_Hold_Case_Config__History> histories = [
            SELECT
                Id,
                Field,
                OldValue,
                NewValue,
                CreatedDate,
                CreatedBy.Id,
                CreatedBy.Name
            FROM FEC_Hold_Case_Config__History
            WHERE ParentId = :recordId
            ORDER BY CreatedDate DESC
        ];

        List<HoldCaseConfigHistoryWrapper> results = new List<HoldCaseConfigHistoryWrapper>();
        for(FEC_Hold_Case_Config__History item : histories){
            HoldCaseConfigHistoryWrapper row = new HoldCaseConfigHistoryWrapper();
            row.modifiedDate = FEC_CommonUltils.formatTimestamp(item.CreatedDate,'dd/MM/yyyy, HH:mm');
            row.userId = item.CreatedBy.Id;
            row.userName = item.CreatedBy.Name;
            row.field = getHistoryFieldLabel(item.Field);
            row.originalValue = item.OldValue != null ? String.valueOf(item.OldValue): '-';
            row.newValue = item.NewValue != null ? String.valueOf(item.NewValue) : '-';
            results.add(row);
        }

        return results;
    }

    /* =====================================================
    * FIELD LABEL MAPPING
    * ===================================================== */
    private static String getHistoryFieldLabel(String apiName){

        Map<String, String> fieldLabels =
            new Map<String, String>{

            'Name' => 'Hold Case Name',
            'Hold_Case_Type__c' => 'Hold Case Type',
            'FEC_Channel__c' => 'Channel',
            'FEC_Current_Status__c' => 'Current Status',
            'FEC_Changed_Status__c' => 'Changed Status',
            'FEC_Case_Stage__c' => 'Case Stage',
            'FEC_NFU_Code__c' => 'NFU Code',
            'FEC_Active__c' => 'Active'
        };

        return fieldLabels.containsKey(apiName)
            ? fieldLabels.get(apiName)
            : apiName;
    }

    @AuraEnabled(cacheable=true)
    public static List<HoldCaseWrapper> getParentHoldCaseConfigurations(Id recordId) {

        if(recordId == null){
            return new List<HoldCaseWrapper>();
        }

        // ================= STEP 1: FIND PARENT HIERARCHY =================
        Set<Id> parentNatureIds = new Set<Id>();

        FEC_Nature_of_Case__c currentNoc = [
            SELECT Id,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        parentNatureIds.add(currentNoc.Id);

        // ================= STEP 2: BUILD PARENT LEVELS =================
    
        if(currentNoc.FEC_Product_Type__c != null){
            parentNatureIds.add(currentNoc.FEC_Product_Type__c);
        }

        if(currentNoc.FEC_Category__c != null){
            parentNatureIds.add(currentNoc.FEC_Category__c);
        }

        if(currentNoc.FEC_Sub_Category__c != null){
            parentNatureIds.add(currentNoc.FEC_Sub_Category__c);
        }

        if(currentNoc.FEC_Sub_Code__c != null){
            parentNatureIds.add(currentNoc.FEC_Sub_Code__c);
        }

        // ================= STEP 3: QUERY PARENT HOLD CASE CONFIG =================
        List<FEC_Hold_Case_Config__c> parentConfigs = [
            SELECT
                Id,
                Name,
                Hold_Case_Type__c,
                FEC_Channel__c,
                FEC_Current_Status__c,
                FEC_Changed_Status__c,
                FEC_Case_Stage__r.Name,
                FEC_NFU_Code__c,
                FEC_Active__c,
                FEC_Nature_of_Cases__c,
                LastModifiedDate,
                LastModifiedBy.Name
            FROM FEC_Hold_Case_Config__c
            WHERE FEC_Nature_of_Cases__c IN :parentNatureIds
            ORDER BY LastModifiedDate DESC
        ];

        // ================= STEP 4: MAP TO WRAPPER =================
        List<HoldCaseWrapper> results = new List<HoldCaseWrapper>();

        for(FEC_Hold_Case_Config__c hc : parentConfigs){

            HoldCaseWrapper item = new HoldCaseWrapper();

            item.Id             = hc.Id;
            item.name           = hc.Name;
            item.holdCaseType   = hc.Hold_Case_Type__c;
            item.channel        = hc.FEC_Channel__c;
            item.currentStatus  = hc.Hold_Case_Type__c == 'Auto'
                                    ? hc.FEC_Current_Status__c
                                    : '';
            item.changedStatus  = hc.Hold_Case_Type__c == 'Auto'
                                    ? hc.FEC_Changed_Status__c
                                    : '';
            item.caseStage      = hc.FEC_Case_Stage__r != null
                                    ? hc.FEC_Case_Stage__r.Name
                                    : '';
            item.nfuCode        = hc.FEC_NFU_Code__c;
            item.active         = hc.FEC_Active__c ? 'Yes' : 'No';
            item.lastModifiedDate = hc.LastModifiedDate.format('dd/MM/yyyy, HH:mm');
            item.lastModifiedBy   = hc.LastModifiedBy.Name;

            results.add(item);
        }

        return results;
    }

    // ================= INNER CLASSES =================

    public class ChannelWrapper {

        @AuraEnabled public String Id;
        @AuraEnabled public String Name;

        public ChannelWrapper(String Id, String Name){
            this.Id   = Id;
            this.Name = Name;
        }
    }

    public class HoldCaseWrapper {

        @AuraEnabled public Id     Id;
        @AuraEnabled public String name;
        @AuraEnabled public String holdCaseType;
        @AuraEnabled public String channel;
        @AuraEnabled public String currentStatus;
        @AuraEnabled public String changedStatus;
        @AuraEnabled public String caseStage;
        @AuraEnabled public String nfuCode;
        @AuraEnabled public String active;
        @AuraEnabled public String lastModifiedDate;
        @AuraEnabled public String lastModifiedBy;
    }

    public class HoldCaseConfigHistoryWrapper {

        @AuraEnabled public String modifiedDate;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String field;
        @AuraEnabled public String originalValue;
        @AuraEnabled public String newValue;
    }
}
