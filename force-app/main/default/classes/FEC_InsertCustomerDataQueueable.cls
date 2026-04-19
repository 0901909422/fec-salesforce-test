public class FEC_InsertCustomerDataQueueable implements Queueable {
    private List<FEC_CustomerAdditionalInfo__c> fullDataList;
    private Set<Id> configIds;      // Thay đổi: Dùng Set để chứa nhiều Config ID
    private List<Id> excelVersionIds; 
    private Set<Id> jsonDocIdsToDelete; // Thay đổi: Dùng Set để chứa nhiều JSON Doc ID
    private static final Integer CHUNK_SIZE = 2000;

    // Constructor nhận dữ liệu Bulk
    public FEC_InsertCustomerDataQueueable(List<FEC_CustomerAdditionalInfo__c> data, Set<Id> configIds, List<Id> excelFileIds, Set<Id> jsonDocIds) {
        this.fullDataList = data;
        this.configIds = configIds;
        this.excelVersionIds = excelFileIds;
        this.jsonDocIdsToDelete = jsonDocIds;
    }

    public void execute(QueueableContext context) {
        if (fullDataList == null || fullDataList.isEmpty()) {
            finalizeProcess();
            return;
        }

        List<FEC_CustomerAdditionalInfo__c> currentBatch = new List<FEC_CustomerAdditionalInfo__c>();
        List<FEC_CustomerAdditionalInfo__c> remainingData = new List<FEC_CustomerAdditionalInfo__c>();

        // Chunking dữ liệu
        for (Integer i = 0; i < fullDataList.size(); i++) {
            if (i < CHUNK_SIZE) {
                currentBatch.add(fullDataList[i]);
            } else {
                remainingData.add(fullDataList[i]);
            }
        }

        if (!currentBatch.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(
                currentBatch,
                FEC_CustomerAdditionalInfo__c.FEC_CompositeKey__c,
                false
            );

            Boolean hasErrors = false;
            for (Database.UpsertResult sr : results) {
                if (!sr.isSuccess()) {
                    hasErrors = true;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Upsert error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }

            if (hasErrors) {
                updateConfigsToFailure();
                return;
            }
        }

        // Chain tiếp nếu còn data
        if (!remainingData.isEmpty()) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new FEC_InsertCustomerDataQueueable(remainingData, configIds, excelVersionIds, jsonDocIdsToDelete));
            }
        } else {
            // Hết data -> Update trạng thái cho TOÀN BỘ Configs và Files
            finalizeProcess();
        }
    }

    private void finalizeProcess() {
        try {
            // 1. Update List Configs -> Processed
            if (configIds != null && !configIds.isEmpty()) {
                List<FEC_CustomerAdditionalInfoConfig__c> configsToUpdate = new List<FEC_CustomerAdditionalInfoConfig__c>();
                for (Id cfgId : configIds) {
                    configsToUpdate.add(new FEC_CustomerAdditionalInfoConfig__c(
                        Id = cfgId,
                        FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS
                    ));
                }
                update configsToUpdate;
            }

            // 2. Update Excel Files -> Processed
            if (excelVersionIds != null && !excelVersionIds.isEmpty()) {
                List<ContentVersion> cvUpdates = new List<ContentVersion>();
                for (Id cvId : excelVersionIds) {
                    cvUpdates.add(new ContentVersion(
                        Id = cvId,
                        FEC_Comments__c = FEC_ConstantCommon.PROCESSED_STATUS
                    ));
                }
                update cvUpdates;
            }

            // 3. Xóa List JSON Files
            if (jsonDocIdsToDelete != null && !jsonDocIdsToDelete.isEmpty()) {
                List<ContentDocument> docsToDelete = new List<ContentDocument>();
                for (Id docId : jsonDocIdsToDelete) {
                    docsToDelete.add(new ContentDocument(Id = docId));
                }
                delete docsToDelete;
            }
        } catch (Exception e) {
            System.debug('Lỗi Finalize: ' + e.getMessage());
        }
    }

    private void updateConfigsToFailure() {
        if (configIds == null || configIds.isEmpty()) {
            return;
        }
        try {
            List<FEC_CustomerAdditionalInfoConfig__c> configsToUpdate = new List<FEC_CustomerAdditionalInfoConfig__c>();
            for (Id cfgId : configIds) {
                configsToUpdate.add(new FEC_CustomerAdditionalInfoConfig__c(
                    Id = cfgId,
                    FEC_Status__c = FEC_ConstantCommon.FAILURE_STATUS
                ));
            }
            update configsToUpdate;
        } catch (Exception e) {
            System.debug('Lỗi updateConfigsToFailure: ' + e.getMessage());
        }
    }
}