/**
 * FEC_PushCampaignDataBatch
 * Queueable job for instant push of campaign data to external API.
 *
 * Uses an Apex Cursor (Database.getCursor) to iterate through the result set
 * in fixed-size chunks (FEC_Constants.CAMPAIGN_PUSH_CHUNK_SIZE). The job
 * re-enqueues itself until the cursor is fully consumed.
 *
 * Each execute() transaction does: cursor.fetch → callout → DML markAsSent
 * → (optional) DML logStart/logFinish → enqueueJob chain.
 *
 * Transaction order guarantee:
 *  - Callout ALWAYS runs BEFORE any DML.
 *  - Log DML runs AFTER the callout is done (no more callouts follow).
 *  - Only 1 System.enqueueJob per transaction (chain self OR finish log).
 */
public with sharing class FEC_PushCampaignDataBatch implements Queueable, Database.AllowsCallouts {

    private Id specificMappingId;
    @TestVisible private Id batchLogId;
    private Database.Cursor cursor;
    private Integer position;
    private Integer processedCount;
    private Integer errorCount;
    private String errorDetails;

    /** Initial entry point — used by callers (controller / scheduler / tests). */
    public FEC_PushCampaignDataBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushCampaignDataBatch() {}

    /**
     * Internal constructor used when chaining the queueable to continue
     * processing the same cursor.
     */
    private FEC_PushCampaignDataBatch(
        Id mappingId, Id batchLogId, Database.Cursor cursor, Integer position,
        Integer processedCount, Integer errorCount, String errorDetails
    ) {
        this.specificMappingId = mappingId;
        this.batchLogId = batchLogId;
        this.cursor = cursor;
        this.position = position;
        this.processedCount = processedCount;
        this.errorCount = errorCount;
        this.errorDetails = errorDetails;
    }

    public void execute(QueueableContext QC) {
        // First execution — open cursor + init state.
        if (this.cursor == null) {
            DateTime dtStart = FEC_Util.getStartOfToday();
            DateTime dtEnd = FEC_Util.getEndOfToday();
            this.cursor = Database.getCursor(
                FEC_CampaignBatchService.buildInstantPushQuery(dtStart, dtEnd)
            );
            this.position = 0;
            this.processedCount = 0;
            this.errorCount = 0;
            this.errorDetails = '';
        }

        Integer total = this.cursor.getNumRecords();
        Integer remaining = total - this.position;

        // Nothing to process — write finish log and exit.
        if (remaining <= 0) {
            createLogIfNeeded();
            writeFinishLog(QC);
            return;
        }

        // Fetch + process chunk. Callout runs BEFORE any DML in this tx.
        Integer fetchSize = Math.min(FEC_Constants.CAMPAIGN_PUSH_CHUNK_SIZE, remaining);
        List<FEC_DataCampaign__c> scope =
            (List<FEC_DataCampaign__c>) this.cursor.fetch(this.position, fetchSize);
        System.debug('>>> [PushCampaignData] execute() — pos: ' + this.position
            + ' / ' + total + ' | scope size: ' + (scope == null ? 0 : scope.size()));

        if (scope != null && !scope.isEmpty()) {
            processChunk(scope);
            this.position += scope.size();
        } else {
            this.position += fetchSize;
        }

        // After callout + markAsSent DML are done, safe to do additional DML.
        // Create log record on first chunk (no more callouts will happen in this tx).
        createLogIfNeeded();

        // Chain: only 1 enqueueJob per transaction.
        if (this.position < total && !Test.isRunningTest()) {
            System.enqueueJob(cloneForChain());
        } else {
            // Last chunk — write finish log in same tx (DML only, no more callouts).
            writeFinishLog(QC);
        }
    }

    // ─── Private Helpers ───────────────────────────────────────────

    private FEC_PushCampaignDataBatch cloneForChain() {
        return new FEC_PushCampaignDataBatch(
            this.specificMappingId, this.batchLogId, this.cursor, this.position,
            this.processedCount, this.errorCount, this.errorDetails
        );
    }

    private void processChunk(List<FEC_DataCampaign__c> scope) {
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                models.add(FEC_CampaignBatchService.mapToModel(rec));
            }

            // Callout FIRST — before any DML.
            sendChunk(models);
            // DML after callout — safe order.
            markAsSent(scope);
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | FEC_PushCampaignDataBatch'
                + ' | Exception: ' + ex.getMessage()
                + ' | StackTrace: ' + ex.getStackTraceString()
                + ' | Records: ' + scope.size()
                + '\n';
            System.debug('>>> [PushCampaignData] ERROR: ' + ex.getMessage()
                + ' | StackTrace: ' + ex.getStackTraceString());
        }
    }

    private void sendChunk(List<FEC_DataCampaign> chunk) {
        String payload = JSON.serialize(chunk);
        System.debug('>>> [PushCampaignData] sendChunk — records: ' + chunk.size()
            + ' | payload size: ' + payload.length() + ' bytes');
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        Integer statusCode = response != null ? response.getStatusCode() : null;
        System.debug('>>> [PushCampaignData] response status: ' + statusCode);
        if (response != null && statusCode != FEC_Constants.HTTP_STATUS_OK
            && statusCode != FEC_Constants.HTTP_STATUS_CREATED) {
            String errorBody = response.getBody() != null ? response.getBody().abbreviate(2000) : '';
            System.debug('>>> [PushCampaignData] callout error — status: ' + statusCode
                + ' | body: ' + errorBody);
            this.errorCount++;
            this.errorDetails += Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | FEC_PushCampaignDataBatch'
                + ' | HTTP ' + statusCode
                + ' | Records: ' + chunk.size()
                + ' | Body: ' + (errorBody.length() > 500 ? errorBody.substring(0, 500) + '...' : errorBody)
                + '\n';
        }
    }

    private void markAsSent(List<FEC_DataCampaign__c> records) {
        for (FEC_DataCampaign__c rec : records) {
            rec.FEC_IsPushed__c = true;
        }
        update records;
    }

    /**
     * Creates the batch log record (once). Called AFTER callout is complete
     * so no "uncommitted work pending" conflict.
     */
    private void createLogIfNeeded() {
        if (this.batchLogId == null) {
            this.batchLogId = FEC_CampaignBatchLogger.logStart(
                'FEC_PushCampaignDataBatch', this.cursor.getNumRecords()
            );
        }
    }

    /**
     * Finalizes the batch log with processed/error counts.
     * Called in the same transaction as the last chunk (after callout done)
     * or when cursor is empty.
     */
    private void writeFinishLog(QueueableContext QC) {
        if (this.batchLogId == null) {
            return;
        }
        FEC_CampaignBatchLogger.logFinish(
            this.batchLogId,
            (QC != null ? QC.getJobId() : null),
            this.processedCount,
            this.errorCount,
            String.isBlank(this.errorDetails) ? null : this.errorDetails
        );
    }
}
