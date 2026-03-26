/**
 * FEC_PushCampaignDataBatch
 * Batch job for instant push of campaign data to external API.
 * Refactored to delegate shared logic to service classes.
 */
public with sharing class FEC_PushCampaignDataBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id specificMappingId;
    private Id batchLogId;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public FEC_PushCampaignDataBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushCampaignDataBatch() {}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime dtStart = FEC_Util.getStartOfToday();
        DateTime dtEnd = FEC_Util.getEndOfToday();

        String countQuery = 'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE CreatedDate >= :dtStart AND CreatedDate <= :dtEnd ' +
            'AND FEC_IsPushed__c = false ' +
            'AND FEC_SendToCommsDB__c = null ' +
            'AND FEC_SentInstantly__c = null ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
            'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null)';

        this.totalRecords = Database.countQuery(countQuery);
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_PushCampaignDataBatch', this.totalRecords);

        String query = FEC_CampaignBatchService.buildInstantPushQuery();
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                models.add(FEC_CampaignBatchService.mapToModel(rec));
            }

            List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(
                models, FEC_Constants.CAMPAIGN_MAX_JSON_SIZE
            );

            for (List<FEC_DataCampaign> chunk : chunks) {
                sendChunk(chunk);
            }

            markAsSent(scope);
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_PushCampaignDataBatch', ex, scope.size()
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
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        if (response != null && response.getStatusCode() != FEC_Constants.HTTP_STATUS_OK
            && response.getStatusCode() != FEC_Constants.HTTP_STATUS_CREATED) {
            this.errorCount++;
            FEC_CampaignBatchLogger.logCalloutError(
                this.batchLogId, 'FEC_PushCampaignDataBatch',
                response.getStatusCode(), response.getBody(), chunk.size()
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
