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
        if (!isTriggerEnabled || newList == null) return;
        // Use timestamp + user suffix for low-collision ExternalID (avoids unsafe casts)
        Long ts = DateTime.now().getTime();
        String userSuffix;
        String uid = UserInfo.getUserId();
        if (uid != null && uid.length() >= 3) {
            userSuffix = uid.substring(0,3);
        } else {
            String tsStr = String.valueOf(DateTime.now().getTime());
            if (tsStr.length() > 3) {
                userSuffix = tsStr.substring(tsStr.length() - 3);
            } else {
                userSuffix = tsStr;
            }
        }
        for (SObject record : newList) {
            record.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_NEW);
            record.put(FEC_Constants.FIELD_EXTERNAL_ID, String.valueOf(ts) + '-' + userSuffix);
        }
    }
    
    /**
     * Logic:
     * - If current status is 'New', keep it as 'New'.
     * - Otherwise, set it to 'Update'.
     */
    public static void handleStatusBeforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
        if (!isTriggerEnabled || newList == null) return;
        for (SObject record : newList) {
            SObject oldRecord = (oldMap != null) ? oldMap.get(record.Id) : null;
            String oldStatus = (oldRecord != null) ? (String)oldRecord.get(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS) : null;

            if (oldStatus == FEC_Constants.PROCESS_STATUS_NEW) {
                record.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_NEW);
            } else {
                record.put(FEC_Constants.FIELD_PROCESS_CHANGE_STATUS, FEC_Constants.PROCESS_STATUS_UPDATE);
            }
        }
    }
}
