public with sharing class FEC_ChannelFunctionService {
    private static final String FN_GET_NATURE_OF_CASE = 'GET_NATURE_OF_CASE';
    private static final String FN_SELF_SERVICE_FLAG = 'SELF_SERVICE_FLAG';
    private static final String FN_UPDATE_CASE_STATUS = 'UPDATE_CASE_STATUS';

    /**
     * Common checker for API/channel capability.
     * Input: channel Name + function name (Get_Nature_Of_Case / Self_Service_Flag / Update_Case_Status).
     */
    public static Boolean isFunctionAllowed(String channelName, String functionName) {
        if (String.isBlank(channelName) || String.isBlank(functionName)) {
            return false;
        }

        List<FEC_Channel__c> channels = [
            SELECT Id,
                   FEC_Channel_Status__c,
                   FEC_Get_Nature_Of_Case__c,
                   FEC_Self_Service_Flag__c,
                   FEC_Update_Case_Status__c
            FROM FEC_Channel__c
            WHERE Name = :channelName
              AND FEC_Channel_Status__c = true
            LIMIT 1
        ];
        if (channels.isEmpty()) {
            return false;
        }

        FEC_Channel__c channel = channels[0];
        if (!isFunctionEnabled(channel, normalizeFunctionName(functionName))) {
            return false;
        }

        return existsNocContainingChannelId(channel.Id);
    }

    private static Boolean isFunctionEnabled(FEC_Channel__c channel, String normalizedFunctionName) {
        if (normalizedFunctionName == FN_GET_NATURE_OF_CASE) {
            return channel.FEC_Get_Nature_Of_Case__c == true;
        }
        if (normalizedFunctionName == FN_SELF_SERVICE_FLAG) {
            return channel.FEC_Self_Service_Flag__c == true;
        }
        if (normalizedFunctionName == FN_UPDATE_CASE_STATUS) {
            return channel.FEC_Update_Case_Status__c == true;
        }
        return false;
    }

    private static String normalizeFunctionName(String functionName) {
        return String.isBlank(functionName)
            ? ''
            : functionName.trim().toUpperCase().replace(' ', '_');
    }

    private static Boolean existsNocContainingChannelId(Id channelId) {
        if (channelId == null) {
            return false;
        }

        String token = String.valueOf(channelId);
        String likeToken = '%' + token + '%';
        List<FEC_Nature_of_Case__c> candidates = [
            SELECT Id, FEC_Channel__c
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Channel__c != null
              AND FEC_Channel__c LIKE :likeToken
            LIMIT 200
        ];

        for (FEC_Nature_of_Case__c noc : candidates) {
            if (csvContainsToken(noc.FEC_Channel__c, token)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean csvContainsToken(String csv, String token) {
        if (String.isBlank(csv) || String.isBlank(token)) {
            return false;
        }
        for (String item : csv.split(',')) {
            if (item != null && item.trim() == token) {
                return true;
            }
        }
        return false;
    }
}
