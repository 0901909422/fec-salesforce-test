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

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        /* ===== LOAD CUSTOMER HISTORY ===== */
        FEC_Customer_History__c hist = [
            SELECT Id,
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
                    FEC_ConstantCommon.REQUESTOR_APS,
                    FEC_ConstantCommon.REQUESTOR_PORTAL,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_CIF_Number__c
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
                    FEC_ConstantCommon.REQUESTOR_APS,
                    FEC_ConstantCommon.REQUESTOR_PORTAL,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_CIF_Number__c
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
            hist.FEC_Primary_Phone__c = getPrimaryPhoneOnly(hist);
        } catch (Exception e) {
            System.debug('### GetCustomerList FAILED: ' + e.getMessage());
        }

        /* ===== 4. GetAddressesList ===== */
        AddressUpdateResult addrResult = new AddressUpdateResult();
        try {
            addrResult = updateAddressesFromApi(hist);
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

    private static String getPrimaryPhoneOnly (FEC_Customer_History__c hist) {
        FEC_GetCustomerList.ResponseWrapper res =
            FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN, null, false,
                null, null, null, null,hist.FEC_Account_Number__c, null, null, null
            );

        if (res == null) return null;

        for (FEC_GetCustomerList.Customer c : res.Customers)
            for (FEC_GetCustomerList.Phone p : c.Phones)
                if (p.Type == 'Mobile') return p.Phone;

        return null;
    }

    private static AddressUpdateResult updateAddressesFromApi(
        FEC_Customer_History__c hist
    ) {
        AddressUpdateResult result = new AddressUpdateResult();
        FEC_GetAddressesList.ResponseWrapper res =
            FEC_GetAddressesList.callGetAddressesList(
                FEC_ConstantCommon.REQUESTOR_APS,FEC_ConstantCommon.REQUESTOR_PORTAL,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                hist.FEC_CIF_Number__c
            );

        if (res == null || res.Addresses == null) return result;

        Map<String, FEC_Address_Info__c> existingMap = new Map<String, FEC_Address_Info__c>();
        for (FEC_Address_Info__c a : [
            SELECT Id, FEC_Address_Type__c
            FROM FEC_Address_Info__c
            WHERE FEC_Customer_History__c = :hist.Id
        ]) {
            existingMap.put(a.FEC_Address_Type__c, a);
        }

        List<FEC_Address_Info__c> toInsert = new List<FEC_Address_Info__c>();

        for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {
            String type = mapApiAddressTypeToSF(ai.AddressType);
            if (String.isBlank(type)) continue;

            FEC_Address_Info__c addr;

            if (existingMap.containsKey(type)) {
                addr = existingMap.get(type);
            }
            else {
                addr = new FEC_Address_Info__c();
                addr.FEC_Customer_History__c = hist.Id;
                addr.FEC_Address_Type__c = type;
                toInsert.add(addr);
            }

            addr.FEC_Address__c = buildFullAddress(ai);
            addr.FEC_Mailing_Address__c = FEC_ConstantCommon.TEXT_YES;

            result.toUpdate.add(addr);

            AddressDTO dto = new AddressDTO();
            dto.addressType = type;
            dto.address = addr.FEC_Address__c;
            dto.mailingAddress = FEC_ConstantCommon.TEXT_YES;
            result.dtoList.add(dto);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        return result;
    }

    private static String mapApiAddressTypeToSF(String apiType) {
        if (apiType == 'CURRES') return 'Current Address';
        if (apiType == 'OFFICE') return 'Office Address';
        if (apiType == 'PERMENT') return 'Permanent Address';
        return null;
    }

    private static String buildFullAddress(FEC_GetAddressesList.AddressInfo a) {
        return String.join(new List<String>{
            a.NumberStr, a.Building, a.Street,
            a.Ward, a.District, a.City,
            a.CountryName, a.ZipCode
        }, ', ');
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