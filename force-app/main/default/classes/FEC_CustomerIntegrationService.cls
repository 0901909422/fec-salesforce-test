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
    public class ResultDTO {
        @AuraEnabled public String customerName;
        @AuraEnabled public String nationalId;
        @AuraEnabled public String gender;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String primaryPhone;
        @AuraEnabled public String emailAddress;
        @AuraEnabled public String plasticID;
    }

    public static FEC_Customer_History__c queryHistoryForSync(Id historyId) {
        return [
            SELECT Id,
                   FEC_CIF_Number__c,
                   FEC_Account_Number__c,
                   FEC_Contract_Number__c,
                   FEC_Email__c,
                   FEC_Primary_Phone__c,
                   FEC_Customer_Name__c,
                   FEC_Date_of_Birth__c,
                   FEC_Gender__c,
                   FEC_National_ID_Passport_ID__c,
                   FEC_Plastic_ID__c
            FROM FEC_Customer_History__c
            WHERE Id = :historyId
            LIMIT 1
        ];
    }

    public static ResultDTO syncCustomer(
        FEC_Customer_History__c hist,
        String cifNumber,
        String phone,
        String accountNumber
    ) {
        ResultDTO result = new ResultDTO();

        if (hist == null) {
            return result;
        }

        String acctNum = String.isNotBlank(hist.FEC_Account_Number__c)
            ? hist.FEC_Account_Number__c
            : null;
        String contractNum = String.isNotBlank(hist.FEC_Contract_Number__c)
            ? hist.FEC_Contract_Number__c
            : null;
        if (String.isBlank(acctNum) && String.isBlank(contractNum) && String.isNotBlank(accountNumber)) {
            acctNum = accountNumber;
        }

        String effectiveCif = String.isNotBlank(cifNumber)
            ? cifNumber
            : hist.FEC_CIF_Number__c;

        if (String.isNotBlank(acctNum) || String.isNotBlank(contractNum)) {
            String cifFromList = enrichFromCustomerList(hist, result, acctNum, contractNum);
            if (String.isNotBlank(cifFromList)) {
                effectiveCif = cifFromList;
            }
        }

        if (String.isBlank(effectiveCif)) {
            return result;
        }

        String requestId = String.valueOf(UUID.randomUUID());
        String requestor = FEC_ConstantCommon.REQUESTOR_CRM;
        String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        String timestampZ = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        // 1. BASIC INFO
        try {
            FEC_GetCustomerInfoBasic.ResponseWrapper basicRes =
                FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(requestId, requestor, timestampZ, effectiveCif);

            if (basicRes != null && basicRes.CustomerBasicInfo != null) {

                result.customerName = basicRes.CustomerBasicInfo.FullName;
                result.gender = basicRes.CustomerBasicInfo.Gender;
                result.dateOfBirth = basicRes.CustomerBasicInfo.Birthday;

                // Lấy email & preferred contacts
                if (basicRes.CustomerBasicInfo.PreferredContacts != null) {
                    for (FEC_GetCustomerInfoBasic.PreferredContact pc : basicRes.CustomerBasicInfo.PreferredContacts) {
                        if (pc == null || pc.Contact == null) continue;

                        if (pc.Contact.Channel == FEC_ConstantCommon.EMAIL && String.isBlank(hist.FEC_Email__c)) {
                            hist.FEC_Email__c = pc.Contact.ContactString;
                            result.emailAddress = pc.Contact.ContactString;
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('### BASIC ERROR: ' + e.getMessage());
        }

        // 1.5. CONTACTS LIST
        try {
            FEC_GetContactsList.ResponseWrapper contactsRes =
                FEC_GetContactsList.callGetContactsList(requestId, requestor, timestampZ, effectiveCif);

            if (contactsRes != null && contactsRes.Contacts != null) {
                saveContactsListFromApi(hist, contactsRes.Contacts);
            }
        } catch (Exception e) {
            System.debug('### CONTACTS LIST ERROR: ' + e.getMessage());
        }

        // 2. DOCUMENT
        try {
            FEC_GetDocumentsList.ResponseWrapper docRes =
                FEC_GetDocumentsList.callGetDocumentsList(requestId, requestor, timestamp, effectiveCif);

            if (docRes != null && docRes.Documents != null && !docRes.Documents.isEmpty()) {
                hist.FEC_National_ID_Passport_ID__c = docRes.Documents[0].DocumentID;

                result.nationalId = docRes.Documents[0].DocumentID;
            }
        } catch (Exception e) {
            System.debug('### DOCUMENT ERROR: ' + e.getMessage());
        }

        // 3. PRIMARY PHONE 
        try {
            if (String.isBlank(result.primaryPhone) && (String.isNotBlank(acctNum) || String.isNotBlank(contractNum))) {
                String mobilePhone = getPrimaryPhone(acctNum, contractNum);
                if (String.isNotBlank(mobilePhone)) {
                    hist.FEC_Primary_Phone__c = mobilePhone;
                    result.primaryPhone = mobilePhone;
                }
            }
        } catch (Exception e) {
            System.debug('### PHONE ERROR: ' + e.getMessage());
        }

        // 4. plasticID
        String cardAccountNumber = String.isNotBlank(acctNum) ? acctNum : accountNumber;
        try {
             FEC_GetCardBasicInfo.ResponseWrapper cardRes = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                cardAccountNumber
            );

            if (cardRes != null 
                && cardRes.CardBasicInfo != null 
                && cardRes.CardBasicInfo.MainCard != null) {

                result.plasticID = cardRes.CardBasicInfo.MainCard.PlasticIndicator;

                hist.FEC_Plastic_ID__c = result.plasticID;
            }

        } catch (Exception e) {
            System.debug(System.Label.FEC_MSG_API_Error + e.getMessage());
        }

        return result;
    }

    private static String enrichFromCustomerList(
        FEC_Customer_History__c hist,
        ResultDTO result,
        String accountNumber,
        String contractNumber
    ) {
        FEC_GetCustomerList.ResponseWrapper res = callGetCustomerList(accountNumber, contractNumber);
        if (res == null || res.Customers == null || res.Customers.isEmpty()) {
            return null;
        }

        FEC_GetCustomerList.Customer customer = res.Customers[0];

        if (String.isNotBlank(customer.CIFNumber)) {
            hist.FEC_CIF_Number__c = customer.CIFNumber;
        }
        if (String.isNotBlank(customer.FullName)) {
            hist.FEC_Customer_Name__c = customer.FullName;
            result.customerName = customer.FullName;
        }
        if (String.isNotBlank(customer.NationalID)) {
            hist.FEC_National_ID_Passport_ID__c = customer.NationalID;
            result.nationalId = customer.NationalID;
        }
        if (customer.DateOfBirth != null) {
            hist.FEC_Date_of_Birth__c = customer.DateOfBirth;
            result.dateOfBirth = customer.DateOfBirth;
        }

        String mobilePhone = extractMobilePhone(customer);
        if (String.isNotBlank(mobilePhone)) {
            hist.FEC_Primary_Phone__c = mobilePhone;
            result.primaryPhone = mobilePhone;
        }

        if (customer.Emails != null && !customer.Emails.isEmpty()) {
            for (FEC_GetCustomerList.EmailInfo em : customer.Emails) {
                if (em != null && String.isNotBlank(em.Email)) {
                    hist.FEC_Email__c = em.Email;
                    result.emailAddress = em.Email;
                    break;
                }
            }
        }

        return customer.CIFNumber;
    }

    private static void saveContactsListFromApi(
        FEC_Customer_History__c hist,
        List<FEC_GetContactsList.ContactInfo> contacts
    ) {
        if (hist == null || contacts == null || contacts.isEmpty()) {
            return;
        }

        List<FEC_Contact_List__c> contactsToInsert = new List<FEC_Contact_List__c>();

        for (FEC_GetContactsList.ContactInfo c : contacts) {
            if (!isPhoneOrEmailChannelContact(c)) {
                continue;
            }

            contactsToInsert.add(new FEC_Contact_List__c(
                FEC_Customer_History__c   = hist.Id,
                FEC_Channel__c            = c.Channel,
                FEC_Communication_Type__c = c.CommunicationType,
                FEC_Contact_String__c     = c.ContactString,
                FEC_Contact_ID__c         = c.ContactId
            ));
        }

        if (contactsToInsert.isEmpty()) {
            return;
        }

        deleteExistingPhoneEmailContacts(hist.Id);
        insert contactsToInsert;
    }

    private static Boolean isPhoneOrEmailChannelContact(FEC_GetContactsList.ContactInfo c) {
        return c != null
            && String.isNotBlank(c.ContactString)
            && (c.Channel == FEC_ConstantCommon.EMAIL
                || c.Channel == FEC_ConstantCommon.PHONE);
    }

    private static void deleteExistingPhoneEmailContacts(Id customerHistoryId) {
        if (customerHistoryId == null) {
            return;
        }

        List<FEC_Contact_List__c> existing = [
            SELECT Id
            FROM FEC_Contact_List__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Channel__c IN (
                  :FEC_ConstantCommon.EMAIL,
                  :FEC_ConstantCommon.PHONE
              )
        ];

        if (!existing.isEmpty()) {
            delete existing;
        }
    }

    private static FEC_GetCustomerList.ResponseWrapper callGetCustomerList(
        String accountNumber,
        String contractNumber
    ) {
        if (String.isNotBlank(contractNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null,
                false,
                null,
                null,
                null,
                null,
                null,
                contractNumber,
                null,
                null
            );
        }
        if (String.isNotBlank(accountNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                null,
                false,
                null,
                null,
                null,
                null,
                accountNumber,
                null,
                null,
                null
            );
        }
        return null;
    }

    private static String extractMobilePhone(FEC_GetCustomerList.Customer customer) {
        if (customer == null || customer.Phones == null) {
            return null;
        }
        for (FEC_GetCustomerList.Phone p : customer.Phones) {
            if (p != null && p.Type == 'Mobile' && String.isNotBlank(p.Phone)) {
                return p.Phone;
            }
        }
        return null;
    }

    private static String getPrimaryPhone(String accountNumber, String contractNumber) {
        FEC_GetCustomerList.ResponseWrapper res = callGetCustomerList(accountNumber, contractNumber);
        if (res == null || res.Customers == null) {
            return null;
        }
        for (FEC_GetCustomerList.Customer c : res.Customers) {
            String phone = extractMobilePhone(c);
            if (String.isNotBlank(phone)) {
                return phone;
            }
        }
        return null;
    }

    private static String normalize(String val) {
        return FEC_CommonUltils.normalizeInsuranceFlag(val);
    }
}