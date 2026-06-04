@IsTest
private class FEC_BCH_AssignmentUpdateService_Test {

    private static final String ROUTING_QUEUE_DEV = 'FEC_BCH_Upd_Test_Q';

    @TestSetup
    static void setupData() {
        ensureQueueByName(FEC_ConstantCommon.QUEUE_HANDLING);
        ensureQueueByName(FEC_ConstantCommon.QUEUE_CARE_INTERNAL_TASK);
        Group routingQueue = ensureQueue(ROUTING_QUEUE_DEV, 'FEC BCH Update Test Queue');

        Case c = new Case(Subject = 'FEC_BCH_AssignmentUpdateService_Test', OwnerId = routingQueue.Id);
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Update Test Assignment',
            FEC_Assignment_Status__c = 'Open'
        );
    }

    @IsTest
    static void testResolveDecisionLabel() {
        Test.startTest();
        System.assertEquals(null, FEC_BCH_AssignmentUpdateService.resolveDecisionLabel(null));
        System.assertEquals(
            'Pending Product',
            FEC_BCH_AssignmentUpdateService.resolveDecisionLabel('pending product')
        );
        System.assertEquals(
            FEC_ConstantCommon.DECISION_CANNOT_CONTACT,
            FEC_BCH_AssignmentUpdateService.resolveDecisionLabel('cannot contact customer')
        );
        System.assertEquals(
            FEC_ConstantCommon.DECISION_OUT_OF_PROCESS,
            FEC_BCH_AssignmentUpdateService.resolveDecisionLabel('out of process')
        );
        System.assertEquals(
            'Custom Decision',
            FEC_BCH_AssignmentUpdateService.resolveDecisionLabel('Custom Decision')
        );
        Test.stopTest();
    }

    @IsTest
    static void testApplyUpdateAssignment_PendingProductAndQueueDecision() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];

        Test.startTest();
        FEC_BCH_AssignmentUpdateService.ApplyResult pendingProduct =
            FEC_BCH_AssignmentUpdateService.applyUpdateAssignment(
                c.Id,
                asg.Id,
                'Pending Product'
            );
        FEC_BCH_AssignmentUpdateService.ApplyResult queueDecision =
            FEC_BCH_AssignmentUpdateService.applyUpdateAssignment(
                c.Id,
                asg.Id,
                FEC_ConstantCommon.DECISION_OUT_OF_PROCESS
            );
        FEC_BCH_AssignmentUpdateService.ApplyResult missingDecision =
            FEC_BCH_AssignmentUpdateService.applyUpdateAssignment(c.Id, asg.Id, '');
        List<FEC_BCH_AssignmentUpdateService.ApplyResult> bulkResults =
            FEC_BCH_AssignmentUpdateService.applyUpdateAssignmentsBulk(
                new List<FEC_BCH_AssignmentUpdateService.UpdateContext>{
                    null,
                    new FEC_BCH_AssignmentUpdateService.UpdateContext(),
                    buildUpdateContext(c.Id, asg.Id, FEC_ConstantCommon.DECISION_CANNOT_CONTACT)
                }
            );
        Test.stopTest();

        System.assertEquals(true, pendingProduct.success);
        System.assertEquals(true, queueDecision.success);
        System.assertEquals(false, missingDecision.success);
        System.assertEquals(3, bulkResults.size());
        System.assertEquals(true, bulkResults[2].success);
    }

    @IsTest
    static void testCollectFromImportRowAndApplyImportBulk() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.assignmentRoutingAction = 'Update to Pending Product';
        row.status = System.Label.FEC_Operation_Success;

        List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem> items =
            new List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem>();
        FEC_BCH_AssignmentUpdateService.collectFromImportRow(
            row,
            true,
            c.Id,
            null,
            asg.Id,
            items
        );
        FEC_BCH_AssignmentUpdateService.collectFromImportRow(
            row,
            false,
            c.Id,
            null,
            asg.Id,
            items
        );

        Test.startTest();
        FEC_BCH_AssignmentUpdateService.applyImportBulk(items);
        FEC_BCH_AssignmentUpdateService.applyImportBulk(new List<FEC_BCH_AssignmentUpdateService.ImportUpdateItem>());
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals('Pending Product', items[0].decision);
    }

    @IsTest
    static void testApplyUpdateAssignmentsBulk_Empty() {
        Test.startTest();
        List<FEC_BCH_AssignmentUpdateService.ApplyResult> results =
            FEC_BCH_AssignmentUpdateService.applyUpdateAssignmentsBulk(null);
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    private static FEC_BCH_AssignmentUpdateService.UpdateContext buildUpdateContext(
        Id caseId,
        Id assignmentId,
        String decision
    ) {
        FEC_BCH_AssignmentUpdateService.UpdateContext ctx = new FEC_BCH_AssignmentUpdateService.UpdateContext();
        ctx.caseId = caseId;
        ctx.assignmentId = assignmentId;
        ctx.decision = decision;
        return ctx;
    }

    private static Group ensureQueue(String developerName, String label) {
        List<Group> existing = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :developerName AND Type = 'Queue'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Group q = new Group(Name = label, DeveloperName = developerName, Type = 'Queue');
        insert q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');
        }
        return q;
    }

    private static void ensureQueueByName(String queueName) {
        if (
            [
                SELECT COUNT()
                FROM Group
                WHERE Name = :queueName AND Type = 'Queue'
            ] > 0
        ) {
            return;
        }
        String devName = 'FEC_BCHUpd_' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 8);
        insert new Group(Name = queueName, DeveloperName = devName, Type = 'Queue');
    }
}
