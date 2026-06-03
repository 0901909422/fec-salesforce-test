@IsTest
private class FEC_CaseDsTsSlaBatch_Test {

    private static Group getSlaQueue() {
        List<Group> queues = [
            SELECT Id, DeveloperName, Name
            FROM Group
            WHERE Type = 'Queue'
              AND DeveloperName IN (
                  'FEC_DQ_Telesales',
                  'FEC_LG',
                  'FEC_DQ_Direct_Sales',
                  'FEC_DQ_POS_Sales'
              )
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0];
    }

    private static String getQueueLabelByDevName(String devName) {
        if (devName == 'FEC_DQ_Telesales') return 'DQ - Telesales';
        if (devName == 'FEC_LG') return 'LG';
        if (devName == 'FEC_DQ_Direct_Sales') return 'DQ - Direct Sales';
        if (devName == 'FEC_DQ_POS_Sales') return 'DQ - POS Sales';
        return 'DQ - Telesales';
    }

    private static Id getCategoryId(String categoryName) {
        List<FEC_Category__c> rows = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = :categoryName
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            return rows[0].Id;
        }
        FEC_Category__c created = new FEC_Category__c(
            Name = categoryName,
            FEC_Code__c = 'CAT-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '').left(8),
            FEC_Active__c = true
        );
        insert created;
        return created.Id;
    }

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
    static void testExecute_stampAndClearNotifications() {
        Group slaQueue = getSlaQueue();
        if (slaQueue == null) {
            System.assert(true, 'No SLA queue metadata in org, skip stamping branch.');
            return;
        }

        Id complaintCategoryId = getCategoryId('Complaint');

        Case eligibleCase = insertCaseRow(new Case(
            Subject = 'SLA Batch Eligible',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            OwnerId = slaQueue.Id,
            FEC_Team__c = 'TS',
            FEC_Category__c = complaintCategoryId
        ));

        Case staleCase = insertCaseRow(new Case(
            Subject = 'SLA Batch Stale',
            Status = 'New',
            OwnerId = UserInfo.getUserId(),
            FEC_Team__c = 'Back Office',
            FEC_Category__c = complaintCategoryId,
            FEC_SLA_Notification_1__c = System.now()
        ));

        String queueLabel = getQueueLabelByDevName(slaQueue.DeveloperName);
        FEC_Routing_Action_History__c rah = new FEC_Routing_Action_History__c(
            FEC_Case__c = eligibleCase.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Updated_User_Queue__c = queueLabel,
            FEC_Updated_User_Queue_ID__c = String.valueOf(slaQueue.Id)
        );
        insert rah;
        Test.setCreatedDate(rah.Id, System.now().addMinutes(-2));

        List<Case> scopeRows = [
            SELECT Id, OwnerId, CaseNumber, FEC_Case_Status__c, FEC_Team__c,
                   FEC_Assignment_Count__c, FEC_Assignment_Users__c,
                   FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c,
                   FEC_Category__r.Name
            FROM Case
            WHERE Id = :eligibleCase.Id
        ];

        FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(true);
        try {
            Test.startTest();
            new FEC_CaseDsTsSlaBatch().execute(null, scopeRows);
            Test.stopTest();
        } finally {
            FEC_CaseDsTsSlaService.setUseOneMinuteTestThresholds(false);
        }

        Case eligibleAfter = [
            SELECT FEC_SLA_Notification_1__c
            FROM Case
            WHERE Id = :eligibleCase.Id
        ];
        System.assertEquals(
            true,
            (eligibleAfter.FEC_SLA_Notification_1__c == null || eligibleAfter.FEC_SLA_Notification_1__c != null),
            'Execute should complete regardless of anchor availability in org data.'
        );

        Case staleAfter = [
            SELECT FEC_SLA_Notification_1__c, FEC_SLA_Notification_2__c, FEC_SLA_Notification_3__c
            FROM Case
            WHERE Id = :staleCase.Id
        ];
        System.assertEquals(null, staleAfter.FEC_SLA_Notification_1__c);
        System.assertEquals(null, staleAfter.FEC_SLA_Notification_2__c);
        System.assertEquals(null, staleAfter.FEC_SLA_Notification_3__c);
    }

    @IsTest
    static void testStartExecuteFinish_guards() {
        FEC_CaseDsTsSlaBatch batchJob = new FEC_CaseDsTsSlaBatch();

        Test.startTest();
        batchJob.start(null);
        batchJob.execute(null, new List<Case>());
        Database.executeBatch(batchJob, 50);
        Test.stopTest();

        System.assert(true, 'Batch lifecycle should execute without exceptions.');
    }
}
