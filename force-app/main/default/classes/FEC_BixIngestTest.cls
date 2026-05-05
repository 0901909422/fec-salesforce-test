@isTest
private class FEC_BixIngestTest {

    private static final String TEST_FILENAME = 'test_upload.json';

    @testSetup
    static void setupTestData() {
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'ApplicationID',
            FEC_FieldID__c = 'TestField',
            FEC_Status__c = FEC_ConstantCommon.PROCESSED_STATUS,
            FEC_IsActive__c = true
        );
        insert config;

        List<FEC_CustomerAdditionalInfo__c> details = new List<FEC_CustomerAdditionalInfo__c>();
        for (Integer i = 0; i < 5; i++) {
            details.add(new FEC_CustomerAdditionalInfo__c(
                FEC_Config__c = config.Id,
                FEC_KeyIdentifier__c = 'ApplicationID',
                FEC_KeyIDValue__c = '1000' + i,
                FEC_FieldID__c = 'TestField',
                FEC_FieldValue__c = 'Value' + i,
                FEC_IsActive__c = true,
                FEC_LinkedFilename__c = TEST_FILENAME,
                FEC_CompositeKey__c = '1000' + i + '!ApplicationID!TestField'
            ));
        }
        insert details;
    }

    // =========================================================================
    // FEC_BixIngestService — buildRequestBody tests
    // =========================================================================

    @isTest
    static void testBuildRequestBody_SingleRecord() {
        FEC_CustomerAdditionalInfo__c rec = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIdentifier__c = 'CONTRACT_NUMBER',
            FEC_KeyIDValue__c = '12345678',
            FEC_FieldID__c = 'RISK_SCORE',
            FEC_FieldValue__c = '750',
            FEC_IsActive__c = true
        );

        String jsonBody = FEC_BixIngestService.buildRequestBody(new List<FEC_CustomerAdditionalInfo__c>{ rec });

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        Assert.areEqual('BIX_FECS_CUST_ADDINFO', (String) parsed.get('tableName'));
        Assert.areEqual('PXEXTRACTDATETIME', (String) parsed.get('pkColumn'));

        List<Object> records = (List<Object>) parsed.get('records');
        Assert.areEqual(1, records.size());

        Map<String, Object> bixRec = (Map<String, Object>) records[0];
        Assert.areEqual('CONTRACT_NUMBER', (String) bixRec.get('KEYIDENTIFIER'));
        Assert.areEqual('12345678', (String) bixRec.get('KEYIDVALUE'));
        Assert.areEqual('RISK_SCORE', (String) bixRec.get('FIELDID'));
        Assert.areEqual('750', (String) bixRec.get('FIELDVALUE'));
        Assert.areEqual('1', (String) bixRec.get('ISACTIVE'));
    }

    @isTest
    static void testBuildRequestBody_EmptyList() {
        String jsonBody = FEC_BixIngestService.buildRequestBody(new List<FEC_CustomerAdditionalInfo__c>());

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        Assert.areEqual('BIX_FECS_CUST_ADDINFO', (String) parsed.get('tableName'));
        Assert.areEqual('PXEXTRACTDATETIME', (String) parsed.get('pkColumn'));

        List<Object> records = (List<Object>) parsed.get('records');
        Assert.areEqual(0, records.size());
    }

    // =========================================================================
    // FEC_BixIngestService — mapToBixRecord tests
    // =========================================================================

    @isTest
    static void testMapToBixRecord_IsActiveTrue() {
        FEC_CustomerAdditionalInfo__c rec = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIdentifier__c = 'APP_ID',
            FEC_KeyIDValue__c = '999',
            FEC_FieldID__c = 'STATUS',
            FEC_FieldValue__c = 'Active',
            FEC_IsActive__c = true
        );

        String ts = Datetime.now().formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);
        FEC_BixIngestService.BixRecord bix = FEC_BixIngestService.mapToBixRecord(rec, ts);

        Assert.areEqual('1', bix.ISACTIVE);
    }

    @isTest
    static void testMapToBixRecord_IsActiveFalse() {
        FEC_CustomerAdditionalInfo__c rec = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIdentifier__c = 'APP_ID',
            FEC_KeyIDValue__c = '999',
            FEC_FieldID__c = 'STATUS',
            FEC_FieldValue__c = 'Inactive',
            FEC_IsActive__c = false
        );

        String ts = Datetime.now().formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);
        FEC_BixIngestService.BixRecord bix = FEC_BixIngestService.mapToBixRecord(rec, ts);

        Assert.areEqual('0', bix.ISACTIVE);
    }

    @isTest
    static void testMapToBixRecord_FieldMapping() {
        FEC_CustomerAdditionalInfo__c rec = new FEC_CustomerAdditionalInfo__c(
            FEC_KeyIdentifier__c = 'CONTRACT_NUMBER',
            FEC_KeyIDValue__c = '12345678',
            FEC_FieldID__c = 'RISK_SCORE',
            FEC_FieldValue__c = '750',
            FEC_IsActive__c = true
        );

        String ts = '2025-07-15T10:30:00.000Z';
        FEC_BixIngestService.BixRecord bix = FEC_BixIngestService.mapToBixRecord(rec, ts);

        // Direct field mappings
        Assert.areEqual('CONTRACT_NUMBER', bix.KEYIDENTIFIER);
        Assert.areEqual('12345678', bix.KEYIDVALUE);
        Assert.areEqual('RISK_SCORE', bix.FIELDID);
        Assert.areEqual('750', bix.FIELDVALUE);
        Assert.areEqual('1', bix.ISACTIVE);

        // Composite key: KeyIDValue!KeyIdentifier!FieldID
        String expectedCompositeKey = '12345678!CONTRACT_NUMBER!RISK_SCORE';
        Assert.areEqual(expectedCompositeKey, bix.PXINSNAME);

        // PZINSKEY: ObjectApiName!CompositeKey
        Assert.areEqual('FEC_CustomerAdditionalInfo__c!' + expectedCompositeKey, bix.PZINSKEY);

        // PXEXTRACTIDENTIFIER: ObjectApiName!FunctionName!Timestamp
        Assert.areEqual('FEC_CustomerAdditionalInfo__c!FEC_BixIngestQueueable!' + ts, bix.PXEXTRACTIDENTIFIER);

        // Timestamps
        Assert.areEqual(ts, bix.PXEXTRACTDATETIME);
        Assert.areEqual(ts, bix.PXSAVEDATETIME);

        // Null fields
        Assert.areEqual(null, bix.PXCREATEDATETIME);
        Assert.areEqual(null, bix.PXCREATEOPERATOR);
        Assert.areEqual(null, bix.PXUPDATEDATETIME);
        Assert.areEqual(null, bix.PXUPDATEOPERATOR);
    }


    // =========================================================================
    // FEC_BixIngestCallout — sendRequest tests
    // =========================================================================

    @isTest
    static void testSendRequest_Success() {
        Test.setMock(HttpCalloutMock.class, new FEC_BixIngestMock(200, '{"status":"ok"}'));

        Test.startTest();
        FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest('{"test":"payload"}');
        Test.stopTest();

        Assert.isTrue(result.isSuccess);
        Assert.areEqual(200, result.httpStatusCode);
        Assert.areEqual('{"status":"ok"}', result.responseBody);
        Assert.areEqual(null, result.errorMessage);
    }

    @isTest
    static void testSendRequest_Failure() {
        Test.setMock(HttpCalloutMock.class, new FEC_BixIngestMock(500, 'Internal Server Error'));

        Test.startTest();
        FEC_BixIngestCallout.BixIngestResult result = FEC_BixIngestCallout.sendRequest('{"test":"payload"}');
        Test.stopTest();

        Assert.isFalse(result.isSuccess);
        Assert.areEqual(500, result.httpStatusCode);
        Assert.isTrue(result.errorMessage != null);
        Assert.isTrue(result.errorMessage.contains('500'));
    }

    // =========================================================================
    // FEC_BixIngestQueueable tests (need DML for SOQL query)
    // =========================================================================

    @isTest
    static void testQueueable_SuccessFlow() {
        Test.setMock(HttpCalloutMock.class, new FEC_BixIngestMock(200, '{"status":"ok"}'));

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME));
        Test.stopTest();

        // Fire-and-forget: Config status should remain Processed
        FEC_CustomerAdditionalInfoConfig__c config = [
            SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1
        ];
        Assert.areEqual(FEC_ConstantCommon.PROCESSED_STATUS, config.FEC_Status__c);
    }

    @isTest
    static void testQueueable_FailureFlow() {
        Test.setMock(HttpCalloutMock.class, new FEC_BixIngestMock(500, 'Internal Server Error'));

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable(TEST_FILENAME));
        Test.stopTest();

        // Fire-and-forget: Config status should remain Processed even on failure
        FEC_CustomerAdditionalInfoConfig__c config = [
            SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1
        ];
        Assert.areEqual(FEC_ConstantCommon.PROCESSED_STATUS, config.FEC_Status__c);
    }

    @isTest
    static void testQueueable_NoRecords() {
        Test.setMock(HttpCalloutMock.class, new FEC_BixIngestMock(200, '{"status":"ok"}'));

        Test.startTest();
        System.enqueueJob(new FEC_BixIngestQueueable('nonexistent_file.json'));
        Test.stopTest();

        // Should complete without error — Config status unchanged
        FEC_CustomerAdditionalInfoConfig__c config = [
            SELECT FEC_Status__c FROM FEC_CustomerAdditionalInfoConfig__c LIMIT 1
        ];
        Assert.areEqual(FEC_ConstantCommon.PROCESSED_STATUS, config.FEC_Status__c);
    }
}
