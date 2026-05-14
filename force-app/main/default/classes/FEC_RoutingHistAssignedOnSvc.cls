/**
 * Report Dashboard — Routing Action History:
 * - FEC_Assigned_On__c (TH1/TH2 phần Assigned)
 * - FEC_Submitted_On__c: TH1 (Case-level) = FEC_Date_Time__c; TH2 = submit Assignment
 */
public without sharing class FEC_RoutingHistAssignedOnSvc {
  private static Boolean fecBhLookupDone = false;
  private static Id fecBusinessHoursId;

  /** Business Hours đặt trong Setup; name phải khớp org (kèm holidays trong cấu hình BH). */
  private static final String FEC_BUSINESS_HOURS_NAME = 'FEC Business Hours';

  /** Bản ghi RAH dùng để suy luận Assigned On (DB + các dòng cùng batch đã xử lý trước). */
  private class PriorRah {
    Id recordId;
    Integer batchIndex;
    Id caseId;
    Id assignmentId;
    Datetime submittedOn;
    Datetime createdDate;

    PriorRah(
      Id recordId,
      Integer batchIndex,
      Id caseId,
      Id assignmentId,
      Datetime submittedOn,
      Datetime createdDate
    ) {
      this.recordId = recordId;
      this.batchIndex = batchIndex;
      this.caseId = caseId;
      this.assignmentId = assignmentId;
      this.submittedOn = submittedOn;
      this.createdDate = createdDate;
    }
  }

  /** So sánh sort: FEC_Submitted_On__c DESC, CreatedDate DESC (TH2.2.2). */
  private static Integer cmpSubmittedDescCreatedDesc(PriorRah a, PriorRah b) {
    if (a.submittedOn > b.submittedOn) {
      return 1;
    }
    if (a.submittedOn < b.submittedOn) {
      return -1;
    }
    if (a.createdDate > b.createdDate) {
      return 1;
    }
    if (a.createdDate < b.createdDate) {
      return -1;
    }
    Integer ai = a.batchIndex != null ? a.batchIndex : -1;
    Integer bi = b.batchIndex != null ? b.batchIndex : -1;
    if (ai > bi) {
      return 1;
    }
    if (ai < bi) {
      return -1;
    }
    String sa = a.recordId != null ? String.valueOf(a.recordId) : '';
    String sb = b.recordId != null ? String.valueOf(b.recordId) : '';
    if (sa > sb) {
      return 1;
    }
    if (sa < sb) {
      return -1;
    }
    return 0;
  }

  private static PriorRah pickBest(List<PriorRah> rows) {
    PriorRah best = null;
    for (PriorRah p : rows) {
      if (p.submittedOn == null) {
        continue;
      }
      if (best == null) {
        best = p;
        continue;
      }
      Integer c = cmpSubmittedDescCreatedDesc(p, best);
      if (c > 0) {
        best = p;
      }
    }
    return best;
  }

  private static List<PriorRah> mergeCaseCandidates(
    Id caseId,
    Map<Id, List<PriorRah>> dbByCase,
    Map<Id, List<PriorRah>> batchByCase
  ) {
    List<PriorRah> out = new List<PriorRah>();
    if (dbByCase != null && dbByCase.containsKey(caseId)) {
      out.addAll(dbByCase.get(caseId));
    }
    if (batchByCase != null && batchByCase.containsKey(caseId)) {
      out.addAll(batchByCase.get(caseId));
    }
    return out;
  }

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

    Map<Id, FEC_Assignment__c> assignmentsById = assignmentIds.isEmpty()
      ? new Map<Id, FEC_Assignment__c>()
      : new Map<Id, FEC_Assignment__c>(
          [
            SELECT Id, FEC_Manual__c, FEC_Submitted_On__c
            FROM FEC_Assignment__c
            WHERE Id IN :assignmentIds
          ]
        );

    Map<Id, List<PriorRah>> dbHistoryByCase = new Map<Id, List<PriorRah>>();
    for (FEC_Routing_Action_History__c h : [
      SELECT
        Id,
        FEC_Case__c,
        FEC_Assignment__c,
        FEC_Submitted_On__c,
        CreatedDate
      FROM FEC_Routing_Action_History__c
      WHERE FEC_Case__c IN :caseIds
    ]) {
      if (h.FEC_Case__c == null) {
        continue;
      }
      if (!dbHistoryByCase.containsKey(h.FEC_Case__c)) {
        dbHistoryByCase.put(h.FEC_Case__c, new List<PriorRah>());
      }
      dbHistoryByCase.get(h.FEC_Case__c)
        .add(
          new PriorRah(
            h.Id,
            null,
            h.FEC_Case__c,
            h.FEC_Assignment__c,
            h.FEC_Submitted_On__c,
            h.CreatedDate
          )
        );
    }

    Datetime nowTs = System.now();
    Map<Id, List<PriorRah>> batchAccumulatedByCase = new Map<Id, List<PriorRah>>();

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

      Datetime caseCreatedOn = c.FEC_Case_Created_On__c != null
        ? c.FEC_Case_Created_On__c
        : nowTs;

      applySubmittedOnBeforeInsertRow(r, assignmentsById, nowTs);

      Datetime effectiveSubmitted = r.FEC_Submitted_On__c != null
        ? r.FEC_Submitted_On__c
        : nowTs;

      if (r.FEC_Assignment__c == null) {
        List<PriorRah> pool = mergeCaseCandidates(
          caseId,
          dbHistoryByCase,
          batchAccumulatedByCase
        );
        List<PriorRah> cand = new List<PriorRah>();
        for (PriorRah p : pool) {
          if (p.assignmentId != null) {
            continue;
          }
          if (p.submittedOn == null) {
            continue;
          }
          if (p.submittedOn < effectiveSubmitted) {
            cand.add(p);
          }
        }
        PriorRah best = pickBest(cand);
        r.FEC_Assigned_On__c = best == null ? caseCreatedOn : best.submittedOn;
      } else {
        FEC_Assignment__c a = assignmentsById.get(r.FEC_Assignment__c);
        List<PriorRah> pool = mergeCaseCandidates(
          caseId,
          dbHistoryByCase,
          batchAccumulatedByCase
        );
        List<PriorRah> candSameAssign = new List<PriorRah>();
        for (PriorRah p : pool) {
          if (p.assignmentId != r.FEC_Assignment__c) {
            continue;
          }
          if (p.submittedOn == null) {
            continue;
          }
          if (p.submittedOn < effectiveSubmitted) {
            candSameAssign.add(p);
          }
        }
        PriorRah bestSame = pickBest(candSameAssign);
        if (bestSame != null) {
          r.FEC_Assigned_On__c = bestSame.submittedOn;
        } else if (a == null || a.FEC_Manual__c != true) {
          r.FEC_Assigned_On__c = caseCreatedOn;
        } else {
          List<PriorRah> candManual = new List<PriorRah>();
          for (PriorRah p : pool) {
            if (p.submittedOn == null) {
              continue;
            }
            if (p.submittedOn <= effectiveSubmitted) {
              candManual.add(p);  
            }
          }
          PriorRah bestManual = pickBest(candManual);
          r.FEC_Assigned_On__c = bestManual == null
            ? caseCreatedOn
            : bestManual.submittedOn;
        }
      }

      if (!batchAccumulatedByCase.containsKey(caseId)) {
        batchAccumulatedByCase.put(caseId, new List<PriorRah>());
      }
      batchAccumulatedByCase.get(caseId)
        .add(
          new PriorRah(
            r.Id,
            i,
            caseId,
            r.FEC_Assignment__c,
            effectiveSubmitted,
            nowTs
          )
        );
    }
  }

  /**
   * Giờ làm việc giữa Assigned On và Submitted On (FEC Business Hours). Format số 2 chữ thập phân.
   */
  public static void applyTatBeforeSave(
    List<FEC_Routing_Action_History__c> records,
    Map<Id, FEC_Routing_Action_History__c> oldMap
  ) {
    if (records == null || records.isEmpty()) {
      return;
    }

    Id bhId = resolveFecBusinessHoursId();
    for (FEC_Routing_Action_History__c r : records) {
      if (bhId == null) {
        r.FEC_TAT_by_Assignment__c = null;
        continue;
      }
      Datetime assigned = r.FEC_Assigned_On__c;
      Datetime submitted = r.FEC_Submitted_On__c;

      if (assigned == null || submitted == null) {
        r.FEC_TAT_by_Assignment__c = null;
        continue;
      }

      Long millis = BusinessHours.diff(bhId, assigned, submitted);
      if (millis == null || millis < 0) {
        r.FEC_TAT_by_Assignment__c = null;
        continue;
      }

      Decimal hours = Decimal.valueOf(millis)
        .divide(3600000, 12, System.RoundingMode.HALF_UP)
        .setScale(2, System.RoundingMode.HALF_UP);
      r.FEC_TAT_by_Assignment__c = hours;
    }
  }

  private static Id resolveFecBusinessHoursId() {
    if (!fecBhLookupDone) {
      fecBhLookupDone = true;
      List<BusinessHours> rows = [
        SELECT Id
        FROM BusinessHours
        WHERE Name = :FEC_BUSINESS_HOURS_NAME AND IsActive = TRUE
        LIMIT 1
      ];
      fecBusinessHoursId = rows.isEmpty() ? null : rows[0].Id;
    }
    return fecBusinessHoursId;
  }

  /**
   * TH1 (Case-level, Assignment null): FEC_Submitted_On__c = FEC_Date_Time__c (formula = CreatedDate trên metadata).
   * Trước insert formula thường chưa có giá trị → fallback nowTs (cùng mốc “sinh” bản ghi).
   * TH2 (Assignment có): FEC_Submitted_On__c = submit Assignment (field trên Assignment), fallback now.
   */
  private static void applySubmittedOnBeforeInsertRow(
    FEC_Routing_Action_History__c r,
    Map<Id, FEC_Assignment__c> assignmentsById,
    Datetime nowTs
  ) {
    if (r.FEC_Case__c == null) {
      return;
    }

    if (r.FEC_Assignment__c == null) {
      return;
    }

    FEC_Assignment__c a = assignmentsById.get(r.FEC_Assignment__c);
    if (a != null && a.FEC_Submitted_On__c != null) {
      r.FEC_Submitted_On__c = a.FEC_Submitted_On__c;
    } else {
      r.FEC_Submitted_On__c = nowTs;
    }
  }

  public static void syncSubmittedOnAfterInsert(
    List<FEC_Routing_Action_History__c> newRecords
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    List<FEC_Routing_Action_History__c> toUpdate = new List<FEC_Routing_Action_History__c>();
    for (FEC_Routing_Action_History__c r : newRecords) {
      if (r.FEC_Case__c == null || r.FEC_Assignment__c != null) {
        continue;
      }
      if (r.CreatedDate == null) {
        continue;
      }
      if (r.FEC_Submitted_On__c == r.CreatedDate) {
        continue;
      }
      toUpdate.add(
        new FEC_Routing_Action_History__c(
          Id = r.Id,
          FEC_Submitted_On__c = r.CreatedDate
        )
      );
    }

    if (!toUpdate.isEmpty()) {
      Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
    }
  }
}