public class FEC_DataCampaignTriggerHandler {
    /**
     * Xử lý logic trước khi bản ghi được cập nhật
     */
    public static void handleBeforeUpdate(List<FEC_DataCampaign__c> newList, Map<Id, FEC_DataCampaign__c> oldMap) {
        for (FEC_DataCampaign__c record : newList) {
            FEC_DataCampaign__c oldRecord = oldMap.get(record.Id);
            
            if (record.FEC_SendToCommsDB__c != null && oldRecord.FEC_SendToCommsDB__c == null) {
                record.FEC_IsPushed__c = true;
            }
        }
    }
}