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

    public FEC_DataCampaign() {}
}