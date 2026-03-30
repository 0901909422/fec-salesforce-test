public with sharing class FEC_PsDNBServiceCallout {
    public static final String API_CONFIG_NAME = 'FEC_Ps_DNB';
    
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
        
        // NEW (theo spec)
        @AuraEnabled public String sys2Code;
        @AuraEnabled public String sys2Message;
        @AuraEnabled public List<Object> resultList;
    }
    
    // ================= MAIN SEND =================
    public static HttpResponse sendRequest(List<DNBRequest> reqList) {
        
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        // ✅ dùng Named Credential
        // String endpoint = 'callout:FECredit_Service/api/v1/do-not-bother/create-info';
        
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
            + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
        
        
        String isoTimestamp = FEC_CommonUltils.formatISOWithTimezone(Datetime.now());
        
        Map<String, String> headers = new Map<String, String>{
            'requester'    => isoTimestamp,
            'trans_id'     => System.UUID.randomUUID().toString(),
            'source'       => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'confirmer'    => isoTimestamp
        };
        
        String body = JSON.serialize(reqList);
        
        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
        FEC_ConstantCommon.API_METHOD_POST,
        headers,
        body
            );
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
            return error(String.format(System.Label.FEC_MSG_Param_Required, new List{'Request'}));
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
        }
        
        
        String requestBody = JSON.serialize(reqList);
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
            + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
        
        try {
            HttpResponse res = sendRequest(reqList);
            FEC_CommonUltils.logApi(
                API_CONFIG_NAME,                // apiName
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            requestBody,
            res,
            null                     // errorMessage
                );
            
            return parseResponse(res.getBody(), res.getStatusCode());
            
        } catch (Exception ex) {
            HttpResponse exceptionRes = new HttpResponse();
            exceptionRes.setStatusCode(FEC_ConstantCommon.ERROR_CODE_500_NUM);
            exceptionRes.setBody(null);
            
            FEC_CommonUltils.logApi(
                API_CONFIG_NAME,
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            requestBody,
            exceptionRes,
            ex.getMessage()
                );
            
            return error(ex.getMessage());
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