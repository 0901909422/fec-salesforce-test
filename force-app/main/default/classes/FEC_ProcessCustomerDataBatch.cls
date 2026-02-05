/**
 * Batch xử lý tổng hợp: Quét Config New, Parse Excel và Update trạng thái
 * @created      : 2025/12/31 trung.bui.4
 */
global class FEC_ProcessCustomerDataBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    private Integer totalRecordsProcessed = 0;

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_ProcessCustomerDataBatch(), 1); 
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE FEC_Status__c = :FEC_ConstantCommon.UPLOADED_STATUS
        ]);
    }

    global void execute(Database.BatchableContext bc, List<FEC_CustomerAdditionalInfoConfig__c> scope) {
        List<ContentVersion> lstCVToUpdate = new List<ContentVersion>();
        List<FEC_CustomerAdditionalInfoConfig__c> lstConfigToUpdate = new List<FEC_CustomerAdditionalInfoConfig__c>();
        Set<Id> contentDocIdsToDelete = new Set<Id>();

        for (FEC_CustomerAdditionalInfoConfig__c config : scope) {
            try {
                List<ContentDocumentLink> links = [
                    SELECT ContentDocumentId, 
                           ContentDocument.LatestPublishedVersionId, 
                           ContentDocument.LatestPublishedVersion.VersionData,
                           ContentDocument.LatestPublishedVersion.Title,
                           ContentDocument.LatestPublishedVersion.Description
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :config.Id 
                    AND ContentDocument.LatestPublishedVersion.FEC_Comments__c = :FEC_ConstantCommon.UPLOADED_STATUS
                ];

                ContentVersion jsonFileToProcess = null;
                Id jsonDocId = null;

                for (ContentDocumentLink link : links) {
                    ContentVersion cv = link.ContentDocument.LatestPublishedVersion;
                    
                    if (cv.Description == FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING) {
                        jsonFileToProcess = cv;
                        jsonDocId = link.ContentDocumentId;
                    } else {
                        lstCVToUpdate.add(new ContentVersion(
                            Id = cv.Id,
                            FEC_Comments__c = FEC_ConstantCommon.PROCESSED_STATUS
                        ));
                    }
                }

                if (jsonDocId != null && jsonFileToProcess != null) {
                    String jsonString = jsonFileToProcess.VersionData.toString(); 
                    List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonString);
                    List<FEC_CustomerAdditionalInfo__c> batchToInsert = new List<FEC_CustomerAdditionalInfo__c>();

                    for (Integer i = 1; i < rows.size(); i++) {
                        List<Object> cols = (List<Object>) rows[i];
                        if (cols.size() < 3) continue; 

                        FEC_CustomerAdditionalInfo__c detail = new FEC_CustomerAdditionalInfo__c(
                            FEC_Config__c = config.Id,
                            FEC_KeyIdentifier__c = config.FEC_KeyIdentifier__c,
                            FEC_FieldID__c = config.FEC_FieldID__c,
                            FEC_KeyIDValue__c = String.valueOf(cols[0]),
                            FEC_FieldValue__c = String.valueOf(cols[1]),
                            FEC_IsActive__c = cols[2] == FEC_ConstantCommon.YES_VALUE,
                            FEC_LinkedFilename__c = jsonFileToProcess.Title
                        );
                        
                        batchToInsert.add(detail);

                        // Chunking nếu file chứa hơn 2000 rows
                        if (batchToInsert.size() >= 2000) {
                            insert batchToInsert;
                            totalRecordsProcessed += batchToInsert.size();
                            batchToInsert.clear();
                        }
                    }

                    if (!batchToInsert.isEmpty()) {
                        insert batchToInsert;
                        totalRecordsProcessed += batchToInsert.size();
                    }
                    config.FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS;
                    contentDocIdsToDelete.add(jsonDocId);
                } else {
                    System.debug('Cảnh báo: Không tìm thấy file JSON data cho Config ' + config.Id);
                }

            } catch (Exception e) {
                System.debug('Lỗi Batch Config ' + config.Id + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
            }
            
            lstConfigToUpdate.add(config);
        }

        if (!lstCVToUpdate.isEmpty()) update lstCVToUpdate;
        if (!lstConfigToUpdate.isEmpty()) update lstConfigToUpdate;
        if (!contentDocIdsToDelete.isEmpty()) {
            List<ContentDocument> docsToDelete = new List<ContentDocument>();
            for(Id docId : contentDocIdsToDelete) {
                docsToDelete.add(new ContentDocument(Id = docId));
            }
            delete docsToDelete;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch hoàn tất. Tổng số dòng data đã tạo: ' + totalRecordsProcessed);
    }
}