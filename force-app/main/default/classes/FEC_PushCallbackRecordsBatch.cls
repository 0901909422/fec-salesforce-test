/**
 * FEC_PushCallbackRecordsBatch
 * Queueable job for pushing callback-eligible campaign records to external API.
 * Does NOT mark records as sent (no FEC_IsPushed__c update).
 * Uses Apex Cursor for pagination.
 */
public with sharing class FEC_PushCallbackRecordsBatch implements Queueable, Database.AllowsCallouts {

    private Id specificMappingId;
    @TestVisible private Id batchLogId;
    private Database.Cursor cursor;
    private Integer position;
    private Integer processedCount;
    private Integer errorCount;
    private String errorDetails;

    public FEC_PushCallbackRecordsBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushCallbackRecordsBatch() {}

    private FEC_PushCallbackRecordsBatch(
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
        if (this.cursor == null) {
            DateTime dtStart = FEC_Util.getStartOfToday();
            DateTime dtEnd = FEC_Util.getEndOfToday();
            this.cursor = Database.getCursor(
                FEC_CampaignBatchService.buildCallbackRecordsPushQuery(dtStart, dtEnd)
            );
            this.position = 0;
            this.processedCount = 0;
            this.errorCount = 0;
            this.errorDetails = '';
        }

        Integer total = this.cursor.getNumRecords();
        Integer remaining = total - this.position;

        if (remaining <= 0) {
            createLogIfNeeded();
            writeFinishLog(QC);
            return;
        }

        Integer fetchSize = Math.min(FEC_Constants.CAMPAIGN_PUSH_CHUNK_SIZE, remaining);
        List<FEC_DataCampaign__c> scope =
            (List<FEC_DataCampaign__c>) this.cursor.fetch(this.position, fetchSize);

        if (scope != null && !scope.isEmpty()) {
            processChunk(scope);
            this.position += scope.size();
        } else {
            this.position += fetchSize;
        }

        createLogIfNeeded();

        if (this.position < total && !Test.isRunningTest()) {
            System.enqueueJob(cloneForChain());
        } else {
            writeFinishLog(QC);
        }
    }

    // ─── Private Helpers ───────────────────────────────────────────

    private FEC_PushCallbackRecordsBatch cloneForChain() {
        return new FEC_PushCallbackRecordsBatch(
            this.specificMappingId, this.batchLogId, this.cursor, this.position,
            this.processedCount, this.errorCount, this.errorDetails
        );
    }

    private void processChunk(List<FEC_DataCampaign__c> scope) {
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                FEC_DataCampaign model = FEC_CampaignBatchService.mapToModel(rec);
                model.isCallback = true;
                models.add(model);
            }
            sendChunk(models);
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | FEC_PushCallbackRecordsBatch'
                + ' | Exception: ' + ex.getMessage()
                + ' | Records: ' + scope.size() + '\n';
        }
    }

    private void sendChunk(List<FEC_DataCampaign> chunk) {
        String payload = JSON.serialize(chunk);
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        Integer statusCode = response != null ? response.getStatusCode() : null;
        if (response != null && statusCode != FEC_Constants.HTTP_STATUS_OK
            && statusCode != FEC_Constants.HTTP_STATUS_CREATED) {
            String errorBody = response.getBody() != null ? response.getBody().abbreviate(2000) : '';
            this.errorCount++;
            this.errorDetails += Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | FEC_PushCallbackRecordsBatch'
                + ' | HTTP ' + statusCode
                + ' | Records: ' + chunk.size()
                + ' | Body: ' + (errorBody.length() > 500 ? errorBody.substring(0, 500) + '...' : errorBody)
                + '\n';
        }
    }

    private void createLogIfNeeded() {
        if (this.batchLogId == null) {
            this.batchLogId = FEC_CampaignBatchLogger.logStart(
                'FEC_PushCallbackRecordsBatch', this.cursor.getNumRecords()
            );
        }
    }

    private void writeFinishLog(QueueableContext QC) {
        if (this.batchLogId == null) { return; }
        FEC_CampaignBatchLogger.logFinish(
            this.batchLogId,
            (QC != null ? QC.getJobId() : null),
            this.processedCount,
            this.errorCount,
            String.isBlank(this.errorDetails) ? null : this.errorDetails
        );
    }
}