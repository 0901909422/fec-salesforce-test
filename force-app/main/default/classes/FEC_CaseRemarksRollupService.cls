/**
 * Gộp toàn bộ FEC_Case_Remarks__c của Case lên 3 trường Long Text trên Case:
 * mỗi remark một dòng "#<n>: <nội dung>", đầy 256 ký tự ở bucket 1 rồi bucket 2, phần còn lại bucket 3 (Text 255).
 *
 * Đồng thời rollup 3 trường meta (#n: ...) tối đa 255 ký tự mỗi trường: người tạo (email),
 * FEC_User_Role__c, thời điểm CreatedDate — nối bằng khoảng trắng giữa các phần.
 */
public without sharing class FEC_CaseRemarksRollupService {
  // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
  private static Set<Id> txnRemarkRollupDoneCaseIds = new Set<Id>();

  @TestVisible
  private static final Integer BUCKET_1_MAX = 256;
  @TestVisible
  private static final Integer BUCKET_2_MAX = 256;
  @TestVisible
  private static final Integer BUCKET_3_MAX = 255;
  @TestVisible
  private static final Integer META_ROLLUP_MAX = 255;
  private static final String META_SEGMENT_SEP = ' ';

  @TestVisible
  private static final Integer STATUS_BUCKET_1_MAX = 255;
  @TestVisible
  private static final Integer STATUS_BUCKET_2_MAX = 255;
  @TestVisible
  private static final Integer STATUS_BUCKET_3_MAX = 255;
  private static final String STATUS_ENTRY_SEP = '\n';

  public static void rollup(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }

    Set<Id> pendingCaseIds = new Set<Id>();
    for (Id caseId : caseIds) {
      if (caseId != null && !txnRemarkRollupDoneCaseIds.contains(caseId)) {
        pendingCaseIds.add(caseId);
      }
    }
    // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
    if (pendingCaseIds.isEmpty()) {
      return;
    }

    List<FEC_Case_Remarks__c> remarks = [
      SELECT
        Id,
        FEC_Case__c,
        FEC_Case_Remarks__c,
        FEC_User_Role__c,
        CreatedDate,
        CreatedById,
        CreatedBy.Email,
        CreatedBy.Username
      FROM FEC_Case_Remarks__c
      WHERE FEC_Case__c IN :pendingCaseIds
      ORDER BY CreatedDate ASC, Id ASC
    ];

    Map<Id, Case> caseMap = new Map<Id, Case>([
      SELECT Id, FEC_Case_Status_History__c
      FROM Case
      WHERE Id IN :pendingCaseIds
    ]);

    Map<Id, List<FEC_Case_Remarks__c>> byCase = new Map<Id, List<FEC_Case_Remarks__c>>();
    for (Id cid : pendingCaseIds) {
      byCase.put(cid, new List<FEC_Case_Remarks__c>());
    }
    for (FEC_Case_Remarks__c r : remarks) {
      if (r.FEC_Case__c != null && byCase.containsKey(r.FEC_Case__c)) {
        byCase.get(r.FEC_Case__c).add(r);
      }
    }

    List<Case> toUpdate = new List<Case>();
    for (Id caseId : pendingCaseIds) {
      List<FEC_Case_Remarks__c> rowsForCase = byCase.get(caseId);
      List<String> lines = formatNumberedLines(rowsForCase);
      BucketPack pack = packLines(lines);

      MetaRollup meta = buildMetaRollup(rowsForCase, pack);

      Case caseRecord = caseMap.get(caseId);
      String fullStatusHistory = caseRecord != null ? caseRecord.FEC_Case_Status_History__c : null;
      StatusHistoryBuckets statusBuckets = distributeStatusHistory(fullStatusHistory, pack);

      toUpdate.add(
        new Case(
          Id = caseId,
          FEC_Case_Remarks_1__c = pack.part1,
          FEC_Case_Remarks_2__c = pack.part2,
          FEC_Case_Remarks_3__c = pack.part3,
          FEC_Case_Remarks_Entered_By__c = meta.enteredBy,
          FEC_Case_Remarks_Entered_By_Role__c = meta.enteredByRole,
          FEC_Case_Remarks_Entered_On__c = meta.enteredOn,
          FEC_Case_Remarks_Entered_By_1__c = meta.enteredBy1,
          FEC_Case_Remarks_Entered_By_2__c = meta.enteredBy2,
          FEC_Case_Remarks_Entered_By_3__c = meta.enteredBy3,
          FEC_Case_Remarks_Entered_By_Role_1__c = meta.enteredByRole1,
          FEC_Case_Remarks_Entered_By_Role_2__c = meta.enteredByRole2,
          FEC_Case_Remarks_Entered_By_Role_3__c = meta.enteredByRole3,
          FEC_Case_Remarks_Entered_On_1__c = meta.enteredOn1,
          FEC_Case_Remarks_Entered_On_2__c = meta.enteredOn2,
          FEC_Case_Remarks_Entered_On_3__c = meta.enteredOn3,
          FEC_Case_Status_History_1__c = statusBuckets.part1,
          FEC_Case_Status_History_2__c = statusBuckets.part2,
          FEC_Case_Status_History_3__c = statusBuckets.part3
        )
      );
    }

    if (!toUpdate.isEmpty()) {
      FEC_CaseTriggerHandler.isExecuting = true;
      try {
        update toUpdate;
      } finally {
        FEC_CaseTriggerHandler.isExecuting = false;
      }
      // SOQL 101: cache/dedupe theo transaction, tránh query lặp khi submit NOC bulk.
      txnRemarkRollupDoneCaseIds.addAll(pendingCaseIds);
    }
  }

  @TestVisible
  private class StatusHistoryBuckets {
    public String part1;
    public String part2;
    public String part3;
  }

  @TestVisible
  private static List<String> parseStatusHistoryEntries(String fullHistory) {
    List<String> entries = new List<String>();
    if (String.isBlank(fullHistory)) {
      return entries;
    }
    Matcher m = Pattern.compile('#\\d+:\\s*').matcher(fullHistory);
    List<Integer> starts = new List<Integer>();
    while (m.find()) {
      starts.add(m.start());
    }
    for (Integer i = 0; i < starts.size(); i++) {
      Integer startPos = starts[i];
      Integer endPos = (i + 1 < starts.size()) ? starts[i + 1] : fullHistory.length();
      entries.add(fullHistory.substring(startPos, endPos).trim());
    }
    return entries;
  }

  @TestVisible
  private static StatusHistoryBuckets distributeStatusHistory(String fullHistory, BucketPack remarkPack) {
    StatusHistoryBuckets result = new StatusHistoryBuckets();
    List<String> statusEntries = parseStatusHistoryEntries(fullHistory);
    if (statusEntries.isEmpty()) {
      return result;
    }

    Integer totalRemarks = remarkPack.count1 + remarkPack.count2 + remarkPack.count3;

    if (totalRemarks == 0) {
      String joined = String.join(statusEntries, STATUS_ENTRY_SEP);
      result.part1 = joined.length() > STATUS_BUCKET_1_MAX ? joined.substring(0, STATUS_BUCKET_1_MAX) : joined;
      return result;
    }

    List<String> bucket1 = new List<String>();
    List<String> bucket2 = new List<String>();
    List<String> bucket3 = new List<String>();

    for (Integer i = 0; i < statusEntries.size(); i++) {
      if (i < remarkPack.count1) {
        bucket1.add(statusEntries[i]);
      } else if (i < remarkPack.count1 + remarkPack.count2) {
        bucket2.add(statusEntries[i]);
      } else {
        bucket3.add(statusEntries[i]);
      }
    }

    result.part1 = joinAndTruncate(bucket1, STATUS_BUCKET_1_MAX);
    result.part2 = joinAndTruncate(bucket2, STATUS_BUCKET_2_MAX);
    result.part3 = joinAndTruncate(bucket3, STATUS_BUCKET_3_MAX);
    return result;
  }

  private static String joinAndTruncate(List<String> entries, Integer maxLen) {
    if (entries == null || entries.isEmpty()) {
      return null;
    }
    String joined = String.join(entries, STATUS_ENTRY_SEP);
    if (joined.length() > maxLen) {
      return joined.substring(0, maxLen);
    }
    return joined;
  }

  @TestVisible
  private static final Integer ENTERED_BY_BUCKET_1_MAX = 255;
  @TestVisible
  private static final Integer ENTERED_BY_BUCKET_2_MAX = 255;
  @TestVisible
  private static final Integer ENTERED_BY_BUCKET_3_MAX = 255;

  @TestVisible
  private class MetaRollup {
    String enteredBy;
    String enteredByRole;
    String enteredOn;
    String enteredBy1;
    String enteredBy2;
    String enteredBy3;
    String enteredByRole1;
    String enteredByRole2;
    String enteredByRole3;
    String enteredOn1;
    String enteredOn2;
    String enteredOn3;
  }

  @TestVisible
  private static MetaRollup buildMetaRollup(List<FEC_Case_Remarks__c> rows, BucketPack pack) {
    MetaRollup m = new MetaRollup();
    if (rows == null || rows.isEmpty()) {
      return m;
    }

    List<String> byCreator = new List<String>();
    List<String> byRole = new List<String>();
    List<String> byTs = new List<String>();

    for (FEC_Case_Remarks__c r : rows) {
      byCreator.add(resolveEnteredByDisplay(r));
      byRole.add(r.FEC_User_Role__c == null ? '' : r.FEC_User_Role__c);
      byTs.add(formatRemarkCreatedTs(r.CreatedDate));
    }

    m.enteredBy = joinNumberedMetaSegments(byCreator);
    m.enteredByRole = joinNumberedMetaSegments(byRole);
    m.enteredOn = joinNumberedMetaSegments(byTs);

    List<String> numberedCreators = buildNumberedSegments(byCreator);
    m.enteredBy1 = joinAndTruncate(sliceList(numberedCreators, 0, pack.count1), ENTERED_BY_BUCKET_1_MAX);
    m.enteredBy2 = joinAndTruncate(sliceList(numberedCreators, pack.count1, pack.count1 + pack.count2), ENTERED_BY_BUCKET_2_MAX);
    m.enteredBy3 = joinAndTruncate(sliceList(numberedCreators, pack.count1 + pack.count2, numberedCreators.size()), ENTERED_BY_BUCKET_3_MAX);

    List<String> numberedRoles = buildNumberedSegments(byRole);
    m.enteredByRole1 = joinAndTruncate(sliceList(numberedRoles, 0, pack.count1), ENTERED_BY_BUCKET_1_MAX);
    m.enteredByRole2 = joinAndTruncate(sliceList(numberedRoles, pack.count1, pack.count1 + pack.count2), ENTERED_BY_BUCKET_2_MAX);
    m.enteredByRole3 = joinAndTruncate(sliceList(numberedRoles, pack.count1 + pack.count2, numberedRoles.size()), ENTERED_BY_BUCKET_3_MAX);

    List<String> numberedTs = buildNumberedSegments(byTs);
    m.enteredOn1 = joinAndTruncate(sliceList(numberedTs, 0, pack.count1), ENTERED_BY_BUCKET_1_MAX);
    m.enteredOn2 = joinAndTruncate(sliceList(numberedTs, pack.count1, pack.count1 + pack.count2), ENTERED_BY_BUCKET_2_MAX);
    m.enteredOn3 = joinAndTruncate(sliceList(numberedTs, pack.count1 + pack.count2, numberedTs.size()), ENTERED_BY_BUCKET_3_MAX);

    return m;
  }

  @TestVisible
  private static List<String> buildNumberedSegments(List<String> bodies) {
    List<String> parts = new List<String>();
    if (bodies == null || bodies.isEmpty()) {
      return parts;
    }
    Integer n = 1;
    for (String raw : bodies) {
      String b = raw == null ? '' : raw;
      b = b.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ');
      parts.add('#' + String.valueOf(n) + ': ' + b);
      n++;
    }
    return parts;
  }

  private static List<String> sliceList(List<String> src, Integer fromIdx, Integer toIdx) {
    List<String> result = new List<String>();
    if (src == null || fromIdx >= toIdx || fromIdx >= src.size()) {
      return result;
    }
    Integer upperBound = Math.min(toIdx, src.size());
    for (Integer i = fromIdx; i < upperBound; i++) {
      result.add(src[i]);
    }
    return result;
  }

  private static String resolveEnteredByDisplay(FEC_Case_Remarks__c r) {
    if (r == null) {
      return '';
    }
    User cb = r.CreatedBy;
    if (cb != null) {
      if (String.isNotBlank(cb.Email)) {
        return cb.Email;
      }
      if (String.isNotBlank(cb.Username)) {
        return cb.Username;
      }
    }
    return r.CreatedById != null ? String.valueOf(r.CreatedById) : '';
  }

  private static String formatRemarkCreatedTs(Datetime dt) {
    if (dt == null) {
      return '';
    }
    return dt.format(
      FEC_ConstantCommon.DATETIME_FORMAT_OUTPUT,
      UserInfo.getTimeZone().getID()
    );
  }

  @TestVisible
  private static String joinNumberedMetaSegments(List<String> bodies) {
    if (bodies == null || bodies.isEmpty()) {
      return null;
    }
    List<String> parts = new List<String>();
    Integer n = 1;
    for (String raw : bodies) {
      String b = raw == null ? '' : raw;
      b = b.replace('\r\n', ' ').replace('\r', ' ').replace('\n', ' ');
      parts.add('#' + String.valueOf(n) + ': ' + b);
      n++;
    }
    String full = String.join(parts, META_SEGMENT_SEP);
    if (full.length() > META_ROLLUP_MAX) {
      return full.substring(0, META_ROLLUP_MAX);
    }
    return full;
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
    public String part1;
    public String part2;
    public String part3;
    public Integer count1 = 0;
    public Integer count2 = 0;
    public Integer count3 = 0;
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
    p.count1 = idx;

    Integer b2Start = idx;
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
    p.count2 = idx - b2Start;

    if (idx >= lines.size()) {
      p.count3 = 0;
      p.part1 = String.isBlank(b1) ? null : b1;
      p.part2 = String.isBlank(b2) ? null : b2;
      p.part3 = null;
      return p;
    }

    p.count3 = lines.size() - idx;
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