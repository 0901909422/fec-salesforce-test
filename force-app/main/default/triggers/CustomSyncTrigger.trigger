trigger CustomSyncTrigger on FEC_Custom_Sync__c (before insert, before update) {
    FEC_CustomSyncValidator.validate(Trigger.new);
}