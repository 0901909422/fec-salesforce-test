public without sharing class FEC_BatchCaseHandlingImportQueueable implements Queueable {

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
            while (idx < allRows.size()) {
                FEC_BatchCaseHandlingImportRow row = allRows[idx];
                idx++;
                if (!FEC_BatchCaseHandlingImportService.shouldApplyImportRow(row)) {
                    continue;
                }
                List<FEC_BatchCaseHandlingImportRow> oneRow = new List<FEC_BatchCaseHandlingImportRow>{ row };
                FEC_BatchCaseHandlingImportService.applyCaseHandlingUpdates(oneRow, cofOrGsr);
                break;
            }

            if (idx < allRows.size()) {
                System.enqueueJob(
                    new FEC_BatchCaseHandlingImportQueueable(
                        batchRecordId,
                        JSON.serialize(allRows),
                        cofOrGsr,
                        idx
                    )
                );
                return;
            }

            FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, allRows);
        } catch (Exception ex) {
            FEC_BatchCaseHandlingImportService.failBatchImportRecord(batchRecordId, ex.getMessage(), allRows);
        }
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
