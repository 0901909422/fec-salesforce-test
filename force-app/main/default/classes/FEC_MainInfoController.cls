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
    }

    public class AddressDTO {
        @AuraEnabled public String addressType;
        @AuraEnabled public String address;
        @AuraEnabled public String mailingAddress;
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
        @AuraEnabled public String ward;
        @AuraEnabled public String city;
        @AuraEnabled public Boolean found;
        @AuraEnabled public String message;
    }

    private class AddressUpdateResult {
        List<FEC_Address_Info__c> toUpdate = new List<FEC_Address_Info__c>();
        List<AddressDTO> dtoList = new List<AddressDTO>();
        /** null = đủ điều kiện đồng bộ; non-null = đã format cho UI địa chỉ. */
        FEC_CaseBusinessService.Error addressEligibilityError;
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
            SELECT Id, FEC_Account_or_Contract__c,FEC_Product_Type__r.Name
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
        String cifNumber = hist.FEC_CIF_Number__c;
        /* ===== CACHE HIT ===== */
        if (String.isNotBlank(hist.FEC_API_Cache__c)) {
            MainInfoDTO cached = (MainInfoDTO) JSON.deserialize(
                hist.FEC_API_Cache__c,
                MainInfoDTO.class
            );
            /* Luôn lấy địa chỉ từ FEC_Address_Info__c — không tin mảng addresses trong JSON cache (dễ lệch sau khi đồng bộ API / map PERMNENT). */
            cached.addresses = buildAddressDTOListFromHistory(hist.Id);
            if (cached.addresses != null && !cached.addresses.isEmpty()) {
                applyAddressEligibilityToDto(cached, hist.Id, null);
                return cached;
            }
            /* Còn cache thông tin KH nhưng đã xóa hết địa chỉ trên SF — phải gọi lại GetAddressesList, không return sớm với mảng rỗng. */
            if (String.isNotBlank(cifNumber)) {
                try {
                    AddressUpdateResult addrResult = updateAddressesFromApi(hist, cifNumber);
                    cached.addresses = addrResult.dtoList;
                    cached.addressUpdateNotEligibleTitle = null;
                    cached.addressUpdateNotEligibleReasons = null;
                    hist.FEC_API_Cache__c = JSON.serialize(cached);
                    update hist;
                    applyAddressEligibilityToDto(cached, hist.Id, addrResult);
                } catch (Exception e) {
                    System.debug('### GetAddressesList (cache + empty addresses resync) FAILED: ' + e.getMessage());
                    applyAddressEligibilityToDto(cached, hist.Id, null);
                }
            } else {
                applyAddressEligibilityToDto(cached, hist.Id, null);
            }
            return cached;
        }

        /* =====================================================
         * CALL API
         * ===================================================== */

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

        /* ===== 2. GetDocumentsList ===== */
        try {
            FEC_GetDocumentsList.ResponseWrapper docRes =
                FEC_GetDocumentsList.callGetDocumentsList(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    cifNumber
                );

            if (docRes != null && docRes.Documents != null && !docRes.Documents.isEmpty()) {
                hist.FEC_National_ID_Passport_ID__c = docRes.Documents[0].DocumentID;
                hist.FEC_Date_of_Issue__c           = docRes.Documents[0].IssueDate;
                hist.FEC_Place_of_Issue__c          = docRes.Documents[0].IssuePlace;
            }
        } catch (Exception e) {
            System.debug('### GetDocumentsList FAILED: ' + e.getMessage());
        }

        /* ===== 3. GetCustomerList ===== */
        try {
            hist.FEC_Primary_Phone__c = getPrimaryPhoneOnly(accountNumber);
        } catch (Exception e) {
            System.debug('### GetCustomerList FAILED: ' + e.getMessage());
        }

        /* ===== 4. GetAddressesList ===== */
        AddressUpdateResult addrResult = new AddressUpdateResult();
        try {
            addrResult = updateAddressesFromApi(hist,cifNumber);
        } catch (Exception e) {
            System.debug('### GetAddressesList FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * DML
         * ===================================================== */
        update hist;

        if (!addrResult.toUpdate.isEmpty()) {
            update addrResult.toUpdate;
        }

        /* =====================================================
         * BUILD DTO
         * ===================================================== */
        MainInfoDTO dto = mapToDTO(hist);
        dto.addresses = addrResult.dtoList;
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);

        /* ===== SAVE CACHE ===== */
        dto.addressUpdateNotEligibleTitle = null;
        dto.addressUpdateNotEligibleReasons = null;
        hist.FEC_API_Cache__c = JSON.serialize(dto);
        update hist;

        applyAddressEligibilityToDto(dto, hist.Id, addrResult);
        return dto;
    }

    /* =====================================================
     * LOG SENSITIVE
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getProvinceOptionsForAddress() {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        for (FEC_Province__c p : [
            SELECT Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Province__c
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            if (String.isBlank(p.FEC_Code__c)) {
                continue;
            }
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = p.FEC_Code__c;
            o.label = String.isNotBlank(p.FEC_Name_VN__c) ? p.FEC_Name_VN__c : p.Name;
            opts.add(o);
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOptionDTO> getWardOptionsForProvinceCode(String provinceCode) {
        List<PicklistOptionDTO> opts = new List<PicklistOptionDTO>();
        if (String.isBlank(provinceCode)) {
            return opts;
        }
        List<FEC_Province__c> provs = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Code__c = :provinceCode
            LIMIT 1
        ];
        if (provs.isEmpty()) {
            return opts;
        }
        Id provinceId = provs[0].Id;
        for (FEC_Ward__c w : [
            SELECT Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Ward__c
            WHERE FEC_Province__c = :provinceId
            ORDER BY FEC_Name_VN__c NULLS LAST, Name
        ]) {
            if (String.isBlank(w.FEC_Code__c)) {
                continue;
            }
            PicklistOptionDTO o = new PicklistOptionDTO();
            o.value = w.FEC_Code__c;
            o.label = String.isNotBlank(w.FEC_Name_VN__c) ? w.FEC_Name_VN__c : w.Name;
            opts.add(o);
        }
        return opts;
    }

    /**
     * Gọi Update Customer Address (SOAP); ghi API log sau khi callout xong (không log trong class API).
     */
    @AuraEnabled
    public static FEC_UpdateCustomerAddress.UpdateResult updateCustomerAddressParams(
        String caseId,
        String sfAddressType,
        String cifNumber,
        String addressId,
        String addressType,
        String number_x,
        String building,
        String street,
        String ward,
        String city,
        String propertyStatus,
        String years,
        String months,
        String isMailingAddress,
        String isPrimary,
        String receiveStatement,
        String cardDelivery
    ) {
        try {
            return FEC_UpdateCustomerAddress.updateCustomerAddressParams(
                caseId,
                sfAddressType,
                cifNumber,
                addressId,
                addressType,
                number_x,
                building,
                street,
                ward,
                city,
                propertyStatus,
                years,
                months,
                isMailingAddress,
                isPrimary,
                receiveStatement,
                cardDelivery
            );
        } finally {
            FEC_UpdateCustomerAddress.logApiResponse();
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
        if (sfAddressType == FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT) {
            for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
                if (ai != null && ai.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT) {
                    found = ai;
                    break;
                }
            }
            if (found == null) {
                for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
                    if (ai != null && ai.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_PERMANENT) {
                        found = ai;
                        break;
                    }
                }
            }
        } else {
            for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
                if (ai != null && ai.AddressType == apiType) {
                    found = ai;
                    break;
                }
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
        dto.ward = found.Ward;
        dto.city = found.City;
        return dto;
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

    /* ================= HELPER METHODS ================= */

    /**
     * Đủ điều kiện đồng bộ địa chỉ hay không (rule giống phoneUpdateValidate).
     * Trả về null nếu được phép; khi chặn: Error với tiêu đề + các dòng Lí do cho UI.
     */
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

    /**
     * Gắn thông báo chặn cập nhật địa chỉ lên DTO trả về LWC (không lưu vào FEC_API_Cache__c).
     * addrResult != null: dùng kết quả đồng bộ địa chỉ (tránh gọi validate trùng).
     * addrResult == null: chỉ đọc cache / chưa gọi GetAddressesList — validate một lần.
     */
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

    private static String getPrimaryPhoneOnly(String accountNumber) {
        FEC_GetCustomerList.ResponseWrapper res =
            FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN, null, false,
                null, null, null, null, accountNumber, null, null, null
            );

        if (res == null) return null;

        for (FEC_GetCustomerList.Customer c : res.Customers)
            for (FEC_GetCustomerList.Phone p : c.Phones)
                if (p.Type == 'Mobile') return p.Phone;

        return null;
    }

    private static AddressUpdateResult updateAddressesFromApi(
        FEC_Customer_History__c hist,
        String cifNumber
    ) {
        AddressUpdateResult result = new AddressUpdateResult();

        if (hist != null && hist.Id != null) {
            FEC_CaseBusinessService.Error addrValErr =
                getAddressUpdateEligibilityForUi(hist.Id);
            if (addrValErr != null) {
                result.dtoList = buildAddressDTOListFromHistory(hist.Id);
                result.addressEligibilityError = addrValErr;
                return result;
            }
        }

        FEC_GetAddressesList.ResponseWrapper res =
            FEC_GetAddressesList.callGetAddressesList(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                cifNumber
            );

        if (res == null || res.Addresses == null) return result;

        List<FEC_GetAddressesList.AddressInfo> addressesToSync =
            filterDuplicatePermanentAddressTypes(res.Addresses);

        /* ===== MAP CODE  ===== */
        Map<String, Id> provinceMap = new Map<String, Id>();
        for (FEC_Province__c c : [
            SELECT Id, FEC_Code__c FROM FEC_Province__c
        ]) {
            provinceMap.put(c.FEC_Code__c, c.Id);
        }

        Map<String, Id> districtMap = new Map<String, Id>();
        for (FEC_District__c d : [
            SELECT Id, FEC_Code__c FROM FEC_District__c
        ]) {
            districtMap.put(d.FEC_Code__c, d.Id);
        }

        Map<String, Id> wardMap = new Map<String, Id>();
        for (FEC_Ward__c w : [
            SELECT Id, FEC_Code__c FROM FEC_Ward__c
        ]) {
            wardMap.put(w.FEC_Code__c, w.Id);
        }

        Map<String, Id> countryMap = new Map<String, Id>();
        for (FEC_Country__c country : [
            SELECT Id, FEC_Code__c FROM FEC_Country__c
        ]) {
            countryMap.put(country.FEC_Code__c, country.Id);
        }

        /* ===== EXISTING ===== */
        Map<String, FEC_Address_Info__c> existingMap = new Map<String, FEC_Address_Info__c>();
        for (FEC_Address_Info__c a : [
            SELECT Id, FEC_Address_Type__c,
                FEC_Building__c, FEC_Number__c, FEC_Street__c,
                FEC_Ward__c, FEC_District__c, FEC_Province__c,
                FEC_Country__c, FEC_ZipCode__c,
                FEC_Full_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
        ]) {
            existingMap.put(a.FEC_Address_Type__c, a);
        }

        List<FEC_Address_Info__c> toInsert = new List<FEC_Address_Info__c>();

        /* ===== PROCESS ===== */
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
            addr.FEC_Mailing_Address__c = true;

            /* ===== WARD ===== */
            if (String.isNotBlank(ai.Ward) && wardMap.containsKey(ai.Ward)) {
                addr.FEC_Ward__c = wardMap.get(ai.Ward);
                addr.FEC_Ward_Text__c = null;
            } else {
                addr.FEC_Ward__c = null;
                addr.FEC_Ward_Text__c = ai.Ward;
            }

            /* ===== DISTRICT ===== */
            if (String.isNotBlank(ai.District) && districtMap.containsKey(ai.District)) {
                addr.FEC_District__c = districtMap.get(ai.District);
                addr.FEC_District_Text__c = null;
            } else {
                addr.FEC_District__c = null;
                addr.FEC_District_Text__c = ai.District;
            }

            /* ===== PROVINCE ===== */
            if (String.isNotBlank(ai.City) && provinceMap.containsKey(ai.City)) {
                addr.FEC_Province__c = provinceMap.get(ai.City);
                addr.FEC_Province_Text__c = null;
            } else {
                addr.FEC_Province__c = null;
                addr.FEC_Province_Text__c = ai.City;
            }

            /* ===== COUNTRY ===== */
            if (String.isNotBlank(ai.CountryName) && countryMap.containsKey(ai.CountryName)) {
                addr.FEC_Country__c = countryMap.get(ai.CountryName);
                addr.FEC_Country_Text__c = null;
            } else {
                addr.FEC_Country__c = null;
                addr.FEC_Country_Text__c = ai.CountryName;
            }

            result.toUpdate.add(addr);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        if (!result.toUpdate.isEmpty()) {
            update result.toUpdate;
        }

        result.dtoList = buildAddressDTOListFromHistory(hist.Id);
        return result;
    }

    private static List<AddressDTO> buildAddressDTOListFromHistory(Id customerHistoryId) {
        List<AddressDTO> outList = new List<AddressDTO>();
        for (FEC_Address_Info__c addr : [
            SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            AddressDTO dto = new AddressDTO();
            dto.addressType = addr.FEC_Address_Type__c;
            dto.address = FEC_CommonUltils.removeTrailingComma(addr.FEC_Full_Address__c);
            dto.mailingAddress = addr.FEC_Mailing_Address__c == true
                ? FEC_ConstantCommon.TEXT_YES
                : null;
            outList.add(dto);
        }
        return outList;
    }

    /**
     * API có thể trả PERMANENT (chuẩn) hoặc PERMNENT (mã nguồn CIF) — cùng một loại địa chỉ thường trú.
     */
    private static String mapApiAddressTypeToSF(String apiType) {
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_CURRES) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_CURRENT;
        }
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_OFFICE) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_OFFICE;
        }
        if (apiType == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT
            || apiType == FEC_ConstantCommon.ADDRESS_TYPE_PERMANENT) {
            return FEC_ConstantCommon.SF_ADDRESS_TYPE_PERMANENT;
        }
        return null;
    }

    /**
     * Khi đồng thời có PERMANENT và PERMNENT, chỉ đồng bộ PERMNENT (nguồn dữ liệu ưu tiên).
     */
    private static List<FEC_GetAddressesList.AddressInfo> filterDuplicatePermanentAddressTypes(
        List<FEC_GetAddressesList.AddressInfo> raw
    ) {
        if (raw == null || raw.isEmpty()) {
            return raw;
        }
        Boolean hasPermnent = false;
        for (FEC_GetAddressesList.AddressInfo ai : raw) {
            if (ai != null && ai.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_PERMNENT) {
                hasPermnent = true;
                break;
            }
        }
        if (!hasPermnent) {
            return raw;
        }
        List<FEC_GetAddressesList.AddressInfo> out = new List<FEC_GetAddressesList.AddressInfo>();
        for (FEC_GetAddressesList.AddressInfo ai : raw) {
            if (ai != null && ai.AddressType == FEC_ConstantCommon.ADDRESS_TYPE_PERMANENT) {
                continue;
            }
            out.add(ai);
        }
        return out;
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