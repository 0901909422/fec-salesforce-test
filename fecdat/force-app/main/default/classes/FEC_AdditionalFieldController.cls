/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Additional_Field__c.
 * @date 2025-12-04
 * @author DAT NGO
 */
public with sharing class FEC_AdditionalFieldController {
    @TestVisible private static Boolean forceException = false;
    
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
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting record: ' + e.getMessage());
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
                500
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
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting Field List Value: ' + e.getMessage());
        }
    }
}