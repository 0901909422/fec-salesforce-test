@IsTest
private class FEC_BatchCaseHandlingImportQueueableTest {

    // 24/06/2026 phong - queueable apply 1 row/transaction (resolve + resolveAllAssignments tốn SOQL)
    @IsTest
    static void importApplyChunkSize_queueableUsesConfiguredRowsPerExecute() {
        System.assertEquals(
            1,
            FEC_BatchCaseHandlingImportQueueable.MAX_APPLICABLE_ROWS_PER_EXECUTE
        );
        System.assertEquals(
            1,
            FEC_BatchCaseHandlingImportService.IMPORT_QUEUEABLE_MAX_ROWS_PER_EXECUTE
        );
        System.assertEquals(
            5,
            FEC_BatchCaseHandlingImportService.IMPORT_APPLY_MAX_ROWS_PER_CHUNK
        );
        System.assertEquals(
            5000,
            FEC_BatchCaseHandlingImportService.IMPORT_ASYNC_VALIDATE_MIN_ROWS
        );
        System.assertEquals(
            400,
            FEC_BatchCaseHandlingImportService.IMPORT_VALIDATE_MAX_ROWS_PER_CHUNK
        );
    }

    @IsTest
    static void shouldValidateImportAsynchronously_thresholdAt5000Rows() {
        System.assertEquals(false, FEC_BatchCaseHandlingImportService.shouldValidateImportAsynchronously(5000));
        System.assertEquals(true, FEC_BatchCaseHandlingImportService.shouldValidateImportAsynchronously(5001));
    }

