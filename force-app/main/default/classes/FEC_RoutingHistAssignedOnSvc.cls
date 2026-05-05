/**
 * Gán FEC_Assigned_On__c cho FEC_Routing_Action_History__c theo spec Report Dashboard (TH1/TH2).
 * TH1: Case có, Assignment không — có/không bản ghi history trước đó trên cùng Case.
 * TH2: Case và Assignment đều có — theo FEC_Manual__c của Assignment.
 */
public without sharing class FEC_RoutingHistAssignedOnSvc {
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
          [SELECT Id, FEC_Manual__c FROM FEC_Assignment__c WHERE Id IN :assignmentIds]
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

      if (r.FEC_Assignment__c == null) {
        Boolean hasPriorRouting = (dbCount + priorSameCaseInBatch) > 0;
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
    }
  }
}
