@IsTest
private class FEC_BCH_AssignmentRouteToService_Test {

    private static final String QUEUE_DEV = 'FEC_BCH_RouteTo_Test_Q';
    private static final String QUEUE_LABEL = 'FEC BCH RouteTo Test Queue';
    private static final String TEAM_CODE = 'RouteToTeam';

    @TestSetup
    static void setupData() {
        Group q = new Group(
            Name = QUEUE_LABEL,
            DeveloperName = QUEUE_DEV,
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
        );
        insert q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');
        }
        FEC_Team__c team = new FEC_Team__c(Name = TEAM_CODE);
        insert team;
        insert new FEC_Team_Queue__c(
            FEC_Queue_Name__c = QUEUE_DEV,
            FEC_Select_Team__c = team.Id,
            FEC_Team__c = TEAM_CODE
        );

        Case c = new Case(Subject = 'FEC_BCH_AssignmentRouteToService_Test');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        insert new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Name__c = 'Route To Test Assignment'
        );
    }

    @IsTest
    static void testResolveQueueDeveloperName() {
        Test.startTest();
        System.assertEquals(
            'FEC_Token_From_Stage',
            FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(
                ' FEC_Token_From_Stage ',
                null,
                null
            )
        );
        System.assertEquals(null, FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(null, null, null));
        System.assertEquals(
            QUEUE_DEV,
            FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(null, 'CS', QUEUE_LABEL)
        );
        System.assertEquals(
            FEC_ConstantCommon.QUEUE_QUALITY_CONTROL_MAILBOX_NAME,
            FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(
                null,
                'CS QC',
                'Quality Control Mailbox'
            )
        );
        Test.stopTest();
    }

    @IsTest
    static void testApplyRouteToAssignment_ValidationAndSuccess() {
        FEC_Assignment__c asg = [SELECT Id FROM FEC_Assignment__c LIMIT 1];
        Datetime submittedOn = Datetime.newInstance(2026, 6, 1, 10, 0, 0);

        Test.startTest();
        FEC_BCH_AssignmentRouteToService.ApplyResult missingId =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignment(null, QUEUE_DEV, submittedOn);
        FEC_BCH_AssignmentRouteToService.ApplyResult missingQueue =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignment(asg.Id, '', submittedOn);
        FEC_BCH_AssignmentRouteToService.ApplyResult success =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignment(asg.Id, QUEUE_DEV, null);
        List<FEC_BCH_AssignmentRouteToService.ApplyResult> bulkResults =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignmentsBulk(
                new List<FEC_BCH_AssignmentRouteToService.RouteToContext>{
                    null,
                    new FEC_BCH_AssignmentRouteToService.RouteToContext(),
                    buildContext(asg.Id, 'MissingTeamQueue', submittedOn),
                    buildContext(asg.Id, QUEUE_DEV, submittedOn)
                }
            );
        Test.stopTest();

        System.assertEquals(false, missingId.success);
        System.assertEquals(false, missingQueue.success);
        System.assertEquals(true, success.success);
        System.assertEquals(4, bulkResults.size());
        System.assertEquals(true, bulkResults[3].success);

        FEC_Assignment__c updated = [
            SELECT FEC_OwnerID__c, FEC_Team__c, FEC_Assignment_Owner__c, FEC_User_Role__c, FEC_Submitted_On__c
            FROM FEC_Assignment__c
            WHERE Id = :asg.Id
        ];
        System.assertEquals(null, updated.FEC_Assignment_Owner__c);
        System.assertEquals(null, updated.FEC_User_Role__c);
        System.assertEquals(QUEUE_LABEL, updated.FEC_OwnerID__c);
        System.assertEquals(TEAM_CODE, updated.FEC_Team__c);
        System.assertNotEquals(null, updated.FEC_Submitted_On__c);
    }

    @IsTest
    static void testApplyRouteToAssignmentsBulk_EmptyInput() {
        Test.startTest();
        List<FEC_BCH_AssignmentRouteToService.ApplyResult> empty =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignmentsBulk(null);
        List<FEC_BCH_AssignmentRouteToService.ApplyResult> emptyList =
            FEC_BCH_AssignmentRouteToService.applyRouteToAssignmentsBulk(
                new List<FEC_BCH_AssignmentRouteToService.RouteToContext>()
            );
        Test.stopTest();

        System.assertEquals(0, empty.size());
        System.assertEquals(0, emptyList.size());
    }

    private static FEC_BCH_AssignmentRouteToService.RouteToContext buildContext(
        Id assignmentId,
        String queueDevName,
        Datetime submittedOn
    ) {
        FEC_BCH_AssignmentRouteToService.RouteToContext ctx = new FEC_BCH_AssignmentRouteToService.RouteToContext();
        ctx.assignmentId = assignmentId;
        ctx.queueDeveloperName = queueDevName;
        ctx.submittedOn = submittedOn;
        return ctx;
    }
}
