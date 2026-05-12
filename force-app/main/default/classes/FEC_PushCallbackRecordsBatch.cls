/**
 * FEC_PushCallbackRecordsBatch
 * Batch job for pushing callback-eligible campaign records to external API.
 * Pushes records inserted today matching Pega filter (F2 OR F3) AND F4 AND F1 AND F6:
 * status not resolved OR callback requested, within lifetime (<=), PushInstant enabled.
 * Does NOT mark records as sent (no FEC_IsPushed__c update).
 */
public with sharing class FEC_PushCallbackRecordsBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id specificMappingId;
    private Id batchLogId;
    private Integer totalRecords = 0;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public FEC_PushCallbackRecordsBatch(Id mappingId) {
        this.specificMappingId = mappingId;
    }

    public FEC_PushCallbackRecordsBatch() {}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime dtStart = FEC_Util.getStartOfToday();
        DateTime dtEnd = FEC_Util.getEndOfToday();

        String countQuery = 'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE FEC_InsertionDate__c >= :dtStart AND FEC_InsertionDate__c <= :dtEnd ' +
            'AND (' +
                '(FEC_RecordStatus__c != \'Resolved-Completed\' ' +
                'AND FEC_RecordStatus__c != \'Resolved-Cancelled\') ' +
                'OR FEC_CallbackRequested__c = \'true\'' +
            ') ' +
            'AND FEC_IsAtOrWithinLifetime__c = true ' +
            'AND FEC_CS_Campaign__r.FEC_PushInstant__c = true';

        this.totalRecords = Database.countQuery(countQuery);
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_PushCallbackRecordsBatch', this.totalRecords);

        String query = FEC_CampaignBatchService.buildCallbackRecordsPushQuery();
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        System.debug('>>> [PushCallbackRecords] execute() — scope size: ' + scope.size());
        try {
            List<FEC_DataCampaign> models = new List<FEC_DataCampaign>();
            for (FEC_DataCampaign__c rec : scope) {
                FEC_DataCampaign model = FEC_CampaignBatchService.mapToModel(rec);
                model.isCallback = true;
                models.add(model);
            }

            List<List<FEC_DataCampaign>> chunks = FEC_CampaignBatchService.chunkBySize(
                models, FEC_Constants.CAMPAIGN_MAX_JSON_SIZE
            );
            System.debug('>>> [PushCallbackRecords] chunks count: ' + chunks.size() + ' | total models: ' + models.size());

            for (List<FEC_DataCampaign> chunk : chunks) {
                sendChunk(chunk);
            }

            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            System.debug('>>> [PushCallbackRecords] ERROR: ' + ex.getMessage() + ' | StackTrace: ' + ex.getStackTraceString());
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_PushCallbackRecordsBatch', ex, scope.size()
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
        System.debug('>>> [PushCallbackRecords] sendChunk — records: ' + chunk.size() + ' | payload size: ' + payload.length() + ' bytes');
        System.debug('>>> [PushCallbackRecords] payload: ' + payload.abbreviate(5000));
        HttpResponse response = FEC_CampaignApiCaller.sendCampaignData(payload);
        Integer statusCode = response != null ? response.getStatusCode() : null;
        System.debug('>>> [PushCallbackRecords] response status: ' + statusCode);
        if (response != null && statusCode != FEC_Constants.HTTP_STATUS_OK
            && statusCode != FEC_Constants.HTTP_STATUS_CREATED) {
            System.debug('>>> [PushCallbackRecords] callout error — status: ' + statusCode + ' | body: ' + response.getBody().abbreviate(2000));
            this.errorCount++;
            FEC_CampaignBatchLogger.logCalloutError(
                this.batchLogId, 'FEC_PushCallbackRecordsBatch',
                statusCode, response.getBody(), chunk.size()
            );
        }
    }
}
