/**
 * FEC_CampaignApiCaller
 * Centralized HTTP callout handler for Campaign module.
 * Replaces duplicated callout logic in batch classes.
 */
public with sharing class FEC_CampaignApiCaller {

    /**
     * Sends campaign data payload to the campaign API endpoint.
     * Shared by FEC_PushCampaignDataBatch and FEC_ScheduledPushCampaignDataBatch.
     * @param jsonBody  Serialized JSON payload to send
     * @return HttpResponse from the API, or null when running in test context
     */
    public static HttpResponse sendCampaignData(String jsonBody) {
        return doPost(FEC_Constants.CAMPAIGN_API_ENDPOINT, jsonBody);
    }

    /**
     * Calls the check-status API with a list of record IDs.
     * Used by FEC_CheckCampaignStatusBatch.
     * @param recordIds  List of record IDs to check status for
     * @return Deserialized StatusResponse, or null on HTTP error
     */
    public static FEC_CampaignApiResponse.StatusResponse checkCampaignStatus(
        List<String> recordIds
    ) {
        if (recordIds == null || recordIds.isEmpty()) {
            return null;
        }
        Map<String, Object> payload = new Map<String, Object>{
            'recordIDs' => recordIds
        };
        HttpResponse response = doPost(
            FEC_Constants.CAMPAIGN_CHECK_STATUS_ENDPOINT,
            JSON.serialize(payload)
        );
        if (response == null || !isSuccessStatus(response.getStatusCode())) {
            return null;
        }
        return (FEC_CampaignApiResponse.StatusResponse) JSON.deserialize(
            response.getBody(), FEC_CampaignApiResponse.StatusResponse.class
        );
    }

    /**
     * Calls the get-calling-list-result API with a set of account numbers.
     * Used by FEC_GetCallingListResultBatch.
     * @param accountNumbers  Set of account or contract numbers to query
     * @return Deserialized CallingListResponse, or null on HTTP error
     */
    public static FEC_CampaignApiResponse.CallingListResponse getCallingListResult(
        Set<String> accountNumbers
    ) {
        if (accountNumbers == null || accountNumbers.isEmpty()) {
            return null;
        }
        Map<String, Object> payload = new Map<String, Object>{
            'accountOrContractNumbers' => new List<String>(accountNumbers)
        };
        HttpResponse response = doPost(
            FEC_Constants.CAMPAIGN_CALLING_LIST_ENDPOINT,
            JSON.serialize(payload)
        );
        if (response == null || !isSuccessStatus(response.getStatusCode())) {
            return null;
        }
        return (FEC_CampaignApiResponse.CallingListResponse) JSON.deserialize(
            response.getBody(), FEC_CampaignApiResponse.CallingListResponse.class
        );
    }

    // ─── Private Helpers ───────────────────────────────────────────

    /**
     * Executes a POST request to the given endpoint with the given body.
     * Delegates to FEC_CommonUltils.calloutApi() for centralized HTTP handling.
     * Returns null when running in test context.
     */
    private static HttpResponse doPost(String endpoint, String body) {
        if (Test.isRunningTest()) {
            return null;
        }
        return FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_Constants.HTTP_METHOD_POST,
            FEC_Constants.HTTP_CONTENT_TYPE_JSON,
            null,
            null,
            body
        );
    }

    /**
     * Checks whether an HTTP status code indicates success (200 or 201).
     */
    private static Boolean isSuccessStatus(Integer statusCode) {
        return statusCode == FEC_Constants.HTTP_STATUS_OK
            || statusCode == FEC_Constants.HTTP_STATUS_CREATED;
    }
}
