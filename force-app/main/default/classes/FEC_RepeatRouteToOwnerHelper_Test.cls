@IsTest
private class FEC_RepeatRouteToOwnerHelper_Test {

    private static final String QUEUE_DEV = 'FEC_RepeatRoute_Test_Q';
    private static final String QUEUE_LABEL = 'FEC Repeat Route Test Queue';

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

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Repeat Route To Owner Test',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'RRTO-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Group targetQueue = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :QUEUE_DEV
            LIMIT 1
        ];

        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Updated_User_Queue_ID__c = String.valueOf(targetQueue.Id),
            FEC_Perform_User__c = UserInfo.getUserId()
        );
    }

    private static Group getTargetQueue() {
        return [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :QUEUE_DEV
            LIMIT 1
        ];
    }

    private static Case getTestCase() {
        return [SELECT Id FROM Case WHERE Subject = 'Repeat Route To Owner Test' LIMIT 1];
    }

    @IsTest
    static void testApplyRepeatRouteToUserOwner_guardClauses() {
        Group q = getTargetQueue();
        String queueIdStr = String.valueOf(q.Id);

        System.assertEquals(
            queueIdStr,
            FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(null, UserInfo.getUserId(), queueIdStr)
        );
        System.assertEquals(
            queueIdStr,
            FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner('', UserInfo.getUserId(), queueIdStr)
        );
        System.assertEquals(
            queueIdStr,
            FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(
                getTestCase().Id,
                null,
                queueIdStr
            )
        );
        System.assertEquals(
            String.valueOf(UserInfo.getUserId()),
            FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(
                String.valueOf(getTestCase().Id),
                UserInfo.getUserId(),
                String.valueOf(UserInfo.getUserId())
            )
        );
        System.assertEquals(
            'not-an-id',
            FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(
                String.valueOf(getTestCase().Id),
                UserInfo.getUserId(),
                'not-an-id'
            )
        );
    }

    @IsTest
    static void testApplyRepeatRouteToUserOwner_firstRouteKeepsQueue() {
        Case c = getTestCase();
        Group q = getTargetQueue();
        delete [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];

        String result = FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(
            String.valueOf(c.Id),
            UserInfo.getUserId(),
            String.valueOf(q.Id)
        );
        System.assertEquals(String.valueOf(q.Id), result, 'First route should keep destination queue.');
    }

    @IsTest
    static void testApplyRepeatRouteToUserOwner_repeatRouteUsesPerformer() {
        Case c = getTestCase();
        Group q = getTargetQueue();

        Test.startTest();
        String result = FEC_RepeatRouteToOwnerHelper.applyRepeatRouteToUserOwner(
            String.valueOf(c.Id),
            q.Id,
            String.valueOf(q.Id)
        );
        Test.stopTest();

        System.assertEquals(String.valueOf(UserInfo.getUserId()), result);
    }
}
