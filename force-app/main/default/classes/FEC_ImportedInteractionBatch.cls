/****************************************************************************************
 * File Name    : FEC_ImportedInteractionBatch.cls
 * Description  : Batch chạy ngầm xử lý Case Interaction đã import
 * Date         : 2026-05-25
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 *   1.0    2026-05-25     Quangdv7             Create
 ****************************************************************************************/

public without sharing class FEC_ImportedInteractionBatch
    implements Schedulable, Database.Batchable<SObject> {

    private static final Integer BATCH_SIZE = 200;

    public FEC_ImportedInteractionBatch() {
    }

    public static void run() {
        Database.executeBatch(new FEC_ImportedInteractionBatch(), BATCH_SIZE);
    }

    // ================= SCHEDULABLE =================
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, BATCH_SIZE);
    }

    // ================= BATCH =================
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    RecordType.Name,
                    FEC_IsImported__c,
                    FEC_Account_or_Contract__c
                FROM Case
                WHERE
                    FEC_IsImported__c = TRUE
                    AND RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> historyIds = new Set<Id>();
        for (Case item : scope) {
            if (item.FEC_Account_or_Contract__c != null) {
                historyIds.add(item.FEC_Account_or_Contract__c);
            }
        }

        Map<Id, FEC_Customer_History__c> historyById = new Map<Id, FEC_Customer_History__c>();
        if (!historyIds.isEmpty()) {
            historyById = new Map<Id, FEC_Customer_History__c>(
                [
                    SELECT
                        Id,
                        FEC_CIF_Number__c,
                        FEC_Primary_Phone__c,
                        FEC_Account_Number__c,
                        FEC_Contract_Number__c
                    FROM FEC_Customer_History__c
                    WHERE Id IN :historyIds
                ]
            );
        }

        List<Case> casesToUpdate = new List<Case>();
        List<FEC_FullCustomerIntegrationJob.SyncRequest> syncRequests =
            new List<FEC_FullCustomerIntegrationJob.SyncRequest>();

        for (Case item : scope) {
            FEC_Customer_History__c history = historyById.get(item.FEC_Account_or_Contract__c);
            if (history != null) {
                String accountNumber = String.isNotBlank(history.FEC_Account_Number__c)
                    ? history.FEC_Account_Number__c
                    : history.FEC_Contract_Number__c;

                syncRequests.add(
                    new FEC_FullCustomerIntegrationJob.SyncRequest(
                        history.Id,
                        history.FEC_CIF_Number__c,
                        history.FEC_Primary_Phone__c,
                        accountNumber
                    )
                );
            }

            item.FEC_IsImported__c = false;
            casesToUpdate.add(item);
        }

        if (!syncRequests.isEmpty()) {
            System.enqueueJob(new FEC_FullCustomerIntegrationJob(syncRequests));
        }

        if (!casesToUpdate.isEmpty()) {
            FEC_CaseTriggerHandler.isExecuting = true;
            update casesToUpdate;
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
