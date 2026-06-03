/**
 * Unit tests for FEC_ApiCalloutQueueable (async FEC_API_Log__c insert).
 */
@IsTest
private class FEC_ApiCalloutQueueable_Test {

    private static FEC_ApiCalloutQueueable buildJob(
        String apiName,
        Boolean isSuccess,
        String errorMessage
    ) {
        return new FEC_ApiCalloutQueueable(
            apiName,
            'https://api.example.com/v1/test',
            'POST',
            '{"request":"test"}',
            '200',
            '{"status":"ok"}',
            isSuccess,
            errorMessage
        );
    }

    @IsTest
    static void execute_insertsApiLog_success() {
        Test.startTest();
        System.enqueueJob(buildJob('FEC_Test_API_Success', true, null));
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
            WHERE Name = 'FEC_Test_API_Success'
        ];
        System.assertEquals(1, logs.size(), 'Queueable must insert one API log.');
        System.assertEquals('https://api.example.com/v1/test', logs[0].FEC_Endpoint__c);
        System.assertEquals('POST', logs[0].FEC_Method__c);
        System.assertEquals('{"request":"test"}', logs[0].FEC_Request_String__c);
        System.assertEquals('200', logs[0].FEC_Status_Code__c);
        System.assertEquals('{"status":"ok"}', logs[0].FEC_Response_String__c);
        System.assertEquals(true, logs[0].FEC_Is_Success__c);
        System.assertEquals(null, logs[0].FEC_Error_Message__c);
    }

    @IsTest
    static void execute_insertsApiLog_failure() {
        Test.startTest();
        System.enqueueJob(buildJob('FEC_Test_API_Fail', false, 'Timeout'));
        Test.stopTest();

        FEC_API_Log__c log = [
            SELECT FEC_Is_Success__c, FEC_Error_Message__c
            FROM FEC_API_Log__c
            WHERE Name = 'FEC_Test_API_Fail'
            LIMIT 1
        ];
        System.assertEquals(false, log.FEC_Is_Success__c);
        System.assertEquals('Timeout', log.FEC_Error_Message__c);
    }
}
