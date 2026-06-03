@IsTest
private class FEC_HoldCaseStage2DisplayService_Test {

    private static HoldCaseData seedHoldCaseData() {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Hold S2 PT',
            FEC_Code__c = 'S2PT' + suffix,
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Hold S2 Cat',
            FEC_Code__c = 'S2CT' + suffix,
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subA = new FEC_Sub_Category__c(
            Name = 'Hold Sub A',
            FEC_Code__c = 'S2SA' + suffix,
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subB = new FEC_Sub_Category__c(
            Name = 'Hold Sub B',
            FEC_Code__c = 'S2SB' + suffix,
            FEC_Active__c = true
        );
        insert new List<SObject>{ pt, cat, subA, subB };

        FEC_Nature_of_Case__c nocA = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subA.Id,
            FEC_Active__c = true
        );
        FEC_Nature_of_Case__c nocB = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subB.Id,
            FEC_Active__c = true
        );
        insert new List<FEC_Nature_of_Case__c>{ nocA, nocB };

        FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(
            Name = 'Stage 1 Initial',
            FEC_Code__c = 'S2S1' + suffix,
            FEC_Nature_of_Cases__c = nocA.Id,
            FEC_Default_Stage__c = true
        );
        FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(
            Name = 'Stage 2 Processing',
            FEC_Code__c = 'S2S2' + suffix,
            FEC_Nature_of_Cases__c = nocA.Id,
            FEC_Default_Stage__c = false
        );
        insert new List<FEC_Case_Stage__c>{ stage1, stage2 };

        insert new FEC_Hold_Case__c(
            FEC_NFU_Code__c = 'NFU-S2-' + suffix,
            FEC_NFU_Reason_VN__c = 'Hold S2 reason',
            FEC_NFU_Duration__c = 30
        );

