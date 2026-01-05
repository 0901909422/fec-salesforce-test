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
                    if(String.isNotBlank(file.base64Data)) {
                        cvList.add(new ContentVersion(
                            Title = file.name,
                            PathOnClient = file.name,
                            VersionData = EncodingUtil.base64Decode(file.base64Data),
                            IsMajorVersion = false,
                            Description = 'Uploaded',
                            FEC_Comments__c = file.sheetXml
                        ));
                    }
                }
                insert cvList;

                // 3. Liên kết File với Config record
                List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
                for(ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvList]) {
                    cdlList.add(new ContentDocumentLink(
                        LinkedEntityId = objConfig.Id,
                        ContentDocumentId = cv.ContentDocumentId,
                        ShareType = 'V'
                    ));
                }
                insert cdlList;
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
               ContentDocument.LatestPublishedVersion.Description
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ]) {
            Map<String, Object> mapFile = new Map<String, Object>();
            mapFile.put('id', objLink.ContentDocumentId);
            mapFile.put('name', objLink.ContentDocument.Title);
            mapFile.put('uploadedBy', objLink.ContentDocument.CreatedBy.Name);
            mapFile.put('uploadedTime', objLink.ContentDocument.LastModifiedDate);
            mapFile.put('status', objLink.ContentDocument.LatestPublishedVersion.Description);
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
}