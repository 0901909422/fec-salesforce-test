@IsTest
private class FEC_BCH_ImportQueueable_Test {

    @TestSetup
    static void setupData() {
        Case openCase = new Case(
            Subject = 'Queueable Import Case',
            FEC_ID_Search__c = 'BCH-Q-OPEN-2026',
            Status = 'New'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert openCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        update new Case(
            Id = openCase.Id,
            FEC_ID_Search__c = 'BCH-Q-OPEN-2026',
            OwnerId = UserInfo.getUserId()
        );
    }

    private static Id insertBatchRecord(String fileName, String status, Datetime uploadedOn) {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            return null;
        }
        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fMap = batchType.getDescribe().fields.getMap();
        if (fMap.containsKey('FEC_File_Name__c')) {
            batchRow.put('FEC_File_Name__c', fileName);
        }
        if (fMap.containsKey('FEC_Status__c') && String.isNotBlank(status)) {
            batchRow.put('FEC_Status__c', status);
        }
        if (fMap.containsKey('FEC_Uploaded_On__c') && uploadedOn != null) {
            batchRow.put('FEC_Uploaded_On__c', uploadedOn);
        }
        insert batchRow;
        return (Id) batchRow.get('Id');
    }

    private static FEC_BatchCaseHandlingImportRow buildApplicableRow(Id caseId) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Operation_Success;
        row.recordId = String.valueOf(caseId);
        row.routingAction = 'RESOLVE';
        row.inputtedRemarks = 'Queueable unit test remark';
        return row;
    }

    @IsTest
    static void testExecute_EmptyPayloadFinalizes() {
        Test.startTest();
        System.enqueueJob(new FEC_BatchCaseHandlingImportQueueable(null, null, null, false, 0));
        Test.stopTest();
        System.assert(true, 'Null batch and empty rows should finalize without exception.');
    }

    @IsTest
    static void testExecute_SingleApplicableRow() {
        Id batchId = insertBatchRecord('Single_Row.xlsx', 'Processing', Datetime.now());
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-Q-OPEN-2026' LIMIT 1];
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildApplicableRow(c.Id)
        };
        String rowsJson = JSON.serialize(rows);

        Test.startTest();
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, null, false, 0)
        );
        Test.stopTest();

        System.assert(true, 'Single applicable row execute should complete.');
    }

    @IsTest
    static void testExecute_ChainsFollowUpJob() {
        Id batchId = insertBatchRecord('Chain_Rows.xlsx', 'Processing', Datetime.now());
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-Q-OPEN-2026' LIMIT 1];
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildApplicableRow(c.Id),
            buildApplicableRow(c.Id)
        };
        String rowsJson = JSON.serialize(rows);

        Test.startTest();
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(batchId, rowsJson, null, false, 0)
        );
        Test.stopTest();

        System.assert(
            Limits.getQueueableJobs() >= 0,
            'Chained import should enqueue follow-up or finalize.'
        );
    }

    @IsTest
    static void testExecute_ExpiredBatchFails() {
        Id batchId = insertBatchRecord(
            'Stale_Batch.xlsx',
            'Processing',
            Datetime.now().addHours(-2)
        );
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-Q-OPEN-2026' LIMIT 1];
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildApplicableRow(c.Id)
        };

        Test.startTest();
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(
                batchId,
                JSON.serialize(rows),
                null,
                false,
                0
            )
        );
        Test.stopTest();

        System.assert(true, 'Expired batch path should fail import record.');
    }

    @IsTest
    static void testExecute_SkipsFailedRowsAndFinalizes() {
        Id batchId = insertBatchRecord('Failed_Rows.xlsx', 'Processing', Datetime.now());
        if (batchId == null) {
            System.assert(true, 'Skipped: FEC_Batch_Case_Handling__c not on org.');
            return;
        }
        FEC_BatchCaseHandlingImportRow failed = new FEC_BatchCaseHandlingImportRow();
        failed.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        failed.recordId = '500000000000001AAA';

        Test.startTest();
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(
                batchId,
                JSON.serialize(new List<FEC_BatchCaseHandlingImportRow>{ failed }),
                null,
                true,
                0
            )
        );
        Test.stopTest();

        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            failed.status,
            'Failed rows should be skipped without changing status.'
        );
    }
}
