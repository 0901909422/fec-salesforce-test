/**
 * @description: Dynamic Controller to fetch Standard History for any Object
 * @author: DAT NGO
 * @date: 2026-03-11
 */
public with sharing class FEC_HistoryController {
    
    /**
     * @description: Wrapper class to standardize history records across different objects
     */
    public class HistoryWrapper {
        @AuraEnabled public String historyId;
        @AuraEnabled public String actionText; // MỚI: Dành cho Update: DAT1
        @AuraEnabled public String fieldName;  // Dành cho Field Label
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
        @AuraEnabled public Datetime modifiedDate;
        @AuraEnabled public String modifiedByName;
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
}