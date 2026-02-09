trigger FEC_CustomerAdditionalConfigHistory on FEC_CustomerAdditionalInfoConfig__c (after insert, after update) {
    
    FEC_CustomerAdditionalHistoryHandler handler = new FEC_CustomerAdditionalHistoryHandler();

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.createHistoryRecords(Trigger.new, null, false);
        } 
        
        else if (Trigger.isUpdate) {
            handler.createHistoryRecords(Trigger.new, Trigger.oldMap, true);
        }
    }
}