public with sharing class FEC_ChannelController {
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Channel__c> getChannels() {
        return [SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c, FEC_Channel_Status__c FROM FEC_MDM_Channel__c ORDER BY CreatedDate DESC];
    }
    
    @AuraEnabled
    public static void deleteChannel(Id recordId) {
        delete [SELECT Id FROM FEC_MDM_Channel__c WHERE Id = :recordId];
    }
}
