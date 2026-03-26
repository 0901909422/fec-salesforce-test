/**
 * FEC_CheckCampaignStatusBatch
 * Batch job to check campaign record status via external API.
 * Refactored to use shared service classes and constants.
 */
public with sharing class FEC_CheckCampaignStatusBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id batchLogId;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, FEC_RecordId__c, FEC_RecordStatus__c, ' +
            'FEC_InsertionDate__c, FEC_CurrentCallAttempt__c, ' +
            'FEC_RecordCurrentLifetime__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_CallbackRequested__c, FEC_SendToCommsDB__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND FEC_SendToCommsDB__c = null ' +
            'AND FEC_RecordStatus__c = \'' + FEC_Constants.CAMPAIGN_STATUS_NEW + '\'';

        Integer totalRecords = Database.countQuery(
            'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND FEC_SendToCommsDB__c = null ' +
            'AND FEC_RecordStatus__c = \'' + FEC_Constants.CAMPAIGN_STATUS_NEW + '\''
        );
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_CheckCampaignStatusBatch', totalRecords);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        List<String> recordIds = collectRecordIds(scope);
        if (recordIds.isEmpty()) {
            return;
        }

        try {
            FEC_CampaignApiResponse.StatusResponse apiResponse =
                FEC_CampaignApiCaller.checkCampaignStatus(recordIds);

            if (apiResponse == null || apiResponse.status != FEC_Constants.API_STATUS_OK) {
                handleApiError(apiResponse, scope.size());
                return;
            }

            List<FEC_DataCampaign__c> recordsToUpdate = processStatusResponse(apiResponse, scope);
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_CheckCampaignStatusBatch', ex, scope.size()
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

    private List<String> collectRecordIds(List<FEC_DataCampaign__c> scope) {
        List<String> ids = new List<String>();
        for (FEC_DataCampaign__c record : scope) {
            if (String.isNotBlank(record.FEC_RecordId__c)) {
                ids.add(record.FEC_RecordId__c);
            }
        }
        return ids;
    }

    private void handleApiError(FEC_CampaignApiResponse.StatusResponse apiResponse, Integer scopeSize) {
        this.errorCount += scopeSize;
        String msg = (apiResponse != null) ? apiResponse.message : 'Null API response';
        this.errorDetails += 'API Error: ' + msg + '\n';
    }

    private List<FEC_DataCampaign__c> processStatusResponse(
        FEC_CampaignApiResponse.StatusResponse apiResponse,
        List<FEC_DataCampaign__c> scope
    ) {
        Map<String, FEC_CampaignApiResponse.StatusRecordData> apiResultMap =
            new Map<String, FEC_CampaignApiResponse.StatusRecordData>();

        if (apiResponse.data != null) {
            for (FEC_CampaignApiResponse.StatusRecordData item : apiResponse.data) {
                apiResultMap.put(item.recordId, item);
            }
        }

        List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();
        for (FEC_DataCampaign__c record : scope) {
            if (apiResultMap.containsKey(record.FEC_RecordId__c)) {
                FEC_CampaignApiResponse.StatusRecordData apiData = apiResultMap.get(record.FEC_RecordId__c);
                if (applyStatusUpdate(record, apiData)) {
                    recordsToUpdate.add(record);
                }
            }
        }
        return recordsToUpdate;
    }

    private Boolean applyStatusUpdate(
        FEC_DataCampaign__c record,
        FEC_CampaignApiResponse.StatusRecordData apiData
    ) {
        if (apiData.status == FEC_Constants.API_CHECK_STATUS_SUCCESS) {
            Date insertionDateOnly;
            if (record.FEC_InsertionDate__c != null) {
                insertionDateOnly = record.FEC_InsertionDate__c.date();
            }
            if (insertionDateOnly != null && insertionDateOnly < System.today()) {
                record.FEC_CurrentCallAttempt__c = 1;
            }
            record.FEC_CallbackRequested__c = '';
            record.FEC_SendToCommsDB__c = FEC_Constants.CAMPAIGN_SEND_TO_COMMS_Y;
            record.FEC_InsertionDate__c = System.now();
            record.FEC_RecordCurrentLifetime__c = record.FEC_RecordCurrentLifetime__c + 1;

            if (String.isNotBlank(apiData.csContractString)) {
                record.FEC_Number4__c = Decimal.valueOf(
                    FEC_Util.getBeforeSubstring(apiData.csContractString, '')
                );
            }
            if (String.isNotBlank(apiData.idiDocNbr)) {
                record.FEC_Number5__c = Decimal.valueOf(apiData.idiDocNbr);
            }
            return true;

        } else if (apiData.status == FEC_Constants.API_CHECK_STATUS_FAILED) {
            record.FEC_RecordStatus__c = FEC_Constants.CAMPAIGN_STATUS_FAILED;
            return true;
        }
        return false;
    }
}
