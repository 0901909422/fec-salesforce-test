public with sharing class FEC_BixIngestQueueable implements Queueable, Database.AllowsCallouts {

    private String linkedFilename;
    private List<List<FEC_CustomerAdditionalInfo__c>> remainingBatches;

    // Primary constructor — called from FEC_InsertCustomerDataQueueable
    public FEC_BixIngestQueueable(String linkedFilename) {
        this.linkedFilename = linkedFilename;
        this.remainingBatches = null;
    }

    // Chaining constructor — called when splitting into multiple batches
    public FEC_BixIngestQueueable(String linkedFilename, List<List<FEC_CustomerAdditionalInfo__c>> remainingBatches) {
        this.linkedFilename = linkedFilename;
        this.remainingBatches = remainingBatches;
    }

    public void execute(QueueableContext context) {
        try {
            List<FEC_CustomerAdditionalInfo__c> records;

            if (remainingBatches != null && !remainingBatches.isEmpty()) {
                // Processing remaining batches from chaining
                records = remainingBatches.remove(0);
            } else {
                // First execution — query records by filename
                records = [
                    SELECT Id, FEC_KeyIdentifier__c, FEC_KeyIDValue__c,
                           FEC_FieldID__c, FEC_FieldValue__c, FEC_IsActive__c,
                           FEC_CompositeKey__c, FEC_Config__c,
                           CreatedDate, CreatedById, LastModifiedDate, LastModifiedById
                    FROM FEC_CustomerAdditionalInfo__c
                    WHERE FEC_LinkedFilename__c = :linkedFilename
                ];

                if (records.isEmpty()) {
                    return;
                }

                // Split into batches if needed
                List<List<FEC_CustomerAdditionalInfo__c>> batches = FEC_BixIngestService.splitIntoBatches(records);
                records = batches.remove(0);

                if (!batches.isEmpty()) {
                    remainingBatches = batches;
                }
            }

            // Build payload and send
            String payload = FEC_BixIngestService.buildRequestBody(records);
            FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest(payload);
            // Fire-and-forget: result is logged by sendRequest(), no status change here

            // Chain for remaining batches
            if (remainingBatches != null && !remainingBatches.isEmpty()) {
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new FEC_BixIngestQueueable(linkedFilename, remainingBatches));
                }
            }

        } catch (Exception e) {
            System.debug('BIX Ingest error: ' + e.getMessage());
            // Fire-and-forget: only log, do NOT change Config status
        }
    }
}
