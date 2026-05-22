public without sharing class FEC_BatchCaseHandlingImportQueueable implements Queueable {

    @TestVisible
    private static final Integer MAX_APPLICABLE_ROWS_PER_EXECUTE = 40;

    private final Id batchRecordId;
    private final String rowsJson;
    private final Boolean cofOrGsr;
    private final Integer nextIndex;

    public FEC_BatchCaseHandlingImportQueueable(
        Id batchRecordId,
        String rowsJson,
        Boolean cofOrGsr,
        Integer nextIndex
    ) {
        this.batchRecordId = batchRecordId;
        this.rowsJson = rowsJson;
        this.cofOrGsr = cofOrGsr == true;
        this.nextIndex = nextIndex == null ? 0 : nextIndex;
    }

    public void execute(QueueableContext context) {
        List<FEC_BatchCaseHandlingImportRow> allRows = parseRows(rowsJson);
        try {
            if (
                batchRecordId != null &&
                FEC_BatchCaseHandlingImportService.isBatchImportProcessingExpired(batchRecordId)
            ) {
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    FEC_BatchCaseHandlingImportService.resolveImportProcessingTimeoutReason(),
                    allRows
                );
                return;
            }
            if (batchRecordId == null || allRows == null || allRows.isEmpty()) {
                FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, allRows);
                return;
            }

            Integer idx = nextIndex;
            Integer applicableRowsInRun = 0;
            while (idx < allRows.size()) {
                FEC_BatchCaseHandlingImportRow row = allRows[idx];
                idx++;
                if (!FEC_BatchCaseHandlingImportService.shouldApplyImportRow(row)) {
                    continue;
                }
                List<FEC_BatchCaseHandlingImportRow> oneRow = new List<FEC_BatchCaseHandlingImportRow>{ row };
                FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(oneRow, cofOrGsr);
                applicableRowsInRun++;

                if (idx >= allRows.size()) {
                    break;
                }
                if (shouldYieldSameExecute() || applicableRowsInRun >= MAX_APPLICABLE_ROWS_PER_EXECUTE) {
                    break;
                }
                if (canEnqueueFollowUpJob()) {
                    enqueueFollowUpJob(batchRecordId, allRows, cofOrGsr, idx);
                    return;
                }
            }

            if (idx < allRows.size()) {
                if (canEnqueueFollowUpJob()) {
                    enqueueFollowUpJob(batchRecordId, allRows, cofOrGsr, idx);
                    return;
                }
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    System.Label.FEC_BCH_ImportFailed,
                    allRows
                );
                return;
            }

            FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, allRows);
        } catch (Exception ex) {
            FEC_BatchCaseHandlingImportService.failBatchImportRecord(batchRecordId, ex.getMessage(), allRows);
        }
    }

    private static Boolean canEnqueueFollowUpJob() {
        return Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
    }

    private static void enqueueFollowUpJob(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> allRows,
        Boolean cofOrGsr,
        Integer nextIndex
    ) {
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(
                batchRecordId,
                JSON.serialize(allRows),
                cofOrGsr,
                nextIndex
            )
        );
    }

    private static Boolean shouldYieldSameExecute() {
        return Limits.getCpuTime() >= (Limits.getLimitCpuTime() * 85 / 100)
            || Limits.getDMLRows() >= (Limits.getLimitDMLRows() * 85 / 100)
            || Limits.getHeapSize() >= (Limits.getLimitHeapSize() * 85 / 100);
    }

    private static List<FEC_BatchCaseHandlingImportRow> parseRows(String jsonPayload) {
        if (String.isBlank(jsonPayload)) {
            return new List<FEC_BatchCaseHandlingImportRow>();
        }
        return (List<FEC_BatchCaseHandlingImportRow>) JSON.deserialize(
            jsonPayload,
            List<FEC_BatchCaseHandlingImportRow>.class
        );
    }
}
