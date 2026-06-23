trigger FEC_MDM_MasterDataSettingTrigger on FEC_MDM_Master_Data_Setting__c (before insert, before update) {
    if (Trigger.isInsert) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
        FEC_ProcessChangeStatusTriggerHandler.handleStatusBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    // Tính hash nội dung — gate bằng isTriggerEnabled để batch set-Synced (chỉ Id+status) KHÔNG ghi đè hash sai
    if (FEC_ProcessChangeStatusTriggerHandler.isTriggerEnabled) {
        FEC_MDMHashUtil.applyHash(Trigger.new);
    }
}