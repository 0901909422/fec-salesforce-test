@IsTest
private class FEC_CaseStatusHistoryServiceTest {
  @IsTest
  static void appendsStatusHistoryWithSpaceSeparatedNumbering() {
    Case c = new Case(Subject = 'Status history insert');
    insert c;

    Case insertedCase = [
      SELECT Id, Status, FEC_Case_Status_History__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      String.isNotBlank(insertedCase.FEC_Case_Status_History__c) &&
      insertedCase.FEC_Case_Status_History__c.startsWith('#1:'),
      'Khi tao Case phai co #1 trong history'
    );

    insertedCase.Status = 'Working';
    update insertedCase;

    Case updatedCase = [
      SELECT FEC_Case_Status_History__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      updatedCase.FEC_Case_Status_History__c.contains(' #2: Working'),
      'Khi doi status phai append #2 va cach nhau bang dau cach'
    );
  }

  @IsTest
  static void doesNotAppendWhenStatusUnchanged() {
    Case c = new Case(Subject = 'Status history unchanged');
    insert c;

    Case currentCase = [
      SELECT Id, Status, FEC_Case_Status_History__c
      FROM Case
      WHERE Id = :c.Id
    ];
    String historyBefore = currentCase.FEC_Case_Status_History__c;

    currentCase.Subject = 'Only subject changed';
    update currentCase;

    Case reloaded = [
      SELECT FEC_Case_Status_History__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assertEquals(
      historyBefore,
      reloaded.FEC_Case_Status_History__c,
      'Khong doi status thi khong duoc append them history'
    );
  }
}
