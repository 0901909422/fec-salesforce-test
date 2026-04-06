global class FEC_ProcessCustomerDataBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    private Integer totalConfigsPushed = 0;

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_ProcessCustomerDataBatch()); 
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, FEC_KeyIdentifier__c, FEC_FieldID__c, FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE FEC_Status__c = :FEC_ConstantCommon.UPLOADED_STATUS
        ]);
    }

    global void execute(Database.BatchableContext bc, List<FEC_CustomerAdditionalInfoConfig__c> scope) {
        Map<Id, FEC_CustomerAdditionalInfoConfig__c> mapConfigs = new Map<Id, FEC_CustomerAdditionalInfoConfig__c>(scope);
        Set<Id> configIds = mapConfigs.keySet();

        List<ContentDocumentLink> allLinks = [
            SELECT ContentDocumentId, LinkedEntityId,
                   ContentDocument.LatestPublishedVersionId, 
                   ContentDocument.LatestPublishedVersion.VersionData,
                   ContentDocument.LatestPublishedVersion.Title,
                   ContentDocument.LatestPublishedVersion.Description,
                   ContentDocument.LatestPublishedVersion.FEC_Comments__c
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :configIds
            AND ContentDocument.LatestPublishedVersion.FEC_Comments__c = :FEC_ConstantCommon.UPLOADED_STATUS
        ];

        Map<Id, List<ContentVersion>> mapJsonFiles = new Map<Id, List<ContentVersion>>();
        Map<Id, List<Id>> mapJsonDocIds = new Map<Id, List<Id>>();
        Map<Id, List<Id>> mapConfigToExcelIds = new Map<Id, List<Id>>();
        Set<Id> orphanDocIds = new Set<Id>();

        for (ContentDocumentLink link : allLinks) {
            ContentVersion cv = link.ContentDocument.LatestPublishedVersion;
            Id cfgId = link.LinkedEntityId;
            
            if (cv.Description == FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING) {
                // Collect orphan docs (file đã bị xóa nhưng link còn tồn tại)
                if (cv.VersionData == null) {
                    orphanDocIds.add(link.ContentDocumentId);
                    continue;
                }
                
                if (!mapJsonFiles.containsKey(cfgId)) mapJsonFiles.put(cfgId, new List<ContentVersion>());
                if (!mapJsonDocIds.containsKey(cfgId)) mapJsonDocIds.put(cfgId, new List<Id>());
                
                mapJsonFiles.get(cfgId).add(cv);
                mapJsonDocIds.get(cfgId).add(link.ContentDocumentId);
            } else {
                if (cv.VersionData == null) {
                    orphanDocIds.add(link.ContentDocumentId);
                    continue;
                }
                if (!mapConfigToExcelIds.containsKey(cfgId)) {
                    mapConfigToExcelIds.put(cfgId, new List<Id>());
                }
                mapConfigToExcelIds.get(cfgId).add(cv.Id);
            }
        }

        // Cleanup orphan ContentDocuments
        if (!orphanDocIds.isEmpty()) {
            try {
                List<ContentDocument> docsToDelete = new List<ContentDocument>();
                for (Id docId : orphanDocIds) {
                    docsToDelete.add(new ContentDocument(Id = docId));
                }
                delete docsToDelete;
            } catch (Exception e) {
                System.debug('Error cleaning up orphan docs: ' + e.getMessage());
            }
        }

        List<FEC_CustomerAdditionalInfo__c> masterDataList = new List<FEC_CustomerAdditionalInfo__c>();
        Set<Id> validConfigIds = new Set<Id>();
        Set<Id> validJsonDocIds = new Set<Id>();
        List<Id> allExcelIdsToQueue = new List<Id>();
        List<FEC_CustomerAdditionalInfoConfig__c> configsToUpdateStatus = new List<FEC_CustomerAdditionalInfoConfig__c>();

        for (FEC_CustomerAdditionalInfoConfig__c config : scope) {
            try {
                List<ContentVersion> jsonFileList = mapJsonFiles.get(config.Id);
                
                if (jsonFileList != null && !jsonFileList.isEmpty()) {
                    for (ContentVersion jsonCV : jsonFileList) {
                        if (jsonCV.VersionData == null) continue;
                        String jsonString = jsonCV.VersionData.toString(); 
                        List<Object> rows = (List<Object>) JSON.deserializeUntyped(jsonString);

                        for (Integer i = 1; i < rows.size(); i++) {
                            List<Object> cols = (List<Object>) rows[i];
                            if (cols.size() < 3) continue; 

                            masterDataList.add(new FEC_CustomerAdditionalInfo__c(
                                FEC_Config__c = config.Id,
                                FEC_KeyIdentifier__c = config.FEC_KeyIdentifier__c,
                                FEC_FieldID__c = config.FEC_FieldID__c,
                                FEC_KeyIDValue__c = String.valueOf(cols[0]),
                                FEC_FieldValue__c = String.valueOf(cols[1]),
                                FEC_IsActive__c = (cols[2] == FEC_ConstantCommon.YES_VALUE),
                                FEC_LinkedFilename__c = jsonCV.Title
                            ));
                        }
                    }

                    validConfigIds.add(config.Id);
                    
                    if (mapJsonDocIds.containsKey(config.Id)) {
                        validJsonDocIds.addAll(mapJsonDocIds.get(config.Id));
                    }

                    if (mapConfigToExcelIds.containsKey(config.Id)) {
                        allExcelIdsToQueue.addAll(mapConfigToExcelIds.get(config.Id));
                    }
                    
                    config.FEC_Status__c = 'Processing';
                    configsToUpdateStatus.add(config);
                    
                } else {
                    config.FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS;
                    configsToUpdateStatus.add(config);
                    System.debug('Config ' + config.Id + ' không có file JSON hợp lệ. Chuyển sang Processed.');
                }
            } catch (Exception e) {
                config.FEC_Status__c = 'Failed';
                configsToUpdateStatus.add(config); 
                System.debug('Lỗi parse Config ' + config.Id + ': ' + e.getMessage());
            }
        }

        if (!configsToUpdateStatus.isEmpty()) update configsToUpdateStatus;

        if (!masterDataList.isEmpty() || !validConfigIds.isEmpty()) {
            System.enqueueJob(new FEC_InsertCustomerDataQueueable(
                masterDataList, 
                validConfigIds, 
                allExcelIdsToQueue, 
                validJsonDocIds
            ));
            totalConfigsPushed += validConfigIds.size();
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch hoàn tất. Configs đã push: ' + totalConfigsPushed);
    }
}