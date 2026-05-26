@IsTest
private class FEC_MrcReturnCaseServiceTest {
    @IsTest
    static void resolveProcessingFlow_mapsStatuses() {
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE,
            FEC_MrcReturnCaseService.resolveProcessingFlow('CN', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE,
            FEC_MrcReturnCaseService.resolveProcessingFlow('TLCN', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('TLDN', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('TLDN', 'CHARGE-OFF')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('TLDN', 'N/A')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'CLOSED')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('HT', 'N/A')
        );
    }

    @IsTest
    static void buildUiContext_returnSubCode_notEligible_autoReject() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_MRC_Status__c = 'CN',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE,
            ctx.processingFlow
        );
        System.assertEquals(true, ctx.autoRouteReject);
        System.assertEquals(false, ctx.showCustomerConfirmation);
    }

    @IsTest
    static void buildUiContext_returnSubCode_paymentFlow_autoRoutePayment() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_MRC_Status__c = 'LK',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT,
            ctx.processingFlow
        );
        System.assertEquals(true, ctx.autoRoutePayment);
        System.assertEquals('TH4', ctx.rl05Scenario);
    }

    @IsTest
    static void buildUiContext_returnSubCode_cpFlow_autoRouteCp() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_MRC_Status__c = 'TLDN',
            FEC_Contract_Status__c = 'CLOSED'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            ctx.processingFlow
        );
        System.assertEquals(true, ctx.autoRouteCp);
    }

    @IsTest
    static void isRl05Branch_fromSubCodeOnly() {
        System.assertEquals(
            true,
            FEC_MrcReturnCaseService.isRl05Branch(null, 'RL05.01')
        );
    }

    @IsTest
    static void buildUiContext_rl0503_showsDeliveryWithEmail() {
        Case c = new Case();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.03',
            null,
            false
        );
        System.assertEquals(true, ctx.isPhotoSubCode);
        System.assertEquals(true, ctx.showDeliveryForm);
        System.assertEquals(true, ctx.hideMrcInfoLwc);
    }

    @IsTest
    static void buildUiContext_photoSubCode_showsDelivery() {
        Case c = new Case();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.01',
            null,
            false
        );
        System.assertEquals(true, ctx.isPhotoSubCode);
        System.assertEquals(true, ctx.showDeliveryForm);
        System.assertEquals(true, ctx.hideMrcInfoLwc);
        System.assertNotEquals(true, ctx.hidePropertyInfo);
    }

    @IsTest
    static void finalizeCaseInformationForRl0502_injectsPropertyInfoFields() {
        FEC_CaseBusinessService.Business biz = new FEC_CaseBusinessService.Business();
        biz.sectionlst = new List<FEC_CaseBusinessService.Section>();
        FEC_CaseBusinessService.Section caseInfo = new FEC_CaseBusinessService.Section(
            'Case Information'
        );
        biz.sectionlst.add(caseInfo);

        Case c = new Case();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );

        FEC_MrcReturnCaseService.finalizeCaseInformationForRl05(biz, ctx, c);

        FEC_CaseBusinessService.Section prop = caseInfo.findSubSection('Property Info');
        System.assertNotEquals(null, prop, 'Property Info subsection');
        System.assertNotEquals(true, prop.hideForMrcRl05);
        FEC_CaseBusinessService.CObject ai = prop.findObj('FEC_Additional_Info__c');
        System.assertNotEquals(null, ai);
        System.assertNotEquals(
            null,
            ai.findField('FEC_Verify_Information__c')
        );
        System.assertNotEquals(null, ai.findField('FEC_Callback__c'));
        System.assert(
            biz.picklistOptionsMap.containsKey('FEC_Additional_Info__c')
        );
    }

    @IsTest
    static void buildUiContext_returnSubCode_hidesMrcLwc_showsProperty_dupCaseOnlyIsTh2() {
        Case c = new Case();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            true
        );
        System.assertEquals(true, ctx.isReturnSubCode);
        System.assertEquals(true, ctx.hideMrcInfoLwc);
        System.assertEquals(false, ctx.hidePropertyInfo);
        System.assertEquals(true, ctx.showCustomerConfirmation);
        System.assertEquals(true, ctx.showMrcDupBanner);
        System.assertEquals(true, ctx.dupCaseOnly);
        System.assertEquals(false, ctx.meetsCondition2);
        System.assertEquals(false, ctx.showDeliveryForm);
    }

    @IsTest
    static void buildUiContext_returnSubCode_th1_cond1AndCond2() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_MRC_Status__c = 'TLDN',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            true
        );
        System.assertEquals(true, ctx.showCustomerConfirmation);
        System.assertEquals(true, ctx.showMrcDupBanner);
        System.assertEquals(true, ctx.meetsCondition2);
        System.assertEquals(false, ctx.dupCaseOnly);
        System.assertEquals('TH1', ctx.rl05Scenario);
        System.assertEquals(false, ctx.showDeliveryForm);
        System.assertEquals(false, ctx.showHandlingRadioOnNotReceived);
    }

    @IsTest
    static void buildUiContext_returnSubCode_th3_cond2Only() {
        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_MRC_Status__c = 'TLDN',
            FEC_Contract_Status__c = 'ACTIVE'
        );
        Case c = new Case(FEC_Account_or_Contract__r = ch);
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );
        System.assertEquals(true, ctx.showCustomerConfirmation);
        System.assertEquals(false, ctx.showMrcDupBanner);
        System.assertEquals('TH3', ctx.rl05Scenario);
        System.assertEquals(true, ctx.showHandlingRadioOnNotReceived);
        System.assertEquals(false, ctx.showDeliveryForm);
    }

    @IsTest
    static void buildUiContext_returnSubCode_th4_noConditions() {
        Case c = new Case();
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            'RL05',
            'RL05.02',
            null,
            false
        );
        System.assertEquals(true, ctx.showCustomerConfirmation);
        System.assertEquals(false, ctx.showMrcDupBanner);
        System.assertEquals(false, ctx.meetsCondition2);
        System.assertEquals(false, ctx.dupCaseOnly);
        System.assertEquals(true, ctx.showDeliveryForm);
    }

    @IsTest
    static void inferSubCodeFromStageName_rl0502() {
        System.assertEquals(
            'RL05.02',
            FEC_MrcReturnCaseService.inferSubCodeFromStageName(
                'RL05.02 - MRC Return Stage 1'
            )
        );
    }

    @IsTest
    static void buildUiContext_infersRl0502FromCaseStage() {
        Case c = new Case(
            FEC_Current_Case_Stage__r = new FEC_Case_Stage__c(
                Name = 'RL05.02 - MRC Return Stage 1'
            )
        );
        FEC_MrcReturnCaseService.MrcRl05UiContext ctx = FEC_MrcReturnCaseService.buildUiContext(
            c,
            null,
            null,
            null,
            false
        );
        System.assertEquals(true, ctx.isRl05Branch);
        System.assertEquals(true, ctx.isReturnSubCode);
        System.assertEquals(true, ctx.showCustomerConfirmation);
    }
}