public without sharing class FEC_CheckEligibleCallout {

    public static final String API_CONFIG_NAME = 'FEC_CheckEligible';
    private static ResponseLog responseLog;

    // ============================================================
    // REQUEST CLASSES
    // ============================================================
    /**
     * Represents the request structure for the CheckEligible API.
     * Following the pattern: { headers: {}, parameters: [...], body: {} }
     */
    public class CheckEligibleRequest {
        public Map<String, String> headers;
        public List<String> parameters;
        public Map<String, Object> body;

        public CheckEligibleRequest() {
            this.headers = new Map<String, String>();
            this.parameters = new List<String>();
            this.body = new Map<String, Object>();
        }
    }

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================
    /**
     * Root response object for CheckEligible API.
     */
    public class CheckEligibleResponse {
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String Status; // "true" = Eligible
        @AuraEnabled public EligibleData Data;
        
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
    }

    /**
     * Detailed eligibility data returned by the API.
     */
    public class EligibleData {
        @AuraEnabled public String BIRTHDAY;          // YYYY-MM-DD
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
    public static CheckEligibleResponse checkEligibility(String idCardNumber) {
        CheckEligibleResponse response = new CheckEligibleResponse();
        
        try {
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            // 1. Prepare Request Wrapper
            CheckEligibleRequest reqWrapper = new CheckEligibleRequest();

            // Add ID_CARD_NUMBER as the first parameter per the example structure
            reqWrapper.parameters.add(idCardNumber);
            // Empty second parameter as per the "Reserved / optional" requirement
            reqWrapper.parameters.add('');

            // Set standard headers (also embedded in JSON body via serialize)
            reqWrapper.headers.put('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE_JSON);
            reqWrapper.headers.put('TransID', generateTransactionId());
            // API Gateway (apigw): consumer_name — giá trị trên Custom Metadata FEC_CheckEligible.FEC_Consumer_Name__c (dùng get() để deploy class trước field vẫn compile)
            if (apiConfig != null) {
                String consumerName = (String) apiConfig.get('FEC_Consumer_Name__c');
                if (String.isNotBlank(consumerName)) {
                    reqWrapper.headers.put('consumer_name', consumerName.trim());
                }
            }

            String requestBodyJson = JSON.serialize(reqWrapper);

            // 2. Resolve Endpoint
            String endpoint = (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            // 3. Execute Callout (GET + JSON body theo pattern hiện tại)
            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
                endpoint,
                FEC_ConstantCommon.API_METHOD_GET,
                reqWrapper.headers,
                requestBodyJson
            );

            // 4. Log the Interaction
            responseLog = new ResponseLog(
                API_CONFIG_NAME,
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
    public static ValidationResult validateRequest(String idCardNumber) {
        if (String.isBlank(idCardNumber)) {
            return new ValidationResult(false, 'ID Card Number is required.');
        }
        
        // Example regex validation for National ID (matching project constants if available)
        if (!Pattern.matches('^(\\d{9}|\\d{12})$', idCardNumber)) {
             return new ValidationResult(false, 'Invalid ID Card Number format.');
        }

        return new ValidationResult(true, null);
    }

    /**
     * Persists the API log to the database.
     */
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

    /**
     * Generates a unique transaction identifier.
     */
    private static String generateTransactionId() {
        return 'SF-' + Datetime.now().getTime() + '-' + Crypto.getRandomInteger();
    }
}
