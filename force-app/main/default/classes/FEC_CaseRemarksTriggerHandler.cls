/**
 * Handler rollup FEC_Case_Remarks__c lên Case (remarks, meta, status history buckets).
 */
public class FEC_CaseRemarksTriggerHandler {
  public static void run() {
    FEC_CaseRemarksTriggerHandler handler = new FEC_CaseRemarksTriggerHandler();

    if (Trigger.isAfter && Trigger.isInsert) {
      handler.onAfterInsert((List<FEC_Case_Remarks__c>) Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
      handler.onAfterUpdate(
        (List<FEC_Case_Remarks__c>) Trigger.new,
        (Map<Id, FEC_Case_Remarks__c>) Trigger.oldMap
      );
    }

    if (Trigger.isAfter && Trigger.isDelete) {
      handler.onAfterDelete((List<FEC_Case_Remarks__c>) Trigger.old);
    }

    if (Trigger.isAfter && Trigger.isUndelete) {
      handler.onAfterUndelete((List<FEC_Case_Remarks__c>) Trigger.new);
    }
  }

  private void onAfterInsert(List<FEC_Case_Remarks__c> newRows) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Case_Remarks__c r : newRows) {
      if (r.FEC_Case__c != null) {
        caseIds.add(r.FEC_Case__c);
      }
    }
    rollupIfNeeded(caseIds);
  }

  private void onAfterUpdate(
    List<FEC_Case_Remarks__c> newRows,
    Map<Id, FEC_Case_Remarks__c> oldMap
  ) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Case_Remarks__c r : newRows) {
      FEC_Case_Remarks__c oldRow = oldMap.get(r.Id);
      if (
        r.FEC_Case_Remarks__c != oldRow.FEC_Case_Remarks__c ||
        r.FEC_Case__c != oldRow.FEC_Case__c ||
        r.FEC_User_Role__c != oldRow.FEC_User_Role__c
      ) {
        if (r.FEC_Case__c != null) {
          caseIds.add(r.FEC_Case__c);
        }
        if (oldRow.FEC_Case__c != null) {
          caseIds.add(oldRow.FEC_Case__c);
        }
      }
    }
    rollupIfNeeded(caseIds);
  }

  private void onAfterDelete(List<FEC_Case_Remarks__c> oldRows) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Case_Remarks__c r : oldRows) {
      if (r.FEC_Case__c != null) {
        caseIds.add(r.FEC_Case__c);
      }
    }
    rollupIfNeeded(caseIds);
  }

  private void onAfterUndelete(List<FEC_Case_Remarks__c> newRows) {
    Set<Id> caseIds = new Set<Id>();
    for (FEC_Case_Remarks__c r : newRows) {
      if (r.FEC_Case__c != null) {
        caseIds.add(r.FEC_Case__c);
      }
    }
    rollupIfNeeded(caseIds);
  }

  private static void rollupIfNeeded(Set<Id> caseIds) {
    if (!caseIds.isEmpty()) {
      FEC_CaseRemarksRollupService.rollup(caseIds);
    }
  }
}