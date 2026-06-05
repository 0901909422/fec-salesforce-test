/**
 * Gửi bell SLA DS/TS khi FEC_SLA_Notification_1/2/3__c được stamp (trigger after update).
 */
public without sharing class FEC_CaseDsTsSlaNotificationSender {

    public static void sendAfterCaseUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        if (newCases == null || newCases.isEmpty() || oldMap == null) {
            return;
        }
        if (!Test.isRunningTest()) {
            FEC_CaseDsTsSlaSchedulable.ensureScheduled();
        }

        List<Case> toNotify = new List<Case>();
        Map<Id, Integer> slotByCaseId = new Map<Id, Integer>();

        for (Case c : newCases) {
            Case oldC = oldMap.get(c.Id);
            if (oldC == null) {
                continue;
            }
            Integer slot = detectNewlyStampedSlot(c, oldC);
            if (slot == null) {
                continue;
            }
            toNotify.add(c);
            slotByCaseId.put(c.Id, slot);
        }

        if (toNotify.isEmpty()) {
            return;
        }

        CustomNotificationType notifType;
        try {
            notifType = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Custom_Notification'
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('FEC_DEBUG DS/TS SLA notify type error: ' + e.getMessage());
            return;
        }

        Map<Id, Case> enriched = new Map<Id, Case>([
            SELECT Id, FEC_ID_Search__c, OwnerId, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE Id IN :slotByCaseId.keySet()
        ]);

        for (Case c : toNotify) {
            Case row = enriched.get(c.Id);
            if (row == null) {
                continue;
            }
            FEC_CaseDsTsSlaService.SlaEligibilityContext ctx =
                FEC_CaseDsTsSlaService.evaluateEligibility(row);
            if (!ctx.isEligible) {
                continue;
            }
            Set<String> recipients = FEC_CaseDsTsSlaService.resolveRecipientUserIds(ctx);
            if (recipients.isEmpty()) {
                continue;
            }
            FEC_CommonUltils.notifyUsers(
                recipients,
                row.Id,
                null,
                FEC_CaseDsTsSlaService.getApproachingTitle(row),
                FEC_CaseDsTsSlaService.getApproachingBody(row),
                notifType
            );
        }
    }

    private static Integer detectNewlyStampedSlot(Case newC, Case oldC) {
        if (newC.FEC_SLA_Notification_1__c != oldC.FEC_SLA_Notification_1__c
            && newC.FEC_SLA_Notification_1__c != null) {
            return 1;
        }
        if (newC.FEC_SLA_Notification_2__c != oldC.FEC_SLA_Notification_2__c
            && newC.FEC_SLA_Notification_2__c != null) {
            return 2;
        }
        if (newC.FEC_SLA_Notification_3__c != oldC.FEC_SLA_Notification_3__c
            && newC.FEC_SLA_Notification_3__c != null) {
            return 3;
        }
        return null;
    }
}
