/**
 * @description: Dynamic Controller to fetch Standard History for any Object
 * @author: DAT NGO
 * @date: 2026-03-11
 */
public with sharing class FEC_HistoryController {
    
    /**
     * @description: Wrapper class to standardize history records across different objects
     */
    public class HistoryWrapper implements Comparable {
        @AuraEnabled public String historyId;
        @AuraEnabled public String actionText; // MỚI: Dành cho Update: DAT1
        @AuraEnabled public String fieldName;  // Dành cho Field Label
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
        @AuraEnabled public Datetime modifiedDate;
        @AuraEnabled public String modifiedByName;

        public Integer compareTo(Object compareTo) {
            HistoryWrapper other = (HistoryWrapper) compareTo;
            if (this.modifiedDate == null && other.modifiedDate == null) return 0;
            if (this.modifiedDate == null) return 1;
            if (other.modifiedDate == null) return -1;
            // DESC order: newer first
            if (this.modifiedDate > other.modifiedDate) return -1;
            if (this.modifiedDate < other.modifiedDate) return 1;
            return 0;
        }
    }

    /**
     * @description: Retrieves tracking history dynamically based on Object API Name
     * @param: Id recordId, String objectApiName
     * @return: List<HistoryWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getRecordHistory(String recordId, String objectApiName) {
        System.debug('[getRecordHistory] START');
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        
        try {
            String historyObjectName = objectApiName.endsWith('__c') ? 
                objectApiName.replace('__c', '__History') : 
                objectApiName + 'History';

            String parentField = objectApiName.endsWith('__c') ? 'ParentId' : objectApiName + 'Id';
            String parentNameField = objectApiName.endsWith('__c') ? 'Parent.Name' : objectApiName + '.Name';

            // =========================================================
            // BƯỚC MỚI: LẤY MAP FIELD CỦA OBJECT ĐỂ DỊCH API NAME SANG LABEL
            // =========================================================
            Map<String, Schema.SObjectField> fieldMap = new Map<String, Schema.SObjectField>();
            try {
                Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
                if (sObjType != null) {
                    fieldMap = sObjType.getDescribe().fields.getMap();
                }
            } catch (Exception e) {
                System.debug('Lỗi lấy Schema Describe: ' + e.getMessage());
            }
            // =========================================================

            String queryString = 'SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, ' + String.escapeSingleQuotes(parentNameField) + ' ' +
                                 'FROM ' + String.escapeSingleQuotes(historyObjectName);

            if (String.isNotBlank(recordId)) {
                queryString += ' WHERE ' + String.escapeSingleQuotes(parentField) + ' = :recordId ';
            }

            queryString += ' ORDER BY CreatedDate DESC LIMIT 50';

            List<SObject> lstSObj = Database.query(queryString);
            
            for (SObject obj : lstSObj) {
                HistoryWrapper wrapper = new HistoryWrapper();
                wrapper.historyId = (String) obj.get('Id');
                wrapper.modifiedDate = (Datetime) obj.get('CreatedDate');
                wrapper.modifiedByName = (String) ((SObject)obj.getSObject('CreatedBy')).get('Name');
                
                String rawFieldName = (String) obj.get('Field');
                String displayFieldName = rawFieldName;
                
                // Lấy Name của bản ghi để format chuỗi
                String recordName = 'Unknown';
                if (objectApiName.endsWith('__c')) {
                    SObject parentObj = obj.getSObject('Parent');
                    if (parentObj != null) recordName = (String) parentObj.get('Name');
                } else {
                    try {
                        SObject parentObj = obj.getSObject(objectApiName);
                        if (parentObj != null) recordName = (String) parentObj.get('Name');
                    } catch(Exception e) { /* fallback if field doesn't exist */ }
                }
                
                // THỎA MÃN YÊU CẦU: Tách Action và Field Name
                if (rawFieldName == 'created') {
                    wrapper.actionText = 'New: ' + recordName;
                    wrapper.fieldName = System.Label.FEC_Msg_HistoryFieldCreated;
                    wrapper.oldValue = '';
                    wrapper.newValue = System.Label.FEC_Msg_NewRecordCreated;
                } else {
                    if (fieldMap.containsKey(rawFieldName)) {
                        displayFieldName = fieldMap.get(rawFieldName).getDescribe().getLabel();
                    } else if (rawFieldName.endsWith('Id') && fieldMap.containsKey(rawFieldName.removeEnd('Id'))) {
                        displayFieldName = fieldMap.get(rawFieldName.removeEnd('Id')).getDescribe().getLabel();
                    }
                    
                    wrapper.actionText = 'Update: ' + recordName;
                    wrapper.fieldName = displayFieldName;
                    wrapper.oldValue = String.valueOf(obj.get('OldValue'));
                    wrapper.newValue = String.valueOf(obj.get('NewValue'));
                }
                
                historyList.add(wrapper);
            }
        } catch (Exception ex) {
            System.debug('[getRecordHistory] ERROR: ' + ex.getMessage());
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Load_History + ' ' + ex.getMessage());
        }
        
        System.debug('[getRecordHistory] RETURN: ' + historyList.size() + ' records');
        return historyList;
    }

    /**
     * @description Get history for all FEC_MDM_Master_Data_Setting__c records belonging to a NOC.
     * @param nocId Nature of Case Id
     * @return List<HistoryWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getSettingHistoryByNoc(String nocId) {
        return getSettingHistoryByIds(nocId, null);
    }

    /**
     * @description Get history for specific setting record IDs.
     * @param nocId Nature of Case Id
     * @param isIntegration null=all, true=fraud only, false=property only
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getSettingHistoryByIds(String nocId, Boolean isIntegration) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        if (String.isBlank(nocId)) return historyList;
        try {
            String q = 'SELECT Id, FEC_Additional_Field__r.Name, FEC_Data_Integration_Mapping__r.FEC_Int_Channel__c FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Nature_Of_Case__c = :nocId';
            if (isIntegration != null) {
                if (isIntegration) {
                    q += ' AND FEC_Data_Integration_Mapping__c != NULL';
                } else {
                    q += ' AND FEC_Data_Integration_Mapping__c = NULL';
                }
            }
            q += ' LIMIT 200';
            List<FEC_MDM_Master_Data_Setting__c> settings = Database.query(q);
            if (settings.isEmpty()) return historyList;

            // Build settingId → friendly display name map
            Map<Id, String> displayNameMap = new Map<Id, String>();
            Set<Id> settingIds = new Set<Id>();
            for (FEC_MDM_Master_Data_Setting__c s : settings) {
                settingIds.add(s.Id);
                String displayName = '';
                if (s.FEC_Additional_Field__r != null && String.isNotBlank(s.FEC_Additional_Field__r.Name)) {
                    displayName = s.FEC_Additional_Field__r.Name;
                } else if (s.FEC_Data_Integration_Mapping__r != null && String.isNotBlank(s.FEC_Data_Integration_Mapping__r.FEC_Int_Channel__c)) {
                    displayName = s.FEC_Data_Integration_Mapping__r.FEC_Int_Channel__c;
                }
                displayNameMap.put(s.Id, displayName);
            }

            Map<String, Schema.SObjectField> fieldMap = new Map<String, Schema.SObjectField>();
            try {
                fieldMap = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
            } catch (Exception e) { /* ignore */ }

            List<FEC_MDM_Master_Data_Setting__History> histories = [
                SELECT Id, ParentId, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, Parent.Name
                FROM FEC_MDM_Master_Data_Setting__History
                WHERE ParentId IN :settingIds
                ORDER BY CreatedDate DESC LIMIT 50
            ];
            for (FEC_MDM_Master_Data_Setting__History h : histories) {
                HistoryWrapper w = new HistoryWrapper();
                w.historyId = h.Id;
                w.modifiedDate = h.CreatedDate;
                w.modifiedByName = h.CreatedBy.Name;
                String rawField = h.Field;
                String fieldLabel = rawField;
                // Use friendly name if available, fallback to Parent.Name
                String recordDisplay = displayNameMap.containsKey(h.ParentId) && String.isNotBlank(displayNameMap.get(h.ParentId))
                    ? displayNameMap.get(h.ParentId)
                    : (h.Parent != null ? h.Parent.Name : '');
                if (rawField == 'created') {
                    w.actionText = 'New: ' + recordDisplay;
                    w.fieldName = 'Khởi tạo';
                } else {
                    if (fieldMap.containsKey(rawField)) {
                        fieldLabel = fieldMap.get(rawField).getDescribe().getLabel();
                    }
                    w.actionText = 'Update: ' + recordDisplay;
                    w.fieldName = fieldLabel;
                }
                w.oldValue = h.OldValue != null ? String.valueOf(h.OldValue) : '';
                w.newValue = h.NewValue != null ? String.valueOf(h.NewValue) : '';
                historyList.add(w);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error loading setting history: ' + ex.getMessage());
        }
        return historyList;
    }

    /**
     * @description Get history for specific Master Data Setting records (by Ids).
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getSettingHistoryBySettingIds(List<Id> settingIds) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        if (settingIds == null || settingIds.isEmpty()) return historyList;
        try {
            Map<String, Schema.SObjectField> fieldMap = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().fields.getMap();
            List<FEC_MDM_Master_Data_Setting__History> histories = [
                SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, Parent.Name
                FROM FEC_MDM_Master_Data_Setting__History
                WHERE ParentId IN :settingIds
                ORDER BY CreatedDate DESC LIMIT 50
            ];
            for (FEC_MDM_Master_Data_Setting__History h : histories) {
                HistoryWrapper w = new HistoryWrapper();
                w.historyId = h.Id;
                w.modifiedDate = h.CreatedDate;
                w.modifiedByName = h.CreatedBy.Name;
                String rawField = h.Field;
                if (rawField == 'created') {
                    w.actionText = 'New: ' + (h.Parent != null ? h.Parent.Name : '');
                    w.fieldName = 'Khởi tạo';
                } else {
                    String fieldLabel = fieldMap.containsKey(rawField) ? fieldMap.get(rawField).getDescribe().getLabel() : rawField;
                    w.actionText = 'Update: ' + (h.Parent != null ? h.Parent.Name : '');
                    w.fieldName = fieldLabel;
                }
                w.oldValue = h.OldValue != null ? String.valueOf(h.OldValue) : '';
                w.newValue = h.NewValue != null ? String.valueOf(h.NewValue) : '';
                historyList.add(w);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error loading history: ' + ex.getMessage());
        }
        return historyList;
    }

    /**
     * @description Get history for Decision Engine rules/conditions by Business Process Id.
     * Queries FEC_MDM_Decision_Rule__History and FEC_MDM_Decision_Condition__History
     * for rules matching the given businessProcessId and tableKey.
     * @param businessProcessId The Business Process Id (stored in FEC_Key_ID__c)
     * @param tableKey The table key filter (e.g. 'STAGE_TRANSITION')
     * @return List<HistoryWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getDecisionEngineHistory(String businessProcessId, String tableKey) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        if (String.isBlank(businessProcessId)) return historyList;
        try {
            // 1. Find all Decision Rules for this BP + tableKey, ordered by priority
            List<FEC_MDM_Decision_Rule__c> rules = [
                SELECT Id, Name, FEC_Priority__c
                FROM FEC_MDM_Decision_Rule__c
                WHERE FEC_Key_ID__c = :businessProcessId
                AND FEC_Table_Key__c = :tableKey
                ORDER BY FEC_Priority__c ASC NULLS LAST
                LIMIT 200
            ];
            if (rules.isEmpty()) return historyList;

            // Build Rule Id → display label map: "Rule #1", "Rule #2", ...
            Map<Id, String> ruleDisplayMap = new Map<Id, String>();
            Set<Id> ruleIds = new Set<Id>();
            Integer ruleIndex = 1;
            for (FEC_MDM_Decision_Rule__c r : rules) {
                ruleIds.add(r.Id);
                ruleDisplayMap.put(r.Id, 'Rule #' + ruleIndex);
                ruleIndex++;
            }

            // 2. Get Rule history
            Map<String, Schema.SObjectField> ruleFieldMap = FEC_MDM_Decision_Rule__c.SObjectType.getDescribe().fields.getMap();
            List<FEC_MDM_Decision_Rule__History> ruleHistories = [
                SELECT Id, ParentId, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, Parent.Name
                FROM FEC_MDM_Decision_Rule__History
                WHERE ParentId IN :ruleIds
                ORDER BY CreatedDate DESC LIMIT 50
            ];
            for (FEC_MDM_Decision_Rule__History h : ruleHistories) {
                String displayName = ruleDisplayMap.containsKey(h.ParentId) ? ruleDisplayMap.get(h.ParentId) : h.Parent.Name;
                historyList.add(buildHistoryWrapper(h.Id, h.Field, h.OldValue, h.NewValue,
                    h.CreatedDate, h.CreatedBy.Name, displayName, ruleFieldMap));
            }

            // 3. Get Conditions and build Condition Id → Rule display label map
            List<FEC_MDM_Decision_Condition__c> conditions = [
                SELECT Id, FEC_Decision_Rule__c
                FROM FEC_MDM_Decision_Condition__c
                WHERE FEC_Decision_Rule__c IN :ruleIds
                LIMIT 500
            ];
            if (!conditions.isEmpty()) {
                Set<Id> condIds = new Set<Id>();
                Map<Id, String> condDisplayMap = new Map<Id, String>();
                for (FEC_MDM_Decision_Condition__c c : conditions) {
                    condIds.add(c.Id);
                    String ruleName = ruleDisplayMap.containsKey(c.FEC_Decision_Rule__c) ? ruleDisplayMap.get(c.FEC_Decision_Rule__c) : '';
                    condDisplayMap.put(c.Id, ruleName);
                }

                Map<String, Schema.SObjectField> condFieldMap = FEC_MDM_Decision_Condition__c.SObjectType.getDescribe().fields.getMap();
                List<FEC_MDM_Decision_Condition__History> condHistories = [
                    SELECT Id, ParentId, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, Parent.Name
                    FROM FEC_MDM_Decision_Condition__History
                    WHERE ParentId IN :condIds
                    ORDER BY CreatedDate DESC LIMIT 50
                ];
                for (FEC_MDM_Decision_Condition__History h : condHistories) {
                    String displayName = condDisplayMap.containsKey(h.ParentId) ? condDisplayMap.get(h.ParentId) : h.Parent.Name;
                    historyList.add(buildHistoryWrapper(h.Id, h.Field, h.OldValue, h.NewValue,
                        h.CreatedDate, h.CreatedBy.Name, displayName, condFieldMap));
                }
            }

            // 4. Sort combined list by date DESC
            historyList.sort();
        } catch (Exception ex) {
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Load_History + ' ' + ex.getMessage());
        }
        return historyList;
    }

    /**
     * @description Get history for Properties Mapping records by Nature of Case Code.
     * @param natureOfCaseCode The NOC code to filter records
     * @return List<HistoryWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<HistoryWrapper> getPropertiesMappingHistory(String natureOfCaseCode) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        if (String.isBlank(natureOfCaseCode)) return historyList;
        try {
            List<FEC_Map_A_Properties_To_Master_Data_Item__c> records = [
                SELECT Id FROM FEC_Map_A_Properties_To_Master_Data_Item__c
                WHERE FEC_Nature_of_Case_Code__c = :natureOfCaseCode
                AND FEC_Is_Deleted__c = false
                LIMIT 200
            ];
            if (records.isEmpty()) return historyList;

            Set<Id> recordIds = new Set<Id>();
            for (FEC_Map_A_Properties_To_Master_Data_Item__c r : records) recordIds.add(r.Id);

            Map<String, Schema.SObjectField> fieldMap = FEC_Map_A_Properties_To_Master_Data_Item__c.SObjectType.getDescribe().fields.getMap();
            List<FEC_Map_A_Properties_To_Master_Data_Item__History> histories = [
                SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedBy.Name, Parent.Name
                FROM FEC_Map_A_Properties_To_Master_Data_Item__History
                WHERE ParentId IN :recordIds
                ORDER BY CreatedDate DESC LIMIT 50
            ];
            for (FEC_Map_A_Properties_To_Master_Data_Item__History h : histories) {
                historyList.add(buildHistoryWrapper(h.Id, h.Field, h.OldValue, h.NewValue,
                    h.CreatedDate, h.CreatedBy.Name, h.Parent != null ? h.Parent.Name : '', fieldMap));
            }
        } catch (Exception ex) {
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Load_History + ' ' + ex.getMessage());
        }
        return historyList;
    }

    /**
     * @description Helper to build a HistoryWrapper from raw history fields.
     */
    private static HistoryWrapper buildHistoryWrapper(
        String historyId, String rawField, Object oldValue, Object newValue,
        Datetime modifiedDate, String modifiedByName, String recordName,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        HistoryWrapper w = new HistoryWrapper();
        w.historyId = historyId;
        w.modifiedDate = modifiedDate;
        w.modifiedByName = modifiedByName;
        if (rawField == 'created') {
            w.actionText = 'New: ' + recordName;
            w.fieldName = System.Label.FEC_Msg_HistoryFieldCreated;
            w.oldValue = '';
            w.newValue = System.Label.FEC_Msg_NewRecordCreated;
        } else {
            String fieldLabel = rawField;
            if (fieldMap.containsKey(rawField)) {
                fieldLabel = fieldMap.get(rawField).getDescribe().getLabel();
            } else if (rawField.endsWith('Id') && fieldMap.containsKey(rawField.removeEnd('Id'))) {
                fieldLabel = fieldMap.get(rawField.removeEnd('Id')).getDescribe().getLabel();
            }
            w.actionText = 'Update: ' + recordName;
            w.fieldName = fieldLabel;
            w.oldValue = oldValue != null ? String.valueOf(oldValue) : '';
            w.newValue = newValue != null ? String.valueOf(newValue) : '';
        }
        return w;
    }
}