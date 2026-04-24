/****************************************************************************************
 * File Name    : FEC_SearchByListNIDsServiceCallout.Apex
 * Author       : LongNH76
 * Date         : 2026-04-21
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-04-21     LongNH76             Create
 
****************************************************************************************/
public with sharing class FEC_SearchByListNIDsServiceCallout {
  
    public class NIDsResponse {
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public List<Result> result;
        @AuraEnabled public Sys2 sys2;
    }

    public class Result {
        @AuraEnabled public String agentCode;
        @AuraEnabled public String agentName;
        @AuraEnabled public String buyerDOB;
        @AuraEnabled public String buyerGender;
        @AuraEnabled public String buyerName;
        @AuraEnabled public String buyerNID;
        @AuraEnabled public String buyerPhone;
        @AuraEnabled public Decimal collectedPremiumFee;
        @AuraEnabled public String effectiveDate;
        @AuraEnabled public String expireDate;
        @AuraEnabled public String insurerCompany;
        @AuraEnabled public String MarkedBuyerNID;
        @AuraEnabled public String MarkedBuyerPhone;
        @AuraEnabled public String paymentID;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String productNameEn;
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String saleChannel;
        @AuraEnabled public String saleSubChannel;
        @AuraEnabled public String StatusDisplay;
        @AuraEnabled public String userID;
        @AuraEnabled public String cancelDate;
    }

    public class Sys2 {
        @AuraEnabled public String code2;
        @AuraEnabled public String datetime4;
        @AuraEnabled public String description2;
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String transID2;
    }

    private static ResponseLog responseLog;

    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(
            String apiName,
            String endpoint,
            String method,
            String requestBody,
            HttpResponse response,
            String errorMessage
        ) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }


    //=============== MAIN CALL METHOD ===============//
    @AuraEnabled
    public static NIDsResponse searchByListNIDs(List<String> nationalIDs) {

        // Generate unique UUID for tracking
        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Search_By_List_NIDs');
        
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
            + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
       
        Map<String, Object> bodyMap = new  Map<String, Object>();
        
        bodyMap.put('sys', new Map<String, Object> {
            'dateTime' => Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_SSSSSS_XXX),
            'transID' => transactionId, 
            'requestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        });
        bodyMap.put('nationalID', nationalIDs);

        // Build request
        String requestBody = JSON.serialize(bodyMap);

        HttpResponse resp = FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            null,
            null,
            requestBody
        );
        responseLog = new ResponseLog(
            'FEC_Search_By_List_NIDs',
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            requestBody,
            resp,
            null
        );
        // Parse response
        if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
            return (NIDsResponse) JSON.deserialize(resp.getBody(), NIDsResponse.class);
            
        } else {
            NIDsResponse err = new NIDsResponse();
            err.sys2 = new Sys2();
            err.sys2.code2 = String.valueOf(resp.getStatusCode());
            err.sys2.description2 = 'HTTP Error: ' + resp.getStatus();
            err.sys2.transID2 = transactionId;
            return err;
        }
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