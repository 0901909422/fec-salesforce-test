public with sharing class FEC_ApplicationsListController {

    /* =====================================================
     * DTO 
     * ===================================================== */
    public class ApplicationRowDTO {
        @AuraEnabled public Id id;
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
    }

    /* =====================================================
     * INIT – CALL API 
     * ===================================================== */
    @AuraEnabled
    public static void loadApplicationInfo(Id caseId) {

        if (caseId == null) return;

        Case cs = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (cs.FEC_Account_or_Contract__c == null) return;

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
                FEC_ConstantCommon.REQUESTOR_CRM, null, false,
                null, null, null, null, null, null, null, null
            );
        } catch (Exception e) {
            cusRes = null;
        }

        if (cusRes == null || cusRes.Customers == null) return;

        for (FEC_GetCustomerList.Customer cus : cusRes.Customers) {

            if (cus.Applications == null) continue;

            String cif = cus.CIFNumber;

            /* =================================================
             * API 2 – APPLICATION STATUS 
             * ================================================= */
            FEC_GetApplicationsList.ResponseWrapper statusRes;
            try {
                statusRes =
                    FEC_GetApplicationsList.callGetApplicationsList(
                        FEC_ConstantCommon.REQUESTOR_RES,
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
                        FEC_ConstantCommon.REQUESTOR_RES,
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                        cif
                    );
            } catch (Exception e) {
                addrRes = null;
            }

            for (FEC_GetCustomerList.Application app : cus.Applications) {

                Map<String, Object> row =
                    new Map<String, Object>();

                row.put('applicationId', app.ApplicationID);
                row.put('accountNumber', app.AccountNumber);
                row.put('contractNumber', app.ContractNumber);
                row.put('productGroup', app.Product);
                row.put('nationalPassportID',cus.NationalID);

                if (cus.Phones != null && !cus.Phones.isEmpty()) {
                    row.put(
                        'registrationPhone',
                       cus.Phones[0].Phone
                    );
                }

                if (cus.Emails != null && !cus.Emails.isEmpty()) {
                    row.put(
                        'registrationEmail',
                        cus.Emails[0].Email
                    );
                }

                /* STATUS */
                if (statusRes != null &&
                    statusRes.Applications != null) {

                    for (FEC_GetApplicationsList.ApplicationInfo st
                        : statusRes.Applications) {

                        if (st.ApplicationID == app.ApplicationID) {
                            row.put('lastStatus', st.LastStatus);
                            row.put('updateDate', st.DateStatus);
                            break;
                        }
                    }
                }

                /* ADDRESS */
                if (addrRes != null && addrRes.Addresses != null) {
                    for (FEC_GetAddressesList.AddressInfo ad
                        : addrRes.Addresses) {

                        if (ad.AddressType == 'CURRES') {
                            row.put(
                                'currentAddress',
                                formatAddress(ad)
                            );
                        }
                        if (ad.AddressType == 'PERMNENT') {
                            row.put(
                                'permanentAddress',
                                formatAddress(ad)
                            );
                        }
                        if (ad.AddressType == 'OFFICE') {
                            row.put(
                                'officeAddress',
                                formatAddress(ad)
                            );
                        }
                    }
                }

                /* =====================================================
                * API 4 – CUSTOMER SALE DISBURSE INFO
                * (Independent – fail thì bỏ qua)
                * ===================================================== */
                FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes;
                try {
                    saleRes = FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo('APP123456');
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
    public static ApplicationRowDTO loadApplicationDetail(Id applicationListId) {

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

        if (rawList.isEmpty()) return null;

        ApplicationRowDTO dto =
            (ApplicationRowDTO) JSON.deserialize(
                JSON.serialize(rawList[0]),
                ApplicationRowDTO.class
            );

        dto.id = rec.Id;
        if (rec.FEC_Customer_History__c != null) {
            List<Case> cases = [
                SELECT Id,FEC_Account_or_Contract__c
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
            dto.id = rec.Id;
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

    /* =====================================================
     * HELPERS
     * ===================================================== */

    private static String formatAddress(
        FEC_GetAddressesList.AddressInfo ad
    ) {
        List<String> parts = new List<String>();
        if (!String.isBlank(ad.Street)) parts.add(ad.Street);
        if (!String.isBlank(ad.City)) parts.add(ad.City);
        if (!String.isBlank(ad.CountryName)) parts.add(ad.CountryName);
        return String.join(parts, ', ');
    }
}