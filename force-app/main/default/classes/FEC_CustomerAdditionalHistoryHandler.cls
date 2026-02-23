/**
 * Handler xử lý logic cho FEC_CustomerAdditionalInfoConfig__c
 * @created: 2026/02/06
 */
public with sharing class FEC_CustomerAdditionalHistoryHandler {

    /**
     * Hàm xử lý ghi Log lịch sử khi Insert hoặc Update Config
     */
    public void createHistoryRecords(List<FEC_CustomerAdditionalInfoConfig__c> newList, Map<Id, FEC_CustomerAdditionalInfoConfig__c> oldMap, Boolean isUpdate) {
        List<FEC_CustomerDataConfigHistory__c> historyRecords = new List<FEC_CustomerDataConfigHistory__c>();
        
        for (FEC_CustomerAdditionalInfoConfig__c config : newList) {
            FEC_CustomerDataConfigHistory__c history = new FEC_CustomerDataConfigHistory__c();
            
            history.FEC_Customers_Data_Config__c = config.Id; 
            history.FEC_KeyIdentifier__c = config.FEC_KeyIdentifier__c;
            history.FEC_FieldID__c = config.FEC_FieldID__c;
            history.FEC_IsActive__c = config.FEC_IsActive__c;
            history.FEC_StartDate__c = config.FEC_StartDate__c;
            history.FEC_EndDate__c = config.FEC_EndDate__c;

            if (isUpdate && config.FEC_Status__c == 'Uploaded') {
                history.FEC_Status__c = 'Reuploaded';
            } else {
                history.FEC_Status__c = config.FEC_Status__c;
            }

            historyRecords.add(history);
        }
        
        if (!historyRecords.isEmpty()) {
            insert historyRecords;
        }
    }
}