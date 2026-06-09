/****************************************************************************************
 * File Name    : FEC_BancaController.cls
 * Author       : Quangdv7
 * Date         : 2025-01-17
 * Description  : Handle Insurance(Banca) Information
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2025-01-17                         Create
****************************************************************************************/

public without sharing class FEC_BancaController {

    /* =====================================================
     * DTO
     * ===================================================== */
    public class BancaDTO {

        @AuraEnabled public Id Id;
        @AuraEnabled public Id caseId;

        @AuraEnabled public String userId;
        @AuraEnabled public String buyerName;
        @AuraEnabled public Date dateofBirth;
        @AuraEnabled public String buyerNID;
        @AuraEnabled public String productName;
        @AuraEnabled public String premiumFree;
        @AuraEnabled public String status;

        @AuraEnabled public String gender;
        @AuraEnabled public String salesChannel;
        @AuraEnabled public String insuranceCompany;
        @AuraEnabled public String subChannel;

        @AuraEnabled public String policyNumber;
        @AuraEnabled public String agentCode;
        @AuraEnabled public String phoneNumber;
        @AuraEnabled public String agentName;

        @AuraEnabled public Date expiryDate;
        @AuraEnabled public String paymentID;
        @AuraEnabled public Date cancelDate;
        @AuraEnabled public Date effectiveDate;
    }

    /* =====================================================
     * LOAD DATA
     * ===================================================== */
    @AuraEnabled
    public static List<BancaDTO> loadataInsurance(Id caseId) {

        if (caseId == null) {

            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Case Id' }
                )
            );
        }

        /* =====================================================
         * GET CASE INFO
         * ===================================================== */
        Case cs = [
            SELECT
                Id,
                FEC_Search_National_ID__c,
                FEC_Account_or_Contract__c,
                FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c,
                FEC_Account_or_Contract__r.FEC_Primary_Phone__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        List<String> nationalIds = collectNationalIdsForSearch(
            cs.FEC_Account_or_Contract__r != null
            ? cs.FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c
            : null,
            cs.FEC_Search_National_ID__c
        );

        String phone =
            cs.FEC_Account_or_Contract__r != null
            ? cs.FEC_Account_or_Contract__r.FEC_Primary_Phone__c
            : null;

        /* =====================================================
         * REMOVE DUPLICATE
         * ===================================================== */
        Map<String, BancaDTO> mapData =
            new Map<String, BancaDTO>();

        /* =====================================================
         * SEARCH BY NID 
         * ===================================================== */
        if (!nationalIds.isEmpty()) {

            try {

                FEC_SearchByListNIDsServiceCallout.NIDsResponse nidResp =
                    FEC_SearchByListNIDsServiceCallout.searchByListNIDs(
                        nationalIds
                    );

                if (
                    nidResp != null &&
                    nidResp.result != null &&
                    !nidResp.result.isEmpty()
                ) {
                    processNIDResponse(
                        nidResp,
                        caseId,
                        mapData
                    );
                }

            } catch (Exception e) {

                System.debug(
                    'SearchByListNIDs ERROR: ' + e.getMessage()
                );
            }
        }

        /* =====================================================
         * SEARCH BY PHONE
         * ===================================================== */
        if (!String.isBlank(phone)) {

            try {

                FEC_SearchByListPhonesServiceCallout.PhonesResponse phoneResp =
                    FEC_SearchByListPhonesServiceCallout.searchByListPhones(
                        new List<String>{ phone }
                    );

                if (
                    phoneResp != null &&
                    phoneResp.result != null &&
                    !phoneResp.result.isEmpty()
                ) {
                    processPhoneResponse(
                        phoneResp,
                        caseId,
                        mapData
                    );
                }

            } catch (Exception e) {

                System.debug(
                    'SearchByListPhones ERROR: ' + e.getMessage()
                );
            }
        }

        /* =====================================================
         * SAVE / UPDATE DB
         * ===================================================== */
        saveInsuranceInfo(
            cs.FEC_Account_or_Contract__c,
            mapData.values()
        );

        /* =====================================================
         * QUERY SAVED DATA
         * ===================================================== */
        List<FEC_Insurance_Info__c> savedRecords = [
            SELECT
                Id,
                FEC_User_ID__c,
                FEC_Buyer_Name__c,
                FEC_Buyer_DOB__c,
                FEC_Buyer_NID__c,
                FEC_Product_Name__c,
                FEC_Premium_Fee__c,
                FEC_Status__c,

                FEC_Buyer_Gender__c,
                FEC_Sale_Channel__c,
                FEC_Insurer_Company__c,
                FEC_Sub_Channel__c,

                FEC_Policy_Number__c,
                FEC_Agent_Code__c,
                FEC_Phone_Number__c,
                FEC_Agent_Name__c,

                FEC_Expiry_Date__c,
                FEC_Payment_ID__c,
                FEC_Cancel_Date__c,
                FEC_Effective_Date__c

            FROM FEC_Insurance_Info__c
            WHERE FEC_Customer_History__c =
                :cs.FEC_Account_or_Contract__c

            ORDER BY CreatedDate DESC
        ];

        /* =====================================================
         * RETURN DTO
         * ===================================================== */
        List<BancaDTO> result = new List<BancaDTO>();

        for (FEC_Insurance_Info__c rec : savedRecords) {

            BancaDTO dto = new BancaDTO();

            dto.Id               = rec.Id;
            dto.caseId           = caseId;

            dto.userId           = rec.FEC_User_ID__c;
            dto.buyerName        = rec.FEC_Buyer_Name__c;
            dto.dateofBirth      = rec.FEC_Buyer_DOB__c;
            dto.buyerNID         = rec.FEC_Buyer_NID__c;
            dto.productName      = rec.FEC_Product_Name__c;

            dto.premiumFree      =
                rec.FEC_Premium_Fee__c != null
                ? String.valueOf(rec.FEC_Premium_Fee__c)
                : null;

            dto.status           = rec.FEC_Status__c;

            dto.gender           = rec.FEC_Buyer_Gender__c;
            dto.salesChannel     = rec.FEC_Sale_Channel__c;
            dto.insuranceCompany = rec.FEC_Insurer_Company__c;
            dto.subChannel       = rec.FEC_Sub_Channel__c;

            dto.policyNumber     = rec.FEC_Policy_Number__c;
            dto.agentCode        = rec.FEC_Agent_Code__c;
            dto.phoneNumber      = rec.FEC_Phone_Number__c;
            dto.agentName        = rec.FEC_Agent_Name__c;

            dto.expiryDate       = rec.FEC_Expiry_Date__c;
            dto.paymentID        = rec.FEC_Payment_ID__c;
            dto.cancelDate       = rec.FEC_Cancel_Date__c;
            dto.effectiveDate    = rec.FEC_Effective_Date__c;

            result.add(dto);
        }

        return result;
    }

    /* =====================================================
     * LOAD INSURANCE DETAIL
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static BancaDTO loadInsuranceDetail(Id insuranceId) {

        if (insuranceId == null) {
            return null;
        }

        FEC_Insurance_Info__c rec = [
            SELECT
                Id,
                FEC_Customer_History__c,

                FEC_User_ID__c,
                FEC_Buyer_Name__c,
                FEC_Buyer_DOB__c,
                FEC_Buyer_NID__c,
                FEC_Product_Name__c,
                FEC_Premium_Fee__c,
                FEC_Status__c,

                FEC_Buyer_Gender__c,
                FEC_Sale_Channel__c,
                FEC_Insurer_Company__c,
                FEC_Sub_Channel__c,

                FEC_Policy_Number__c,
                FEC_Agent_Code__c,
                FEC_Phone_Number__c,
                FEC_Agent_Name__c,

                FEC_Expiry_Date__c,
                FEC_Payment_ID__c,
                FEC_Cancel_Date__c,
                FEC_Effective_Date__c

            FROM FEC_Insurance_Info__c
            WHERE Id = :insuranceId
            LIMIT 1
        ];

        BancaDTO dto = new BancaDTO();

        dto.Id               = rec.Id;
        dto.caseId           = rec.FEC_Customer_History__c;

        dto.userId           = rec.FEC_User_ID__c;
        dto.buyerName        = rec.FEC_Buyer_Name__c;
        dto.dateofBirth      = rec.FEC_Buyer_DOB__c;
        dto.buyerNID         = rec.FEC_Buyer_NID__c;
        dto.productName      = rec.FEC_Product_Name__c;

        dto.premiumFree      =
            rec.FEC_Premium_Fee__c != null
            ? String.valueOf(rec.FEC_Premium_Fee__c)
            : null;

        dto.status           = rec.FEC_Status__c;

        dto.gender           = rec.FEC_Buyer_Gender__c;
        dto.salesChannel     = rec.FEC_Sale_Channel__c;
        dto.insuranceCompany = rec.FEC_Insurer_Company__c;
        dto.subChannel       = rec.FEC_Sub_Channel__c;

        dto.policyNumber     = rec.FEC_Policy_Number__c;
        dto.agentCode        = rec.FEC_Agent_Code__c;
        dto.phoneNumber      = rec.FEC_Phone_Number__c;
        dto.agentName        = rec.FEC_Agent_Name__c;

        dto.expiryDate       = rec.FEC_Expiry_Date__c;
        dto.paymentID        = rec.FEC_Payment_ID__c;
        dto.cancelDate       = rec.FEC_Cancel_Date__c;
        dto.effectiveDate    = rec.FEC_Effective_Date__c;

        return dto;
    }

    /* =====================================================
     * PROCESS NID RESPONSE
     * ===================================================== */
    private static void processNIDResponse(
        FEC_SearchByListNIDsServiceCallout.NIDsResponse response,
        Id caseId,
        Map<String, BancaDTO> mapData
    ) {

        if (
            response == null ||
            response.result == null
        ) {
            return;
        }

        for (
            FEC_SearchByListNIDsServiceCallout.Result item :
            response.result
        ) {

            String mapKey = insuranceMapKey(
                item.userID,
                item.policyNumber,
                item.buyerNID
            );

            if (String.isBlank(mapKey)) {
                continue;
            }

            mapData.put(
                mapKey,
                mapFromNID(item, caseId)
            );
        }
    }

    /* =====================================================
     * PROCESS PHONE RESPONSE
     * ===================================================== */
    private static void processPhoneResponse(
        FEC_SearchByListPhonesServiceCallout.PhonesResponse response,
        Id caseId,
        Map<String, BancaDTO> mapData
    ) {

        if (
            response == null ||
            response.result == null
        ) {
            return;
        }

        for (
            FEC_SearchByListPhonesServiceCallout.Result item :
            response.result
        ) {

            String mapKey = insuranceMapKey(
                item.userID,
                item.policyNumber,
                item.buyerNID
            );

            if (String.isBlank(mapKey)) {
                continue;
            }

            mapData.put(
                mapKey,
                mapFromPhone(item, caseId)
            );
        }
    }

    /* =====================================================
     * MAP FROM NID
     * ===================================================== */
    private static BancaDTO mapFromNID(
        FEC_SearchByListNIDsServiceCallout.Result item,
        Id caseId
    ) {

        BancaDTO dto = new BancaDTO();

        dto.caseId           = caseId;
        dto.userId           = item.userID;
        dto.buyerName        = item.buyerName;
        dto.dateofBirth      = FEC_CommonUltils.toDateStr(item.buyerDOB);
        dto.buyerNID         = item.buyerNID;
        dto.productName      = item.productNameEn;
        dto.premiumFree      = String.valueOf(item.collectedPremiumFee);
        dto.status           = item.StatusDisplay;

        dto.gender           = item.buyerGender;
        dto.salesChannel     = item.saleChannel;
        dto.insuranceCompany = item.insurerCompany;
        dto.subChannel       = item.saleSubChannel;

        dto.policyNumber     = item.policyNumber;
        dto.agentCode        = item.agentCode;
        dto.phoneNumber      = item.buyerPhone;
        dto.agentName        = item.agentName;

        dto.expiryDate       = FEC_CommonUltils.toDateStr(item.expireDate);
        dto.paymentID        = item.paymentID;
        dto.cancelDate       = FEC_CommonUltils.toDateStr(item.cancelDate);
        dto.effectiveDate    = FEC_CommonUltils.toDateStr(item.effectiveDate);

        return dto;
    }

    /* =====================================================
     * MAP FROM PHONE
     * ===================================================== */
    private static BancaDTO mapFromPhone(
        FEC_SearchByListPhonesServiceCallout.Result item,
        Id caseId
    ) {

        BancaDTO dto = new BancaDTO();

        dto.caseId           = caseId;
        dto.userId           = item.userID;
        dto.buyerName        = item.buyerName;
        dto.dateofBirth      = FEC_CommonUltils.toDateStr(item.buyerDOB);
        dto.buyerNID         = item.buyerNID;
        dto.productName      = item.productNameEn;
        dto.premiumFree      = String.valueOf(item.collectedPremiumFee);
        dto.status           = item.statusDisplay;

        dto.gender           = item.buyerGender;
        dto.salesChannel     = item.saleChannel;
        dto.insuranceCompany = item.insurerCompany;
        dto.subChannel       = item.saleSubChannel;

        dto.policyNumber     = item.policyNumber;
        dto.agentCode        = item.agentCode;
        dto.phoneNumber      = item.buyerPhone;
        dto.agentName        = item.agentName;

        dto.expiryDate       = FEC_CommonUltils.toDateStr(item.expireDate);
        dto.paymentID        = item.paymentID;
        dto.cancelDate       = FEC_CommonUltils.toDateStr(item.cancelDate);
        dto.effectiveDate    = FEC_CommonUltils.toDateStr(item.effectiveDate);

        return dto;
    }

    /* =====================================================
     * SAVE INSURANCE INFO
     * ===================================================== */
    private static List<FEC_Insurance_Info__c> saveInsuranceInfo(
        Id customerHistoryId,
        List<BancaDTO> dataList
    ) {

        List<FEC_Insurance_Info__c> upsertList =
            new List<FEC_Insurance_Info__c>();

        if (
            customerHistoryId == null ||
            dataList == null ||
            dataList.isEmpty()
        ) {
            return upsertList;
        }

        /* =====================================================
         * GET EXISTING DATA
         * ===================================================== */
        Map<String, FEC_Insurance_Info__c> existingMap =
            new Map<String, FEC_Insurance_Info__c>();

        for (
            FEC_Insurance_Info__c oldRec :
            [
                SELECT
                    Id,
                    FEC_User_ID__c,
                    FEC_Policy_Number__c,
                    FEC_Buyer_NID__c
                FROM FEC_Insurance_Info__c
                WHERE FEC_Customer_History__c = :customerHistoryId
            ]
        ) {

            String existingKey = insuranceMapKey(
                oldRec.FEC_User_ID__c,
                oldRec.FEC_Policy_Number__c,
                oldRec.FEC_Buyer_NID__c
            );

            if (!String.isBlank(existingKey)) {
                existingMap.put(existingKey, oldRec);
            }
        }

        /* =====================================================
         * INSERT / UPDATE
         * ===================================================== */
        for (BancaDTO dto : dataList) {

            FEC_Insurance_Info__c rec;

            String dtoKey = insuranceMapKey(
                dto.userId,
                dto.policyNumber,
                dto.buyerNID
            );

            if (
                !String.isBlank(dtoKey) &&
                existingMap.containsKey(dtoKey)
            ) {

                rec = existingMap.get(dtoKey);

            } else {

                rec = new FEC_Insurance_Info__c();
                rec.FEC_Customer_History__c =
                    customerHistoryId;
            }

            rec.FEC_User_ID__c         = dto.userId;
            rec.FEC_Buyer_Name__c      = dto.buyerName;
            rec.FEC_Buyer_DOB__c       = dto.dateofBirth;
            rec.FEC_Buyer_NID__c       = dto.buyerNID;
            rec.FEC_Product_Name__c    = dto.productName;

            if (!String.isBlank(dto.premiumFree)) {

                try {
                    rec.FEC_Premium_Fee__c =
                        Decimal.valueOf(dto.premiumFree);
                } catch (Exception e) {
                    System.debug(
                        'Premium parse error: ' +
                        e.getMessage()
                    );
                }
            }

            rec.FEC_Status__c          = dto.status;
            rec.FEC_Buyer_Gender__c    = dto.gender;

            rec.FEC_Sale_Channel__c    = dto.salesChannel;
            rec.FEC_Sub_Channel__c     = dto.subChannel;

            rec.FEC_Insurer_Company__c = dto.insuranceCompany;

            rec.FEC_Policy_Number__c   = dto.policyNumber;

            rec.FEC_Agent_Code__c      = dto.agentCode;
            rec.FEC_Agent_Name__c      = dto.agentName;

            rec.FEC_Phone_Number__c    = dto.phoneNumber;

            rec.FEC_Expiry_Date__c     = dto.expiryDate;
            rec.FEC_Cancel_Date__c     = dto.cancelDate;
            rec.FEC_Effective_Date__c  = dto.effectiveDate;

            rec.FEC_Payment_ID__c      = dto.paymentID;

            upsertList.add(rec);
        }

        if (!upsertList.isEmpty()) {
            upsert upsertList;
        }

        return upsertList;
    }

    /* =====================================================
     * COLLECT NATIONAL IDs (History + Case search fields)
     * ===================================================== */
    private static List<String> collectNationalIdsForSearch(
        String historyNationalIds,
        String caseSearchNationalId
    ) {
        Set<String> seen = new Set<String>();
        List<String> nationalIds = new List<String>();

        for (String raw : new List<String>{
            historyNationalIds,
            caseSearchNationalId
        }) {
            for (String id : parseCommaSeparatedNationalIds(raw)) {
                if (!seen.contains(id)) {
                    seen.add(id);
                    nationalIds.add(id);
                }
            }
        }

        return nationalIds;
    }

    /* =====================================================
     * MAP KEY
     * ===================================================== */
    private static String insuranceMapKey(
        String userId,
        String policyNumber,
        String buyerNid
    ) {
        if (!String.isBlank(policyNumber)) {
            return 'POL:' + policyNumber.trim();
        }

        if (!String.isBlank(userId)) {
            String key = 'UID:' + userId.trim();
            if (!String.isBlank(buyerNid)) {
                key += ':' + buyerNid.trim();
            }
            return key;
        }

        if (!String.isBlank(buyerNid)) {
            return 'NID:' + buyerNid.trim();
        }

        return null;
    }

    /* =====================================================
     * PARSE COMMA-SEPARATED NATIONAL IDs
     * ===================================================== */
    private static List<String> parseCommaSeparatedNationalIds(String raw) {

        List<String> nationalIds = new List<String>();

        if (String.isBlank(raw)) {
            return nationalIds;
        }

        for (String part : raw.split('[,;\\n\\r]+')) {

            String trimmed = part != null ? part.trim() : null;

            if (!String.isBlank(trimmed)) {
                nationalIds.add(trimmed);
            }
        }

        return nationalIds;
    }
}