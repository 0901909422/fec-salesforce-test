trigger FEC_MDM_ChannelTrigger on FEC_MDM_Channel__c (before insert, before update) {
    if (Trigger.isInsert) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}