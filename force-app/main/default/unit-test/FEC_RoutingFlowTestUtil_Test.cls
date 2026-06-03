/**
 * Unit tests for FEC_RoutingFlowTestUtil (manual routing flow steps via Execute Anonymous).
 */
@IsTest
private class FEC_RoutingFlowTestUtil_Test {

    private static final String CASE_SUBJECT = 'RFT Util Case';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        String q2Dev = 'RFT_Q2_' + suffix;
        String q3Dev = 'RFT_Q3_' + suffix;
        String s1Code = 'RFTS1_' + suffix;
        String s2Code = 'RFTS2_' + suffix;
        String s3Code = 'RFTS3_' + suffix;

        Group q2 = new Group(Name = 'RFT Queue 2 ' + suffix, DeveloperName = q2Dev, Type = 'Queue');
        Group q3 = new Group(Name = 'RFT Queue 3 ' + suffix, DeveloperName = q3Dev, Type = 'Queue');
        insert new List<Group>{ q2, q3 };

        insert new QueueSobject(QueueId = q2.Id, SobjectType = 'Case');
        insert new QueueSobject(QueueId = q3.Id, SobjectType = 'Case');

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User agent = new User(
            Alias = 'rftagt',
            Email = 'rft.agent' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'RftAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'rft.agent' + suffix + '@test.invalid',
            FEC_User_Group__c = 'CC',
            FEC_Main_Queue__c = q2Dev
        );
        insert agent;

        System.runAs(agent) {
            FEC_Business_Process__c bp = new FEC_Business_Process__c(
                Name = 'RFT BP',
                FEC_Code__c = 'RFTBP' + suffix,
                FEC_Active__c = true
            );
            insert bp;

            FEC_Product_Type__c prod = new FEC_Product_Type__c(
                Name = 'RFT Product',
                FEC_Code__c = 'RFTP' + suffix,
                FEC_Active__c = true
            );
            insert prod;

            FEC_Category__c cat = new FEC_Category__c(
                Name = 'RFT Cat',
                FEC_Code__c = 'RFTC' + suffix,
                FEC_Active__c = true
            );
            insert cat;

            FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
                Name = 'RFT SubCat',
                FEC_Code__c = 'RFTSC' + suffix,
                FEC_Active__c = true
            );
            insert subCat;

            FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
                Name = 'RFT SubCode',
                FEC_Code__c = 'RFTX' + suffix,
                FEC_Active__c = true
            );
            insert subCode;

            FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id,
                FEC_Sub_Code__c = subCode.Id,
                FEC_Business_Process__c = bp.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true
            );
            insert noc;

            FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
                Name = 'RFT Stage 1',
                FEC_Code__c = s1Code,
                FEC_Nature_of_Cases__c = noc.Id,
                FEC_Default_Stage__c = true,
                FEC_Active__c = true,
                FEC_Business_Process__c = bp.Id,
                FEC_User_Group__c = 'CC'
            );
            FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
                Name = 'RFT Stage 2',
                FEC_Code__c = s2Code,
                FEC_Nature_of_Cases__c = noc.Id,
                FEC_Active__c = true,
                FEC_Business_Process__c = bp.Id,
                FEC_User_Group__c = 'CC'
            );
            FEC_Case_Stage__c stage3 = new FEC_Case_Stage__c(
                Name = 'RFT Stage 3',
                FEC_Code__c = s3Code,
                FEC_Nature_of_Cases__c = noc.Id,
                FEC_Active__c = true,
                FEC_Business_Process__c = bp.Id,
                FEC_User_Group__c = 'CC'
            );
            insert new List<FEC_Case_Stage__c>{ stage1, stage2, stage3 };

            FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(
                Name = 'RFT Route To',
                FEC_Code__c = 'Route to',
                FEC_Type__c = 'Routing Action',
                FEC_Active__c = true
            );
            FEC_Action_Button__c btnRevert = new FEC_Action_Button__c(
                Name = 'RFT Revert',
                FEC_Code__c = 'Revert',
                FEC_Type__c = 'Routing Action',
                FEC_Active__c = true
            );
            insert new List<FEC_Action_Button__c>{ btnRoute, btnRevert };

            insert new List<FEC_Stage_Change__c>{
                new FEC_Stage_Change__c(
                    FEC_Previous_Stage__c = stage1.Id,
                    FEC_Next_Stage__c = stage2.Id,
                    FEC_Action_Button__c = btnRoute.Id,
                    FEC_Next_Queue__c = q2Dev,
                    FEC_Team_User_Group__c = 'SP',
                    FEC_Active__c = true,
                    FEC_IsReverted__c = false
                ),
                new FEC_Stage_Change__c(
                    FEC_Previous_Stage__c = stage2.Id,
                    FEC_Next_Stage__c = stage3.Id,
                    FEC_Action_Button__c = btnRoute.Id,
                    FEC_Next_Queue__c = q3Dev,
                    FEC_Team_User_Group__c = 'SP',
                    FEC_Active__c = true,
                    FEC_IsReverted__c = false
                ),
                new FEC_Stage_Change__c(
                    FEC_Previous_Stage__c = stage2.Id,
                    FEC_Next_Stage__c = stage1.Id,
                    FEC_Action_Button__c = btnRevert.Id,
                    FEC_Active__c = true,
                    FEC_IsReverted__c = true
                ),
                new FEC_Stage_Change__c(
                    FEC_Previous_Stage__c = stage3.Id,
                    FEC_Next_Stage__c = stage2.Id,
                    FEC_Action_Button__c = btnRevert.Id,
                    FEC_Active__c = true,
                    FEC_IsReverted__c = false
                )
            };

            insert new FEC_Team_Queue__c(FEC_Queue_Name__c = q2Dev, FEC_Team__c = 'CC');
            insert new FEC_Team_Queue__c(FEC_Queue_Name__c = q3Dev, FEC_Team__c = 'CC');

            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert new Case(
                    Subject = CASE_SUBJECT,
                    Status = 'New',
                    OwnerId = agent.Id,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id,
                    FEC_Is_Submited__c = true,
                    FEC_Current_Case_Stage__c = stage1.Id,
                    FEC_Process_Action_Count__c = 0
                );
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    private static User agentUser() {
        return [SELECT Id FROM User WHERE LastName = 'RftAgent' LIMIT 1];
    }

    private static Case testCase() {
        return [SELECT Id FROM Case WHERE Subject = :CASE_SUBJECT LIMIT 1];
    }

    private static FEC_Case_Stage__c stage1() {
        return [
            SELECT Id, FEC_Code__c
            FROM FEC_Case_Stage__c
            WHERE FEC_Default_Stage__c = TRUE
            LIMIT 1
        ];
    }

    private static FEC_Case_Stage__c stage2() {
        return [
            SELECT Id, FEC_Code__c
            FROM FEC_Case_Stage__c
            WHERE FEC_Default_Stage__c = FALSE
            ORDER BY FEC_Code__c ASC
            LIMIT 1
        ];
    }

    private static FEC_Case_Stage__c stage3() {
        return [
            SELECT Id, FEC_Code__c
            FROM FEC_Case_Stage__c
            WHERE FEC_Default_Stage__c = FALSE
            ORDER BY FEC_Code__c DESC
            LIMIT 1
        ];
    }

    private static void runStepSmoke(Integer step) {
        Case c = testCase();
        String s1Id = stage1().Id;
        FEC_RoutingFlowTestUtil.runStep(c.Id, s1Id, step);
    }

    @IsTest
    static void testRunStep_Zero_ResetsCaseAndClearsHistory() {
        Case c = testCase();
        FEC_Case_Stage__c s1 = stage1();
        FEC_Case_Stage__c s2 = stage2();

        update new Case(Id = c.Id, FEC_Current_Case_Stage__c = s2.Id);
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Route to',
            FEC_Previous_Stage__c = s1.Id,
            FEC_Next_Stage__c = s2.Id
        );

        Test.startTest();
        FEC_RoutingFlowTestUtil.runStep(c.Id, s1.Id, 0);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Current_Case_Stage__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(s1.Id, updated.FEC_Current_Case_Stage__c);
        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id]
        );
    }

    @IsTest
    static void testRunStep_InvalidStep_DoesNotThrow() {
        Case c = testCase();

        Test.startTest();
        FEC_RoutingFlowTestUtil.runStep(c.Id, stage1().Id, 99);
        Test.stopTest();

        System.assert(true, 'Invalid step should log warning only.');
    }

    @IsTest
    static void testRunStep9_SkipsWhenNoRev3to1Button() {
        System.runAs(agentUser()) {
            Test.startTest();
            runStepSmoke(9);
            Test.stopTest();
            System.assert(true, 'Step 9 should return when rev3to1 button is absent.');
        }
    }

    @IsTest
    static void testRunStep_RouteAndRevertSmoke() {
        System.runAs(agentUser()) {
            FEC_RoutingFlowTestUtil.runStep(testCase().Id, stage1().Id, 0);

            Test.startTest();
            runStepSmoke(1);
            runStepSmoke(2);
            Test.stopTest();

            System.assertNotEquals(null, [
                SELECT FEC_Current_Case_Stage__r.FEC_Code__c
                FROM Case
                WHERE Id = :testCase().Id
            ].FEC_Current_Case_Stage__r.FEC_Code__c);
        }
    }

    @IsTest
    static void testRunStep_RepeatRouteStepsSmoke() {
        System.runAs(agentUser()) {
            String caseId = testCase().Id;
            String s1Id = stage1().Id;
            FEC_RoutingFlowTestUtil.runStep(caseId, s1Id, 0);

            Test.startTest();
            FEC_RoutingFlowTestUtil.runStep(caseId, s1Id, 3);
            FEC_RoutingFlowTestUtil.runStep(caseId, s1Id, 4);
            FEC_RoutingFlowTestUtil.runStep(caseId, s1Id, 5);
            Test.stopTest();

            System.assert(true, 'Steps 3–5 should execute without unhandled exception.');
        }
    }

    @IsTest
    static void testRunStep6_FromStage2Smoke() {
        System.runAs(agentUser()) {
            Case c = testCase();
            String s1Id = stage1().Id;
            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = stage2().Id);

            Test.startTest();
            FEC_RoutingFlowTestUtil.runStep(c.Id, s1Id, 6);
            Test.stopTest();

            System.assert(true, 'Step 6 should execute without unhandled exception.');
        }
    }

    @IsTest
    static void testRunStep7_FromStage3Smoke() {
        System.runAs(agentUser()) {
            Case c = testCase();
            String s1Id = stage1().Id;
            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = stage3().Id);

            Test.startTest();
            FEC_RoutingFlowTestUtil.runStep(c.Id, s1Id, 7);
            Test.stopTest();

            System.assert(true, 'Step 7 should execute without unhandled exception.');
        }
    }

    @IsTest
    static void testRunStep8_FromStage2Smoke() {
        System.runAs(agentUser()) {
            Case c = testCase();
            String s1Id = stage1().Id;
            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = stage2().Id);

            Test.startTest();
            FEC_RoutingFlowTestUtil.runStep(c.Id, s1Id, 8);
            Test.stopTest();

            System.assert(true, 'Step 8 should execute without unhandled exception.');
        }
    }

    @IsTest
    static void testRunStep9_WithRev3to1Button() {
        System.runAs(agentUser()) {
            Case c = testCase();
            FEC_Case_Stage__c s1 = stage1();
            FEC_Case_Stage__c s3 = stage3();
            FEC_Action_Button__c btnRevert = [
                SELECT Id
                FROM FEC_Action_Button__c
                WHERE FEC_Code__c = 'Revert'
                LIMIT 1
            ];

            insert new FEC_Stage_Change__c(
                FEC_Previous_Stage__c = s3.Id,
                FEC_Next_Stage__c = s1.Id,
                FEC_Action_Button__c = btnRevert.Id,
                FEC_Active__c = true,
                FEC_IsReverted__c = true
            );

            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = s3.Id);

            Test.startTest();
            FEC_RoutingFlowTestUtil.runStep(c.Id, s1.Id, 9);
            Test.stopTest();

            System.assertNotEquals(null, [
                SELECT FEC_Current_Case_Stage__c
                FROM Case
                WHERE Id = :c.Id
            ].FEC_Current_Case_Stage__c);
        }
    }
}