    @IsTest
    static void validateImportRowsChunk_duplicateCaseDetectedAcrossChunks() {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildValidateRow('CASE-DUP-1', 'Resolve'),
            buildValidateRow('CASE-DUP-1', 'Resolve')
        };
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext ctx =
            new FEC_BatchCaseHandlingImportService.ImportValidateChunkContext();
        ctx.cofOrGsr = false;
        ctx.caseBySearch = new Map<String, Case>();
        ctx.businessProcessCodeByCaseId = new Map<Id, String>();
        ctx.assignmentByName = new Map<String, FEC_Assignment__c>();
        ctx.assignmentByRecordId = new Map<Id, FEC_Assignment__c>();
        ctx.configuredLabelsByStage = new Map<Id, Set<String>>();
        ctx.picklistValueByNormByField = new Map<String, Map<String, String>>();
        ctx.currentUserId = UserInfo.getUserId();
        ctx.currentUserGroup = null;
        ctx.currentUserQueueIds = new Set<Id>();
        ctx.seenCaseSearch = new Set<String>();
        ctx.routingSignatureByCaseSearch = new Map<String, String>();
        FEC_BatchCaseHandlingImportService.validateImportRowsChunk(rows, ctx, 0, 1);
        FEC_BatchCaseHandlingImportService.validateImportRowsChunk(rows, ctx, 1, 2);
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[1].status
        );
        System.assert(
            rows[1].errors != null &&
            rows[1].errors.contains(System.Label.FEC_Batch_Case_Handling_Import_Err_Duplicate_Case_Id),
            'Chunk 2 phải báo duplicate Case ID từ state chunk 1'
        );
    }

    @IsTest
    static void serializeImportValidateChunkContext_roundTripPreservesSeenCaseSearch() {
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext ctx =
            new FEC_BatchCaseHandlingImportService.ImportValidateChunkContext();
        ctx.cofOrGsr = false;
        ctx.currentUserGroup = 'OM';
        ctx.seenCaseSearch = new Set<String>{ 'CASE-RT-1' };
        ctx.routingSignatureByCaseSearch = new Map<String, String>{ 'CASE-RT-1' => 'resolve' };
        ctx.caseBySearch = new Map<String, Case>();
        ctx.businessProcessCodeByCaseId = new Map<Id, String>();
        ctx.assignmentByName = new Map<String, FEC_Assignment__c>();
        ctx.assignmentByRecordId = new Map<Id, FEC_Assignment__c>();
        ctx.configuredLabelsByStage = new Map<Id, Set<String>>();
        ctx.currentUserQueueIds = new Set<Id>();
        String payload = FEC_BatchCaseHandlingImportService.serializeImportValidateChunkContext(ctx);
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext restored =
            FEC_BatchCaseHandlingImportService.deserializeImportValidateChunkContext(payload);
        System.assertEquals(true, restored.cofOrGsr == false);
        System.assertEquals(true, restored.seenCaseSearch.contains('CASE-RT-1'));
        System.assertEquals('resolve', restored.routingSignatureByCaseSearch.get('CASE-RT-1'));
    }

    // 08/06/2026 linhdev - mô phỏng file import lớn: validate sync không vượt SOQL 101
    @IsTest
    static void validateCaseHandlingImportRows_largeVolume_staysUnderSoqlLimit() {
        List<Object> inputRows = buildSimulatedImportInputRows(3500);
        Test.startTest();
        List<FEC_BatchCaseHandlingImportRow> results =
            FEC_BatchCaseHandlingImportService.validateCaseHandlingImportRows(inputRows, false);
        Test.stopTest();
        System.assertEquals(3500, results.size(), 'Phải validate đủ số dòng import');
        System.assert(
            Limits.getQueries() < Limits.getLimitQueries(),
            'SOQL sau validate 3500 row: ' + Limits.getQueries()
        );
        System.assert(
            Limits.getQueries() < 101,
            'Không được vượt SOQL 101 khi validate file lớn. Actual: ' + Limits.getQueries()
        );
    }

    // 08/06/2026 linhdev - mô phỏng async validate chunk (>5000 row) từng hop dưới SOQL 101
    @IsTest
    static void validateImportRowsChunk_asyncVolume_eachChunkStaysUnderSoqlLimit() {
        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BatchCaseHandlingImportService.buildImportRowsFromInputObjects(
                buildSimulatedImportInputRows(5200)
            );
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext ctx =
            FEC_BatchCaseHandlingImportService.prepareImportValidateChunkContext(rows, false);
        Integer chunkSize = FEC_BatchCaseHandlingImportService.IMPORT_VALIDATE_MAX_ROWS_PER_CHUNK;
        Integer maxQueriesUsedInChunk = 0;
        Test.startTest();
        for (Integer startIdx = 0; startIdx < rows.size(); startIdx += chunkSize) {
            Integer queriesAtChunkStart = Limits.getQueries();
            Integer endIdx = Math.min(startIdx + chunkSize, rows.size());
            FEC_BatchCaseHandlingImportService.validateImportRowsChunk(rows, ctx, startIdx, endIdx);
            Integer queriesInChunk = Limits.getQueries() - queriesAtChunkStart;
            if (queriesInChunk > maxQueriesUsedInChunk) {
                maxQueriesUsedInChunk = queriesInChunk;
            }
        }
        Test.stopTest();
        System.assertEquals(5200, rows.size());
        System.assert(
            maxQueriesUsedInChunk < 101,
            'Mỗi validate chunk phải dưới SOQL 101. Max chunk SOQL: ' + maxQueriesUsedInChunk
        );
        System.assert(
            Limits.getQueries() < 101,
            'Tổng SOQL validate 5200 row theo chunk: ' + Limits.getQueries()
        );
    }

    private static List<Object> buildSimulatedImportInputRows(Integer rowCount) {
        List<Object> inputRows = new List<Object>();
        for (Integer idx = 0; idx < rowCount; idx++) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('caseidsearch', 'SIM-BCH-LARGE-' + String.valueOf(idx));
            row.put('routingaction', 'Resolve');
            inputRows.add(row);
        }
        return inputRows;
    }

    @IsTest
    static void shouldYieldImportGovernorLimits_falseAtStartOfTest() {
        System.assertEquals(false, FEC_BatchCaseHandlingImportService.shouldYieldImportGovernorLimits());
    }

    // 02/06/2026 15:45 linhdev - hardening: guard governor phải bật khi query tiến gần ngưỡng an toàn import
    @IsTest
    static void shouldYieldImportGovernorLimits_trueNearQueryThreshold() {
        for (Integer idx = 0; idx < 75; idx++) {
            User probeUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        }
        System.assertEquals(true, FEC_BatchCaseHandlingImportService.shouldYieldImportGovernorLimits());
    }

    // 28/05/2026 15:24 linhdev - production safety: import luôn qua queueable (không sync)
    @IsTest
    static void shouldProcessImportSynchronously_falseEvenForSingleApplicableRow() {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildApplicableRow('500000000000000AAA')
        };
        System.assertEquals(1, FEC_BatchCaseHandlingImportService.countApplicableImportRows(rows));
        System.assertEquals(false, FEC_BatchCaseHandlingImportService.shouldProcessImportSynchronously(rows));
    }

    @IsTest
    static void shouldProcessImportSynchronously_falseWhenExceedsSyncLimit() {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();
        for (Integer idx = 0; idx < 6; idx++) {
            rows.add(buildApplicableRow(String.valueOf(500000000000000L + idx)));
        }
        System.assertEquals(6, FEC_BatchCaseHandlingImportService.countApplicableImportRows(rows));
        System.assertEquals(false, FEC_BatchCaseHandlingImportService.shouldProcessImportSynchronously(rows));
    }

    @IsTest
    static void hasRemainingApplicableImportRows_skipsFailedRows() {
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildFailedRow(),
            buildFailedRow(),
            buildApplicableRow('500000000000000AAA')
        };
        System.assertEquals(true, FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, 0));
        System.assertEquals(true, FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, 2));
        System.assertEquals(false, FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(rows, 3));
    }

    @IsTest
    static void queueableFinalizesWhenNoApplicableRowsRemain() {
        Id batchId = insertProcessingBatch('CardReplacementSyncTest.xlsx');
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildFailedRow(),
            buildFailedRow()
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

        SObject batchRow = queryBatch(batchId);
        System.assertNotEquals('Processing', String.valueOf(batchRow.get('FEC_Status__c')));
    }

    @IsTest
    static void processApplicableImportRowsSyncFinalizesBatchWithoutProcessingStatus() {
        Id batchId = insertProcessingBatch('CardReplacementSyncApply.xlsx');
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildApplicableRow('500000000000000AAA')
        };

        Test.startTest();
        FEC_BatchCaseHandlingImportService.processApplicableImportRowsSync(batchId, rows, false);
        Test.stopTest();

        SObject batchRow = queryBatch(batchId);
        System.assertNotEquals('Processing', String.valueOf(batchRow.get('FEC_Status__c')));
        System.assertEquals(
            System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed,
            rows[0].status
        );
    }

    @IsTest
    static void failBatchImportRecord_marksProcessedWhenAtLeastOneRowSuccess() {
        User admin = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        FEC_TestDataFactory.assignPermissionSets(admin.Id, new List<String>{ 'FEC_Batch_Case_Handling' });

        Id batchId = insertProcessingBatch('CardReplacementPartialSuccess.xlsx');
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>{
            buildFailedRow(),
            buildApplicableRow('500000000000001AAA')
        };
        rows[1].status = System.Label.FEC_Operation_Success;

        System.runAs(admin) {
            Test.startTest();
            FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                batchId,
                System.Label.FEC_BCH_ImportFailed,
                rows
            );
            Test.stopTest();

            SObject batchRow = queryBatch(batchId);
            System.assertEquals('Processed', String.valueOf(batchRow.get('FEC_Status__c')));
            System.assertEquals(1, Integer.valueOf(String.valueOf(batchRow.get('FEC_Total_Success_Records__c'))));
            System.assertEquals(1, Integer.valueOf(String.valueOf(batchRow.get('FEC_Total_Failed_Records__c'))));
        }
    }

    // 02/06/2026 15:45 linhdev - hardening: queueable import nhiều dòng phải tự finalize, không treo Processing
    @IsTest
    static void queueableLargeApplicableRows_finishesWithoutProcessingStuck() {
        Id batchId = insertProcessingBatch('CardReplacementLargeImport.xlsx');
        List<FEC_BatchCaseHandlingImportRow> rows = new List<FEC_BatchCaseHandlingImportRow>();
        for (Integer idx = 0; idx < 20; idx++) {
            rows.add(buildApplicableRow(String.valueOf(500000000000000L + idx) + 'AAA'));
        }

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

        SObject batchRow = queryBatch(batchId);
        System.assertNotEquals('Processing', String.valueOf(batchRow.get('FEC_Status__c')));
    }

    private static FEC_BatchCaseHandlingImportRow buildValidateRow(String caseIdSearch, String routingAction) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.caseIdSearch = caseIdSearch;
        row.routingAction = routingAction;
        row.status = System.Label.FEC_Batch_Case_Handling_Success;
        row.errors = FEC_ConstantCommon.STR_EMPTY;
        return row;
    }

    private static FEC_BatchCaseHandlingImportRow buildApplicableRow(String recordId) {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.recordId = recordId;
        row.routingAction = 'Resolve';
        row.inputtedRemarks = 'Bulk import test remark';
        row.status = 'Validated';
        return row;
    }

    private static FEC_BatchCaseHandlingImportRow buildFailedRow() {
        FEC_BatchCaseHandlingImportRow row = new FEC_BatchCaseHandlingImportRow();
        row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        row.errors = 'Validation failed';
        return row;
    }

    private static Id insertProcessingBatch(String fileName) {
        Schema.SObjectType batchType = Schema.getGlobalDescribe().get('FEC_Batch_Case_Handling__c');
        System.assertNotEquals(null, batchType, 'FEC_Batch_Case_Handling__c must exist in org');
        SObject batchRow = batchType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = batchType.getDescribe().fields.getMap();
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_File_Name__c' }, fileName);
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Status__c' }, 'Processing');
        FEC_BatchCaseHandlingSObjectUtil.putIfFieldExists(fieldMap, batchRow, new List<String>{ 'FEC_Total_Records__c', 'FEC_Total_Records_Count__c' }, 1);
        insert batchRow;
        return (Id) batchRow.get('Id');
    }

    private static SObject queryBatch(Id batchId) {
        return [
            SELECT Id, FEC_Status__c, FEC_Total_Failed_Records__c, FEC_Total_Success_Records__c
            FROM FEC_Batch_Case_Handling__c
            WHERE Id = :batchId
            LIMIT 1
        ];
    }
}