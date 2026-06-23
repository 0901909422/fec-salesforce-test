/**
 * FEC_ScheduledPushCampaignDataBatch
 * Queueable job for pushing scheduled campaign data to external API.
 * Uses Apex Cursor for pagination. Marks records as sent after successful push.
 * Schedule via FEC_ScheduledPushCampaignDataScheduler.
 */
public with sharing class FEC_ScheduledPushCampaignDataBatch implements Queueable, Database.AllowsCallouts {

    @TestVisible private Id batchLogId;
    private Database.Cursor cursor;
    private Integer position;
    private Integer processedCount;
    private Integer errorCount;
    private String errorDetails;

    public FEC_ScheduledPushCampaignDataBatch() {}

    private FEC_ScheduledPushCampaignDataBatch(
        Id batchLogId, Database.Cursor cursor, Integer position,
        Integer processedCount, Integer errorCount, String errorDetails
    ) {
        this.batchLogId = batchLogId;
        this.cursor = cursor;
        this.position = position;
        this.processedCount = processedCount;
        this.errorCount = errorCount;
        this.errorDetails = errorDetails;
    }

    // --- Queueable ---
    public void execute(QueueableContext QC) {
        if (this.cursor == null) {
            String dayOfWeek = DateTime.now().format('EEEE');
            String selectFields = 'Id, FEC_AppId__c, FEC_AccountOrContractNumber__c, FEC_ProductLine__c, ' +
                'FEC_Number1__c, FEC_Number2__c, FEC_Number3__c, FEC_Number4__c, FEC_Number5__c, ' +
                'FEC_String1__c, FEC_String2__c, FEC_String3__c, FEC_String4__c, FEC_String5__c, ' +
                'FEC_DateTime1__c, FEC_DateTime2__c, FEC_DateTime3__c, ' +
                'FEC_RecordId__c, FEC_RecordStatus__c, FEC_RecordLifetime__c, FEC_RecordCurrentLifetime__c, ' +
                'FEC_MaxCallAttempt__c, FEC_CurrentCallAttempt__c, FEC_CampaignCallingList__c, FEC_SystemName__c, ' +
                'CreatedDate, LastModifiedDate, CreatedBy.Name, LastModifiedBy.Name, ' +
                'FEC_CS_Campaign__r.FEC_Campaign__r.FEC_CampaignId__c, ' +
                'FEC_CS_Campaign__r.FEC_ScheduleCampaign__c, ' +
                'FEC_CS_Campaign__r.FEC_SaturdaySchedule__c, ' +
                'FEC_CS_Campaign__r.FEC_SundaySchedule__c';

            String query = FEC_CampaignBatchService.buildScheduledQuery(selectFields, dayOfWeek);
            this.cursor = Database.getCursor(query);
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

    private FEC_ScheduledPushCampaignDataBatch cloneForChain() {
        return new FEC_ScheduledPushCampaignDataBatch(
            this.batchLogId, this.cursor, this.position,
            this.processedCount, this.errorCount, this.errorDetails
        );
    }

    private void processChunk(List<FEC_DataCampaign__c> scope) {
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                models.add(FEC_CampaignBatchService.mapToModel(rec));
            }
            sendChunk(models);
            markAsSent(scope);
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT_LOG)
                + ' | FEC_ScheduledPushCampaignDataBatch'
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
                + ' | FEC_ScheduledPushCampaignDataBatch'
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

    private void createLogIfNeeded() {
        if (this.batchLogId == null) {
            this.batchLogId = FEC_CampaignBatchLogger.logStart(
                'FEC_ScheduledPushCampaignDataBatch', this.cursor.getNumRecords()
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