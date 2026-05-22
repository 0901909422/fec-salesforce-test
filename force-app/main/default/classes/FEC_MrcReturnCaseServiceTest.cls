@IsTest
private class FEC_MrcReturnCaseServiceTest {
    @IsTest
    static void resolveProcessingFlow_mapsStatuses() {
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_NOT_ELIGIBLE,
            FEC_MrcReturnCaseService.resolveProcessingFlow('CN', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('TLDN', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_PAYMENT_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'ACTIVE')
        );
        System.assertEquals(
            FEC_MrcReturnCaseService.FLOW_CP_SUPPORT,
            FEC_MrcReturnCaseService.resolveProcessingFlow('LK', 'CLOSED')
        );
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
        System.assertEquals(true, ctx.hidePropertyInfo);
    }

    @IsTest
    static void buildUiContext_returnSubCode_hidesMrcLwc_dupCaseOnlyIsTh2() {
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
        System.assertEquals(false, ctx.showCustomerConfirmation);
        System.assertEquals(true, ctx.showMrcDupBanner);
        System.assertEquals(true, ctx.dupCaseOnly);
        System.assertEquals('TH2', ctx.rl05Scenario);
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
        System.assertEquals(false, ctx.showCustomerConfirmation);
        System.assertEquals(false, ctx.showMrcDupBanner);
        System.assertEquals('TH4', ctx.rl05Scenario);
        System.assertEquals(true, ctx.showDeliveryForm);
    }
}