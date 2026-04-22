public with sharing class FEC_FetchCollectionDataServiceCallout {
  
    public class CollectionDataResponse {
        @AuraEnabled public Boolean Success;
        @AuraEnabled public List<AllocationHistory> AllocationHistory;
        @AuraEnabled public List<CommunicationHistory> CommunicationHistory;
        @AuraEnabled public List<InteractionHistory> CollectionInteractions;
        @AuraEnabled public NFUDetailsList NFU;
    }

   public class AllocationHistory {
        @AuraEnabled public String POS;
        @AuraEnabled public String AllocationDate;
        @AuraEnabled public String CurrentBucket;
        @AuraEnabled public String DPD;
        @AuraEnabled public String AgentID;
        @AuraEnabled public String AgentName;
        @AuraEnabled public String Job;
        @AuraEnabled public String BucketDownLayerName;
    }

    public class CommunicationHistory {
        @AuraEnabled public String ContractNumber;
        @AuraEnabled public String CommunicationType;
        @AuraEnabled public String Template;
        @AuraEnabled public String CampaignName;
        @AuraEnabled public String PhoneNumber;
        @AuraEnabled public String CommunicatedDate;
        @AuraEnabled public String Address;
        //08:53:06:450 USER_DEBUG [20]|DEBUG|BODY: 
        // {"CommunicationHistory":
        // [{"ContractNumber":"20161129-0006618",
        // "Address":"",
        // "CampaignName":"TEST_CS21_DAY_OF_RUNDATE_POSTDUE_CAMPAIGN",
        // "PhoneNumber":"XXXXXXXXXXX",
        // "CommunicatedDate":"20260325T144016.799 GMT",
        // "CommunicationType":"VB","Template":"CS21_DOD"},{
        //     "ContractNumber":"20161129-0006618","Address":"",
    }

    public class InteractionHistory {
        @AuraEnabled public String InteractedAgentsID;
        @AuraEnabled public String InteractedDate;
        @AuraEnabled public String InteractedCode;
        @AuraEnabled public String PhoneNumber;
        @AuraEnabled public String PromisedRepaymentAmount;
        @AuraEnabled public String NextInteractionDate;
        @AuraEnabled public String ContactedPerson;
        @AuraEnabled public String DueReason;
        @AuraEnabled public String OtherNotes;
    }

    public class NFUDetailsList {
        @AuraEnabled public String NFUStatus;
        @AuraEnabled public String NFUStartDate;
        @AuraEnabled public String NFUExpiryDate;
        @AuraEnabled public String NFUCode;
        @AuraEnabled public String NFUReason;
        //{"NFUDetailsList":
        // [{
        //     "ContractNumber":"20161129-0006618",
        //     "NFUReason":"",
        //     "NFUCode":"",
        //     "NFUStatus":"Y",
        //     "NFUStartDate":"20260310T103856.862 GMT",
        //     "NFUExpiryDate":"22991227"
        // }],"Success":"true"}
    }

    //=============== MAIN CALL METHOD ===============//
    @AuraEnabled 
    public static CollectionDataResponse fetchCollectionData(String contractNumber, String recordType) {
        //PhongBT11: Giữ nguyên signature cũ, delegate sang method mới với default date values
        // để không break các caller hiện tại
        return fetchCollectionDataWithDates(contractNumber, recordType, '20251212', '99991212');
    }

    // Overload mới: thêm startDate và endDate
    @AuraEnabled
    public static CollectionDataResponse fetchCollectionDataWithDates(String contractNumber, String recordType, String startDate, String endDate) {
        System.debug('contractNumber: ' + contractNumber);
        System.debug('recordType: ' + recordType);
        System.debug('startDate: ' + startDate);
        System.debug('endDate: ' + endDate);

        if (String.isBlank(contractNumber)) {
            throw new CalloutException(System.Label.FEC_Contract_Number_Is_Null);
        }
        if (String.isBlank(recordType)) {
            throw new CalloutException(System.Label.FEC_Record_Type_Is_Null);
        }

        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Fetch_Collection_Data');

        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
                + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');

        Map<String, String> headers = new Map<String, String>{
            'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };

        Map<String, Object> bodyMap = new Map<String, Object>();
        bodyMap.put('ContractNumber', contractNumber);
        bodyMap.put('RecordType', recordType);
        bodyMap.put('StartDate', String.isNotBlank(startDate) ? startDate : '20251212');
        bodyMap.put('EndDate', String.isNotBlank(endDate) ? endDate : '99991212');

        String requestBody = JSON.serialize(bodyMap);

        System.debug('===== API REQUEST =====');
        System.debug('ENDPOINT: ' + endpoint);
        System.debug('METHOD: POST');
        System.debug('HEADERS: ' + JSON.serialize(headers));
        System.debug('BODY: ' + requestBody);

        try {
            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_POST, headers, requestBody);

            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                return (CollectionDataResponse) JSON.deserialize(resp.getBody(), CollectionDataResponse.class);
            } else {
                System.debug('response: ' + resp);
                CollectionDataResponse err = new CollectionDataResponse();
                err.Success = false;
                return err;
            }
        } catch (Exception ex) {
            CollectionDataResponse err = new CollectionDataResponse();
            err.Success = false;
            return err;
        }
    }
}