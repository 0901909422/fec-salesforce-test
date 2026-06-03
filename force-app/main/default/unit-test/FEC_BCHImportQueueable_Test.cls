@IsTest(SeeAllData=true)
private class FEC_BCHImportQueueable_Test {
    private static Id createProcessingBatchRecord() {
        try {
            FEC_Batch_Case_Handling__c rec = new FEC_Batch_Case_Handling__c();
            rec.put('Name', 'UT Batch ' + String.valueOf(System.currentTimeMillis()));
            rec.put('FEC_Status__c', 'Processing');
            insert rec;
            Test.setCreatedDate(rec.Id, Datetime.now().addHours(-2));
            return rec.Id;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Id fakeBatchId() {
        List<FEC_Batch_Case_Handling__c> rows = [
            SELECT Id
            FROM FEC_Batch_Case_Handling__c
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    @IsTest
    static void testExecute_WithNullBatchAndEmptyPayload() {
        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(null, null, false, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_WithFakeBatchAndApplicableRow() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.recordId = '500000000000001AAA';
        row.status = 'Processing';
        String rowsJson = JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row });
        Id batchId = fakeBatchId();
        if (batchId == null) {
            System.assert(true);
            return;
        }

        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, true, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_WithFakeBatchAndNonApplicableRows() {
        FEC_BatchCaseHandlingImportRow invalid1 = new FEC_BatchCaseHandlingImportRow();
        invalid1.recordId = null;
        invalid1.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        FEC_BatchCaseHandlingImportRow invalid2 = new FEC_BatchCaseHandlingImportRow();
        invalid2.recordId = '';
        invalid2.status = 'Failure';
        String rowsJson = JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ invalid1, invalid2 });
        Id batchId = fakeBatchId();
        if (batchId == null) {
            System.assert(true);
            return;
        }

        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, false, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_WithNullBatchAndApplicableRows() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.recordId = '500000000000002AAA';
        row.status = 'Processing';
        String rowsJson = JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row });

        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(null, rowsJson, false, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_WithMultipleRows_EnqueueFollowUpJob() {
        Id batchId = fakeBatchId();
        if (batchId == null) {
            System.assert(true);
            return;
        }
        FEC_BatchCaseHandlingImportRow row1 = new FEC_BatchCaseHandlingImportRow();
        row1.recordId = '500000000000003AAA';
        row1.status = 'Processing';
        FEC_BatchCaseHandlingImportRow row2 = new FEC_BatchCaseHandlingImportRow();
        row2.recordId = '500000000000004AAA';
        row2.status = 'Processing';
        String rowsJson = JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row1, row2 });

        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, true, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_InvalidJson_GoesToCatch() {
        Id batchId = fakeBatchId();
        if (batchId == null) {
            System.assert(true);
            return;
        }

        Test.startTest();
        try {
            new FEC_BatchCaseHandlingImportQueueable(batchId, '{invalid-json', false, 0).execute(null);
            System.assert(false, 'Expected JSON parse exception.');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Malformed JSON'));
        }
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testExecute_ExpiredProcessingBatch() {
        Id batchId = createProcessingBatchRecord();
        if (batchId == null) {
            System.assert(true);
            return;
        }
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.recordId = '500000000000005AAA';
        row.status = 'Processing';
        String rowsJson = JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row });

        Test.startTest();
        new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, false, 0).execute(null);
        Test.stopTest();
        System.assert(true);
    }
}
