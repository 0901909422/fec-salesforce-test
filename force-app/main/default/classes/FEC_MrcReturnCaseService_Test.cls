@IsTest
private class FEC_MrcReturnCaseService_Test {

    @IsTest
    static void testBuildUiContext_TH4() {
        // Setup dữ liệu giả lập cho Case và SubCategory
        Case testCase = new Case(Status = 'New');
        
        // Giả lập subCategoryCode và subCodeCode thuộc RL05.02
        Test.startTest();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            testCase, 'RL05', 'RL05.02', 'Đã nhận MRC', false
        );
        Test.stopTest();

        System.assertEquals(true, ctx.isRl05Branch, 'Phải thuộc nhánh RL05.');
        System.assertEquals('TH4', ctx.rl05Scenario, 'Phải là kịch bản TH4 khi không có Case trùng.');
        System.assertEquals(true, ctx.showDeliveryForm, 'TH4 phải hiện Delivery Form.');
    }

    @IsTest
    static void testResolveProcessingFlow() {
        // Test luồng CP_SUPPORT
        String flow = FEC_MrcReturnCaseService.resolveProcessingFlow('TLCCDTKH', 'ACTIVE');
        System.assertEquals(FEC_MrcReturnCaseService.FLOW_CP_SUPPORT, flow);

        // Test luồng NOT_ELIGIBLE
        String ineligible = FEC_MrcReturnCaseService.resolveProcessingFlow('CN', 'ACTIVE');
        System.assertEquals(FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE, ineligible);
    }

    @IsTest
    static void testIsCustomerReceivedMrcConfirmation() {
        System.assertEquals(true, FEC_MrcReturnCaseService.isCustomerReceivedMrcConfirmation('Customer received MRC'));
        System.assertEquals(true, FEC_MrcReturnCaseService.isCustomerReceivedMrcConfirmation('Đã nhận'));
        System.assertEquals(false, FEC_MrcReturnCaseService.isCustomerReceivedMrcConfirmation('Chưa nhận'));
    }

    @IsTest
    static void testMrcReturnCaseInformationValidate() {
        Case c = new Case(
            FEC_Account_or_Contract__r = new FEC_Customer_History__c(FEC_Product_Code__c = 'VN')
        );

        Test.startTest();
        FEC_CaseBusinessService.Error err =
            FEC_MrcReturnCaseService.mrcReturnCaseInformationValidate(c, 'RL05', 'RL05.02');
        Test.stopTest();

        System.assertNotEquals(null, err);
        System.assert(err.errorlst.size() > 0, 'Phải báo lỗi khi Product Code không phải TW.');
    }

    @IsTest
    static void testBuildUiContext_TH1_TH2_TH3() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Status_ID__c = 'TLCCDTKH',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case baseCase = new Case(FEC_Account_or_Contract__r = ch);

        Test.startTest();
        FEC_MrcReturnCaseService.MrcRl05UiContext th1 =
            FEC_MrcReturnCaseService.buildUiContext(
                baseCase, 'RL05', 'RL05.02', FEC_MrcReturnCaseService.CONF_RECEIVED, true
            );
        FEC_MrcReturnCaseService.MrcRl05UiContext th2 =
            FEC_MrcReturnCaseService.buildUiContext(
                baseCase, 'RL05', 'RL05.02', null, true
            );
        FEC_MrcReturnCaseService.MrcRl05UiContext th3 =
            FEC_MrcReturnCaseService.buildUiContext(
                baseCase, 'RL05', 'RL05.02', FEC_MrcReturnCaseService.CONF_NOT_RECEIVED, false
            );
        Test.stopTest();

        System.assertEquals('TH1', th1.rl05Scenario);
        System.assertEquals('TH2', th2.rl05Scenario);
        System.assertEquals('TH3', th3.rl05Scenario);
        System.assertEquals(true, th3.showHandlingRadioOnNotReceived);
    }

    @IsTest
    static void testBuildUiContext_PhotoSubCode() {
        Case c = new Case();
        Test.startTest();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx =
            FEC_MrcReturnCaseService.buildUiContext(c, 'RL05', 'RL05.01', null, false);
        Test.stopTest();

        System.assertEquals(true, ctx.isPhotoSubCode);
        System.assertEquals(true, ctx.showDeliveryForm);
        System.assertEquals(false, ctx.showCustomerConfirmation);
    }

    @IsTest
    static void testBuildUiContext_NotEligibleFlow() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Status_ID__c = 'CN',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);

        Test.startTest();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx =
            FEC_MrcReturnCaseService.buildUiContext(c, 'RL05', 'RL05.02', null, false);
        Test.stopTest();

        System.assertEquals(FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE, ctx.processingFlow);
        System.assertEquals(true, ctx.autoRouteReject);
    }

    @IsTest
    static void testHelperMethods() {
        Test.startTest();
        System.assertEquals(true, FEC_MrcReturnCaseService.isRl05Branch('RL05', 'RL05.02'));
        System.assertEquals(true, FEC_MrcReturnCaseService.meetsCondition2('TLDN'));
        System.assertEquals('RL05.02', FEC_MrcReturnCaseService.inferSubCodeFromStageName('Stage RL05.02 Open'));
        System.assertEquals(false, FEC_MrcReturnCaseService.needsDeliveryLwc(null));
        Test.stopTest();
    }

    @IsTest
    static void testShouldSkipStage1Field() {
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx =
            FEC_MrcReturnCaseService.buildUiContext(
                new Case(), 'RL05', 'RL05.02', FEC_MrcReturnCaseService.CONF_RECEIVED, false
            );
        Case submittedCase = new Case(FEC_Is_Submited__c = true);

        Test.startTest();
        Boolean skipAssessment = FEC_MrcReturnCaseService.shouldSkipStage1Field(
            FEC_MrcReturnCaseService.MRC_RETURN,
            'RL05',
            'RL05.02',
            FEC_ConstantCommon.STAGE_ONE + ' Open',
            'FEC_Contract_Processing_MRC_Assessment__c',
            ctx,
            new Case()
        );
        Boolean skipConfirmation = FEC_MrcReturnCaseService.shouldSkipStage1Field(
            FEC_MrcReturnCaseService.MRC_RETURN,
            'RL05',
            'RL05.02',
            FEC_ConstantCommon.STAGE_ONE + ' Open',
            'FEC_Customer_Confirmation__c',
            ctx,
            submittedCase
        );
        Boolean skipHandling = FEC_MrcReturnCaseService.shouldSkipStage1Field(
            FEC_MrcReturnCaseService.MRC_RETURN,
            'RL05',
            'RL05.02',
            FEC_ConstantCommon.STAGE_TWO,
            'FEC_MRC_Request_Handling_Option__c',
            ctx,
            null
        );
        Test.stopTest();

        System.assertEquals(true, skipAssessment);
        System.assertEquals(false, skipConfirmation);
        System.assertEquals(true, skipHandling);
    }

    @IsTest
    static void testShouldSkipMasterDataRow() {
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx =
            FEC_MrcReturnCaseService.buildUiContext(
                new Case(), 'RL05', 'RL05.01', null, false
            );
        ctx.hideMrcInfoLwc = true;

        Test.startTest();
        Boolean skipMrc = FEC_MrcReturnCaseService.shouldSkipMasterDataRow(
            'Case Information', 'MRC', 'fec_MRC', null, ctx
        );
        Boolean skipDelivery = FEC_MrcReturnCaseService.shouldSkipMasterDataRow(
            'Case Information', 'Delivery', 'fec_MrcDeliveryForm', null, ctx, new Case()
        );
        Boolean skipClosure = FEC_MrcReturnCaseService.shouldSkipMasterDataRow(
            'Case Information', 'Closure', 'fec_ContractClosureForm', null, ctx
        );
        Test.stopTest();

        System.assertEquals(true, skipMrc);
        System.assertEquals(true, skipDelivery);
        System.assertEquals(true, skipClosure);
    }

    @IsTest
    static void testApplyRl05CodeFallbacksAndResolveCodes() {
        FEC_CaseBusinessService.Business biz = new FEC_CaseBusinessService.Business();
        Case c = new Case(
            FEC_SubCategory__r = new FEC_Sub_Category__c(FEC_Code__c = 'RL05'),
            FEC_SubCode__r = new FEC_Sub_Code__c(FEC_Code__c = 'RL05.02')
        );

        Test.startTest();
        FEC_MrcReturnCaseService.applyRl05CodeFallbacks(biz, c, 'Stage RL05.02');
        String subCode = FEC_MrcReturnCaseService.resolveSubCodeCode(null, c, 'Stage RL05.02');
        String subCat = FEC_MrcReturnCaseService.resolveSubCategoryCode(null, c, null);
        String inferred = FEC_MrcReturnCaseService.inferSubCategoryFromStageName('Stage RL05.02');
        Test.stopTest();

        System.assertEquals('RL05.02', biz.subCodeCode);
        System.assertEquals('RL05', subCat);
        System.assertNotEquals(null, subCode);
        System.assertEquals('RL05', inferred);
    }

    @IsTest
    static void testSelectStageChangeForRoute() {
        FEC_Stage_Change__c sc1 = new FEC_Stage_Change__c(
            FEC_Team_User_Group__c = 'SP',
            FEC_Next_Queue__c = 'CS_Frontline_Queue'
        );
        FEC_Stage_Change__c sc2 = new FEC_Stage_Change__c(
            FEC_Team_User_Group__c = 'CC',
            FEC_Next_Queue__c = 'Handling'
        );

        Test.startTest();
        FEC_Stage_Change__c picked =
            FEC_MrcReturnCaseService.selectStageChangeForRoute(
                new List<FEC_Stage_Change__c>{ sc1, sc2 },
                'SP',
                null
            );
        FEC_Stage_Change__c single =
            FEC_MrcReturnCaseService.selectStageChangeForRoute(
                new List<FEC_Stage_Change__c>{ sc1 },
                null,
                null
            );
        Test.stopTest();

        System.assertEquals('SP', picked.FEC_Team_User_Group__c);
        System.assertEquals(sc1, single);
    }

    @IsTest
    static void testIsRl0503DpdOnlyValidation() {
        FEC_CaseBusinessService.Error err = new FEC_CaseBusinessService.Error();
        err.errorlst = new List<String>{
            System.Label.FEC_MRC_Return_Msg_DPD_RL0503
        };

        Test.startTest();
        Boolean onlyDpd = FEC_MrcReturnCaseService.isRl0503DpdOnlyValidation(err, 'RL05.03');
        Boolean notDpd = FEC_MrcReturnCaseService.isRl0503DpdOnlyValidation(err, 'RL05.02');
        Test.stopTest();

        System.assertEquals(true, onlyDpd);
        System.assertEquals(false, notDpd);
    }

    @IsTest
    static void testResolveProcessingFlowVariants() {
        Test.startTest();
        String payment = FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'ACTIVE');
        String cpClosed = FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'CLOSED');
        String notEligible = FEC_MrcReturnCaseService.resolveProcessingFlow('CN', 'ACTIVE');
        Test.stopTest();

        System.assertEquals(FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT, payment);
        System.assertEquals(FEC_MrcReturnCaseService.FLOW_CP_SUPPORT, cpClosed);
        System.assertEquals(FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE, notEligible);
    }

    @IsTest
    static void testShouldHideMrcDeliveryLwc() {
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx =
            FEC_MrcReturnCaseService.buildUiContext(
                new Case(), 'RL05', 'RL05.02', FEC_MrcReturnCaseService.CONF_RECEIVED, false
            );
        Case withDelivery = new Case(
            FEC_Customer_Confirmation__c = FEC_MrcReturnCaseService.CONF_RECEIVED,
            FEC_Delivery_Option_2__c = 'Email'
        );

        Test.startTest();
        Boolean hideNoDelivery = FEC_MrcReturnCaseService.shouldHideMrcDeliveryLwc(ctx, new Case());
        Boolean hideWithDelivery = FEC_MrcReturnCaseService.shouldHideMrcDeliveryLwc(ctx, withDelivery);
        Test.stopTest();

        System.assertEquals(true, hideNoDelivery);
        System.assertEquals(false, hideWithDelivery);
    }
}