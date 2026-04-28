/**
 * FEC_ScheduledPushCampaignDataBatch
 * Scheduled batch job for pushing campaign data to external API.
 * Refactored to delegate shared logic to service classes.
 */
public with sharing class FEC_ScheduledPushCampaignDataBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    private Id batchLogId;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    // --- Schedulable ---
    public void execute(SchedulableContext SC) {
        Database.executeBatch(new FEC_ScheduledPushCampaignDataBatch(), 200);
    }

    // --- Batchable ---
    public Database.QueryLocator start(Database.BatchableContext BC) {
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
        this.totalRecords = Database.countQuery(query.replaceFirst('SELECT .*? FROM', 'SELECT count() FROM'));
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_ScheduledPushCampaignDataBatch', this.totalRecords);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        System.debug('>>> [ScheduledPushCampaign] execute() — scope size: ' + scope.size());
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                models.add(FEC_CampaignBatchService.mapToModel(rec));
            }

            List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(
                models, FEC_Constants.CAMPAIGN_MAX_JSON_SIZE
            );
            System.debug('>>> [ScheduledPushCampaign] chunks count: ' + chunks.size() + ' | total models: ' + models.size());

            for (List<FEC_DataCampaign> chunk : chunks) {
                sendChunk(chunk);
            }

            markAsSent(scope);
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            System.debug('>>> [ScheduledPushCampaign] ERROR: ' + ex.getMessage() + ' | StackTrace: ' + ex.getStackTraceString());
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_ScheduledPushCampaignDataBatch', ex, scope.size()
            );
        }
    }

    public void finish(Database.BatchableContext BC) {
        FEC_CampaignBatchLogger.logFinish(
            this.batchLogId,
            (BC != null ? BC.getJobId() : null),
            this.processedCount,
            this.errorCount,
            String.isBlank(this.errorDetails) ? null : this.errorDetails
        );
    }

    // ─── Private Helpers ───────────────────────────────────────────

    private void sendChunk(List<FEC_DataCampaign> chunk) {
        String payload = JSON.serialize(chunk);
        System.debug('>>> [ScheduledPushCampaign] sendChunk — records: ' + chunk.size() + ' | payload size: ' + payload.length() + ' bytes');
        System.debug('>>> [ScheduledPushCampaign] payload: ' + payload.abbreviate(5000));
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        Integer statusCode = response != null ? response.getStatusCode() : null;
        System.debug('>>> [ScheduledPushCampaign] response status: ' + statusCode);
        if (response != null && statusCode != FEC_Constants.HTTP_STATUS_OK
            && statusCode != FEC_Constants.HTTP_STATUS_CREATED) {
            System.debug('>>> [ScheduledPushCampaign] callout error — status: ' + statusCode + ' | body: ' + response.getBody().abbreviate(2000));
            this.errorCount++;
            FEC_CampaignBatchLogger.logCalloutError(
                this.batchLogId, 'FEC_ScheduledPushCampaignDataBatch',
                statusCode, response.getBody(), chunk.size()
            );
        }
    }

    private void markAsSent(List<FEC_DataCampaign__c> records) {
        for (FEC_DataCampaign__c rec : records) {
            rec.FEC_IsPushed__c = true;
        }
        update records;
    }
}
