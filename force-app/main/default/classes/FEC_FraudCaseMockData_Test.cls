@IsTest
private class FEC_FraudCaseMockData_Test {

    @IsTest
    static void test_getLocationData() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.getLocationData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('location'), 'Should contain location key');
        System.assert(result.contains('Vietnam'), 'Should contain country data');
    }

    @IsTest
    static void test_getServiceCasesInfoMockData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceCasesInfo result =
            FEC_FraudCaseMockData.getServiceCasesInfoMockData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('5008X00000123AB', result.caseId);
        System.assertEquals('Fraud Review', result.caseType);
        System.assertEquals('Resolved', result.caseStatus);
    }

    @IsTest
    static void test_getCaseInfoMockData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CaseInfo result =
            FEC_FraudCaseMockData.getCaseInfoMockData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Pending-FraudTask', result.caseStatus);
        System.assertEquals(FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE, result.caseChannel);
    }

    @IsTest
    static void test_getNotificationMockData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.NotificationInfo result =
            FEC_FraudCaseMockData.getNotificationMockData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Email', result.notificationType);
        System.assertEquals('Delivered', result.status);
    }

    @IsTest
    static void test_getRemarksMockData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.RemarksInfo result =
            FEC_FraudCaseMockData.getRemarksMockData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('R01', result.id);
        System.assertEquals('Cancel', result.decision);
    }

    @IsTest
    static void test_getCustomerMockData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo result =
            FEC_FraudCaseMockData.getCustomerMockData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.customerName);
        System.assertNotEquals(null, result.nationalId);
        System.assertEquals('Card', result.productType);
    }

    @IsTest
    static void test_responseCreateFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseCreateFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CreateFraudCaseResponse'));
        System.assert(result.contains('Code>1</'));
    }

    @IsTest
    static void test_responseCreateFailedFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseCreateFailedFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('Code>0</'));
    }

    @IsTest
    static void test_responseSuccessCancelFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseSuccessCancelFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CancelFraudCaseResponse'));
        System.assert(result.contains('Code>1</'));
    }

    @IsTest
    static void test_responseFailedCancelFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseFailedCancelFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CancelFraudCaseResponse'));
    }

    @IsTest
    static void test_responseFailedCancelConnectFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseFailedCancelConnectFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('Code>0</'));
    }

    @IsTest
    static void test_responseFailedCreateConnectFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.responseFailedCreateConnectFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CreateFraudCaseResponse'));
        System.assert(result.contains('Code>0</'));
    }

    @IsTest
    static void test_getCategoryMockupData() {
        Test.startTest();
        List<Map<String, Object>> result = FEC_FraudCaseMockData.getCategoryMockupData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return categories');
    }

    @IsTest
    static void test_getSubCategoryMockupData() {
        Test.startTest();
        List<Map<String, Object>> result = FEC_FraudCaseMockData.getSubCategoryMockupData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return sub-categories');
    }

    @IsTest
    static void test_getCategorySubCodeMockupData() {
        Test.startTest();
        List<Map<String, Object>> result = FEC_FraudCaseMockData.getCategorySubCodeMockupData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Should return sub-codes');
    }

    @IsTest
    static void test_getFraudMasterData() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.getFraudMasterData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('GetFraudMasterDataResponse'));
    }

    @IsTest
    static void test_getCreateFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.getCreateFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CreateFraudCaseResponse'));
        System.assert(result.contains('FRAUD-000001'));
    }

    @IsTest
    static void test_getCancelFraudCase() {
        Test.startTest();
        String result = FEC_FraudCaseMockData.getCancelFraudCase();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CancelFraudCaseResponse'));
        System.assert(result.contains('Success'));
    }
}
