@IsTest
private class FEC_CaseStatusHistoryServiceTest {
  @IsTest
  static void appendsStatusHistoryWithSpaceSeparatedNumbering() {
    Case c = new Case(Subject = 'Status history insert');
    insert c;

    Case insertedCase = [
      SELECT Id, Status, FEC_Case_Status_History__c, FEC_Case_Status_History_1__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      String.isNotBlank(insertedCase.FEC_Case_Status_History__c) &&
      insertedCase.FEC_Case_Status_History__c.startsWith('#1:'),
      'Khi tao Case phai co #1 trong history'
    );
    System.assert(
      String.isNotBlank(insertedCase.FEC_Case_Status_History_1__c) &&
      insertedCase.FEC_Case_Status_History_1__c.startsWith('#1:'),
      'Khi tao Case, bucket 1 phai co #1'
    );

    insertedCase.Status = 'Working';
    update insertedCase;

    Case updatedCase = [
      SELECT FEC_Case_Status_History__c, FEC_Case_Status_History_1__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      updatedCase.FEC_Case_Status_History__c.contains(' #2: Working'),
      'Khi doi status phai append #2 va cach nhau bang dau cach'
    );
    System.assert(
      updatedCase.FEC_Case_Status_History_1__c.contains('#2:'),
      'Khi chua co remark, status #2 van nam o bucket 1'
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

  @IsTest
  static void statusHistoryDistributedByRemarkBuckets() {
    FEC_CaseRemarksRollupService.BucketPack pack = new FEC_CaseRemarksRollupService.BucketPack();
    pack.count1 = 2;
    pack.count2 = 1;
    pack.count3 = 0;

    String fullHistory = '#1: New #2: Open #3: Working';
    FEC_CaseRemarksRollupService.StatusHistoryBuckets buckets =
      FEC_CaseRemarksRollupService.distributeStatusHistory(fullHistory, pack);

    System.assert(
      buckets.part1 != null && buckets.part1.contains('#1:') && buckets.part1.contains('#2:'),
      'Bucket 1 phai chua status #1 va #2 tuong ung voi 2 remark dau'
    );
    System.assert(
      buckets.part2 != null && buckets.part2.contains('#3:'),
      'Bucket 2 phai chua status #3 tuong ung voi remark thu 3'
    );
    System.assertEquals(null, buckets.part3, 'Bucket 3 phai rong khi khong co remark o bucket 3');
  }

  @IsTest
  static void parseStatusHistoryEntriesFromCombinedField() {
    String history = '#1: New #2: Open #3: Working';
    List<String> entries = FEC_CaseRemarksRollupService.parseStatusHistoryEntries(history);
    System.assertEquals(3, entries.size(), 'Phai parse duoc 3 entries');
    System.assert(entries[0].startsWith('#1:'), 'Entry dau tien phai la #1');
    System.assert(entries[2].startsWith('#3:'), 'Entry cuoi phai la #3');
  }
}
