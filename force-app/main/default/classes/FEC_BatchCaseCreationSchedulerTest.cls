@IsTest
private class FEC_BatchCaseCreationSchedulerTest {
  @IsTest
  static void schedulerExecutesBatch() {
    Test.startTest();
    new FEC_BatchCaseCreationScheduler().execute(null);
    Test.stopTest();
  }

  @IsTest
  static void attachAndLoadPendingPayload() {
    FEC_Batch_Case_Creation__c batchRow = new FEC_Batch_Case_Creation__c(
      FEC_File_Name__c = 'batch_test.xlsx',
      FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS,
      FEC_Total_Records__c = 1
    );
    insert batchRow;

    List<Object> rows = new List<Object>{
      new Map<String, Object>{
        'layout' => 'simple',
        'contractNumber' => 'C-001'
      }
    };
    FEC_BatchCaseCreationPendingService.attachPendingImportPayload(
      batchRow.Id,
      'Welcome Call',
      JSON.serialize(rows)
    );

    FEC_BatchCaseCreationPendingService.ImportPayload payload = FEC_BatchCaseCreationPendingService.loadPendingImportPayload(
      batchRow.Id
    );
    System.assertEquals('Welcome Call', payload.templateName);
    System.assertEquals(1, payload.rows.size());
  }

  @IsTest
  static void markBatchImportSystemFailure_setsFailure() {
    FEC_Batch_Case_Creation__c batchRow = new FEC_Batch_Case_Creation__c(
      FEC_File_Name__c = 'batch_test.xlsx',
      FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
    );
    insert batchRow;

    FEC_BatchCaseCreationController.markBatchImportSystemFailure(batchRow.Id, 'System error');

    batchRow = [
      SELECT FEC_Status__c, FEC_Failure_Reason__c
      FROM FEC_Batch_Case_Creation__c
      WHERE Id = :batchRow.Id
    ];
    System.assertEquals('Failure', batchRow.FEC_Status__c);
    System.assertEquals('System error', batchRow.FEC_Failure_Reason__c);
  }

  @IsTest
  static void processPendingWithoutPayload_marksFailure() {
    FEC_Batch_Case_Creation__c batchRow = new FEC_Batch_Case_Creation__c(
      FEC_File_Name__c = 'batch_test.xlsx',
      FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS
    );
    insert batchRow;

    Test.startTest();
    FEC_BatchCaseCreationController.processPendingBatchImport(batchRow.Id);
    Test.stopTest();

    batchRow = [
      SELECT FEC_Status__c
      FROM FEC_Batch_Case_Creation__c
      WHERE Id = :batchRow.Id
    ];
    System.assertEquals('Failure', batchRow.FEC_Status__c);
  }
}
