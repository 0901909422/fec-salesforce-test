public with sharing class FEC_ChannelFunctionService {
    private static final String FN_CANCEL_CS_CASE = 'CANCELCSCASE';
    private static final String FN_GET_CS_MASTER_DATA = 'GETCSMASTERDATA';
    private static final String FN_GET_CS_MASTER_DATA_BY_CODE = 'GETCSMASTERDATABYCODE';
    private static final String FN_CREATE_CS_CASE =
        FEC_ConstantCommon.MY_CASE_FUNCTION_CREATE_CS_CASE.toUpperCase();
    private static final String FN_GET_CS_CASE_STATUS = 'GETCSCASESTATUS';

    /**
     * Kiểm tra channel (Name hoặc FEC_Channel_ID__c) có được phép gọi My Case API function hay không.
     *
     * 1. FEC_Channel__c tồn tại và FEC_Channel_Status__c = true
     * 2. Checkbox tương ứng functionName = true:
     *    - CancelCSCase -> FEC_Cancel_Case__c
     *    - GetCSMasterData / GetCSMasterDataByCode / CreateCSCase -> FEC_Get_Nature_Of_Case__c
     *    - GetCSCaseStatus -> FEC_Update_Case_Status__c
     */
    public static Boolean isFunctionAllowed(String channelNameOrId, String functionName) {
        if (String.isBlank(channelNameOrId) || String.isBlank(functionName)) {
            return false;
        }

        List<FEC_Channel__c> channels = [
            SELECT FEC_Cancel_Case__c,
                   FEC_Get_Nature_Of_Case__c,
                   FEC_Update_Case_Status__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
              AND (Name = :channelNameOrId OR FEC_Channel_ID__c = :channelNameOrId)
            LIMIT 1
        ];
        if (channels.isEmpty()) {
            return false;
        }

        return isFunctionCheckboxEnabled(channels[0], normalizeFunctionName(functionName));
    }

    private static Boolean isFunctionCheckboxEnabled(
        FEC_Channel__c channel,
        String normalizedFunctionName
    ) {
        if (normalizedFunctionName == FN_CANCEL_CS_CASE) {
            return channel.FEC_Cancel_Case__c == true;
        }
        if (normalizedFunctionName == FN_GET_CS_MASTER_DATA
            || normalizedFunctionName == FN_GET_CS_MASTER_DATA_BY_CODE
            || normalizedFunctionName == FN_CREATE_CS_CASE) {
            return channel.FEC_Get_Nature_Of_Case__c == true;
        }
        if (normalizedFunctionName == FN_GET_CS_CASE_STATUS) {
            return channel.FEC_Update_Case_Status__c == true;
        }
        return false;
    }

    private static String normalizeFunctionName(String functionName) {
        if (String.isBlank(functionName)) {
            return '';
        }
        return functionName.trim().replace(' ', '').replace('_', '').toUpperCase();
    }
}