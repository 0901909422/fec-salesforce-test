/**
 * FEC_GetCallingListResultBatch
 * Batch job to retrieve calling list results from external API and update records.
 * Refactored to use shared service classes and constants.
 */
public with sharing class FEC_GetCallingListResultBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id batchLogId;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String dayOfWeek = Datetime.now().format('EEEE');
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

        Integer totalRecords = Database.countQuery(
            query.replaceFirst('SELECT .*? FROM', 'SELECT count() FROM')
        );
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_GetCallingListResultBatch', totalRecords);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        Set<String> accountSet = collectAccountNumbers(scope);
        if (accountSet.isEmpty()) {
            return;
        }

        try {
            FEC_CampaignApiResponse.CallingListResponse apiResponse =
                FEC_CampaignApiCaller.getCallingListResult(accountSet);

            if (apiResponse == null || apiResponse.status != FEC_Constants.API_STATUS_OK
                || apiResponse.data == null) {
                handleApiError(apiResponse, scope.size());
                return;
            }

            List<FEC_DataCampaign__c> recordsToUpdate = processCallingListResponse(apiResponse, scope);
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            FEC_CampaignBatchLogger.logException(
                this.batchLogId, 'FEC_GetCallingListResultBatch', ex, scope.size()
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

    private Set<String> collectAccountNumbers(List<FEC_DataCampaign__c> scope) {
        Set<String> accountSet = new Set<String>();
        for (FEC_DataCampaign__c rec : scope) {
            if (String.isNotBlank(rec.FEC_AccountOrContractNumber__c)) {
                accountSet.add(rec.FEC_AccountOrContractNumber__c);
            }
        }
        return accountSet;
    }

    private void handleApiError(
        FEC_CampaignApiResponse.CallingListResponse apiResponse, Integer scopeSize
    ) {
        this.errorCount += scopeSize;
        String msg = (apiResponse != null) ? apiResponse.message : 'Null API response';
        this.errorDetails += 'API Error: ' + msg + '\n';
    }

    private List<FEC_DataCampaign__c> processCallingListResponse(
        FEC_CampaignApiResponse.CallingListResponse apiResponse,
        List<FEC_DataCampaign__c> scope
    ) {
        Map<String, FEC_CampaignApiResponse.CallingListRecordData> responseMap =
            new Map<String, FEC_CampaignApiResponse.CallingListRecordData>();

        for (FEC_CampaignApiResponse.CallingListRecordData apiRec : apiResponse.data) {
            if (String.isNotBlank(apiRec.accountOrContractNumber)) {
                responseMap.put(apiRec.accountOrContractNumber, apiRec);
            }
        }

        List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();
        for (FEC_DataCampaign__c rec : scope) {
            if (responseMap.containsKey(rec.FEC_AccountOrContractNumber__c)) {
                FEC_CampaignApiResponse.CallingListRecordData apiData =
                    responseMap.get(rec.FEC_AccountOrContractNumber__c);
                if (applyCallingListUpdate(rec, apiData)) {
                    recordsToUpdate.add(rec);
                }
            }
        }
        return recordsToUpdate;
    }

    private Boolean applyCallingListUpdate(
        FEC_DataCampaign__c rec,
        FEC_CampaignApiResponse.CallingListRecordData apiData
    ) {
        if (String.isBlank(apiData.callResult)) {
            return false;
        }

        rec.FEC_AgentID__c = apiData.agentId;

        if (String.isNotBlank(apiData.attempt)) {
            rec.FEC_Attempt__c = Decimal.valueOf(apiData.attempt);
        }
        if (String.isNotBlank(apiData.callResult)) {
            rec.FEC_CallResult__c = Decimal.valueOf(apiData.callResult);
        }
        if (String.isNotBlank(apiData.callTime)) {
            rec.FEC_CallTime__c = (DateTime) JSON.deserialize(
                '"' + apiData.callTime + '"', DateTime.class
            );
        }

        String newStatus = FEC_CampaignBatchService.evaluateCallStatus(apiData.callResult);
        rec.FEC_CallStatus__c = newStatus;

        if (newStatus == FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED) {
            rec.FEC_RecordStatus__c = newStatus;
        }

        return true;
    }
}
