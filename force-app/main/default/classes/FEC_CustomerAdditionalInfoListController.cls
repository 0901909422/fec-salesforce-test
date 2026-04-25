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
            if (objConfig.Id == null) {
                objConfig.FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS;
            } else if (objConfig.FEC_Status__c == FEC_ConstantCommon.PROCESSED_STATUS 
                       || objConfig.FEC_Status__c == FEC_ConstantCommon.FAILURE_STATUS) {
                objConfig.FEC_Status__c = FEC_ConstantCommon.REUPLOADED_STATUS;
            }
            upsert objConfig;

            if (lstFiles != null && !lstFiles.isEmpty()) {
                List<ContentVersion> cvList = new List<ContentVersion>();
                for(FEC_FileInfo file : lstFiles) {
                    if(String.isNotBlank(file.base64Data) && String.isNotBlank(file.sheetXml)) {
                        ContentVersion cvExcel = new ContentVersion();
                        cvExcel.Title = file.name; 
                        cvExcel.PathOnClient = file.name;
                        cvExcel.VersionData = EncodingUtil.base64Decode(file.base64Data);
                        cvExcel.Description = FEC_ConstantCommon.ORIGINAL_USER_UPLOAD;
                        cvExcel.FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS;
                        cvExcel.FirstPublishLocationId = objConfig.Id;
                        cvList.add(cvExcel);

                        ContentVersion cvJson = new ContentVersion();
                        cvJson.Title = file.name + FEC_ConstantCommon.JSON_EXTENSION;
                        cvJson.PathOnClient = file.name + FEC_ConstantCommon.JSON_EXTENSION;
                        cvJson.VersionData = Blob.valueOf(file.sheetXml);
                        cvJson.Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING;
                        cvJson.FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS;
                        cvJson.FirstPublishLocationId = objConfig.Id; 
                        cvList.add(cvJson);
                    }
                }
                insert cvList;
            }
            return FEC_ConstantCommon.SUCCESS_MESSAGE;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Trigger batch processing immediately
     * @return Success message from Custom Label
     */
    @AuraEnabled
    public static String triggerBatchProcessing() {
        try {
            Database.executeBatch(new FEC_ProcessCustomerDataBatch());
            return System.Label.FEC_Process_Now_Success;
        } catch (Exception e) {
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
                   CreatedDate, CreatedBy.Name, LastModifiedDate
            FROM FEC_CustomerAdditionalInfoConfig__c
            WHERE FEC_Status__c IN :FEC_ConstantCommon.PENDING_STATUSES 
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<FEC_CustomerAdditionalInfoConfig__c> getExistingConfigs() {
        return [SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c, FEC_FieldName__c, FEC_Status__c, FEC_IsActive__c, FEC_StartDate__c, FEC_EndDate__c 
                FROM FEC_CustomerAdditionalInfoConfig__c 
                WHERE FEC_Status__c IN :FEC_ConstantCommon.PROCESSED_STATUSES 
                ORDER BY CreatedDate DESC];
    }

    /**
     * Lấy danh sách các file liên quan đến bản ghi Config
     * @param recordId ID của bản ghi FEC_CustomerAdditionalInfoConfig__c
     * @return List<Map<String, Object>> Danh sách thông tin file
     * @created: 2026/01/02 trung.bui.4
     */
    @AuraEnabled(cacheable=false)
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
            AND ContentDocument.LatestPublishedVersion.Description = :FEC_ConstantCommon.ORIGINAL_USER_UPLOAD
        ]) {
            Map<String, Object> mapFile = new Map<String, Object>();
            mapFile.put(FEC_ConstantCommon.KEY_ID, objLink.ContentDocumentId);
            mapFile.put(FEC_ConstantCommon.KEY_NAME, objLink.ContentDocument.Title);
            mapFile.put(FEC_ConstantCommon.KEY_UPLOADED_BY, objLink.ContentDocument.CreatedBy.Name);
            mapFile.put(FEC_ConstantCommon.KEY_UPLOADED_TIME, objLink.ContentDocument.LastModifiedDate);
            mapFile.put(FEC_ConstantCommon.KEY_STATUS, objLink.ContentDocument.LatestPublishedVersion.FEC_Comments__c);
            lstFiles.add(mapFile);
        }
        return lstFiles;
    }

    /**
     * Soft delete Config — cập nhật trạng thái sang Cancelled thay vì xóa bản ghi
     * @param configId ID của bản ghi FEC_CustomerAdditionalInfoConfig__c cần xóa
     */
    @AuraEnabled
    public static void deleteConfig(Id configId) {
        Savepoint sp = Database.setSavepoint(); 
        
        try {
            if (configId != null) {
                FEC_CustomerAdditionalInfoConfig__c config = [
                    SELECT Id, FEC_Status__c 
                    FROM FEC_CustomerAdditionalInfoConfig__c 
                    WHERE Id = :configId 
                    LIMIT 1
                ];

                if (!FEC_ConstantCommon.DELETABLE_STATUSES.contains(config.FEC_Status__c)) {
                    throw new AuraHandledException(System.Label.FEC_Error_Cannot_Delete_Status);
                }

                config.FEC_Status__c = FEC_ConstantCommon.CANCELLED_STATUS;
                update config;
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteFile(Id documentId) {
        try {
            if (documentId != null) {
                delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
            }
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Message_Deleting_File + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Boolean checkDuplicateConfig(String keyId, String fieldId, Id currentConfigId) {
        Integer count = [
            SELECT count() 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE FEC_KeyIdentifier__c = :keyId 
            AND FEC_FieldID__c = :fieldId 
            AND Id != :currentConfigId
        ];
        return count > 0;
    }

    /**
     * Lấy lịch sử thay đổi của một Config cụ thể
     * Sắp xếp theo CreatedDate DESC, nếu cùng thời gian thì theo status flow (Processed > Processing > Reuploaded > Uploaded)
     * @param configId ID của bản ghi Config
     */
    @AuraEnabled(cacheable=false)
    public static List<FEC_CustomerDataConfigHistory__c> getConfigHistory(Id configId) {
        List<FEC_CustomerDataConfigHistory__c> lstHistory = [
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

        // Sort phụ theo status priority khi CreatedDate giống nhau
        Map<String, Integer> mapStatusOrder = new Map<String, Integer>{
            'Processed' => 0,
            'Reprocess' => 1,
            'Processing' => 2,
            'Failure' => 3,
            'Cancelled' => 4,
            'Reuploaded' => 5,
            'Uploaded' => 6
        };

        lstHistory.sort(new HistoryComparator(mapStatusOrder));
        return lstHistory;
    }

    /**
     * Comparator để sort history: CreatedDate DESC, rồi status priority ASC
     */
    private class HistoryComparator implements Comparator<FEC_CustomerDataConfigHistory__c> {
        private Map<String, Integer> statusOrder;

        public HistoryComparator(Map<String, Integer> statusOrder) {
            this.statusOrder = statusOrder;
        }

        public Integer compare(FEC_CustomerDataConfigHistory__c a, FEC_CustomerDataConfigHistory__c b) {
            // CreatedDate DESC
            if (a.CreatedDate > b.CreatedDate) return -1;
            if (a.CreatedDate < b.CreatedDate) return 1;

            // Cùng CreatedDate → sort theo status priority (số nhỏ lên trước)
            Integer orderA = statusOrder.containsKey(a.FEC_Status__c) ? statusOrder.get(a.FEC_Status__c) : 99;
            Integer orderB = statusOrder.containsKey(b.FEC_Status__c) ? statusOrder.get(b.FEC_Status__c) : 99;
            return orderA - orderB;
        }
    }
}