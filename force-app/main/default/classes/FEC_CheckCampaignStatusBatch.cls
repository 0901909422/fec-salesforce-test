/**
 * FEC_CheckCampaignStatusBatch
 * Batch job to check campaign record status via OData external object.
 * Uses dynamic SOQL to query PostgresCampaignLog__x and update records.
 */
public with sharing class FEC_CheckCampaignStatusBatch implements Database.Batchable<sObject>, Database.Stateful {

    private Id batchLogId;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, FEC_RecordId__c, FEC_RecordStatus__c, ' +
            'FEC_InsertionDate__c, FEC_CurrentCallAttempt__c, ' +
            'FEC_RecordCurrentLifetime__c, FEC_RecordLifetime__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_CallbackRequested__c, FEC_SendToCommsDB__c, FEC_AccountOrContractNumber__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordCurrentLifetime__c <= FEC_RecordLifetime__c';

        Integer totalRecords = Database.countQuery(
            'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_RecordCurrentLifetime__c <= FEC_RecordLifetime__c'
        );
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_CheckCampaignStatusBatch', totalRecords);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        System.debug('>>> [CheckCampaignStatus] execute() — scope size: ' + scope.size());
        Set<String> accountSet = collectAccountNumbers(scope);
        System.debug('>>> [CheckCampaignStatus] accountSet size: ' + accountSet.size());
        if (accountSet.isEmpty()) {
            System.debug('>>> [CheckCampaignStatus] accountSet is empty — skipping');
            return;
        }

        try {
            String query = 'SELECT ExternalId, CONTRACT_NUMBER__c, RECORD_ID__c, ' +
                'NUMBER4__c, NUMBER5__c, RECORD_CURRENT_LIFETIME__c, ' +
                'INSERTION_DATE__c, CALLBACK_REQUESTED__c, ' +
                'CURRENT_CALL_ATTEMPT__c, IS_MAX_ATTEMPT__c, ' +
                'SEND_TO_COMMSDB__c, SENT_INSTANTLY__c ' +
                'FROM PostgresCampaignLog__x ' +
                'WHERE CONTRACT_NUMBER__c IN :accountSet ' +
                'AND STATUS__c = \'COMPLETED\'';
            System.debug('>>> [CheckCampaignStatus] OData query: ' + query);
            List<SObject> odataResults = Database.query(query);
            System.debug('>>> [CheckCampaignStatus] OData results returned: ' + odataResults.size());

            List<FEC_DataCampaign__c> recordsToUpdate = processODataResults(odataResults, scope);
            System.debug('>>> [CheckCampaignStatus] records to update: ' + recordsToUpdate.size());
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
                System.debug('>>> [CheckCampaignStatus] DML update completed');
            }
            this.processedCount += scope.size();
        } catch (Exception ex) {
            this.errorCount += scope.size();
            this.errorDetails += ex.getMessage() + '\n';
            System.debug('>>> [CheckCampaignStatus] ERROR: ' + ex.getMessage() + ' | StackTrace: ' + ex.getStackTraceString());
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

    private Set<String> collectAccountNumbers(List<FEC_DataCampaign__c> scope) {
        Set<String> accountSet = new Set<String>();
        for (FEC_DataCampaign__c rec : scope) {
            if (String.isNotBlank(rec.FEC_AccountOrContractNumber__c)) {
                accountSet.add(rec.FEC_AccountOrContractNumber__c);
            }
        }
        return accountSet;
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
        rec.FEC_Number4__c = (Decimal) odataData.get('NUMBER4__c');
        rec.FEC_Number5__c = (Decimal) odataData.get('NUMBER5__c');
        rec.FEC_RecordCurrentLifetime__c = (Decimal) odataData.get('RECORD_CURRENT_LIFETIME__c');
        rec.FEC_InsertionDate__c = (DateTime) odataData.get('INSERTION_DATE__c');
        rec.FEC_CallbackRequested__c = (String) odataData.get('CALLBACK_REQUESTED__c');
        rec.FEC_CurrentCallAttempt__c = (Decimal) odataData.get('CURRENT_CALL_ATTEMPT__c');
        rec.FEC_SendToCommsDB__c = (String) odataData.get('SEND_TO_COMMSDB__c');
        rec.FEC_SentInstantly__c = (String) odataData.get('SENT_INSTANTLY__c');

        System.debug('>>> [CheckCampaignStatus] applyODataUpdate — contract: ' + rec.FEC_AccountOrContractNumber__c +
            ' | num4: ' + rec.FEC_Number4__c + ' | num5: ' + rec.FEC_Number5__c +
            ' | lifetime: ' + rec.FEC_RecordCurrentLifetime__c +
            ' | insertion: ' + rec.FEC_InsertionDate__c +
            ' | callback: ' + rec.FEC_CallbackRequested__c +
            ' | attempt: ' + rec.FEC_CurrentCallAttempt__c +
            ' | commsDB: ' + rec.FEC_SendToCommsDB__c +
            ' | sentInstantly: ' + rec.FEC_SentInstantly__c);

        return true;
    }
}
