trigger FEC_GeneralAssignmentTrigger on FEC_General_Assignment__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            FEC_GeneralAssignmentTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            FEC_GeneralAssignmentTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
