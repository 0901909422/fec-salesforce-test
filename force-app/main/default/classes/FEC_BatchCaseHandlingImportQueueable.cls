public without sharing class FEC_BatchCaseHandlingImportQueueable implements Queueable {

    // 28/05/2026 15:30 linhdev - production safety: queueable execute chỉ xử lý 1 row
    // để tránh vượt giới hạn enqueue khi FEC_CaseBusinessService.run tự enqueue job theo routing action.
    @TestVisible
    private static final Integer MAX_APPLICABLE_ROWS_PER_EXECUTE = 1;

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
            List<FEC_BatchCaseHandlingImportRow> rowsToApply = new List<FEC_BatchCaseHandlingImportRow>();
            while (idx < allRows.size()) {
                FEC_BatchCaseHandlingImportRow row = allRows[idx];
                idx++;
                if (!FEC_BatchCaseHandlingImportService.shouldApplyImportRow(row)) {
                    continue;
                }
                rowsToApply.add(row);
                applicableRowsInRun++;

                if (idx >= allRows.size()) {
                    break;
                }
                if (shouldYieldSameExecute() || applicableRowsInRun >= MAX_APPLICABLE_ROWS_PER_EXECUTE) {
                    break;
                }
            }

            if (!rowsToApply.isEmpty()) {
                // 28/05/2026 10:53 linhdev - xử lý import theo lô + guard SOQL để tránh Too many SOQL queries: 101
                FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(rowsToApply, cofOrGsr);
            }

            if (idx < allRows.size()) {
                if (canEnqueueFollowUpJob()) {
                    enqueueFollowUpJob(batchRecordId, allRows, cofOrGsr, idx);
                    return;
                }
                // 27/05/2026 22:15 linhdev - không còn slot queueable nhưng không còn row applicable thì finalize thay vì fail/timeout
                if (!FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(allRows, idx)) {
                    FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, allRows);
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

    // 27/05/2026 22:15 linhdev - sửa điều kiện chain queueable (trước đó == 0 chặn follow-up job không đúng)
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

    // 28/05/2026 11:20 linhdev - dùng ngưỡng governor chung với ImportService (72%)
    private static Boolean shouldYieldSameExecute() {
        return FEC_BatchCaseHandlingImportService.shouldYieldImportGovernorLimits();
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