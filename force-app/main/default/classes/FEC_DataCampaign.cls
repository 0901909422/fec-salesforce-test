public with sharing class FEC_DataCampaign {
    @AuraEnabled public String campaignID;
    @AuraEnabled public String appID;
    @AuraEnabled public String accountOrContractNumber;
    @AuraEnabled public String productLine;
    
    @AuraEnabled public Decimal number1;
    @AuraEnabled public Decimal number2;
    @AuraEnabled public Decimal number3;
    @AuraEnabled public Decimal number4;
    @AuraEnabled public Decimal number5;
    
    @AuraEnabled public String string1;
    @AuraEnabled public String string2;
    @AuraEnabled public String string3;
    @AuraEnabled public String string4;
    @AuraEnabled public String string5;
    
    @AuraEnabled public Datetime dateTime1;
    @AuraEnabled public Datetime dateTime2;
    @AuraEnabled public Datetime dateTime3;
    
    @AuraEnabled public String recordID;
    @AuraEnabled public String recordStatus;
    @AuraEnabled public Decimal recordLifetime;
    @AuraEnabled public Decimal recordCurrentLifetime;
    @AuraEnabled public Decimal maxCallAttempt;
    @AuraEnabled public Decimal currentCallAttempt;
    @AuraEnabled public String campaignCallingList;
    @AuraEnabled public String systemName;
    
    @AuraEnabled public DateTime createDateTime;
    @AuraEnabled public DateTime updateDateTime;
    @AuraEnabled public String createBy;
    @AuraEnabled public String updateBy;

    @AuraEnabled public Boolean isExistingRecords = false;
    @AuraEnabled public Boolean isCallback = false;

    public FEC_DataCampaign() {}

    /**
     * Factory method: tạo DTO từ SObject.
     * Thay thế mapToModel() trùng lặp trong các batch class.
     * @param record FEC_DataCampaign__c SObject to map
     * @return FEC_DataCampaign DTO with all fields populated
     * @throws IllegalArgumentException if record is null
     */
    public static FEC_DataCampaign fromSObject(FEC_DataCampaign__c record) {
        if (record == null) {
            throw new IllegalArgumentException(System.Label.FEC_Campaign_Error_RecordNull);
        }
        FEC_DataCampaign m = new FEC_DataCampaign();
        m.campaignID = record.FEC_CS_Campaign__r?.FEC_Campaign__r?.FEC_CampaignId__c;
        m.appID = record.FEC_AppId__c;
        m.accountOrContractNumber = record.FEC_AccountOrContractNumber__c;
        m.productLine = record.FEC_ProductLine__c;
        m.number1 = record.FEC_Number1__c;
        m.number2 = record.FEC_Number2__c;
        m.number3 = record.FEC_Number3__c;
        m.number4 = record.FEC_Number4__c;
        m.number5 = record.FEC_Number5__c;
        m.string1 = record.FEC_String1__c;
        m.string2 = record.FEC_String2__c;
        m.string3 = record.FEC_String3__c;
        m.string4 = record.FEC_String4__c;
        m.string5 = record.FEC_String5__c;
        m.dateTime1 = record.FEC_DateTime1__c;
        m.dateTime2 = record.FEC_DateTime2__c;
        m.dateTime3 = record.FEC_DateTime3__c;
        m.recordID = record.FEC_RecordId__c;
        m.recordStatus = record.FEC_RecordStatus__c;
        m.createDateTime = record.CreatedDate;
        m.createBy = record.CreatedBy?.Name;
        m.updateDateTime = record.LastModifiedDate;
        m.updateBy = record.LastModifiedBy?.Name;
        m.campaignCallingList = record.FEC_CampaignCallingList__c;
        m.maxCallAttempt = record.FEC_MaxCallAttempt__c;
        m.recordLifetime = record.FEC_RecordLifetime__c;
        m.currentCallAttempt = record.FEC_CurrentCallAttempt__c;
        m.recordCurrentLifetime = record.FEC_RecordCurrentLifetime__c;
        m.isExistingRecords = false;
        m.isCallback = false;
        return m;
    }
}