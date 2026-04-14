/**
 * Gọi API SearchByListNIDs (Banca Insurance) theo pattern FEC_GetCustomerList.
 * Config: FEC_API_Config__mdt.getInstance('FEC_Search_By_List_NIDs')
 */
public with sharing class FEC_SearchByListNIDs {

    public class InsuranceResult {
        @AuraEnabled public String userId;
        @AuraEnabled public String buyerName;
        @AuraEnabled public String buyerDOB;
        @AuraEnabled public String buyerNID;
        @AuraEnabled public String productNameEn;
        @AuraEnabled public String collectedPremiumFee;
        @AuraEnabled public String paymentID;
        @AuraEnabled public String effectiveDate;
        @AuraEnabled public String statusDisplay;
        @AuraEnabled public String policyNumber;
        @AuraEnabled public String insurerCompany;
        @AuraEnabled public String markedBuyerNID;
    }

    @AuraEnabled
    public static List<InsuranceResult> searchByNIDs(List<String> nationalIds) {
        if (nationalIds == null || nationalIds.isEmpty()) return new List<InsuranceResult>();

        return searchByNIDsReal(nationalIds);
    }

    // Gọi API thực — dùng khi có data thực trên UAT/Production
    @AuraEnabled
    public static List<InsuranceResult> searchByNIDsReal(List<String> nationalIds) {
        if (nationalIds == null || nationalIds.isEmpty()) return new List<InsuranceResult>();

        String transId = String.valueOf(UUID.randomUUID());
        String dateTimeStr = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.000000') + '+07:00';

        Map<String, Object> sysMap = new Map<String, Object>{
            'dateTime'    => dateTimeStr,
            'transID'     => transId,
            'requestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM
        };
        Map<String, Object> bodyMap = new Map<String, Object>{
            'sys'        => sysMap,
            'nationalID' => nationalIds
        };
        String jsonBody = JSON.serialize(bodyMap);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Search_By_List_NIDs');
        String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;

        HttpResponse res = FEC_CommonUltils.calloutApi(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            null,
            null,
            jsonBody
        );

        System.debug('FEC_SearchByListNIDs status: ' + res.getStatusCode());
        System.debug('FEC_SearchByListNIDs body: ' + res.getBody()?.left(500));

        if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
            return parseResponse(res.getBody());
        }
        return new List<InsuranceResult>();
    }

    private static List<InsuranceResult> parseResponse(String body) {
        List<InsuranceResult> results = new List<InsuranceResult>();
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> resultList = (List<Object>) parsed.get('result');
            if (resultList == null) return results;

            for (Object item : resultList) {
                Map<String, Object> r = (Map<String, Object>) item;
                InsuranceResult ins = new InsuranceResult();
                ins.userId              = (String) r.get('userID');
                ins.buyerName           = (String) r.get('buyerName');
                ins.buyerDOB            = (String) r.get('buyerDOB');
                ins.buyerNID            = (String) r.get('buyerNID');
                ins.productNameEn       = (String) r.get('productNameEn');
                ins.collectedPremiumFee = (String) r.get('collectedPremiumFee');
                ins.paymentID           = (String) r.get('paymentID');
                ins.effectiveDate       = (String) r.get('effectiveDate');
                ins.statusDisplay       = (String) r.get('StatusDisplay');
                ins.policyNumber        = (String) r.get('policyNumber');
                ins.insurerCompany      = (String) r.get('insurerCompany');
                ins.markedBuyerNID      = (String) r.get('MarkedBuyerNID');
                results.add(ins);
            }
        } catch (Exception e) {
            System.debug('FEC_SearchByListNIDs parse error: ' + e.getMessage());
        }
        return results;
    }
}
