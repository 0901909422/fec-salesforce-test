public without sharing class FEC_BCH_ImportApplyBatch implements Database.Batchable<SObject> {

    private final Id batchRecordId;
    private final Boolean cofOrGsr;
    private final Integer applyPass;
    @TestVisible
    private static final Integer MAX_APPLY_RETRY_PASSES = 2;

    public FEC_BCH_ImportApplyBatch(Id batchRecordId, Boolean cofOrGsr) {
        this(batchRecordId, cofOrGsr, 0);
    }

    public FEC_BCH_ImportApplyBatch(Id batchRecordId, Boolean cofOrGsr, Integer applyPass) {
        this.batchRecordId = batchRecordId;
        this.cofOrGsr = cofOrGsr == true;
        this.applyPass = applyPass == null || applyPass < 0 ? 0 : applyPass;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (batchRecordId == null) {
            return Database.getQueryLocator(
                'SELECT Id FROM FEC_BCH_Import_Work_Item__c WHERE Id = null'
            );
        }
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    FEC_Row_Index__c,
                    FEC_Row_Payload__c,
                    FEC_Row_Status__c,
                    FEC_Row_Error__c,
                    FEC_Record_Id__c
                FROM FEC_BCH_Import_Work_Item__c
                WHERE FEC_Batch_Case_Handling__c = :batchRecordId
                AND (
                    FEC_Row_Status__c = null OR
                    FEC_Row_Status__c = 'Pending' OR
                    FEC_Row_Status__c = 'Processing'
                )
                ORDER BY FEC_Row_Index__c ASC
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        List<FEC_BCH_Import_Work_Item__c> workItems = (List<FEC_BCH_Import_Work_Item__c>) scope;
        if (workItems == null || workItems.isEmpty()) {
            return;
        }
        List<FEC_BatchCaseHandlingImportRow> rows = FEC_BCH_ImportWorkItemService.deserializeRows(workItems);
        try {
            FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(rows, cofOrGsr);
            FEC_BCH_ImportWorkItemService.saveScopeOutcomes(workItems, rows);
        } catch (Exception ex) {
            FEC_BCH_ImportWorkItemService.markScopeFailed(workItems, rows, ex.getMessage());
        }
    }

    public void finish(Database.BatchableContext context) {
        if (batchRecordId == null) {
            return;
        }
        Integer totalCount = FEC_BCH_ImportWorkItemService.countRowsByBatch(batchRecordId);
        Integer successCount = FEC_BCH_ImportWorkItemService.countRowsByStatus(batchRecordId, 'Success');
        Integer failedCount = FEC_BCH_ImportWorkItemService.countRowsByStatus(batchRecordId, 'Failed');
        Integer pendingCount = FEC_BCH_ImportWorkItemService.countRowsByStatus(batchRecordId, 'Pending');
        Integer processingCount = FEC_BCH_ImportWorkItemService.countRowsByStatus(batchRecordId, 'Processing');
        Integer unresolvedCount = (pendingCount == null ? 0 : pendingCount) + (processingCount == null ? 0 : processingCount);
        if (unresolvedCount > 0 && applyPass < MAX_APPLY_RETRY_PASSES) {
            Database.executeBatch(
                new FEC_BCH_ImportApplyBatch(batchRecordId, cofOrGsr, applyPass + 1),
                FEC_BatchCaseHandlingImportService.IMPORT_BATCH_APPLY_SCOPE_SIZE
            );
            return;
        }
        if (unresolvedCount > 0) {
            failedCount += unresolvedCount;
        }
        String firstFailureReason = FEC_BCH_ImportWorkItemService.findFirstFailureReason(batchRecordId);
        if (String.isBlank(firstFailureReason) && unresolvedCount > 0) {
            firstFailureReason = FEC_BatchCaseHandlingImportService.resolveImportQueueLimitExceededReason();
        }
        if (FEC_BatchCaseHandlingImportService.shouldFinalizeImportWithSummaryOnly(totalCount)) {
            // 25/06/2026 linhdev- volume lớn: chốt batch theo summary để tránh vượt heap ở bước load full rows.
            FEC_BatchCaseHandlingImportService.finalizeBatchImportRecordFromSummary(
                batchRecordId,
                totalCount,
                successCount,
                failedCount,
                firstFailureReason
            );
            // 25/06/2026 linhdev- xuất full result theo nhiều phần bằng queueable chain để tránh heap/CPU blow ở Batch.finish.
            FEC_BatchCaseHandlingImportService.enqueueChunkedResultArtifactFromWorkItems(
                batchRecordId,
                firstFailureReason,
                FEC_BatchCaseHandlingImportService.IMPORT_RESULT_ARTIFACT_QUEUEABLE_CHUNK_SIZE
            );
            return;
        }
        List<FEC_BatchCaseHandlingImportRow> rows =
            FEC_BCH_ImportWorkItemService.loadRowsByBatch(batchRecordId);
        FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, rows);
    }
}
