/**
 * Batch quét Case DS/TS SLA: stamp FEC_SLA_Notification_1/2/3__c hoặc clear khi hết eligible.
 */
public without sharing class FEC_CaseDsTsSlaBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id FROM Case WHERE Id = null LIMIT 0
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id, OwnerId, CaseNumber, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE (
                FEC_Case_Status__c = :FEC_ConstantCommon.CASE_STATUS_PENDING
                OR FEC_Case_Status__c LIKE :FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX
                OR FEC_Case_Status__c LIKE 'Pending -%'
            )
            AND FEC_Category__r.Name IN ('Complaint', 'Feedback')
            /* Team DS/TS: lọc trong execute (teamContainsDsOrTs), không LIKE %DS%/%TS% — Telesales/LG không khớp LIKE */
            AND (
                (
                    (FEC_Assignment_Count__c = 0 OR FEC_Assignment_Count__c = NULL)
                    AND OwnerId IN :queueIds
                )
                OR (
                    FEC_Assignment_Count__c > 0
                    AND (
                        FEC_Assignment_Users__c LIKE '%DQ - Direct Sales%'
                        OR FEC_Assignment_Users__c LIKE '%DQ - POS Sales%'
                        OR FEC_Assignment_Users__c LIKE '%DQ - Telesales%'
                        OR FEC_Assignment_Users__c LIKE '%LG%'
                    )
                )
            )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Datetime nowDt = System.now();
        Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext> contextsByCaseId =
            new Map<Id, FEC_CaseDsTsSlaService.SlaEligibilityContext>();

        for (Case row : scope) {
            FEC_CaseDsTsSlaService.SlaEligibilityContext ctx =
                FEC_CaseDsTsSlaService.evaluateEligibility(row);
            if (ctx.isEligible) {
                contextsByCaseId.put(row.Id, ctx);
            }
        }

        FEC_CaseDsTsSlaService.bulkResolveAnchors(contextsByCaseId);

        List<Case> patches = new List<Case>();
        for (Case row : scope) {
            FEC_CaseDsTsSlaService.SlaEligibilityContext ctx = contextsByCaseId.get(row.Id);
            Case patch = FEC_CaseDsTsSlaService.buildNotificationPatch(row, ctx, nowDt);
            if (patch != null) {
                patches.add(patch);
            }
        }

        if (!patches.isEmpty()) {
            for (Case patch : patches) {
                FEC_CaseInitUpdateService.registerSystemCaseUpdate(patch.Id);
            }
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            try {
                update patches;
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }

        clearStaleNotifications();
    }

    public void finish(Database.BatchableContext bc) {
    }

    private void clearStaleNotifications() {
        List<Case> stale = [
            SELECT Id, OwnerId, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE (
                FEC_SLA_Notification_1__c != NULL
                OR FEC_SLA_Notification_2__c != NULL
                OR FEC_SLA_Notification_3__c != NULL
            )
            LIMIT 200
        ];

        List<Case> clearPatches = new List<Case>();
        for (Case row : stale) {
            FEC_CaseDsTsSlaService.SlaEligibilityContext ctx =
                FEC_CaseDsTsSlaService.evaluateEligibility(row);
            if (!ctx.isEligible && FEC_CaseDsTsSlaService.needsClearNotifications(row)) {
                Case patch = new Case(Id = row.Id);
                patch.FEC_SLA_Notification_1__c = null;
                patch.FEC_SLA_Notification_2__c = null;
                patch.FEC_SLA_Notification_3__c = null;
                clearPatches.add(patch);
            }
        }

        if (!clearPatches.isEmpty()) {
            FEC_CaseTriggerHandler.isSystemUpdate = true;
            try {
                update clearPatches;
            } finally {
                FEC_CaseTriggerHandler.isSystemUpdate = false;
            }
        }
    }
}
