public with sharing class FEC_ChannelFunctionService {
    private static final String FN_GET_NATURE_OF_CASE = 'GET_NATURE_OF_CASE';
    /** CamelCase input: GetNatureOfCase */
    private static final String FN_GET_NATURE_OF_CASE_COMPACT = 'GETNATUREOFCASE';
    private static final String FN_SELF_SERVICE_FLAG = 'SELF_SERVICE_FLAG';
    private static final String FN_UPDATE_CASE_STATUS = 'UPDATE_CASE_STATUS';
    /** CamelCase input: UpdateCaseStatus */
    private static final String FN_UPDATE_CASE_STATUS_COMPACT = 'UPDATECASESTATUS';
    private static final String FN_CANCEL_CASE = 'CANCEL_CASE';
    private static final String FN_CANCEL_CASE_NOSPACES = 'CANCELCASE';

    /**
     * Common checker for API/channel capability.
     * First argument: FEC_Channel__c.Name or FEC_Channel_ID__c (e.g. FEMobile).
     * Second argument maps to FEC_Channel__c checkboxes (camelCase or legacy underscore forms):
     * GetNatureOfCase / Get_Nature_Of_Case -> FEC_Get_Nature_Of_Case__c;
     * UpdateCaseStatus / Update_Case_Status -> FEC_Update_Case_Status__c;
     * CancelCase / Cancel_Case -> FEC_Cancel_Case__c. Self_Service_Flag -> FEC_Self_Service_Flag__c.
     * CancelCase: true when channel is active and checkbox is true (no Nature of Case required).
     * Other functions: same checkboxes plus at least one Nature of Case whose FEC_Channel__c includes this channel Id.
     */
    public static Boolean isFunctionAllowed(String channelNameOrId, String functionName) {
        if (String.isBlank(channelNameOrId) || String.isBlank(functionName)) {
            return false;
        }

        List<FEC_Channel__c> channels = [
            SELECT Id,
                   FEC_Channel_Status__c,
                   FEC_Get_Nature_Of_Case__c,
                   FEC_Self_Service_Flag__c,
                   FEC_Update_Case_Status__c,
                   FEC_Cancel_Case__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
              AND (Name = :channelNameOrId OR FEC_Channel_ID__c = :channelNameOrId)
            LIMIT 1
        ];
        if (channels.isEmpty()) {
            return false;
        }

        FEC_Channel__c channel = channels[0];
        String normalizedFn = normalizeFunctionName(functionName);
        if (!isFunctionEnabled(channel, normalizedFn)) {
            return false;
        }

        if (isCancelCaseFunction(normalizedFn)) {
            return true;
        }

        return existsNocContainingChannelId(channel.Id);
    }

    private static Boolean isCancelCaseFunction(String normalizedFunctionName) {
        return normalizedFunctionName == FN_CANCEL_CASE ||
            normalizedFunctionName == FN_CANCEL_CASE_NOSPACES;
    }

    private static Boolean isGetNatureOfCaseFunction(String normalizedFunctionName) {
        return normalizedFunctionName == FN_GET_NATURE_OF_CASE ||
            normalizedFunctionName == FN_GET_NATURE_OF_CASE_COMPACT;
    }

    private static Boolean isUpdateCaseStatusFunction(String normalizedFunctionName) {
        return normalizedFunctionName == FN_UPDATE_CASE_STATUS ||
            normalizedFunctionName == FN_UPDATE_CASE_STATUS_COMPACT;
    }

    private static Boolean isFunctionEnabled(FEC_Channel__c channel, String normalizedFunctionName) {
        if (isGetNatureOfCaseFunction(normalizedFunctionName)) {
            return channel.FEC_Get_Nature_Of_Case__c == true;
        }
        if (normalizedFunctionName == FN_SELF_SERVICE_FLAG) {
            return channel.FEC_Self_Service_Flag__c == true;
        }
        if (isUpdateCaseStatusFunction(normalizedFunctionName)) {
            return channel.FEC_Update_Case_Status__c == true;
        }
        if (isCancelCaseFunction(normalizedFunctionName)) {
            return channel.FEC_Cancel_Case__c == true;
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
