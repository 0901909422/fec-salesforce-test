public with sharing class FEC_PsDNBServiceCallout {
    public static final String API_CONFIG_NAME = 'FEC_Ps_DNB';
    public static FEC_ResponseLog responseLog;
    
    // ================= REQUEST =================
    public class DNBRequest {
        public String reason;
        public String full_name;
        public String nid;
        public Boolean do_not_bother;
        public String type;
        public String type_value;
    }
    
    // ================= RESPONSE =================
    public class DNBResult {
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String requestDateTime;
        @AuraEnabled public String transId;
        @AuraEnabled public Integer httpStatus;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public List<Object> resultList;
        
    }
    
    // ================= MAIN SEND =================
    public static HttpResponse sendRequest(List<DNBRequest> reqList) {
        
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        
        FEC_API_Config__mdt apiConfig = [
            SELECT FEC_Endpoint__c
            FROM FEC_API_Config__mdt
            WHERE DeveloperName = :API_CONFIG_NAME
            LIMIT 1
        ];
        
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
            + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
        System.debug('FINAL endpoint = ' + endpoint);
        
        if (String.isBlank(endpoint)) {
            throw new CalloutException('Endpoint is null or empty. Please check API configuration.');
        }
        
        String isoTimestamp = FEC_CommonUltils.formatISOWithTimezone(Datetime.now());
        
        Map<String, String> headers = new Map<String, String>{
            'requester'    => isoTimestamp,
            'trans_id'     => System.UUID.randomUUID().toString(),
            'source'       => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'confirmer'    => isoTimestamp
        };
        
        String body = JSON.serialize(reqList);
        
        HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        headers,
        body
            );
        
        return res;
    }
    
    // ================= PARSE =================
    public static DNBResult parseResponse(String jsonResponse, Integer httpStatus) {
        DNBResult result = new DNBResult();
        result.httpStatus = httpStatus;
        result.rawResponse = jsonResponse;
        
        // HTTP fail
        if (httpStatus != FEC_ConstantCommon.SUCCESS_CODE_200_NUM) {
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
            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
            
            System.debug('responseMap: ' + responseMap);
            
            // ===== SYS =====
            Map<String, Object> sysMap = (Map<String, Object>) responseMap.get('sys');
            if (sysMap != null) {
                
                Object codeObj = sysMap.get('code');
                Integer code = codeObj != null ? Integer.valueOf(String.valueOf(codeObj)) : null;
                
                result.code = String.valueOf(code);
                result.transId = (String) sysMap.get('trans_id');
                result.description = (String) sysMap.get('message');
                result.success = (code == 0);
                
            } else {
                result.success = false;
                result.errorMessage = System.Label.FEC_MSG_Response_Null;
                return result;
            }
            
            // ===== RESULT ARRAY =====
            if (responseMap.containsKey('result')) {
                result.resultList = (List<Object>) responseMap.get('result');
            }
            
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }
        
        System.debug('result: ' + result);
        return result;
    }
    
    // ================= MAIN METHOD =================
    @AuraEnabled
    public static DNBResult notifyPsDNB(List<DNBRequest> reqList) {
        
        // ✅ VALIDATION
        if (reqList == null || reqList.isEmpty()) {
            return error(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Request'}));
        }
        
        for (DNBRequest r : reqList) {
            if (String.isBlank(r.reason) ||
                String.isBlank(r.full_name) ||
                String.isBlank(r.nid) ||
                r.do_not_bother == null ||
                String.isBlank(r.type) ||
            String.isBlank(r.type_value)) {
                
                return error(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG);
            }
            
            if (r.nid != null && r.nid.length() > 255) {
                return error('Field nid tối đa 255 ký tự');
            }
            
            // ✅ validate max length type_value (<=40)
            if (r.type_value != null && r.type_value.length() > 40) {
                return error('Field type_value tối đa 40 ký tự');
            }
        }
        
        
        try {
            HttpResponse res = sendRequest(reqList);
            
            logApiFull(
                API_CONFIG_NAME,
            FEC_ConstantCommon.API_METHOD_POST,
            reqList,
            res != null ? res.getBody() : null,
            true,
            String.valueOf(res != null ? res.getStatusCode() : null),
            null,
            null
                );
            
            System.debug('HTTP Response: ' + res);
            
            return parseResponse(
                res != null ? res.getBody() : null,
            res != null ? res.getStatusCode() : 500
                );
            
        } catch (Exception ex) {
            
            // ✅ LOG ERROR
            logApiFull(
                API_CONFIG_NAME,
            FEC_ConstantCommon.API_METHOD_POST,
            reqList,
            null,
            false,
            '500',
            ex.getMessage(),
            null
                );
            
            System.debug('ERROR: ' + ex.getMessage());
            System.debug('STACK: ' + ex.getStackTraceString());
            
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
            HttpResponse apiResponse = new HttpResponse();
            apiResponse.setStatusCode(isSuccess ? 200 : 500);
            apiResponse.setBody(FEC_CommonUltils.serializeSafe(responseObj));
            
            FEC_CommonUltils.logApi(
                'FEC_Ps_DNB',
            endpoint,
            method,
            FEC_CommonUltils.serializeSafe(requestObj),
            apiResponse,
            errorMessage
                );
            
        } catch (Exception e) {
            System.debug('LOG_API_ERROR: ' + e.getMessage());
        }
    }
    
    
    // ================= HELPER =================
    private static DNBResult error(String msg) {
        DNBResult err = new DNBResult();
        err.success = false;
        err.errorMessage = msg;
        return err;
    }
    
    
}