trigger FEC_DataCampaignTrigger on FEC_DataCampaign__c (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        FEC_DataCampaignTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}