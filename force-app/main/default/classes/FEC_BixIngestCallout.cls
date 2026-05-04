public with sharing class FEC_BixIngestCallout {

    public static final String API_CONFIG_NAME = 'FEC_BIX_Ingest';
    private static final String API_LOG_NAME = 'FEC_BixIngestCallout';

    public class BixIngestResult {
        public Boolean isSuccess;
        public Integer httpStatusCode;
        public String responseBody;
        public String errorMessage;
    }

    @TestVisible
    private static String resolveEndpoint() {
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        if (apiConfig == null || String.isBlank(apiConfig.FEC_Endpoint__c)) {
            throw new CalloutException(System.Label.FEC_MSG_Endpoint_Null);
        }
        return 'callout:FEC_API' + apiConfig.FEC_Endpoint__c;
    }

    public static BixIngestResult sendRequest(String jsonPayload) {
        BixIngestResult result = new BixIngestResult();
        String endpoint = resolveEndpoint();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod(FEC_ConstantCommon.API_METHOD_POST);
            req.setHeader(FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE, FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
            req.setBody(jsonPayload);
            req.setTimeout(FEC_ConstantCommon.HTTP_TIMEOUT_MAX);

            Http http = new Http();
            HttpResponse response = http.send(req);

            result.httpStatusCode = response.getStatusCode();
            result.responseBody = response.getBody();
            result.isSuccess = (response.getStatusCode() == FEC_ConstantCommon.HTTP_STATUS_OK);

            if (!result.isSuccess) {
                result.errorMessage = 'HTTP ' + response.getStatusCode() + ': ' + response.getBody();
            }

            logApiCall(endpoint, jsonPayload, response, result.isSuccess ? null : result.errorMessage);

        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();

            HttpResponse syntheticResponse = new HttpResponse();
            syntheticResponse.setStatusCode(FEC_ConstantCommon.ERROR_CODE_500_NUM);
            syntheticResponse.setBody('');
            logApiCall(endpoint, jsonPayload, syntheticResponse, e.getMessage());
        }

        return result;
    }

    private static void logApiCall(String endpoint, String requestBody, HttpResponse response, String errorMessage) {
        try {
            System.debug('=== BIX Ingest API Log ===');
            System.debug('Endpoint: ' + endpoint);
            System.debug('Request Body: ' + requestBody);
            System.debug('Status: ' + response.getStatusCode());
            System.debug('Success: ' + (response.getStatusCode() == FEC_ConstantCommon.HTTP_STATUS_OK));
            if (errorMessage != null) {
                System.debug('Error: ' + errorMessage);
            }
        } catch (Exception e) {
            System.debug('BIX log error: ' + e.getMessage());
        }
    }
}
