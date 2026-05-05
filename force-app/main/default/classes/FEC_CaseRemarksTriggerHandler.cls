public class FEC_CaseRemarksTriggerHandler {
  public static void run() {
    Set<Id> caseIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUndelete) {
      for (FEC_Case_Remarks__c r : (List<FEC_Case_Remarks__c>) Trigger.new) {
        if (r.FEC_Case__c != null) {
          caseIds.add(r.FEC_Case__c);
        }
      }
    } else if (Trigger.isUpdate) {
      for (FEC_Case_Remarks__c r : (List<FEC_Case_Remarks__c>) Trigger.new) {
        FEC_Case_Remarks__c oldRow = (FEC_Case_Remarks__c) Trigger.oldMap.get(r.Id);
        if (
          r.FEC_Case_Remarks__c != oldRow.FEC_Case_Remarks__c ||
          r.FEC_Case__c != oldRow.FEC_Case__c
        ) {
          if (r.FEC_Case__c != null) {
            caseIds.add(r.FEC_Case__c);
          }
          if (oldRow.FEC_Case__c != null) {
            caseIds.add(oldRow.FEC_Case__c);
          }
        }
      }
    } else if (Trigger.isDelete) {
      for (FEC_Case_Remarks__c r : (List<FEC_Case_Remarks__c>) Trigger.old) {
        if (r.FEC_Case__c != null) {
          caseIds.add(r.FEC_Case__c);
        }
      }
    }

    if (!caseIds.isEmpty()) {
      FEC_CaseRemarksRollupService.rollup(caseIds);
    }
  }
}
