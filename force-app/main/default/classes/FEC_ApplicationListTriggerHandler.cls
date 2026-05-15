/**
 * Handler cho trigger FEC_Application_List__c: đồng bộ Sales Channel lên FEC_Customer_History__c.
 */
public with sharing class FEC_ApplicationListTriggerHandler {

    /**
     * Đồng bộ FEC_Sales_Channel__c / FEC_Sales_Sub_Channel__c trên FEC_Customer_History__c khi Application List thay đổi.
     * @param newList Danh sách bản ghi sau insert/update
     * @param oldMap Map bản ghi trước update; null khi insert
     * @param isUpdate true nếu context update
     */
    public void syncSalesChannelFromApplicationList(List<FEC_Application_List__c> newList, Map<Id, FEC_Application_List__c> oldMap, Boolean isUpdate) {
        Set<Id> chIds = new Set<Id>();
        for (FEC_Application_List__c al : newList) {
            if (al.FEC_Customer_History__c == null) {
                continue;
            }
            if (!isUpdate) {
                chIds.add(al.FEC_Customer_History__c);
                continue;
            }
            FEC_Application_List__c oldRow = oldMap.get(al.Id);
            if (oldRow.FEC_CC_Code__c != al.FEC_CC_Code__c
                || oldRow.FEC_DSA_Code__c != al.FEC_DSA_Code__c
                || oldRow.FEC_TSA_Code__c != al.FEC_TSA_Code__c
                || oldRow.FEC_Customer_History__c != al.FEC_Customer_History__c) {
                if (oldRow.FEC_Customer_History__c != null) {
                    chIds.add(oldRow.FEC_Customer_History__c);
                }
                chIds.add(al.FEC_Customer_History__c);
            }
        }

        if (!chIds.isEmpty()) {
            FEC_SalesChannelFromApplicationService.syncCustomerHistoryFromApplicationListParents(chIds);
        }
    }
}
