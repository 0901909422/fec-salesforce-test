/****************************************************************************************
 * File Name    : FEC_CustomerIntegrationService.Apex
 * Author       : Quangdv7
 * Date         : 2026-03-30
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-30     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_CustomerIntegrationService {

    /* =====================================================
     * RESULT DTO
     * ===================================================== */
    public class ResultDTO {
        @AuraEnabled public List<FEC_SecondaryController.ReferenceDTO> references;
        @AuraEnabled public List<FEC_SecondaryController.ContactDTO> contacts;

        public ResultDTO() {
            references = new List<FEC_SecondaryController.ReferenceDTO>();
            contacts   = new List<FEC_SecondaryController.ContactDTO>();
        }
    }

    /* =====================================================
     * MAIN METHOD
     * ===================================================== */
    public static ResultDTO syncCustomer(
        FEC_Customer_History__c hist,
        String cifNumber,
        String phone,
        String accountNumber
    ) {

        ResultDTO result = new ResultDTO();

        if (hist == null || String.isBlank(cifNumber)) {
            return result;
        }

        String requestId = String.valueOf(UUID.randomUUID());
        String requestor = FEC_ConstantCommon.REQUESTOR_CRM;
        String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        String timestampZ = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        /* =====================================================
         * PREPARE DATA (NO DML)
         * ===================================================== */
        List<FEC_Contact_List__c> contactInsert = new List<FEC_Contact_List__c>();
        List<FEC_Address_Info__c> addressInsert = new List<FEC_Address_Info__c>();

        /* =====================================================
         * 1. CUSTOMER BASIC (CALLOUT)
         * ===================================================== */
        try {
            FEC_GetCustomerInfoBasic.ResponseWrapper basicRes =
                FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
                    requestId, requestor, timestampZ, cifNumber
                );

            if (basicRes != null && basicRes.CustomerBasicInfo != null) {

                mapBasicInfo(hist, basicRes);

                if (basicRes.CustomerBasicInfo.PreferredContacts != null) {
                    for (FEC_GetCustomerInfoBasic.PreferredContact pc :
                        basicRes.CustomerBasicInfo.PreferredContacts) {

                        if (pc == null || pc.Contact == null) continue;

                        FEC_SecondaryController.ContactDTO dto = mapContactDTO(pc);
                        result.contacts.add(dto);

                        contactInsert.add(new FEC_Contact_List__c(
                            FEC_Customer_History__c   = hist.Id,
                            FEC_Channel__c            = dto.channel,
                            FEC_Communication_Type__c = dto.communicationType,
                            FEC_Contact_String__c     = dto.contactString,
                            FEC_Contact_ID__c         = dto.contactId
                        ));

                        if (dto.channel == FEC_ConstantCommon.EMAIL
                            && String.isBlank(hist.FEC_Email__c)) {
                            hist.FEC_Email__c = dto.contactString;
                        }
                    }
                }
            }

        } catch (Exception e) {
            System.debug('### BASIC ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * 2. DOCUMENT (CALLOUT)
         * ===================================================== */
        try {
            FEC_GetDocumentsList.ResponseWrapper docRes =
                FEC_GetDocumentsList.callGetDocumentsList(
                    requestId, requestor, timestamp, cifNumber
                );

            if (docRes != null && docRes.Documents != null && !docRes.Documents.isEmpty()) {
                hist.FEC_National_ID_Passport_ID__c = docRes.Documents[0].DocumentID;
                hist.FEC_Date_of_Issue__c           = docRes.Documents[0].IssueDate;
                hist.FEC_Place_of_Issue__c          = docRes.Documents[0].IssuePlace;
            }

        } catch (Exception e) {
            System.debug('### DOCUMENT ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * 3. DIGITAL (CALLOUT)
         * ===================================================== */
        try {
            FEC_GetDigitalAccountStatus.ResponseWrapper digitalRes =
                FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
                    requestId, requestor, timestamp, phone, cifNumber
                );

            if (digitalRes != null && digitalRes.DigitalAccounts != null) {
                for (FEC_GetDigitalAccountStatus.DigitalAccountInfo da :
                    digitalRes.DigitalAccounts) {

                    if (da == null) continue;

                    if (da.Type == FEC_ConstantCommon.CHANNEL_ZALO)
                        hist.FEC_Zalo_Follower__c = normalize(da.Status);

                    if (da.Type == FEC_ConstantCommon.CHANNEL_WEBSITE)
                        hist.FEC_Website_Account__c = normalize(da.Status);

                    if (da.Type == FEC_ConstantCommon.CHANNEL_FE_MOBILE_APP)
                        hist.FEC_Mobile_App_Account__c = normalize(da.Status);
                }
            }

        } catch (Exception e) {
            System.debug('### DIGITAL ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * 4. RELATIVES (CALLOUT)
         * ===================================================== */
        try {
            FEC_GetRelativesList.ResponseWrapper relRes =
                FEC_GetRelativesList.callGetRelativesList(
                    requestId, requestor, timestamp, cifNumber
                );

            if (relRes != null && relRes.Relatives != null) {
                for (FEC_GetRelativesList.RelativeInfo r : relRes.Relatives) {
                    result.references.add(mapReferenceDTO(r));
                }
            }

        } catch (Exception e) {
            System.debug('### RELATIVE ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * 5. ADDRESS (CALLOUT ONLY → NO DML HERE)
         * ===================================================== */
        try {
            addressInsert = buildAddressList(
                hist.Id, cifNumber, requestId, requestor, timestamp
            );
        } catch (Exception e) {
            System.debug('### ADDRESS ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * 6. PHONE (CALLOUT)
         * ===================================================== */
        try {
            if (String.isNotBlank(accountNumber)) {
                hist.FEC_Primary_Phone__c = getPrimaryPhone(accountNumber);
            }
        } catch (Exception e) {
            System.debug('### PHONE ERROR: ' + e.getMessage());
        }

        /* =====================================================
         * ===== ALL CALLOUT DONE → NOW DML =====
         * ===================================================== */

        // DELETE OLD CONTACT
        delete [
            SELECT Id FROM FEC_Contact_List__c
            WHERE FEC_Customer_History__c = :hist.Id
        ];

        if (!contactInsert.isEmpty()) insert contactInsert;
        if (!addressInsert.isEmpty()) insert addressInsert;

        update hist;

        return result;
    }

    /* =====================================================
     * ADDRESS BUILD (NO DML)
     * ===================================================== */
    private static List<FEC_Address_Info__c> buildAddressList(
        Id histId,
        String cifNumber,
        String requestId,
        String requestor,
        String timestamp
    ) {
        List<FEC_Address_Info__c> result = new List<FEC_Address_Info__c>();

        FEC_GetAddressesList.ResponseWrapper res =
            FEC_GetAddressesList.callGetAddressesList(
                requestId, requestor, timestamp, cifNumber
            );

        if (res == null || res.Addresses == null) return result;

        for (FEC_GetAddressesList.AddressInfo ai : res.Addresses) {

            String type = mapType(ai.AddressType);
            if (type == null) continue;

            result.add(new FEC_Address_Info__c(
                FEC_Customer_History__c = histId,
                FEC_Address_Type__c = type,
                FEC_Address__c = buildAddress(ai),
                FEC_Mailing_Address__c = 'Yes'
            ));
        }

        return result;
    }

    /* =====================================================
     * MAPPING HELPERS
     * ===================================================== */
    private static void mapBasicInfo(
        FEC_Customer_History__c hist,
        FEC_GetCustomerInfoBasic.ResponseWrapper res
    ) {
        hist.FEC_First_Name__c     = res.CustomerBasicInfo.FirstName;
        hist.FEC_Middle_Name__c    = res.CustomerBasicInfo.MiddleName;
        hist.FEC_Last_Name__c      = res.CustomerBasicInfo.LastName;
        hist.FEC_Customer_Name__c  = res.CustomerBasicInfo.FullName;
        hist.FEC_Date_of_Birth__c  = res.CustomerBasicInfo.Birthday;
        hist.FEC_Gender__c         = res.CustomerBasicInfo.Gender;
        hist.FEC_Marital_Status__c = res.CustomerBasicInfo.MaritalStatus;
        hist.FEC_CIF_Number__c     = res.CustomerBasicInfo.CIFNumber;
    }

    private static FEC_SecondaryController.ContactDTO mapContactDTO(
        FEC_GetCustomerInfoBasic.PreferredContact pc
    ) {
        FEC_SecondaryController.ContactDTO dto =
            new FEC_SecondaryController.ContactDTO();

        dto.channel           = pc.Contact.Channel;
        dto.communicationType = pc.Contact.CommunicationType;
        dto.contactString     = pc.Contact.ContactString;
        dto.contactId         = pc.Contact.ContactId;

        return dto;
    }

    private static FEC_SecondaryController.ReferenceDTO mapReferenceDTO(
        FEC_GetRelativesList.RelativeInfo r
    ) {
        FEC_SecondaryController.ReferenceDTO dto =
            new FEC_SecondaryController.ReferenceDTO();

        dto.fullName     = r.FullName;
        dto.relationship = r.RelationType;
        dto.phoneNumber  = r.PhoneNumber;

        return dto;
    }

    private static String mapType(String t) {
        if (t == 'CURRES') return 'Current Address';
        if (t == 'OFFICE') return 'Office Address';
        if (t == 'PERMNENT') return 'Permanent Address';
        return null;
    }

    private static String buildAddress(FEC_GetAddressesList.AddressInfo a) {
        return String.join(new List<String>{
            a.Building, a.NumberStr, a.Street, a.Ward,
            a.City, a.CountryName
        }, ', ');
    }

    private static String getPrimaryPhone(String accountNumber) {
        FEC_GetCustomerList.ResponseWrapper res =
            FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null, false, null, null, null, null,
                accountNumber, null, null, null
            );

        if (res == null || res.Customers == null) return null;

        for (FEC_GetCustomerList.Customer c : res.Customers)
            for (FEC_GetCustomerList.Phone p : c.Phones)
                if (p.Type == 'Mobile') return p.Phone;

        return null;
    }

    private static String normalize(String val) {
        return FEC_CommonUltils.normalizeInsuranceFlag(val);
    }
}