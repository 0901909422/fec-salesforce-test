public without sharing class FEC_ReplacementCardCallout {

    private static ResponseLog responseLog;

    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    public class ReplaceCardRequest {
        public Map<String, String> parameters;
        public Map<String, String> headers;
        public Map<String, String> body;
    }

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    public class ReplaceCardResponse {

        public String AccountNumber;
        public String CARD_BLK;
        public String CardNumber;
        public String pxObjClass;
        public String REPL_FEE_FLAG;
        public Sys2 Sys2;
        public String errorCode;
        public String errorMessage;
    }

    public class Sys2 {
        public String Code;
        public String DateTimeStr;
        public String Description;
        public String pxObjClass;
        public String TransID;
    }

    // ============================================================
    // VALIDATION RESULT
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
    public static ReplaceCardResponse callReplaceCard(
        String transId,
        String requestorId,
        String cardBlk,
        String last4CardNumber,
        String replacementFeeFlag,
        String accountNumber
    ){
        ReplaceCardResponse response = new ReplaceCardResponse();
        try{
            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);
            ReplaceCardRequest request = new ReplaceCardRequest();
            request.headers = new Map<String, String>{
                'TransID' => transId,
                'RequestorID' => requestorId,
                'DateTime' => dateTimeStr,
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };
            request.body = new Map<String, String>{
                'CARD_BLK' => cardBlk,
                '4LastCardNumber' => last4CardNumber,
                'REPL_FEE_FLAG' => replacementFeeFlag,
                'AccountNumber' => accountNumber
            };
            String requestBodyJson = JSON.serialize(request.body);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_ReplacementCard');

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;

            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_POST, request.headers, requestBodyJson);

            // Log response
            String requestJson = JSON.serialize(request);
            responseLog = new ResponseLog(
                'FEC_ReplacementCard',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                requestJson,
                res,
                null
            );

            if (res.getStatusCode() == 200) {
                response = (ReplaceCardResponse)JSON.deserialize(res.getBody(), ReplaceCardResponse.class);
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

    public static Boolean isSuccess(ReplaceCardResponse response){
        return response != null
            && response.Sys2 != null
            && response.Sys2.Code == '1';
    }

    // ============================================================
    // VALIDATE REQUEST
    // ============================================================
    public static ValidationResult validateRequest(
        String transId,
        String requestorId,
        String cardBlk,
        String last4CardNumber,
        String replacementFeeFlag,
        String accountNumber
    ){

        if(String.isBlank(transId)) {
            return new ValidationResult(false,System.Label.FEC_MSG_TransID_Null);
        }

        if(String.isBlank(requestorId)) {
            return new ValidationResult(false,System.Label.FEC_MSG_RequestorID_Null);
        }

        if(String.isBlank(cardBlk)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'CARD_BLK'}));
        }

        if(String.isBlank(accountNumber)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'AccountNumber'}));
        }

        if(String.isBlank(last4CardNumber)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'4LastCardNumber'}));
        }

        if(String.isBlank(replacementFeeFlag)) {
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'REPL_FEE_FLAG'}));
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