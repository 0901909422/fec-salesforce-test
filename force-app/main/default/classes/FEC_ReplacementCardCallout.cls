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
    // RESULT WRAPPER
    // ============================================================

    public class ResultWrapper {

        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;

        @AuraEnabled public String transId;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String cardNumber;
        @AuraEnabled public String description;
        @AuraEnabled public String replacementFeeFlag;

        public ResultWrapper(){
            isSuccess = false;
        }
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

        ReplaceCardResponse response;

        try{

            String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_XXX);
            ReplaceCardRequest request = new ReplaceCardRequest();
            request.headers = new Map<String,Object>{
                'TransID' => transId,
                'RequestorID' => requestorId,
                'DateTime' => dateTimeStr,
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };
            request.parameters = new Map<String,String>();
            request.body = new Map<String,Object>{
                'CARD_BLK' => cardBlk,
                '4LastCardNumber' => last4CardNumber,
                'REPL_FEE_FLAG' => replacementFeeFlag,
                'AccountNumber' => accountNumber
            };
            String requestBodyJson = JSON.serialize(request);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_ReplacementCard');
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_REPLACEMENT_CARD_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            Map<String,String> headers = new Map<String,String>{
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
                'TransID' => transId,
                'RequestorID' => requestorId,
                'DateTime' => dateTimeStr
            };

            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, 'POST', headers, requestBodyJson);

            if(resp.getStatusCode() == 200){
                response =
                    (ReplaceCardResponse)JSON.deserialize(
                        resp.getBody(),
                        ReplaceCardResponse.class
                    );

            } else{
                response = new ReplaceCardResponse();
                response.errorCode = String.valueOf(resp.getStatusCode());
                response.errorMessage = resp.getStatus();
            }

        } catch(Exception e){
            response = new ReplaceCardResponse();
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

        if(String.isBlank(transId))
            return new ValidationResult(false,System.Label.FEC_MSG_TransID_Null);

        if(String.isBlank(requestorId))
            return new ValidationResult(false,System.Label.FEC_MSG_RequestorID_Null);

        if(String.isBlank(accountNumber))
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'AccountNumber'}));

        if(String.isBlank(last4CardNumber))
            return new ValidationResult(false,
                String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'4LastCardNumber'}));

        return new ValidationResult(true,null);
    }

    // ============================================================
    // VALIDATE RESPONSE
    // ============================================================

    public static ValidationResult validateResponse(ReplaceCardResponse response){

        if(response == null)
            return new ValidationResult(false,System.Label.FEC_MSG_Response_Null);

        if(String.isNotBlank(response.errorCode))
            return new ValidationResult(false,
                response.errorCode + ' - ' + response.errorMessage);

        if(response.Sys2 == null)
            return new ValidationResult(false,System.Label.FEC_MSG_Response_Sys_Null);

        if(response.Sys2.Code != '1')
            return new ValidationResult(false,response.Sys2.Description);

        return new ValidationResult(true,null);
    }

    // ============================================================
    // CONVERT RESULT WRAPPER
    // ============================================================

    public static ResultWrapper convertToResultWrapper(ReplaceCardResponse response){
        ResultWrapper result = new ResultWrapper();
        ValidationResult validation = validateResponse(response);
        if(!validation.isValid){
            result.errorCode = response != null ? response.errorCode : null;
            result.errorMessage = validation.errorMessage;
            return result;
        }

        result.isSuccess = true;
        result.transId = response.Sys2.TransID;
        result.accountNumber = response.AccountNumber;
        result.cardNumber = response.CardNumber;
        result.description = response.Sys2.Description;
        result.replacementFeeFlag = response.REPL_FEE_FLAG;

        return result;
    }
}