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
        // FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        // FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);
        
        // // String endpoint = apiSetting?.FEC_Call_Mock__c
        // //     ? ''
        // //     : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

        string endpoint = 'https://sf-csm-service-dev.fecredit.cloud/api/v1/do-not-bother/create-info';
        
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
        DNBResult result = new DNBResult();
        result.httpStatus = httpStatus;
        result.rawResponse = jsonResponse;
        
        // ❌ HTTP fail
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
            
            result.pxObjClass = (String) responseMap.get('pxObjClass');
            
            // ===== Sys =====
            Map<String, Object> sysMap = (Map<String, Object>) responseMap.get('Sys');
            if (sysMap != null) {
                result.code = (String) sysMap.get('Code');
                result.description = (String) sysMap.get('Description');
                result.requestDateTime = (String) sysMap.get('RequestDateTime');
                result.transId = (String) sysMap.get('TransID');
            }
            
            // ===== sys2 (QUAN TRỌNG) =====
            Map<String, Object> sys2Map = (Map<String, Object>) responseMap.get('sys2');
            if (sys2Map != null) {
                result.sys2Code = (String) sys2Map.get('code2');
                result.sys2Message = (String) sys2Map.get('message2');
                
                // ✅ SUCCESS đúng spec
                result.success = (result.sys2Code == '0');
            } else {
                result.success = false;
                result.errorMessage = 'Missing sys2 in response';
            }
            
            // ===== result array =====
            if (responseMap.containsKey('result')) {
                result.resultList = (List<Object>) responseMap.get('result');
            }
            
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }
        
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
        
        try {
            // ===== DEBUG REQUEST =====
            System.debug('=== REQUEST BODY ===');
            System.debug(JSON.serializePretty(reqList));
            
            HttpResponse res = sendRequest(reqList);
            
            // ===== DEBUG RESPONSE =====
            System.debug('=== HTTP STATUS ===');
            System.debug(res.getStatusCode());
            
            System.debug('=== RAW RESPONSE ===');
            System.debug(res.getBody());
            
            return parseResponse(res.getBody(), res.getStatusCode());
        } catch (Exception ex) {
            System.debug('=== EXCEPTION ===');
            System.debug(ex);
            System.debug(ex.getMessage());
            System.debug(ex.getStackTraceString());
            
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
    
    // ✅ ISO 8601 with timezone (+07:00)
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