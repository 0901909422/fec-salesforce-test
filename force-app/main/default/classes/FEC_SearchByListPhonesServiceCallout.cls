/****************************************************************************************
 * File Name    : FEC_SearchByListPhonesServiceCallout.Apex
 * Author       : LongNH76
 * Date         : 2026-04-27
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-04-27     LongNH76             Create
 
****************************************************************************************/

public with sharing class FEC_SearchByListPhonesServiceCallout {
    //tạo ra cho đỡ cần Metadata file
    private static final String API_NAME = 'FEC_Search_By_List_Phones';
    public class PhonesResponse {
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
        @AuraEnabled public String markedBuyerNID;
        @AuraEnabled public String markedBuyerPhone;
        @AuraEnabled public String paymentID;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String productNameEn;
        @AuraEnabled public String pxObjClass;
        @AuraEnabled public String saleChannel;
        @AuraEnabled public String saleSubChannel;
        @AuraEnabled public String statusDisplay;
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

    @AuraEnabled
    public static PhonesResponse searchByListPhones(List<String> phones) {
        if (phones == null || phones.isEmpty()) {
            throw new CalloutException('Phone list cannot be empty');
        }

        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Search_By_List_Phones');
    
        if (String.isBlank(apiConfig?.FEC_Endpoint__c)) {
            throw new CalloutException('Missing API endpoint config: FEC_Search_By_List_Phones');
        }
        String endpointPath = apiConfig.FEC_Endpoint__c;
        String endpoint =
            (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '') +
            endpointPath;

        Map<String, Object> bodyMap = new Map<String, Object>();
        bodyMap.put('sys', new Map<String, Object>{
            'dateTime' => Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_SSSSSS_XXX),
            'transID' => transactionId,
            'requestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM
        });
        bodyMap.put('phone', phones);

        String requestBody = JSON.serialize(bodyMap);
        HttpResponse resp = FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            null,
            null,
            requestBody
        );

        FEC_CommonUltils.logApi(
            API_NAME,
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            requestBody,
            resp,
            null
        );

        if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
            return (PhonesResponse) JSON.deserialize(resp.getBody(), PhonesResponse.class);
        }

        PhonesResponse err = new PhonesResponse();
        err.sys2 = new Sys2();
        err.sys2.code2 = String.valueOf(resp.getStatusCode());
        err.sys2.description2 = 'HTTP Error: ' + resp.getStatus();
        err.sys2.transID2 = transactionId;
        return err;
    }
}