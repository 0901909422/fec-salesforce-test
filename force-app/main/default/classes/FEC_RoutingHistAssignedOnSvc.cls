/**
 * Report Dashboard — Routing Action History:
 * - FEC_Assigned_On__c (TH1/TH2 phần Assigned)
 * - FEC_Submitted_On__c (TH1 Case-level; TH2 từ Assignment.FEC_Submitted_On__c)
 */
public without sharing class FEC_RoutingHistAssignedOnSvc {
  /** Bỏ qua email / logic nặng trên after update khi chỉ chain Submitted On */
  public static Boolean suppressAfterUpdateForChain = false;

  public static void applyBeforeInsert(List<FEC_Routing_Action_History__c> newRecords) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    Set<Id> assignmentIds = new Set<Id>();
    for (FEC_Routing_Action_History__c r : newRecords) {
      if (r.FEC_Case__c != null) {
        caseIds.add(r.FEC_Case__c);
      }
      if (r.FEC_Assignment__c != null) {
        assignmentIds.add(r.FEC_Assignment__c);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }

    Map<Id, Case> casesById = new Map<Id, Case>(
      [SELECT Id, FEC_Case_Created_On__c FROM Case WHERE Id IN :caseIds]
    );

    Map<Id, Integer> historyCountByCase = new Map<Id, Integer>();
    for (AggregateResult ar : [
      SELECT FEC_Case__c caseId, COUNT(Id) rowCount
      FROM FEC_Routing_Action_History__c
      WHERE FEC_Case__c IN :caseIds
      GROUP BY FEC_Case__c
    ]) {
      historyCountByCase.put(
        (Id) ar.get('caseId'),
        (Integer) ar.get('rowCount')
      );
    }

    Map<Id, FEC_Assignment__c> assignmentsById = assignmentIds.isEmpty()
      ? new Map<Id, FEC_Assignment__c>()
      : new Map<Id, FEC_Assignment__c>(
          [
            SELECT Id, FEC_Manual__c, FEC_Submitted_On__c
            FROM FEC_Assignment__c
            WHERE Id IN :assignmentIds
          ]
        );

    Datetime nowTs = System.now();

    for (Integer i = 0; i < newRecords.size(); i++) {
      FEC_Routing_Action_History__c r = newRecords[i];
      if (r.FEC_Case__c == null) {
        continue;
      }

      Id caseId = r.FEC_Case__c;
      Case c = casesById.get(caseId);
      if (c == null) {
        continue;
      }

      Integer priorSameCaseInBatch = 0;
      for (Integer j = 0; j < i; j++) {
        if (newRecords[j].FEC_Case__c == caseId) {
          priorSameCaseInBatch++;
        }
      }

      Integer dbCount = historyCountByCase.containsKey(caseId)
        ? historyCountByCase.get(caseId)
        : 0;
      Datetime caseCreatedOn = c.FEC_Case_Created_On__c != null
        ? c.FEC_Case_Created_On__c
        : nowTs;

      Boolean hasPriorRouting = (dbCount + priorSameCaseInBatch) > 0;

      if (r.FEC_Assignment__c == null) {
        r.FEC_Assigned_On__c = hasPriorRouting ? nowTs : caseCreatedOn;
      } else {
        FEC_Assignment__c a = assignmentsById.get(r.FEC_Assignment__c);
        if (a == null) {
          r.FEC_Assigned_On__c = caseCreatedOn;
        } else if (a.FEC_Manual__c == true) {
          r.FEC_Assigned_On__c = nowTs;
        } else {
          r.FEC_Assigned_On__c = caseCreatedOn;
        }
      }

      applySubmittedOnBeforeInsertRow(
        r,
        hasPriorRouting,
        assignmentsById,
        nowTs
      );
    }
  }

  /**
   * TH1 (Assignment null): bản ghi đầu Case = thời điểm tạo RAH; bản sau = Submitted chỉ khi
   * đã có bước tiếp (xử lý trong chainCaseLevelSubmittedOnAfterInsert).
   * TH2 (Assignment có): = FEC_Submitted_On__c của Assignment (submit), fallback now().
   */
  private static void applySubmittedOnBeforeInsertRow(
    FEC_Routing_Action_History__c r,
    Boolean hasPriorRouting,
    Map<Id, FEC_Assignment__c> assignmentsById,
    Datetime nowTs
  ) {
    if (r.FEC_Case__c == null) {
      return;
    }

    if (r.FEC_Assignment__c == null) {
      if (!hasPriorRouting) {
        r.FEC_Submitted_On__c = nowTs;
      } else {
        r.FEC_Submitted_On__c = null;
      }
      return;
    }

    FEC_Assignment__c a = assignmentsById.get(r.FEC_Assignment__c);
    if (a != null && a.FEC_Submitted_On__c != null) {
      r.FEC_Submitted_On__c = a.FEC_Submitted_On__c;
    } else {
      r.FEC_Submitted_On__c = nowTs;
    }
  }

  /**
   * TH1: bản ghi Case-level (Assignment null) không phải bước đầu tiên của Case
   * → khi có bản ghi mới (bước sau), gán Submitted On bước trước = Assigned On của bước sau.
   * Không ghi đè bước đầu tiên trên Case (index 0).
   */
  public static void chainCaseLevelSubmittedOnAfterInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (FEC_Routing_Action_History__c r : newRecords) {
      if (r.FEC_Case__c != null) {
        caseIds.add(r.FEC_Case__c);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }

    List<FEC_Routing_Action_History__c> timeline = [
      SELECT
        Id,
        FEC_Case__c,
        CreatedDate,
        FEC_Assignment__c,
        FEC_Assigned_On__c,
        FEC_Submitted_On__c
      FROM FEC_Routing_Action_History__c
      WHERE FEC_Case__c IN :caseIds
      ORDER BY FEC_Case__c, CreatedDate ASC, Id ASC
    ];

    Map<Id, List<Integer>> caseIdToIndices = new Map<Id, List<Integer>>();
    for (Integer k = 0; k < timeline.size(); k++) {
      Id cid = timeline[k].FEC_Case__c;
      if (cid == null) {
        continue;
      }
      if (!caseIdToIndices.containsKey(cid)) {
        caseIdToIndices.put(cid, new List<Integer>());
      }
      caseIdToIndices.get(cid).add(k);
    }

    Map<Id, FEC_Routing_Action_History__c> toUpdate = new Map<Id, FEC_Routing_Action_History__c>();

    for (FEC_Routing_Action_History__c curr : newRecords) {
      if (curr.Id == null || curr.FEC_Case__c == null) {
        continue;
      }

      List<Integer> idxList = caseIdToIndices.get(curr.FEC_Case__c);
      if (idxList == null || idxList.isEmpty()) {
        continue;
      }

      Integer pos = -1;
      for (Integer idx : idxList) {
        if (timeline[idx].Id == curr.Id) {
          pos = idx;
          break;
        }
      }
      if (pos <= 0) {
        continue;
      }

      FEC_Routing_Action_History__c prev = timeline[pos - 1];
      if (prev.FEC_Case__c != curr.FEC_Case__c) {
        continue;
      }
      if (prev.FEC_Assignment__c != null) {
        continue;
      }

      Integer firstPos = idxList[0];
      if (pos - 1 == firstPos) {
        continue;
      }

      Datetime nextAssigned = curr.FEC_Assigned_On__c != null
        ? curr.FEC_Assigned_On__c
        : curr.CreatedDate;

      if (prev.FEC_Submitted_On__c == nextAssigned) {
        continue;
      }

      toUpdate.put(
        prev.Id,
        new FEC_Routing_Action_History__c(
          Id = prev.Id,
          FEC_Submitted_On__c = nextAssigned
        )
      );
    }

    if (toUpdate.isEmpty()) {
      return;
    }

    try {
      suppressAfterUpdateForChain = true;
      Database.update(toUpdate.values(), AccessLevel.SYSTEM_MODE);
    } finally {
      suppressAfterUpdateForChain = false;
    }
  }
}
