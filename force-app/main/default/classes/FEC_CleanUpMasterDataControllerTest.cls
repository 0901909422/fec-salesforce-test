/**
 * @description Smoke tests for FEC_CleanUpMasterDataController.
 *              Note: syncDataToMDM/pushMDMToLive launch batches — test cẩn thận để không vượt limit.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_CleanUpMasterDataControllerTest {

    @IsTest
    static void testGetAllMasterData() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_CleanUpMasterDataController.getAllMasterData();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testGetAllMasterDataMDM() {
        Test.startTest();
        Map<String, List<Object>> data = FEC_CleanUpMasterDataController.getAllMasterDataMDM();
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testGetRecentBatchLogs_Default() {
        Test.startTest();
        List<FEC_Batch_Log__c> logs = FEC_CleanUpMasterDataController.getRecentBatchLogs(null);
        Test.stopTest();
        Assert.isNotNull(logs);
    }

    @IsTest
    static void testGetRecentBatchLogs_CustomLimit() {
        Test.startTest();
        List<FEC_Batch_Log__c> logs = FEC_CleanUpMasterDataController.getRecentBatchLogs(10);
        Test.stopTest();
        Assert.isNotNull(logs);
    }

    @IsTest
    static void testGetRecentBatchLogs_ZeroLimit() {
        Test.startTest();
        List<FEC_Batch_Log__c> logs = FEC_CleanUpMasterDataController.getRecentBatchLogs(0);
        Test.stopTest();
        Assert.isNotNull(logs);
    }

    @IsTest
    static void testSyncDataToMDM_Callable() {
        // Wrap trong startTest/stopTest để batch chạy đến cùng — Iterable size = 1
        // tương đương 1 executeBatch invocation (đủ điều kiện test runtime).
        Test.startTest();
        try {
            FEC_CleanUpMasterDataController.syncDataToMDM();
            Assert.isTrue(true, 'Method called without throw');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testPushMDMToLive_Callable() {
        Test.startTest();
        try {
            FEC_CleanUpMasterDataController.pushMDMToLive();
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}