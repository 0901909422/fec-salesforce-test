/**
 * @description Common Handler to manage 'Process_Change_Status__c' across all Master Data objects.
 * Handles automatic tagging of 'New' on creation and 'Update' on modification.
 */
public with sharing class FEC_ProcessChangeStatusTriggerHandler {
    // Chiếc công tắc: mặc định là true (vẫn chạy logic trigger)
    public static Boolean isTriggerEnabled = true;
    
    /**
     * Set status to 'New' for all records on creation.
     */
    public static void handleStatusBeforeInsert(List<SObject> newList) {
        if (!isTriggerEnabled) return;
        for (SObject record : newList) {
            record.put('Process_Change_Status__c', 'New');
            Long ts = DateTime.now().getTime();
            Integer rand = Integer.valueOf(Math.random() * 1000);
            record.put('ExternalID__c', ts + '-' + rand);
        }
    }
    
    /**
     * Logic:
     * - If current status is 'New', keep it as 'New'.
     * - Otherwise, set it to 'Update'.
     */
    public static void handleStatusBeforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (!isTriggerEnabled) return;
        for (SObject record : newList) {
            SObject oldRecord = oldMap.get((Id)record.get('Id'));
            String oldStatus = (String)oldRecord.get('Process_Change_Status__c');
            
            if (oldStatus == 'New') {
                record.put('Process_Change_Status__c', 'New');
            } else {
                record.put('Process_Change_Status__c', 'Update');
            }
        }
    }
}
