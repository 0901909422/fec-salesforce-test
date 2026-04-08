/**
 * Callout: Disb_Status_Inquiry / GetDisbInfoByAcct (JSON envelope: headers, parameters, body).
 * Maps response Applications[].Application to FEC_Pending_Disbursement__c fields at integration layer.
 */
public with sharing class FEC_GetDisbInfoByAcctCallout {

    private static final String API_CONFIG_NAME = 'FEC_GetDisb_Info_By_Acct';

    //=============== REQUEST ===============//

    public class GetDisbInfoRequestEnvelope {
        public Map<String, Object> headers;
        public List<Object> parameters;
        public Map<String, Object> body;

        public GetDisbInfoRequestEnvelope() {
            this.headers = new Map<String, Object>();
            this.parameters = new List<Object>();
            this.body = new Map<String, Object>();
        }
    }

    //=============== RESPONSE ===============//

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

    public static String buildRequestPayload(
        String transId,
        String dateTimeHeader,
        String accountNumber,
        Integer ageOfRecords
    ) {
        Map<String, Object> headerMap = new Map<String, Object>{
            'TransID' => transId,
            'DateTime' => dateTimeHeader,
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        Map<String, Object> bodyMap = new Map<String, Object>{
            'AccountNumber' => accountNumber
        };
        if (ageOfRecords != null) {
            bodyMap.put('AgeOfRecords', ageOfRecords);
        }
        Map<String, Object> root = new Map<String, Object>{
            'headers' => headerMap,
            'parameters' => new List<Object>(),
            'body' => bodyMap
        };
        return JSON.serialize(root);
    }

    public static HttpResponse sendRequest(String jsonPayload) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_DISB_INFO_BY_ACCT_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

        Map<String, String> httpHeaders = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };

        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            httpHeaders,
            jsonPayload
        );
    }

    public static GetDisbInfoByAcctResponse parseResponseBody(String responseBody, Integer httpStatus) {
        GetDisbInfoByAcctResponse out = new GetDisbInfoByAcctResponse();
        if (httpStatus != null && httpStatus != 200) {
            out.errorCode = String.valueOf(httpStatus);
            out.errorMessage = String.format(
                System.Label.FEC_MSG_HTTP_Error,
                new List<String>{String.valueOf(httpStatus)}
            );
            return out;
        }
        if (String.isBlank(responseBody)) {
            out.errorCode = 'EMPTY';
            out.errorMessage = System.Label.FEC_MSG_Response_Null;
            return out;
        }
        try {
            String normalized = responseBody.replace('"DateTime":', '"DateTime_x":');
            out = (GetDisbInfoByAcctResponse) JSON.deserialize(
                normalized,
                FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctResponse.class
            );
        } catch (JSONException e) {
            out.errorCode = 'JSON_PARSE_ERROR';
            out.errorMessage = String.format(
                System.Label.FEC_MSG_Parse_JSON_Error,
                new List<String>{e.getMessage()}
            );
        }
        return out;
    }

    public static GetDisbInfoByAcctResponse getDisbInfoByAcct(String accountNumber, Integer ageOfRecords) {
        ValidationResult reqVal = validateRequest(accountNumber);
        if (!reqVal.isValid) {
            GetDisbInfoByAcctResponse err = new GetDisbInfoByAcctResponse();
            err.errorCode = 'VALIDATION_ERROR';
            err.errorMessage = reqVal.errorMessage;
            return err;
        }

        String transactionId = String.valueOf(UUID.randomUUID());
        String dateTimeValue = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);
        ValidationResult headerVal = validateRequestHeaders(transactionId, dateTimeValue, FEC_ConstantCommon.REQUESTOR_PEGA_CSM);
        if (!headerVal.isValid) {
            GetDisbInfoByAcctResponse err = new GetDisbInfoByAcctResponse();
            err.errorCode = 'HEADER_VALIDATION_ERROR';
            err.errorMessage = headerVal.errorMessage;
            return err;
        }

        String payload = buildRequestPayload(transactionId, dateTimeValue, accountNumber, ageOfRecords);
        HttpResponse resp = sendRequest(payload);
        Integer statusCode = resp == null ? null : resp.getStatusCode();
        String bodyStr = resp == null ? null : resp.getBody();
        return parseResponseBody(bodyStr, statusCode);
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
        try {
            Pattern dateTimePattern = Pattern.compile(FEC_ConstantCommon.PATTERN_DATE_TIME_FULL);
            Matcher matcher = dateTimePattern.matcher(dateTimeValue);
            if (!matcher.matches()) {
                return new ValidationResult(
                    false,
                    String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeValue})
                );
            }
        } catch (Exception e) {
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
            result.errorMessage = e.getMessage();
        }
        return result;
    }
}