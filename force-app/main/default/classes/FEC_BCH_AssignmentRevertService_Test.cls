@IsTest
private class FEC_BCH_AssignmentRevertService_Test {

    private static final String REVERT_QUEUE_DEV = 'FEC_BCH_Revert_Test_Q';

    @TestSetup
    static void setupData() {
        Group routingQueue = ensureQueue(REVERT_QUEUE_DEV, 'FEC BCH Revert Test Queue');
        Case c = new Case(Subject = 'FEC_BCH_AssignmentRevertService_Test', OwnerId = routingQueue.Id);
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Revert Test Assignment',
            FEC_Assignment_Status__c = 'Open',
            FEC_Assignment_Owner__c = UserInfo.getUserId(),
            FEC_OwnerID__c = UserInfo.getUserId()
        );
    }

    @IsTest
    static void testResolveRevertDecisionFromLabel() {
        Test.startTest();
        System.assertEquals(null, FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel(null));
        System.assertEquals(
            FEC_ConstantCommon.DECISION_USER,
            FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel('Revert to User')
        );
        System.assertEquals(
            FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE,
            FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel('Revert to User\'s Team Queue')
        );
        System.assertEquals(null, FEC_BCH_AssignmentRevertService.resolveRevertDecisionFromLabel('Resolve'));
        Test.stopTest();
    }

    @IsTest
    static void testApplyRevertToUser() {
        Case c = [SELECT Id, CreatedById FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];

        FEC_BCH_AssignmentRevertService.RevertContext ctx = new FEC_BCH_AssignmentRevertService.RevertContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;
        ctx.decision = FEC_ConstantCommon.DECISION_USER;

        Test.startTest();
        List<FEC_BCH_AssignmentRevertService.ApplyResult> results =
            FEC_BCH_AssignmentRevertService.applyRevertAssignmentsBulk(
                new List<FEC_BCH_AssignmentRevertService.RevertContext>{ ctx }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        FEC_Assignment__c loaded = [
            SELECT FEC_Assignment_Status__c, FEC_Assignment_Owner__c, FEC_OwnerID__c
            FROM FEC_Assignment__c
            WHERE Id = :asg.Id
        ];
        System.assertEquals(FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR, loaded.FEC_Assignment_Status__c);
        System.assertEquals(c.CreatedById, loaded.FEC_Assignment_Owner__c);
        System.assertEquals(String.valueOf(c.CreatedById), String.valueOf(loaded.FEC_OwnerID__c));
    }

    @IsTest
    static void testApplyRevertToTeamQueue() {
        Group queue = ensureQueue(REVERT_QUEUE_DEV, 'FEC BCH Revert Test Queue');
        User runUser = [SELECT Id, FEC_Main_Queue__c FROM User WHERE Id = :UserInfo.getUserId()];
        runUser.FEC_Main_Queue__c = queue.DeveloperName;
        update runUser;

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];

        FEC_BCH_AssignmentRevertService.RevertContext ctx = new FEC_BCH_AssignmentRevertService.RevertContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;
        ctx.decision = FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE;

        Test.startTest();
        List<FEC_BCH_AssignmentRevertService.ApplyResult> results =
            FEC_BCH_AssignmentRevertService.applyRevertAssignmentsBulk(
                new List<FEC_BCH_AssignmentRevertService.RevertContext>{ ctx }
            );
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        FEC_Assignment__c loaded = [
            SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Assignment_Status__c
            FROM FEC_Assignment__c
            WHERE Id = :asg.Id
        ];
        System.assertEquals(null, loaded.FEC_Assignment_Owner__c);
        System.assertEquals(queue.Name, loaded.FEC_OwnerID__c);
        System.assertEquals(FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR, loaded.FEC_Assignment_Status__c);
    }

    @IsTest
    static void testCollectFromImportRowAndApplyImportBulk() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.assignmentRoutingAction = 'Revert to User';
        row.status = System.Label.FEC_Operation_Success;

        List<FEC_BCH_AssignmentRevertService.ImportRevertItem> items =
            new List<FEC_BCH_AssignmentRevertService.ImportRevertItem>();
        FEC_BCH_AssignmentRevertService.collectFromImportRow(
            row,
            true,
            true,
            c.Id,
            asg.Id,
            FEC_CaseBusinessService.REVERT,
            items
        );
        FEC_BCH_AssignmentRevertService.collectFromImportRow(
            row,
            false,
            true,
            c.Id,
            asg.Id,
            FEC_CaseBusinessService.REVERT,
            items
        );

        Test.startTest();
        FEC_BCH_AssignmentRevertService.applyImportBulk(items);
        FEC_BCH_AssignmentRevertService.applyImportBulk(new List<FEC_BCH_AssignmentRevertService.ImportRevertItem>());
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals(FEC_ConstantCommon.DECISION_USER, items[0].decision);
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
}
