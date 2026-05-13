/**
 * FEC_CampaignApiCaller
 * Centralized HTTP callout handler for Campaign module.
 * Logs every API call to FEC_API_Log__c via FEC_CommonUltils.logApi().
 */
public with sharing class FEC_CampaignApiCaller {

    private static final Integer MAX_REQUEST_LENGTH = 131072;
    private static final Integer MAX_RESPONSE_LENGTH = 131072;
    private static final Integer MAX_ERROR_LENGTH = 255;

    /**
     * Sends campaign data payload to the campaign API endpoint.
     * Shared by all campaign push batch jobs.
     * Logs the API call (success or failure) to FEC_API_Log__c.
     * @param jsonBody  Serialized JSON payload to send
     * @return HttpResponse from the API, or null when running in test context
     */
    public static HttpResponse sendCampaignData(String jsonBody) {
        String endpoint = FEC_EndpointResolver.resolveEndpoint(FEC_Constants.CAMPAIGN_API_CONFIG_NAME);
        String apiName = FEC_Constants.CAMPAIGN_API_CONFIG_NAME;
        HttpResponse response = null;
        String errorMessage = null;

        try {
            response = doPost(endpoint, apiName, jsonBody);
        } catch (Exception ex) {
            errorMessage = ex.getMessage();
            logApiCall(apiName, endpoint, jsonBody, null, errorMessage);
            throw ex;
        }

        logApiCall(apiName, endpoint, jsonBody, response, errorMessage);
        return response;
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
        HttpRequest tempReq = new HttpRequest();
        FEC_EndpointResolver.applyAuthHeaders(tempReq, configName);
        String apiKeyHeader = tempReq.getHeader('X-API-KEY');
        if (String.isNotBlank(apiKeyHeader)) {
            headers.put('X-API-KEY', apiKeyHeader);
        }
        return FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_Constants.HTTP_METHOD_POST, headers, body);
    }

    /**
     * Logs the API call to FEC_API_Log__c defensively.
     * Truncates request/response bodies to fit field limits.
     * Never throws — failures are logged via System.debug only.
     */
    private static void logApiCall(String apiName, String endpoint, String requestBody, HttpResponse response, String errorMessage) {
        try {
            String truncatedRequest = truncate(requestBody, MAX_REQUEST_LENGTH);
            String truncatedError = truncate(errorMessage, MAX_ERROR_LENGTH);
            FEC_CommonUltils.logApi(
                apiName,
                endpoint,
                FEC_Constants.HTTP_METHOD_POST,
                truncatedRequest,
                response,
                truncatedError
            );
        } catch (Exception ex) {
            System.debug('>>> [CampaignApiCaller] API log insert failed: ' + ex.getMessage());
        }
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
