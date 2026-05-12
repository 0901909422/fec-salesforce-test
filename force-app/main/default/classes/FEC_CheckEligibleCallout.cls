/****************************************************************************************
* File Name    : FEC_CheckEligibleCallout
* Author       : LongNH76
* Date         : 2026-03-23
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-03-23     LongNH76             Create
   1.1      2026-05-04     LongNH76             Change Mess Valid
   1.2      2026-05-12     LongNH76             Delete Pattern Validate
* ===============================================================
 
****************************************************************************************/

public without sharing class FEC_CheckEligibleCallout {

    private static ResponseLog responseLog;

    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    /**
     * Represents the request structure for the CheckEligible API.
     * Following the pattern: { headers: {}, parameters: [...], body: {} }
     */
    public class CheckEligibleRequest {
        public Map<String,String> parameters;
        public Map<String, Object> headers;
        public Map<String, Object> body;
    }

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    /**
     * Root response object for CheckEligible API.
     */
    public class CheckEligibleResponse {
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String Status; 
        @AuraEnabled public EligibleData Data;
        
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
    }

    /**
     * Detailed eligibility data returned by the API.
     */
    public class EligibleData {
        @AuraEnabled public String BIRTHDAY;      
        @AuraEnabled public String GENDER;
        @AuraEnabled public String ID_CARD_NUMBER;
        @AuraEnabled public String LEAD_NEXTVALID;
        @AuraEnabled public String MAX_LOAN_AMOUNT_2;
        @AuraEnabled public String MIN_LOAN_AMOUNT_2;
        @AuraEnabled public String OPPORTUNITY_NAME;
        @AuraEnabled public String pxObjClass;
    }

    // ============================================================
    // LOGGING & UTILITY CLASSES
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

    public class ValidationResult {
        public Boolean isValid;
        public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
        }
    }

    // ============================================================
    // MAIN CALLOUT METHOD
    // ============================================================
    /**
     * Executes the CheckEligible API callout.
     * 
     * @param idCardNumber The customer's ID card number (mandatory).
     * @return CheckEligibleResponse containing the result of the callout.
     */
    public static CheckEligibleResponse checkEligibility(String idCardNumber, String phoneNumber) {
        CheckEligibleResponse response = new CheckEligibleResponse();
        
        try {
            validateRequest(idCardNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_CheckEligible');

            // 1. Prepare Request Wrapper
            CheckEligibleRequest reqWrapper = new CheckEligibleRequest();

            // TEST: tạm tắt parameters/headers trong JSON log — bật lại sau khi thử API xong.
            // reqWrapper.headers = new Map<String, Object>{
            //     'TransID'     => FEC_CommonUltils.generateTransactionUUID(),
            //     'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            // };

            // reqWrapper.parameters = new Map<String, String>{
            //     'ID_CARD_NUMBER'    => idCardNumber,
            //     'PHONE_NUMBER'      => phoneNumber
            // };

            reqWrapper.body = new Map<String, Object>();
            String requestBodyJson = JSON.serialize(reqWrapper);

            // TEST: tạm tắt consumer_name từ CMDT (không ghi vào reqWrapper.headers).
            // if (apiConfig != null) {
            //     String consumerName = apiConfig.FEC_Consumer_Name__c;
            //     if (String.isNotBlank(consumerName)) {
            //         reqWrapper.headers.put('consumer_name', consumerName.trim());
            //     }
            // }

            String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.FEC_GET_CARD_TXN_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            
            endpoint += '?ID_CARD_NUMBER=' + EncodingUtil.urlEncode(idCardNumber,'UTF-8')
            + '&PHONE_NUMBER=' + EncodingUtil.urlEncode(phoneNumber,'UTF-8');

            Map<String,String> headers = new Map<String,String>{
                'TransID'     => FEC_CommonUltils.generateTransactionUUID(),
                'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };

            // 3. Execute Callout (GET + JSON body theo pattern hiện tại)
            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                headers,
                null
            );

            // 4. Log the Interaction
            responseLog = new ResponseLog(
                'FEC_CheckEligible',
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                requestBodyJson,
                res,
                null
            );

            // 5. Handle Response
            if (res.getStatusCode() == 200) {
                response = (CheckEligibleResponse) JSON.deserialize(res.getBody(), CheckEligibleResponse.class);
            } else {
                response.errorCode = String.valueOf(res.getStatusCode());
                response.errorMessage = 'API Error: ' + res.getStatus() + ' - ' + res.getBody();
            }

        } catch (Exception e) {
            response.errorCode = 'CALLOUT_EXCEPTION';
            response.errorMessage = e.getMessage();
            
            if (responseLog != null) {
                responseLog.errorMessage = e.getMessage();
            }
        }

        return response;
    }

    // ============================================================
    // HELPER METHODS
    // ============================================================

    /**
     * Checks if the response indicates the customer is eligible.
     */
    public static Boolean isEligible(CheckEligibleResponse response) {
        return response != null && 'true'.equalsIgnoreCase(response.Status);
    }

    /**
     * Validates input parameters before making the callout.
     */
    private static void validateRequest(String idCardNumber) {
        if (String.isBlank(idCardNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CardNumber'}));
        }

        // if (!Pattern.matches(FEC_ConstantCommon.PATTERN_NATIONAL_ID, idCardNumber)) {
        //     throw new CalloutException(System.Label.FEC_MSG_National_ID_Invalid);
        // }
    }

    // /**
    //  * Persists the API log to the database.
    //  */
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