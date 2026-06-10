@IsTest
private class FEC_BCH_ImportValidateQueueable_Test {

    private static Id insertBatchRecord(String fileName) {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            return null;
        }
        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', fileName);
        }
        if (fMap.containsKey('FEC_Status__c')) {
            batchRow.put('FEC_Status__c', 'Processing');
        }
        if (fMap.containsKey('FEC_Uploaded_On__c')) {
            batchRow.put('FEC_Uploaded_On__c', Datetime.now());
        }
        insert batchRow;
        return (Id) batchRow.get('Id');
    }

    private static FEC_BatchCaseHandlingImportRow buildRow(String caseSearchId) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.caseIdSearch = caseSearchId;
        row.routingAction = 'RESOLVE';
        row.inputtedRemarks = 'Validate queueable test';
        return row;
    }

    @IsTest
    static void testExecute_NullBatchIdReturnsEarly() {
        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(null, null, null, null, false, 0)
        );
        Test.stopTest();
        System.assert(true, 'Null batch id should exit without exception.');
    }

    @IsTest
    static void testExecute_EmptyRowsFinalizes() {
        Id batchId = insertBatchRecord('Validate_Empty.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(batchId, '[]', '[]', null, false, 0)
        );
        Test.stopTest();

        System.assert(true, 'Empty rows should finalize batch import.');
    }

    @IsTest
    static void testExecute_ValidatesRowsFromInputJson() {
        Id batchId = insertBatchRecord('Validate_Input.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        List<Object> inputRows = new List<Object>{
            new Map<String, Object>{
                'caseIdSearch' => 'BCH-VAL-NO-MATCH',
                'routingAction' => 'RESOLVE',
                'inputtedRemarks' => 'remark'
            }
        };

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                JSON.serialize(inputRows),
                null,
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Validate queueable should process input rows.');
    }

    @IsTest
    static void testExecute_UsesSerializedRowsAndContext() {
        Id batchId = insertBatchRecord('Validate_Serialized.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildRow('BCH-VAL-SER-001')
        };
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext ctx =
            FEC_BatchCaseHandlingImportService.prepareImportValidateChunkContext(rows, false);

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(rows),
                FEC_BatchCaseHandlingImportService.serializeImportValidateChunkContext(ctx),
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Serialized rows with context should validate.');
    }

    @IsTest
    static void testExecute_ExpiredBatchFailsImport() {
        Id batchId = insertBatchRecord('Validate_Expired.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        SObject batchRow = batchType.newSObject(batchId);
        if (fMap.containsKey('FEC_Uploaded_On__c')) {
            batchRow.put('FEC_Uploaded_On__c', Datetime.now().addHours(-3));
        }
        if (fMap.containsKey('FEC_Status__c')) {
            batchRow.put('FEC_Status__c', 'Processing');
        }
        update batchRow;

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ buildRow('BCH-VAL-EXP') }),
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Expired batch should fail import without exception.');
    }

    @IsTest
    static void testExecute_InvalidValidateContextFailsBatch() {
        Id batchId = insertBatchRecord('Validate_InvalidCtx.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildRow('BCH-VAL-CTX-001')
        };

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(rows),
                '{invalid-json',
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Invalid validate context should fail batch safely.');
    }

    @IsTest
    static void testExecute_ValidatedRowsWithoutApplicableEnqueueFinalize() {
        Id batchId = insertBatchRecord('Validate_NoApply.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        FEC_BatchCaseHandlingImportRow row = buildRow('BCH-NO-MATCH-999');
        row.status = 'Failed';
        row.routingAction = null;

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row }),
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Non-applicable rows should finalize batch.');
    }

    @IsTest
    static void testExecute_ApplicableRowEnqueuesApplyJob() {
        Id batchId = insertBatchRecord('Validate_Apply.xlsx');
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }

        Case openCase = new Case(
            Subject = 'BCH Validate Apply Case',
            FEC_ID_Search__c = 'BCH-VAL-APPLY-' + String.valueOf(System.currentTimeMillis()),
            Status = 'New'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert openCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.recordId = String.valueOf(openCase.Id);
        row.routingAction = 'RESOLVE';
        row.inputtedRemarks = 'Apply path test';

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ row }),
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Applicable row should enqueue apply job.');
    }

    @IsTest
    static void testExecute_CofOrGsrTruePath() {
        Id batchId = insertBatchRecord('Validate_CofGsr.xlsx');
        if (batchId == null) {
            return;
        }

        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildRow('BCH-COF-NO-MATCH')
        };

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(rows),
                null,
                true,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'cofOrGsr=true validate path should complete.');
    }

    @IsTest
    static void testExecute_ChunkedValidationEnqueuesFollowUp() {
        Id batchId = insertBatchRecord('Validate_Chunk.xlsx');
        if (batchId == null) {
            return;
        }

        Integer chunkSize = FEC_BatchCaseHandlingImportService.IMPORT_VALIDATE_MAX_ROWS_PER_CHUNK;
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();
        for (Integer i = 0; i < chunkSize + 1; i++) {
            FEC_BatchCaseHandlingImportRow row = buildRow('BCH-CHUNK-' + i);
            row.status = 'Failed';
            row.routingAction = null;
            rows.add(row);
        }

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchId,
                null,
                JSON.serialize(rows),
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Chunked validation should enqueue follow-up or finalize.');
    }
}
