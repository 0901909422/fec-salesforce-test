trigger FEC_CaseAssignmentTrigger on FEC_Case_Assignment__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            FEC_CaseAssignmentMutationGuard.enforceActiveRequiresNocOnInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            FEC_CaseAssignmentMutationGuard.enforceActiveRequiresNocOnUpdate(Trigger.new, Trigger.oldMap);
            FEC_CaseAssignmentMutationGuard.enforceBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            FEC_CaseAssignmentTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            FEC_CaseAssignmentTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}