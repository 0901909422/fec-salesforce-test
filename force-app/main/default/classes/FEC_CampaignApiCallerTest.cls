/**
 * FEC_CampaignApiCallerTest
 * Tests for FEC_CampaignApiCaller.
 */
@isTest
private class FEC_CampaignApiCallerTest {

    @isTest
    static void testSendCampaignData_ReturnsNullInTestContext() {
        Test.startTest();
        HttpResponse resp = FEC_CampaignApiCaller.sendCampaignData('{"test":"data"}');
        Test.stopTest();

        Assert.areEqual(null, resp, 'sendCampaignData should return null in test context');
    }

    @isTest
    static void testSendCampaignData_EmptyPayload() {
        Test.startTest();
        HttpResponse resp = FEC_CampaignApiCaller.sendCampaignData('');
        Test.stopTest();

        Assert.areEqual(null, resp, 'Should return null in test context even with empty payload');
    }
}
