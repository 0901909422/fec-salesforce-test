@isTest
private class FEC_CaseRemarksRollupServiceTest {
  private static String strLen(Integer n) {
    String alpha = '0123456789';
    String out = '';
    while (out.length() < n) {
      out += alpha;
    }
    return out.substring(0, n);
  }

  @isTest
  static void rollup_matchesBaFourRemarkExample() {
    Case c = new Case(Subject = 'Rollup BA example');
    insert c;

    List<FEC_Case_Remarks__c> rows = new List<FEC_Case_Remarks__c>{
      new FEC_Case_Remarks__c(
        FEC_Case__c = c.Id,
        FEC_Case_Remarks__c = strLen(50)
      ),
      new FEC_Case_Remarks__c(
        FEC_Case__c = c.Id,
        FEC_Case_Remarks__c = strLen(100)
      ),
      new FEC_Case_Remarks__c(
        FEC_Case__c = c.Id,
        FEC_Case_Remarks__c = strLen(50)
      ),
      new FEC_Case_Remarks__c(
        FEC_Case__c = c.Id,
        FEC_Case_Remarks__c = strLen(60)
      )
    };
    insert rows;

    Case updated = [
      SELECT FEC_Case_Remarks_1__c, FEC_Case_Remarks_2__c, FEC_Case_Remarks_3__c
      FROM Case
      WHERE Id = :c.Id
    ];

    System.assert(
      updated.FEC_Case_Remarks_1__c.contains('#1:') &&
        updated.FEC_Case_Remarks_1__c.contains('#2:') &&
        updated.FEC_Case_Remarks_1__c.contains('#3:'),
      'Ba remark đầu phải nằm ở FEC_Case_Remarks_1__c'
    );
    System.assert(
      updated.FEC_Case_Remarks_1__c != null &&
        updated.FEC_Case_Remarks_1__c.length() <= 256,
      'Trường 1 không vượt quá 256 ký tự'
    );
    System.assert(
      String.isNotBlank(updated.FEC_Case_Remarks_2__c) &&
        updated.FEC_Case_Remarks_2__c.startsWith('#4:'),
      'Remark thứ 4 phải bắt đầu ở FEC_Case_Remarks_2__c'
    );
    System.assertEquals(
      null,
      updated.FEC_Case_Remarks_3__c,
      'Chưa cần bucket 3 trong ví dụ BA'
    );
  }

  @isTest
  static void deleteRemarkRebuildsRollup() {
    Case c = new Case(Subject = 'Rollup delete');
    insert c;
    FEC_Case_Remarks__c r1 = new FEC_Case_Remarks__c(
      FEC_Case__c = c.Id,
      FEC_Case_Remarks__c = 'A'
    );
    FEC_Case_Remarks__c r2 = new FEC_Case_Remarks__c(
      FEC_Case__c = c.Id,
      FEC_Case_Remarks__c = 'B'
    );
    insert new List<FEC_Case_Remarks__c>{ r1, r2 };

    delete r2;

    Case updated = [
      SELECT FEC_Case_Remarks_1__c, FEC_Case_Remarks_2__c, FEC_Case_Remarks_3__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      updated.FEC_Case_Remarks_1__c.contains('#1:') && !updated.FEC_Case_Remarks_1__c.contains('#2:'),
      'Sau xóa chỉ còn một dòng đánh số #1'
    );
    System.assertEquals(null, updated.FEC_Case_Remarks_2__c);
    System.assertEquals(null, updated.FEC_Case_Remarks_3__c);
  }

}
