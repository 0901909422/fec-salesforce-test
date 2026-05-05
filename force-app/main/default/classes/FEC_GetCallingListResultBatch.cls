/**
 * FEC_GetCallingListResultBatch
 * Batch job to retrieve calling list results from OData external object and update records.
 * Refactored to use shared service classes and constants.
 */
public with sharing class FEC_GetCallingListResultBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    // OData server không handle được IN clause quá lớn — chia nhỏ query theo CHUNK_SIZE
    private static final Integer ODATA_CHUNK_SIZE = 50;
    // Batch scope size — tận dụng governor limits (100 SOQL/transaction)
    private static final Integer BATCH_SCOPE_SIZE = 200;

    private Id batchLogId;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_GetCallingListResultBatch(), BATCH_SCOPE_SIZE);
    }

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
        System.debug('>>> [GetCallingListResult] execute() — scope size: ' + scope.size());

        try {
            List<SObject> odataResults = queryODataInChunks(scope);
            System.debug('>>> [GetCallingListResult] OData total results returned: ' + odataResults.size());

            List<FEC_DataCampaign__c> recordsToUpdate = processODataResults(odataResults, scope);
            System.debug('>>> [GetCallingListResult] records to update: ' + recordsToUpdate.size());
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
                System.debug('>>> [GetCallingListResult] DML update completed');
            }
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            System.debug('>>> [GetCallingListResult] ERROR: ' + ex.getMessage() + ' | StackTrace: ' + ex.getStackTraceString());
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

    /**
     * Chia nhỏ OData query theo ODATA_CHUNK_SIZE dựa trên scope records.
     * Mỗi chunk gom accountSet CHỈ của records trong chunk đó,
     * đảm bảo IN clause luôn nhỏ và ổn định, không mất data.
     */
    private List<SObject> queryODataInChunks(List<FEC_DataCampaign__c> scope) {
        List<SObject> allResults = new List<SObject>();
        Integer total = scope.size();
        Integer chunkCount = 0;

        for (Integer i = 0; i < total; i += ODATA_CHUNK_SIZE) {
            Integer endIdx = Math.min(i + ODATA_CHUNK_SIZE, total);
            Set<String> accountChunk = new Set<String>();
            for (Integer j = i; j < endIdx; j++) {
                FEC_DataCampaign__c rec = scope[j];
                if (String.isNotBlank(rec.FEC_AccountOrContractNumber__c)) {
                    accountChunk.add(rec.FEC_AccountOrContractNumber__c);
                }
            }

            if (accountChunk.isEmpty()) {
                continue;
            }

            String query = 'SELECT ExternalId, CONTRACT_NUMBER__c, CALL_TIME__c, ' +
                'ATTEMPT__c, AGENT_ID__c, CALL_RESULT__c ' +
                'FROM CommdbPegaCsResultTable__x ' +
                'WHERE CONTRACT_NUMBER__c IN :accountChunk';

            chunkCount++;
            System.debug('>>> [GetCallingListResult] OData chunk #' + chunkCount +
                ' | accounts: ' + accountChunk.size());
            List<SObject> chunkResults = Database.query(query);
            System.debug('>>> [GetCallingListResult] OData chunk #' + chunkCount +
                ' returned: ' + chunkResults.size());
            allResults.addAll(chunkResults);
        }
        return allResults;
    }

    @TestVisible
    private List<FEC_DataCampaign__c> processODataResults(List<SObject> odataResults, List<FEC_DataCampaign__c> scope) {
        Map<String, SObject> resultMap = new Map<String, SObject>();
        for (SObject odataRec : odataResults) {
            String contractNumber = (String) odataRec.get('CONTRACT_NUMBER__c');
            if (String.isNotBlank(contractNumber)) {
                resultMap.put(contractNumber, odataRec);
            }
        }

        List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();
        for (FEC_DataCampaign__c rec : scope) {
            if (resultMap.containsKey(rec.FEC_AccountOrContractNumber__c)) {
                SObject odataData = resultMap.get(rec.FEC_AccountOrContractNumber__c);
                if (applyODataUpdate(rec, odataData)) {
                    recordsToUpdate.add(rec);
                }
            }
        }
        return recordsToUpdate;
    }

    @TestVisible
    private Boolean applyODataUpdate(FEC_DataCampaign__c rec, SObject odataData) {
        Object callResultVal = odataData.get('CALL_RESULT__c');
        if (callResultVal == null) {
            System.debug('>>> [GetCallingListResult] applyODataUpdate — CALL_RESULT__c is null for contract: ' + rec.FEC_AccountOrContractNumber__c + ' — skipping');
            return false;
        }

        rec.FEC_CallTime__c = (DateTime) odataData.get('CALL_TIME__c');
        rec.FEC_Attempt__c = (Decimal) odataData.get('ATTEMPT__c');
        rec.FEC_AgentID__c = (String) odataData.get('AGENT_ID__c');
        rec.FEC_CallResult__c = (Decimal) callResultVal;

        String newStatus = FEC_CampaignBatchService.evaluateCallStatus(String.valueOf(callResultVal));
        rec.FEC_CallStatus__c = newStatus;

        if (newStatus == FEC_Constants.CAMPAIGN_STATUS_RESOLVED_CANCELLED) {
            rec.FEC_RecordStatus__c = newStatus;
        }

        System.debug('>>> [GetCallingListResult] applyODataUpdate — contract: ' + rec.FEC_AccountOrContractNumber__c +
            ' | callResult: ' + callResultVal + ' | status: ' + newStatus +
            ' | attempt: ' + rec.FEC_Attempt__c + ' | agent: ' + rec.FEC_AgentID__c);

        return true;
    }
}
