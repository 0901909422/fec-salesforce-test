trigger FEC_MDM_CaseStageTrigger on FEC_MDM_Case_Stage__c (before insert, before update) {
    if (Trigger.isInsert) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}