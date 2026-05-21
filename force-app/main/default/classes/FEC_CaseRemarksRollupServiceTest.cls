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
      SELECT
        FEC_Case_Remarks_1__c,
        FEC_Case_Remarks_2__c,
        FEC_Case_Remarks_3__c,
        FEC_Case_Remarks_Entered_By__c,
        FEC_Case_Remarks_Entered_By_Role__c,
        FEC_Case_Remarks_Entered_On__c,
        FEC_Case_Remarks_Entered_By_1__c,
        FEC_Case_Remarks_Entered_By_2__c,
        FEC_Case_Remarks_Entered_By_3__c
      FROM Case
      WHERE Id = :c.Id
    ];

    System.assert(
      updated.FEC_Case_Remarks_1__c.contains('#1:') &&
        updated.FEC_Case_Remarks_1__c.contains('#2:') &&
        updated.FEC_Case_Remarks_1__c.contains('#3:'),
      'Ba remark đầu phải nằm ở FEC_Case_Remarks_1__c'
    );
    String myEmail = UserInfo.getUserEmail();
    System.assert(
      String.isNotBlank(updated.FEC_Case_Remarks_Entered_By__c) &&
        updated.FEC_Case_Remarks_Entered_By__c.contains('#1:') &&
        updated.FEC_Case_Remarks_Entered_By__c.contains('#2:') &&
        updated.FEC_Case_Remarks_Entered_By__c.contains(myEmail),
      'Entered By phải có đánh số và email người tạo remark'
    );
    System.assert(
      updated.FEC_Case_Remarks_Entered_By__c.contains(' #2:'),
      'Các cụm #n: phải nối bằng khoảng trắng'
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

    System.assert(
      String.isNotBlank(updated.FEC_Case_Remarks_Entered_By_1__c) &&
        updated.FEC_Case_Remarks_Entered_By_1__c.contains('#1:') &&
        updated.FEC_Case_Remarks_Entered_By_1__c.contains('#2:') &&
        updated.FEC_Case_Remarks_Entered_By_1__c.contains('#3:'),
      'Entered By bucket 1 phai chua #1, #2, #3 tuong ung voi 3 remark dau'
    );
    System.assert(
      String.isNotBlank(updated.FEC_Case_Remarks_Entered_By_2__c) &&
        updated.FEC_Case_Remarks_Entered_By_2__c.contains('#4:'),
      'Entered By bucket 2 phai chua #4 tuong ung voi remark thu 4'
    );
    System.assertEquals(
      null,
      updated.FEC_Case_Remarks_Entered_By_3__c,
      'Entered By bucket 3 phai rong khi khong co remark o bucket 3'
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
      SELECT
        FEC_Case_Remarks_1__c,
        FEC_Case_Remarks_2__c,
        FEC_Case_Remarks_3__c,
        FEC_Case_Remarks_Entered_By__c,
        FEC_Case_Remarks_Entered_By_Role__c,
        FEC_Case_Remarks_Entered_On__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      updated.FEC_Case_Remarks_1__c.contains('#1:') && !updated.FEC_Case_Remarks_1__c.contains('#2:'),
      'Sau xóa chỉ còn một dòng đánh số #1'
    );
    System.assertEquals(null, updated.FEC_Case_Remarks_2__c);
    System.assertEquals(null, updated.FEC_Case_Remarks_3__c);
    System.assert(
      updated.FEC_Case_Remarks_Entered_By__c != null &&
        updated.FEC_Case_Remarks_Entered_By__c.startsWith('#1:') &&
        !updated.FEC_Case_Remarks_Entered_By__c.contains('#2:'),
      'Meta Entered By chỉ còn #1 sau khi xóa remark 2'
    );
  }

  @isTest
  static void rollup_distributesStatusHistoryByRemarkBuckets() {
    Case c = new Case(Subject = 'StatusHistory bucket');
    insert c;

    c = [SELECT Id, FEC_Case_Status_History__c FROM Case WHERE Id = :c.Id];
    c.Status = 'Working';
    update c;
    c = [SELECT Id, FEC_Case_Status_History__c FROM Case WHERE Id = :c.Id];
    c.Status = 'Escalated';
    update c;
    c = [SELECT Id, FEC_Case_Status_History__c FROM Case WHERE Id = :c.Id];

    System.assert(
      String.isNotBlank(c.FEC_Case_Status_History__c) &&
        c.FEC_Case_Status_History__c.contains('#3:'),
      'Case phai co 3 status entries truoc khi tao remark'
    );

    List<FEC_Case_Remarks__c> rows = new List<FEC_Case_Remarks__c>{
      new FEC_Case_Remarks__c(FEC_Case__c = c.Id, FEC_Case_Remarks__c = strLen(50)),
      new FEC_Case_Remarks__c(FEC_Case__c = c.Id, FEC_Case_Remarks__c = strLen(100)),
      new FEC_Case_Remarks__c(FEC_Case__c = c.Id, FEC_Case_Remarks__c = strLen(50))
    };
    insert rows;

    Case updated = [
      SELECT
        FEC_Case_Remarks_1__c,
        FEC_Case_Remarks_2__c,
        FEC_Case_Status_History_1__c,
        FEC_Case_Status_History_2__c,
        FEC_Case_Status_History_3__c
      FROM Case
      WHERE Id = :c.Id
    ];

    System.assert(
      String.isNotBlank(updated.FEC_Case_Status_History_1__c) &&
        updated.FEC_Case_Status_History_1__c.contains('#1:'),
      'Status bucket 1 phai co it nhat entry #1'
    );
  }

  @isTest
  static void metaRollup_includesRoleAndTimestamp() {
    Case c = new Case(Subject = 'Meta role ts');
    insert c;
    String roleVal = 'Test Role';
    insert new FEC_Case_Remarks__c(
      FEC_Case__c = c.Id,
      FEC_Case_Remarks__c = 'X',
      FEC_User_Role__c = roleVal
    );

    Case upd = [
      SELECT FEC_Case_Remarks_Entered_By_Role__c, FEC_Case_Remarks_Entered_On__c
      FROM Case
      WHERE Id = :c.Id
    ];
    System.assert(
      upd.FEC_Case_Remarks_Entered_By_Role__c != null &&
        upd.FEC_Case_Remarks_Entered_By_Role__c.contains('#1:') &&
        upd.FEC_Case_Remarks_Entered_By_Role__c.contains(roleVal),
      'Role rollup phải có #1: và FEC_User_Role__c'
    );
    System.assert(
      upd.FEC_Case_Remarks_Entered_On__c != null &&
        upd.FEC_Case_Remarks_Entered_On__c.startsWith('#1:'),
      'Entered On phải có #1: và CreatedDate đã format'
    );
  }

}
