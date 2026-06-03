@IsTest
private class FEC_DocReqRoutingActionService_Test {

    @TestSetup
    static void setupData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(
                Id = UserInfo.getUserId(),
                FEC_User_Group__c = 'CC'
            );
        }

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Doc Request BP',
            FEC_Code__c = 'DOCBP',
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
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCatDoc = new FEC_Sub_Category__c(
            Name = 'Document',
            FEC_Code__c = 'DOC',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCatRl05 = new FEC_Sub_Category__c(
            Name = 'RL05 Cat',
            FEC_Code__c = 'RL05',
            FEC_Active__c = true
        );
        insert new List<FEC_Sub_Category__c>{ subCatDoc, subCatRl05 };

        FEC_Sub_Code__c subCodeRl0402 = new FEC_Sub_Code__c(
            Name = 'RL04.02',
            FEC_Code__c = 'RL04.02',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCodeRl0501 = new FEC_Sub_Code__c(
            Name = 'RL05.01',
            FEC_Code__c = 'RL05.01',
            FEC_Active__c = true
        );
        insert new List<FEC_Sub_Code__c>{ subCodeRl0402, subCodeRl0501 };

        FEC_Nature_of_Case__c nocDoc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCatDoc.Id,
            FEC_Sub_Code__c = subCodeRl0402.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_User_Group__c = 'CC',
            FEC_Active__c = true
        );
        insert nocDoc;

        FEC_Case_Stage__c defaultStage = new FEC_Case_Stage__c(
            Name = 'Stage 1 Open',
            FEC_Code__c = 'STG-DOC-1',
            FEC_Nature_of_Cases__c = nocDoc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        FEC_Case_Stage__c emptyRl05Stage = new FEC_Case_Stage__c(
            Name = 'Stage 1 RL05 Case',
            FEC_Code__c = 'STG-RL05-C',
            FEC_Nature_of_Cases__c = nocDoc.Id,
            FEC_Default_Stage__c = false,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        FEC_Case_Stage__c rl05StageWithScreens = new FEC_Case_Stage__c(
            Name = 'Stage 1 RL05 With Screens',
            FEC_Code__c = 'STG-RL05-S',
            FEC_Nature_of_Cases__c = nocDoc.Id,
            FEC_Default_Stage__c = false,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        FEC_Case_Stage__c templateRl05Stage = new FEC_Case_Stage__c(
            Name = 'RL05.01 Stage 1 Template',
            FEC_Code__c = 'STG-RL05-T',
            FEC_Nature_of_Cases__c = nocDoc.Id,
            FEC_Default_Stage__c = false,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        insert new List<FEC_Case_Stage__c>{ defaultStage, emptyRl05Stage, rl05StageWithScreens, templateRl05Stage };

        FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(
            Name = 'Route To',
            FEC_Code__c = 'Route to',
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        FEC_Action_Button__c btnRevert = new FEC_Action_Button__c(
            Name = 'Revert',
            FEC_Code__c = FEC_ConstantCommon.ACTION_REVERT,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        insert new List<FEC_Action_Button__c>{ btnRoute, btnRevert };

        insert new List<FEC_Stage_Screen__c>{
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = defaultStage.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = defaultStage.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_NEW
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = defaultStage.Id,
                FEC_Action_Button__c = btnRevert.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = 'Revert'
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = templateRl05Stage.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = rl05StageWithScreens.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = rl05StageWithScreens.Id,
                FEC_Action_Button__c = btnRevert.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.ACTION_REVERT
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{
                new Case(
                    Subject = 'Doc RL04 Case',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCatDoc.Id,
                    FEC_SubCode__c = subCodeRl0402.Id,
                    FEC_Customer_Type__c = 'Existing',
                    FEC_Current_Case_Stage__c = defaultStage.Id,
                    FEC_ID_Search__c = 'DOC-RL04-' + String.valueOf(System.currentTimeMillis())
                ),
                new Case(
                    Subject = 'RL05 Case',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCatRl05.Id,
                    FEC_SubCode__c = subCodeRl0501.Id,
                    FEC_Customer_Type__c = 'Existing',
                    FEC_Current_Case_Stage__c = rl05StageWithScreens.Id,
                    FEC_ID_Search__c = 'DOC-RL05-' + String.valueOf(System.currentTimeMillis())
                ),
                new Case(
                    Subject = 'RL05 Template Fallback',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCatRl05.Id,
                    FEC_SubCode__c = subCodeRl0501.Id,
                    FEC_Customer_Type__c = 'Existing',
                    FEC_Current_Case_Stage__c = emptyRl05Stage.Id,
                    FEC_ID_Search__c = 'DOC-RL05-FB-' + String.valueOf(System.currentTimeMillis())
                ),
                new Case(
                    Subject = 'Non RL05 Case',
                    Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCatDoc.Id,
                    FEC_SubCode__c = subCodeRl0402.Id,
                    FEC_Customer_Type__c = 'Existing',
                    FEC_Current_Case_Stage__c = defaultStage.Id,
                    FEC_ID_Search__c = 'DOC-NON-' + String.valueOf(System.currentTimeMillis())
                )
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testIsRl0402OrRl0403SubCode() {
        System.assertEquals(true, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode('RL04.02'));
        System.assertEquals(true, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode(' rl04.03 '));
        System.assertEquals(false, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode('RL05.01'));
        System.assertEquals(false, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode(null));
        System.assertEquals(false, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode(''));
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_NullCaseId() {
        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(null);
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_InvalidCaseId() {
        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(
                '500000000000000AAA'
            );
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_WithStage() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Doc RL04 Case'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'Phải có routing action khi có stage screen.');
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_RevertOnly() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Doc RL04 Case'
            LIMIT 1
        ];
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.REVERT
        );

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'Revert history phải trả action Revert.');
        Boolean hasRevert = false;
        for (FEC_CaseBusinessService.Action act : actions) {
            if (act.code == FEC_ConstantCommon.ACTION_REVERT) {
                hasRevert = true;
            }
        }
        System.assertEquals(true, hasRevert);
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_NullCaseId() {
        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(null);
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_NonRl05Branch() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Non RL05 Case'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(c.Id);
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_WithStageScreens() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'RL05 Case'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'RL05 case phải có routing actions từ stage screen.');
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_RevertAction() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'RL05 Case'
            LIMIT 1
        ];
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.REVERT
        );

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'Revert path RL05 phải trả actions.');
    }
}
