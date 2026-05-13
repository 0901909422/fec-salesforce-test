// tungnm37: Controller cho NOC Channel Config tab
public with sharing class FEC_NocChannelConfigController {

    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> searchChannels(String searchTerm) {
        // tungnm37 fix: tìm kiếm starts-with theo FEC_Channel_Vietnamese_name__c (không dùng % ở đầu)
        String q = String.isBlank(searchTerm) ? '%' : searchTerm + '%';
        return [
            SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
              AND FEC_Channel_Vietnamese_name__c LIKE :q
            ORDER BY FEC_Channel_Vietnamese_name__c ASC
            LIMIT 20
        ];
    }

    @AuraEnabled
    public static String getChannelIds(String nocId) {
        if (String.isBlank(nocId)) return null;
        List<FEC_Nature_of_Case__c> nocs = [
            SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :nocId LIMIT 1
        ];
        return nocs.isEmpty() ? null : nocs[0].FEC_Channel__c;
    }

    @AuraEnabled
    public static void saveChannelIds(String nocId, String channelIds) {
        if (String.isBlank(nocId)) return;
        Database.update(
            new FEC_Nature_of_Case__c(Id = nocId, FEC_Channel__c = channelIds),
            AccessLevel.SYSTEM_MODE
        );
    }
}
