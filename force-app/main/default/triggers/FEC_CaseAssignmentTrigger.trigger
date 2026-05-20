trigger FEC_CaseAssignmentTrigger on FEC_Case_Assignment__c (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        FEC_CaseAssignmentMutationGuard.enforceBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
