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
        public String pxObjClass;
        public String RespCode;
        public String RespDesc;
        public String TransDTTM;
        public String TransID;

        public String errorCode;
        public String errorMessage;
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
        String cardNumber,
        String transId,
        String customerId
    ){
        PINResponse response = new PINResponse();
        try{
            PINRequest request = new PINRequest();
            request.headers = new Map<String, String>{};
            request.body = new Map<String, String>{};
            request.parameters = new List<String>{
                cardNumber,
                transId,
                customerId
            };

            String requestBodyJson = JSON.serialize(request);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_PINReissueService');

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
            
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE_JSON, null, null, requestBodyJson);

            // Log response
            responseLog = new ResponseLog(
                'FEC_PINReissue',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                requestBodyJson,
                res,
                null
            );

            if (res.getStatusCode() == 200) {
                response = (PINResponse)JSON.deserialize(res.getBody(), PINResponse.class);
            } else {
                response.errorCode = String.valueOf(res.getStatusCode());
                response.errorMessage = res.getBody();
            }
        } catch(Exception e){
            response.errorCode = 'CALLOUT_ERROR';
            response.errorMessage = e.getMessage();
        }
        return response;
    }

    // ============================================================
    // SUCCESS CHECK
    // ============================================================

    public static Boolean isSuccess(PINResponse response){
        return response != null
            && response.RespCode == '0';
    }

    // ============================================================
    // VALIDATE REQUEST
    // ============================================================
    public static ValidationResult validateRequest(
        String cardNumber,
        String transId,
        String customerId
    ){

        if(String.isBlank(transId)) {
            return new ValidationResult(false,System.Label.FEC_MSG_TransID_Null);
        }

        if(String.isBlank(cardNumber)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'CardNumber'}));
        }

        if(String.isBlank(customerId)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'CustomerId'}));
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
                responseLog.errorMessage);
        }
    }
}