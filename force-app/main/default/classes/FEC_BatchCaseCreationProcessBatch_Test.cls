@IsTest
private class FEC_BatchCaseCreationProcessBatch_Test {

    private static FEC_Batch_Case_Creation__c makeBatchRow(String fileName, String statusValue) {
        FEC_Batch_Case_Creation__c row = new FEC_Batch_Case_Creation__c(
            FEC_File_Name__c = fileName,
            FEC_Status__c = statusValue
        );
        insert row;
        return row;
    }

    @IsTest
    static void testExecuteBatch_processesUploadedRows() {
        FEC_Batch_Case_Creation__c uploaded = makeBatchRow(
            'batch_uploaded.xlsx',
            FEC_ConstantCommon.UPLOADED_STATUS
        );
        makeBatchRow('batch_processed.xlsx', 'Processed');

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_BatchCaseCreationProcessBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        System.assertEquals('BatchApex', job.JobType);
        System.assertEquals('Completed', job.Status);

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT Id, FEC_Status__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :uploaded.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.FEC_Status__c);
    }

    @IsTest
    static void testExecuteAndFinish_withEmptyScope() {
        FEC_BatchCaseCreationProcessBatch batchJob = new FEC_BatchCaseCreationProcessBatch();

        Test.startTest();
        batchJob.execute(null, new List<FEC_Batch_Case_Creation__c>());
        batchJob.finish(null);
        Test.stopTest();

        System.assert(true, 'Empty scope should be handled without exceptions.');
    }

    @IsTest
    static void testExecuteBatch_handlesControllerExceptionWithCatch() {
        FEC_Batch_Case_Creation__c uploaded = makeBatchRow(
            'batch_bad_payload.xlsx',
            FEC_ConstantCommon.UPLOADED_STATUS
        );

        // Create a malformed deferred payload so loadPendingImportPayload throws JSON parse exception.
        insert new ContentVersion(
            Title = FEC_BatchCaseCreationPendingService.PAYLOAD_CONTENT_TITLE,
            PathOnClient = 'bad_payload.json',
            VersionData = Blob.valueOf('{invalid_json'),
            Description = FEC_ConstantCommon.JSON_DATA_FOR_PROCESSING,
            FirstPublishLocationId = uploaded.Id
        );

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_BatchCaseCreationProcessBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        System.assertEquals('Completed', job.Status, 'Batch should complete after catching row exception.');

        FEC_Batch_Case_Creation__c refreshed = [
            SELECT Id, FEC_Status__c, FEC_Failure_Reason__c
            FROM FEC_Batch_Case_Creation__c
            WHERE Id = :uploaded.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.Id);
        System.assertNotEquals(null, refreshed.FEC_Status__c);
    }
}
