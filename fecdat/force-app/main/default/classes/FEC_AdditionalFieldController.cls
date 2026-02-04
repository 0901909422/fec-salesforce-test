/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Additional_Field__c.
 * @date 2025-12-04
 * @author DAT NGO
 */
public with sharing class FEC_AdditionalFieldController {
    // Use centralized constants from FEC_Constants (messages still backed by Custom Labels)
    // Refer to FEC_Constants.OPERATION_SUCCESS, FEC_Constants.QUERY_LIMIT, etc.
    
    /**
     * @description Xóa bản ghi Additional Field.
     * @param recordId ID của bản ghi cần xóa.
     * @return String 'Success' hoặc thông báo lỗi.
     */
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        try {
            FEC_MDM_Additional_Field__c recordToDelete = new FEC_MDM_Additional_Field__c(Id = recordId);
            delete recordToDelete;
            return FEC_Constants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + e.getMessage());
        }
    }
    
    /**
     * @description Lấy danh sách các bản ghi Additional Field.
     * @return List<FEC_MDM_Additional_Field__c> Danh sách các bản ghi.
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field__c> getAdditionalFields() {
        List<FEC_MDM_Additional_Field__c> fields = [
               SELECT 
                Id, 
                Name, 
                FEC_Unique_ID__c,
                FEC_Name_VN__c, 
                FEC_Type__c,
                FEC_Field_Status__c,
                FEC_Field_Mandatory__c,
                Process_Change_Status__c,
                CreatedDate
            FROM 
                FEC_MDM_Additional_Field__c 
            ORDER BY 
                CreatedDate DESC 
            LIMIT 
                :FEC_Constants.QUERY_LIMIT
            ];
        
        return fields;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Additional_Field_List_Value__c> getFieldListValues(String selectedFieldId) {
        return [
                        SELECT Id, Name, FEC_Name_VN__c, FEC_Order__c, FEC_Additional_Field__c, Process_Change_Status__c
                        FROM FEC_MDM_Additional_Field_List_Value__c
                        WHERE FEC_Additional_Field__c = :selectedFieldId
                        ORDER BY FEC_Order__c ASC NULLS LAST
                    ];
    }
    
    @AuraEnabled
    public static String deleteFieldListValue(Id recordId) {
        try {
            delete [SELECT Id FROM FEC_MDM_Additional_Field_List_Value__c WHERE Id = :recordId];
            return FEC_Constants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_FIELDLIST_PREFIX + e.getMessage());
        }
    }
}
