@IsTest
private class FEC_ProcessCustomerDataBatchTest {

    /**
     * Bug Condition Exploration Test
     * 
     * Validates: Requirements 1.1, 1.2
     * 
     * Bug Condition: Config có status 'Uploaded' nhưng không có ContentDocumentLink nào
     * với FEC_Comments__c = 'Uploaded' và Description = 'JSON_Data_For_Processing'.
     * 
     * Expected behavior (after fix): Config should transition to 'Processed'.
     * On UNFIXED code: This test is EXPECTED TO FAIL because the bug causes
     * config to stay 'Uploaded' indefinitely.
     */
    @IsTest
    static void testBugCondition_ConfigWithoutFiles_StaysUploaded() {
        // Arrange: Create config with status 'Uploaded' but NO files attached
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            Name = 'Test Config No Files',
            FEC_KeyIdentifier__c = 'TestKey',
            FEC_FieldID__c = 'TestField',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert config;

        // Act: Run the batch
        Test.startTest();
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Assert: Config should be 'Processed' (expected behavior after fix)
        FEC_CustomerAdditionalInfoConfig__c result = [
            SELECT FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE Id = :config.Id
        ];
        Assert.areEqual(
            FEC_ConstantCommon.PROCESSED_STATUS, 
            result.FEC_Status__c,
            'Config without files should transition to Processed, but got: ' + result.FEC_Status__c
        );

        // Assert: No detail records should be created for this config
        Integer detailCount = [
            SELECT COUNT() 
            FROM FEC_CustomerAdditionalInfo__c 
            WHERE FEC_Config__c = :config.Id
        ];
        Assert.areEqual(
            0, 
            detailCount, 
            'No FEC_CustomerAdditionalInfo__c records should be created for config without files'
        );
    }

    /**
     * Preservation Property Test - Valid JSON Files
     * 
     * Validates: Requirements 3.1, 3.2
     * 
     * Property 2: Preservation - Config có file JSON hợp lệ phải được xử lý bình thường.
     * Config with valid JSON file attached should transition to 'Processing'
     * and create correct FEC_CustomerAdditionalInfo__c records.
     */
    @IsTest
    static void testPreservation_ConfigWithValidJsonFiles_ProcessedNormally() {
        // Arrange: Create config with status 'Uploaded'
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            Name = 'Test Config Valid JSON',
            FEC_KeyIdentifier__c = 'TestKey',
            FEC_FieldID__c = 'TestField',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert config;

        // Create ContentVersion with valid JSON data
        String validJson = '[["header1","header2","header3"],["key1","value1","yes"]]';
        ContentVersion cv = new ContentVersion(
            Title = 'test_data.json',
            PathOnClient = 'test_data.json',
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            VersionData = Blob.valueOf(validJson)
        );
        insert cv;

        // Query ContentDocumentId and create link to config
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = config.Id,
            ShareType = 'V'
        );

        // Act: Run the batch
        Test.startTest();
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Assert: Config status should be 'Processing'
        FEC_CustomerAdditionalInfoConfig__c result = [
            SELECT FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE Id = :config.Id
        ];
        Assert.areEqual(
            'Processing', 
            result.FEC_Status__c,
            'Config with valid JSON file should transition to Processing, but got: ' + result.FEC_Status__c
        );

        // Assert: FEC_CustomerAdditionalInfo__c records created with correct values
        List<FEC_CustomerAdditionalInfo__c> details = [
            SELECT FEC_Config__c, FEC_KeyIdentifier__c, FEC_FieldID__c,
                   FEC_KeyIDValue__c, FEC_FieldValue__c, FEC_IsActive__c, FEC_LinkedFilename__c
            FROM FEC_CustomerAdditionalInfo__c 
            WHERE FEC_Config__c = :config.Id
        ];
        Assert.areEqual(1, details.size(), 'Should create 1 detail record (1 data row after header)');

