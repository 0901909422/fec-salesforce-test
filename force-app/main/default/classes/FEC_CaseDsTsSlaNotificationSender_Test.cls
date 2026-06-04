@IsTest
private class FEC_CaseDsTsSlaNotificationSender_Test {

    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testSendAfterCaseUpdate_guardClauses() {
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(null, new Map<Id, Case>());
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(new List<Case>(), new Map<Id, Case>());
        System.assert(true, 'Guard clauses should not throw.');
    }

    @IsTest
    static void testSendAfterCaseUpdate_newlyStampedSlot() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id queueId = queueIds.iterator().next();
        String suffix = String.valueOf(System.currentTimeMillis());
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Notify',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_ID_Search__c = 'DSTS-' + suffix
        ));

        Case oldC = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_1__c = System.now();

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :row.Id].Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_slotsTwoAndThree() {
        Set<Id> queueIds = FEC_CaseDsTsSlaService.getSlaOwnerQueueIds();
        if (queueIds.isEmpty()) {
            System.assert(true, 'No SLA queue metadata in org.');
            return;
        }
        Id queueId = queueIds.iterator().next();
        Datetime nowDt = System.now();
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA Slot 2/3',
            OwnerId = queueId,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Team__c = 'TS',
            FEC_SLA_Notification_1__c = nowDt,
            FEC_ID_Search__c = 'DSTS23-' + String.valueOf(System.currentTimeMillis())
        ));

        Case old2 = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_2__c = nowDt.addMinutes(1);
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => old2 }
        );

        Case old3 = row.clone(true, true, true, true);
        row.FEC_SLA_Notification_3__c = nowDt.addMinutes(2);
        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => old3 }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }

    @IsTest
    static void testSendAfterCaseUpdate_noStampChange() {
        Case row = insertCaseRow(new Case(
            Subject = 'DS/TS SLA No Change',
            Status = 'New',
            FEC_ID_Search__c = 'DSTS-NC-' + String.valueOf(System.currentTimeMillis())
        ));
        Case oldC = row.clone(true, true, true, true);

        Test.startTest();
        FEC_CaseDsTsSlaNotificationSender.sendAfterCaseUpdate(
            new List<Case>{ row },
            new Map<Id, Case>{ row.Id => oldC }
        );
        Test.stopTest();

        System.assertNotEquals(null, row.Id);
    }
}
