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
        @AuraEnabled public Sys sys;
        @AuraEnabled public List<Result> result;
    }

    public class Sys {
        @AuraEnabled public String transID;
        @AuraEnabled public String datetime4;
        @AuraEnabled public Integer code;
        @AuraEnabled public String description;
        @AuraEnabled public String pxObjClass; 
    }

    public class Result {
        @AuraEnabled public String pxObjClass;

        @AuraEnabled public String userID;
        @AuraEnabled public String buyerName;
        @AuraEnabled public String buyerDOB;
        @AuraEnabled public String buyerNID;
        @AuraEnabled public String buyerPhone;
        @AuraEnabled public String productNameEn;
        @AuraEnabled public String collectedPremiumFee;
        @AuraEnabled public String paymentID;
        @AuraEnabled public String expireDate;
        @AuraEnabled public String effectiveDate;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String insurerCompany;
        @AuraEnabled public String agentCode;
        @AuraEnabled public String agentName;
        @AuraEnabled public String saleChannel;
        @AuraEnabled public String saleSubChannel;
        @AuraEnabled public String buyerGender;
        @AuraEnabled public String cancelDate;
        @AuraEnabled public String StatusDisplay;
    }

    @AuraEnabled(cacheable=false)
    public static NIDsResponse searchByListNIDs(List<String> nationalIDs) {

        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Search_By_List_NIDs');

        String endpoint =
            (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '') +
            (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');

        Map<String, Object> bodyMap = new Map<String, Object>{
            'sys' => new Map<String, Object>{
                'dateTime' => Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_SSSSSS_XXX),
                'transID' => transactionId,
                'requestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
            },
            'nationalID' => nationalIDs
        };

        String requestBody = JSON.serialize(bodyMap);

        HttpResponse resp = FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            null,
            null,
            requestBody
        );

        if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
            return (NIDsResponse) JSON.deserialize(resp.getBody(), NIDsResponse.class);
            
        }
        NIDsResponse err = new NIDsResponse();
        err.sys = new Sys();
        err.sys.code = resp.getStatusCode();
        err.sys.description = 'HTTP Error: ' + resp.getStatus();
        err.sys.transID = transactionId;
        return err;
    }
}