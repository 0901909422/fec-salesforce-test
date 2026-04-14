public without sharing class FEC_PINReissueServiceCallout {
    
    private static ResponseLog responseLog;
    
    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    public class PINRequest {
        public Map<String, String> headers;
        public List<String> parameters;
        public Map<String, String> body;
    }
    
    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    public class PINResponse {
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String RespCode;
        @AuraEnabled public String RespDesc;
        @AuraEnabled public String TransDTTM;
        @AuraEnabled public String TransID;
        
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean isSuccess;
    }
    
    // ============================================================
    // VALIDATION CLASS
    // ============================================================
    public class ValidationResult {
        
        public Boolean isValid;
        public String errorMessage;
        
        public ValidationResult(Boolean isValid,String errorMessage){
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }
    
    // ============================================================
    // RESPONSE LOG CLASS
    // ============================================================
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
    
    // ============================================================
    // MAIN CALLOUT
    // ============================================================
    public static PINResponse callPINReissue(
        String nationalID,
    String transId,
    String mobile
    ){
        PINResponse response = new PINResponse();
        try{
            String nationalIdParam = '';
            String mobileParam = '';
            FEC_System_Config__c systemConfig = FEC_System_Config__c.getOrgDefaults();
            if (String.isNotBlank(systemConfig?.FEC_Enviroment__c) && systemConfig.FEC_Enviroment__c == FEC_ConstantCommon.RESET_PIN_NON_PRODUCTION) {
                nationalIdParam = FEC_ConstantCommon.RESET_PIN_DEFAULT_NID;
                mobileParam = FEC_ConstantCommon.RESET_PIN_DEFAULT_PHONE;
            }else{
                nationalIdParam = nationalID;
                mobileParam = mobile;
            }
            
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_PINReissueService');
            
            String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
                + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
            endpoint += '?NationalID=' + nationalIdParam;
            endpoint += '&TransID=' + transId;
            endpoint += '&Mobile=' + mobileParam;
            
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_GET, FEC_ConstantCommon.API_CONTENT_TYPE_JSON, null, null, null);
            
            // Log response
            responseLog = new ResponseLog(
                'FEC_PINReissue',
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            null,
            res,
            null
                );
            
            if (res.getStatusCode() == 200) {
                response = (PINResponse)JSON.deserialize(res.getBody(), PINResponse.class);
                
                // ✅ SET SUCCESS FLAG
                response.isSuccess = (response != null && response.RespCode == '0' && response.errorMessage ==null);
                
            } else {
                response.errorCode = String.valueOf(res.getStatusCode());
                response.errorMessage = res.getBody();
                response.isSuccess = false; // ✅ FAIL CASE
            }
        } catch(Exception e){
            response.errorCode = 'CALLOUT_ERROR';
            response.errorMessage = e.getMessage();
            response.isSuccess = false;
        }
        System.debug('### PIN RESPONSE: ' + response);
        return response;
    }
    
    
    // ============================================================
    // VALIDATE REQUEST
    // ============================================================
    public static ValidationResult validateRequest(
        String nationalID,
    String transId,
    String mobile
    ){
        
        if(String.isBlank(transId)) {
            return new ValidationResult(false,System.Label.FEC_MSG_TransID_Null);
        }
        
        if(String.isBlank(nationalID)) {
            return new ValidationResult(false,
            String.format(System.Label.FEC_MSG_Param_Required,
            new List<String>{'National ID'}));
        }
        
        if(String.isBlank(mobile)) {
            return new ValidationResult(false,
            String.format(System.Label.FEC_MSG_Param_Required,
            new List<String>{'Mobile'}));
        }
        
        return new ValidationResult(true, null);
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
}