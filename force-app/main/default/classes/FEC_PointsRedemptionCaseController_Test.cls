@IsTest
private class FEC_PointsRedemptionCaseController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Cashback',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Sub_Code__c sc = new FEC_Sub_Code__c(
            Name = 'SC RC33',
            FEC_Code__c = 'RC33.01',
            FEC_Active__c = true
        );
        insert sc;

        if (Schema.getGlobalDescribe().containsKey('FEC_Nature_of_Case__c')) {
            insert new FEC_Nature_of_Case__c(
                FEC_Product_Type__c = pt.Id,
                FEC_Sub_Code__c = sc.Id
            );
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                FEC_Product_Type__c = pt.Id,
                FEC_SubCode__c = sc.Id,
                Status = 'New'
            );
            insert c;

            FEC_Customer_History__c ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CUST-' + suffix,
                FEC_Available_Points__c = 200000,
                FEC_Account_Number__c = 'ACC123'
            );
            insert ch;

            c.FEC_Account_or_Contract__c = ch.Id;
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static String buildEligibilitySoap(String availablePoints) {
        return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>' +
            '<GetRewardEligibilityResponse xmlns="http://esbservice.fecredit.org/CMS_RewardWS/">' +
            '<SysResponse><Status>0</Status></SysResponse>' +
            '<AvailablePoints>' + availablePoints + '</AvailablePoints>' +
            '<RedemptionOptions><CashbackEligible>true</CashbackEligible></RedemptionOptions>' +
            '<Products>' +
            '<Product><ID>P1</ID><Name>Tier 1</Name><Type>Cashback</Type><Price>100000</Price><RedeemTypeID>1</RedeemTypeID></Product>' +
            '</Products>' +
            '</GetRewardEligibilityResponse>' +
            '</soap:Body></soap:Envelope>';
    }

    private class RewardEligibilityMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(buildEligibilitySoap('200000'));
            return res;
        }
    }

    private class RewardEligibilityLowPointsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(buildEligibilitySoap('50000'));
            return res;
        }
    }

    @IsTest
    static void testInitData_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityMock());

        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(true, res.showRedemptionUi);
        System.assertNotEquals(0, res.tierOptions.size());
    }

    @IsTest
    static void testInitData_BelowMinPoints() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityLowPointsMock());

        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
    }

    @IsTest
    static void testInitData_NullCaseId() {
        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(null, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
        System.assertNotEquals(null, res.notEligibleMessage);
    }

    @IsTest
    static void testInitData_WrongSubCodeBranch() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityMock());

        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC99.99', 'RC99');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
    }

    @IsTest
    static void testSaveDraftSelection() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        String tierJson = '{"productId":"P1","productName":"Tier 1","productType":"Cashback","priceId":"1","price":100000,"cashback":0,"redeemTypeId":1}';

        Test.startTest();
        FEC_PointsRedemptionCaseController.saveDraftSelection(c.Id, tierJson, 'RC33.01');
        Test.stopTest();

        System.assertEquals(
            '100000',
            [SELECT FEC_Redeemed_Points__c FROM Case WHERE Id = :c.Id].FEC_Redeemed_Points__c
        );
    }

    @IsTest
    static void testSaveDraftSelection_BlankParamsNoOp() {
        Test.startTest();
        FEC_PointsRedemptionCaseController.saveDraftSelection(null, null, null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testInitData_ApiFailure() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new RewardEligibilityErrorMock());

        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
        System.assertNotEquals(null, res.notEligibleMessage);
    }

    @IsTest
    static void testInitData_NoAccountNumber() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [
            SELECT Id FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        ch.FEC_Account_Number__c = null;
        update ch;

        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
    }

    @IsTest
    static void testInitData_SavedRedeemedPointsOnCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_Redeemed_Points__c = '150000';
        update c;

        Test.setMock(HttpCalloutMock.class, new RewardEligibilityErrorMock());
        Test.startTest();
        FEC_PointsRedemptionCaseController.InitResult res =
            FEC_PointsRedemptionCaseController.initData(c.Id, 'RC33.01', 'RC33');
        Test.stopTest();

        System.assertEquals(false, res.showRedemptionUi);
    }

    private class RewardEligibilityErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>' +
                '<GetRewardEligibilityResponse><SysResponse><Status>1</Status></SysResponse>' +
                '</GetRewardEligibilityResponse></soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

}