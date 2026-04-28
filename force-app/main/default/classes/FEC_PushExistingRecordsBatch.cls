/**
 * FEC_PushExistingRecordsBatch
 * Batch job for pushing existing (older) campaign records to external API.
 * Re-pushes records created before today that are still within lifetime,
 * not resolved/callback, and belong to a PushInstant-enabled campaign.
 * Does NOT mark records as sent (no FEC_IsPushed__c update).
 */
public with sharing class FEC_PushExistingRecordsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id specificMappingId;
    private Id batchLogId;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public FEC_PushExistingRecordsBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushExistingRecordsBatch() {}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime dtStart = FEC_Util.getStartOfToday();

        String countQuery = 'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE CreatedDate < :dtStart ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordStatus__c != \'Pending-callback\' ' +
            'AND FEC_IsWithinLifetime__c = true ' +
            'AND (FEC_CallbackRequested__c != \'true\' OR FEC_CallbackRequested__c = null) ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true ' +
            'AND (FEC_InsertionDate__c = null OR FEC_InsertionDate__c < :dtStart)';

        this.totalRecords = Database.countQuery(countQuery);
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_PushExistingRecordsBatch', this.totalRecords);

        String query = FEC_CampaignBatchService.buildExistingRecordsPushQuery();
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        System.debug('>>> [PushExistingRecords] execute() — scope size: ' + scope.size());
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                FEC_DataCampaign model = FEC_CampaignBatchService.mapToModel(rec);
                model.isExistingRecords = true;
                models.add(model);
            }

            List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(
                models, FEC_Constants.CAMPAIGN_MAX_JSON_SIZE
            );
            System.debug('>>> [PushExistingRecords] chunks count: ' + chunks.size() + ' | total models: ' + models.size());

            for (List<FEC_DataCampaign> chunk : chunks) {
                sendChunk(chunk);
            }

            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            System.debug('>>> [PushExistingRecords] ERROR: ' + ex.getMessage() + ' | StackTrace: ' + ex.getStackTraceString());
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_PushExistingRecordsBatch', ex, scope.size()
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
        System.debug('>>> [PushExistingRecords] sendChunk — records: ' + chunk.size() + ' | payload size: ' + payload.length() + ' bytes');
        System.debug('>>> [PushExistingRecords] payload: ' + payload.abbreviate(5000));
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        Integer statusCode = response != null ? response.getStatusCode() : null;
        System.debug('>>> [PushExistingRecords] response status: ' + statusCode);
        if (response != null && statusCode != FEC_Constants.HTTP_STATUS_OK
            && statusCode != FEC_Constants.HTTP_STATUS_CREATED) {
            System.debug('>>> [PushExistingRecords] callout error — status: ' + statusCode + ' | body: ' + response.getBody().abbreviate(2000));
            this.errorCount++;
            FEC_CampaignBatchLogger.logCalloutError(
                this.batchLogId, 'FEC_PushExistingRecordsBatch',
                statusCode, response.getBody(), chunk.size()
            );
        }
    }
}
