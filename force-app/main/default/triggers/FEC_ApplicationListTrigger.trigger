trigger FEC_ApplicationListTrigger on FEC_Application_List__c (after insert, after update) {
    
    FEC_ApplicationListTriggerHandler handler = new FEC_ApplicationListTriggerHandler();

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.syncSalesChannelFromApplicationList(Trigger.new, null, false);
        } 
        
        else if (Trigger.isUpdate) {
            handler.syncSalesChannelFromApplicationList(Trigger.new, Trigger.oldMap, true);
        }
    }
}
