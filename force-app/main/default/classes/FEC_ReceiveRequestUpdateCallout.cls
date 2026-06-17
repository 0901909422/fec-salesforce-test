public with sharing class FEC_ReceiveRequestUpdateCallout {

    public static final String API_CONFIG_NAME = 'ReceiveRequestUpdate';
    private static final String API_LOG_NAME = 'FEC_ReceiveRequestUpdateCallout';
    private static final Integer MAX_TRANSACTION_ID_LEN = 36;
    private static final Integer MAX_ORDER_CODE_LEN = 50;
    private static final Integer MAX_STATUS_LEN = 15;
    private static final Integer MAX_STATUS_CODE_LEN = 10;
    private static final Integer MAX_NOTES_LEN = 4000;

    public class RequestWrapper {
        public Map<String, String> headers;
        public List<String> parameters;
        public RequestBody body;
    }

    public class RequestBody {
        public String Status;
        public String OrderCode;
        public String requestDate;
        public String Status_Code;
        public String Notes;
        public String RequestorID;
        public String TransactionId;
    }

    public class ResponseWrapper {
        public String pxObjClass;
        public SysResponse Sys;
        public String errorCode;
        public String errorMessage;
    }

    public class SysResponse {
        public String Code;
        public String Description;
        public String pxObjClass;
        public String RequestDateTime;
        public String TransID;
    }

    public class CalloutResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public Integer httpStatusCode;
        @AuraEnabled public ResponseWrapper response;
        @AuraEnabled public String errorMessage;
    }

    public static CalloutResult sendRequest(RequestBody body) {
        CalloutResult result = new CalloutResult();
        validateRequest(body);
        String endpoint = resolveEndpoint();
        String requestJson = serializeRequest(buildRequest(body));

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod(FEC_ConstantCommon.API_METHOD_POST);
            req.setHeader(
                FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
                FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            );
            req.setBody(requestJson);
            req.setTimeout(FEC_ConstantCommon.HTTP_TIMEOUT_MAX);

            Http http = new Http();
            HttpResponse response = http.send(req);

            result.httpStatusCode = response.getStatusCode();
            result.response = parseResponse(response.getBody(), response.getStatusCode());
            result.isSuccess = isSuccess(result.response) && response.getStatusCode() == FEC_ConstantCommon.HTTP_STATUS_OK;

            if (!result.isSuccess) {
                result.errorMessage = resolveErrorMessage(result.response, response);
            }

            logApiCall(endpoint, requestJson, response, result.errorMessage);
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage();

            HttpResponse syntheticResponse = new HttpResponse();
            syntheticResponse.setStatusCode(FEC_ConstantCommon.ERROR_CODE_500_NUM);
            syntheticResponse.setBody('');
            logApiCall(endpoint, body != null ? JSON.serialize(body) : null, syntheticResponse, e.getMessage());
        }

        return result;
    }

    public static CalloutResult sendRequest(
        String status,
        String orderCode,
        String statusCode,
        String notes,
        String requestDate
    ) {
        RequestBody body = new RequestBody();
        body.Status = status;
        body.OrderCode = orderCode;
        body.Status_Code = statusCode;
        body.Notes = notes;
        body.requestDate = String.isNotBlank(requestDate)
            ? requestDate
            : Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');
        body.RequestorID = FEC_ConstantCommon.REQUESTOR_PEGA_CSM;
        body.TransactionId = String.valueOf(UUID.randomUUID());
        return sendRequest(body);
    }

    @TestVisible
    private static String resolveEndpoint() {
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        if (apiConfig == null || String.isBlank(apiConfig.FEC_Endpoint__c)) {
            throw new CalloutException(System.Label.FEC_MSG_Endpoint_Null);
        }
        return 'callout:FEC_API' + apiConfig.FEC_Endpoint__c;
    }

    @TestVisible
    private static RequestWrapper buildRequest(RequestBody body) {
        RequestWrapper request = new RequestWrapper();
        request.headers = new Map<String, String>{
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        request.parameters = new List<String>();
        request.body = body;
        return request;
    }

    @TestVisible
    private static String serializeRequest(RequestWrapper request) {
        Map<String, Object> bodyMap = new Map<String, Object>{
            'Status' => request.body.Status,
            'OrderCode' => request.body.OrderCode,
            'Date' => request.body.requestDate,
            'Status_Code' => request.body.Status_Code,
            'Notes' => request.body.Notes,
            'RequestorID' => request.body.RequestorID,
            'TransactionId' => request.body.TransactionId
        };

        return JSON.serialize(new Map<String, Object>{
            'headers' => request.headers,
            'parameters' => request.parameters,
            'body' => bodyMap
        });
    }

    @TestVisible
    private static void validateRequest(RequestBody body) {
        if (body == null) {
            throw new CalloutException(System.Label.FEC_CS_CASE_STATUS_REQUEST_INVALID_MSG);
        }

        if (String.isBlank(body.TransactionId)) {
            body.TransactionId = String.valueOf(UUID.randomUUID());
        } else if (body.TransactionId.length() > MAX_TRANSACTION_ID_LEN) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }

        if (String.isBlank(body.RequestorID)) {
            body.RequestorID = FEC_ConstantCommon.REQUESTOR_PEGA_CSM;
        } else if (body.RequestorID.length() > MAX_TRANSACTION_ID_LEN) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        if (String.isBlank(body.requestDate)) {
            body.requestDate = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');
        }

        if (String.isBlank(body.Status)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Status' }));
        }
        if (body.Status.length() > MAX_STATUS_LEN) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'Status', String.valueOf(MAX_STATUS_LEN) }));
        }

        if (String.isBlank(body.OrderCode)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'OrderCode' }));
        }
        if (body.OrderCode.length() > MAX_ORDER_CODE_LEN) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'OrderCode', String.valueOf(MAX_ORDER_CODE_LEN) }));
        }

        if (String.isBlank(body.Status_Code)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Status_Code' }));
        }
        if (body.Status_Code.length() > MAX_STATUS_CODE_LEN) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'Status_Code', String.valueOf(MAX_STATUS_CODE_LEN) }));
        }

        if (String.isNotBlank(body.Notes) && body.Notes.length() > MAX_NOTES_LEN) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'Notes', String.valueOf(MAX_NOTES_LEN) }));
        }
    }

    @TestVisible
    private static ResponseWrapper parseResponse(String responseBody, Integer httpStatusCode) {
        ResponseWrapper response = new ResponseWrapper();

        if (httpStatusCode != FEC_ConstantCommon.HTTP_STATUS_OK) {
            response.errorCode = String.valueOf(httpStatusCode);
            response.errorMessage = 'HTTP ' + httpStatusCode;
            return response;
        }

        if (String.isBlank(responseBody)) {
            response.errorCode = String.valueOf(httpStatusCode);
            response.errorMessage = System.Label.FEC_MSG_Response_Null;
            return response;
        }

        try {
            response = (ResponseWrapper) JSON.deserialize(responseBody, ResponseWrapper.class);
        } catch (Exception e) {
            response.errorCode = String.valueOf(httpStatusCode);
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    public static Boolean isSuccess(ResponseWrapper response) {
        return response != null
            && response.Sys != null
            && response.Sys.Code == '1';
    }

    private static String resolveErrorMessage(ResponseWrapper response, HttpResponse httpResponse) {
        if (response != null && response.Sys != null && String.isNotBlank(response.Sys.Description)) {
            return response.Sys.Description;
        }
        if (response != null && String.isNotBlank(response.errorMessage)) {
            return response.errorMessage;
        }
        return 'HTTP ' + httpResponse.getStatusCode() + ': ' + httpResponse.getBody();
    }

    private static void logApiCall(String endpoint, String requestBody, HttpResponse response, String errorMessage) {
        try {
            FEC_CommonUltils.logApi(
                API_LOG_NAME,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                requestBody,
                response,
                errorMessage
            );
        } catch (Exception e) {
            System.debug(API_LOG_NAME + ' log error: ' + e.getMessage());
        }
    }
}