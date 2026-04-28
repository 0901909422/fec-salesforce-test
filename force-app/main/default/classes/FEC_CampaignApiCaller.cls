/**
 * FEC_CampaignApiCaller
 * Centralized HTTP callout handler for Campaign module.
 */
public with sharing class FEC_CampaignApiCaller {

    /**
     * Sends campaign data payload to the campaign API endpoint.
     * Shared by FEC_PushCampaignDataBatch and FEC_ScheduledPushCampaignDataBatch.
     * @param jsonBody  Serialized JSON payload to send
     * @return HttpResponse from the API, or null when running in test context
     */
    public static HttpResponse sendCampaignData(String jsonBody) {
        return doPost(
            FEC_EndpointResolver.resolveEndpoint(FEC_Constants.CAMPAIGN_API_CONFIG_NAME),
            FEC_Constants.CAMPAIGN_API_CONFIG_NAME,
            jsonBody
        );
    }

    // ─── Private Helpers ───────────────────────────────────────────

    /**
     * Executes a POST request with auth headers from FEC_API_Config__mdt.
     */
    private static HttpResponse doPost(String endpoint, String configName, String body) {
        if (Test.isRunningTest()) {
            return null;
        }
        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => FEC_Constants.HTTP_CONTENT_TYPE_JSON
        };
        FEC_API_Config__mdt cfg = FEC_API_Config__mdt.getInstance(configName);
        if (cfg != null && !cfg.FEC_Use_Named_Credential__c && String.isNotBlank(cfg.FEC_API_Key__c)) {
            headers.put('X-API-KEY', cfg.FEC_API_Key__c);
        }
        return FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_Constants.HTTP_METHOD_POST, headers, body);
    }
}
