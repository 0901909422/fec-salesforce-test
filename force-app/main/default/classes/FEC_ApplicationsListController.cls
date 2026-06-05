/****************************************************************************************
 * File Name    : FEC_ApplicationsListController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-12
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-12     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_ApplicationsListController {

    /* =====================================================
     * DTO 
     * ===================================================== */
    public class ApplicationRowDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public Id caseId; 
        @AuraEnabled public String applicationId;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String contractNumber;
        @AuraEnabled public String lastStatus;
        @AuraEnabled public String updateDate;
        @AuraEnabled public String productGroup;
        @AuraEnabled public String nationalPassportID;
        @AuraEnabled public String registrationPhone;
        @AuraEnabled public String registrationEmail;
        @AuraEnabled public String currentAddress;
        @AuraEnabled public String permanentAddress;
        @AuraEnabled public String officeAddress;
        @AuraEnabled public String ccCode;
        @AuraEnabled public String ccName;
        @AuraEnabled public String dSACode;
        @AuraEnabled public String dSAName;
        @AuraEnabled public String tSACode;
        @AuraEnabled public String tSAName;
        @AuraEnabled public Map<String, String> helpTexts;
    }

    /* =====================================================
     * INIT – CALL API 
     * ===================================================== */
    @AuraEnabled
    public static void loadApplicationInfo(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        Case cs = [
            SELECT FEC_Account_or_Contract__c, FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Contract_Number__c, FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

       String productTypeName = 
            cs.FEC_Product_Type__c != null 
            ? cs.FEC_Product_Type__r.Name 
            : null;

        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            cs.FEC_Account_or_Contract__r.FEC_Account_Number__c,
            cs.FEC_Account_or_Contract__r.FEC_Contract_Number__c
        );

        Id historyId = cs.FEC_Account_or_Contract__c;

        FEC_Application_List__c cacheRec;

        List<FEC_Application_List__c> existed = [
            SELECT Id, FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE FEC_Customer_History__c = :historyId
            LIMIT 1
        ];

        if (!existed.isEmpty()) {
            cacheRec = existed[0];
            if (!String.isBlank(cacheRec.FEC_API_Cache_Applications__c)) {
                return;
            }
        } else {
            cacheRec = new FEC_Application_List__c(
                FEC_Customer_History__c = historyId
            );
        }

        List<Map<String, Object>> cacheData =
            new List<Map<String, Object>>();

        /* =====================================================
         * API 1 – CUSTOMER LIST
         * ===================================================== */
        FEC_GetCustomerList.ResponseWrapper cusRes;
        try {
            cusRes = FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN, null, false,
                null, null, null, null, accountNumber, null, null, null
            );
        } catch (Exception e) {
            cusRes = null;
        }

        if (cusRes == null || cusRes.Customers == null) return;

        // Cache Province/District maps ONCE before loop (avoid SOQL-in-loop)
        Map<String, String> cityMap = new Map<String, String>();
        for (FEC_Province__c c : [SELECT Name, FEC_Code__c, FEC_Name_VN__c FROM FEC_Province__c]) {
            cityMap.put(c.FEC_Code__c, c.FEC_Name_VN__c);
        }

        Map<String, String> districtMap = new Map<String, String>();
        for (FEC_District__c d : [SELECT Name, FEC_Code__c, FEC_Name_VN__c FROM FEC_District__c]) {
            districtMap.put(d.FEC_Code__c, d.FEC_Name_VN__c);
        }

        for (FEC_GetCustomerList.Customer cus : cusRes.Customers) {

            if (cus.Applications == null) continue;

            String cif = cus.CIFNumber;

            Map<String, FEC_GetProductListCallout.ProductInfo> productMap =
                new Map<String, FEC_GetProductListCallout.ProductInfo>();

            try {
                FEC_GetProductListCallout.CIF_GetProductsListResponse productRes =
                    FEC_GetProductListCallout.callService(cif);

                if (productRes != null && productRes.products != null) {
                    for (FEC_GetProductListCallout.ProductInfo p : productRes.products) {
                        if (String.isNotBlank(p.applicationId)) {
                            productMap.put(p.applicationId, p);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('GetProductList API failed: ' + e.getMessage());
            }

            /* =================================================
             * API 2 – APPLICATION STATUS 
             * ================================================= */
            FEC_GetApplicationsList.ResponseWrapper statusRes;
            try {
                statusRes =
                    FEC_GetApplicationsList.callGetApplicationsList(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                        cif
                    );
            } catch (Exception e) {
                statusRes = null;
            }

            /* =================================================
             * API 3 – ADDRESS
             * ================================================= */
            FEC_GetAddressesList.ResponseWrapper addrRes;
                try {
                    addrRes =
                        FEC_GetAddressesList.callGetAddressesList(
                            FEC_CommonUltils.generateTransactionId(),
                            FEC_ConstantCommon.REQUESTOR_CRM,
                            Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                            cif
                        );
                } catch (Exception e) {
                    addrRes = null;
                }

                // Province/District maps already cached outside loop
                // (moved to avoid SOQL-in-loop governor limit violation)

            for (FEC_GetApplicationsList.ApplicationInfo st: statusRes.Applications) {
                String accountNumbers = FEC_ConstantCommon.STR_NA;
                Map<String,Object> row = new Map<String,Object>();
                
                row.put('applicationId', st.ApplicationID);
                row.put('lastStatus', st.LastStatus);
                row.put('updateDate', st.DateStatus);
                row.put('productGroup', st.ProductGroup);

                row.put('nationalPassportID', cus.NationalID);

                if (cus.Phones != null && !cus.Phones.isEmpty()) {
                    row.put('registrationPhone', cus.Phones[0].Phone);
                }

                if (cus.Emails != null && !cus.Emails.isEmpty()) {
                    row.put('registrationEmail', cus.Emails[0].Email);
                }

                if (productMap.containsKey(st.ApplicationID)) {
                    FEC_GetProductListCallout.ProductInfo prod =
                        productMap.get(st.ApplicationID);
                    accountNumbers = String.isBlank(prod.accountNumber)
                        ? FEC_ConstantCommon.STR_NA
                        : prod.accountNumber;
                    row.put('contractNumber', prod.dealId);
                }
                row.put('accountNumber', accountNumbers);

                if (cus.Addresses != null) {
                    for (FEC_GetCustomerList.Address ad : cus.Addresses) {
                         String districtName = (ad.District != null && districtMap.containsKey(ad.District)) ? districtMap.get(ad.District) : ad.District;
                         String cityName = (ad.City != null && cityMap.containsKey(ad.City)) ? cityMap.get(ad.City) : ad.City;

                        if (ad.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_CURRES) {

                            row.put(
                                'currentAddress',
                                FEC_CommonUltils.formatAddress(
                                    ad.Building,    
                                    ad.HouseNumber,
                                    ad.Street,
                                    ad.Ward,
                                    districtName,
                                    cityName,
                                    ad.CountryName,
                                    ad.ZipCode
                                )
                            );

                            break;
                        }
                    }
                }

                /* ADDRESS */
                if (addrRes != null && addrRes.Addresses != null) {
                    for (FEC_GetAddressesList.AddressInfo ad
                        : addrRes.Addresses) {
                        String districtName = (ad.District != null && districtMap.containsKey(ad.District)) ? districtMap.get(ad.District) : ad.District;
                        String cityName = (ad.City != null && cityMap.containsKey(ad.City)) ? cityMap.get(ad.City) : ad.City;

                        if (ad.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT) {
                            row.put(
                                'permanentAddress',
                                FEC_CommonUltils.formatAddress(
                                    ad.Building,    
                                    ad.NumberStr,
                                    ad.Street,
                                    ad.Ward,
                                    districtName,
                                    cityName,
                                    ad.CountryName,
                                    ad.ZipCode
                                )
                            );
                        }
                        if (ad.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_OFFICE) {
                            row.put(
                                'officeAddress',
                                FEC_CommonUltils.formatAddress(
                                    ad.Building,    
                                    ad.NumberStr,
                                    ad.Street,
                                    ad.Ward,
                                    districtName,
                                    cityName,
                                    ad.CountryName,
                                    ad.ZipCode
                                )
                            );
                        }
                    }
                }

                /* =====================================================
                * API 4 – CUSTOMER SALE DISBURSE INFO
                * ===================================================== */
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes;
                try {
                    saleRes = FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(st.ApplicationID);
                    if (saleRes != null &&
                        saleRes.CustomerSaleInfos != null &&
                        !saleRes.CustomerSaleInfos.isEmpty()) {

                        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo sale =
                            saleRes.CustomerSaleInfos[0];

                        row.put('ccCode', sale.CC_CODE);
                        row.put('ccName', sale.CC_NAME);
                        row.put('dSACode', sale.DSA_CODE);
                        row.put('dSAName', sale.DSA_NAME);
                        row.put('tSACode', sale.TSA_CODE);
                        row.put('tSAName', sale.TSA_NAME);
                    }
                } catch (Exception e) {
                    System.debug('SaleDisburseInfo API failed: ' + e.getMessage());
                }

                cacheData.add(row);
            }
        }

        cacheRec.FEC_API_Cache_Applications__c =
            JSON.serialize(cacheData);

        upsert cacheRec;
    }

    @AuraEnabled(cacheable=true)
    public static ApplicationRowDTO loadApplicationDetail( Id applicationListId, String applicationId) {

        if (applicationListId == null) {
            return null;
        }

        FEC_Application_List__c rec = [
            SELECT Id, FEC_API_Cache_Applications__c,
            FEC_Customer_History__c
            FROM FEC_Application_List__c
            WHERE Id = :applicationListId
            LIMIT 1
        ];

        if (String.isBlank(rec.FEC_API_Cache_Applications__c)) {
            return null;
        }

        List<Object> rawList =
            (List<Object>) JSON.deserializeUntyped(
                rec.FEC_API_Cache_Applications__c
            );

        if (rawList.isEmpty()) {
            return null;
        }

        ApplicationRowDTO dto;

        for (Object obj : rawList) {

            ApplicationRowDTO temp =
                (ApplicationRowDTO) JSON.deserialize(
                    JSON.serialize(obj),
                    ApplicationRowDTO.class
                );

            if (temp.applicationId == applicationId) {
                dto = temp;
                break;
            }
        }

        if (dto == null) {
            return null;
        }

       dto.Id = rec.Id;

        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap( FEC_Application_List__c.SObjectType );
        if (rec.FEC_Customer_History__c != null) {
            List<Case> cases = [
                SELECT Id, FEC_Account_or_Contract__c
                FROM Case
                WHERE FEC_Account_or_Contract__c = :rec.FEC_Customer_History__c
                LIMIT 1
            ];

            if (!cases.isEmpty()) {
                dto.caseId = cases[0].Id;
            }
        }

        return dto;
    }

    /* =====================================================
     * UI – READ CACHE ONLY
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<ApplicationRowDTO> getApplicationsForUI(Id caseId) {

        if (caseId == null) return new List<ApplicationRowDTO>();

        Case cs = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (cs.FEC_Account_or_Contract__c == null)
            return new List<ApplicationRowDTO>();

        FEC_Application_List__c rec = [
            SELECT Id, FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE FEC_Customer_History__c =
                :cs.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        if (String.isBlank(rec.FEC_API_Cache_Applications__c))
            return new List<ApplicationRowDTO>();

        List<Object> raw =
            (List<Object>) JSON.deserializeUntyped(
                rec.FEC_API_Cache_Applications__c
            );

        List<ApplicationRowDTO> result =
            new List<ApplicationRowDTO>();

        for (Object o : raw) {
            ApplicationRowDTO dto =
                (ApplicationRowDTO) JSON.deserialize(
                    JSON.serialize(o),
                    ApplicationRowDTO.class
                );
            dto.Id = rec.Id;
            dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Application_List__c.SObjectType);
            result.add(dto);
        }

        return result;
    }

    /* =====================================================
     * LOG SENSITIVE
     * ===================================================== */
    @AuraEnabled
    public static void logSensitiveFromMainInfo(
        String section,
        String fieldLabel,
        Id relatedCaseId
    ) {
        User u = [
            SELECT Username, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        FEC_CommonUltils.logSensitiveAccess(
            section,
            fieldLabel,
            u.Username != null ? u.Username.split('@')[0] : null,
            u.UserRole != null ? u.UserRole.Name : null,
            relatedCaseId
        );
    }
}