        FEC_CustomerAdditionalInfo__c detail = details[0];
        Assert.areEqual(config.Id, detail.FEC_Config__c, 'Detail should reference the config');
        Assert.areEqual('TestKey', detail.FEC_KeyIdentifier__c, 'KeyIdentifier should match config');
        Assert.areEqual('TestField', detail.FEC_FieldID__c, 'FieldID should match config');
        Assert.areEqual('key1', detail.FEC_KeyIDValue__c, 'KeyIDValue should be cols[0]');
        Assert.areEqual('value1', detail.FEC_FieldValue__c, 'FieldValue should be cols[1]');
        Assert.areEqual(true, detail.FEC_IsActive__c, 'IsActive should be true when cols[2] is yes');
        Assert.areEqual('test_data.json', detail.FEC_LinkedFilename__c, 'LinkedFilename should match CV title');
    }

    /**
     * Preservation Property Test - Invalid JSON
     * 
     * Validates: Requirements 3.2
     * 
     * Property 2: Preservation - Config có file JSON invalid phải chuyển sang 'Failed'.
     * Error handling behavior must be preserved: invalid JSON causes status = 'Failed'.
     */
    @IsTest
    static void testPreservation_ConfigWithInvalidJson_StatusFailed() {
        // Arrange: Create config with status 'Uploaded'
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            Name = 'Test Config Invalid JSON',
            FEC_KeyIdentifier__c = 'TestKey',
            FEC_FieldID__c = 'TestField',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert config;

        // Create ContentVersion with invalid JSON content
        ContentVersion cv = new ContentVersion(
            Title = 'bad_data.json',
            PathOnClient = 'bad_data.json',
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            VersionData = Blob.valueOf('not valid json')
        );
        insert cv;

        // Query ContentDocumentId and create link to config
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = config.Id,
            ShareType = 'V'
        );

        // Act: Run the batch
        Test.startTest();
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Assert: Config status should be 'Failed' due to JSON parse error
        FEC_CustomerAdditionalInfoConfig__c result = [
            SELECT FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE Id = :config.Id
        ];
        Assert.areEqual(
            'Failed', 
            result.FEC_Status__c,
            'Config with invalid JSON should transition to Failed, but got: ' + result.FEC_Status__c
        );
    }

    /**
     * Preservation Property Test - Mixed Configs
     * 
     * Validates: Requirements 3.1, 3.2, 3.3
     * 
     * Property 2: Preservation - Mixed configs phải được xử lý đúng theo từng điều kiện.
     * Config with valid JSON → 'Processing', config with invalid JSON → 'Failed'.
     */
    @IsTest
    static void testPreservation_MixedConfigs_EachProcessedCorrectly() {
        // Arrange: Create 2 configs with status 'Uploaded'
        FEC_CustomerAdditionalInfoConfig__c configValid = new FEC_CustomerAdditionalInfoConfig__c(
            Name = 'Config Valid JSON',
            FEC_KeyIdentifier__c = 'ValidKey',
            FEC_FieldID__c = 'ValidField',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        FEC_CustomerAdditionalInfoConfig__c configInvalid = new FEC_CustomerAdditionalInfoConfig__c(
            Name = 'Config Invalid JSON',
            FEC_KeyIdentifier__c = 'InvalidKey',
            FEC_FieldID__c = 'InvalidField',
            FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
        );
        insert new List<FEC_CustomerAdditionalInfoConfig__c>{ configValid, configInvalid };

        // Create ContentVersion with valid JSON for config 1
        String validJson = '[["header1","header2","header3"],["key1","value1","yes"]]';
        ContentVersion cvValid = new ContentVersion(
            Title = 'valid_data.json',
            PathOnClient = 'valid_data.json',
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            VersionData = Blob.valueOf(validJson)
        );
        // Create ContentVersion with invalid JSON for config 2
        ContentVersion cvInvalid = new ContentVersion(
            Title = 'invalid_data.json',
            PathOnClient = 'invalid_data.json',
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FEC_Comments__c = FEC_ConstantCommon.UPLOADED_STATUS,
            VersionData = Blob.valueOf('not valid json')
        );
        insert new List<ContentVersion>{ cvValid, cvInvalid };

        // Query ContentDocumentIds
        List<ContentVersion> insertedCVs = [
            SELECT Id, ContentDocumentId, Title 
            FROM ContentVersion 
            WHERE Id IN :new Set<Id>{ cvValid.Id, cvInvalid.Id }
        ];

        Id validDocId;
        Id invalidDocId;
        for (ContentVersion insertedCV : insertedCVs) {
            if (insertedCV.Id == cvValid.Id) {
                validDocId = insertedCV.ContentDocumentId;
            } else {
                invalidDocId = insertedCV.ContentDocumentId;
            }
        }

        // Create ContentDocumentLinks
        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(
                ContentDocumentId = validDocId,
                LinkedEntityId = configValid.Id,
                ShareType = 'V'
            ),
            new ContentDocumentLink(
                ContentDocumentId = invalidDocId,
                LinkedEntityId = configInvalid.Id,
                ShareType = 'V'
            )
        };

        // Act: Run the batch
        Test.startTest();
        Database.executeBatch(new FEC_ProcessCustomerDataBatch());
        Test.stopTest();

        // Assert: Config with valid JSON → 'Processing'
        FEC_CustomerAdditionalInfoConfig__c resultValid = [
            SELECT FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE Id = :configValid.Id
        ];
        Assert.areEqual(
            'Processing', 
            resultValid.FEC_Status__c,
            'Config with valid JSON should transition to Processing, but got: ' + resultValid.FEC_Status__c
        );

        // Assert: Config with invalid JSON → 'Failed'
        FEC_CustomerAdditionalInfoConfig__c resultInvalid = [
            SELECT FEC_Status__c 
            FROM FEC_CustomerAdditionalInfoConfig__c 
            WHERE Id = :configInvalid.Id
        ];
        Assert.areEqual(
            'Failed', 
            resultInvalid.FEC_Status__c,
            'Config with invalid JSON should transition to Failed, but got: ' + resultInvalid.FEC_Status__c
        );
    }
}
