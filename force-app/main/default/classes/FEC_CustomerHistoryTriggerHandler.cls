/**
 * Handler cho trigger FEC_Customer_History__c: đồng bộ Sales Channel từ FEC_Sales_Logic__c.
 */
public with sharing class FEC_CustomerHistoryTriggerHandler {

    /**
     * Đồng bộ FEC_Sales_Channel__c / FEC_Sales_Sub_Channel__c theo FEC_Sales_Logic__c khi mã CC/DSA/TSA thay đổi.
     * @param newList Danh sách bản ghi sau insert/update
     * @param oldMap Map bản ghi trước update; null khi insert
     * @param isUpdate true nếu context update
     */
    public void syncSalesChannelFromSalesLogic(List<FEC_Customer_History__c> newList, Map<Id, FEC_Customer_History__c> oldMap, Boolean isUpdate) {
        List<FEC_Customer_History__c> toSync = new List<FEC_Customer_History__c>();
        for (FEC_Customer_History__c ch : newList) {
            if (!isUpdate) {
                toSync.add(ch);
                continue;
            }
            FEC_Customer_History__c oldRow = oldMap.get(ch.Id);
            if (oldRow.FEC_CC_Code__c != ch.FEC_CC_Code__c
                || oldRow.FEC_DSA_Code__c != ch.FEC_DSA_Code__c
                || oldRow.FEC_TSA_Code__c != ch.FEC_TSA_Code__c) {
                toSync.add(ch);
            }
        }

        if (!toSync.isEmpty()) {
            FEC_SalesChannelFromApplicationService.syncCustomerHistoryFromSalesLogic(toSync);
        }
    }
}
