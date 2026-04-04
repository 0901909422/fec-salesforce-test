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
    }

    public class AddressDTO {
        @AuraEnabled public String addressType;
        @AuraEnabled public String address;
        @AuraEnabled public String mailingAddress;
    }

    private class AddressUpdateResult {
        List<FEC_Address_Info__c> toUpdate = new List<FEC_Address_Info__c>();
        List<AddressDTO> dtoList = new List<AddressDTO>();
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
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        String accountNumber;
        String cifNumber;
        FEC_Customer_History__c hist;
        /* ===== LOAD CUSTOMER HISTORY ===== */
        if (c.FEC_Account_or_Contract__c != null) {
            hist = [
                SELECT Id,
                    FEC_Account_Number__c,
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

            accountNumber = hist.FEC_Account_Number__c;
            cifNumber = hist.FEC_CIF_Number__c;
        }
        /* ===== CACHE HIT ===== */
        if (String.isNotBlank(hist.FEC_API_Cache__c)) {
            return (MainInfoDTO) JSON.deserialize(
                hist.FEC_API_Cache__c,
                MainInfoDTO.class
            );
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
        hist.FEC_API_Cache__c = JSON.serialize(dto);
        update hist;
        return dto;
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

    /* ================= HELPER METHODS ================= */

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
        FEC_GetAddressesList.ResponseWrapper res =
            FEC_GetAddressesList.callGetAddressesList(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                cifNumber
            );

        if (res == null || res.Addresses == null) return result;

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
        for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {

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
            addr.FEC_Mailing_Address__c = FEC_ConstantCommon.TEXT_YES;

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

        /* ===== RE-QUERY GET FORMULA ===== */
        List<FEC_Address_Info__c> refreshed = [
            SELECT Id, FEC_Address_Type__c, FEC_Full_Address__c, FEC_Mailing_Address__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
        ];

        /* ===== DTO ===== */
        for (FEC_Address_Info__c addr : refreshed) {
            AddressDTO dto = new AddressDTO();
            dto.addressType = addr.FEC_Address_Type__c;
            dto.address = FEC_CommonUltils.removeTrailingComma(addr.FEC_Full_Address__c);
            dto.mailingAddress = addr.FEC_Mailing_Address__c;
            result.dtoList.add(dto);
        }

        return result;
    }

    private static String mapApiAddressTypeToSF(String apiType) {
        if (apiType == 'CURRES') return 'Current Address';
        if (apiType == 'OFFICE') return 'Office Address';
        if (apiType == 'PERMNENT') return 'Permanent Address';
        return null;
    }

    private static String buildFullAddress(FEC_GetAddressesList.AddressInfo a, Map<String,String> cityMap, Map<String,String> districtMap) {
        String cityName = (a.City != null && cityMap.containsKey(a.City)) ? cityMap.get(a.City) : a.City;
        String districtName = (a.District!= null && districtMap.containsKey(a.District)) ? districtMap.get(a.District) : a.District;

        return FEC_CommonUltils.formatAddress(
            a.Building,
            a.NumberStr,
            a.Street,
            a.Ward,
            districtName,
            cityName,
            a.CountryName,
            a.ZipCode
        );
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