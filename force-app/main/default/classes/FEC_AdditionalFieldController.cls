/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Additional_Field__c.
 * @date 2025-12-04
 * @author DAT NGO
 */
public with sharing class FEC_AdditionalFieldController {
    // Centralized constants used from FEC_Constants
    
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' Invalid Id');
        }
        try {
            delete new FEC_MDM_Additional_Field__c(Id = recordId);
            return FEC_Constants.OPERATION_SUCCESS;
        } catch (Exception e) {
            System.debug('FEC_AdditionalFieldController.deleteRecord error: ' + e);
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field__c> getAdditionalFields() {
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT Id, Name, FEC_Unique_ID__c, FEC_Name_VN__c, FEC_Type__c,
                   FEC_Field_Status__c, FEC_Field_Mandatory__c, Process_Change_Status__c, CreatedDate
            FROM FEC_MDM_Additional_Field__c
            ORDER BY CreatedDate DESC
            LIMIT :FEC_Constants.QUERY_LIMIT
        ];
        // Enforce field-level security before returning
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        return (List<FEC_MDM_Additional_Field__c>) safe;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field_List_Value__c> getFieldListValues(Id selectedFieldId) {
        if (selectedFieldId == null) return new List<FEC_MDM_Additional_Field_List_Value__c>();
        List<FEC_MDM_Additional_Field_List_Value__c> values = [
            SELECT Id, Name, FEC_Name_VN__c, FEC_Order__c, FEC_Additional_Field__c, Process_Change_Status__c
            FROM FEC_MDM_Additional_Field_List_Value__c
            WHERE FEC_Additional_Field__c = :selectedFieldId
            ORDER BY FEC_Order__c ASC NULLS LAST
            LIMIT :FEC_Constants.QUERY_LIMIT
        ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, values).getRecords();
        return (List<FEC_MDM_Additional_Field_List_Value__c>) safe;
    }
    
    @AuraEnabled
    public static String deleteFieldListValue(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_FIELDLIST_PREFIX + ' Invalid Id');
        }
        try {
            delete [SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c WHERE Id = :recordId];
            return FEC_Constants.OPERATION_SUCCESS;
        } catch (Exception e) {
            System.debug('FEC_AdditionalFieldController.deleteFieldListValue error: ' + e);
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_FIELDLIST_PREFIX + ' ' + e.getMessage());
        }
    }
}
