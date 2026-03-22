/**
 * Đồng bộ Case.Status theo bản ghi Routing Action History mới nhất (Route to).
 * Map Team: User → FEC_Main_Queue__c → FEC_Team_Queue__c; Queue → DeveloperName → FEC_Team_Queue__c
 * (dùng FEC_Original_User_Queue_ID__c / FEC_Updated_User_Queue_ID__c — các trường *_Queue__c text chỉ là nhãn).
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
    if (inPendingStatusSync || newCases == null || newCases.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Case c : newCases) {
      if (c.Id != null) {
        caseIds.add(c.Id);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }

    // Một query: Case hiện tại (Status/IsClosed) — so sánh đúng sau các trigger lồng (vd: Routing History).
    Map<Id, Case> currentCaseById = new Map<Id, Case>(
      [
        SELECT Id, Status, IsClosed
        FROM Case
        WHERE Id IN :caseIds
      ]
    );

    // Một query: Route to mới nhất mỗi Case (ORDER BY CreatedDate DESC, lấy bản đầu tiên theo từng Case).
    Map<Id, FEC_Routing_Action_History__c> latestRouteToByCaseId = loadLatestRouteToHistoryByCaseId(
      caseIds
    );
    if (latestRouteToByCaseId.isEmpty()) {
      return;
    }

    List<Case> toUpdate = new List<Case>();
    for (Id caseId : caseIds) {
      Case current = currentCaseById.get(caseId);
      if (current == null || current.IsClosed) {
        continue;
      }
      FEC_Routing_Action_History__c history = latestRouteToByCaseId.get(caseId);
      if (history == null) {
        continue;
      }

      String desiredStatus = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
        history
      );
      if (desiredStatus == current.Status) {
        continue;
      }
      toUpdate.add(new Case(Id = caseId, Status = desiredStatus));
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
   * Tính chuỗi Status cho một Case (không DML) — Aura/API có thể gọi.
   */
  public static String computePendingStatusForCase(Id caseId) {
    if (caseId == null) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    Map<Id, FEC_Routing_Action_History__c> latest = loadLatestRouteToHistoryByCaseId(
      new Set<Id>{ caseId }
    );
    FEC_Routing_Action_History__c h = latest.get(caseId);
    if (h == null) {
      return FEC_ConstantCommon.CASE_STATUS_PENDING;
    }
    return FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(h);
  }

  /**
   * Bulk: mỗi CaseId → đúng một bản ghi Route to mới nhất (CreatedDate DESC).
   */
  private static Map<Id, FEC_Routing_Action_History__c> loadLatestRouteToHistoryByCaseId(
    Set<Id> caseIds
  ) {
    Map<Id, FEC_Routing_Action_History__c> latestByCase = new Map<Id, FEC_Routing_Action_History__c>();
    if (caseIds == null || caseIds.isEmpty()) {
      return latestByCase;
    }

    String routeTo = FEC_ConstantCommon.CASE_ROUTING_ACTION;
    List<FEC_Routing_Action_History__c> rows = [
      SELECT
        FEC_Case__c,
        FEC_Original_User_Queue_ID__c,
        FEC_Updated_User_Queue_ID__c
      FROM FEC_Routing_Action_History__c
      WHERE FEC_Case__c IN :caseIds AND FEC_Routing_Action__c = :routeTo
      ORDER BY CreatedDate DESC
    ];

    for (FEC_Routing_Action_History__c row : rows) {
      if (row.FEC_Case__c != null && !latestByCase.containsKey(row.FEC_Case__c)) {
        latestByCase.put(row.FEC_Case__c, row);
      }
    }
    return latestByCase;
  }
}
