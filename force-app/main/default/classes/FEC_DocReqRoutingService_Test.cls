@IsTest
private class FEC_DocReqRoutingService_Test {

    private static Group docQueue;

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        docQueue = new Group(
            Name = 'Doc Routing Queue',
            DeveloperName = 'Doc_Routing_Queue_' + suffix.right(8),
            Type = FEC_ConstantCommon.GROUP_TYPE_QUEUE
        );
        insert docQueue;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = docQueue.Id, SobjectType = 'Case');
        }

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Doc Routing BP',
            FEC_Code__c = 'DRBP' + suffix.right(6),
            FEC_Active__c = true
        );
        insert bp;

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Code__c = 'CARD',
            FEC_Active__c = true
        );
        insert prod;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Doc Sub',
            FEC_Code__c = 'DOC',
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'RL04.02',
            FEC_Code__c = 'RL04.02',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
            Name = 'Stage 1 Doc',
            FEC_Code__c = 'STG1-' + suffix.right(6),
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
            Name = 'Stage 2 Doc',
            FEC_Code__c = 'STG2-' + suffix.right(6),
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = false,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        insert new List<FEC_Case_Stage__c>{ stage1, stage2 };

        FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(
            Name = 'Route To',
            FEC_Code__c = 'Route to',
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        insert btnRoute;

        docQueue = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Id = :docQueue.Id
            LIMIT 1
        ];

        insert new List<FEC_Stage_Change__c>{
            new FEC_Stage_Change__c(
                FEC_Previous_Stage__c = stage1.Id,
                FEC_Next_Stage__c = stage2.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_Next_Queue__c = docQueue.DeveloperName,
                FEC_Team_User_Group__c = 'SP',
                FEC_Active__c = true,
                FEC_IsReverted__c = false
            ),
            new FEC_Stage_Change__c(
                FEC_Previous_Stage__c = stage1.Id,
                FEC_Next_Stage__c = stage2.Id,
                FEC_Next_Queue__c = docQueue.Name,
                FEC_Team_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_IsReverted__c = false
            ),
            new FEC_Stage_Change__c(
                FEC_Previous_Stage__c = stage2.Id,
                FEC_Next_Stage__c = stage1.Id,
                FEC_Next_Queue__c = String.valueOf(docQueue.Id),
                FEC_Team_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_IsReverted__c = false
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{
                new Case(
                    Subject = 'Doc Routing Case',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id,
                    FEC_Current_Case_Stage__c = stage1.Id,
                    FEC_ID_Search__c = 'DOC-RT-' + suffix
                ),
                new Case(
                    Subject = 'Doc Routing No Stage',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id,
                    FEC_ID_Search__c = 'DOC-NS-' + suffix
                ),
                new Case(
                    Subject = 'Doc Routing Stage2',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id,
                    FEC_Current_Case_Stage__c = stage2.Id,
                    FEC_ID_Search__c = 'DOC-S2-' + suffix
                )
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getCaseBySubject(String subject) {
        return [SELECT Id, FEC_Current_Case_Stage__c FROM Case WHERE Subject = :subject LIMIT 1];
    }

    private static FEC_Action_Button__c getRouteButton() {
        return [
            SELECT Id
            FROM FEC_Action_Button__c
            WHERE FEC_Code__c = 'Route to'
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetStageChangeRouting_NullCaseId() {
        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(null, 'SP', null, null);
        Test.stopTest();

        System.assertEquals(null, result.nextTeam);
        System.assertEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_EmptyInputs() {
        Case c = getCaseBySubject('Doc Routing Case');

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, null, null, null);
        Test.stopTest();

        System.assertEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_CaseWithoutStage() {
        Case c = getCaseBySubject('Doc Routing No Stage');

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, 'SP', null, null);
        Test.stopTest();

        System.assertEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_SuccessByDeveloperName() {
        Case c = getCaseBySubject('Doc Routing Case');
        Id actionId = getRouteButton().Id;

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, 'SP', actionId, null);
        Test.stopTest();

        System.assertEquals('SP', result.nextTeam);
        System.assertNotEquals(null, result.nextQueueId);
        System.assertNotEquals(null, result.nextQueueLabel);
    }

    @IsTest
    static void testGetStageChangeRouting_SuccessWithPreviousStageId() {
        Case c = getCaseBySubject('Doc Routing No Stage');
        Case staged = getCaseBySubject('Doc Routing Case');
        Id actionId = getRouteButton().Id;

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(
                c.Id,
                'SP',
                actionId,
                staged.FEC_Current_Case_Stage__c
            );
        Test.stopTest();

        System.assertEquals('SP', result.nextTeam);
        System.assertNotEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_TeamOnlyMatch() {
        Case c = getCaseBySubject('Doc Routing Case');

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, 'CC', null, null);
        Test.stopTest();

        System.assertEquals('CC', result.nextTeam);
        System.assertNotEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_ActionOnlyMatch() {
        Case c = getCaseBySubject('Doc Routing Case');
        Id actionId = getRouteButton().Id;

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, null, actionId, null);
        Test.stopTest();

        System.assertNotEquals(null, result.nextQueueId);
    }

    @IsTest
    static void testGetStageChangeRouting_QueueById() {
        Case c = getCaseBySubject('Doc Routing Stage2');
        Group queue = [SELECT Id FROM Group WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE LIMIT 1];

        Test.startTest();
        FEC_DocumentRequestRoutingService.StageRoutingResult result =
            FEC_DocumentRequestRoutingService.getStageChangeRouting(c.Id, 'CC', null, null);
        Test.stopTest();

        System.assertEquals('CC', result.nextTeam);
        System.assertEquals(String.valueOf(queue.Id), result.nextQueueId);
    }
}
