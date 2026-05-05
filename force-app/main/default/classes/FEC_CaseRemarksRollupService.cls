/**
 * Gộp toàn bộ FEC_Case_Remarks__c của Case lên 3 trường Long Text trên Case:
 * mỗi remark một dòng "#<n>: <nội dung>", đầy 256 ký tự ở bucket 1 rồi bucket 2, phần còn lại bucket 3.
 */
public with sharing class FEC_CaseRemarksRollupService {
  @TestVisible
  private static final Integer BUCKET_1_MAX = 256;
  @TestVisible
  private static final Integer BUCKET_2_MAX = 256;
  @TestVisible
  private static final Integer BUCKET_3_MAX = 131072;

  public static void rollup(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }

    List<FEC_Case_Remarks__c> remarks = [
      SELECT Id, FEC_Case__c, FEC_Case_Remarks__c, CreatedDate
      FROM FEC_Case_Remarks__c
      WHERE FEC_Case__c IN :caseIds
      ORDER BY CreatedDate ASC, Id ASC
    ];

    Map<Id, List<FEC_Case_Remarks__c>> byCase = new Map<Id, List<FEC_Case_Remarks__c>>();
    for (Id cid : caseIds) {
      byCase.put(cid, new List<FEC_Case_Remarks__c>());
    }
    for (FEC_Case_Remarks__c r : remarks) {
      if (r.FEC_Case__c != null && byCase.containsKey(r.FEC_Case__c)) {
        byCase.get(r.FEC_Case__c).add(r);
      }
    }

    List<Case> toUpdate = new List<Case>();
    for (Id caseId : caseIds) {
      List<String> lines = formatNumberedLines(byCase.get(caseId));
      BucketPack pack = packLines(lines);
      toUpdate.add(
        new Case(
          Id = caseId,
          FEC_Case_Remarks_1__c = pack.part1,
          FEC_Case_Remarks_2__c = pack.part2,
          FEC_Case_Remarks_3__c = pack.part3
        )
      );
    }

    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }

  private static List<String> formatNumberedLines(List<FEC_Case_Remarks__c> rows) {
    List<String> lines = new List<String>();
    if (rows == null || rows.isEmpty()) {
      return lines;
    }
    Integer n = 1;
    for (FEC_Case_Remarks__c r : rows) {
      String body = r.FEC_Case_Remarks__c == null ? '' : r.FEC_Case_Remarks__c;
      body = body.replace('\r\n', '\n').replace('\r', '\n');
      body = body.replace('\n', ' ');
      lines.add('#' + String.valueOf(n) + ': ' + body);
      n++;
    }
    return lines;
  }

  @TestVisible
  private class BucketPack {
    String part1;
    String part2;
    String part3;
  }

  @TestVisible
  private static BucketPack packLines(List<String> lines) {
    BucketPack p = new BucketPack();
    p.part1 = null;
    p.part2 = null;
    p.part3 = null;
    if (lines == null || lines.isEmpty()) {
      return p;
    }

    Integer idx = 0;
    String b1 = '';
    while (idx < lines.size()) {
      String line = lines[idx];
      String candidate = b1.length() == 0 ? line : b1 + '\n' + line;
      if (candidate.length() <= BUCKET_1_MAX) {
        b1 = candidate;
        idx++;
      } else {
        break;
      }
    }

    String b2 = '';
    while (idx < lines.size()) {
      String line = lines[idx];
      String candidate = b2.length() == 0 ? line : b2 + '\n' + line;
      if (candidate.length() <= BUCKET_2_MAX) {
        b2 = candidate;
        idx++;
      } else {
        break;
      }
    }

    if (idx >= lines.size()) {
      p.part1 = String.isBlank(b1) ? null : b1;
      p.part2 = String.isBlank(b2) ? null : b2;
      p.part3 = null;
      return p;
    }

    List<String> tail = new List<String>();
    for (Integer j = idx; j < lines.size(); j++) {
      tail.add(lines[j]);
    }
    String b3 = String.join(tail, '\n');
    if (b3.length() > BUCKET_3_MAX) {
      b3 = b3.substring(0, BUCKET_3_MAX);
    }

    p.part1 = String.isBlank(b1) ? null : b1;
    p.part2 = String.isBlank(b2) ? null : b2;
    p.part3 = String.isBlank(b3) ? null : b3;
    return p;
  }
}
