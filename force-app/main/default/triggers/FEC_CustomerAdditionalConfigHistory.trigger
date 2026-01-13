trigger FEC_CustomerAdditionalConfigHistory on FEC_CustomerAdditionalInfoConfig__c (after insert, after update) {
    List<FEC_CustomerDataConfigHistory__c> historyRecords = new List<FEC_CustomerDataConfigHistory__c>();
    
    for (FEC_CustomerAdditionalInfoConfig__c config : Trigger.new) {
        FEC_CustomerDataConfigHistory__c history = new FEC_CustomerDataConfigHistory__c();
        
        history.FEC_Customers_Data_Config__c = config.Id; 
        history.FEC_KeyIdentifier__c = config.FEC_KeyIdentifier__c;
        history.FEC_FieldID__c = config.FEC_FieldID__c;
        history.FEC_Status__c = config.FEC_Status__c === 'Uploaded' && Trigger.isUpdate ? 'Reuploaded' : config.FEC_Status__c;
        history.FEC_IsActive__c = config.FEC_IsActive__c;
        history.FEC_StartDate__c = config.FEC_StartDate__c;
        history.FEC_EndDate__c = config.FEC_EndDate__c;

        historyRecords.add(history);
    }
    
    // Insert danh sách lịch sử (Bulkify)
    if (!historyRecords.isEmpty()) {
        insert historyRecords;
    }
}