trigger FEC_CaseAssignmentNOCTrigger on FEC_Case_Assignment_NOC__c (before insert, before update, before delete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeDelete(Trigger.old);
    }
}
