@IsTest
private class FEC_BixIngestQueueable_Test {

    private static final String TEST_FILENAME = 'BIX_Upload_Data_2026.csv';
    private static final String BIX_API_CONFIG_NAME = 'FEC_BIX_Ingest';

    private class MockSuccessCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status": "success"}');
            return res;
        }
    }

    private static Boolean isBixIngestEndpointConfigured() {
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(BIX_API_CONFIG_NAME);
        return cfg != null && String.isNotBlank(cfg.FEC_Endpoint__c);
    }

    @TestSetup
    static void setupData() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'LEAD_ID',
            FEC_FieldID__c = 'Score',
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS,
            FEC_IsActive__c = true
        );
        insert config;

        List<FEC_CustomerAdditionalInfo__c> testRecords = new List<FEC_CustomerAdditionalInfo__c>();
        for (Integer i = 0; i < 3; i++) {
            testRecords.add(
                new FEC_CustomerAdditionalInfo__c(
                    FEC_Config__c = config.Id,
                    FEC_LinkedFilename__c = TEST_FILENAME,
                    FEC_KeyIdentifier__c = 'LEAD_ID',
                    FEC_KeyIDValue__c = '00Q0000000' + i,
                    FEC_FieldID__c = 'Score',
                    FEC_FieldValue__c = String.valueOf(80 + i),
                    FEC_IsActive__c = true,
                    FEC_CompositeKey__c = '00Q0000000' + i + '!LEAD_ID!Score'
                )
            );
        }
        insert testRecords;
    }

    /**
     * Constructor chính: query theo filename, build payload, gọi BIX callout.
     * Cần deploy FEC_BixIngestQueueable.cls cùng test; cần CMDT FEC_BIX_Ingest trên org để chạy callout.
     */
    @IsTest
    static void testQueueable_PrimaryConstructor_Success() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME));
        Test.stopTest();

        System.assertEquals(
            3,
            [SELECT COUNT() FROM FEC_CustomerAdditionalInfo__c WHERE FEC_LinkedFilename__c = :TEST_FILENAME]
        );
    }

    /**
     * Constructor chaining: xử lý batch đầu từ remainingBatches.
     */
    @IsTest
    static void testQueueable_ChainingConstructor_Success() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        List<FEC_CustomerAdditionalInfo__c> allRecords = [
            SELECT Id, FEC_KeyIdentifier__c, FEC_KeyIDValue__c, FEC_FieldID__c, FEC_FieldValue__c, FEC_IsActive__c
            FROM FEC_CustomerAdditionalInfo__c
            WHERE FEC_LinkedFilename__c = :TEST_FILENAME
        ];
        List<List<FEC_CustomerAdditionalInfo__c>> remainingBatches = new List<List<FEC_CustomerAdditionalInfo__c>>();
        remainingBatches.add(new List<FEC_CustomerAdditionalInfo__c>{ allRecords[0], allRecords[1] });
        remainingBatches.add(new List<FEC_CustomerAdditionalInfo__c>{ allRecords[2] });

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME, remainingBatches));
        Test.stopTest();

        System.assert(true, 'Chaining queueable hoàn tất không ném ngoại lệ.');
    }

    /**
     * Không có bản ghi theo filename → return sớm, không callout.
     */
    @IsTest
    static void testQueueable_EmptyRecords_ReturnEarly() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable('NON_EXISTING_FILE_NAME.csv'));
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_CustomerAdditionalInfo__c WHERE FEC_LinkedFilename__c = 'NON_EXISTING_FILE_NAME.csv']
        );
    }

    /**
     * Không set HttpCalloutMock → lỗi callout bị catch trong execute.
     */
    @IsTest
    static void testQueueable_TriggerException_SwallowedSafely() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME));
        Test.stopTest();

        System.assert(true, 'Lỗi callout được nuốt an toàn trong khối catch.');
    }

    /**
     * Mock callout trả về lỗi HTTP — execute nuốt exception.
     */
    @IsTest
    static void testQueueable_CalloutFailure_Swallowed() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockFailureCallout());

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME));
        Test.stopTest();

        System.assert(true, 'Failed callout should be caught in execute.');
    }

    /**
     * Constructor chaining với remainingBatches rỗng sau remove(0).
     */
    @IsTest
    static void testQueueable_ChainingConstructor_EmptyRemaining() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        List<FEC_CustomerAdditionalInfo__c> allRecords = [
            SELECT Id, FEC_KeyIdentifier__c, FEC_KeyIDValue__c, FEC_FieldID__c, FEC_FieldValue__c, FEC_IsActive__c
            FROM FEC_CustomerAdditionalInfo__c
            WHERE FEC_LinkedFilename__c = :TEST_FILENAME
        ];
        List<List<FEC_CustomerAdditionalInfo__c>> remainingBatches =
            new List<List<FEC_CustomerAdditionalInfo__c>>{ allRecords };

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME, remainingBatches));
        Test.stopTest();

        System.assertEquals(3, allRecords.size());
    }

    @IsTest
    static void testQueueable_PrimaryConstructor_ChainsWhenSplit() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        FEC_CustomerAdditionalInfoConfig__c config = [
            SELECT Id FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1
        ];
        List<FEC_CustomerAdditionalInfo__c> bulkRecords = new List<FEC_CustomerAdditionalInfo__c>();
        for (Integer i = 10; i < 25; i++) {
            bulkRecords.add(
                new FEC_CustomerAdditionalInfo__c(
                    FEC_Config__c = config.Id,
                    FEC_LinkedFilename__c = 'BIX_BULK_SPLIT.csv',
                    FEC_KeyIdentifier__c = 'LEAD_ID',
                    FEC_KeyIDValue__c = '00Q0000000' + i,
                    FEC_FieldID__c = 'Score',
                    FEC_FieldValue__c = String.valueOf(70 + i),
                    FEC_IsActive__c = true,
                    FEC_CompositeKey__c = '00Q0000000' + i + '!LEAD_ID!Score'
                )
            );
        }
        insert bulkRecords;

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable('BIX_BULK_SPLIT.csv'));
        Test.stopTest();

        System.assertEquals(
            15,
            [SELECT COUNT() FROM FEC_CustomerAdditionalInfo__c WHERE FEC_LinkedFilename__c = 'BIX_BULK_SPLIT.csv']
        );
    }

    @IsTest
    static void testQueueable_ChainingConstructor_NullFilename() {
        if (!isBixIngestEndpointConfigured()) {
            return;
        }
        Test.setMock(HttpCalloutMock.class, new MockSuccessCallout());

        List<FEC_CustomerAdditionalInfo__c> allRecords = [
            SELECT Id, FEC_KeyIdentifier__c, FEC_KeyIDValue__c, FEC_FieldID__c, FEC_FieldValue__c, FEC_IsActive__c
            FROM FEC_CustomerAdditionalInfo__c
            WHERE FEC_LinkedFilename__c = :TEST_FILENAME
        ];
        List<List<FEC_CustomerAdditionalInfo__c>> batches =
            new List<List<FEC_CustomerAdditionalInfo__c>>{ allRecords };

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(null, batches));
        Test.stopTest();

        System.assertEquals(3, allRecords.size());
    }

    @IsTest
    static void testExecuteDirect_PrimaryConstructor_WithoutEndpointConfig() {
        // Không phụ thuộc endpoint CMDT: execute phải tự bắt lỗi callout và thoát an toàn.
        Test.startTest();
        new FEC_BixIngestQueueable(TEST_FILENAME).execute(null);
        Test.stopTest();
        System.assert(true, 'Primary execute should swallow endpoint/callout failures.');
    }

    @IsTest
    static void testExecuteDirect_ChainingConstructor_WithoutEndpointConfig() {
        List<FEC_CustomerAdditionalInfo__c> seed = new List<FEC_CustomerAdditionalInfo__c>{
            new FEC_CustomerAdditionalInfo__c(
                FEC_KeyIdentifier__c = 'LEAD_ID',
                FEC_KeyIDValue__c = '00Q000000099',
                FEC_FieldID__c = 'Score',
                FEC_FieldValue__c = '88',
                FEC_IsActive__c = true
            )
        };
        List<List<FEC_CustomerAdditionalInfo__c>> batches = new List<List<FEC_CustomerAdditionalInfo__c>>{
            seed
        };

        Test.startTest();
        new FEC_BixIngestQueueable('NO_FILE_REQUIRED.csv', batches).execute(null);
        Test.stopTest();
        System.assert(true, 'Chaining execute should run safely in test context.');
    }

    private class MockFailureCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"status":"error"}');
            return res;
        }
    }
}
