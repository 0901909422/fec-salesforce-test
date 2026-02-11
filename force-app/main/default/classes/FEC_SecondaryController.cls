public with sharing class FEC_SecondaryController {

    /* =====================================================
     * DTOs
     * ===================================================== */

    public class ReferenceDTO {
        @AuraEnabled public String fullName;
        @AuraEnabled public String relationship;
        @AuraEnabled public String phoneNumber;
    }

    public class SecondaryInfoDTO {
        @AuraEnabled public String zaloFollower;
        @AuraEnabled public String websiteAccount;
        @AuraEnabled public String mobileAppAccount;
        @AuraEnabled public String email;
        @AuraEnabled public String workPhone;
        @AuraEnabled public List<ReferenceDTO> references;
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
                   FEC_Zalo_Follower__c,
                   FEC_Website_Account__c,
                   FEC_Mobile_App_Account__c,
                   FEC_Email__c,
                   FEC_Work_Phone__c,
                   FEC_API_Cache_Secondary_Demo__c,
                   FEC_CIF_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        /* =====================================================
         * CACHE HIT → KHÔNG CALL API
         * ===================================================== */
        if (String.isNotBlank(hist.FEC_API_Cache_Secondary_Demo__c)) {
            return (SecondaryInfoDTO) JSON.deserialize(
                hist.FEC_API_Cache_Secondary_Demo__c,
                SecondaryInfoDTO.class
            );
        }

        /* =====================================================
         * CALL APIs
         * ===================================================== */

        /* ---------- 1. DIGITAL ACCOUNT STATUS ---------- */
        try {
            FEC_GetDigitalAccountStatus.ResponseWrapper digitalRes =
                FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
                    FEC_ConstantCommon.REQUESTOR_APS,
                    FEC_ConstantCommon.REQUESTOR_PORTAL,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_Work_Phone__c,
                    hist.FEC_CIF_Number__c
                );

            if (digitalRes != null && digitalRes.DigitalAccounts != null) {
                hist.FEC_Zalo_Follower__c =
                    getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_ZALO);

                hist.FEC_Website_Account__c =
                    getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_WEBSITE);

                hist.FEC_Mobile_App_Account__c =
                    getStatusByType(digitalRes.DigitalAccounts, FEC_ConstantCommon.CHANNEL_FE_MOBILE_APP);
            }
        } catch (Exception e) {
            System.debug('### DigitalAccountStatus FAILED: ' + e.getMessage());
        }

        /* ---------- 2. CONTACT LIST ---------- */
        try {
            FEC_GetContactsList.ResponseWrapper contactRes =
                FEC_GetContactsList.callGetContactsList(
                    FEC_ConstantCommon.REQUESTOR_APS,
                    FEC_ConstantCommon.REQUESTOR_PORTAL,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_CIF_Number__c
                );

            if (contactRes != null && contactRes.Contacts != null) {
                hist.FEC_Email__c      = extractEmail(contactRes.Contacts);
                hist.FEC_Work_Phone__c = extractWorkPhone(contactRes.Contacts);
            }
        } catch (Exception e) {
            System.debug('### GetContactsList FAILED: ' + e.getMessage());
        }

        /* ---------- 3. RELATIVES LIST ---------- */
        FEC_GetRelativesList.ResponseWrapper relativesRes;
        try {
            relativesRes =
                FEC_GetRelativesList.callGetRelativesList(
                    FEC_ConstantCommon.REQUESTOR_APS,
                    FEC_ConstantCommon.REQUESTOR_PORTAL,
                    Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                    hist.FEC_CIF_Number__c
                );
        } catch (Exception e) {
            System.debug('### GetRelativesList FAILED: ' + e.getMessage());
        }

        /* =====================================================
         * BUILD DTO
         * ===================================================== */
        SecondaryInfoDTO dto = mapToDTO(hist);
        dto.references = buildReferenceDTO(relativesRes);

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

    private static SecondaryInfoDTO mapToDTO(
        FEC_Customer_History__c h
    ) {
        SecondaryInfoDTO dto = new SecondaryInfoDTO();
        dto.zaloFollower     = h.FEC_Zalo_Follower__c;
        dto.websiteAccount   = h.FEC_Website_Account__c;
        dto.mobileAppAccount = h.FEC_Mobile_App_Account__c;
        dto.email            = h.FEC_Email__c;
        dto.workPhone        = h.FEC_Work_Phone__c;
        return dto;
    }
}