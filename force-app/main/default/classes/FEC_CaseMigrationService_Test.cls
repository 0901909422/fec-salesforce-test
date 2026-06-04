@IsTest
private class FEC_CaseMigrationService_Test {

    @TestSetup
    static void setupData() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), FEC_User_Group__c = 'CC');
        }

        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Migration BP',
            FEC_Code__c = 'MIGBP',
            FEC_Active__c = true
        );
        insert bp;

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Migration Product',
            FEC_Code__c = 'MIGP',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Migration Category',
            FEC_Code__c = 'MIGC',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Migration SubCat',
            FEC_Code__c = 'MIGS',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Migration SubCode',
            FEC_Code__c = 'MIGSC',
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

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Migration Stage 1',
            FEC_Code__c = 'MIG-STG-1',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id
        );
        insert stage;

        FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(
            Name = 'Route To',
            FEC_Code__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        FEC_Action_Button__c btnResolve = new FEC_Action_Button__c(
            Name = 'Resolve',
            FEC_Code__c = FEC_CaseBusinessService.RESOLVE,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        insert new List<FEC_Action_Button__c>{ btnRoute, btnResolve };

        insert new List<FEC_Stage_Screen__c>{
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnResolve.Id,
                FEC_User_Group__c = 'CC',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Migration Service Test Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Customer_Type__c = 'Existing',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'MIG-CASE-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetRoutingActionlstForApex_InvalidAndValid() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_CaseMigrationService.RoutingActionListResult blank =
            FEC_CaseMigrationService.getRoutingActionlstForApex('');
        FEC_CaseMigrationService.RoutingActionListResult valid =
            FEC_CaseMigrationService.getRoutingActionlstForApex(String.valueOf(c.Id));
        try {
            FEC_CaseMigrationService.getRoutingActionlst(null);
            System.assert(false, 'Blank case id should throw AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();

        System.assertEquals(false, blank.success);
        System.assertNotEquals(null, blank.message);
        System.assertEquals(true, valid.success);
        System.assert(valid.data.size() > 0, 'Configured stage screen should expose routing actions.');
    }

    @IsTest
    static void testMoveNextStageForApex() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_CaseMigrationService.RoutingActionListResult actions =
            FEC_CaseMigrationService.getRoutingActionlstForApex(String.valueOf(c.Id));

        Test.startTest();
        FEC_CaseMigrationService.MoveNextStageListResult blankCase =
            FEC_CaseMigrationService.moveNextStageForApex('', FEC_CaseBusinessService.RESOLVE);
        FEC_CaseMigrationService.MoveNextStageListResult invalidAction =
            FEC_CaseMigrationService.moveNextStageForApex(String.valueOf(c.Id), 'Not_A_Action');
        FEC_CaseMigrationService.MoveNextStageListResult resolveMove =
            FEC_CaseMigrationService.moveNextStageForApex(
                String.valueOf(c.Id),
                FEC_CaseBusinessService.RESOLVE
            );
        if (actions.success && !actions.data.isEmpty()) {
            FEC_CaseMigrationService.moveNextStageForApex(
                String.valueOf(c.Id),
                actions.data[0].code
            );
        }
        Test.stopTest();

        System.assertEquals(false, blankCase.success);
        System.assertEquals(false, invalidAction.success);
        System.assertEquals(true, resolveMove.success);
    }

    @IsTest
    static void testMoveNextStage_AuraWrapper() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_CaseMigrationService.moveNextStage(String.valueOf(c.Id), 'invalid_action');
            System.assert(false, 'Invalid action should throw AuraHandledException.');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        List<FEC_CaseMigrationService.MoveNextStageItem> items =
            FEC_CaseMigrationService.moveNextStage(
                String.valueOf(c.Id),
                FEC_CaseBusinessService.RESOLVE
            );
        Test.stopTest();

        System.assertNotEquals(null, items);
    }
}
