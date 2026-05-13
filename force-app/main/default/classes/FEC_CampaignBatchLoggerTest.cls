/**
 * FEC_CampaignBatchLoggerTest
 * Tests for FEC_CampaignBatchLogger.
 * Validates: Requirements 5.1, 5.2, 5.3
 */
@isTest
private class FEC_CampaignBatchLoggerTest {

    @isTest
    static void testLogStart_CreatesRecord() {
        Test.startTest();
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 100);
        Test.stopTest();

        Assert.isTrue(logId != null, 'logStart should return a non-null Id');
        FEC_Batch_Log__c log = [
            SELECT FEC_Batch_Name__c, FEC_Status__c, FEC_Total_Job_Items__c,
                   FEC_Processed_Items__c, FEC_Error_Count__c
            FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.areEqual('TestBatch', log.FEC_Batch_Name__c);
        Assert.areEqual(FEC_Constants.BATCH_LOG_IN_PROGRESS, log.FEC_Status__c);
        Assert.areEqual(100, log.FEC_Total_Job_Items__c);
        Assert.areEqual(0, log.FEC_Processed_Items__c);
        Assert.areEqual(0, log.FEC_Error_Count__c);
    }

    @isTest
    static void testLogFinish_Completed() {
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 50);

        Test.startTest();
        FEC_CampaignBatchLogger.logFinish(logId, 'JOB123', 50, 0, null);
        Test.stopTest();

        FEC_Batch_Log__c log = [
            SELECT FEC_Status__c, FEC_Job_ID__c, FEC_Processed_Items__c,
                   FEC_Error_Count__c, FEC_Error_Details__c
            FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.areEqual(FEC_Constants.BATCH_LOG_COMPLETED, log.FEC_Status__c);
        Assert.areEqual('JOB123', log.FEC_Job_ID__c);
        Assert.areEqual(50, log.FEC_Processed_Items__c);
        Assert.areEqual(0, log.FEC_Error_Count__c);
    }

    @isTest
    static void testLogFinish_Failed() {
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 50);

        Test.startTest();
        FEC_CampaignBatchLogger.logFinish(logId, 'JOB456', 40, 10, 'Some errors');
        Test.stopTest();

        FEC_Batch_Log__c log = [
            SELECT FEC_Status__c, FEC_Error_Count__c, FEC_Error_Details__c
            FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.areEqual(FEC_Constants.BATCH_LOG_FAILED, log.FEC_Status__c);
        Assert.areEqual(10, log.FEC_Error_Count__c);
        Assert.areEqual('Some errors', log.FEC_Error_Details__c);
    }

    @isTest
    static void testLogCalloutError_AppendsDetails() {
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 10);

        Test.startTest();
        FEC_CampaignBatchLogger.logCalloutError(logId, 'TestBatch', 500, 'Server Error', 5);
        Test.stopTest();

        FEC_Batch_Log__c log = [
            SELECT FEC_Error_Details__c FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.isTrue(log.FEC_Error_Details__c.contains('HTTP 500'),
            'Error details should contain HTTP status code');
        Assert.isTrue(log.FEC_Error_Details__c.contains('Server Error'),
            'Error details should contain response body');
        Assert.isTrue(log.FEC_Error_Details__c.contains('Records: 5'),
            'Error details should contain affected record count');
    }

    @isTest
    static void testLogException_AppendsInfo() {
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 10);

        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception ex) {
            FEC_CampaignBatchLogger.logException(logId, 'TestBatch', ex, 3);
        }
        Test.stopTest();

        FEC_Batch_Log__c log = [
            SELECT FEC_Error_Details__c FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.isTrue(log.FEC_Error_Details__c.contains('Exception:'),
            'Error details should contain exception info');
        Assert.isTrue(log.FEC_Error_Details__c.contains('Records: 3'),
            'Error details should contain affected record count');
    }

    @isTest
    static void testLogFinish_NullLogId_NoException() {
        // Should not throw when given null logId
        Test.startTest();
        FEC_CampaignBatchLogger.logFinish(null, 'JOB', 0, 0, null);
        Test.stopTest();
        // If we reach here, no exception was thrown — pass
        Assert.isTrue(true, 'logFinish with null logId should not throw');
    }

    @isTest
    static void testLogCalloutError_NullLogId_NoException() {
        Test.startTest();
        FEC_CampaignBatchLogger.logCalloutError(null, 'Batch', 500, 'err', 1);
        Test.stopTest();
        Assert.isTrue(true, 'logCalloutError with null logId should not throw');
    }

    @isTest
    static void testLogException_NullLogId_NoException() {
        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception ex) {
            FEC_CampaignBatchLogger.logException(null, 'Batch', ex, 1);
        }
        Test.stopTest();
        Assert.isTrue(true, 'logException with null logId should not throw');
    }

    @isTest
    static void testLogCalloutError_MultipleAppends() {
        Id logId = FEC_CampaignBatchLogger.logStart('TestBatch', 20);

        Test.startTest();
        FEC_CampaignBatchLogger.logCalloutError(logId, 'TestBatch', 400, 'Bad Request', 2);
        FEC_CampaignBatchLogger.logCalloutError(logId, 'TestBatch', 503, 'Unavailable', 3);
        Test.stopTest();

        FEC_Batch_Log__c log = [
            SELECT FEC_Error_Details__c FROM FEC_Batch_Log__c WHERE Id = :logId
        ];
        Assert.isTrue(log.FEC_Error_Details__c.contains('HTTP 400'),
            'Should contain first error');
        Assert.isTrue(log.FEC_Error_Details__c.contains('HTTP 503'),
            'Should contain second error');
    }
}
