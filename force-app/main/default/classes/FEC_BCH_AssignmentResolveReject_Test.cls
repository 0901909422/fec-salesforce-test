@IsTest
private class FEC_BCH_AssignmentResolveReject_Test {

    @TestSetup
    static void setupData() {
        Case c = new Case(Subject = 'FEC_BCH_AssignmentResolveReject_Test');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Resolve Reject Test Assignment',
            FEC_Assignment_Status__c = 'Open'
        );
    }

    @IsTest
    static void testIsResolveOrRejectMethodKey() {
        Test.startTest();
        System.assertEquals(false, FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(null));
        System.assertEquals(false, FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(''));
        System.assertEquals(
            true,
            FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(FEC_CaseBusinessService.RESOLVE)
        );
        System.assertEquals(
            true,
            FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey(FEC_CaseBusinessService.REJECT)
        );
        System.assertEquals(false, FEC_BCH_AssignmentResolveRejectService.isResolveOrRejectMethodKey('Route'));
        Test.stopTest();
    }

    @IsTest
    static void testCollectFromImportRow() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem> items =
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>();

        Test.startTest();
        FEC_BCH_AssignmentResolveRejectService.collectFromImportRow(
            row,
            true,
            true,
            c.Id,
            asg.Id,
            FEC_CaseBusinessService.RESOLVE,
            items
        );
        FEC_BCH_AssignmentResolveRejectService.collectFromImportRow(
            null,
            true,
            true,
            c.Id,
            asg.Id,
            FEC_CaseBusinessService.RESOLVE,
            items
        );
        FEC_BCH_AssignmentResolveRejectService.applyImportBulk(null);
        FEC_BCH_AssignmentResolveRejectService.applyImportBulk(
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>()
        );
        Test.stopTest();

        System.assertEquals(1, items.size());
        System.assertEquals(asg.Id, items[0].assignmentId);
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, items[0].methodKey);
    }

    @IsTest
    static void testApplyResolveRejectAssignmentsBulk() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];

        FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext ctx =
            new FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;
        ctx.submittedOn = System.now();

        Test.startTest();
        List<FEC_BCH_AssignmentResolveRejectService.ApplyResult> results =
            FEC_BCH_AssignmentResolveRejectService.applyResolveRejectAssignmentsBulk(
                new List<FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext>{ ctx }
            );
        FEC_BCH_AssignmentResolveRejectService.applyImportBulk(
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>{
                buildImportItem(asg.Id, c.Id, FEC_CaseBusinessService.RESOLVE)
            }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        FEC_Assignment__c loaded = [
            SELECT FEC_Assignment_Status__c, FEC_Assignment_Owner__c
            FROM FEC_Assignment__c
            WHERE Id = :asg.Id
        ];
        System.assertEquals(FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED, loaded.FEC_Assignment_Status__c);
        System.assertEquals(UserInfo.getUserId(), loaded.FEC_Assignment_Owner__c);
    }

    @IsTest
    static void testApplyResolveRejectAssignmentsBulk_MissingIds() {
        Test.startTest();
        List<FEC_BCH_AssignmentResolveRejectService.ApplyResult> results =
            FEC_BCH_AssignmentResolveRejectService.applyResolveRejectAssignmentsBulk(
                new List<FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext>{
                    new FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext()
                }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assertNotEquals(null, results[0].errorMessage);
    }

    @IsTest
    static void testApplyResolveReject_WithQueueOwnerSync() {
        String queueDev = 'FEC_BCH_RR_Sync_Q';
        Group queue = new Group(
            Name = 'RR Sync Queue',
            DeveloperName = queueDev,
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
        );
        insert queue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
        }

        Case c = new Case(Subject = 'Resolve Reject Queue Sync');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Open Owner Assignment',
            FEC_Assignment_Status__c = 'Open',
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );

        FEC_Assignment__c asg = new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Queue Owner Assignment',
            FEC_Assignment_Status__c = 'Open',
            FEC_OwnerID__c = String.valueOf(queue.Id)
        );
        insert asg;

        FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext ctx =
            new FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;

        Test.startTest();
        List<FEC_BCH_AssignmentResolveRejectService.ApplyResult> results =
            FEC_BCH_AssignmentResolveRejectService.applyResolveRejectAssignmentsBulk(
                new List<FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext>{ ctx }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        Case refreshed = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
        System.assert(
            String.isNotBlank(refreshed.FEC_Assignment_Users__c),
            'Open assignment owner should sync to Case.FEC_Assignment_Users__c.'
        );
    }

    @IsTest
    static void testSyncAssignmentUsers_PlainQueueNameOwner() {
        Case c = new Case(Subject = 'Resolve Reject Plain Queue Name');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Plain Queue Name Assignment',
            FEC_Assignment_Status__c = 'Open',
            FEC_OwnerID__c = 'DQ - CS Support'
        );
        FEC_Assignment__c asg = new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Resolve Target Assignment',
            FEC_Assignment_Status__c = 'Open',
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
        insert asg;

        FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext ctx =
            new FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;

        Test.startTest();
        FEC_BCH_AssignmentResolveRejectService.applyResolveRejectAssignmentsBulk(
            new List<FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext>{ ctx }
        );
        Test.stopTest();

        Case refreshed = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
        System.assert(String.isNotBlank(refreshed.FEC_Assignment_Users__c));
    }

    @IsTest
    static void testApplyImportBulk_InvalidItemsSkipped() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem badItem =
            new FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem();
        badItem.row = row;

        Test.startTest();
        FEC_BCH_AssignmentResolveRejectService.applyImportBulk(
            new List<FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem>{ badItem }
        );
        Test.stopTest();

        System.assertNotEquals(null, row);
    }

    @IsTest
    static void testSyncMainCaseResolveWhenNoActiveAssignments() {
        Case c = [SELECT Id, Status FROM Case LIMIT 1];
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];

        FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext ctx =
            new FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext();
        ctx.caseId = c.Id;
        ctx.assignmentId = asg.Id;

        Test.startTest();
        FEC_BCH_AssignmentResolveRejectService.applyResolveRejectAssignmentsBulk(
            new List<FEC_BCH_AssignmentResolveRejectService.ResolveRejectContext>{ ctx }
        );
        Set<Id> resolvedCaseIds = FEC_BCH_AssignmentResolveRejectService.syncMainCaseResolveWhenNoActiveAssignments(
            new Set<Id>{ c.Id }
        );
        Test.stopTest();

        System.assertEquals(true, resolvedCaseIds.contains(c.Id));
        Case refreshed = [SELECT Status FROM Case WHERE Id = :c.Id];
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED, refreshed.Status);
    }

    @IsTest
    static void testSyncMainCaseResolveWhenNoActiveAssignments_EmptyInput() {
        Test.startTest();
        Set<Id> resolvedCaseIds = FEC_BCH_AssignmentResolveRejectService.syncMainCaseResolveWhenNoActiveAssignments(
            null
        );
        Test.stopTest();
        System.assertEquals(true, resolvedCaseIds.isEmpty());
    }

    private static FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem buildImportItem(
        Id assignmentId,
        Id caseId,
        String methodKey
    ) {
        FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem item =
            new FEC_BCH_AssignmentResolveRejectService.ImportResolveRejectItem();
        item.row = new FEC_BatchCaseHandlingImportRow();
        item.assignmentId = assignmentId;
        item.caseId = caseId;
        item.methodKey = methodKey;
        return item;
    }
}
