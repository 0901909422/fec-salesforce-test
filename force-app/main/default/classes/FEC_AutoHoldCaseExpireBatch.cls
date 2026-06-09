/**
 * Expires automatic case holds: sets Case.Status from snapshot and completes history rows.
 */
public inherited sharing class FEC_AutoHoldCaseExpireBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id, FEC_Case__c, FEC_Release_Case_Status__c
                FROM FEC_Case_Hold_History__c
                WHERE
                    FEC_Status__c = :FEC_AutoHoldCaseHistoryService.STATUS_ACTIVE
                    AND FEC_Type__c = :FEC_AutoHoldCaseHistoryService.TYPE_AUTO
                    AND FEC_End_Time__c <= :DateTime.now()
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<FEC_Case_Hold_History__c> scope) {
        List<Case> caseUpdates = new List<Case>();
        Map<Integer, Id> indexToHistoryId = new Map<Integer, Id>();

        Integer idx = 0;
        for (FEC_Case_Hold_History__c h : scope) {
            if (h.FEC_Case__c != null && String.isNotBlank(h.FEC_Release_Case_Status__c)) {
                caseUpdates.add(
                    new Case(Id = h.FEC_Case__c, Status = h.FEC_Release_Case_Status__c.trim())
                );
                indexToHistoryId.put(idx, h.Id);
                idx++;
            }
        }

        Set<Id> historyIdsToComplete = new Set<Id>();
        for (FEC_Case_Hold_History__c h : scope) {
            if (h.FEC_Case__c == null || String.isBlank(h.FEC_Release_Case_Status__c)) {
                historyIdsToComplete.add(h.Id);
            }
        }

        if (!caseUpdates.isEmpty()) {
            Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            try {
                Database.SaveResult[] results = Database.update(caseUpdates, false, AccessLevel.SYSTEM_MODE);
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        Id hid = indexToHistoryId.get(i);
                        if (hid != null) {
                            historyIdsToComplete.add(hid);
                        }
                    }
                }
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = prior;
            }
        }

        List<FEC_Case_Hold_History__c> historyUpdates = new List<FEC_Case_Hold_History__c>();
        for (Id historyId : historyIdsToComplete) {
            historyUpdates.add(
                new FEC_Case_Hold_History__c(
                    Id = historyId,
                    FEC_Status__c = FEC_AutoHoldCaseHistoryService.STATUS_COMPLETED
                )
            );
        }
        if (!historyUpdates.isEmpty()) {
            Database.update(historyUpdates, AccessLevel.SYSTEM_MODE);
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
