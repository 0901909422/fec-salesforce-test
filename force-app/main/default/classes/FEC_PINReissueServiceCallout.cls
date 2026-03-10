public without sharing class FEC_PINReissueServiceCallout {

    // ============================================================
    // REQUEST CLASSES
    // ============================================================

    public class PINRequest {
        public Map<String,Object> headers;
        public List<String> parameters;
        public Map<String,Object> body;
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
    // RESULT WRAPPER
    // ============================================================

    public class ResultWrapper {

        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;

        @AuraEnabled public String transId;
        @AuraEnabled public String description;
        @AuraEnabled public String responseCode;

        public ResultWrapper(){
            isSuccess = false;
        }
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
    // MAIN CALLOUT
    // ============================================================

    public static PINResponse fetchPIN(

        String cardNumber,
        String transId,
        String customerId
    ){
        PINResponse response;
        try{

            PINRequest request = new PINRequest();
            request.headers = new Map<String,Object>();
            request.parameters = new List<String>{
                cardNumber,
                transId,
                customerId
            };

            request.body = new Map<String,Object>();
            String requestBodyJson = JSON.serialize(request);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_PINReissueService');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_PIN_REISSUE_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            Map<String,String> headers = new Map<String,String>{'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON};

            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders( endpoint, 'GET', headers, requestBodyJson);

            if(resp.getStatusCode() == 200){
                response =
                    (PINResponse)JSON.deserialize(
                        resp.getBody(),
                        PINResponse.class
                    );
            } else{
                response = new PINResponse();
                response.errorCode = String.valueOf(resp.getStatusCode());
                response.errorMessage = resp.getStatus();
            }

        } catch(Exception e){
            response = new PINResponse();
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

        if(String.isBlank(cardNumber))
            return new ValidationResult(false, 
            String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'CardNumber'}));

        if(String.isBlank(transId))
            return new ValidationResult(false,System.Label.FEC_MSG_TransID_Null);

        if(String.isBlank(customerId))
            return new ValidationResult(false,
            String.format(System.Label.FEC_MSG_Param_Required,
                new List<String>{'CustomerId'}));

        return new ValidationResult(true,null);
    }

    // ============================================================
    // VALIDATE RESPONSE
    // ============================================================

    public static ValidationResult validateResponse(PINResponse response){

        if(response == null)
            return new ValidationResult(false,System.Label.FEC_MSG_Response_Null);

        if(String.isNotBlank(response.errorCode))
            return new ValidationResult(false,
                response.errorCode + ' - ' + response.errorMessage);

        if(response.RespCode != '0')
            return new ValidationResult(false,response.RespDesc);

        return new ValidationResult(true,null);
    }

    // ============================================================
    // CONVERT RESULT WRAPPER
    // ============================================================

    public static ResultWrapper convertToResultWrapper(PINResponse response){
        ResultWrapper result = new ResultWrapper();
        ValidationResult validation = validateResponse(response);
        if(!validation.isValid){
            result.errorCode = response != null ? response.errorCode : null;
            result.errorMessage = validation.errorMessage;
            return result;
        }
        result.isSuccess = true;
        result.transId = response.TransID;
        result.description = response.RespDesc;
        result.responseCode = response.RespCode;

        return result;
    }
}