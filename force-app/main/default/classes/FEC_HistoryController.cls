/**
 * @description: Dynamic Controller to fetch Standard History for any Object
 * @author: DAT NGO
 * @date: 2026-03-11
 */
public with sharing class FEC_HistoryController {

    // ── Test injection points (allow unit tests to mock __History via @TestVisible helpers).
    //   Note: __History SObjects can't be instantiated in Apex, so we expose helper methods
    //   for direct unit testing of the wrapper-building/format logic instead.
    
    /**
     * @description Helper for testing: build HistoryWrapper directly from primitive fields,
     *              bypassing the need for actual __History SObjects (which can't be created in Apex).
     */
    @TestVisible
    private static HistoryWrapper buildHistoryWrapperForTest(
        String historyId, String rawField, String oldValue, String newValue,
        Datetime modifiedDate, String modifiedByName, String recordName,
        String objectApiName
    ) {
        Map<String, Schema.SObjectField> fieldMap = new Map<String, Schema.SObjectField>();
        try {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType != null) fieldMap = sObjType.getDescribe().fields.getMap();
        } catch (Exception e) { /* ignore */ }
        return buildHistoryWrapper(historyId, rawField, oldValue, newValue, modifiedDate, modifiedByName, recordName, fieldMap);
    }

    /**
     * @description Helper for testing isLikelySalesforceId / formatBooleanValue private methods.
     */
    @TestVisible
    private static Boolean isLikelySalesforceIdForTest(String value) {
        return isLikelySalesforceId(value);
    }

    @TestVisible
    private static String formatBooleanValueForTest(String value) {
        return formatBooleanValue(value);
    }
    
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
            // Convert SObjects to simple maps (testable)
            List<Map<String, Object>> rawRows = new List<Map<String, Object>>();
            for (SObject obj : lstSObj) {
                Map<String, Object> row = new Map<String, Object>{
                    'Id' => obj.get('Id'),
                    'Field' => obj.get('Field'),
                    'OldValue' => obj.get('OldValue'),
                    'NewValue' => obj.get('NewValue'),
                    'CreatedDate' => obj.get('CreatedDate')
                };
                try {
                    SObject createdBy = obj.getSObject('CreatedBy');
                    row.put('CreatedByName', createdBy != null ? (String) createdBy.get('Name') : '');
                } catch (Exception e) { row.put('CreatedByName', ''); }
                String recordName = 'Unknown';
                if (objectApiName.endsWith('__c')) {
                    try {
                        SObject parentObj = obj.getSObject('Parent');
                        if (parentObj != null) recordName = (String) parentObj.get('Name');
                    } catch (Exception e) { /* ignore */ }
                } else {
                    try {
                        SObject parentObj = obj.getSObject(objectApiName);
                        if (parentObj != null) recordName = (String) parentObj.get('Name');
                    } catch (Exception e) { /* ignore */ }
                }
                row.put('RecordName', recordName);
                rawRows.add(row);
            }
            historyList = transformRecordHistory(rawRows, fieldMap);

            // Re-sort after dedup since map iteration order is not guaranteed
            historyList.sort();
        } catch (Exception ex) {
            System.debug('[getRecordHistory] ERROR: ' + ex.getMessage());
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Load_History + ' ' + ex.getMessage());
        }
        
        System.debug('[getRecordHistory] RETURN: ' + historyList.size() + ' records');
        return historyList;
    }

    /**
     * @description Transform raw history rows (extracted from __History SObjects) into HistoryWrapper list,
     *              with dedup of raw-Id vs friendly-Name duplicates. Extracted for unit testability since
     *              __History SObjects can't be instantiated in Apex tests.
     */
    @TestVisible
    private static List<HistoryWrapper> transformRecordHistory(
        List<Map<String, Object>> rawRows,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();

        // ── Deduplicate: Salesforce History Tracking sometimes creates 2 entries for the same
        //    lookup field change — one with raw ID, one with friendly Name (same CreatedDate).
        //    We keep only the friendly-name version and discard the raw-ID duplicate.
        Map<String, Map<String, Object>> dedupMap = new Map<String, Map<String, Object>>();
        for (Map<String, Object> row : rawRows) {
            String fieldName = (String) row.get('Field');
            Datetime cd = (Datetime) row.get('CreatedDate');
            String groupKey = fieldName + '|' + (cd != null ? String.valueOf(cd.getTime() / 1000) : '');
            String newVal = row.get('NewValue') != null ? String.valueOf(row.get('NewValue')) : '';
            if (!dedupMap.containsKey(groupKey)) {
                dedupMap.put(groupKey, row);
            } else {
                Map<String, Object> existing = dedupMap.get(groupKey);
                String existingNewVal = existing.get('NewValue') != null ? String.valueOf(existing.get('NewValue')) : '';
                if (isLikelySalesforceId(existingNewVal) && !isLikelySalesforceId(newVal)) {
                    dedupMap.put(groupKey, row);
                }
            }
        }

        for (Map<String, Object> row : dedupMap.values()) {
            HistoryWrapper wrapper = new HistoryWrapper();
            wrapper.historyId = (String) row.get('Id');
            wrapper.modifiedDate = (Datetime) row.get('CreatedDate');
            wrapper.modifiedByName = row.get('CreatedByName') != null ? (String) row.get('CreatedByName') : '';
            
            String rawFieldName = (String) row.get('Field');
            String displayFieldName = rawFieldName;
            String recordName = row.get('RecordName') != null ? (String) row.get('RecordName') : 'Unknown';
            
            if (rawFieldName == 'created') {
                wrapper.actionText = 'New: ' + recordName;
                wrapper.fieldName = System.Label.FEC_Msg_HistoryFieldCreated;
                wrapper.oldValue = '';
                wrapper.newValue = System.Label.FEC_Msg_NewRecordCreated;
            } else {
                if (fieldMap.containsKey(rawFieldName)) {
                    displayFieldName = fieldMap.get(rawFieldName).getDescribe().getLabel();
                } else if (rawFieldName != null && rawFieldName.endsWith('Id') && fieldMap.containsKey(rawFieldName.removeEnd('Id'))) {
                    displayFieldName = fieldMap.get(rawFieldName.removeEnd('Id')).getDescribe().getLabel();
                }
                
                wrapper.actionText = 'Update: ' + recordName;
                wrapper.fieldName = displayFieldName;
                String rawOld = row.get('OldValue') != null ? String.valueOf(row.get('OldValue')) : '';
                String rawNew = row.get('NewValue') != null ? String.valueOf(row.get('NewValue')) : '';
                // Convert boolean (Checkbox) values to friendly Checked/Unchecked
                if (fieldMap.containsKey(rawFieldName)
                    && fieldMap.get(rawFieldName).getDescribe().getType() == Schema.DisplayType.Boolean) {
                    wrapper.oldValue = formatBooleanValue(rawOld);
                    wrapper.newValue = formatBooleanValue(rawNew);
                } else {
                    wrapper.oldValue = rawOld;
                    wrapper.newValue = rawNew;
                }
            }
            
            historyList.add(wrapper);
        }
        return historyList;
    }

    /**
     * @description Transform simple history rows (without dedup) into HistoryWrapper list.
     *              Used by setting/decision/properties history methods.
     */
    @TestVisible
    private static List<HistoryWrapper> transformSimpleHistory(
        List<Map<String, Object>> rawRows,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        List<HistoryWrapper> historyList = new List<HistoryWrapper>();
        for (Map<String, Object> row : rawRows) {
            HistoryWrapper w = new HistoryWrapper();
            w.historyId = (String) row.get('Id');
            w.modifiedDate = (Datetime) row.get('CreatedDate');
            w.modifiedByName = row.get('CreatedByName') != null ? (String) row.get('CreatedByName') : '';
            String rawField = (String) row.get('Field');
            String recordName = row.get('RecordName') != null ? (String) row.get('RecordName') : '';
            if (rawField == 'created') {
                w.actionText = 'New: ' + recordName;
                w.fieldName = System.Label.FEC_Msg_HistoryFieldCreated;
                w.oldValue = '';
                w.newValue = System.Label.FEC_Msg_NewRecordCreated;
            } else {
                String fieldLabel = (fieldMap != null && fieldMap.containsKey(rawField))
                    ? fieldMap.get(rawField).getDescribe().getLabel()
                    : rawField;
                w.actionText = 'Update: ' + recordName;
                w.fieldName = fieldLabel;
                String rawOld = row.get('OldValue') != null ? String.valueOf(row.get('OldValue')) : '';
                String rawNew = row.get('NewValue') != null ? String.valueOf(row.get('NewValue')) : '';
                if (fieldMap != null && fieldMap.containsKey(rawField)
                    && fieldMap.get(rawField).getDescribe().getType() == Schema.DisplayType.Boolean) {
                    w.oldValue = formatBooleanValue(rawOld);
                    w.newValue = formatBooleanValue(rawNew);
                } else {
                    w.oldValue = rawOld;
                    w.newValue = rawNew;
                }
            }
            historyList.add(w);
        }
        return historyList;
    }

    /**
     * @description Convert boolean string ('true'/'false'/'null'/'') to friendly display.
     * Used for Checkbox fields in history display so user sees Checked/Unchecked instead of true/false.
     */
    private static String formatBooleanValue(String value) {
        if (String.isBlank(value) || value == 'null') return 'Unchecked';
        String normalized = value.toLowerCase();
        if (normalized == 'true') return 'Checked';
        if (normalized == 'false') return 'Unchecked';
        return value;
    }

    /**
     * @description Detect if a String value looks like a raw Salesforce Id (15 or 18 chars, alphanumeric).
     * Used to filter duplicate history entries where Salesforce tracks both raw Id + friendly Name.
     */
    private static Boolean isLikelySalesforceId(String value) {
        if (String.isBlank(value)) return false;
        Integer len = value.length();
        if (len != 15 && len != 18) return false;
        // Must be alphanumeric only
        Pattern p = Pattern.compile('^[a-zA-Z0-9]+$');
        return p.matcher(value).matches();
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
            // Convert to plain rows for testable transform
            List<Map<String, Object>> rawRows = new List<Map<String, Object>>();
            for (FEC_MDM_Master_Data_Setting__History h : histories) {
                String parentName = h.Parent != null ? h.Parent.Name : '';
                String displayName = displayNameMap.containsKey(h.ParentId) && String.isNotBlank(displayNameMap.get(h.ParentId))
                    ? displayNameMap.get(h.ParentId)
                    : parentName;
                rawRows.add(new Map<String, Object>{
                    'Id' => h.Id,
                    'Field' => h.Field,
                    'OldValue' => h.OldValue,
                    'NewValue' => h.NewValue,
                    'CreatedDate' => h.CreatedDate,
                    'CreatedByName' => (h.CreatedBy != null ? h.CreatedBy.Name : ''),
                    'RecordName' => displayName
                });
            }
            historyList = transformSimpleHistory(rawRows, fieldMap);
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
            List<Map<String, Object>> rawRows = new List<Map<String, Object>>();
            for (FEC_MDM_Master_Data_Setting__History h : histories) {
                rawRows.add(new Map<String, Object>{
                    'Id' => h.Id,
                    'Field' => h.Field,
                    'OldValue' => h.OldValue,
                    'NewValue' => h.NewValue,
                    'CreatedDate' => h.CreatedDate,
                    'CreatedByName' => (h.CreatedBy != null ? h.CreatedBy.Name : ''),
                    'RecordName' => (h.Parent != null ? h.Parent.Name : '')
                });
            }
            historyList = transformSimpleHistory(rawRows, fieldMap);
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
            String rawOld = oldValue != null ? String.valueOf(oldValue) : '';
            String rawNew = newValue != null ? String.valueOf(newValue) : '';
            // Convert boolean (Checkbox) values to friendly Checked/Unchecked
            if (fieldMap.containsKey(rawField)
                && fieldMap.get(rawField).getDescribe().getType() == Schema.DisplayType.Boolean) {
                w.oldValue = formatBooleanValue(rawOld);
                w.newValue = formatBooleanValue(rawNew);
            } else {
                w.oldValue = rawOld;
                w.newValue = rawNew;
            }
        }
        return w;
    }
}