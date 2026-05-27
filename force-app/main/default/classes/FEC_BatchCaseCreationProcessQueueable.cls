/**
 * Processes one FEC_Batch_Case_Creation__c record (Uploaded → cases) asynchronously.
 */
public without sharing class FEC_BatchCaseCreationProcessQueueable implements Queueable {
  private final Id batchRecordId;

  public FEC_BatchCaseCreationProcessQueueable(Id batchRecordId) {
    this.batchRecordId = batchRecordId;
  }

  public void execute(QueueableContext context) {
    if (batchRecordId == null) {
      return;
    }
    FEC_BatchCaseCreationController.processPendingBatchImport(batchRecordId);
  }
}
