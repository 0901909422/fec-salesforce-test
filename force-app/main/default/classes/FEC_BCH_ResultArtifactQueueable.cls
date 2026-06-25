public without sharing class FEC_BCH_ResultArtifactQueueable implements Queueable {

    private final Id batchRecordId;
    private final String batchFailureReason;
    private final Integer afterRowIndex;
    private final Integer partNumber;
    private final Integer chunkSize;

    public FEC_BCH_ResultArtifactQueueable(
        Id batchRecordId,
        String batchFailureReason,
        Integer afterRowIndex,
        Integer partNumber,
        Integer chunkSize
    ) {
        this.batchRecordId = batchRecordId;
        this.batchFailureReason = batchFailureReason;
        this.afterRowIndex = afterRowIndex == null ? -1 : afterRowIndex;
        this.partNumber = partNumber == null || partNumber < 1 ? 1 : partNumber;
        this.chunkSize = chunkSize == null || chunkSize < 1
            ? FEC_BatchCaseHandlingImportService.IMPORT_RESULT_ARTIFACT_QUEUEABLE_CHUNK_SIZE
            : chunkSize;
    }

    public void execute(QueueableContext context) {
        if (batchRecordId == null) {
            return;
        }
        FEC_BCH_ImportWorkItemService.WorkItemChunkResult chunk =
            FEC_BCH_ImportWorkItemService.loadRowsByBatchChunk(
                batchRecordId,
                afterRowIndex,
                chunkSize
            );
        if (chunk == null || chunk.rows == null || chunk.rows.isEmpty()) {
            return;
        }
        FEC_BatchCaseHandlingImportService.persistBatchResultArtifactWithFileName(
            batchRecordId,
            chunk.rows,
            batchFailureReason,
            FEC_BatchCaseHandlingImportService.resolveChunkResultFileName(
                batchRecordId,
                partNumber
            )
        );
        if (
            chunk.hasMore == true &&
            chunk.lastRowIndex != null &&
            chunk.lastRowIndex > afterRowIndex
        ) {
            System.enqueueJob(
                new FEC_BCH_ResultArtifactQueueable(
                    batchRecordId,
                    batchFailureReason,
                    chunk.lastRowIndex,
                    partNumber + 1,
                    chunkSize
                )
            );
        }
    }
}
