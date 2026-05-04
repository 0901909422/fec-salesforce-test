/**
 * FEC_CheckCampaignStatusBatch
 * Batch job to check campaign record status via OData external object.
 * Uses dynamic SOQL to query PostgresCampaignLog__x and update records.
 */
public with sharing class FEC_CheckCampaignStatusBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    private Id batchLogId;
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private String errorDetails = '';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new FEC_CheckCampaignStatusBatch());
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, FEC_RecordId__c, FEC_RecordStatus__c, ' +
            'FEC_InsertionDate__c, FEC_CurrentCallAttempt__c, ' +
            'FEC_RecordCurrentLifetime__c, FEC_RecordLifeTime__c, FEC_Number4__c, FEC_Number5__c, ' +
            'FEC_CallbackRequested__c, FEC_SendToCommsDB__c, FEC_AccountOrContractNumber__c ' +
            'FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_IsWithinLifetime__c = true';

        Integer totalRecords = Database.countQuery(
            'SELECT count() FROM FEC_DataCampaign__c ' +
            'WHERE FEC_IsPushed__c = true ' +
            'AND (NOT FEC_RecordStatus__c LIKE \'Resolved-%\') ' +
            'AND FEC_IsWithinLifetime__c = true'
        );
        this.batchLogId = FEC_CampaignBatchLogger.logStart('FEC_CheckCampaignStatusBatch', totalRecords);

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<FEC_DataCampaign__c> scope) {
        System.debug('>>> [CheckCampaignStatus] execute() — scope size: ' + scope.size());
        Set<String> accountSet = collectAccountNumbers(scope);
        System.debug('>>> [CheckCampaignStatus] accountSet size: ' + accountSet.size());
        Set<String> recordIdSet = new Set<String>();
        for (FEC_DataCampaign__c rec : scope) {
            if (String.isNotBlank(rec.FEC_RecordId__c)) {
                recordIdSet.add(rec.FEC_RecordId__c);
            }
        }
        System.debug('>>> [CheckCampaignStatus] recordIdSet size: ' + recordIdSet.size());
        if (accountSet.isEmpty() || recordIdSet.isEmpty()) {
            System.debug('>>> [CheckCampaignStatus] accountSet or recordIdSet is empty — skipping');
            return;
        }

        try {
            String query = 'SELECT account_or_contract_number__c, record_id__c, ' +
                'number4__c, number5__c, record_current_lifetime__c, ' +
                'insertion_date__c, callback_requested__c, ' +
                'current_call_attempt__c, is_max_attempt__c, ' +
                'send_to_commsdb__c, sent_instantly__c ' +
                'FROM PostgresCampaignLog__x ' +
                'WHERE account_or_contract_number__c IN :accountSet ' +
                'AND record_id__c IN :recordIdSet ' +
                'AND status__c = \'COMPLETED\'';
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
            String accountNumber = (String) odataRec.get('account_or_contract_number__c');
            String recordId = (String) odataRec.get('record_id__c');
            if (String.isNotBlank(accountNumber) && String.isNotBlank(recordId)) {
                resultMap.put(accountNumber + '_' + recordId, odataRec);
            }
        }

        List<FEC_DataCampaign__c> recordsToUpdate = new List<FEC_DataCampaign__c>();
        for (FEC_DataCampaign__c rec : scope) {
            String compositeKey = rec.FEC_AccountOrContractNumber__c + '_' + rec.FEC_RecordId__c;
            if (resultMap.containsKey(compositeKey)) {
                SObject odataData = resultMap.get(compositeKey);
                if (applyODataUpdate(rec, odataData)) {
                    recordsToUpdate.add(rec);
                }
            }
        }
        return recordsToUpdate;
    }

    @TestVisible
    private Boolean applyODataUpdate(FEC_DataCampaign__c rec, SObject odataData) {
        rec.FEC_Number4__c = FEC_CommonUltils.parseDecimal(odataData.get('number4__c'));
        rec.FEC_Number5__c = FEC_CommonUltils.parseDecimal(odataData.get('number5__c'));
        rec.FEC_RecordCurrentLifetime__c = FEC_CommonUltils.parseDecimal(odataData.get('record_current_lifetime__c'));
        rec.FEC_InsertionDate__c = FEC_CommonUltils.parseDateTime(odataData.get('insertion_date__c'));
        rec.FEC_CallbackRequested__c = (String) odataData.get('callback_requested__c');
        rec.FEC_CurrentCallAttempt__c = FEC_CommonUltils.parseDecimal(odataData.get('current_call_attempt__c'));
        rec.FEC_SendToCommsDB__c = (String) odataData.get('send_to_commsdb__c');
        rec.FEC_SentInstantly__c = (String) odataData.get('sent_instantly__c');
        rec.FEC_IsMaxAttempt__c = (String) odataData.get('is_max_attempt__c');

        System.debug('>>> [CheckCampaignStatus] applyODataUpdate — contract: ' + rec.FEC_AccountOrContractNumber__c +
            ' | recordId: ' + rec.FEC_RecordId__c +
            ' | num4: ' + rec.FEC_Number4__c + ' | num5: ' + rec.FEC_Number5__c +
            ' | lifetime: ' + rec.FEC_RecordCurrentLifetime__c +
            ' | insertion: ' + rec.FEC_InsertionDate__c +
            ' | callback: ' + rec.FEC_CallbackRequested__c +
            ' | attempt: ' + rec.FEC_CurrentCallAttempt__c +
            ' | commsDB: ' + rec.FEC_SendToCommsDB__c +
            ' | sentInstantly: ' + rec.FEC_SentInstantly__c +
            ' | isMaxAttempt: ' + rec.FEC_IsMaxAttempt__c);

        return true;
    }
}
