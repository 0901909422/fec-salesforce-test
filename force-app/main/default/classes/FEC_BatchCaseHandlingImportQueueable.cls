public without sharing class FEC_BatchCaseHandlingImportQueueable implements Queueable {

    // 28/05/2026 15:30 linhdev - production safety: queueable execute chỉ xử lý 1 row
    // để tránh vượt giới hạn enqueue khi FEC_CaseBusinessService.run tự enqueue job theo routing action.
    @TestVisible
    private static final Integer MAX_APPLICABLE_ROWS_PER_EXECUTE = 1;

    private final Id batchRecordId;
    private final String rowsJson;
    // 02/06/2026 16:10 linhdev - giữ state kết quả theo row index giữa các queueable hop để tránh serialize lại full rows
    private final String outcomesJson;
    private final Boolean cofOrGsr;
    private final Integer nextIndex;

    public FEC_BatchCaseHandlingImportQueueable(
        Id batchRecordId,
        String rowsJson,
        String outcomesJson,
        Boolean cofOrGsr,
        Integer nextIndex
    ) {
        this.batchRecordId = batchRecordId;
        this.rowsJson = rowsJson;
        this.outcomesJson = outcomesJson;
        this.cofOrGsr = cofOrGsr == true;
        this.nextIndex = nextIndex == null ? 0 : nextIndex;
    }

    public void execute(QueueableContext context) {
        List<FEC_BatchCaseHandlingImportRow> allRows = parseRows(rowsJson);
        // 02/06/2026 16:10 linhdev - outcome map nhỏ hơn nhiều so với full row payload -> giảm CPU khi chain file lớn
        Map<String, RowOutcome> outcomeByRowIndex = parseOutcomes(outcomesJson);
        try {
            if (
                batchRecordId != null &&
                FEC_BatchCaseHandlingImportService.isBatchImportProcessingExpired(batchRecordId)
            ) {
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    FEC_BatchCaseHandlingImportService.resolveImportProcessingTimeoutReason(),
                    applyOutcomes(allRows, outcomeByRowIndex)
                );
                return;
            }
            if (batchRecordId == null || allRows == null || allRows.isEmpty()) {
                FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(
                    batchRecordId,
                    applyOutcomes(allRows, outcomeByRowIndex)
                );
                return;
            }

            Integer idx = nextIndex;
            Integer applicableRowsInRun = 0;
            List<FEC_BatchCaseHandlingImportRow> rowsToApply = new List<FEC_BatchCaseHandlingImportRow>();
            Map<Integer, FEC_BatchCaseHandlingImportRow> applicableRowByIndex = new Map<Integer, FEC_BatchCaseHandlingImportRow>();
            while (idx < allRows.size()) {
                Integer rowIndex = idx;
                FEC_BatchCaseHandlingImportRow row = allRows[idx];
                idx++;
                if (!FEC_BatchCaseHandlingImportService.shouldApplyImportRow(row)) {
                    continue;
                }
                rowsToApply.add(row);
                applicableRowByIndex.put(rowIndex, row);
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
                // 02/06/2026 16:10 linhdev - chỉ persist status/errors cần thiết cho lần chạy kế tiếp
                for (Integer rowIndex : applicableRowByIndex.keySet()) {
                    FEC_BatchCaseHandlingImportRow processedRow = applicableRowByIndex.get(rowIndex);
                    RowOutcome out = new RowOutcome();
                    out.status = processedRow == null ? null : processedRow.status;
                    out.errors = processedRow == null ? null : processedRow.errors;
                    outcomeByRowIndex.put(String.valueOf(rowIndex), out);
                }
            }

            if (idx < allRows.size()) {
                if (canEnqueueFollowUpJob()) {
                    enqueueFollowUpJob(batchRecordId, rowsJson, outcomeByRowIndex, cofOrGsr, idx);
                    return;
                }
                // 27/05/2026 22:15 linhdev - không còn slot queueable nhưng không còn row applicable thì finalize thay vì fail/timeout
                if (!FEC_BatchCaseHandlingImportService.hasRemainingApplicableImportRows(allRows, idx)) {
                    FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(
                        batchRecordId,
                        applyOutcomes(allRows, outcomeByRowIndex)
                    );
                    return;
                }
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    System.Label.FEC_BCH_ImportFailed,
                    applyOutcomes(allRows, outcomeByRowIndex)
                );
                return;
            }

            FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(
                batchRecordId,
                applyOutcomes(allRows, outcomeByRowIndex)
            );
        } catch (Exception ex) {
            FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                batchRecordId,
                ex.getMessage(),
                applyOutcomes(allRows, outcomeByRowIndex)
            );
        }
    }

    // 27/05/2026 22:15 linhdev - sửa điều kiện chain queueable (trước đó == 0 chặn follow-up job không đúng)
    private static Boolean canEnqueueFollowUpJob() {
        return Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
    }

    private static void enqueueFollowUpJob(
        Id batchRecordId,
        String rowsJson,
        Map<String, RowOutcome> outcomeByRowIndex,
        Boolean cofOrGsr,
        Integer nextIndex
    ) {
        System.enqueueJob(
            new FEC_BatchCaseHandlingImportQueueable(
                batchRecordId,
                rowsJson,
                // 02/06/2026 16:10 linhdev - chain với state nhỏ (outcomes) thay vì serialize lại toàn bộ allRows
                JSON.serialize(outcomeByRowIndex),
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

    private static Map<String, RowOutcome> parseOutcomes(String jsonPayload) {
        if (String.isBlank(jsonPayload)) {
            return new Map<String, RowOutcome>();
        }
        return (Map<String, RowOutcome>) JSON.deserialize(
            jsonPayload,
            Map<String, RowOutcome>.class
        );
    }

    private static List<FEC_BatchCaseHandlingImportRow> applyOutcomes(
        List<FEC_BatchCaseHandlingImportRow> rows,
        Map<String, RowOutcome> outcomeByRowIndex
    ) {
        if (rows == null || rows.isEmpty() || outcomeByRowIndex == null || outcomeByRowIndex.isEmpty()) {
            return rows;
        }
        for (String rowIndexKey : outcomeByRowIndex.keySet()) {
            Integer rowIndex;
            try {
                rowIndex = Integer.valueOf(rowIndexKey);
            } catch (Exception ex) {
                continue;
            }
            if (rowIndex == null || rowIndex < 0 || rowIndex >= rows.size()) {
                continue;
            }
            FEC_BatchCaseHandlingImportRow row = rows[rowIndex];
            RowOutcome out = outcomeByRowIndex.get(rowIndexKey);
            if (row == null || out == null) {
                continue;
            }
            row.status = out.status;
            row.errors = out.errors;
        }
        return rows;
    }

    private class RowOutcome {
        public String status;
        public String errors;
    }
}