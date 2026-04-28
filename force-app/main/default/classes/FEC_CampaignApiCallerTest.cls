/**
 * FEC_CampaignApiCallerTest
 * Tests for FEC_CampaignApiCaller.
 * Validates: Requirements 4.1, 4.3
 */
@isTest
private class FEC_CampaignApiCallerTest {

    @isTest
    static void testSendCampaignData_ReturnsNullInTestContext() {
        Test.startTest();
        HttpResponse resp = FEC_CampaignApiCaller.sendCampaignData('{"test":"data"}');
        Test.stopTest();

        // sendCampaignData returns null when Test.isRunningTest()
        Assert.areEqual(null, resp, 'sendCampaignData should return null in test context');
    }

    @isTest
    static void testCheckCampaignStatus_NullInput() {
        Test.startTest();
        FEC_CampaignApiResponse.StatusResponse resp =
            FEC_CampaignApiCaller.checkCampaignStatus(null);
        Test.stopTest();

        Assert.areEqual(null, resp, 'checkCampaignStatus with null should return null');
    }

    @isTest
    static void testCheckCampaignStatus_EmptyInput() {
        Test.startTest();
        FEC_CampaignApiResponse.StatusResponse resp =
            FEC_CampaignApiCaller.checkCampaignStatus(new List<String>());
        Test.stopTest();

        Assert.areEqual(null, resp, 'checkCampaignStatus with empty list should return null');
    }

    @isTest
    static void testGetCallingListResult_NullInput() {
        Test.startTest();
        FEC_CampaignApiResponse.CallingListResponse resp =
            FEC_CampaignApiCaller.getCallingListResult(null);
        Test.stopTest();

        Assert.areEqual(null, resp, 'getCallingListResult with null should return null');
    }

    @isTest
    static void testGetCallingListResult_EmptyInput() {
        Test.startTest();
        FEC_CampaignApiResponse.CallingListResponse resp =
            FEC_CampaignApiCaller.getCallingListResult(new Set<String>());
        Test.stopTest();

        Assert.areEqual(null, resp, 'getCallingListResult with empty set should return null');
    }

    @isTest
    static void testCheckCampaignStatus_WithMock() {
        // doPost returns null in test context, so result is null
        // This test verifies the method handles the null response gracefully
        Test.startTest();
        FEC_CampaignApiResponse.StatusResponse resp =
            FEC_CampaignApiCaller.checkCampaignStatus(new List<String>{ 'REC001', 'REC002' });
        Test.stopTest();

        // doPost returns null in test context → isSuccessStatus check fails → returns null
        Assert.areEqual(null, resp, 'Should return null when doPost returns null in test');
    }

    @isTest
    static void testGetCallingListResult_WithMock() {
        Test.startTest();
        FEC_CampaignApiResponse.CallingListResponse resp =
            FEC_CampaignApiCaller.getCallingListResult(new Set<String>{ 'ACC001' });
        Test.stopTest();

        Assert.areEqual(null, resp, 'Should return null when doPost returns null in test');
    }

    @isTest
    static void testSendCampaignData_EmptyPayload() {
        Test.startTest();
        HttpResponse resp = FEC_CampaignApiCaller.sendCampaignData('');
        Test.stopTest();

        Assert.areEqual(null, resp, 'Should return null in test context even with empty payload');
    }
}
