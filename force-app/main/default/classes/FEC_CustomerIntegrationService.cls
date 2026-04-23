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
    }

    public static ResultDTO syncCustomer(
        FEC_Customer_History__c hist,
        String cifNumber,
        String phone,
        String accountNumber
    ) {
        ResultDTO result = new ResultDTO();

        if (hist == null || String.isBlank(cifNumber)) return result;

        String requestId = String.valueOf(UUID.randomUUID());
        String requestor = FEC_ConstantCommon.REQUESTOR_CRM;
        String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        String timestampZ = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        try {
            FEC_GetCustomerInfoBasic.ResponseWrapper basicRes =
                FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(requestId, requestor, timestampZ, cifNumber);

            if (basicRes != null && basicRes.CustomerBasicInfo != null) {
                hist.FEC_First_Name__c     = basicRes.CustomerBasicInfo.FirstName;
                hist.FEC_Middle_Name__c    = basicRes.CustomerBasicInfo.MiddleName;
                hist.FEC_Last_Name__c      = basicRes.CustomerBasicInfo.LastName;
                hist.FEC_Customer_Name__c  = basicRes.CustomerBasicInfo.FullName;
                hist.FEC_Date_of_Birth__c  = basicRes.CustomerBasicInfo.Birthday;
                hist.FEC_Gender__c         = basicRes.CustomerBasicInfo.Gender;
                hist.FEC_CIF_Number__c     = basicRes.CustomerBasicInfo.CIFNumber;

                result.customerName = basicRes.CustomerBasicInfo.FullName;
                result.nationalId = hist.FEC_National_ID_Passport_ID__c;
                result.gender = basicRes.CustomerBasicInfo.Gender;
                result.dateOfBirth = basicRes.CustomerBasicInfo.Birthday;

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

        // 2. PRIMARY PHONE
        try {
            if (String.isNotBlank(accountNumber)) {
                hist.FEC_Primary_Phone__c = getPrimaryPhone(accountNumber);
                result.primaryPhone = hist.FEC_Primary_Phone__c;
            }
        } catch (Exception e) {
            System.debug('### PHONE ERROR: ' + e.getMessage());
        }

        return result;
    }

    private static String getPrimaryPhone(String accountNumber) {
        FEC_GetCustomerList.ResponseWrapper res =
            FEC_GetCustomerList.getCustomerList(FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN, null, false, null, null, null, null, accountNumber, null, null, null);

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