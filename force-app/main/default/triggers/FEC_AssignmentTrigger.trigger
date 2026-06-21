// tungnm37: Trigger sync Case.FEC_Assignment_Users__c khi FEC_Assignment_Owner__c thay đổi
trigger FEC_AssignmentTrigger on FEC_Assignment__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        FEC_AssignmentTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        FEC_AssignmentTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
