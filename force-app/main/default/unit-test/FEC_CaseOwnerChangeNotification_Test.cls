@IsTest
private class FEC_CaseOwnerChangeNotification_Test {

    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Group getExistingQueueWithEmail() {
        List<Group> queues = [
            SELECT Id, Email
            FROM Group
            WHERE Type = 'Queue'
              AND Email != null
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0];
    }

    @IsTest
    static void testSendNotificationToNewOwner_userAndQueue() {
        Group queueGroup = getExistingQueueWithEmail();

        Case c1 = insertCaseRow(new Case(
            Subject = 'Owner Change User',
            Status = 'New'
        ));
        Case c2 = insertCaseRow(new Case(
            Subject = 'Owner Change Queue',
            Status = 'New'
        ));
        Case c3 = insertCaseRow(new Case(
            Subject = 'Owner Not Changed',
            Status = 'New'
        ));

        Map<Id, Case> oldMap = new Map<Id, Case>{
            c1.Id => new Case(Id = c1.Id, OwnerId = c1.OwnerId),
            c2.Id => new Case(Id = c2.Id, OwnerId = c2.OwnerId),
            c3.Id => new Case(Id = c3.Id, OwnerId = c3.OwnerId)
        };

        List<Case> newCases = new List<Case>{
            new Case(Id = c1.Id, OwnerId = UserInfo.getUserId()),
            new Case(Id = c2.Id, OwnerId = queueGroup != null ? queueGroup.Id : c2.OwnerId),
            new Case(Id = c3.Id, OwnerId = c3.OwnerId)
        };

        Test.startTest();
        FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner(newCases, oldMap);
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assert(emailInvocations > 0, 'Should send email for owner change cases.');
    }

    @IsTest
    static void testSendNotificationToNewOwner_guardAndNoOwnerChanged() {
        Case c = insertCaseRow(new Case(
            Subject = 'No Change',
            Status = 'New'
        ));
        Map<Id, Case> oldMap = new Map<Id, Case>{
            c.Id => new Case(Id = c.Id, OwnerId = c.OwnerId)
        };
        List<Case> unchanged = new List<Case>{
            new Case(Id = c.Id, OwnerId = c.OwnerId)
        };

        Test.startTest();
        FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner(null, oldMap);
        FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner(unchanged, null);
        FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner(unchanged, oldMap);
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, emailInvocations, 'Guard/no-change flows should not send emails.');
    }

    @IsTest
    static void testSendNotificationToNewOwner_emailBatchChunking() {
        List<Case> insertedCases = new List<Case>();
        for (Integer i = 0; i < 11; i++) {
            insertedCases.add(insertCaseRow(new Case(
                Subject = 'Chunking Case ' + i,
                Status = 'New'
            )));
        }

        Map<Id, Case> oldMap = new Map<Id, Case>();
        List<Case> newCases = new List<Case>();
        for (Case c : insertedCases) {
            oldMap.put(c.Id, new Case(Id = c.Id, OwnerId = c.OwnerId));
            // force owner changed and route to current user (always has an email in org test context)
            newCases.add(new Case(Id = c.Id, OwnerId = UserInfo.getUserId()));
        }

        Test.startTest();
        FEC_CaseOwnerChangeNotification.sendNotificationToNewOwner(newCases, oldMap);
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(2, emailInvocations, '11 emails should be sent in 2 batches (10 + 1).');
    }
}
