/**
 * Nightly batch: processes FEC_Batch_Case_Creation__c records in Uploaded status.
 */
public without sharing class FEC_BatchCaseCreationProcessBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM FEC_Batch_Case_Creation__c
        WHERE FEC_Status__c = :FEC_ConstantCommon.UPLOADED_STATUS
        ORDER BY CreatedDate ASC
      ]
    );
  }

  public void execute(Database.BatchableContext context, List<FEC_Batch_Case_Creation__c> scope) {
    for (FEC_Batch_Case_Creation__c batchRow : scope) {
      try {
        FEC_BatchCaseCreationController.processPendingBatchImport(batchRow.Id);
      } catch (Exception ex) {
        FEC_BatchCaseCreationController.markBatchImportSystemFailure(
          batchRow.Id,
          ex.getMessage()
        );
      }
    }
  }

  public void finish(Database.BatchableContext context) {
  }
}
