public without sharing class FEC_BCH_ImportValidateQueueable implements Queueable {

    private final Id batchRecordId;
    private final String inputRowsJson;
    private final String rowsJson;
    private final String validateContextJson;
    private final Boolean cofOrGsr;
    private final Integer nextValidateIndex;

    public FEC_BCH_ImportValidateQueueable(
        Id batchRecordId,
        String inputRowsJson,
        String rowsJson,
        String validateContextJson,
        Boolean cofOrGsr,
        Integer nextValidateIndex
    ) {
        this.batchRecordId = batchRecordId;
        this.inputRowsJson = inputRowsJson;
        this.rowsJson = rowsJson;
        this.validateContextJson = validateContextJson;
        this.cofOrGsr = cofOrGsr == true;
        this.nextValidateIndex = nextValidateIndex == null ? 0 : nextValidateIndex;
    }

    public void execute(QueueableContext context) {
        List<FEC_BatchCaseHandlingImportRow> rows = parseRows(rowsJson);
        FEC_BatchCaseHandlingImportService.ImportValidateChunkContext validateCtx = null;
        try {
            if (
                batchRecordId != null &&
                FEC_BatchCaseHandlingImportService.isBatchImportProcessingExpired(batchRecordId)
            ) {
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    FEC_BatchCaseHandlingImportService.resolveImportProcessingTimeoutReason(),
                    rows
                );
                return;
            }
            if (batchRecordId == null) {
                return;
            }
            List<Object> inputRows = parseInputRows(inputRowsJson);
            if (rows == null || rows.isEmpty()) {
                rows = FEC_BatchCaseHandlingImportService.buildImportRowsFromInputObjects(inputRows);
            }
            if (rows == null || rows.isEmpty()) {
                FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, rows);
                return;
            }
            if (String.isBlank(validateContextJson)) {
                validateCtx = FEC_BatchCaseHandlingImportService.prepareImportValidateChunkContext(rows, cofOrGsr);
            } else {
                validateCtx = FEC_BatchCaseHandlingImportService.deserializeImportValidateChunkContext(
                    validateContextJson
                );
            }
            Integer endIdx = Math.min(
                nextValidateIndex + FEC_BatchCaseHandlingImportService.IMPORT_VALIDATE_MAX_ROWS_PER_CHUNK,
                rows.size()
            );
            FEC_BatchCaseHandlingImportService.validateImportRowsChunk(
                rows,
                validateCtx,
                nextValidateIndex,
                endIdx
            );
            if (endIdx < rows.size()) {
                if (canEnqueueFollowUpJob()) {
                    enqueueFollowUpValidateJob(
                        batchRecordId,
                        inputRowsJson,
                        JSON.serialize(rows),
                        FEC_BatchCaseHandlingImportService.serializeImportValidateChunkContext(validateCtx),
                        cofOrGsr,
                        endIdx
                    );
                    return;
                }
                FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                    batchRecordId,
                    System.Label.FEC_BCH_ImportFailed,
                    rows
                );
                return;
            }
            enqueueApplyJob(batchRecordId, rows, cofOrGsr);
        } catch (Exception ex) {
            FEC_BatchCaseHandlingImportService.failBatchImportRecord(
                batchRecordId,
                ex.getMessage(),
                rows
            );
        }
    }

    private static Boolean canEnqueueFollowUpJob() {
        return Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
    }

    private static void enqueueFollowUpValidateJob(
        Id batchRecordId,
        String inputRowsJson,
        String rowsJson,
        String validateContextJson,
        Boolean cofOrGsr,
        Integer nextValidateIndex
    ) {
        System.enqueueJob(
            new FEC_BCH_ImportValidateQueueable(
                batchRecordId,
                inputRowsJson,
                rowsJson,
                validateContextJson,
                cofOrGsr,
                nextValidateIndex
            )
        );
    }

    private static void enqueueApplyJob(
        Id batchRecordId,
        List<FEC_BatchCaseHandlingImportRow> rows,
        Boolean cofOrGsr
    ) {
        if (FEC_BatchCaseHandlingImportService.hasApplicableImportRows(rows)) {
            System.enqueueJob(
                new FEC_BatchCaseHandlingImportQueueable(
                    batchRecordId,
                    JSON.serialize(rows),
                    null,
                    cofOrGsr,
                    0
                )
            );
            return;
        }
        FEC_BatchCaseHandlingImportService.finalizeBatchImportRecord(batchRecordId, rows);
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

    private static List<Object> parseInputRows(String jsonPayload) {
        if (String.isBlank(jsonPayload)) {
            return new List<Object>();
        }
        return (List<Object>) JSON.deserializeUntyped(jsonPayload);
    }
}
