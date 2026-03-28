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
       
        // ✅ dùng Named Credential
        String endpoint = 'callout:FECredit_Service/api/v1/do-not-bother/create-info';
        
        
        // ✅ FIX timestamp ISO + timezone
        String isoTimestamp = formatISOWithTimezone(Datetime.now());
        
        Map<String, String> headers = new Map<String, String>{
            'requester'    => isoTimestamp,
            'trans_id'     => System.UUID.randomUUID().toString(),
            'source'       => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            'Content-Type' => 'application/json',
            'confirmer'    => isoTimestamp
        };
        
        String body = JSON.serialize(reqList);
        
        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
        'POST',
        headers,
        body
            );
    }
    
    // ================= PARSE =================
    public static DNBResult parseResponse(String jsonResponse, Integer httpStatus) {
        System.debug('jsonResponse: ' + jsonResponse);
        System.debug('httpStatus: ' + httpStatus);
        
        DNBResult result = new DNBResult();
        result.httpStatus = httpStatus;
        result.rawResponse = jsonResponse;
        
        // HTTP fail
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
                result.errorMessage = 'Missing sys in response';
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
            return error('Request is empty');
        }
        
        for (DNBRequest r : reqList) {
            if (String.isBlank(r.reason) ||
                String.isBlank(r.full_name) ||
                String.isBlank(r.nid) ||
                r.do_not_bother == null ||
                String.isBlank(r.type) ||
            String.isBlank(r.type_value)) {
                
                return error('Missing required fields in request');
            }
        }
        
        
        String requestBody = JSON.serialize(reqList);
        String endpoint = 'callout:FECredit_Service/api/v1/do-not-bother/create-info';
        
        try {
            HttpResponse res = sendRequest(reqList);
            FEC_CommonUltils.logApi(
                API_CONFIG_NAME,                // apiName
            endpoint,
            'POST',
            requestBody,
            res,
            null                     // errorMessage
                );
            
            return parseResponse(res.getBody(), res.getStatusCode());
            
        } catch (Exception ex) {
            HttpResponse exceptionRes = new HttpResponse();
            exceptionRes.setStatusCode(500);
            exceptionRes.setBody(null);
            
            FEC_CommonUltils.logApi(
                API_CONFIG_NAME,
            endpoint,
            'POST',
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
    
    private static String formatISOWithTimezone(Datetime dt) {
        TimeZone tz = UserInfo.getTimeZone();
        Integer offset = tz.getOffset(dt) / 1000 / 60; // minutes
        
        Integer hours = offset / 60;
        Integer minutes = Math.mod(offset, 60);
        
        String sign = hours >= 0 ? '+' : '-';
        
        return dt.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS') +
            sign +
            pad2(Math.abs(hours)) +
            ':' +
            pad2(Math.abs(minutes));
    }
    
    private static String pad2(Integer val) {
        return (val < 10 ? '0' : '') + String.valueOf(val);
    }
}