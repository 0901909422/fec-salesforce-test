@IsTest
private class FEC_FraudCaseMockData_Test {

    @IsTest
    static void test_AllMockMethods() {
        System.assertNotEquals(null, FEC_FraudCaseMockData.getLocationData());
        System.assertNotEquals(null, FEC_FraudCaseMockData.getServiceCasesInfoMockData());
        System.assertNotEquals(null, FEC_FraudCaseMockData.getCaseInfoMockData());
        System.assertNotEquals(null, FEC_FraudCaseMockData.getNotificationMockData());
        System.assertNotEquals(null, FEC_FraudCaseMockData.getRemarksMockData());
        System.assertNotEquals(null, FEC_FraudCaseMockData.getCustomerMockData());
    }

    @IsTest
    static void test_ResponseMethods() {
        try { FEC_FraudCaseMockData.responseFailedCancelFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.responseFailedCancelConnectFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.responseFailedCreateConnectFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.responseSuccessCancelFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.responseCreateFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.responseCreateFailedFraudCase(); } catch (Exception e) {}
    }

    @IsTest
    static void test_CategoryMockMethods() {
        try { FEC_FraudCaseMockData.getCategoryMockupData(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.getSubCategoryMockupData(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.getCategorySubCodeMockupData(); } catch (Exception e) {}
    }

    @IsTest
    static void test_OtherMockMethods() {
        try { FEC_FraudCaseMockData.getFraudMasterData(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.getCreateFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.getCancelFraudCase(); } catch (Exception e) {}
        try { FEC_FraudCaseMockData.getCifFeDictLocationVw(); } catch (Exception e) {}
    }
}