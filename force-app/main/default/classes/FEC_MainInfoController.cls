/****************************************************************************************
 * File Name    : FEC_MainInfoController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_MainInfoController {

    /** Legacy: chỉ đọc khi bản ghi cũ còn dữ liệu trong FEC_Address__c (không ghi thêm). */
    private static final String PENDING_ADDR_META_PREFIX = 'FEC_ADDR_META';
    private static final String PENDING_ADDR_META_SEP = '\u001F';

    /* =====================================================
     * DTO
     * ===================================================== */
    public class MainInfoDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public String fullName;
        @AuraEnabled public String firstName;
        @AuraEnabled public String middleName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Date birthDate;
        @AuraEnabled public String gender;
        @AuraEnabled public String maritalStatus;
        @AuraEnabled public String cifNumber;
        @AuraEnabled public String nationalIDPassportID;
        @AuraEnabled public String dateOfIssue;
        @AuraEnabled public String placeOfIssue;
        @AuraEnabled public String primaryPhone;
        @AuraEnabled public List<AddressDTO> addresses;
        /** Tiêu đề khi KH không đủ điều kiện cập nhật địa chỉ (null = không chặn). */
        @AuraEnabled public String addressUpdateNotEligibleTitle;
        /** Các dòng lí do; mỗi phần tử đã gồm tiền tố "Lí do: …". */
        @AuraEnabled public List<String> addressUpdateNotEligibleReasons;
        /** JSON payload địa chỉ thường trú đang chờ (FEC_Address_Info__c pending theo Case). */
        @AuraEnabled public String pendingPermanentAddressJson;
        /** JSON payload địa chỉ công ty đang chờ (FEC_Address_Info__c pending theo Case). */
        @AuraEnabled public String pendingOfficeAddressJson;
        /** JSON payload địa chỉ hiện tại đang chờ (FEC_Address_Info__c pending theo Case). */
        @AuraEnabled public String pendingCurrentAddressJson;
        /** Id master FEC_Address_Info__c — Case.FEC_Selected_Address_Info__c (loại vừa Save cho Address Update API). */
        @AuraEnabled public String selectedAddressInfoId;
        /** Id master FEC_Address_Info__c — Case.FEC_Selected_Address__c (Mailing Address user chọn). */
        @AuraEnabled public String selectedMailingAddressId;
        /** Chuỗi hiển thị cột Updated Information (Case.FEC_Updated_Info_* — sau Save/Submit). */
        @AuraEnabled public String updatedInfoPermanentAddress;
        @AuraEnabled public String updatedInfoOfficeAddress;
        @AuraEnabled public String updatedInfoCurrentAddress;
    }

    public class AddressDTO {
        @AuraEnabled public String addressType;
        @AuraEnabled public String address;
        @AuraEnabled public String mailingAddress;
        /** Id bản ghi FEC_Address_Info__c (đồng bộ CIF, FEC_Case__c = null) — dùng làm FEC_Parent_Address__c khi lưu pending. */
        @AuraEnabled public String addressInfoId;
        /** Tên quận/huyện từ FEC_District__r — hiển thị với nhãn "Ward" trên UI. */
        @AuraEnabled public String ward;
    }

    public class PicklistOptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    /** Context để gọi FEC_UpdateCustomerAddress cho địa chỉ giao phát (cùng bản ghi PERMNENT/OFFICE). */
    public class MailingAddressContextDTO {
        @AuraEnabled public String cifNumber;
        @AuraEnabled public String addressId;
        @AuraEnabled public String addressType;
        @AuraEnabled public String building;
        @AuraEnabled public String number_x;
        @AuraEnabled public String street;
        @AuraEnabled public String district;
        /** Tên quận/huyện (Ward trên UI) — resolve từ master / CIF Ward / SF record. */
        @AuraEnabled public String districtLabel;
        @AuraEnabled public String city;
        @AuraEnabled public Boolean found;
        @AuraEnabled public String message;
    }

    private class AddressUpdateResult {
        List<AddressDTO> dtoList = new List<AddressDTO>();
        FEC_CaseBusinessService.Error addressEligibilityError;
    }

    /** CIF AddressId/AddressType theo loại SF — pending JSON, không callout sau DML trong loadMainInfo. */
    private class PendingAddressApiMeta {
        String cifNumber;
        String addressId;
        String addressType;
    }

    /* =====================================================
     * MAIN METHOD
     * ===================================================== */
    @AuraEnabled(cacheable=false)
    public static MainInfoDTO loadMainInfo(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        /* ===== LOAD CASE ===== */
        Case c = [
            SELECT Id, FEC_Account_or_Contract__c, FEC_Product_Type__r.Name,
                   FEC_Selected_Address_Info__c,
                   FEC_Selected_Address__c,
                   FEC_Updated_Info_Permanent_Address__c,
                   FEC_Updated_Info_Office_Address__c,
                   FEC_Updated_Info_Current_Address__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Not_Found,
                    new List<String>{ 'Customer History' }
                )
            );
        }

        /* ===== LOAD CUSTOMER HISTORY ===== */
        FEC_Customer_History__c hist = [
            SELECT Id,
                FEC_Account_Number__c,
                FEC_Contract_Number__c,
                FEC_First_Name__c,
                FEC_Middle_Name__c,
                FEC_Last_Name__c,
                FEC_Customer_Name__c,
                FEC_Date_of_Birth__c,
                FEC_Gender__c,
                FEC_Marital_Status__c,
                FEC_CIF_Number__c,
                FEC_National_ID_Passport_ID__c,
                FEC_Date_of_Issue__c,
                FEC_Place_of_Issue__c,
                FEC_Primary_Phone__c,
                FEC_API_Cache__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            c.FEC_Product_Type__r.Name,
            hist.FEC_Account_Number__c,
            hist.FEC_Contract_Number__c
        );
        String productTypeName = c.FEC_Product_Type__r.Name;
        String cifNumber = hist.FEC_CIF_Number__c;
        String contractNumber = hist.FEC_Contract_Number__c;
        /* ===== CACHE HIT ===== */
        if (String.isNotBlank(hist.FEC_API_Cache__c)) {
            MainInfoDTO cached = (MainInfoDTO) JSON.deserialize(
                hist.FEC_API_Cache__c,
                MainInfoDTO.class
            );
            /* Luôn lấy địa chỉ từ FEC_Address_Info__c — không tin mảng addresses trong JSON cache (dễ lệch sau khi đồng bộ API / map PERMNENT). */
            cached.addresses = buildAddressDTOListForCase(hist.Id);

            if (cached.addresses != null && !cached.addresses.isEmpty()) {
                String effectiveCifForPending = String.isNotBlank(cifNumber)
                    ? cifNumber
                    : cached.cifNumber;
                String newPhone = null;
                String cardMailingInd = null;
                Map<String, PendingAddressApiMeta> pendingApiMeta =
                    new Map<String, PendingAddressApiMeta>();
                FEC_CommonUltils.beginDeferredApiLogging();
                try {
                    newPhone = resolvePrimaryPhoneForCacheHitCalloutOnly(
                        cached, hist, productTypeName, accountNumber, contractNumber
                    );
                    cardMailingInd = resolveCardMailingIndCalloutOnly(
                        productTypeName,
                        accountNumber,
                        c.FEC_Selected_Address_Info__c == null
                    );
                    pendingApiMeta = prefetchPendingAddressApiMeta(
                        c.Id,
                        effectiveCifForPending,
                        null
                    );
                } finally {
                    FEC_CommonUltils.flushDeferredApiLogs();
                }
                Boolean histNeedsUpdate = false;
                if (String.isNotBlank(newPhone)) {
                    hist.FEC_Primary_Phone__c = newPhone;
                    histNeedsUpdate = true;
                }
                Boolean mailingFlagsUpdated = false;
                if (String.isNotBlank(cardMailingInd)) {
                    try {
                        syncMailingAddressFlagsFromCardMailingInd(hist.Id, cardMailingInd);
                        mailingFlagsUpdated = true;
                        cached.addresses = buildAddressDTOListForCase(hist.Id);
                    } catch (Exception e) {
                        System.debug('### MailingInd sync FAILED: ' + e.getMessage());
                    }
                }
                if (histNeedsUpdate || mailingFlagsUpdated) {
                    if (histNeedsUpdate) {
                        hist.FEC_API_Cache__c = JSON.serialize(cached);
                    }
                    update hist;
                }
                applyCaseMailingContextToDto(cached, c);
                applyAddressEligibilityToDto(cached, hist.Id, null);
                applyPendingAddressFields(
                    cached,
                    c.Id,
                    effectiveCifForPending,
                    pendingApiMeta
                );
                applyCaseUpdatedInfoAddressFields(cached, c);
                return cached;
            }

            // Cache có KH nhưng chưa có địa chỉ: mọi callout trước, DML sau.
            String effectiveCif = String.isNotBlank(cifNumber)
                ? cifNumber
                : cached.cifNumber;
            AddressUpdateResult addrResult = new AddressUpdateResult();
            FEC_GetAddressesList.ResponseWrapper addrListRes = null;
            String newPhoneAfterAddrSync = null;
            String cardMailingIndAfterAddrSync = null;
            Map<String, PendingAddressApiMeta> pendingApiMetaAfterSync =
                new Map<String, PendingAddressApiMeta>();
            if (String.isNotBlank(effectiveCif)) {
                FEC_CommonUltils.beginDeferredApiLogging();
                try {
                    addrListRes = fetchAddressesListByCif(effectiveCif);
                    cardMailingIndAfterAddrSync = resolveCardMailingIndCalloutOnly(
                        productTypeName,
                        accountNumber,
                        c.FEC_Selected_Address_Info__c == null
                    );
                    newPhoneAfterAddrSync = resolvePrimaryPhoneForCacheHitCalloutOnly(
                        cached, hist, productTypeName, accountNumber, contractNumber
                    );
                    pendingApiMetaAfterSync = prefetchPendingAddressApiMeta(
                        c.Id,
                        effectiveCif,
                        addrListRes
                    );
                } finally {
                    FEC_CommonUltils.flushDeferredApiLogs();
                }
                try {
                    addrResult = persistAddressesFromApiResponse(
                        hist,
                        addrListRes,
                        accountNumber,
                        productTypeName,
                        true,
                        c.FEC_Selected_Address_Info__c != null,
                        cardMailingIndAfterAddrSync
                    );
                    cached.addresses = buildAddressDTOListForCase(hist.Id);
                    if (cached.addresses == null || cached.addresses.isEmpty()) {
                        cached.addresses = addrResult.dtoList;
                    }
                    cached.addressUpdateNotEligibleTitle = null;
                    cached.addressUpdateNotEligibleReasons = null;
                    Boolean cacheNeedsSave =
                        cached.addresses != null && !cached.addresses.isEmpty();
                    if (String.isNotBlank(newPhoneAfterAddrSync)) {
                        hist.FEC_Primary_Phone__c = newPhoneAfterAddrSync;
                        cacheNeedsSave = true;
                    }
                    if (cacheNeedsSave) {
                        hist.FEC_API_Cache__c = JSON.serialize(cached);
                        update hist;
                    }
                    applyAddressEligibilityToDto(cached, hist.Id, addrResult);
                } catch (Exception e) {
                    System.debug('### GetAddressesList (cache + empty addresses resync) FAILED: ' + e.getMessage());
                    applyAddressEligibilityToDto(cached, hist.Id, null);
                }
            } else {
                applyAddressEligibilityToDto(cached, hist.Id, null);
            }
            applyCaseMailingContextToDto(cached, c);
            applyPendingAddressFields(
                cached,
                c.Id,
                effectiveCif,
                pendingApiMetaAfterSync
            );
            applyCaseUpdatedInfoAddressFields(cached, c);
            return cached;
        }

        /* =====================================================
         * CALL API — hoãn ghi FEC_API_Log__c; mọi callout xong rồi mới DML (addresses / hist / log).
         * ===================================================== */
        FEC_CommonUltils.beginDeferredApiLogging();
        AddressUpdateResult addrResult = new AddressUpdateResult();
        FEC_GetAddressesList.ResponseWrapper addrListRes = null;
        String cardMailingIndForColdLoad = null;
        String apiPhoneForColdLoad = null;
        Map<String, PendingAddressApiMeta> pendingApiMetaForColdLoad =
            new Map<String, PendingAddressApiMeta>();
        try {
            /* ===== 1. GetCustomerInfoBasic ===== */
            try {
                FEC_GetCustomerInfoBasic.ResponseWrapper basicRes =
                    FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z),
                        cifNumber
                    );

                if (basicRes != null && basicRes.CustomerBasicInfo != null) {
                    hist.FEC_First_Name__c     = basicRes.CustomerBasicInfo.FirstName;
                    hist.FEC_Middle_Name__c    = basicRes.CustomerBasicInfo.MiddleName;
                    hist.FEC_Last_Name__c      = basicRes.CustomerBasicInfo.LastName;
                    hist.FEC_Customer_Name__c  = basicRes.CustomerBasicInfo.FullName;
                    hist.FEC_Date_of_Birth__c  = basicRes.CustomerBasicInfo.Birthday;
                    hist.FEC_Gender__c         = basicRes.CustomerBasicInfo.Gender;
                    hist.FEC_Marital_Status__c = basicRes.CustomerBasicInfo.MaritalStatus;
                    hist.FEC_CIF_Number__c     = basicRes.CustomerBasicInfo.CIFNumber;
                }
            } catch (Exception e) {
                System.debug('### GetCustomerInfoBasic FAILED: ' + e.getMessage());
            }

            try {
                FEC_GetDocumentsList.ResponseWrapper docRes =
                    FEC_GetDocumentsList.callGetDocumentsList(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                        cifNumber
                    );

                if (docRes != null && docRes.Documents != null && !docRes.Documents.isEmpty()) {
                    hist.FEC_National_ID_Passport_ID__c = docRes.Documents[0].IDDocumentNumber;
                    hist.FEC_Date_of_Issue__c           = docRes.Documents[0].IssueDate;
                    hist.FEC_Place_of_Issue__c          = docRes.Documents[0].IssuePlace;
                }
            } catch (Exception e) {
                System.debug('### GetDocumentsList FAILED: ' + e.getMessage());
            }

            /* ===== 2. GetAddressesList (trước GetCustomerList và trước DML đồng bộ địa chỉ) ===== */
            try {
                addrListRes = fetchAddressesListByCif(cifNumber);
                cardMailingIndForColdLoad = resolveCardMailingIndCalloutOnly(
                    productTypeName,
                    accountNumber,
                    c.FEC_Selected_Address_Info__c == null
                );
            } catch (Exception e) {
                System.debug('### GetAddressesList FAILED: ' + e.getMessage());
            }

            /* ===== 3. GetCustomerList ===== */
            try {
                apiPhoneForColdLoad = getPrimaryPhoneOnly(
                    productTypeName,
                    accountNumber,
                    contractNumber
                );
            } catch (Exception e) {
                System.debug('### GetCustomerList FAILED: ' + e.getMessage());
            }

            pendingApiMetaForColdLoad = prefetchPendingAddressApiMeta(
                c.Id,
                cifNumber,
                addrListRes
            );
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        /* =====================================================
         * DML
         * ===================================================== */
        try {
            addrResult = persistAddressesFromApiResponse(
                hist,
                addrListRes,
                accountNumber,
                productTypeName,
                true,
                c.FEC_Selected_Address_Info__c != null,
                cardMailingIndForColdLoad
            );
        } catch (Exception e) {
            System.debug('### persistAddressesFromApiResponse FAILED: ' + e.getMessage());
        }
        if (String.isNotBlank(apiPhoneForColdLoad)) {
            hist.FEC_Primary_Phone__c = apiPhoneForColdLoad;
        }
        update hist;

        MainInfoDTO dto = mapToDTO(hist);
        dto.addresses = buildAddressDTOListForCase(hist.Id);
        if (dto.addresses == null || dto.addresses.isEmpty()) {
            dto.addresses = addrResult.dtoList;
        }
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);

        /* ===== SAVE CACHE (chỉ khi đã có địa chỉ) ===== */
        dto.addressUpdateNotEligibleTitle = null;
        dto.addressUpdateNotEligibleReasons = null;
        if (dto.addresses != null && !dto.addresses.isEmpty()) {
            hist.FEC_API_Cache__c = JSON.serialize(dto);
            update hist;
        }

        applyCaseMailingContextToDto(dto, c);
        applyAddressEligibilityToDto(dto, hist.Id, addrResult);
        applyPendingAddressFields(dto, c.Id, cifNumber, pendingApiMetaForColdLoad);
        applyCaseUpdatedInfoAddressFields(dto, c);
        return dto;
    }

    /* =====================================================
     * LOG SENSITIVE
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceOptionsForAddress() {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        // Bộ tỉnh country FEC_Code__c = 2 (API CIF).
        for (FEC_Province__c p : [
            SELECT Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = '2'
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            if (String.isBlank(p.FEC_Code__c)) {
                continue;
            }
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = p.FEC_Code__c;
            o.label = FEC_CommonUltils.picklistLabelFromFecNameVn(p.FEC_Name_VN__c);
            if (String.isBlank(o.label)) {
                continue;
            }
            opts.add(o);
        }
        return opts;
    }

    /** Lookup tỉnh/TP (value = FEC_Province__c Id, country 2) cho searchable combobox. */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceCityLookupOptions() {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        for (FEC_Province__c p : [
            SELECT Id, FEC_Name_VN__c
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = '2'
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(p.FEC_Name_VN__c);
            if (String.isBlank(lbl)) continue;
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.label = lbl;
            o.value = String.valueOf(p.Id);
            opts.add(o);
        }
        return opts;
    }

    /** Tỉnh/thành theo FEC_Country__c.FEC_Code__c. */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceOptionsForCountryFecCode(String fecCountryCode) {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        if (String.isBlank(fecCountryCode)) {
            return opts;
        }
        String countryCode = fecCountryCode.trim();
        for (FEC_Province__c p : [
            SELECT Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = :countryCode
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            if (String.isBlank(p.FEC_Code__c)) {
                continue;
            }
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = p.FEC_Code__c;
            o.label = FEC_CommonUltils.picklistLabelFromFecNameVn(p.FEC_Name_VN__c);
            if (String.isBlank(o.label)) {
                continue;
            }
            opts.add(o);
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getDistrictOptionsForProvinceCode(
        String provinceCode,
        String selectedDistrictCode
    ) {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        if (String.isBlank(provinceCode)) {
            appendSelectedDistrictOptionIfMissing(opts, selectedDistrictCode);
            return opts;
        }
        String code = provinceCode.trim();
        List<FEC_Province__c> provs = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Code__c = :code
              AND FEC_Country__r.FEC_Code__c = :FEC_COUNTRY_MASTER_API
            LIMIT 1
        ];
        if (!provs.isEmpty()) {
            Id provinceId = provs[0].Id;

            for (FEC_District__c d : [
                SELECT Name, FEC_Code__c, FEC_Name_VN__c
                FROM FEC_District__c
                WHERE FEC_Province__c = :provinceId
                ORDER BY FEC_Name_VN__c NULLS LAST, Name
            ]) {
                if (String.isBlank(d.FEC_Code__c)) {
                    continue;
                }
                PicklistOptionDTO o = new PicklistOptionDTO();
                o.value = d.FEC_Code__c;
                String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(d.FEC_Name_VN__c);
                if (String.isBlank(lbl)) {
                    lbl = String.isNotBlank(d.Name) ? d.Name : d.FEC_Code__c;
                }
                o.label = lbl;
                opts.add(o);
            }
        }
        appendSelectedDistrictOptionIfMissing(opts, selectedDistrictCode);
        return opts;
    }

    /**
     * Bổ sung option Ward đang chọn (mã CIF) khi không nằm trong bộ country 2 của tỉnh —
     * ví dụ FEC_Code__c = 780 thuộc country 1 nhưng vẫn cần label FEC_Name_VN__c trên UI.
     */
    @TestVisible
    private static void appendSelectedDistrictOptionIfMissing(
        List<PicklistOptionDTO> opts,
        String selectedDistrictCode
    ) {
        if (opts == null || String.isBlank(selectedDistrictCode)) {
            return;
        }
        String dc = selectedDistrictCode.trim();
        for (PicklistOptionDTO existing : opts) {
            if (existing != null && dc.equals(existing.value)) {
                return;
            }
        }
        List<FEC_District__c> rows = [
            SELECT FEC_Code__c, FEC_Name_VN__c, Name
            FROM FEC_District__c
            WHERE FEC_Code__c = :dc
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return;
        }
        String lbl = districtLabelFromFecDistrictRecord(rows[0]);
        if (String.isBlank(lbl) || lbl.trim().equalsIgnoreCase(dc)) {
            return;
        }
        PicklistOptionDTO extra = new PicklistOptionDTO();
        extra.value = rows[0].FEC_Code__c;
        extra.label = lbl;
        // Apex: add(0, x) on empty list throws List index out of bounds: 0 — use add(x) when empty.
        if (opts.isEmpty()) {
            opts.add(extra);
        } else {
            opts.add(0, extra);
        }
    }

    @AuraEnabled
    public static MailingAddressContextDTO getMailingAddressUpdateContext(
        Id caseId,
        String sfAddressType
    ) {
        MailingAddressContextDTO dto = new MailingAddressContextDTO();
        dto.found = false;

        if (caseId == null) {
            dto.message = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'Case Id'}
            );
            return dto;
        }
        if (String.isBlank(sfAddressType)) {
            dto.message = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'Address Type'}
            );
            return dto;
        }

        String apiType = mapSfAddressTypeToApiCode(sfAddressType);
        if (String.isBlank(apiType)) {
            dto.message = String.format(
                System.Label.FEC_MSG_Invalid,
                new List<String>{ 'Address Type' }
            );
            return dto;
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            dto.message = String.format(
                System.Label.FEC_MSG_Not_Found,
                new List<String>{ 'Customer History' }
            );
            return dto;
        }

        FEC_Customer_History__c hist = [
            SELECT FEC_CIF_Number__c, FEC_API_Cache__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        String cifNumber = hist.FEC_CIF_Number__c;
        if (String.isBlank(cifNumber) && String.isNotBlank(hist.FEC_API_Cache__c)) {
            try {
                Map<String, Object> cacheRoot = (Map<String, Object>) JSON.deserializeUntyped(
                    hist.FEC_API_Cache__c
                );
                if (cacheRoot != null && cacheRoot.containsKey('cifNumber')) {
                    Object v = cacheRoot.get('cifNumber');
                    if (v != null) {
                        String fromCache = String.valueOf(v).trim();
                        if (String.isNotBlank(fromCache)) {
                            cifNumber = fromCache;
                        }
                    }
                }
            } catch (Exception ignore) {
                // giữ cifNumber null, báo lỗi thiếu CIF bên dưới
            }
        }
        if (String.isBlank(cifNumber)) {
            dto.message = String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'CIFNumber'}
            );
            return dto;
        }

        FEC_GetAddressesList.ResponseWrapper res =
            FEC_GetAddressesList.callGetAddressesList(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                cifNumber
            );

        if (res == null || res.Addresses == null) {
            dto.message = String.format(
                System.Label.FEC_MSG_Not_Found,
                new List<String>{ 'Addresses' }
            );
            return dto;
        }

        FEC_GetAddressesList.AddressInfo found;
        for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
            if (ai != null && ai.AddressType == apiType) {
                found = ai;
                break;
            }
        }

        if (found == null || String.isBlank(found.AddressId)) {
            dto.message = String.format(
                System.Label.FEC_MSG_Not_Found,
                new List<String>{ 'Address' }
            );
            return dto;
        }

        dto.found = true;
        dto.cifNumber = cifNumber;
        dto.addressId = found.AddressId;
        dto.addressType = found.AddressType;
        dto.building = found.Building;
        dto.number_x = found.NumberStr;
        dto.street = found.Street;
        dto.district = found.District;
        /* CIF có thể trả mã tỉnh thuộc bộ master legacy (1); combobox chỉ load bộ 2 — chuẩn hóa mã cho UI. */
        dto.city = FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo(found.City);
        dto.districtLabel = resolveDistrictLabelForMailingContext(
            found.District,
            dto.city,
            found,
            c.FEC_Account_or_Contract__c,
            sfAddressType
        );
        return dto;
    }

    /** Chuẩn hóa mã tỉnh về bộ country 2 (combobox UI). */
    @AuraEnabled(cacheable=true)
    public static String normalizeProvinceCodeForAddressUi(String cityCode) {
        if (String.isBlank(cityCode)) {
            return cityCode;
        }
        return FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo(cityCode.trim());
    }

    private static String mapSfAddressTypeToApiCode(String sfType) {
        if (sfType == FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT) {
            return FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT;
        }
        if (sfType == FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE) {
            return FEC_ConstantCommon.ADDRESS_TYPE_OFFICE;
        }
        if (sfType == FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT) {
            return FEC_ConstantCommon.ADDRESS_TYPE_CURRES;
        }
        return null;
    }

    /** MailingInd + AddressType → FEC_Mailing_Address__c (E/OFFICE, C/CURRES, R/PERMNENT). */
    @TestVisible
    private static Boolean isMailingAddressFromCardMailingInd(
        String mailingInd,
        String apiAddressType
    ) {
        if (String.isBlank(mailingInd) || String.isBlank(apiAddressType)) {
            return false;
        }
        String ind = mailingInd.trim().toUpperCase();
        String type = apiAddressType.trim().toUpperCase();
        if (ind == 'E' && type == FEC_ConstantCommon.ADDRESS_TYPE_OFFICE) {
            return true;
        }
        if (ind == 'C' && type == FEC_ConstantCommon.ADDRESS_TYPE_CURRES) {
            return true;
        }
        if (ind == 'R' && type == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT) {
            return true;
        }
        return false;
    }

    private static String fetchCardMailingInd(String accountNumber) {
        if (String.isBlank(accountNumber)) {
            return null;
        }
        FEC_GetCardBasicInfo.ResponseWrapper res =
            FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accountNumber
            );
        if (res?.CardBasicInfo?.MainCard != null) {
            return res.CardBasicInfo.MainCard.MailingInd;
        }
        return null;
    }

    /** Gọi GetCardBasicInfo rồi cập nhật FEC_Mailing_Address__c trên master address list. */
    public static Boolean syncMailingAddressFlagsFromCardMailingInd(
        Id customerHistoryId,
        String mailingInd
    ) {
        if (customerHistoryId == null) {
            return false;
        }
        List<FEC_Address_Info__c> rows = [
            SELECT Id, FEC_Address_Type__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Case__c = null
        ];
        if (rows.isEmpty()) {
            return false;
        }
        List<FEC_Address_Info__c> toUpdate = new List<FEC_Address_Info__c>();
        for (FEC_Address_Info__c addr : rows) {
            String apiType = mapSfAddressTypeToApiCode(addr.FEC_Address_Type__c);
            Boolean isMailing = isMailingAddressFromCardMailingInd(mailingInd, apiType);
            if (addr.FEC_Mailing_Address__c != isMailing) {
                addr.FEC_Mailing_Address__c = isMailing;
                toUpdate.add(addr);
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        return true;
    }

    /**
     * Lưu loại địa chỉ vừa Save trên Case (FEC_Selected_Address_Info__c).
     * Master (FEC_Case__c = null) khi sửa loại đã có trên CIF; pending (FEC_Case__c = Case) khi Add New.
     * masterAddressInfoId = null → bỏ chọn trên Case.
     */
    @AuraEnabled
    public static void saveCaseSelectedAddressInfo(
        Id caseId,
        Id masterAddressInfoId
    ) {
        saveCaseSelectedAddressInfoInternal(caseId, masterAddressInfoId, true);
    }

    private static void saveCaseSelectedAddressInfoInternal(
        Id caseId,
        Id masterAddressInfoId,
        Boolean validateMaster
    ) {
        if (caseId == null) {
            throw new AuraHandledException('caseId is required');
        }
        if (masterAddressInfoId != null && validateMaster == true) {
            Case c = [
                SELECT FEC_Account_or_Contract__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            List<FEC_Address_Info__c> targetRows = [
                SELECT Id, FEC_Customer_History__c, FEC_Case__c
                FROM FEC_Address_Info__c
                WHERE Id = :masterAddressInfoId
                LIMIT 1
            ];
            if (
                targetRows.isEmpty() ||
                targetRows[0].FEC_Customer_History__c != c.FEC_Account_or_Contract__c
            ) {
                throw new AuraHandledException(
                    'Invalid FEC_Selected_Address_Info__c for this Case / Customer History'
                );
            }
            Id rowCaseId = targetRows[0].FEC_Case__c;
            if (rowCaseId != null && rowCaseId != caseId) {
                throw new AuraHandledException(
                    'Invalid FEC_Selected_Address_Info__c for this Case / Customer History'
                );
            }
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        update new Case(
            Id = caseId,
            FEC_Selected_Address_Info__c = masterAddressInfoId
        );
        // Mailing lưu trên Case.FEC_Selected_Address__c; FEC_Selected_Address_Info__c = loại gọi Address Update API.
    }

    private static Id resolveCaseSelectedAddressInfoId(Id caseId) {
        if (caseId == null) {
            return null;
        }
        List<Case> rows = [
            SELECT FEC_Selected_Address_Info__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].FEC_Selected_Address_Info__c;
    }

    private static void applyCaseMailingContextToDto(MainInfoDTO dto, Case c) {
        if (dto == null || c == null) {
            return;
        }
        dto.selectedAddressInfoId = c.FEC_Selected_Address_Info__c != null
            ? String.valueOf(c.FEC_Selected_Address_Info__c)
            : null;
        dto.selectedMailingAddressId = c.FEC_Selected_Address__c != null
            ? String.valueOf(c.FEC_Selected_Address__c)
            : null;
    }

    private static List<AddressDTO> buildAddressDTOListForCase(Id customerHistoryId) {
        /* Mailing hiển thị từ FEC_Mailing_Address__c master (+ pending JSON trên LWC). */
        return buildAddressDTOListFromHistory(customerHistoryId);
    }

    private static Boolean refreshMailingAddressFlagsForCardProduct(
        Id customerHistoryId,
        String productTypeName,
        String accountNumber
    ) {
        if (customerHistoryId == null
            || !FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE.equalsIgnoreCase(productTypeName)
            || String.isBlank(accountNumber)) {
            return false;
        }
        try {
            syncMailingAddressFlagsFromCardMailingInd(
                customerHistoryId,
                fetchCardMailingInd(accountNumber)
            );
            return true;
        } catch (Exception e) {
            System.debug('### MailingInd sync FAILED: ' + e.getMessage());
            return false;
        }
    }

    /** Xóa cache Main Info để loadMainInfo gọi lại API (sau cập nhật địa chỉ). */
    @AuraEnabled
    public static void clearMainInfoCache(Id caseId) {
        if (caseId == null) {
            return;
        }
        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) {
            return;
        }
        update new FEC_Customer_History__c(
            Id = c.FEC_Account_or_Contract__c,
            FEC_API_Cache__c = null
        );
    }

    /** Master FEC_Address_Info__c (Original, FEC_Case__c = null) theo loại địa chỉ. */
    private static Id resolveOriginalAddressIdForType(
        Id customerHistoryId,
        String sfAddressType
    ) {
        if (customerHistoryId == null || String.isBlank(sfAddressType)) {
            return null;
        }
        List<FEC_Address_Info__c> masters = [
            SELECT Id
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Case__c = null
              AND FEC_Address_Type__c = :sfAddressType
            LIMIT 1
        ];
        return masters.isEmpty() ? null : masters[0].Id;
    }

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

    private static FEC_CaseBusinessService.Error getAddressUpdateEligibilityForUi(
        Id cHistoryId
    ) {
        FEC_CaseBusinessService.Error raw = FEC_CaseBusinessService.phoneUpdateValidate(
            cHistoryId
        );
        if (raw == null || raw.errorlst == null || raw.errorlst.isEmpty()) {
            return null;
        }
        return new FEC_CaseBusinessService.Error(
            System.Label.FEC_MSG_Address_Update_Not_Eligible,
            formatContactValidationErrorsForAddressUi(raw.errorlst)
        );
    }

    private static List<String> formatContactValidationErrorsForAddressUi(
        List<String> rawlst
    ) {
        List<String> out = new List<String>();
        if (rawlst == null) {
            return out;
        }
        for (String s : rawlst) {
            if (String.isBlank(s)) {
                continue;
            }
            String t = s.trim();
            if (t.startsWith('Block Code 1 = ')) {
                String v = t.substring('Block Code 1 = '.length()).trim();
                out.add(
                    String.format(
                        System.Label.FEC_MSG_Address_Update_Reason_Block_Code_1,
                        new List<String>{ v }
                    )
                );
            } else if (t.startsWith('Block Code 2 = ')) {
                String v = t.substring('Block Code 2 = '.length()).trim();
                out.add(
                    String.format(
                        System.Label.FEC_MSG_Address_Update_Reason_Block_Code_2,
                        new List<String>{ v }
                    )
                );
            } else if (t.startsWith('Block Code = ')) {
                String v = t.substring('Block Code = '.length()).trim();
                out.add(
                    String.format(
                        System.Label.FEC_MSG_Address_Update_Reason_Block_Code,
                        new List<String>{ v }
                    )
                );
            } else if (t.startsWith('Account Status = ')) {
                String v = t.substring('Account Status = '.length()).trim();
                out.add(
                    String.format(
                        System.Label.FEC_MSG_Address_Update_Reason_Account_Status,
                        new List<String>{ v }
                    )
                );
            } else {
                out.add(
                    String.format(
                        System.Label.FEC_MSG_Address_Update_Reason_Generic,
                        new List<String>{ t }
                    )
                );
            }
        }
        return out;
    }

    /** Gắn thông báo chặn cập nhật địa chỉ lên DTO (không lưu cache). */
    private static void applyAddressEligibilityToDto(
        MainInfoDTO dto,
        Id customerHistoryId,
        AddressUpdateResult addrResult
    ) {
        if (dto == null || customerHistoryId == null) {
            return;
        }
        if (addrResult != null && addrResult.addressEligibilityError != null) {
            dto.addressUpdateNotEligibleTitle = addrResult.addressEligibilityError.label;
            dto.addressUpdateNotEligibleReasons = addrResult.addressEligibilityError.errorlst;
            return;
        }
        if (addrResult != null) {
            dto.addressUpdateNotEligibleTitle = null;
            dto.addressUpdateNotEligibleReasons = null;
            return;
        }
        FEC_CaseBusinessService.Error e = getAddressUpdateEligibilityForUi(
            customerHistoryId
        );
        if (e != null) {
            dto.addressUpdateNotEligibleTitle = e.label;
            dto.addressUpdateNotEligibleReasons = e.errorlst;
        } else {
            dto.addressUpdateNotEligibleTitle = null;
            dto.addressUpdateNotEligibleReasons = null;
        }
    }

    private static String getPrimaryPhoneOnly(
        String productTypeName,
        String accountNumber,
        String contractNumber
    ) {
        FEC_GetCustomerList.ResponseWrapper res = callGetCustomerListForPhone(
            productTypeName,
            accountNumber,
            contractNumber
        );
        if (res == null || res.Customers == null) {
            return null;
        }

        for (FEC_GetCustomerList.Customer c : res.Customers) {
            String phone = extractPhoneFromCustomerList(c);
            if (String.isNotBlank(phone)) {
                return phone;
            }
        }

        return null;
    }

    private static FEC_GetCustomerList.ResponseWrapper callGetCustomerListForPhone(
        String productTypeName,
        String accountNumber,
        String contractNumber
    ) {
        Boolean preferContract =
            (productTypeName == FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE
                || productTypeName == FEC_ConstantCommon.PRODUCT_TYPE_INSURANCE_CASE)
            && String.isNotBlank(contractNumber);

        if (preferContract) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null,
                false,
                null, null, null, null,
                null,
                contractNumber,
                null, null
            );
        }
        if (String.isNotBlank(accountNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null,
                false,
                null, null, null, null,
                accountNumber,
                null,
                null, null
            );
        }
        if (String.isNotBlank(contractNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null,
                false,
                null, null, null, null,
                null,
                contractNumber,
                null, null
            );
        }
        return null;
    }

    private static String extractPhoneFromCustomerList(FEC_GetCustomerList.Customer customer) {
        if (customer == null || customer.Phones == null) {
            return null;
        }
        String fallbackPhone = null;
        for (FEC_GetCustomerList.Phone p : customer.Phones) {
            if (p == null || String.isBlank(p.Phone)) {
                continue;
            }
            String type = (p.Type != null) ? p.Type.trim() : '';
            if ('Mobile'.equalsIgnoreCase(type)) {
                return p.Phone.trim();
            }
            if (fallbackPhone == null && 'Phone'.equalsIgnoreCase(type)) {
                fallbackPhone = p.Phone.trim();
            }
        }
        return fallbackPhone;
    }

    private static Boolean syncPrimaryPhoneForCacheHit(
        MainInfoDTO cached,
        FEC_Customer_History__c hist,
        String productTypeName,
        String accountNumber,
        String contractNumber
    ) {
        String newPhone = resolvePrimaryPhoneForCacheHitCalloutOnly(
            cached,
            hist,
            productTypeName,
            accountNumber,
            contractNumber
        );
        if (String.isNotBlank(newPhone)) {
            hist.FEC_Primary_Phone__c = newPhone;
            return true;
        }
        return false;
    }

    /**
     * Chỉ callout / đọc DB — không DML. Trả phone cần ghi lên hist (null = không đổi).
     */
    private static String resolvePrimaryPhoneForCacheHitCalloutOnly(
        MainInfoDTO cached,
        FEC_Customer_History__c hist,
        String productTypeName,
        String accountNumber,
        String contractNumber
    ) {
        if (cached == null || hist == null) {
            return null;
        }
        if (String.isNotBlank(hist.FEC_Primary_Phone__c)) {
            cached.primaryPhone = hist.FEC_Primary_Phone__c;
            return null;
        }
        try {
            String apiPhone = getPrimaryPhoneOnly(
                productTypeName,
                accountNumber,
                contractNumber
            );
            if (String.isNotBlank(apiPhone)) {
                cached.primaryPhone = apiPhone;
                return apiPhone;
            }
        } catch (Exception e) {
            System.debug('### GetCustomerList (cache resync phone) FAILED: ' + e.getMessage());
        }
        cached.primaryPhone = null;
        return null;
    }

    /** GetCardBasicInfo callout only — null khi không phải Card hoặc không cần sync mailing. */
    private static String resolveCardMailingIndCalloutOnly(
        String productTypeName,
        String accountNumber,
        Boolean syncMailingWhenSelectedAddressEmpty
    ) {
        if (syncMailingWhenSelectedAddressEmpty != true
            || !FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE.equalsIgnoreCase(productTypeName)
            || String.isBlank(accountNumber)) {
            return null;
        }
        try {
            return fetchCardMailingInd(accountNumber);
        } catch (Exception e) {
            System.debug('### GetCardBasicInfo (MailingInd) FAILED: ' + e.getMessage());
            return null;
        }
    }

    private static FEC_GetAddressesList.ResponseWrapper fetchAddressesListByCif(
        String cifNumber
    ) {
        if (String.isBlank(cifNumber)) {
            return null;
        }
        return FEC_GetAddressesList.callGetAddressesList(
            FEC_CommonUltils.generateTransactionId(),
            FEC_ConstantCommon.REQUESTOR_CRM,
            Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
            cifNumber
        );
    }

    private static Boolean pendingRowNeedsApiMeta(FEC_Address_Info__c row) {
        if (row == null || String.isBlank(row.FEC_Address_Type__c)) {
            return false;
        }
        String raw = row.FEC_Address__c;
        if (String.isNotBlank(raw) && raw.trim().startsWith('{')) {
            return false;
        }
        List<String> meta = unpackPendingAddressApiMeta(raw);
        return String.isBlank(meta[0])
            || String.isBlank(meta[1])
            || String.isBlank(meta[2]);
    }

    private static Set<String> collectSfTypesNeedingPendingApiMeta(Id caseId) {
        Set<String> needed = new Set<String>();
        if (caseId == null) {
            return needed;
        }
        for (FEC_Address_Info__c row : [
            SELECT FEC_Address_Type__c, FEC_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :caseId
        ]) {
            if (pendingRowNeedsApiMeta(row)) {
                needed.add(row.FEC_Address_Type__c);
            }
        }
        return needed;
    }

    private static Map<String, PendingAddressApiMeta> buildPendingApiMetaMapFromAddressesResponse(
        String cifNumber,
        FEC_GetAddressesList.ResponseWrapper res,
        Set<String> sfTypesNeeded
    ) {
        Map<String, PendingAddressApiMeta> outMap =
            new Map<String, PendingAddressApiMeta>();
        if (String.isBlank(cifNumber)
            || res == null
            || res.Addresses == null
            || sfTypesNeeded == null
            || sfTypesNeeded.isEmpty()) {
            return outMap;
        }
        for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
            if (ai == null) {
                continue;
            }
            String sfType = mapApiAddressTypeToSF(ai.AddressType);
            if (String.isBlank(sfType) || !sfTypesNeeded.contains(sfType)) {
                continue;
            }
            PendingAddressApiMeta meta = new PendingAddressApiMeta();
            meta.cifNumber = cifNumber;
            meta.addressId = ai.AddressId;
            meta.addressType = ai.AddressType;
            outMap.put(sfType, meta);
        }
        return outMap;
    }

    private static Map<String, PendingAddressApiMeta> prefetchPendingAddressApiMeta(
        Id caseId,
        String cifNumber,
        FEC_GetAddressesList.ResponseWrapper existingListRes
    ) {
        Set<String> needed = collectSfTypesNeedingPendingApiMeta(caseId);
        if (needed.isEmpty() || String.isBlank(cifNumber)) {
            return new Map<String, PendingAddressApiMeta>();
        }
        FEC_GetAddressesList.ResponseWrapper res = existingListRes;
        if (res == null) {
            try {
                res = fetchAddressesListByCif(cifNumber);
            } catch (Exception e) {
                System.debug('### prefetchPendingAddressApiMeta FAILED: ' + e.getMessage());
                return new Map<String, PendingAddressApiMeta>();
            }
        }
        return buildPendingApiMetaMapFromAddressesResponse(cifNumber, res, needed);
    }

    private static final String FEC_COUNTRY_MASTER_LEGACY = '1'; // bộ master cũ
    private static final String FEC_COUNTRY_MASTER_API = '2';

    private static Map<Id, FEC_Country__c> buildCountryByIdMap(List<FEC_Country__c> rows) {
        Map<Id, FEC_Country__c> m = new Map<Id, FEC_Country__c>();
        if (rows == null) {
            return m;
        }
        for (FEC_Country__c r : rows) {
            if (r != null) {
                m.put(r.Id, r);
            }
        }
        return m;
    }

    /** Remap country master 1 → 2 (cùng tên). */
    private static Id remapCountryIdToApiMaster(Id countryId, Map<Id, FEC_Country__c> countryById) {
        if (countryId == null || countryById == null || !countryById.containsKey(countryId)) {
            return null;
        }
        FEC_Country__c src = countryById.get(countryId);
        String code = (src.FEC_Code__c != null) ? src.FEC_Code__c.trim() : '';
        if (FEC_COUNTRY_MASTER_API.equals(code)) {
            return countryId;
        }
        if (!FEC_COUNTRY_MASTER_LEGACY.equals(code)) {
            return countryId;
        }
        String matchVn = String.isNotBlank(src.FEC_Name_VN__c) ? src.FEC_Name_VN__c.trim() : null;
        String matchNm = (src.Name != null) ? src.Name.trim() : null;
        for (FEC_Country__c t : countryById.values()) {
            if (t == null || t.Id == src.Id) {
                continue;
            }
            String tc = (t.FEC_Code__c != null) ? t.FEC_Code__c.trim() : '';
            if (!FEC_COUNTRY_MASTER_API.equals(tc)) {
                continue;
            }
            String tvn = String.isNotBlank(t.FEC_Name_VN__c) ? t.FEC_Name_VN__c.trim() : '';
            String tnm = (t.Name != null) ? t.Name.trim() : '';
            if (String.isNotBlank(matchVn)) {
                if (matchVn.equalsIgnoreCase(tvn) || matchVn.equalsIgnoreCase(tnm)) {
                    return t.Id;
                }
            }
            if (String.isNotBlank(matchNm)) {
                if (matchNm.equalsIgnoreCase(tvn) || matchNm.equalsIgnoreCase(tnm)) {
                    return t.Id;
                }
            }
        }
        return countryId;
    }

    /** Resolve FEC_Country__c từ CountryCode/Name API; ưu tiên FEC_Code__c = 2. */
    private static Id resolveCountryIdFromApiAddressInfo(
        FEC_GetAddressesList.AddressInfo ai,
        List<FEC_Country__c> countries
    ) {
        if (ai == null || countries == null || countries.isEmpty()) {
            return null;
        }
        String codeApi = String.isNotBlank(ai.CountryCode) ? ai.CountryCode.trim() : null;
        if (codeApi != null) {
            for (FEC_Country__c c : countries) {
                if (c.FEC_Code__c != null && c.FEC_Code__c.trim().equalsIgnoreCase(codeApi)) {
                    return c.Id;
                }
            }
        }
        String nameApi = String.isNotBlank(ai.CountryName) ? ai.CountryName.trim() : null;
        if (nameApi == null) {
            return null;
        }
        Id preferApi = null;
        Id anyId = null;
        for (FEC_Country__c c : countries) {
            String vn = String.isNotBlank(c.FEC_Name_VN__c) ? c.FEC_Name_VN__c.trim() : '';
            String nm = (c.Name != null) ? c.Name.trim() : '';
            if (!nameApi.equalsIgnoreCase(vn) && !nameApi.equalsIgnoreCase(nm)) {
                continue;
            }
            String fc = (c.FEC_Code__c != null) ? c.FEC_Code__c.trim() : '';
            if (FEC_COUNTRY_MASTER_API.equals(fc)) {
                preferApi = c.Id;
                break;
            }
            if (anyId == null) {
                anyId = c.Id;
            }
        }
        return preferApi != null ? preferApi : anyId;
    }

    /** Remap mã City API: tỉnh bộ 1 → tỉnh cùng tên bộ 2 (nếu đúng 1 bản ghi). */
    private static Id resolveProvinceForAddressSync(String cityCode) {
        if (String.isBlank(cityCode)) {
            return null;
        }
        String codeTrim = cityCode.trim();
        List<FEC_Province__c> srcRows = [
            SELECT Id, Name, FEC_Name_VN__c, FEC_Country__r.FEC_Code__c
            FROM FEC_Province__c
            WHERE FEC_Code__c = :codeTrim
            LIMIT 1
        ];
        if (srcRows.isEmpty()) {
            return null;
        }
        FEC_Province__c src = srcRows[0];
        String countryCode = (src.FEC_Country__r != null && src.FEC_Country__r.FEC_Code__c != null)
            ? src.FEC_Country__r.FEC_Code__c.trim()
            : '';
        if (!FEC_COUNTRY_MASTER_LEGACY.equals(countryCode)) {
            return src.Id;
        }
        String matchName = String.isNotBlank(src.FEC_Name_VN__c) ? src.FEC_Name_VN__c.trim() : null;
        if (String.isBlank(matchName)) {
            matchName = (src.Name != null) ? src.Name.trim() : null;
        }
        if (String.isBlank(matchName)) {
            return src.Id;
        }
        List<FEC_Province__c> targetRows = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = :FEC_COUNTRY_MASTER_API
              AND (FEC_Name_VN__c = :matchName OR Name = :matchName)
        ];
        if (targetRows.size() == 1) {
            return targetRows[0].Id;
        }
        return src.Id;
    }

    private static AddressUpdateResult updateAddressesFromApi(
        FEC_Customer_History__c hist,
        String cifNumber,
        String accountNumber,
        String productTypeName,
        Boolean syncForDisplayOnly,
        Boolean skipCardMailingIndSync
    ) {
        AddressUpdateResult result = new AddressUpdateResult();

        FEC_CaseBusinessService.Error addrValErr = null;
        if (hist != null && hist.Id != null) {
            addrValErr = getAddressUpdateEligibilityForUi(hist.Id);
            if (addrValErr != null && syncForDisplayOnly != true) {
                result.dtoList = buildAddressDTOListFromHistory(hist.Id);
                result.addressEligibilityError = addrValErr;
                return result;
            }
        }

        FEC_GetAddressesList.ResponseWrapper res = fetchAddressesListByCif(cifNumber);

        String mailingInd = null;
        if (FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE.equalsIgnoreCase(productTypeName)
            && String.isNotBlank(accountNumber)
            && skipCardMailingIndSync != true) {
            mailingInd = resolveCardMailingIndCalloutOnly(
                productTypeName,
                accountNumber,
                true
            );
        }

        return persistAddressesFromApiResponse(
            hist,
            res,
            accountNumber,
            productTypeName,
            syncForDisplayOnly,
            skipCardMailingIndSync,
            mailingInd,
            addrValErr
        );
    }

    /** Chỉ DML — caller phải hoàn tất mọi callout trước khi gọi. */
    private static AddressUpdateResult persistAddressesFromApiResponse(
        FEC_Customer_History__c hist,
        FEC_GetAddressesList.ResponseWrapper res,
        String accountNumber,
        String productTypeName,
        Boolean syncForDisplayOnly,
        Boolean skipCardMailingIndSync,
        String mailingInd
    ) {
        return persistAddressesFromApiResponse(
            hist,
            res,
            accountNumber,
            productTypeName,
            syncForDisplayOnly,
            skipCardMailingIndSync,
            mailingInd,
            null
        );
    }

    private static AddressUpdateResult persistAddressesFromApiResponse(
        FEC_Customer_History__c hist,
        FEC_GetAddressesList.ResponseWrapper res,
        String accountNumber,
        String productTypeName,
        Boolean syncForDisplayOnly,
        Boolean skipCardMailingIndSync,
        String mailingInd,
        FEC_CaseBusinessService.Error preloadedEligibilityError
    ) {
        AddressUpdateResult result = new AddressUpdateResult();
        FEC_CaseBusinessService.Error addrValErr = preloadedEligibilityError;
        if (addrValErr == null && hist != null && hist.Id != null) {
            addrValErr = getAddressUpdateEligibilityForUi(hist.Id);
            if (addrValErr != null && syncForDisplayOnly != true) {
                result.dtoList = buildAddressDTOListFromHistory(hist.Id);
                result.addressEligibilityError = addrValErr;
                return result;
            }
        }

        if (res == null || res.Addresses == null) {
            if (hist != null && hist.Id != null) {
                result.dtoList = buildAddressDTOListFromHistory(hist.Id);
            }
            if (addrValErr != null) {
                result.addressEligibilityError = addrValErr;
            }
            return result;
        }

        /* ===== MAP CODE  ===== */
        Map<String, Id> districtMap = new Map<String, Id>();
        for (FEC_District__c d : [
            SELECT Id, FEC_Code__c FROM FEC_District__c
        ]) {
            districtMap.put(d.FEC_Code__c, d.Id);
        }

        List<FEC_Country__c> allCountries = [
            SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Country__c
            ORDER BY FEC_Code__c NULLS LAST, Name
        ];
        Map<Id, FEC_Country__c> countryById = buildCountryByIdMap(allCountries);

        /* ===== EXISTING ===== */
        Map<String, FEC_Address_Info__c> existingMap = new Map<String, FEC_Address_Info__c>();
        for (FEC_Address_Info__c a : [
            SELECT Id, FEC_Address_Type__c,
                FEC_Building__c, FEC_Number__c, FEC_Street__c,
                FEC_District__c, FEC_Province__c,
                FEC_Country__c, FEC_ZipCode__c,
                FEC_Full_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
              AND FEC_Case__c = null
        ]) {
            existingMap.put(a.FEC_Address_Type__c, a);
        }

        List<FEC_Address_Info__c> toInsert = new List<FEC_Address_Info__c>();
        List<FEC_Address_Info__c> toUpdate = new List<FEC_Address_Info__c>();
        List<FEC_GetAddressesList.AddressInfo> addressesToSync = res.Addresses;

        for (FEC_GetAddressesList.AddressInfo ai : addressesToSync) {

            String type = mapApiAddressTypeToSF(ai.AddressType);
            if (String.isBlank(type)) continue;

            FEC_Address_Info__c addr;

            if (existingMap.containsKey(type)) {
                addr = existingMap.get(type);
            } else {
                addr = new FEC_Address_Info__c();
                addr.FEC_Customer_History__c = hist.Id;
                addr.FEC_Address_Type__c = type;
                toInsert.add(addr);
            }

            /* ===== BASIC FIELDS ===== */
            addr.FEC_Building__c = ai.Building;
            addr.FEC_Number__c   = ai.NumberStr;
            addr.FEC_Street__c   = ai.Street;
            addr.FEC_ZipCode__c  = ai.ZipCode;
            addr.FEC_Property_Status__c = ai.PropertyStatus;
            addr.FEC_Years__c = ai.Years != null ? String.valueOf(ai.Years) : null;
            addr.FEC_Months__c = ai.Months != null ? String.valueOf(ai.Months) : null;

            /* ===== WARD (Xã): không đồng bộ từ API GetAddressesList ===== */
            addr.FEC_Ward__c = null;
            addr.FEC_Ward_Text__c = null;

            /* ===== PROVINCE / CITY (resolve trước để quyết định District/Ward) ===== */
            Id provinceId = resolveProvinceForAddressSync(ai.City);
            if (provinceId != null) {
                addr.FEC_Province__c = provinceId;
                addr.FEC_Province_Text__c = null;
            } else if (String.isNotBlank(ai.City)) {
                addr.FEC_Province__c = null;
                addr.FEC_Province_Text__c = ai.City;
            } else {
                addr.FEC_Province__c = null;
                addr.FEC_Province_Text__c = null;
            }

            // District API → FEC_District__c (Ward UI); fallback FEC_District_Text__c.
            if (String.isNotBlank(ai.District) && districtMap.containsKey(ai.District)) {
                addr.FEC_District__c = districtMap.get(ai.District);
                addr.FEC_District_Text__c = null;
            } else if (String.isNotBlank(ai.District)) {
                addr.FEC_District__c = null;
                addr.FEC_District_Text__c = ai.District;
            } else {
                addr.FEC_District__c = null;
                addr.FEC_District_Text__c = null;
            }

            /* ===== COUNTRY: resolve từ API + remap 1 → 2 (cùng tên) cho FEC_Address_Info__c ===== */
            Id countryId = resolveCountryIdFromApiAddressInfo(ai, allCountries);
            if (countryId != null) {
                countryId = remapCountryIdToApiMaster(countryId, countryById);
                addr.FEC_Country__c = countryId;
                addr.FEC_Country_Text__c = null;
            } else {
                addr.FEC_Country__c = null;
                addr.FEC_Country_Text__c = ai.CountryName;
            }

            toUpdate.add(addr);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        if (FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE.equalsIgnoreCase(productTypeName)
            && String.isNotBlank(accountNumber)
            && skipCardMailingIndSync != true) {
            try {
                syncMailingAddressFlagsFromCardMailingInd(hist.Id, mailingInd);
            } catch (Exception e) {
                System.debug('### MailingInd sync FAILED: ' + e.getMessage());
            }
        }

        result.dtoList = buildAddressDTOListFromHistory(hist.Id);
        if (addrValErr != null) {
            result.addressEligibilityError = addrValErr;
        }
        return result;
    }

    private static List<AddressDTO> buildAddressDTOListFromHistory(Id customerHistoryId) {
        List<AddressDTO> outList = new List<AddressDTO>();
        for (FEC_Address_Info__c addr : [
            SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c,
                   FEC_District__r.FEC_Name_VN__c, FEC_District__r.Name,
                   FEC_District_Text__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Case__c = null
        ]) {
            AddressDTO dto = new AddressDTO();
            dto.addressInfoId = addr.Id != null ? String.valueOf(addr.Id) : null;
            dto.addressType = addr.FEC_Address_Type__c;
            String fullAddress = FEC_CommonUltils.removeTrailingComma(addr.FEC_Full_Address__c);
            dto.mailingAddress = addr.FEC_Mailing_Address__c == true
                ? FEC_ConstantCommon.TEXT_YES
                : FEC_ConstantCommon.TEXT_NO;
            // Ward = tên quận/huyện từ lookup, fallback sang text nếu không có trong master
            if (addr.FEC_District__c != null) {
                String vn = addr.FEC_District__r?.FEC_Name_VN__c;
                dto.ward = String.isNotBlank(vn) ? vn : addr.FEC_District__r?.Name;
            } else if (String.isNotBlank(addr.FEC_District_Text__c)) {
                dto.ward = addr.FEC_District_Text__c;
            }
            if (String.isNotBlank(dto.ward)) {
                String normalizedAddress = String.isNotBlank(fullAddress)
                    ? fullAddress.toLowerCase()
                    : '';
                String normalizedWard = dto.ward.toLowerCase();
                if (String.isBlank(fullAddress)) {
                    fullAddress = dto.ward;
                } else if (!normalizedAddress.contains(normalizedWard)) {
                    fullAddress = fullAddress + ', ' + dto.ward;
                }
            }
            dto.address = fullAddress;
            outList.add(dto);
        }
        return outList;
    }

    /** Map mã API GetAddressesList → FEC_Address_Info__c.FEC_Address_Type__c. */
    private static String mapApiAddressTypeToSF(String apiType) {
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_CURRES) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT;
        }
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_OFFICE) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE;
        }
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT;
        }
        return null;
    }

    /** Legacy FEC_Address__c meta → [cif, addressId, addressType]. */
    public static List<String> unpackPendingAddressApiMeta(String raw) {
        List<String> z = new List<String>{ '', '', '' };
        if (String.isBlank(raw)) {
            return z;
        }
        String head = PENDING_ADDR_META_PREFIX + PENDING_ADDR_META_SEP;
        if (!raw.startsWith(head)) {
            return z;
        }
        String body = raw.substring(head.length());
        List<String> parts = body.split(Pattern.quote(PENDING_ADDR_META_SEP), -1);
        for (Integer i = 0; i < 3; i++) {
            z[i] = (i < parts.size()) ? parts[i] : '';
        }
        return z;
    }

    private static Id resolveProvinceIdFromFecCode(String provinceCode) {
        if (String.isBlank(provinceCode)) {
            return null;
        }
        String code = provinceCode.trim();
        List<FEC_Province__c> lst = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Code__c = :code
            LIMIT 1
        ];
        return lst.isEmpty() ? null : lst[0].Id;
    }

    private static Boolean isDisplayableDistrictLabel(String label, String districtCode) {
        if (String.isBlank(label)) {
            return false;
        }
        if (String.isBlank(districtCode)) {
            return true;
        }
        return !label.trim().equalsIgnoreCase(districtCode.trim());
    }

    private static String districtLabelFromFecDistrictRecord(FEC_District__c d) {
        if (d == null) {
            return null;
        }
        String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(d.FEC_Name_VN__c);
        if (String.isBlank(lbl)) {
            lbl = d.Name;
        }
        return String.isNotBlank(lbl) ? lbl : null;
    }

    private static String resolveDistrictLabelFromMaster(
        String districtCode,
        String provinceCode
    ) {
        if (String.isBlank(districtCode)) {
            return null;
        }
        String dc = districtCode.trim();
        Id provinceId = null;
        if (String.isNotBlank(provinceCode)) {
            List<FEC_Province__c> provs = [
                SELECT Id
                FROM FEC_Province__c
                WHERE FEC_Code__c = :provinceCode.trim()
                  AND FEC_Country__r.FEC_Code__c = :FEC_COUNTRY_MASTER_API
                LIMIT 1
            ];
            if (!provs.isEmpty()) {
                provinceId = provs[0].Id;
            }
        }
        if (provinceId != null) {
            List<FEC_District__c> scoped = [
                SELECT FEC_Name_VN__c, Name, FEC_Code__c
                FROM FEC_District__c
                WHERE FEC_Code__c = :dc AND FEC_Province__c = :provinceId
                LIMIT 1
            ];
            if (!scoped.isEmpty()) {
                return districtLabelFromFecDistrictRecord(scoped[0]);
            }
        }
        List<FEC_District__c> anyProv = [
            SELECT FEC_Name_VN__c, Name, FEC_Code__c
            FROM FEC_District__c
            WHERE FEC_Code__c = :dc
            LIMIT 1
        ];
        return anyProv.isEmpty() ? null : districtLabelFromFecDistrictRecord(anyProv[0]);
    }

    private static String resolveDistrictLabelFromHistoryAddress(
        Id customerHistoryId,
        String sfAddressType,
        String districtCode
    ) {
        if (customerHistoryId == null || String.isBlank(sfAddressType)) {
            return null;
        }
        List<FEC_Address_Info__c> rows = [
            SELECT
                FEC_District__r.FEC_Name_VN__c,
                FEC_District__r.Name,
                FEC_District_Text__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Case__c = null
              AND FEC_Address_Type__c = :sfAddressType
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        FEC_Address_Info__c row = rows[0];
        if (row.FEC_District__r != null) {
            String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(
                row.FEC_District__r.FEC_Name_VN__c
            );
            if (String.isBlank(lbl)) {
                lbl = row.FEC_District__r.Name;
            }
            if (isDisplayableDistrictLabel(lbl, districtCode)) {
                return lbl;
            }
        }
        if (
            String.isNotBlank(row.FEC_District_Text__c) &&
            isDisplayableDistrictLabel(row.FEC_District_Text__c, districtCode)
        ) {
            return row.FEC_District_Text__c.trim();
        }
        return null;
    }

    /** Nhãn Ward: master → CIF Ward → SF history. */
    private static String resolveDistrictLabelForMailingContext(
        String districtCode,
        String provinceCode,
        FEC_GetAddressesList.AddressInfo apiAddress,
        Id customerHistoryId,
        String sfAddressType
    ) {
        if (String.isBlank(districtCode)) {
            return null;
        }
        String dc = districtCode.trim();
        String fromMaster = resolveDistrictLabelFromMaster(dc, provinceCode);
        if (isDisplayableDistrictLabel(fromMaster, dc)) {
            return fromMaster;
        }
        if (apiAddress != null && String.isNotBlank(apiAddress.Ward)) {
            String wardLbl = apiAddress.Ward.trim();
            if (isDisplayableDistrictLabel(wardLbl, dc)) {
                return wardLbl;
            }
        }
        String fromHistory = resolveDistrictLabelFromHistoryAddress(
            customerHistoryId,
            sfAddressType,
            dc
        );
        if (isDisplayableDistrictLabel(fromHistory, dc)) {
            return fromHistory;
        }
        return null;
    }

    private static Id resolveDistrictIdFromFecCode(String districtCode, Id provinceId) {
        if (String.isBlank(districtCode)) {
            return null;
        }
        String dc = districtCode.trim();
        if (provinceId != null) {
            List<FEC_District__c> lst = [
                SELECT Id
                FROM FEC_District__c
                WHERE FEC_Code__c = :dc AND FEC_Province__c = :provinceId
                LIMIT 1
            ];
            if (!lst.isEmpty()) {
                return lst[0].Id;
            }
        }
        List<FEC_District__c> lst2 = [
            SELECT Id
            FROM FEC_District__c
            WHERE FEC_Code__c = :dc
            LIMIT 1
        ];
        return lst2.isEmpty() ? null : lst2[0].Id;
    }

    private static Id resolveCountryIdFromProvinceId(Id provinceId) {
        if (provinceId == null) {
            return null;
        }
        List<FEC_Province__c> lst = [
            SELECT FEC_Country__c
            FROM FEC_Province__c
            WHERE Id = :provinceId
            LIMIT 1
        ];
        return lst.isEmpty() ? null : lst[0].FEC_Country__c;
    }

    private static String pendingProvinceLabelFromRow(FEC_Address_Info__c row) {
        if (row == null || row.FEC_Province__r == null) {
            return null;
        }
        String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(
            row.FEC_Province__r.FEC_Name_VN__c
        );
        return String.isNotBlank(lbl) ? lbl : null;
    }

    private static String pendingDistrictLabelFromRow(FEC_Address_Info__c row) {
        if (row == null || row.FEC_District__r == null) {
            return null;
        }
        String lbl = FEC_CommonUltils.picklistLabelFromFecNameVn(
            row.FEC_District__r.FEC_Name_VN__c
        );
        if (String.isBlank(lbl)) {
            lbl = row.FEC_District__r.Name;
        }
        if (String.isBlank(lbl)) {
            lbl = row.FEC_District__r.FEC_Code__c;
        }
        return String.isNotBlank(lbl) ? lbl : null;
    }

    private static String enrichStoredPendingJsonWithLabels(
        FEC_Address_Info__c row,
        String rawJson
    ) {
        if (String.isBlank(rawJson)) {
            return rawJson;
        }
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(
                rawJson.trim()
            );
            if (m == null) {
                return rawJson;
            }
            Object distLblObj = m.get('districtLabel');
            String distLblExisting =
                distLblObj != null ? String.valueOf(distLblObj).trim() : '';
            if (String.isBlank(distLblExisting)) {
                String distLbl = pendingDistrictLabelFromRow(row);
                if (String.isNotBlank(distLbl)) {
                    m.put('districtLabel', distLbl);
                }
            }
            Object cityLblObj = m.get('cityLabel');
            String cityLblExisting =
                cityLblObj != null ? String.valueOf(cityLblObj).trim() : '';
            if (String.isBlank(cityLblExisting)) {
                String cityLbl = pendingProvinceLabelFromRow(row);
                if (String.isNotBlank(cityLbl)) {
                    m.put('cityLabel', cityLbl);
                }
            }
            return JSON.serialize(m);
        } catch (Exception e) {
            return rawJson;
        }
    }

    private static String buildPendingJsonForLwc(
        FEC_Address_Info__c row,
        Id caseId,
        Id selectedMasterId,
        Id customerHistoryId,
        String defaultCifNumber,
        Map<String, PendingAddressApiMeta> apiMetaBySfType
    ) {
        String rawMeta = row.FEC_Address__c;
        if (String.isNotBlank(rawMeta) && rawMeta.trim().startsWith('{')) {
            return enrichStoredPendingJsonWithLabels(row, rawMeta);
        }
        List<String> meta = unpackPendingAddressApiMeta(rawMeta);
        String cif = meta[0];
        String aid = meta[1];
        String atyp = meta[2];
        if (String.isBlank(cif) && String.isNotBlank(defaultCifNumber)) {
            cif = defaultCifNumber;
        }
        if (String.isBlank(atyp) && String.isNotBlank(row.FEC_Address_Type__c)) {
            atyp = mapSfAddressTypeToApiCode(row.FEC_Address_Type__c);
        }
        if (String.isNotBlank(row.FEC_Address_Type__c) && apiMetaBySfType != null) {
            PendingAddressApiMeta prefetched = apiMetaBySfType.get(row.FEC_Address_Type__c);
            if (prefetched != null) {
                if (String.isBlank(cif) && String.isNotBlank(prefetched.cifNumber)) {
                    cif = prefetched.cifNumber;
                }
                if (String.isBlank(aid) && String.isNotBlank(prefetched.addressId)) {
                    aid = prefetched.addressId;
                }
                if (String.isBlank(atyp) && String.isNotBlank(prefetched.addressType)) {
                    atyp = prefetched.addressType;
                }
            }
        }
        Map<String, Object> m = new Map<String, Object>();
        m.put('cifNumber', cif);
        m.put('addressId', aid);
        m.put('addressType', atyp);
        m.put('number_x', row.FEC_Number__c);
        m.put('building', row.FEC_Building__c);
        m.put('street', row.FEC_Street__c);
        m.put(
            'district',
            (row.FEC_District__r != null) ? row.FEC_District__r.FEC_Code__c : null
        );
        m.put(
            'city',
            (row.FEC_Province__r != null) ? row.FEC_Province__r.FEC_Code__c : null
        );
        m.put('districtLabel', pendingDistrictLabelFromRow(row));
        m.put('cityLabel', pendingProvinceLabelFromRow(row));
        m.put('propertyStatus', row.FEC_Property_Status__c);
        m.put('years', blankToNullText(row.FEC_Years__c));
        m.put('months', blankToNullText(row.FEC_Months__c));
        Id rowMasterId = row.FEC_Parent_Address__c;
        if (rowMasterId == null && customerHistoryId != null && String.isNotBlank(row.FEC_Address_Type__c)) {
            rowMasterId = resolveOriginalAddressIdForType(
                customerHistoryId,
                row.FEC_Address_Type__c
            );
        }
        if (selectedMasterId == null) {
            selectedMasterId = resolveCaseSelectedAddressInfoId(caseId);
        }
        m.put(
            'isMailingAddress',
            (selectedMasterId != null && rowMasterId == selectedMasterId) ? 'Y' : 'N'
        );
        return JSON.serialize(m);
    }

    /**
     * Map sfAddressType → JSON pending cho LWC (từ các trường địa chỉ + meta CIF đã prefetch).
     */
    public static Map<String, String> loadCasePendingAddressJsonMap(Id caseId) {
        return loadCasePendingAddressJsonMap(caseId, null, null);
    }

    private static Map<String, String> loadCasePendingAddressJsonMap(
        Id caseId,
        String defaultCifNumber,
        Map<String, PendingAddressApiMeta> apiMetaBySfType
    ) {
        Map<String, String> outMap = new Map<String, String>();
        if (caseId == null) {
            return outMap;
        }
        Case caseRow = [
            SELECT FEC_Account_or_Contract__c, FEC_Selected_Address_Info__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        Id selectedMasterId = caseRow.FEC_Selected_Address_Info__c;
        Id customerHistoryId = caseRow.FEC_Account_or_Contract__c;
        String cifForPending = defaultCifNumber;
        Map<String, PendingAddressApiMeta> metaBySfType = apiMetaBySfType;
        if (metaBySfType == null) {
            if (String.isBlank(cifForPending) && customerHistoryId != null) {
                List<FEC_Customer_History__c> hists = [
                    SELECT FEC_CIF_Number__c
                    FROM FEC_Customer_History__c
                    WHERE Id = :customerHistoryId
                    LIMIT 1
                ];
                if (!hists.isEmpty()) {
                    cifForPending = hists[0].FEC_CIF_Number__c;
                }
            }
            metaBySfType = prefetchPendingAddressApiMeta(caseId, cifForPending, null);
        }
        for (FEC_Address_Info__c row : [
            SELECT
                FEC_Address_Type__c,
                FEC_Address__c,
                FEC_Building__c,
                FEC_Number__c,
                FEC_Street__c,
                FEC_Property_Status__c,
                FEC_Years__c,
                FEC_Months__c,
                FEC_Parent_Address__c,
                FEC_District__r.FEC_Code__c,
                FEC_District__r.FEC_Name_VN__c,
                FEC_District__r.Name,
                FEC_Province__r.FEC_Code__c,
                FEC_Province__r.FEC_Name_VN__c
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :caseId
        ]) {
            if (row == null || String.isBlank(row.FEC_Address_Type__c)) {
                continue;
            }
            outMap.put(row.FEC_Address_Type__c, buildPendingJsonForLwc(
                row,
                caseId,
                selectedMasterId,
                customerHistoryId,
                cifForPending,
                metaBySfType
            ));
        }
        return outMap;
    }

    /** Xóa FEC_Address_Info__c pending theo Case. */
    public static void clearCasePendingAddressRows(Id caseId) {
        if (caseId == null) {
            return;
        }
        delete [
            SELECT Id
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :caseId
        ];
    }

    private static final List<String> STANDARD_SF_ADDRESS_TYPES = new List<String>{
        FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
        FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
        FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
    };

    /**
     * Luồng Update Address: clone pending (FEC_Case__c = Case) từ từng master có sẵn
     * (Permanent / Office / Current) — 1 master → 1 pending, 2 → 2, 3 → 3.
     * Chỉ copy các cột địa chỉ; không ghi FEC_Address__c (JSON build khi load LWC / gọi API).
     * Idempotent: bỏ qua nếu Case đã có pending hoặc đã có FEC_Updated_Info_* (đã Save/Submit).
     */
    @AuraEnabled
    public static Integer initializeCasePendingAddressesFromMasters(Id caseId) {
        if (caseId == null) {
            return 0;
        }
        Case c = [
            SELECT
                Id,
                FEC_Account_or_Contract__c,
                FEC_Updated_Info_Permanent_Address__c,
                FEC_Updated_Info_Office_Address__c,
                FEC_Updated_Info_Current_Address__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) {
            return 0;
        }
        if (hasAnyCaseUpdatedInfoAddress(c)) {
            return 0;
        }
        Integer existingPending = [
            SELECT COUNT()
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :caseId
        ];
        if (existingPending > 0) {
            return 0;
        }

        Map<String, FEC_Address_Info__c> masterByType = new Map<String, FEC_Address_Info__c>();
        for (FEC_Address_Info__c master : [
            SELECT
                Id,
                FEC_Address_Type__c,
                FEC_Building__c,
                FEC_Number__c,
                FEC_Street__c,
                FEC_District__c,
                FEC_Province__c,
                FEC_Country__c,
                FEC_Property_Status__c,
                FEC_Years__c,
                FEC_Months__c,
                FEC_District__r.FEC_Code__c,
                FEC_District__r.FEC_Name_VN__c,
                FEC_District__r.Name,
                FEC_Province__r.FEC_Code__c,
                FEC_Province__r.FEC_Name_VN__c,
                FEC_Province__r.Name
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
              AND FEC_Case__c = null
              AND FEC_Address_Type__c IN :STANDARD_SF_ADDRESS_TYPES
        ]) {
            if (master != null && String.isNotBlank(master.FEC_Address_Type__c)) {
                masterByType.put(master.FEC_Address_Type__c, master);
            }
        }
        if (masterByType.isEmpty()) {
            return 0;
        }

        List<FEC_Address_Info__c> toInsert = new List<FEC_Address_Info__c>();
        for (String sfType : STANDARD_SF_ADDRESS_TYPES) {
            FEC_Address_Info__c master = masterByType.get(sfType);
            if (master == null) {
                continue;
            }
            toInsert.add(new FEC_Address_Info__c(
                Name = sfType.left(80),
                FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
                FEC_Case__c = caseId,
                FEC_Address_Type__c = sfType,
                FEC_Building__c = master.FEC_Building__c,
                FEC_Number__c = master.FEC_Number__c,
                FEC_Street__c = master.FEC_Street__c,
                FEC_District__c = master.FEC_District__c,
                FEC_Province__c = master.FEC_Province__c,
                FEC_Country__c = master.FEC_Country__c,
                FEC_Property_Status__c = master.FEC_Property_Status__c,
                FEC_Years__c = master.FEC_Years__c,
                FEC_Months__c = master.FEC_Months__c,
                FEC_Parent_Address__c = master.Id,
                FEC_Mailing_Address__c = false
            ));
        }
        if (toInsert.isEmpty()) {
            return 0;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        insert toInsert;
        return toInsert.size();
    }

    private class PendingPropertyFields {
        String propertyStatus;
        String years;
        String months;
    }

    private static PendingPropertyFields resolvePendingPropertyFields(
        String pendingAddressJson,
        Id parentAddressInfoId
    ) {
        PendingPropertyFields out = new PendingPropertyFields();
        if (String.isNotBlank(pendingAddressJson) && pendingAddressJson.trim().startsWith('{')) {
            try {
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
                    pendingAddressJson.trim()
                );
                if (data != null) {
                    Object prop = data.get('propertyStatus');
                    out.propertyStatus = prop != null ? String.valueOf(prop).trim() : null;
                    out.years = parsePendingTextField(data.get('years'));
                    out.months = parsePendingTextField(data.get('months'));
                }
            } catch (Exception e) {
                // fallback parent
            }
        }
        if (parentAddressInfoId != null) {
            List<FEC_Address_Info__c> parents = [
                SELECT FEC_Property_Status__c, FEC_Years__c, FEC_Months__c
                FROM FEC_Address_Info__c
                WHERE Id = :parentAddressInfoId
                LIMIT 1
            ];
            if (!parents.isEmpty()) {
                FEC_Address_Info__c parent = parents[0];
                if (String.isBlank(out.propertyStatus)) {
                    out.propertyStatus = parent.FEC_Property_Status__c;
                }
                if (String.isBlank(out.years)) {
                    out.years = parent.FEC_Years__c;
                }
                if (String.isBlank(out.months)) {
                    out.months = parent.FEC_Months__c;
                }
            }
        }
        return out;
    }

    private static String parsePendingTextField(Object raw) {
        if (raw == null) {
            return null;
        }
        return blankToNullText(String.valueOf(raw));
    }

    private static String blankToNullText(String val) {
        if (String.isBlank(val)) {
            return null;
        }
        return val.trim();
    }

    /** Lưu địa chỉ pending (FEC_Case__c = Case); FEC_Parent_Address__c = Id Original Address (master). Trả Id pending. */
    @AuraEnabled
    public static Id savePendingAddress(
        Id caseId,
        String sfAddressType,
        Boolean deletePending,
        Id parentAddressInfoId,
        String building,
        String number_x,
        String street,
        String districtCode,
        String provinceCode,
        Boolean isMailingAddress,
        String pendingAddressJson
    ) {
        if (caseId == null || String.isBlank(sfAddressType)) {
            throw new AuraHandledException('caseId and sfAddressType are required');
        }
        Set<String> allowed = new Set<String>{
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT
        };
        if (!allowed.contains(sfAddressType)) {
            throw new AuraHandledException('Unknown sfAddressType: ' + sfAddressType);
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException('Case has no Customer History');
        }

        if (parentAddressInfoId == null) {
            parentAddressInfoId = resolveOriginalAddressIdForType(
                c.FEC_Account_or_Contract__c,
                sfAddressType
            );
        }

        List<FEC_Address_Info__c> existing = [
            SELECT Id
            FROM FEC_Address_Info__c
            WHERE FEC_Case__c = :caseId
              AND FEC_Address_Type__c = :sfAddressType
            LIMIT 1
        ];

        if (deletePending == true) {
            if (!existing.isEmpty()) {
                FEC_CaseTriggerHandler.isExecuting = true;
                delete existing;
            }
            return null;
        }

        if (parentAddressInfoId != null) {
            List<FEC_Address_Info__c> par = [
                SELECT Id, FEC_Customer_History__c, FEC_Case__c
                FROM FEC_Address_Info__c
                WHERE Id = :parentAddressInfoId
                LIMIT 1
            ];
            if (
                par.isEmpty() ||
                par[0].FEC_Customer_History__c != c.FEC_Account_or_Contract__c ||
                par[0].FEC_Case__c != null
            ) {
                throw new AuraHandledException('Invalid FEC_Parent_Address__c for this Case / Customer History');
            }
        }

        Id provId = resolveProvinceIdFromFecCode(provinceCode);
        Id distId = resolveDistrictIdFromFecCode(districtCode, provId);
        Id countryId = resolveCountryIdFromProvinceId(provId);

        PendingPropertyFields propertyFields = resolvePendingPropertyFields(
            pendingAddressJson,
            parentAddressInfoId
        );

        Id pendingId = persistPendingRowAndReturnId(
            caseId,
            c.FEC_Account_or_Contract__c,
            sfAddressType,
            parentAddressInfoId,
            building,
            number_x,
            street,
            distId,
            provId,
            countryId,
            propertyFields,
            pendingAddressJson,
            existing
        );
        syncCaseUpdatedInfoFromPendingRow(caseId, pendingId);
        return pendingId;
    }

    /** Gán pending JSON từ FEC_Address_Info__c (theo Case) vào DTO (luôn gọi sau cache/API, không đưa vào cache). */
    private static void applyPendingAddressFields(MainInfoDTO dto, Id caseId) {
        applyPendingAddressFields(dto, caseId, null, null);
    }

    private static void applyPendingAddressFields(
        MainInfoDTO dto,
        Id caseId,
        String defaultCifNumber,
        Map<String, PendingAddressApiMeta> apiMetaBySfType
    ) {
        dto.pendingPermanentAddressJson = null;
        dto.pendingOfficeAddressJson = null;
        dto.pendingCurrentAddressJson = null;
        if (caseId == null) {
            return;
        }
        Map<String, String> m = loadCasePendingAddressJsonMap(
            caseId,
            defaultCifNumber,
            apiMetaBySfType
        );
        dto.pendingPermanentAddressJson = m.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT);
        dto.pendingOfficeAddressJson = m.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE);
        dto.pendingCurrentAddressJson = m.get(FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT);
    }

    /**
     * Cột Updated Information: chỉ gán chuỗi FEC_Updated_Info_* lên DTO — không ghi đè
     * mainInfoData.addresses (LWC dùng snapshot addresses làm Original).
     */
    private static void applyCaseUpdatedInfoAddressFields(MainInfoDTO dto, Case c) {
        if (dto == null || c == null) {
            return;
        }
        dto.updatedInfoPermanentAddress = blankToNullText(c.FEC_Updated_Info_Permanent_Address__c);
        dto.updatedInfoOfficeAddress = blankToNullText(c.FEC_Updated_Info_Office_Address__c);
        dto.updatedInfoCurrentAddress = blankToNullText(c.FEC_Updated_Info_Current_Address__c);
    }

    private static Boolean hasAnyCaseUpdatedInfoAddress(Case c) {
        if (c == null) {
            return false;
        }
        return String.isNotBlank(c.FEC_Updated_Info_Permanent_Address__c)
            || String.isNotBlank(c.FEC_Updated_Info_Office_Address__c)
            || String.isNotBlank(c.FEC_Updated_Info_Current_Address__c);
    }

    private static Map<String, String> buildCaseUpdatedInfoAddressMap(Case c) {
        Map<String, String> outMap = new Map<String, String>();
        if (c == null) {
            return outMap;
        }
        putUpdatedInfoAddressIfPresent(
            outMap,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT,
            c.FEC_Updated_Info_Permanent_Address__c
        );
        putUpdatedInfoAddressIfPresent(
            outMap,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE,
            c.FEC_Updated_Info_Office_Address__c
        );
        putUpdatedInfoAddressIfPresent(
            outMap,
            FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT,
            c.FEC_Updated_Info_Current_Address__c
        );
        return outMap;
    }

    private static void putUpdatedInfoAddressIfPresent(
        Map<String, String> outMap,
        String sfType,
        String rawText
    ) {
        if (outMap == null || String.isBlank(sfType) || String.isBlank(rawText)) {
            return;
        }
        outMap.put(sfType, rawText.trim());
    }

    /** Ghép chuỗi hiển thị giống composeAddressText trên LWC. */
    private static String composeDisplayAddressFromParts(
        String building,
        String number_x,
        String street,
        String districtLabel,
        String cityLabel
    ) {
        List<String> parts = new List<String>();
        addDisplayPart(parts, building);
        addDisplayPart(parts, number_x);
        addDisplayPart(parts, street);
        addDisplayPart(parts, districtLabel);
        addDisplayPart(parts, cityLabel);
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static void addDisplayPart(List<String> parts, String val) {
        if (parts == null || String.isBlank(val)) {
            return;
        }
        parts.add(val.trim());
    }

    private static String composeDisplayAddressFromPendingRow(FEC_Address_Info__c row) {
        if (row == null) {
            return null;
        }
        return composeDisplayAddressFromParts(
            row.FEC_Building__c,
            row.FEC_Number__c,
            row.FEC_Street__c,
            pendingDistrictLabelFromRow(row),
            pendingProvinceLabelFromRow(row)
        );
    }

    /** Lưu chuỗi hiển thị Updated Information lên Case (sau Save / trước xóa pending). */
    public static void persistCaseUpdatedInfoAddressForType(
        Id caseId,
        String sfAddressType,
        String displayText
    ) {
        if (caseId == null || String.isBlank(sfAddressType)) {
            return;
        }
        Case patch = new Case(Id = caseId);
        assignUpdatedInfoAddressField(patch, sfAddressType, displayText);
        FEC_CaseTriggerHandler.isExecuting = true;
        update patch;
    }

    private static void assignUpdatedInfoAddressField(
        Case patch,
        String sfAddressType,
        String displayText
    ) {
        if (patch == null || String.isBlank(sfAddressType)) {
            return;
        }
        String val = String.isBlank(displayText) ? null : displayText.trim();
        if (sfAddressType == FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT) {
            patch.FEC_Updated_Info_Permanent_Address__c = val;
        } else if (sfAddressType == FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE) {
            patch.FEC_Updated_Info_Office_Address__c = val;
        } else if (sfAddressType == FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT) {
            patch.FEC_Updated_Info_Current_Address__c = val;
        }
    }

    private static Id persistPendingRowAndReturnId(
        Id caseId,
        Id customerHistoryId,
        String sfAddressType,
        Id parentAddressInfoId,
        String building,
        String number_x,
        String street,
        Id distId,
        Id provId,
        Id countryId,
        PendingPropertyFields propertyFields,
        String pendingAddressJson,
        List<FEC_Address_Info__c> existing
    ) {
        String nameVal = sfAddressType.left(80);
        Id pendingId;
        if (!existing.isEmpty()) {
            pendingId = existing[0].Id;
            FEC_Address_Info__c upd = new FEC_Address_Info__c(
                Id = pendingId,
                Name = nameVal,
                FEC_Address_Type__c = sfAddressType,
                FEC_Building__c = building,
                FEC_Number__c = number_x,
                FEC_Street__c = street,
                FEC_District__c = distId,
                FEC_Province__c = provId,
                FEC_Country__c = countryId,
                FEC_Property_Status__c = propertyFields.propertyStatus,
                FEC_Years__c = propertyFields.years,
                FEC_Months__c = propertyFields.months,
                FEC_Parent_Address__c = parentAddressInfoId,
                FEC_Address__c = String.isNotBlank(pendingAddressJson) ? pendingAddressJson : null
            );
            FEC_CaseTriggerHandler.isExecuting = true;
            update upd;
        } else {
            FEC_Address_Info__c ins = new FEC_Address_Info__c(
                Name = nameVal,
                FEC_Customer_History__c = customerHistoryId,
                FEC_Case__c = caseId,
                FEC_Address_Type__c = sfAddressType,
                FEC_Building__c = building,
                FEC_Number__c = number_x,
                FEC_Street__c = street,
                FEC_District__c = distId,
                FEC_Province__c = provId,
                FEC_Country__c = countryId,
                FEC_Property_Status__c = propertyFields.propertyStatus,
                FEC_Years__c = propertyFields.years,
                FEC_Months__c = propertyFields.months,
                FEC_Parent_Address__c = parentAddressInfoId,
                FEC_Address__c = String.isNotBlank(pendingAddressJson) ? pendingAddressJson : null
            );
            FEC_CaseTriggerHandler.isExecuting = true;
            insert ins;
            pendingId = ins.Id;
        }
        return pendingId;
    }

    public static void syncCaseUpdatedInfoFromPendingRow(Id caseId, Id pendingRowId) {
        if (caseId == null || pendingRowId == null) {
            return;
        }
        List<FEC_Address_Info__c> savedRows = [
            SELECT
                FEC_Address_Type__c,
                FEC_Address__c,
                FEC_Parent_Address__c,
                FEC_Building__c,
                FEC_Number__c,
                FEC_Street__c,
                FEC_District__r.FEC_Code__c,
                FEC_District__r.FEC_Name_VN__c,
                FEC_District__r.Name,
                FEC_Province__r.FEC_Code__c,
                FEC_Province__r.FEC_Name_VN__c
            FROM FEC_Address_Info__c
            WHERE Id = :pendingRowId
            LIMIT 1
        ];
        if (savedRows.isEmpty()) {
            return;
        }
        FEC_Address_Info__c saved = savedRows[0];
        if (String.isBlank(saved.FEC_Address_Type__c)) {
            return;
        }
        String displayText = composeDisplayAddressFromPendingRow(saved);
        List<Case> caseRows = [
            SELECT FEC_Selected_Address__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        Case patch = new Case(Id = caseId);
        Boolean dirty = false;
        if (String.isNotBlank(displayText)) {
            assignUpdatedInfoAddressField(patch, saved.FEC_Address_Type__c, displayText);
            dirty = true;
        }
        if (
            applySelectedMailingAddressFromPendingJson(
                patch,
                caseRows.isEmpty() ? null : caseRows[0],
                saved
            )
        ) {
            dirty = true;
        }
        if (dirty) {
            FEC_CaseTriggerHandler.isExecuting = true;
            update patch;
        }
    }

    private static String parseIsMailingAddressFromPendingJson(String pendingAddressJson) {
        if (String.isBlank(pendingAddressJson) || !pendingAddressJson.trim().startsWith('{')) {
            return null;
        }
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
                pendingAddressJson.trim()
            );
            Object raw = data.get('isMailingAddress');
            if (raw == null) {
                return null;
            }
            return String.valueOf(raw).trim();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Ghi Case.FEC_Selected_Address__c khi user tick Mailing (isMailingAddress = Y trong pending JSON).
     * FEC_Selected_Address_Info__c vẫn dùng cho Address Update API target.
     */
    private static Boolean applySelectedMailingAddressFromPendingJson(
        Case patch,
        Case existingCase,
        FEC_Address_Info__c pending
    ) {
        if (patch == null || pending == null) {
            return false;
        }
        String isMailing = parseIsMailingAddressFromPendingJson(pending.FEC_Address__c);
        if (String.isBlank(isMailing)) {
            return false;
        }
        Id mailingTargetId = pending.FEC_Parent_Address__c != null
            ? pending.FEC_Parent_Address__c
            : pending.Id;
        if ('Y'.equalsIgnoreCase(isMailing)) {
            patch.FEC_Selected_Address__c = mailingTargetId;
            return true;
        }
        if ('N'.equalsIgnoreCase(isMailing)) {
            Id currentMailingId = existingCase != null
                ? existingCase.FEC_Selected_Address__c
                : null;
            if (currentMailingId != null && currentMailingId == mailingTargetId) {
                patch.FEC_Selected_Address__c = null;
                return true;
            }
        }
        return false;
    }

    private static MainInfoDTO mapToDTO(FEC_Customer_History__c h) {
        MainInfoDTO d = new MainInfoDTO();
        d.firstName = h.FEC_First_Name__c;
        d.middleName = h.FEC_Middle_Name__c;
        d.lastName = h.FEC_Last_Name__c;
        d.fullName = h.FEC_Customer_Name__c;
        d.birthDate = h.FEC_Date_of_Birth__c;
        d.gender = h.FEC_Gender__c;
        d.maritalStatus = h.FEC_Marital_Status__c;
        d.cifNumber = h.FEC_CIF_Number__c;
        d.nationalIDPassportID = h.FEC_National_ID_Passport_ID__c;
        d.placeOfIssue = h.FEC_Place_of_Issue__c;
        d.dateOfIssue = String.valueOf(h.FEC_Date_of_Issue__c);
        d.primaryPhone = h.FEC_Primary_Phone__c;
        return d;
    }
}