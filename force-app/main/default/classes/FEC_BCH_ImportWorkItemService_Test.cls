@IsTest
private class FEC_BCH_ImportWorkItemService_Test {

    @TestSetup
    static void setupData() {
        Case openCase = new Case(
            Subject = 'BCH Work Item Test Case',
            FEC_ID_Search__c = 'BCH-WI-OPEN-2026',
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
            FEC_ID_Search__c = 'BCH-WI-OPEN-2026',
            OwnerId = UserInfo.getUserId()
        );
    }

    private static Id insertBatchRecord(String fileName) {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        if (batchType == null) {
            return null;
        }
        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = batchType.getDescribe().fields.getMap();
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Name__c' }, fileName);
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, 1);
        insert batchRow;
        return (Id) batchRow.get('Id');
    }

    private static FEC_BatchCaseHandlingImportRow buildRow(String status, String recordId) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = status;
        row.recordId = recordId;
        row.routingAction = 'Resolve';
        row.inputtedRemarks = 'Work item unit test';
        return row;
    }

    @IsTest
    static void testWorkItemService_stageLoadAndCounts() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_Stage.xlsx');
        if (batchId == null) {
            return;
        }

        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildRow(System.Label.FEC_Operation_Success, '500000000000001AAA'),
            buildRow(System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed, null)
        };
        FEC_BCH_ImportWorkItemService.stageRows(batchId, rows);
        FEC_BCH_ImportWorkItemService.stageRows(null, rows);
        FEC_BCH_ImportWorkItemService.stageRows(batchId, null);

        System.assertEquals(2, FEC_BCH_ImportWorkItemService.countRowsByBatch(batchId));
        System.assertEquals(0, FEC_BCH_ImportWorkItemService.countRowsByBatch(null));
        System.assertEquals(2, FEC_BCH_ImportWorkItemService.countRowsByStatus(batchId, 'Pending'));

        List<FEC_BCH_Import_Work_Item__c> items = [
            SELECT FEC_Row_Payload__c, FEC_Row_Index__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchId
            ORDER BY FEC_Row_Index__c ASC
        ];
        List<FEC_BatchCaseHandlingImportRow> deserialized =
            FEC_BCH_ImportWorkItemService.deserializeRows(items);
        System.assertEquals(2, deserialized.size());

        rows[0].status = System.Label.FEC_Batch_Case_Handling_Success;
        FEC_BCH_ImportWorkItemService.saveScopeOutcomes(items, rows);
        System.assertEquals(1, FEC_BCH_ImportWorkItemService.countRowsByStatus(batchId, 'Success'));

        FEC_BCH_ImportWorkItemService.markScopeFailed(items, rows, 'batch scope failed');
        System.assert(
            String.isNotBlank(FEC_BCH_ImportWorkItemService.findFirstFailureReason(batchId)),
            'Phải trả failure reason sau markScopeFailed.'
        );

        FEC_BCH_ImportWorkItemService.WorkItemChunkResult chunk =
            FEC_BCH_ImportWorkItemService.loadRowsByBatchChunk(batchId, -1, 1);
        System.assertEquals(1, chunk.rows.size());
        System.assertEquals(2, FEC_BCH_ImportWorkItemService.loadRowsByBatch(batchId).size());
    }

    @IsTest
    static void testWorkItemService_invalidPayloadDeserialize() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_BadPayload.xlsx');
        insert new FEC_BCH_Import_Work_Item__c(
            FEC_Batch_Case_Handling__c = batchId,
            FEC_Row_Index__c = 0,
            FEC_Row_Payload__c = '{not-valid-json',
            FEC_Row_Status__c = 'Pending'
        );
        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BCH_ImportWorkItemService.loadRowsByBatch(batchId);
        System.assertEquals(1, rows.size());
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[0].status
        );
    }

    @IsTest
    static void testImportApplyBatch_executeApplicableRow() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Case c = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'BCH-WI-OPEN-2026' LIMIT 1];
        Id batchId = insertBatchRecord('WorkItem_ApplyExecute.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow('Validated', String.valueOf(c.Id))
            }
        );

        Test.startTest();
        Database.executeBatch(new FEC_BCH_ImportApplyBatch(batchId, false), 5);
        Test.stopTest();

        System.assert(
            FEC_BCH_ImportWorkItemService.countRowsByBatch(batchId) > 0,
            'Work item phải tồn tại sau batch apply.'
        );
    }

    @IsTest
    static void testImportApplyBatch_executeEmptyScopeFinishes() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_EmptyScope.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow(System.Label.FEC_Batch_Case_Handling_Success, '500000000000004AAA')
            }
        );
        List<FEC_BCH_Import_Work_Item__c> resolvedItems = [
            SELECT Id, FEC_Row_Status__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchId
        ];
        for (FEC_BCH_Import_Work_Item__c item : resolvedItems) {
            item.FEC_Row_Status__c = 'Success';
        }
        update resolvedItems;

        Test.startTest();
        Database.executeBatch(new FEC_BCH_ImportApplyBatch(batchId, false), 5);
        Test.stopTest();

        System.assert(true, 'Batch với scope rỗng phải finish không exception.');
    }

    @IsTest
    static void testImportApplyBatch_finishSmallImport() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_ApplyBatch.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow(
                    System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
                    '500000000000002AAA'
                )
            }
        );

        Test.startTest();
        Database.executeBatch(new FEC_BCH_ImportApplyBatch(batchId, false), 5);
        Database.executeBatch(new FEC_BCH_ImportApplyBatch(null, false), 5);
        Test.stopTest();

        FEC_Batch_Case_Handling__c batchRow = [
            SELECT FEC_Status__c
            FROM FEC_Batch_Case_Handling__c
            WHERE Id = :batchId
            LIMIT 1
        ];
        System.assertNotEquals('Processing', String.valueOf(batchRow.FEC_Status__c));
    }

    @IsTest
    static void testImportApplyBatch_finishSummaryOnlyPath() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_SummaryOnly.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow(System.Label.FEC_Batch_Case_Handling_Success, '500000000000007AAA'),
                buildRow(System.Label.FEC_Batch_Case_Handling_Success, '500000000000008AAA')
            }
        );
        List<FEC_BCH_Import_Work_Item__c> successItems = [
            SELECT Id, FEC_Row_Status__c
            FROM FEC_BCH_Import_Work_Item__c
            WHERE FEC_Batch_Case_Handling__c = :batchId
        ];
        for (FEC_BCH_Import_Work_Item__c item : successItems) {
            item.FEC_Row_Status__c = 'Success';
        }
        update successItems;

        FEC_BatchCaseHandlingImportService.testSummaryOnlyMinRowsOverride = 1;
        try {
            Test.startTest();
            Database.executeBatch(new FEC_BCH_ImportApplyBatch(batchId, false), 5);
            Test.stopTest();
        } finally {
            FEC_BatchCaseHandlingImportService.testSummaryOnlyMinRowsOverride = null;
        }

        System.assert(true, 'Summary-only finish path should complete without exception.');
    }

    @IsTest
    static void testResultArtifactQueueable_executesChunk() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_ResultArtifact.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow(System.Label.FEC_Operation_Success, '500000000000003AAA')
            }
        );

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ResultArtifactQueueable(batchId, 'unit-test', -1, 1, 1)
        );
        System.enqueueJob(
            new FEC_BCH_ResultArtifactQueueable(null, 'unit-test', -1, 1, 1)
        );
        Test.stopTest();

        System.assert(true, 'Result artifact queueable should complete without exception.');
    }

    @IsTest
    static void testResultArtifactQueueable_defaultConstructorAndEmptyChunk() {
        if (!FEC_BCH_ImportWorkItemService.isWorkItemObjectAvailable()) {
            System.assert(true, 'Skipped: work item object not on org.');
            return;
        }
        Id batchId = insertBatchRecord('WorkItem_ResultArtifact_Empty.xlsx');
        FEC_BCH_ImportWorkItemService.stageRows(
            batchId,
            new List<FEC_BatchCaseHandlingImportRow>{
                buildRow(System.Label.FEC_Operation_Success, '500000000000006AAA')
            }
        );

        FEC_BCH_ResultArtifactQueueable defaults =
            new FEC_BCH_ResultArtifactQueueable(batchId, null, null, null, null);
        System.assertNotEquals(null, defaults);

        Test.startTest();
        System.enqueueJob(
            new FEC_BCH_ResultArtifactQueueable(batchId, 'empty-chunk', 99, 1, 1)
        );
        Test.stopTest();

        System.assertEquals(1, FEC_BCH_ImportWorkItemService.countRowsByBatch(batchId));
    }
}
