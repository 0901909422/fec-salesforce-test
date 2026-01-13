/**
 * Controller for LWC fec_customerAdditionalInfoList
 * Handles saving configuration and imported CSV data
 * @created      :  2025/12/31 trung.bui.4
 */
public with sharing class FEC_CustomerAdditionalInfoListController {

    /**
     * Save Config record and List of Detail records
     */
    @AuraEnabled
    public static String saveCustomerData(
        FEC_CustomerAdditionalInfoConfig__c objConfig,
        List<FEC_FileInfo> lstFiles
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            // 1. Lưu Header Config (Status mặc định là New)
            objConfig.FEC_Status__c = 'Uploaded'; 
            upsert objConfig;

            // 2. Lưu File vào ContentVersion
            if (lstFiles != null && !lstFiles.isEmpty()) {
                List<ContentVersion> cvList = new List<ContentVersion>();
                for(FEC_FileInfo file : lstFiles) {
                    if(String.isNotBlank(file.base64Data) && String.isNotBlank(file.sheetXml)) {
                        ContentVersion cvExcel = new ContentVersion();
                        cvExcel.Title = file.name; 
                        cvExcel.PathOnClient = file.name;
                        cvExcel.VersionData = EncodingUtil.base64Decode(file.base64Data);
                        cvExcel.Description = 'Original_User_Upload';
                        cvExcel.FEC_Comments__c = 'Uploaded';
                        cvExcel.FirstPublishLocationId = objConfig.Id;
                        cvList.add(cvExcel);

                        ContentVersion cvJson = new ContentVersion();
                        cvJson.Title = file.name + '.json';
                        cvJson.PathOnClient = file.name + '.json';
                        cvJson.VersionData = Blob.valueOf(file.sheetXml);
                        cvJson.Description = 'JSON_Data_For_Processing';
                        cvJson.FEC_Comments__c = 'Uploaded';
                        cvJson.FirstPublishLocationId = objConfig.Id; 
                        cvList.add(cvJson);
                    }
                }
                insert cvList;
            }
            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get list of uploaded configurations
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_CustomerAdditionalInfoConfig__c> getUploadedConfigs() {
        return [
            SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c, FEC_FieldName__c, 
                   FEC_StartDate__c, FEC_EndDate__c, FEC_Status__c, FEC_IsActive__c,
                   CreatedDate, CreatedBy.Name
            FROM FEC_CustomerAdditionalInfoConfig__c
            WHERE FEC_Status__c = 'Uploaded' 
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_CustomerAdditionalInfoConfig__c> getExistingConfigs() {
        return [SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c, FEC_FieldName__c, FEC_Status__c, FEC_IsActive__c, FEC_StartDate__c, FEC_EndDate__c 
                FROM FEC_CustomerAdditionalInfoConfig__c 
                WHERE FEC_Status__c = 'Processed' 
                ORDER BY CreatedDate DESC];
    }

    /**
     * Lấy danh sách các file liên quan đến bản ghi Config
     * @param recordId ID của bản ghi FEC_CustomerAdditionalInfoConfig__c
     * @return List<Map<String, Object>> Danh sách thông tin file
     * @created: 2026/01/02 trung.bui.4
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRelatedFiles(Id recordId) {
        List<Map<String, Object>> lstFiles = new List<Map<String, Object>>();
        
        // 1. Truy vấn các ContentDocumentLink liên quan
        for (ContentDocumentLink objLink : [
            SELECT ContentDocumentId, 
               ContentDocument.Title, 
               ContentDocument.CreatedBy.Name, 
               ContentDocument.LastModifiedDate,
               ContentDocument.LatestPublishedVersion.FEC_Comments__c
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.LatestPublishedVersion.Description = 'Original_User_Upload'
        ]) {
            Map<String, Object> mapFile = new Map<String, Object>();
            mapFile.put('id', objLink.ContentDocumentId);
            mapFile.put('name', objLink.ContentDocument.Title);
            mapFile.put('uploadedBy', objLink.ContentDocument.CreatedBy.Name);
            mapFile.put('uploadedTime', objLink.ContentDocument.LastModifiedDate);
            mapFile.put('status', objLink.ContentDocument.LatestPublishedVersion.FEC_Comments__c);
            lstFiles.add(mapFile);
        }
        return lstFiles;
    }

    @AuraEnabled
    public static void deleteFile(Id documentId) {
        try {
            if (documentId != null) {
                // Xóa ContentDocument sẽ tự động xóa các ContentVersion và Link liên quan
                delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
            }
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi xóa file trên hệ thống: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Boolean checkDuplicateConfig(String keyId, String fieldId, Id currentConfigId) {
        // Tìm kiếm các bản ghi có cùng Key và Field, loại trừ bản ghi hiện tại nếu đang ở chế độ Edit
        Integer count = [
            SELECT count() 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE FEC_KeyIdentifier__c = :keyId 
            AND FEC_FieldID__c = :fieldId 
            AND Id != :currentConfigId
        ];
        System.debug(System.LoggingLevel.DEBUG, 'FEC_CustomerAdditionalInfoConfig__c duplicated length: ' + count);
        return count > 0;
    }

    /**
     * Lấy lịch sử thay đổi của một Config cụ thể
     * @param configId ID của bản ghi Config
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_CustomerDataConfigHistory__c> getConfigHistory(Id configId) {
        return [
            SELECT Id, 
                   FEC_KeyIdentifier__c, 
                   FEC_FieldID__c, 
                   FEC_Status__c, 
                   FEC_IsActive__c, 
                   FEC_StartDate__c, 
                   FEC_EndDate__c,
                   CreatedDate, 
                   CreatedBy.Name,
                   LastModifiedDate,
                   LastModifiedBy.Name
            FROM FEC_CustomerDataConfigHistory__c
            WHERE FEC_Customers_Data_Config__c = :configId
            ORDER BY CreatedDate DESC
        ];
    }
}