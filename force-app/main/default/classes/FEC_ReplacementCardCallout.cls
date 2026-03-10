public without sharing class FEC_ReplacementCardCallout {

    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    public class ReplaceCardRequest {
        public Map<String,String> parameters;
        public Map<String,Object> headers;
        public Map<String,Object> body;
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
    // MAIN CALLOUT
    // ============================================================
    public static ReplaceCardResponse replaceCard(
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
            request.headers = new Map<String,Object>{
                'TransID' => transId,
                'RequestorID' => requestorId,
                'DateTime' => dateTimeStr,
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };
            request.body = new Map<String,Object>{
                'CARD_BLK' => cardBlk,
                '4LastCardNumber' => last4CardNumber,
                'REPL_FEE_FLAG' => replacementFeeFlag,
                'AccountNumber' => accountNumber
            };
            String requestBodyJson = JSON.serialize(request.body);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_ReplacementCard');

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;

            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_POST, request.headers, requestBodyJson);

            // Log response
            String requestHeaderJson = JSON.serialize(request.headers);
            responseLog = new ResponseLog(
                'FEC_CardLockUnLock',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                'headers: ' + requestHeaderJson + ', body: ' + requestBodyJson,
                res,
                null
            );

            if (res.getStatusCode() == 200) {
                response = (ReplaceCardResponse)JSON.deserialize(res.getBody(), LockUnlockResponse.class);
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

}