        HoldCaseData data = new HoldCaseData();
        data.ptId = pt.Id;
        data.catId = cat.Id;
        data.subAId = subA.Id;
        data.subBId = subB.Id;
        data.stage2Id = stage2.Id;
        data.nocBId = nocB.Id;
        return data;
    }

    private class HoldCaseData {
        Id ptId;
        Id catId;
        Id subAId;
        Id subBId;
        Id stage2Id;
        Id nocBId;
    }

    private static Case insertSubmittedCase(
        HoldCaseData data,
        String stage1Result,
        Integer processActionCount
    ) {
        Case c = new Case(
            Subject = 'Hold Stage2 Test',
            Status = 'New',
            FEC_Team__c = FEC_ConstantCommon.TEAM_CS_SUPPORT,
            FEC_Is_Submited__c = true,
            FEC_Product_Type__c = data.ptId,
            FEC_Category__c = data.catId,
            FEC_SubCategory__c = data.subAId,
            FEC_Current_Case_Stage__c = data.stage2Id,
            FEC_NFU_Description_Result__c = stage1Result,
            FEC_Process_Action_Count__c = processActionCount
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testEvaluate_NullCaseId() {
        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                null, null, null, null, null, null, null, null, null
            );
        Test.stopTest();

        System.assertEquals(FEC_HoldCaseStage2DisplayService.MODE_DEFAULT, result.displayMode);
        System.assertEquals(false, result.showHoldCaseSection);
    }

    @IsTest
    static void testEvaluate_TH1_ErrorRetry() {
        HoldCaseData data = seedHoldCaseData();
        Case c = insertSubmittedCase(data, 'ERROR', 1);

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subAId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(true, result.showHoldCaseSection);
        System.assertEquals(FEC_HoldCaseStage2DisplayService.MODE_ERROR_RETRY, result.displayMode);
        System.assertEquals(true, result.showManualHoldCaseButton);
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testEvaluate_TH1_MaxRetryReached() {
        HoldCaseData data = seedHoldCaseData();
        Case c = insertSubmittedCase(data, 'ERROR', 3);

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subAId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(FEC_HoldCaseStage2DisplayService.MODE_ERROR_RETRY, result.displayMode);
        System.assertEquals(false, result.showManualHoldCaseButton);
    }

    @IsTest
    static void testEvaluate_TH2_SuccessWithInfoNoAuto() {
        HoldCaseData data = seedHoldCaseData();
        Case c = insertSubmittedCase(data, 'SUCCESS', 0);

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subBId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(true, result.showHoldCaseSection);
        System.assertEquals(
            FEC_HoldCaseStage2DisplayService.MODE_SUCCESS_WITH_INFO_NO_AUTO,
            result.displayMode
        );
        System.assertNotEquals(null, result.infoMessage);
    }

    @IsTest
    static void testEvaluate_TH2_SuccessWithInfoHasAuto() {
        HoldCaseData data = seedHoldCaseData();
        insert new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = data.nocBId,
            Hold_Case_Type__c = 'Auto',
            FEC_Active__c = true
        );
        Case c = insertSubmittedCase(data, 'ALREADY_MARKED', 0);

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subBId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(
            FEC_HoldCaseStage2DisplayService.MODE_SUCCESS_WITH_INFO_HAS_AUTO,
            result.displayMode
        );
        System.assertNotEquals(null, result.infoMessage);
    }

    @IsTest
    static void testEvaluate_TH3_InfoHasAutoButton() {
        HoldCaseData data = seedHoldCaseData();
        insert new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = data.nocBId,
            Hold_Case_Type__c = 'Auto',
            FEC_Case_Stage__c = data.stage2Id,
            FEC_Active__c = true
        );
        Case c = insertSubmittedCase(data, null, 0);

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subBId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(true, result.showHoldCaseSection);
        System.assertEquals(
            FEC_HoldCaseStage2DisplayService.MODE_INFO_HAS_AUTO_BUTTON,
            result.displayMode
        );
        System.assertEquals(true, result.showManualHoldCaseButton);
        System.assertNotEquals(null, result.infoMessage);
    }

    @IsTest
    static void testEvaluate_NotStage2Context() {
        HoldCaseData data = seedHoldCaseData();
        Case c = new Case(
            Subject = 'Stage1 Only',
            Status = 'New',
            FEC_Team__c = FEC_ConstantCommon.TEAM_CS_SUPPORT,
            FEC_Is_Submited__c = false,
            FEC_Product_Type__c = data.ptId,
            FEC_Category__c = data.catId,
            FEC_SubCategory__c = data.subAId,
            FEC_Current_Case_Stage__c = data.stage2Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_HoldCaseStage2DisplayService.HoldCaseStage2Display result =
            FEC_HoldCaseStage2DisplayService.evaluate(
                c.Id, data.ptId, data.catId, data.subBId, null,
                data.ptId, data.catId, data.subAId, null
            );
        Test.stopTest();

        System.assertEquals(FEC_HoldCaseStage2DisplayService.MODE_DEFAULT, result.displayMode);
        System.assertEquals(false, result.showHoldCaseSection);
    }

    @IsTest
    static void testTestVisibleHelpers() {
        HoldCaseData data = seedHoldCaseData();
        FEC_Nature_of_Case__c nocA = [
            SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Sub_Category__c = :data.subAId LIMIT 1
        ];
        FEC_Nature_of_Case__c nocB = [
            SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Sub_Category__c = :data.subBId LIMIT 1
        ];
        insert new FEC_Hold_Case_Config__c(
            FEC_Nature_of_Cases__c = nocB.Id,
            Hold_Case_Type__c = 'Auto',
            FEC_Case_Stage__c = data.stage2Id,
            FEC_Active__c = true
        );
        FEC_Case_Stage__c stage1 = [
            SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Default_Stage__c = TRUE LIMIT 1
        ];
        Case c = insertSubmittedCase(data, null, 0);

        Test.startTest();
        System.assertEquals(
            true,
            FEC_HoldCaseStage2DisplayService.isNatureOfCaseChanged(
                data.ptId, data.catId, data.subBId, null,
                data.ptId, data.catId, data.subAId, null
            )
        );
        System.assertEquals(
            false,
            FEC_HoldCaseStage2DisplayService.isNatureOfCaseChanged(
                data.ptId, data.catId, data.subAId, null,
                data.ptId, data.catId, data.subAId, null
            )
        );
        System.assertEquals(true, FEC_HoldCaseStage2DisplayService.isEligibleHoldCaseTeam(
            FEC_ConstantCommon.TEAM_VALUE_CSSUPPORT + '_Other',
            null
        ));
        System.assertEquals(true, FEC_HoldCaseStage2DisplayService.hasHoldConfig('Auto', nocB.Id));
        System.assertEquals(
            true,
            FEC_HoldCaseStage2DisplayService.hasHoldConfigForStage('Auto', nocB.Id, data.stage2Id)
        );
        System.assertEquals(
            false,
            FEC_HoldCaseStage2DisplayService.hasHoldConfigAtStage1('Auto', nocB.Id, data.stage2Id)
        );
        System.assertEquals(
            nocA.Id,
            FEC_HoldCaseStage2DisplayService.resolveNatureOfCaseId(
                data.ptId, data.catId, data.subAId, null, data.stage2Id
            )
        );
        System.assertEquals(
            stage1.Id,
            FEC_HoldCaseStage2DisplayService.resolveStage1IdForNature(nocA.Id, data.stage2Id)
        );
        Case queried = [
            SELECT
                Id,
                IsClosed,
                Status,
                FEC_Is_Submited__c,
                FEC_Stage_Name__c,
                FEC_Team__c,
                FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
                FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Id = :c.Id
            LIMIT 1
        ];
        System.assertEquals(
            true,
            FEC_HoldCaseStage2DisplayService.isStage2HoldCaseContext(queried)
        );
        Test.stopTest();
    }
}
