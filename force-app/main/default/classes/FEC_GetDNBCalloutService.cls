public with sharing class FEC_GetDNBCalloutService {
    public static final String API_CONFIG_NAME = 'FEC_Get_DNB';
    
    public class DNBRequest {
        public String phone;
        public String nid;
        public String email;
    }
    
    public class DNBRequestWrapper {
        public Map<String, String> headers;
        public List<Object> parameters;
        public DNBRequest body;
    }
    
    // ================= RESPONSE =================
    public class DNBResult {
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public List<ResultItem> result;
        @AuraEnabled public Sys2 sys2;
        
        @AuraEnabled public Integer httpStatus;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
    
    public class ResultItem {
        @AuraEnabled public String confirmed_time;
        @AuraEnabled public Object do_not_bother;
        @AuraEnabled public String exclude_time;
        @AuraEnabled public String expected_exclude_time;
        @AuraEnabled public String full_name;
        @AuraEnabled public String nid;
        @AuraEnabled public String reason2;
        @AuraEnabled public String requested_time;
        @AuraEnabled public String source2;
        @AuraEnabled public String type;
        @AuraEnabled public String type_value;
    }
    
    public class Sys2 {
        @AuraEnabled public String code2;
        @AuraEnabled public String message2;
        @AuraEnabled public String trans_id;
        @AuraEnabled public Object request;
    }
    
    public class CalloutResult {
        public HttpResponse response;
        public Map<String, String> headers;
        public List<Object> parameters;
    }
    
    // ================= MAIN SEND =================
    public static CalloutResult sendRequest(DNBRequest req) {
        
        CalloutResult out = new CalloutResult();
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
            + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
        
        if (String.isBlank(endpoint)) {
            throw new CalloutException(System.Label.FEC_MSG_Endpoint_Null);
        }
        
        String isoTimestamp = FEC_CommonUltils.formatISOWithTimezone(Datetime.now());
        
        Map<String, String> httpHeaders = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'requested_time' => isoTimestamp,
            'trans_id' => FEC_CommonUltils.generateTransactionUUID(),
            'source' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };
        
        // BUILD REQUEST WRAPPER TO LOG FULL INFO
        DNBRequestWrapper wrapper = new DNBRequestWrapper();
        wrapper.headers = httpHeaders;
        wrapper.parameters = new List<Object>();
        wrapper.body = req;
        
        String body = JSON.serialize(req);
        
        System.debug('FINAL REQUEST: ' + body);
        
        HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        httpHeaders,
        body
            );
        
        out.response = res;
        out.headers = httpHeaders;
        out.parameters = wrapper.parameters;
        
        return out;
    }
    
    public static DNBResult parseResponse(String jsonResponse, Integer httpStatus) {
        
        DNBResult result = new DNBResult();
        result.httpStatus = httpStatus;
        result.rawResponse = jsonResponse;
        
        if (httpStatus != 200) {
            result.success = false;
            result.errorMessage = 'HTTP Error: ' + httpStatus;
            return result;
        }
        
        if (String.isBlank(jsonResponse)) {
            result.success = false;
            result.errorMessage = System.Label.FEC_MSG_Response_Null;
            return result;
        }
        
        try {
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            
            if (!raw.containsKey('sys')) {
                result.success = false;
                result.errorMessage = System.Label.FEC_CS_CASE_SYS_MISSING_MSG;
                return result;
            }
            
            Map<String, Object> sys = (Map<String, Object>) raw.get('sys');
            
            Integer code = (Integer) sys.get('code');
            String message = (String) sys.get('message');
            
            if (code != 0) {
                result.success = false;
                result.errorMessage = message;
                
                if (sys.containsKey('list_invalid')) {
                    result.errorMessage += ' - invalid: ' + JSON.serialize(sys.get('list_invalid'));
                }
                
                return result;
            }
            
            result.success = true;
            
            // map result nếu có
            if (raw.containsKey('result')) {
                result.result = (List<ResultItem>) JSON.deserialize(
                    JSON.serialize(raw.get('result')),
                List<ResultItem>.class
                    );
            }
            
            if (result.result == null || result.result.isEmpty()) {
                result.errorMessage = System.Label.FEC_Termination_No_Data;
            }
            
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }
        
        return result;
    }
    
    // ================= MAIN METHOD =================
    @AuraEnabled
    public static DNBResult getDNB(DNBRequest req) {
        System.debug('Received Request: ' + JSON.serialize(req));
        if (req == null) {
            return error(System.Label.FEC_CS_CASE_STATUS_REQUEST_INVALID_MSG);
        }
        
        if (String.isBlank(req.phone) || String.isBlank(req.nid)) {
            return error(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
        }
        
        try {
            CalloutResult callout = sendRequest(req);
            
            HttpResponse res = callout.response;
            Map<String, String> headers = callout.headers;
            
            
            if (res == null) {
                return error(System.Label.FEC_MSG_Response_Null);
            }
            
            Boolean isSuccess = res.getStatusCode() == 200;
            String responseBody = res.getBody();
            System.debug('RAW RESPONSE: ' + responseBody);
            
            logApiFull(
                API_CONFIG_NAME,
            'POST',
            new Map<String, Object>{
                'headers' => headers,
                'parameters' => callout.parameters,
                'body'    => req
            },
            responseBody,
            isSuccess,
            String.valueOf(res.getStatusCode()),
            null,
            null
                );
            
            return parseResponse(responseBody, res.getStatusCode());
            
        } catch (Exception ex) {
            return error(ex.getMessage());
        }
    }
    
    private static void logApiFull(
        String endpoint,
    String method,
    Object requestObj,
    Object responseObj,
    Boolean isSuccess,
    String statusCode,
    String errorMessage,
    String transactionId
    ) {
        try {
            System.debug('LOGGING API CALL: ' + endpoint);
            System.debug('Method: ' + method);
            System.debug('Request: ' + JSON.serialize(requestObj));
            System.debug('Response: ' + JSON.serialize(responseObj));
            HttpResponse apiResponse = new HttpResponse();
            apiResponse.setStatusCode(isSuccess ? 200 : 500);
            apiResponse.setBody(JSON.serialize(responseObj));
            
            FEC_CommonUltils.logApi(
                API_CONFIG_NAME,
            endpoint,
            method,
            JSON.serialize(requestObj),
            apiResponse,
            errorMessage
                );
            
        } catch (Exception e) {
            System.debug('LOG_API_ERROR: ' + e.getMessage());
        }
    }
    
    private static DNBResult error(String msg) {
        DNBResult err = new DNBResult();
        err.success = false;
        err.errorMessage = msg;
        return err;
    }
}