public with sharing class FEC_FetchCollectionDataServiceCallout {
  
    public class CollectionDataResponse {
        @AuraEnabled public String Success;
        @AuraEnabled public List<AllocationHistory> AllocationHistory;
        @AuraEnabled public List<CommunicationHistory> CommunicationHistory;
        /** API middleware trả key InteractionHistory; LWC đọc trực tiếp key này. */
        @AuraEnabled public List<CollectionInteractionItem> InteractionHistory;
        @AuraEnabled public List<NFUItem> NFUDetailsList;
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

    /** Bản ghi tương tác — đổi tên class để tránh trùng property InteractionHistory (JSON API). */
    public class CollectionInteractionItem {
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

    public class NFUItem {
        @AuraEnabled public String NFUStatus;
        @AuraEnabled public String NFUStartDate;
        @AuraEnabled public String NFUExpiryDate;
        @AuraEnabled public String NFUCode;
        @AuraEnabled public String NFUReason;
    }

    //=============== MAIN CALL METHOD ===============//
    @AuraEnabled
    public static CollectionDataResponse fetchCollectionData(
        String contractNumber,
        String recordType,
        Id caseId
    ) {
        return fetchCollectionDataWithDates(contractNumber, recordType, '20251212', '99991212', caseId);
    }

    @AuraEnabled
    public static CollectionDataResponse fetchCollectionDataWithDates(
        String contractNumber,
        String recordType,
        String startDate,
        String endDate,
        Id caseId
    ) {
        System.debug('contractNumber: ' + contractNumber);
        System.debug('recordType: ' + recordType);
        System.debug('startDate: ' + startDate);
        System.debug('endDate: ' + endDate);
        System.debug('caseId: ' + caseId);

        if (String.isBlank(contractNumber)) {
            throw new CalloutException(System.Label.FEC_Contract_Number_Is_Null);
        }
        if (String.isBlank(recordType)) {
            throw new CalloutException(System.Label.FEC_Record_Type_Is_Null);
        }

        String apiContractNumber = resolveContractNumberForApi(contractNumber, caseId);
        System.debug('apiContractNumber: ' + apiContractNumber);

        String transactionId = String.valueOf(UUID.randomUUID());

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Fetch_Collection_Data');

        String endpoint = (String.isNotBlank(apiSetting?.FEC_Endpoint__c) ? apiSetting.FEC_Endpoint__c : '')
                + (String.isNotBlank(apiConfig?.FEC_Endpoint__c) ? apiConfig.FEC_Endpoint__c : '');
        endpoint += '?ContractNumber=' + apiContractNumber
                    + '&StartDate=' + startDate
                    + '&EndDate=' + endDate
                    + '&RecordType=' + recordType;
        Map<String, String> headers = new Map<String, String>{
            // 'Accept' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
        };

        System.debug('===== API REQUEST =====');
        System.debug('ENDPOINT: ' + endpoint);
        System.debug('METHOD: GET');
        System.debug('HEADERS: ' + JSON.serialize(headers));

        try {
            HttpResponse resp = FEC_CommonUltils.calloutApiWithHeaders(endpoint, FEC_ConstantCommon.API_METHOD_GET, headers, null);

            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                System.debug('response: ' + resp.getBody());
                CollectionDataResponse deserialized =
                    (CollectionDataResponse) JSON.deserialize(resp.getBody(), CollectionDataResponse.class);
                return deserialized;
            } else {
                System.debug('response: ' + resp);
                CollectionDataResponse err = new CollectionDataResponse();
                err.Success = 'false';
                return err;
            }
        } catch (Exception ex) {
            System.debug('Exception: ' + ex);
            CollectionDataResponse err = new CollectionDataResponse();
            err.Success = 'false';
            return err;
        }
    }

    @TestVisible
    private static String resolveContractNumberForApi(String contractNumber, Id caseId) {
        if (caseId == null) {
            return contractNumber;
        }

        List<Case> cases = [
            SELECT FEC_Product_Type__r.Name,
                   FEC_Account_Number__c,
                   FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty() || !isCardProductType(cases[0].FEC_Product_Type__r?.Name)) {
            return contractNumber;
        }

        String accountNumber = resolveAccountNumberFromCase(cases[0]);
        return String.isNotBlank(accountNumber) ? accountNumber : contractNumber;
    }

    @TestVisible
    private static Boolean isCardProductType(String productTypeName) {
        return String.isNotBlank(productTypeName)
            && productTypeName.trim().equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE);
    }

    @TestVisible
    private static String resolveAccountNumberFromCase(Case c) {
        if (c == null) {
            return null;
        }
        if (c.FEC_Account_or_Contract__r != null
            && String.isNotBlank(c.FEC_Account_or_Contract__r.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        }
        if (c.FEC_Account_or_Contract__c != null) {
            List<FEC_Customer_History__c> rows = [
                SELECT FEC_Account_Number__c
                FROM FEC_Customer_History__c
                WHERE Id = :c.FEC_Account_or_Contract__c
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].FEC_Account_Number__c)) {
                return rows[0].FEC_Account_Number__c;
            }
        }
        return c.FEC_Account_Number__c;
    }

}