/*------------------------------------------------------------
Author:        DuanNguyen
Company:       Isobar
Description:   Batch sync specific records by IDs without updating CustomSync__c and without recall
Test Class:    FEC_BatchCustomSyncByIdsTest
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/05/04     DuanNguyen                 Init
------------------------------------------------------------*/
/*
    // Usage:
    Map<Id,Case> mCase = new Map<Id,Case>([Select id from Case limit 100]);
    FEC_BatchCustomSyncByIds batch = new FEC_BatchCustomSyncByIds('CustomSyncID', mCase.keyset());
    Database.executeBatch(batch, 10);
*/
global class FEC_BatchCustomSyncByIds implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id customSyncId;
    private Set<Id> recordIds;
    private CustomSync__c cus;
    private List<FEC_API_Log__c> logs = new List<FEC_API_Log__c>();

    public FEC_BatchCustomSyncByIds(Id customSyncId, Set<Id> recordIds) {
        this.customSyncId = customSyncId;
        this.recordIds = recordIds;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        this.cus = [
            SELECT Id, Name, WhatSync__c, TableName__c, TargetObject__c,
                   RequestBodyMapping__c, MappingDataType__c, PkColumn__c,
                   ProcessingQuantity__c
            FROM CustomSync__c
            WHERE Id = :customSyncId
            LIMIT 1
        ];

        String fieldList = FEC_BatchCustomSync.extractFieldsFromMapping(cus.RequestBodyMapping__c);
        String queryString = 'SELECT ' + fieldList + ' FROM ' + cus.TargetObject__c + ' WHERE Id IN :recordIds';
        return Database.getQueryLocator(queryString);
    }

    global void execute(Database.BatchableContext bc, List<sObject> scope) {
        FEC_API_Log__c log = new FEC_API_Log__c();
        log.FEC_Custom_Sync__c = cus.Id;
        try {
            if (scope == null || scope.isEmpty())  return;
            List<String> scopeIds = new List<String>();
            for (Id reId : new Map<Id, sObject>(scope).keySet()) {
                scopeIds.add(String.valueOf(reId));
            }
            log.Records__c = JSON.serialize(scopeIds);
            List<FEC_API_Log__c> resultLogs = FEC_CustomSyncCallout.sendRequest(cus, log, scope);
            for (FEC_API_Log__c rLog : resultLogs) {
                if (rLog.FEC_Is_Success__c ?? false) rLog.FEC_Error_Message__c = null;
                logs.add(rLog);
            } 
            return;
        } catch (Exception e) {
            log.FEC_Error_Message__c = 'Exception FEC_BatchCustomSyncByIds: Line ' + e.getLineNumber() + ' - ' + e.getMessage();
        }
        logs.add(log);
    }

    global void finish(Database.BatchableContext bc) { 
        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}
