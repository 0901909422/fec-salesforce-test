/****************************************************************************************
* File Name    : FEC_GetCardTransactions.Apex
* Author       : Quangdv7
* Date         : 2025-01-20
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2025-01-20     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_GetCardTransactions {

    // ============================================================
    // REQUEST CLASSES
    // ============================================================

    public class CardTxnRequest {
        public List<String> parameters;
        public Map<String, Object> headers;
        public Map<String, Object> body;
    }

    // ============================================================
    // RESPONSE CLASSES
    // ============================================================

    public class CardTxnResponse {
        public Sys Sys;
        public List<CardTransaction> CardTransactions;

        public String errorCode;
        public String errorMessage;
    }

    public class Sys {
        public String TransID;
        public String RequestorID;
        public String DateTimeStr;
        public String Code;
        public String Description;
    }

    public class CardTransaction {
        public String IPPPlan;
        public String PlanDescription;
    }

    // ============================================================
    // RESULT WRAPPER
    // ============================================================

    public class ResultWrapper {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorCode;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String transId;
        @AuraEnabled public List<CardTransaction> transactions;

        public ResultWrapper() {
            isSuccess = false;
            transactions = new List<CardTransaction>();
        }
    }

    // ============================================================
    // VALIDATION CLASS
    // ============================================================

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

    public static CardTxnResponse getCardTransactions(
        String transId,
        String dateTimeStr,
        String requestorId,
        String accountNumber,
        Date startDate,
        Date endDate
    ) {

        CardTxnResponse response;

        try {

            CardTxnRequest request = new CardTxnRequest();

            request.headers = new Map<String, Object>{
                'TransID'     => transId,
                'RequestorID' => requestorId,
                'DateTime'    => dateTimeStr,
                'Content-Type'=> FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };

            request.parameters = new List<String>{
                accountNumber,
                startDate != null ? startDate.format() : null,
                endDate != null ? endDate.format() : null
            };

            request.body = new Map<String, Object>();

            String requestBodyJson = JSON.serialize(request);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_GetCardTransactions');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.FEC_GET_CARD_TXN_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse resp = FEC_CommonUltils.calloutApi( endpoint,'POST', FEC_ConstantCommon.API_CONTENT_TYPE_JSON, '', null, requestBodyJson );
            if (resp.getStatusCode() == 200) {

                response = (CardTxnResponse)
                    JSON.deserialize(resp.getBody(), CardTxnResponse.class);

            } else {
                response = new CardTxnResponse();
                response.errorCode = String.valueOf(resp.getStatusCode());
                response.errorMessage = resp.getStatus();
            }

        } catch (Exception e) {

            response = new CardTxnResponse();
            response.errorCode = 'CALLOUT_ERROR';
            response.errorMessage = e.getMessage();
        }

        return response;
    }

    // ============================================================
    // SUCCESS 
    // ============================================================

    public static Boolean isSuccess(CardTxnResponse response) {
        return response != null
            && response.Sys != null
            && response.Sys.Code == '1';
    }

    // ============================================================
    // VALIDATION METHODS
    // ============================================================

    public static ValidationResult validateRequest(
        String transId,
        String requestorId,
        String accountNumber,
        Date startDate,
        Date endDate
    ) {

        if (String.isBlank(transId))
            return new ValidationResult(false, System.Label.FEC_MSG_TransID_Null);

        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
        };

        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId))
            return new ValidationResult(false, System.Label.FEC_MSG_RequestorID_Null);

        if (String.isBlank(accountNumber))
            return new ValidationResult(false, System.Label.FEC_MSG_AccountNumber_Null);

        if (startDate == null || endDate == null)
            return new ValidationResult(false, System.Label.FEC_MSG_StartDate_EndDate_Null);

        if (endDate < startDate)
            return new ValidationResult(false, System.Label.FEC_MSG_EndDate_Must_StartDate);

        return new ValidationResult(true, null);
    }

    public static ValidationResult validateResponse(CardTxnResponse response) {

        if (response == null)
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Null);

        if (String.isNotBlank(response.errorCode))
            return new ValidationResult(false,
                response.errorCode + ' - ' + response.errorMessage);

        if (response.Sys == null)
            return new ValidationResult(false, System.Label.FEC_MSG_Response_Sys_Null);

        if (response.Sys.Code != '1')
            return new ValidationResult(false,
                response.Sys.Description);

        return new ValidationResult(true, null);
    }

    // ============================================================
    // CONVERT TO RESULT WRAPPER
    // ============================================================

    public static ResultWrapper convertToResultWrapper(CardTxnResponse response) {

        ResultWrapper result = new ResultWrapper();

        ValidationResult validation = validateResponse(response);

        if (!validation.isValid) {
            result.errorCode = response != null ? response.errorCode : null;
            result.errorMessage = validation.errorMessage;
            return result;
        }

        result.isSuccess = true;
        result.transId = response.Sys.TransID;

        result.transactions = response.CardTransactions != null
            ? response.CardTransactions
            : new List<CardTransaction>();

        return result;
    }
}
