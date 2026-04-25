public with sharing class FEC_FetchCollectionDataServiceCallout {
  
    public class CollectionDataResponse {
        @AuraEnabled public Boolean Success;
        @AuraEnabled public List<AllocationHistory> AllocationHistory;
        @AuraEnabled public List<CommunicationHistory> CommunicationHistory;
        @AuraEnabled public List<InteractionHistory> CollectionInteractions;
        @AuraEnabled public NFU NFU;
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
        @AuraEnabled public String Address2;
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

    public class NFU {
        @AuraEnabled public String NFUStatus;
        @AuraEnabled public String NFUStartDate;
        @AuraEnabled public String NFUExpiryDate;
        @AuraEnabled public String NFUCode;
        @AuraEnabled public String NFUReason;
    }

    //=============== MAIN CALL METHOD ===============//
    @AuraEnabled 
    public static CollectionDataResponse fetchCollectionData(String contractNumber, String recordType) {
        System.System.debug('contractNumber: ' +contractNumber);
        System.System.debug('recordType: ' +recordType);
        if (String.isBlank(contractNumber)) {
            throw new CalloutException(
                System.Label.FEC_Contract_Number_Is_Null
            );
        }

        if (String.isBlank(recordType)) {
            throw new CalloutException(
                System.Label.FEC_Record_Type_Is_Null
            );
        }

        // Generate unique UUID for tracking
        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Fetch_Collection_Data');
        
        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
                + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
       
        Map<String, String> headers = new Map<String, String>{
            'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };
        
        Map<String, Object> bodyMap = new  Map<String, Object>();
        bodyMap.put('ContractNumber', contractNumber);
        bodyMap.put('RecordType', recordType);
        // Build request
        String requestBody = JSON.serialize(bodyMap);
        
        try {
            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_POST, headers, requestBody);

            // Parse response
            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                return (CollectionDataResponse) JSON.deserialize(resp.getBody(), CollectionDataResponse.class);
                
            } else {
                System.debug('response: ' + resp);
                CollectionDataResponse err = new CollectionDataResponse();
                err.Success = false;
                  System.System.debug('err: ' +err);
                return err;
            }
            
        } catch (Exception ex) {
            CollectionDataResponse err = new CollectionDataResponse();
            err.Success = false;
            System.System.debug('err: ' +err);
            return err;
        }

    }
}