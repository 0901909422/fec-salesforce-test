/**
 * Callout: Disb_Status_Inquiry / GetDisbInfoByAcct (JSON envelope: headers, parameters, body).
 * Maps response Applications[].Application to FEC_Pending_Disbursement__c fields at integration layer.
 */
public with sharing class FEC_GetDisbInfoByAcctCallout {

    private static final String API_CONFIG_NAME = 'FEC_GetDisb_Info_By_Acct';

    private static ResponseLog responseLog;

    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(String apiName, String endpoint, String method, String requestBody, HttpResponse response, String errorMessage) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }

    private static void stashDisbApiLog(GetDisbInfoByAcctExecutionResult result) {
        responseLog = new ResponseLog(
            'FEC_GetDisbInfoByAcctCallout',
            result.endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            result.requestPayload,
            result.httpResponse,
            result.logErrorMessage
        );
    }

    public static void logApiResponse() {
        if (responseLog != null) {
            FEC_CommonUltils.logApi(
                responseLog.apiName,
                responseLog.endpoint,
                responseLog.method,
                responseLog.requestBody,
                responseLog.response,
                responseLog.errorMessage
            );
        }
    }

    //=============== RESPONSE ===============//

    public class GetDisbInfoByAcctExecutionResult {
        public GetDisbInfoByAcctResponse response;
        public String endpoint;
        public String requestPayload;
        public HttpResponse httpResponse;
        public String logErrorMessage;
    }

    public class GetDisbInfoByAcctResponse {
        public String pxObjClass;
        public List<ApplicationsEntry> Applications;
        public Sys2Block Sys2;
        public String errorCode;
        public String errorMessage;
    }

    public class Sys2Block {
        public String Code2;
        public String DateTime_x;
        public String Description;
        public String pxObjClass;
        public String TransID;
    }

    public class ApplicationsEntry {
        public String pxObjClass;
        public ApplicationDetail Application;
    }

    public class ApplicationDetail {
        public String AccountNumber;
        public String ApplicationID;
        public String Channel;
        public String DisbAmount;
        public String DisbStatus;
        public String pxObjClass;
        public String RequestedDt;
        public String AppStatusLos;
        public String UpdatedDt;
    }

    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }

    public class ResultWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String transId;
        @AuraEnabled public String sysCode2;
        @AuraEnabled public String sysDescription;
        @AuraEnabled public List<ApplicationDetailWrapper> applications;

        public ResultWrapper() {
            this.isSuccess = false;
            this.applications = new List<ApplicationDetailWrapper>();
        }
    }

    public class ApplicationDetailWrapper {
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String channel;
        @AuraEnabled public String disbAmount;
        @AuraEnabled public String disbStatus;
        @AuraEnabled public String requestedDt;
        @AuraEnabled public String appStatusLos;
        @AuraEnabled public String updatedDt;

        public ApplicationDetailWrapper() {}

        public ApplicationDetailWrapper(ApplicationDetail d) {
            if (d != null) {
                this.accountNumber = d.AccountNumber;
                this.applicationId = d.ApplicationID;
                this.channel = d.Channel;
                this.disbAmount = d.DisbAmount;
                this.disbStatus = d.DisbStatus;
                this.requestedDt = d.RequestedDt;
                this.appStatusLos = d.AppStatusLos;
                this.updatedDt = d.UpdatedDt;
            }
        }
    }

    //=============== REQUEST ===============//

    public static String buildRequestPayload(
        String transId,
        String dateTimeHeader,
        String requestorId,
        String accountNumber,
        Integer ageOfRecords
    ) {
        Map<String, Object> headerMap = new Map<String, Object>{
            'TransID' => transId,
            'DateTime' => dateTimeHeader,
            'RequestorID' => requestorId,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        Map<String, Object> bodyMap;
        if (ageOfRecords != null) {
            bodyMap = new Map<String, Object>{
                'AgeOfRecords' => ageOfRecords,
                'AccountNumber' => accountNumber
            };
        } else {
            bodyMap = new Map<String, Object>{
                'AccountNumber' => accountNumber
            };
        }
        Map<String, Object> root = new Map<String, Object>{
            'headers' => headerMap,
            'parameters' => new List<Object>(),
            'body' => bodyMap
        };
        return JSON.serialize(root);
    }

    private static String resolveDisbInfoEndpoint() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        return apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
    }

    private static GetDisbInfoByAcctResponse disbErrorResponse(String errorCode, String errorMessage) {
        GetDisbInfoByAcctResponse err = new GetDisbInfoByAcctResponse();
        err.errorCode = errorCode;
        err.errorMessage = errorMessage;
        return err;
    }

    public static HttpResponse sendRequest(
        String jsonPayload,
        String transId,
        String dateTimeHeader,
        String requestorId
    ) {
        String endpoint = resolveDisbInfoEndpoint();

        Map<String, String> httpHeaders = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'TransID' => transId,
            'DateTime' => dateTimeHeader,
            'RequestorID' => requestorId
        };

        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            httpHeaders,
            jsonPayload
        );
    }

    public static GetDisbInfoByAcctResponse parseResponseBody(String responseBody, Integer httpStatus) {
        GetDisbInfoByAcctResponse response = new GetDisbInfoByAcctResponse();
        if (httpStatus != null && httpStatus != 200) {
            response.errorCode = String.valueOf(httpStatus);
            response.errorMessage = String.format(
                System.Label.FEC_MSG_HTTP_Error,
                new List<String>{String.valueOf(httpStatus)}
            );
            return response;
        }
        if (String.isBlank(responseBody)) {
            response.errorCode = 'EMPTY';
            response.errorMessage = System.Label.FEC_MSG_Response_Null;
            return response;
        }
        try {
            String normalized = responseBody.replace('"DateTime":', '"DateTime_x":');
            response = (GetDisbInfoByAcctResponse) JSON.deserialize(
                normalized,
                FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctResponse.class
            );
        } catch (JSONException e) {
            response.errorCode = 'JSON_PARSE_ERROR';
            response.errorMessage = String.format(
                System.Label.FEC_MSG_Parse_JSON_Error,
                new List<String>{e.getMessage()}
            );
        }
        return response;
    }

    public static GetDisbInfoByAcctResponse getDisbInfoByAcct(String accountNumber, Integer ageOfRecords) {
        return getDisbInfoByAcctExecutionResult(accountNumber, ageOfRecords).response;
    }

    public static GetDisbInfoByAcctExecutionResult getDisbInfoByAcctExecutionResult(String accountNumber, Integer ageOfRecords) {
        return getDisbInfoByAcctExecutionResult(
            accountNumber,
            ageOfRecords,
            String.valueOf(UUID.randomUUID()),
            Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX),
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM
        );
    }

    public static GetDisbInfoByAcctExecutionResult getDisbInfoByAcctExecutionResult(
        String accountNumber,
        Integer ageOfRecords,
        String transId,
        String dateTimeHeader,
        String requestorId
    ) {
        GetDisbInfoByAcctExecutionResult result = new GetDisbInfoByAcctExecutionResult();
        result.endpoint = resolveDisbInfoEndpoint();
        ValidationResult reqVal = validateRequest(accountNumber);
        if (!reqVal.isValid) {
            HttpResponse synVal = new HttpResponse();
            synVal.setStatusCode(400);
            synVal.setBody('');
            result.requestPayload = null;
            result.httpResponse = synVal;
            result.logErrorMessage = reqVal.errorMessage;
            result.response = disbErrorResponse('VALIDATION_ERROR', reqVal.errorMessage);
            stashDisbApiLog(result);
            return result;
        }
        ValidationResult headerVal = validateRequestHeaders(
            transId,
            dateTimeHeader,
            requestorId
        );
        if (!headerVal.isValid) {
            HttpResponse synHdr = new HttpResponse();
            synHdr.setStatusCode(400);
            synHdr.setBody('');
            result.requestPayload = null;
            result.httpResponse = synHdr;
            result.logErrorMessage = headerVal.errorMessage;
            result.response = disbErrorResponse('HEADER_VALIDATION_ERROR', headerVal.errorMessage);
            stashDisbApiLog(result);
            return result;
        }
        String payload = buildRequestPayload(transId, dateTimeHeader, requestorId, accountNumber, ageOfRecords);
        result.requestPayload = payload;
        HttpResponse resp;
        String callExMsg = null;
        try {
            resp = sendRequest(
                payload,
                transId,
                dateTimeHeader,
                requestorId
            );
        } catch (Exception e) {
            callExMsg = e.getMessage();
            resp = new HttpResponse();
            resp.setStatusCode(0);
            resp.setBody('');
        }
        result.httpResponse = resp;
        result.logErrorMessage = callExMsg;
        if (String.isNotBlank(callExMsg)) {
            result.response = disbErrorResponse(
                'CALLOUT_ERROR',
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{callExMsg})
            );
        } else {
            result.response = parseResponseBody(
                resp == null ? null : resp.getBody(),
                resp == null ? null : resp.getStatusCode()
            );
        }
        stashDisbApiLog(result);
        return result;
    }

    public static ValidationResult validateRequest(String accountNumber) {
        if (String.isBlank(accountNumber)) {
            return new ValidationResult(
                false,
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'})
            );
        }
        return new ValidationResult(true, null);
    }

    public static ValidationResult validateRequestHeaders(String transId, String dateTimeValue, String requestorId) {
        if (String.isBlank(transId)) {
            return new ValidationResult(false, System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(dateTimeValue)) {
            return new ValidationResult(false, System.Label.FEC_MSG_Datetime_Null);
        }
        Pattern dateTimePattern = Pattern.compile(FEC_ConstantCommon.PATTERN_DATE_TIME_FULL);
        if (!dateTimePattern.matcher(dateTimeValue).matches()) {
            return new ValidationResult(
                false,
                String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeValue})
            );
        }
        if (String.isBlank(requestorId)) {
            return new ValidationResult(false, System.Label.FEC_MSG_RequestorID_Null);
        }
        return new ValidationResult(true, null);
    }

    public static ValidationResult validateResponse(GetDisbInfoByAcctResponse response) {
        if (response == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Null);
        }
        if (String.isNotBlank(response.errorCode)) {
            return new ValidationResult(
                false,
                String.format(
                    System.Label.FEC_MSG_HTTP_Error,
                    new List<String>{response.errorCode + ' - ' + response.errorMessage}
                )
            );
        }
        if (response.Sys2 == null) {
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Sys_Null);
        }
        return new ValidationResult(true, null);
    }

    public static Boolean isBusinessSuccess(GetDisbInfoByAcctResponse response) {
        return response != null
            && response.Sys2 != null
            && response.Sys2.Code2 == '1';
    }

    public static ResultWrapper convertToResultWrapper(GetDisbInfoByAcctResponse response) {
        ResultWrapper result = new ResultWrapper();
        ValidationResult validation = validateResponse(response);
        if (!validation.isValid) {
            result.isSuccess = false;
            result.errorCode = response == null ? null : response.errorCode;
            result.errorMessage = validation.errorMessage;
            return result;
        }
        result.transId = response.Sys2.TransID;
        result.sysCode2 = response.Sys2.Code2;
        result.sysDescription = response.Sys2.Description;
        if (!isBusinessSuccess(response)) {
            result.isSuccess = false;
            result.errorCode = response.Sys2.Code2;
            result.errorMessage = String.format(
                System.Label.FEC_MSG_API_Error,
                new List<String>{response.Sys2.Description}
            );
            return result;
        }
        result.isSuccess = true;
        if (response.Applications != null) {
            for (ApplicationsEntry row : response.Applications) {
                if (row != null && row.Application != null) {
                    result.applications.add(new ApplicationDetailWrapper(row.Application));
                }
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static ResultWrapper getDisbInfoByAcctWithValidation(String accountNumber, Integer ageOfRecords) {
        ResultWrapper result = new ResultWrapper();
        try {
            GetDisbInfoByAcctResponse apiRes = getDisbInfoByAcct(accountNumber, ageOfRecords);
            result = convertToResultWrapper(apiRes);
        } catch (CalloutException e) {
            result.isSuccess = false;
            result.errorCode = 'CALLOUT_ERROR';
            result.errorMessage = String.format(
                System.Label.FEC_MSG_HTTP_Error,
                new List<String>{e.getMessage()}
            );
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorCode = 'UNKNOWN_ERROR';
            result.errorMessage = System.Label.FEC_Unknown_Error;
        }
        return result;
    }
}