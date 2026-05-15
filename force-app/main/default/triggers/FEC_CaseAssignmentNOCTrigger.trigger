trigger FEC_CaseAssignmentNOCTrigger on FEC_Case_Assignment_NOC__c (before insert, before update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}