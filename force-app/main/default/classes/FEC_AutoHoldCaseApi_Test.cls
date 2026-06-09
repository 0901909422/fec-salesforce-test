@IsTest
private class FEC_AutoHoldCaseApi_Test {

    @IsTest
    static void testMarkNFU_delegatesToService() {
        FEC_MarkNFU.MarkNFURequest req = new FEC_MarkNFU.MarkNFURequest();
        Test.startTest();
        FEC_MarkNFU.MarkNFUResult result = FEC_AutoHoldCaseApi.markNFU(req);
        Test.stopTest();
        System.assertNotEquals(null, result, 'markNFU should return a result object.');
    }

    @IsTest
    static void testIsIntegrationEnabled_andConfigName() {
        System.assertEquals(
            FEC_MarkNFU.API_CONFIG_NAME,
            FEC_AutoHoldCaseApi.MARK_NFU_API_CONFIG_NAME
        );
        System.assertEquals(
            FEC_API_Config__mdt.getInstance(FEC_AutoHoldCaseApi.MARK_NFU_API_CONFIG_NAME) != null,
            FEC_AutoHoldCaseApi.isIntegrationEnabled()
        );
    }
}
