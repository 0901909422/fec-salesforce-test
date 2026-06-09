@IsTest
private class FEC_BCH_CofGsrImportRouteToService_Test {

    private static final String QUEUE_DEV = FEC_ConstantCommon.QUEUE_QUALITY_CONTROL_MAILBOX_NAME;
    private static final String ROUTE_LABEL = 'Route to CS QC - Quality Control Mailbox';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Group q = new Group(
            Name = 'Quality Control Mailbox ' + suffix,
            DeveloperName = QUEUE_DEV,
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
        );
        try {
            insert q;
        } catch (DmlException ex) {
            q = [
                SELECT Id, Name, DeveloperName
                FROM Group
                WHERE DeveloperName = :QUEUE_DEV AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                LIMIT 1
            ];
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            if ([SELECT COUNT() FROM QueueSobject WHERE QueueId = :q.Id] == 0) {
                insert new QueueSobject(QueueId = q.Id, SobjectType = 'Case');
            }
        }
        FEC_Team__c team = new FEC_Team__c(Name = 'QC' + suffix);
        insert team;
        if ([SELECT COUNT() FROM FEC_Team_Queue__c WHERE FEC_Queue_Name__c = :QUEUE_DEV] == 0) {
            insert new FEC_Team_Queue__c(
                FEC_Queue_Name__c = QUEUE_DEV,
                FEC_Select_Team__c = team.Id,
                FEC_Team__c = 'QC'
            );
        }

        Case c = new Case(Subject = 'COF GSR Route To Import', OwnerId = q.Id);
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testLabelParsingHelpers() {
        Test.startTest();
        System.assertEquals(true, FEC_BCH_CofGsrImportRouteToService.isCofGsrRouteToImportLabel(ROUTE_LABEL));
        System.assertEquals(false, FEC_BCH_CofGsrImportRouteToService.isCofGsrRouteToImportLabel('Route to Team'));
        System.assertEquals(
            'Quality Control Mailbox',
            FEC_BCH_CofGsrImportRouteToService.parseQueueLabelFromRouteAction(ROUTE_LABEL)
        );
        System.assertEquals(
            'CS QC',
            FEC_BCH_CofGsrImportRouteToService.parseTeamHintFromRouteAction(ROUTE_LABEL)
        );
        System.assertEquals(
            true,
            FEC_BCH_CofGsrImportRouteToService.isRouteToLabelResolvable(ROUTE_LABEL)
        );
        System.assertEquals(
            QUEUE_DEV,
            FEC_BCH_CofGsrImportRouteToService.resolveQueueDeveloperNameForImport(ROUTE_LABEL)
        );
        Test.stopTest();
    }

    @IsTest
    static void testCollectAndApplyCreateRoutingAssignmentsBulk() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        FEC_BatchCaseHandlingImportRow okRow = new FEC_BatchCaseHandlingImportRow();
        okRow.status = System.Label.FEC_Operation_Success;
        FEC_BatchCaseHandlingImportRow badRow = new FEC_BatchCaseHandlingImportRow();
        badRow.status = System.Label.FEC_Operation_Success;

        List<FEC_BCH_CofGsrImportRouteToService.CreateContext> contexts =
            new List<FEC_BCH_CofGsrImportRouteToService.CreateContext>();
        FEC_BCH_CofGsrImportRouteToService.collectCreateContext(
            okRow,
            c.Id,
            ROUTE_LABEL,
            contexts
        );
        FEC_BCH_CofGsrImportRouteToService.collectCreateContext(
            badRow,
            c.Id,
            'Route to Unknown - No Such Queue',
            contexts
        );
        FEC_BCH_CofGsrImportRouteToService.collectCreateContext(null, c.Id, ROUTE_LABEL, contexts);

        Map<Id, Case> caseLiteById = new Map<Id, Case>{ c.Id => c };

        Test.startTest();
        FEC_BCH_CofGsrImportRouteToService.applyCreateRoutingAssignmentsBulk(contexts, caseLiteById);
        FEC_BCH_CofGsrImportRouteToService.applyCreateRoutingAssignmentsBulk(null, caseLiteById);
        Test.stopTest();

        System.assertEquals(2, contexts.size());
        System.assertEquals(QUEUE_DEV, contexts[0].queueDeveloperName);
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            badRow.status
        );
        System.assert(
            [SELECT COUNT() FROM FEC_Assignment__c WHERE FEC_Case__c = :c.Id] > 0,
            'Valid route label should insert routing assignment.'
        );
    }
}
