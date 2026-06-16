@IsTest
private class FEC_DocReqRoutingActionService_Test {

    private static void ensureRunUserMainQueue() {
        Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
        if (!userFields.containsKey('FEC_Main_Queue__c')) {
            return;
        }
        User runUser = new User(Id = UserInfo.getUserId());
        List<Group> queues = [
            SELECT DeveloperName
            FROM Group
            WHERE Type = 'Queue'
              AND DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            LIMIT 1
        ];
        if (queues.isEmpty()) {
            Group q = new Group(
                Name = 'DocReq Action Test CS Support Queue',
                DeveloperName = FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME,
                Type = 'Queue'
            );
            insert q;
            runUser.FEC_Main_Queue__c = q.DeveloperName;
        } else {
            runUser.FEC_Main_Queue__c = queues[0].DeveloperName;
        }
        update runUser;
    }

    @TestSetup
    static void setupData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            ensureRunUserMainQueue();
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
        System.assertEquals(true, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode('RC04.04'));
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

    @IsTest
    static void testGetRoutingActionsForMrcRl05_InvalidCaseId() {
        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(
                '500000000000000AAA'
            );
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_NoUserGroup() {
        User noGroupUser = createUserWithoutGroup();
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'RL05 Case'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions;
        System.runAs(noGroupUser) {
            actions = FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05(c.Id);
        }
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForMrcRl05_NewActionType() {
        FEC_Case_Stage__c stage = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Code__c = 'STG-RL05-S'
            LIMIT 1
        ];
        FEC_Action_Button__c btn = [
            SELECT Id
            FROM FEC_Action_Button__c
            WHERE FEC_Code__c = 'Route to'
            LIMIT 1
        ];
        insert new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stage.Id,
            FEC_Action_Button__c = btn.Id,
            FEC_User_Group__c = 'CC',
            FEC_Active__c = true,
            FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_NEW,
            FEC_Custom_Action_Button_Label__c = 'RL05 New Route'
        );

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

        Boolean hasNewLabel = false;
        for (FEC_CaseBusinessService.Action act : actions) {
            if (act.label == 'RL05 New Route') {
                hasNewLabel = true;
            }
        }
        System.assertEquals(true, hasNewLabel);
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_DefaultStageFallback() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Doc RL04 Case'
            LIMIT 1
        ];
        c.FEC_Current_Case_Stage__c = null;
        update c;

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'Phải resolve default stage khi FEC_Current_Case_Stage__c null.');
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_CustomLabel() {
        FEC_Case_Stage__c stage = [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Code__c = 'STG-DOC-1'
            LIMIT 1
        ];
        FEC_Action_Button__c btn = [
            SELECT Id
            FROM FEC_Action_Button__c
            WHERE FEC_Code__c = 'Route to'
            LIMIT 1
        ];
        insert new FEC_Stage_Screen__c(
            FEC_Case_Stage__c = stage.Id,
            FEC_Action_Button__c = btn.Id,
            FEC_User_Group__c = 'CC',
            FEC_Active__c = true,
            FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL,
            FEC_Custom_Action_Button_Label__c = 'Custom Route Label'
        );

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

        Boolean hasCustom = false;
        for (FEC_CaseBusinessService.Action act : actions) {
            if (act.label == 'Custom Route Label') {
                hasCustom = true;
            }
        }
        System.assertEquals(true, hasCustom);
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_NoUserGroup() {
        User noGroupUser = createUserWithoutGroup();
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Doc RL04 Case'
            LIMIT 1
        ];

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions;
        System.runAs(noGroupUser) {
            actions = FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(
                c.Id
            );
        }
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_RouteToHistory() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Doc RL04 Case'
            LIMIT 1
        ];
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO
        );

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assert(actions.size() > 0, 'Route To history vẫn phải trả New/All actions.');
        Boolean hasRevert = false;
        for (FEC_CaseBusinessService.Action act : actions) {
            if (act.code == FEC_ConstantCommon.ACTION_REVERT) {
                hasRevert = true;
            }
        }
        System.assertEquals(false, hasRevert);
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_MissingNocFields() {
        FEC_CaseTriggerHandler.isExecuting = true;
        Case bareCase;
        try {
            bareCase = new Case(
                Subject = 'Bare Doc Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'DOC-BARE-' + String.valueOf(System.currentTimeMillis())
            );
            insert bareCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(
                bareCase.Id
            );
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_NoMatchingNoc() {
        FEC_Product_Type__c prod = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = 'CARD'
            LIMIT 1
        ];
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE FEC_Code__c = 'Request'
            LIMIT 1
        ];
        FEC_Sub_Category__c subCat = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = 'DOC'
            LIMIT 1
        ];
        FEC_Sub_Code__c orphanSubCode = new FEC_Sub_Code__c(
            Name = 'ORPHAN',
            FEC_Code__c = 'ORPHAN',
            FEC_Active__c = true
        );
        insert orphanSubCode;

        FEC_CaseTriggerHandler.isExecuting = true;
        Case c;
        try {
            c = new Case(
                Subject = 'Orphan NOC Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = orphanSubCode.Id,
                FEC_Customer_Type__c = 'Existing',
                FEC_ID_Search__c = 'DOC-ORPHAN-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    @IsTest
    static void testGetRoutingActionsForRl0402Rl0403_NoDefaultStageOnNoc() {
        FEC_Business_Process__c bp = [
            SELECT Id
            FROM FEC_Business_Process__c
            WHERE FEC_Code__c = 'DOCBP'
            LIMIT 1
        ];
        FEC_Product_Type__c prod = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = 'CARD'
            LIMIT 1
        ];
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE FEC_Code__c = 'Request'
            LIMIT 1
        ];
        FEC_Sub_Category__c subCat = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = 'DOC'
            LIMIT 1
        ];
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'NO-DEF-STG',
            FEC_Code__c = 'NO-DEF-STG',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Customer_Type__c = 'Existing',
            FEC_User_Group__c = 'CC',
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_Case_Stage__c(
            Name = 'Non Default Stage',
            FEC_Code__c = 'STG-NODEF',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = false,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        Case c;
        try {
            c = new Case(
                Subject = 'No Default Stage Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Customer_Type__c = 'Existing',
                FEC_ID_Search__c = 'DOC-NODEF-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_CaseBusinessService.Action> actions =
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(c.Id);
        Test.stopTest();

        System.assertEquals(0, actions.size());
    }

    private static User createUserWithoutGroup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'nogrup',
            Email = 'nogrup' + String.valueOf(System.currentTimeMillis()) + '@test.fec.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoGroup',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'nogrup' + String.valueOf(System.currentTimeMillis()) + '@test.fec.com'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testIsRl0402OrRl0403SubCode_andNullCaseGuards() {
        System.assertEquals(false, FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode(null));
        System.assertEquals(
            true,
            FEC_DocumentRequestRoutingActionService.isRl0402OrRl0403SubCode('RL04.02')
        );
        Test.startTest();
        System.assertEquals(
            0,
            FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403(null).size()
        );
        Test.stopTest();
    }
}
