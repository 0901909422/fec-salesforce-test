/**
 * Processes Uploaded batch imports one record per Queueable execution (avoids SOQL 101).
 */
public without sharing class FEC_BatchCaseChainQueueable implements Queueable {
  private final List<Id> batchRecordIds;
  private final Integer startIndex;

  public FEC_BatchCaseChainQueueable(List<Id> batchRecordIds) {
    this(batchRecordIds, 0);
  }

  private FEC_BatchCaseChainQueueable(List<Id> batchRecordIds, Integer startIndex) {
    this.batchRecordIds = batchRecordIds == null
      ? new List<Id>()
      : new List<Id>(batchRecordIds);
    this.startIndex = startIndex == null ? 0 : startIndex;
  }

  public void execute(QueueableContext context) {
    if (batchRecordIds.isEmpty() || startIndex >= batchRecordIds.size()) {
      return;
    }
    FEC_BatchCaseCreationController.processPendingBatchImport(
      batchRecordIds[startIndex]
    );
    Integer nextIndex = startIndex + 1;
    if (
      nextIndex < batchRecordIds.size() &&
      Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()
    ) {
      System.enqueueJob(
        new FEC_BatchCaseChainQueueable(batchRecordIds, nextIndex)
      );
    }
  }
}
