public without sharing class FEC_SyncCaseStatusBatch implements Database.Batchable<FEC_Routing_Action_History__c> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, FEC_Changed_Status__c
            FROM FEC_Routing_Action_History__c
            WHERE CreatedDate = YESTERDAY
            AND FEC_Changed_Status__c != NULL
        ]);
    }

    public void execute(Database.BatchableContext bc, List<FEC_Routing_Action_History__c> scope) {
        Set<String> statusNames = new Set<String>();
        for (FEC_Routing_Action_History__c rec : scope) {
            if (String.isNotBlank(rec.FEC_Changed_Status__c)) {
                statusNames.add(rec.FEC_Changed_Status__c.trim());
            }
        }

        if (statusNames.isEmpty()
            || !Schema.sObjectType.FEC_Case_Status__c.isAccessible()
            || !Schema.sObjectType.FEC_Case_Status__c.fields.Name.isAccessible()
            || !Schema.sObjectType.FEC_Case_Status__c.isCreateable()
            || !Schema.sObjectType.FEC_Case_Status__c.fields.Name.isCreateable()) {
            return;
        }

        Map<String, FEC_Case_Status__c> existingByName = new Map<String, FEC_Case_Status__c>();
        for (FEC_Case_Status__c statusRec : [
            SELECT Id, Name
            FROM FEC_Case_Status__c
            WHERE Name IN :statusNames
        ]) {
            existingByName.put(statusRec.Name, statusRec);
        }

        List<FEC_Case_Status__c> toInsert = new List<FEC_Case_Status__c>();
        for (String statusName : statusNames) {
            if (!existingByName.containsKey(statusName)) {
                toInsert.add(new FEC_Case_Status__c(
                    Name = statusName
                ));
            }
        }

        insert toInsert;
    }

    public void finish(Database.BatchableContext bc) {
    }
}