/**
 * Unit tests for FEC_LogApiQueueable (async FEC_API_Log__c insert).
 */
@IsTest
private class FEC_LogApiQueueable_Test {

    private static FEC_LogApiQueueable buildJob(
        String apiName,
        Boolean isSuccess,
        String errorMessage
    ) {
        return new FEC_LogApiQueueable(
            apiName,
            'https://api.example.com/v1/log',
            'POST',
            '{"key":"value"}',
            isSuccess,
            '200',
            errorMessage,
            '{"result":"ok"}'
        );
    }

    @IsTest
    static void testExecute_InsertsApiLog_Success() {
        Test.startTest();
        System.enqueueJob(buildJob('FEC_LogApiQueueable_Success', true, null));
        Test.stopTest();

        List<FEC_API_Log__c> logs = [
            SELECT Name,
                   FEC_Endpoint__c,
                   FEC_Method__c,
                   FEC_Request_String__c,
                   FEC_Status_Code__c,
                   FEC_Response_String__c,
                   FEC_Is_Success__c,
                   FEC_Error_Message__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_LogApiQueueable_Success'
        ];

        System.assertEquals(1, logs.size(), 'Queueable must insert one API log.');
        System.assertEquals('https://api.example.com/v1/log', logs[0].FEC_Endpoint__c);
        System.assertEquals('POST', logs[0].FEC_Method__c);
        System.assertEquals('{"key":"value"}', logs[0].FEC_Request_String__c);
        System.assertEquals('200', logs[0].FEC_Status_Code__c);
        System.assertEquals('{"result":"ok"}', logs[0].FEC_Response_String__c);
        System.assertEquals(true, logs[0].FEC_Is_Success__c);
        System.assertEquals(null, logs[0].FEC_Error_Message__c);
    }

    @IsTest
    static void testExecute_InsertsApiLog_Failure() {
        Test.startTest();
        System.enqueueJob(buildJob('FEC_LogApiQueueable_Fail', false, 'Connection timeout'));
        Test.stopTest();

        FEC_API_Log__c log = [
            SELECT FEC_Is_Success__c, FEC_Error_Message__c, FEC_Status_Code__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_LogApiQueueable_Fail'
            LIMIT 1
        ];

        System.assertEquals(false, log.FEC_Is_Success__c);
        System.assertEquals('Connection timeout', log.FEC_Error_Message__c);
        System.assertEquals('200', log.FEC_Status_Code__c);
    }

    @IsTest
    static void testExecute_InsertsApiLog_NullOptionalFields() {
        FEC_LogApiQueueable job = new FEC_LogApiQueueable(
            'FEC_LogApiQueueable_Minimal',
            null,
            'GET',
            null,
            false,
            null,
            null,
            null
        );

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        FEC_API_Log__c log = [
            SELECT Name, FEC_Endpoint__c, FEC_Request_String__c, FEC_Response_String__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_LogApiQueueable_Minimal'
            LIMIT 1
        ];

        System.assertEquals('FEC_LogApiQueueable_Minimal', log.Name);
        System.assertEquals(null, log.FEC_Endpoint__c);
        System.assertEquals(null, log.FEC_Request_String__c);
        System.assertEquals(null, log.FEC_Response_String__c);
    }
}
