/**
 * Trạng thái hiển thị khi Pending: Standard Status = Pending, chuỗi ghép team = FEC_Team__c
 * (một hoặc nhiều team cách nhau bởi "_"). Pending-{teams} qua formula FEC_Final_Status__c và computePendingStatusForCase.
 *
 * Khi đổi Owner: nếu Status trước đó là Open và Case đã submit (FEC_Is_Submited__c)
 * thì chuyển Status standard sang Pending. Case nháp chưa submit giữ Open.
 * (Gọi sau các xử lý khác trong after update — ví dụ Routing Action History khi change owner.)
 */
public without sharing class FEC_CasePendingStatusService {
  /** Tránh vòng lặp khi update Case kích hoạt lại trigger. */
  private static Boolean inPendingStatusSync = false;

  /**
   * Gọi từ Case trigger (after insert / after update), bulk-safe, không SOQL trong loop.
   *
   * @param newCases Trigger.new
   * @param oldMap Trigger.oldMap (null khi insert)
   */
  public static void syncPendingStatusFromLatestRouteTo(
    List<Case> newCases,
    Map<Id, Case> oldMap
  ) {
    if (inPendingStatusSync || newCases == null || newCases.isEmpty() || oldMap == null) {
      return;
    }

    Set<Id> candidateIds = new Set<Id>();
    for (Case c : newCases) {
      Case oldCase = oldMap.get(c.Id);
      if (oldCase == null) {
        continue;
      }
      if (c.OwnerId == oldCase.OwnerId) {
        continue;
      }
      if (oldCase.Status != FEC_ConstantCommon.CASE_STATUS_OPEN) {
        continue;
      }
      if (c.IsClosed) {
        continue;
      }
      if (c.Status == FEC_ConstantCommon.CASE_STATUS_PENDING) {
        continue;
      }
      candidateIds.add(c.Id);
    }

    if (candidateIds.isEmpty()) {
      return;
    }

    // Đọc từ DB: Trigger.new khi chỉ đổi Owner có thể không populate FEC_Is_Submited__c.
    Map<Id, Case> submittedCaseMap = new Map<Id, Case>(
      [
        SELECT Id
        FROM Case
        WHERE Id IN :candidateIds AND FEC_Is_Submited__c = TRUE
      ]
    );

    List<Case> toUpdate = new List<Case>();
    for (Id caseId : candidateIds) {
      if (!submittedCaseMap.containsKey(caseId)) {
        continue;
      }
      toUpdate.add(
        new Case(Id = caseId, Status = FEC_ConstantCommon.CASE_STATUS_PENDING)
      );
    }

    if (toUpdate.isEmpty()) {
      return;
    }

    inPendingStatusSync = true;
    try {
      Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
    } finally {
      inPendingStatusSync = false;
    }
  }

  /**
   * Chuỗi hiển thị Pending: Pending hoặc Pending-{Team} / Pending-{Team1}_{Team2}
   * theo FEC_Team__c trên Case (khớp công thức FEC_Final_Status__c).
   */
  public static String computePendingStatusForCase(Id caseId) {
    if (caseId == null) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    List<Case> rows = [
      SELECT Status, FEC_Team__c
      FROM Case
      WHERE Id = :caseId
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    Case c = rows[0];
    if (c.Status != FEC_ConstantCommon.CASE_STATUS_PENDING) {
      return c.Status;
    }
    if (String.isBlank(c.FEC_Team__c)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + c.FEC_Team__c;
  }
}
