trigger FEC_MDM_BusinessProcessTrigger on FEC_MDM_Business_Process__c (before insert, before update) {
    if (Trigger.isInsert) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}