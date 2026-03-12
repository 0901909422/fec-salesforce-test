/****************************************************************************************
 * File Name    : FEC_SecondaryController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_SecondaryController {

    /* =====================================================
     * DTOs
     * ===================================================== */

    public class ReferenceDTO {
        @AuraEnabled public String fullName;
        @AuraEnabled public String relationship;
        @AuraEnabled public String phoneNumber;
    }

    public class ContactDTO {
        @AuraEnabled public String channel;
        @AuraEnabled public String communicationType;
        @AuraEnabled public String contactString;
        @AuraEnabled public String contactId;
    }

    public class SecondaryInfoDTO {
        @AuraEnabled public String zaloFollower;
        @AuraEnabled public String websiteAccount;
        @AuraEnabled public String mobileAppAccount;
        @AuraEnabled public List<ContactDTO> contactList;
        @AuraEnabled public List<ReferenceDTO> references;
        @AuraEnabled public Map<String, String> helpTexts;
    }

    /* =====================================================
     * MAIN METHOD
     * ===================================================== */
    @AuraEnabled(cacheable=false)
    public static SecondaryInfoDTO loadSecondaryInfo(Id caseId) {

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
                    FEC_CIF_Number__c,
                   FEC_Zalo_Follower__c,
                   FEC_Website_Account__c,
                   FEC_Mobile_App_Account__c,
                   FEC_API_Cache_Secondary_Demo__c,
                   FEC_Work_Phone__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        /* =====================================================
         * CACHE HIT 
         * ===================================================== */
        if (String.isNotBlank(hist.FEC_API_Cache_Secondary_Demo__c)) {
            SecondaryInfoDTO dto =
                (SecondaryInfoDTO) JSON.deserialize(
                    hist.FEC_API_Cache_Secondary_Demo__c,
                    SecondaryInfoDTO.class
                );

            dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);

            return dto;
        }

        /* =====================================================
         * CALL APIs
         * ===================================================== */

        /* ---------- 1. DIGITAL ACCOUNT STATUS ---------- */
        try {
            FEC_GetDigitalAccountStatus.ResponseWrapper digitalRes =
                FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_Work_Phone__c,
                    hist.FEC_CIF_Number__c
                );

            if (digitalRes != null && digitalRes.DigitalAccounts != null) {
                hist.FEC_Zalo_Follower__c =
                    FEC_CommonUltils.normalizeInsuranceFlag(getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_ZALO));

                hist.FEC_Website_Account__c =
                    FEC_CommonUltils.normalizeInsuranceFlag(getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_WEBSITE));

                hist.FEC_Mobile_App_Account__c =
                    FEC_CommonUltils.normalizeInsuranceFlag(getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_FE_MOBILE_APP));
            }
        } catch (Exception e) {
            System.debug('### DigitalAccountStatus FAILED: ' + e.getMessage());
        }

        /* ---------- 2. CONTACT LIST ---------- */
         List<FEC_Contact_List__c> contactsToInsert = new List<FEC_Contact_List__c>();

        try {
            FEC_GetCustomerInfoBasic.ResponseWrapper contactRes =
                FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z),
                    hist.FEC_CIF_Number__c
                );

            if (contactRes != null
                && contactRes.CustomerBasicInfo != null
                && contactRes.CustomerBasicInfo.PreferredContacts != null
            ) {
                for (FEC_GetCustomerInfoBasic.PreferredContact pc :
                    contactRes.CustomerBasicInfo.PreferredContacts) {

                    if (pc == null || pc.Contact == null) continue;

                    contactsToInsert.add(new FEC_Contact_List__c(
                        FEC_Customer_History__c   = hist.Id,
                        FEC_Channel__c            = pc.Contact.Channel,
                        FEC_Communication_Type__c = pc.Contact.CommunicationType,
                        FEC_Contact_String__c     = pc.Contact.ContactString,
                        FEC_Contact_ID__c         = pc.Contact.ContactId
                    ));
                }
            }
        } catch (Exception e) {
            System.debug('### GetContactsList FAILED: ' + e.getMessage());
        }

        /* ---------- 3. RELATIVES LIST ---------- */
        FEC_GetRelativesList.ResponseWrapper relativesRes;
        try {
            relativesRes =
                FEC_GetRelativesList.callGetRelativesList(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_CIF_Number__c
                );
        } catch (Exception e) {
            System.debug('### GetRelativesList FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BUILD DTO
         * ===================================================== */
         if (!contactsToInsert.isEmpty()) {
            insert contactsToInsert;
        }
        SecondaryInfoDTO dto = mapToDTO(hist);
        dto.references = buildReferenceDTO(relativesRes);
        dto.contactList = buildContactDTO(hist.Id);
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType);

        /* =====================================================
         * SAVE CACHE
         * ===================================================== */
        hist.FEC_API_Cache_Secondary_Demo__c = JSON.serialize(dto);
        update hist;

        return dto;
    }

    /* =====================================================
     * LOG SENSITIVE
     * ===================================================== */
    @AuraEnabled
    public static void logSensitiveFromSecondaryInfo(
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
     * HELPER METHODS 
     * ===================================================== */

    private static String getStatusByType(
        List<FEC_GetDigitalAccountStatus.DigitalAccountInfo> accounts,
        String type
    ) {
        if (accounts == null || String.isBlank(type)) return null;

        for (FEC_GetDigitalAccountStatus.DigitalAccountInfo da : accounts) {
            if (da != null && type.equals(da.Type)) {
                return da.Status;
            }
        }
        return null;
    }

    private static String extractEmail(
        List<FEC_GetContactsList.ContactInfo> contacts
    ) {
        for (FEC_GetContactsList.ContactInfo c : contacts) {
            if (c != null && c.Channel == 'Email') {
                return c.ContactString;
            }
        }
        return null;
    }

    private static String extractWorkPhone(
        List<FEC_GetContactsList.ContactInfo> contacts
    ) {
        for (FEC_GetContactsList.ContactInfo c : contacts) {
            if (c != null && c.Channel == 'Phone'
                && c.CommunicationType == 'Work') {
                return c.ContactString;
            }
        }
        return null;
    }
    
    private static List<ReferenceDTO> buildReferenceDTO(
        FEC_GetRelativesList.ResponseWrapper res
    ) {
        List<ReferenceDTO> result = new List<ReferenceDTO>();
        if (res == null || res.Relatives == null) return result;

        for (FEC_GetRelativesList.RelativeInfo ri : res.Relatives) {
            ReferenceDTO dto = new ReferenceDTO();
            dto.fullName     = ri.FullName;
            dto.relationship = ri.RelationType;
            dto.phoneNumber  = ri.PhoneNumber;
            result.add(dto);
        }
        return result;
    }

   private static List<ContactDTO> buildContactDTO(Id customerHistoryId) {

        List<ContactDTO> result = new List<ContactDTO>();

        if (customerHistoryId == null) {
            return result;
        }

        List<FEC_Contact_List__c> contactRecords = [
            SELECT FEC_Channel__c,
                FEC_Communication_Type__c,
                FEC_Contact_String__c,
                FEC_Contact_ID__c
            FROM FEC_Contact_List__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];

        for (FEC_Contact_List__c c : contactRecords) {
            ContactDTO dto = new ContactDTO();
            dto.channel = c.FEC_Channel__c;
            dto.communicationType = c.FEC_Communication_Type__c;
            dto.contactString = c.FEC_Contact_String__c;
            dto.contactId = c.FEC_Contact_ID__c;
            result.add(dto);
        }

        return result;
    }

    private static SecondaryInfoDTO mapToDTO(
        FEC_Customer_History__c h
    ) {
        SecondaryInfoDTO dto = new SecondaryInfoDTO();
        dto.zaloFollower     = h.FEC_Zalo_Follower__c;
        dto.websiteAccount   = h.FEC_Website_Account__c;
        dto.mobileAppAccount = h.FEC_Mobile_App_Account__c;
        return dto;
    }
}