@IsTest
private class FEC_BCH_ImportRoutingResolver_Test {

    private static final String USER_GROUP_CC = 'CC';

    @TestSetup
    static void setupRoutingData() {
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'BCH Import Routing BP',
            FEC_Code__c = 'BCHRT',
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
            Name = 'BCH Sub',
            FEC_Code__c = 'BCH',
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'BCH.01',
            FEC_Code__c = 'BCH.01',
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = USER_GROUP_CC,
            FEC_Active__c = true
        );
        insert noc;

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'BCH Import Stage',
            FEC_Code__c = 'BCH-STG',
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true,
            FEC_Business_Process__c = bp.Id,
            FEC_User_Group__c = USER_GROUP_CC
        );
        insert stage;

        FEC_Action_Button__c btnResolve = new FEC_Action_Button__c(
            Name = 'Resolve',
            FEC_Code__c = FEC_CaseBusinessService.RESOLVE,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(
            Name = 'Route To',
            FEC_Code__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        FEC_Action_Button__c btnRevert = new FEC_Action_Button__c(
            Name = 'Revert',
            FEC_Code__c = FEC_CaseBusinessService.REVERT,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        FEC_Action_Button__c btnEscalate = new FEC_Action_Button__c(
            Name = 'Escalate',
            FEC_Code__c = FEC_CaseBusinessService.ESCALATE,
            FEC_Type__c = FEC_ConstantCommon.ACTION_BUTTON_TYPE_ROUTING_ACTION,
            FEC_Active__c = true
        );
        insert new List<FEC_Action_Button__c>{ btnResolve, btnRoute, btnRevert, btnEscalate };

        insert new List<FEC_Stage_Screen__c>{
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnResolve.Id,
                FEC_Code__c = 'SCR-RESOLVE',
                FEC_User_Group__c = USER_GROUP_CC,
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnRoute.Id,
                FEC_Code__c = 'SCR-ROUTE',
                FEC_Custom_Action_Button_Label__c = 'Team Alpha - Queue Beta',
                FEC_User_Group__c = USER_GROUP_CC,
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnRevert.Id,
                FEC_Code__c = 'SCR-REVERT',
                FEC_User_Group__c = USER_GROUP_CC,
                FEC_Active__c = true,
                FEC_Field_Type__c = 'New'
            ),
            new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stage.Id,
                FEC_Action_Button__c = btnEscalate.Id,
                FEC_Code__c = FEC_CaseBusinessService.ESCALATE,
                FEC_User_Group__c = 'SP',
                FEC_Active__c = true,
                FEC_Field_Type__c = FEC_ConstantCommon.STAGE_SCREEN_FIELD_TYPE_ALL
            )
        };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'BCH Import Routing Case',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'BCH-RT-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static FEC_Case_Stage__c getTestStage() {
        return [
            SELECT Id
            FROM FEC_Case_Stage__c
            WHERE FEC_Code__c = 'BCH-STG'
            LIMIT 1
        ];
    }

    @IsTest
    static void testClearCache_andPreloadStageScreens_emptyOrNull() {
        FEC_BCH_ImportRoutingResolver.clearCache();

        FEC_BCH_ImportRoutingResolver.preloadStageScreens(null, USER_GROUP_CC);
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(new Set<Id>(), USER_GROUP_CC);

        FEC_BCH_ImportRoutingResolver.ResolvedRouting out =
            FEC_BCH_ImportRoutingResolver.resolve(getTestStage().Id, FEC_CaseBusinessService.RESOLVE);

        System.assertEquals(false, out.matchedStageScreen, 'Cache empty after null/empty preload.');
    }

    @IsTest
    static void testResolve_nullStageOrBlankLabel() {
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(
            new Set<Id>{ getTestStage().Id },
            USER_GROUP_CC
        );

        FEC_BCH_ImportRoutingResolver.ResolvedRouting nullStage =
            FEC_BCH_ImportRoutingResolver.resolve(null, 'Resolve');
        System.assertEquals(false, nullStage.matchedStageScreen);

        FEC_BCH_ImportRoutingResolver.ResolvedRouting blankLabel =
            FEC_BCH_ImportRoutingResolver.resolve(getTestStage().Id, '   ');
        System.assertEquals(false, blankLabel.matchedStageScreen);
    }

    @IsTest
    static void testResolve_resolve_matchesStageScreen() {
        Id stageId = getTestStage().Id;
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(
            new Set<Id>{ stageId },
            USER_GROUP_CC
        );

        FEC_BCH_ImportRoutingResolver.ResolvedRouting out =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, FEC_CaseBusinessService.RESOLVE);

        System.assertEquals(true, out.matchedStageScreen);
        System.assertNotEquals(null, out.actionButtonId);
        System.assertEquals(FEC_CaseBusinessService.RESOLVE, out.methodKey);
    }

    @IsTest
    static void testResolve_routeTo_parsesTeamAndQueue() {
        Id stageId = getTestStage().Id;
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(
            new Set<Id>{ stageId },
            USER_GROUP_CC
        );

        String excelLabel = 'Route to Team Alpha - Queue Beta';
        FEC_BCH_ImportRoutingResolver.ResolvedRouting out =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, excelLabel);

        System.assertEquals(true, out.matchedStageScreen);
        System.assertEquals(FEC_CaseBusinessService.ROUTE_TO, out.methodKey);
        System.assertEquals('Team Alpha', out.routeTeamHint);
        System.assertEquals('Queue Beta', out.routeQueueHint);
    }

    @IsTest
    static void testResolve_revert_prefersNewFieldType() {
        Id stageId = getTestStage().Id;
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(
            new Set<Id>{ stageId },
            USER_GROUP_CC
        );

        FEC_BCH_ImportRoutingResolver.ResolvedRouting out =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, 'Revert');

        System.assertEquals(true, out.matchedStageScreen);
        System.assertEquals(FEC_CaseBusinessService.REVERT, out.methodKey);
    }

    @IsTest
    static void testResolve_ignoreUserGroupFilter_loadsSpScreen() {
        Id stageId = getTestStage().Id;
        FEC_BCH_ImportRoutingResolver.clearCache();
        FEC_BCH_ImportRoutingResolver.preloadStageScreens(
            new Set<Id>{ stageId },
            USER_GROUP_CC
        );

        FEC_BCH_ImportRoutingResolver.ResolvedRouting filtered =
            FEC_BCH_ImportRoutingResolver.resolve(stageId, FEC_CaseBusinessService.ESCALATE);
        System.assertEquals(false, filtered.matchedStageScreen);

        FEC_BCH_ImportRoutingResolver.ResolvedRouting allGroups =
            FEC_BCH_ImportRoutingResolver.resolve(
                stageId,
                FEC_CaseBusinessService.ESCALATE,
                true
            );
        System.assertEquals(true, allGroups.matchedStageScreen);
        System.assertEquals(FEC_CaseBusinessService.ESCALATE, allGroups.methodKey);
    }

    @IsTest
    static void testRequiresStageScreenMatch() {
        System.assertEquals(
            false,
            FEC_BCH_ImportRoutingResolver.requiresStageScreenMatch(
                FEC_CaseBusinessService.TRANSFER
            )
        );
        System.assertEquals(
            true,
            FEC_BCH_ImportRoutingResolver.requiresStageScreenMatch(
                FEC_CaseBusinessService.RESOLVE
            )
        );
        System.assertEquals(
            true,
            FEC_BCH_ImportRoutingResolver.requiresStageScreenMatch(null)
        );
    }
}
