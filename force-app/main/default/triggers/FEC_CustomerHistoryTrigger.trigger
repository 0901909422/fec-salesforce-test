trigger FEC_CustomerHistoryTrigger on FEC_Customer_History__c (after insert, after update) {
    
    FEC_CustomerHistoryTriggerHandler handler = new FEC_CustomerHistoryTriggerHandler();

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.syncSalesChannelFromSalesLogic(Trigger.new, null, false);
        } 
        
        else if (Trigger.isUpdate) {
            handler.syncSalesChannelFromSalesLogic(Trigger.new, Trigger.oldMap, true);
        }
    }
}
