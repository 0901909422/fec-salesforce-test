/**
 * Trạng thái hiển thị khi Pending: Standard Status = Pending; chuỗi Pending-{team}
 * qua formula FEC_Final_Status__c (FEC_Team__c) và computePendingStatusForCase.
 *
 * computePendingStatusForCase (khi Status = Pending): ưu tiên bản ghi **FEC_Routing_Action_History__c**
 * có Routing Action = Change Owner mới nhất để tính Pending-{team} (thay cho dựa vào Route to mới nhất).
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
  /** @deprecated Chuyển sang syncPendingStatusWhenSubmittedOwnerChanges (tên cũ gây nhầm). */
  public static void syncPendingStatusFromLatestRouteTo(
    List<Case> newCases,
    Map<Id, Case> oldMap
  ) {
    syncPendingStatusWhenSubmittedOwnerChanges(newCases, oldMap);
  }

  public static void syncPendingStatusWhenSubmittedOwnerChanges(
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
   * Chuỗi hiển thị Pending: Pending hoặc Pending-{Team} / Pending-{Team1}_{Team2}.
   * Bước 1: nếu có bản ghi Routing Action History **Change Owner** mới nhất → tính từ
   * FEC_Original_User_Queue_ID__c / FEC_Updated_User_Queue_ID__c (giống buildPendingStatusFromRouteHistoryRow).
   * Ngược lại: theo FEC_Team__c trên Case (khớp công thức FEC_Final_Status__c).
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
    List<FEC_Routing_Action_History__c> latestChangeOwner = [
      SELECT
        FEC_Original_User_Queue_ID__c,
        FEC_Updated_User_Queue_ID__c
      FROM FEC_Routing_Action_History__c
      WHERE
        FEC_Case__c = :caseId
        AND FEC_Routing_Action__c = :FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT 1
    ];
    if (!latestChangeOwner.isEmpty()) {
      return FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
        latestChangeOwner[0]
      );
    }
    if (String.isBlank(c.FEC_Team__c)) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    return FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX + c.FEC_Team__c;
  }
}
