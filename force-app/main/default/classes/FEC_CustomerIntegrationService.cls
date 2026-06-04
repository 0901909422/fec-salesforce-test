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

public without sharing class FEC_CustomerIntegrationService {
    private static final String ADDR_COUNTRY_MASTER_LEGACY = '1';
    private static final String ADDR_COUNTRY_MASTER_API = '2';

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
                   FEC_Plastic_ID__c,
                   FEC_Case__c,
                   FEC_Case__r.FEC_Product_Type__r.FEC_Code__c
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

        String requestor = FEC_ConstantCommon.REQUESTOR_CRM;
        String timestamp = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        String timestampZ = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        FEC_GetCustomerInfoBasic.ResponseWrapper basicRes;
        FEC_GetContactsList.ResponseWrapper contactsRes;
        FEC_GetAddressesList.ResponseWrapper addressesRes;
        FEC_GetDocumentsList.ResponseWrapper docRes;
        FEC_GetCardBasicInfo.ResponseWrapper cardRes;
        FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper authRes;
        FEC_GetCardPlanInfo.CardPlanResult cardPlanRes;
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes;
        FEC_GetLoanBasicInfo.ResponseWrapper loanRes;
        FEC_GetMRCInfo.MRCInfoResult mrcRes;
        List<FEC_IPP__c> ippToInsert = new List<FEC_IPP__c>();

        try {
            basicRes = FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
                FEC_CommonUltils.generateTransactionId(),
                requestor,
                timestampZ,
                effectiveCif
            );
        } catch (Exception e) {
            System.debug('### BASIC CALLOUT ERROR: ' + e.getMessage());
        }

        try {
            contactsRes = FEC_GetContactsList.callGetContactsList(
                FEC_CommonUltils.generateTransactionId(),
                requestor,
                timestampZ,
                effectiveCif
            );
        } catch (Exception e) {
            System.debug('### CONTACTS LIST CALLOUT ERROR: ' + e.getMessage());
        }

        try {
            addressesRes = FEC_GetAddressesList.callGetAddressesList(
                FEC_CommonUltils.generateTransactionId(),
                requestor,
                Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT),
                effectiveCif
            );
        } catch (Exception e) {
            System.debug('### ADDRESSES LIST CALLOUT ERROR: ' + e.getMessage());
        }

        try {
            docRes = FEC_GetDocumentsList.callGetDocumentsList(
                FEC_CommonUltils.generateTransactionId(),
                requestor,
                timestamp,
                effectiveCif
            );
        } catch (Exception e) {
            System.debug('### DOCUMENT CALLOUT ERROR: ' + e.getMessage());
        }

        try {
            if (String.isBlank(result.primaryPhone)
                && (String.isNotBlank(acctNum) || String.isNotBlank(contractNum))) {
                String mobilePhone = getPrimaryPhone(acctNum, contractNum);
                if (String.isNotBlank(mobilePhone)) {
                    hist.FEC_Primary_Phone__c = mobilePhone;
                    result.primaryPhone = mobilePhone;
                }
            }
        } catch (Exception e) {
            System.debug('### PHONE CALLOUT ERROR: ' + e.getMessage());
        }

        if (isCardInteractionProductType(hist)) {
            String cardAccountNumber = String.isNotBlank(acctNum) ? acctNum : accountNumber;
            if (String.isNotBlank(cardAccountNumber)) {
                try {
                    cardRes = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                        cardAccountNumber
                    );
                } catch (Exception e) {
                    System.debug('### CARD BASIC CALLOUT ERROR: ' + e.getMessage());
                }

                try {
                    authRes = FEC_MFASOUTSTANDINGAUTHINQ.callService(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                        FEC_ConstantCommon.VMX_VERSION_DEFAULT,
                        FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                        FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                        FEC_ConstantCommon.REQUESTOR_ORG,
                        cardAccountNumber
                    );
                } catch (Exception e) {
                    System.debug('### OUTSTANDING AUTH CALLOUT ERROR: ' + e.getMessage());
                }

                try {
                    cardSecRes = FEC_GetCardSecInfo.getCardSecInfo(cardAccountNumber);
                } catch (Exception e) {
                    System.debug('### CARD SEC CALLOUT ERROR: ' + e.getMessage());
                }

                try {
                    cardPlanRes = FEC_GetCardPlanInfo.getCardPlanInfo(cardAccountNumber);
                } catch (Exception e) {
                    System.debug('### CARD PLAN CALLOUT ERROR: ' + e.getMessage());
                }

                try {
                    ippToInsert = buildIppRecordsFromThreeApis(
                        hist,
                        cardAccountNumber,
                        cardSecRes,
                        cardPlanRes
                    );
                } catch (Exception e) {
                    System.debug('### IPP BUILD ERROR: ' + e.getMessage());
                }
            }
        }

        if (isLoanInteractionProductType(hist)) {
            String loanContractNumber = String.isNotBlank(contractNum)
                ? contractNum
                : hist.FEC_Contract_Number__c;
            if (String.isNotBlank(loanContractNumber)) {
                try {
                    loanRes = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                        FEC_CommonUltils.generateTransactionId(),
                        FEC_ConstantCommon.REQUESTOR_CRM,
                        Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                        loanContractNumber
                    );
                } catch (Exception e) {
                    System.debug('### LOAN BASIC CALLOUT ERROR: ' + e.getMessage());
                }

                try {
                    FEC_GetMRCInfo.MRCInfoRequest mrcReq = new FEC_GetMRCInfo.MRCInfoRequest();
                    mrcReq.ContractNumber = loanContractNumber;
                    mrcRes = FEC_GetMRCInfo.getMRCInfo(mrcReq);
                } catch (Exception e) {
                    System.debug('### MRC CALLOUT ERROR: ' + e.getMessage());
                }
            }
        }

        try {
            applyCustomerInfoBasicFromApi(hist, result, basicRes);
        } catch (Exception e) {
            System.debug('### BASIC APPLY ERROR: ' + e.getMessage());
        }

        try {
            if (contactsRes != null && contactsRes.Contacts != null) {
                saveContactsListFromApi(hist, contactsRes.Contacts);
            }
        } catch (Exception e) {
            System.debug('### CONTACTS LIST DML ERROR: ' + e.getMessage());
        }

        try {
            if (addressesRes != null && addressesRes.Addresses != null) {
                applyAddressesListFromApi(hist, addressesRes.Addresses);
            }
        } catch (Exception e) {
            System.debug(
                '### ADDRESSES LIST DML ERROR: ' + e.getMessage()
                    + ' | ' + e.getStackTraceString()
            );
        }

        try {
            applyDocumentsListFromApi(hist, result, docRes);
        } catch (Exception e) {
            System.debug('### DOCUMENT APPLY ERROR: ' + e.getMessage());
        }

        try {
            applyCardBasicInfoFromApi(hist, result, cardRes);
        } catch (Exception e) {
            System.debug('### CARD BASIC APPLY ERROR: ' + e.getMessage());
        }

        try {
            applyOutstandingAuthFromApi(hist, authRes);
        } catch (Exception e) {
            System.debug('### OUTSTANDING AUTH DML ERROR: ' + e.getMessage());
        }

        try {
            applyCardPlanFromApi(hist, cardPlanRes);
        } catch (Exception e) {
            System.debug('### CARD PLAN DML ERROR: ' + e.getMessage());
        }

        try {
            applyCardSecInfoFromApi(hist, cardSecRes);
            persistIppRecords(hist.Id, ippToInsert);
        } catch (Exception e) {
            System.debug('### CARD SEC / IPP DML ERROR: ' + e.getMessage());
        }

        try {
            applyLoanBasicInfoFromApi(hist, loanRes);
            if (mrcRes != null && mrcRes.success && mrcRes.data != null) {
                applyMrcInfoFromApi(hist, mrcRes.data);
            }
        } catch (Exception e) {
            System.debug('### LOAN APPLY ERROR: ' + e.getMessage());
        }

        return result;
    }

    private static void applyCustomerInfoBasicFromApi(
        FEC_Customer_History__c hist,
        ResultDTO result,
        FEC_GetCustomerInfoBasic.ResponseWrapper basicRes
    ) {
        if (hist == null || basicRes == null || basicRes.CustomerBasicInfo == null) {
            return;
        }

        FEC_GetCustomerInfoBasic.CustomerBasicInfo info = basicRes.CustomerBasicInfo;

        hist.FEC_First_Name__c = info.FirstName;
        hist.FEC_Middle_Name__c = info.MiddleName;
        hist.FEC_Last_Name__c = info.LastName;
        hist.FEC_Customer_Name__c = info.FullName;
        hist.FEC_Date_of_Birth__c = info.Birthday;
        hist.FEC_Gender__c = info.Gender;
        hist.FEC_Marital_Status__c = info.MaritalStatus;
        if (String.isNotBlank(info.CIFNumber)) {
            hist.FEC_CIF_Number__c = info.CIFNumber;
        }

        if (result != null) {
            result.customerName = info.FullName;
            result.gender = info.Gender;
            result.dateOfBirth = info.Birthday;
        }

        if (info.PreferredContacts != null) {
            for (FEC_GetCustomerInfoBasic.PreferredContact pc : info.PreferredContacts) {
                if (pc == null || pc.Contact == null) {
                    continue;
                }
                if (pc.Contact.Channel == FEC_ConstantCommon.EMAIL && String.isBlank(hist.FEC_Email__c)) {
                    hist.FEC_Email__c = pc.Contact.ContactString;
                    if (result != null) {
                        result.emailAddress = pc.Contact.ContactString;
                    }
                }
            }
        }
    }

    private static void applyDocumentsListFromApi(
        FEC_Customer_History__c hist,
        ResultDTO result,
        FEC_GetDocumentsList.ResponseWrapper docRes
    ) {
        if (hist == null || docRes == null || docRes.Documents == null || docRes.Documents.isEmpty()) {
            return;
        }

        FEC_GetDocumentsList.DocumentInfo doc = docRes.Documents[0];
        hist.FEC_National_ID_Passport_ID__c = doc.DocumentID;
        hist.FEC_Date_of_Issue__c = doc.IssueDate;
        hist.FEC_Place_of_Issue__c = doc.IssuePlace;

        if (result != null) {
            result.nationalId = doc.DocumentID;
        }
    }

    private static Boolean isLoanInteractionProductType(FEC_Customer_History__c hist) {
        String productTypeCode = resolveInteractionProductTypeCode(hist);
        return productTypeCode == FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE;
    }

    private static void applyLoanBasicInfoFromApi(
        FEC_Customer_History__c hist,
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse
    ) {
        if (hist == null || loanResponse == null || loanResponse.LoanBasicInfo == null) {
            return;
        }

        FEC_GetLoanBasicInfo.Loan loan = loanResponse.LoanBasicInfo.Loan;
        FEC_GetLoanBasicInfo.Product product = loanResponse.LoanBasicInfo.Product;
        FEC_GetLoanBasicInfo.PassDue passDue = loanResponse.LoanBasicInfo.PassDue;
        FEC_GetLoanBasicInfo.TerminationSimulation termSim =
            loanResponse.LoanBasicInfo.TerminationSimulation;

        if (loan != null) {
            if (String.isNotBlank(loan.ContractNumber)) {
                hist.FEC_Contract_Number__c = loan.ContractNumber;
            }
            hist.FEC_Contract_Type__c = loan.ContractType;
            hist.FEC_Contract_Status__c = FEC_CommonUltils.mapApiContractStatusToPicklist(
                loan.ContractStatus
            );
            hist.FEC_Agreement_Date__c = loan.AgreementDate;
            hist.FEC_Application_ID__c = loan.ApplicationID;
            hist.FEC_Company_Name__c = loan.CompanyName;
        }

        if (product != null) {
            hist.FEC_Charge_Off_Date__c = product.ChargeOffDate;
            hist.FEC_Rate__c = product.Rate;
            hist.FEC_Account_Status_Change_Date__c = product.ClosureDate;
            hist.FEC_Loan_Amount__c = product.LoanAmount;
            hist.FEC_EMI__c = product.EMI;
            hist.FEC_Tenure__c = product.Tenure;
            hist.FEC_Insurance_Amount__c = product.InsuranceAmount;
            hist.FEC_First_Payment_Date__c = product.FirstPaymentDate;
            hist.FEC_Last_Payment_Date__c = product.LastPaymentDate;
            if (String.isNotBlank(product.Product)) {
                hist.FEC_Product_Code__c = product.Product;
            }
        }

        if (termSim != null) {
            hist.FEC_Next_Due_Date__c = termSim.NextDueDate;
        }

        if (passDue != null) {
            hist.FEC_Days_Past_Due__c = passDue.DPD;
        }
    }

    private static void applyMrcInfoFromApi(
        FEC_Customer_History__c hist,
        FEC_GetMRCInfo.MRCInfoData data
    ) {
        if (hist == null || data == null) {
            return;
        }

        hist.FEC_MRC_Zone__c = data.mrcZone;
        hist.FEC_Area__c = data.area;
        hist.FEC_Plate_Number__c = data.plateNumber;
        hist.FEC_MRC_Status__c = data.status;
        hist.FEC_Status_ID__c = data.statusId;
        hist.FEC_ID__c = data.id;

        hist.FEC_Original_MRC_Remark__c = data.remark;
        hist.FEC_Modified_Date__c = parseMrcDateFromApi(data.modifiedDate);
        hist.FEC_Delivery_Date__c = parseMrcDateFromApi(data.mailcode);
        hist.FEC_Received_Date__c = parseMrcDateFromApi(data.receivedDate);
        hist.FEC_Original_MRC_Receiver__c = data.receiverInformation;

        hist.FEC_Posted_Date__c = parseMrcDateFromApi(data.notaryPostedDate);
        hist.FEC_Postal_Code__c = data.notaryMailcode;
        hist.FEC_Notarized_MRC_Remark__c = data.notaryRemark;
        hist.FEC_Notarized_MRC_Receiver__c = data.notaryReceiverInformation;

        if (String.isNotBlank(data.provideNumber)) {
            try {
                hist.FEC_Provided_Number__c = Decimal.valueOf(data.provideNumber.trim());
            } catch (Exception e) {
                System.debug('### MRC ProvidedNumber parse: ' + e.getMessage());
            }
        } else {
            hist.FEC_Provided_Number__c = null;
        }
    }

    private static Date parseMrcDateFromApi(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String trimmed = raw.trim();
        try {
            return Date.valueOf(trimmed);
        } catch (Exception e) {
            return FEC_CommonUltils.parseDate(trimmed);
        }
    }

    private static Boolean isCardInteractionProductType(FEC_Customer_History__c hist) {
        String productTypeCode = resolveInteractionProductTypeCode(hist);
        return productTypeCode == FEC_ConstantCommon.PRODUCT_TYPE_CARD_CASE;
    }

    private static String resolveInteractionProductTypeCode(FEC_Customer_History__c hist) {
        if (hist == null) {
            return null;
        }

        if (hist.FEC_Case__r != null && String.isNotBlank(hist.FEC_Case__r.FEC_Product_Type__r.FEC_Code__c)) {
            return hist.FEC_Case__r.FEC_Product_Type__r.FEC_Code__c;
        }

        if (hist.Id == null) {
            return null;
        }

        List<Case> interactions = [
            SELECT FEC_Product_Type__r.FEC_Code__c
            FROM Case
            WHERE FEC_Account_or_Contract__c = :hist.Id
              AND RecordType.DeveloperName = :FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            LIMIT 1
        ];
        if (!interactions.isEmpty()
            && interactions[0].FEC_Product_Type__r != null
            && String.isNotBlank(interactions[0].FEC_Product_Type__r.FEC_Code__c)) {
            return interactions[0].FEC_Product_Type__r.FEC_Code__c;
        }

        return null;
    }

    private static void applyCardBasicInfoFromApi(
        FEC_Customer_History__c hist,
        ResultDTO result,
        FEC_GetCardBasicInfo.ResponseWrapper cardRes
    ) {
        if (hist == null || cardRes == null || cardRes.CardBasicInfo == null) {
            return;
        }

        FEC_GetCardBasicInfo.MainCard m = cardRes.CardBasicInfo.MainCard;
        if (m == null) {
            return;
        }

        Integer dpd;
        if (cardRes.CardBasicInfo.PassDue != null) {
            dpd = cardRes.CardBasicInfo.PassDue.DPD;
        }

        Date activationDateParsed = null;
        if (cardRes.CardBasicInfo.CardHistories != null
            && cardRes.CardBasicInfo.CardHistories.CardHistory != null
            && !cardRes.CardBasicInfo.CardHistories.CardHistory.isEmpty()) {
            activationDateParsed = FEC_CommonUltils.parseDate(
                String.valueOf(cardRes.CardBasicInfo.CardHistories.CardHistory[0].CardActivationDate)
            );
        }

        hist.FEC_Account_Number__c = m.AccountNumber;
        hist.FEC_Contract_Number__c = m.ContractNumber;
        hist.FEC_Account_Status__c = m.Status;
        hist.FEC_Credit_Limit__c = m.CreditLimit;
        hist.FEC_OTB__c = m.OTB;
        hist.FEC_Hold_Amount__c = m.HoldAmount;
        hist.FEC_Block_Date_1__c = m.AccountBlockCode1Date;
        hist.FEC_Reason_1__c = m.RsnBlockCode1;
        hist.FEC_Block_Code_2__c = m.BlockCode2;
        hist.FEC_Block_Date_2__c = m.AccountBlockCode2Date;
        hist.FEC_Reason_2__c = m.RsnBlockCode2;
        if (dpd != null) {
            hist.FEC_Days_Past_Due__c = dpd;
        }
        hist.FEC_Card_Number__c = m.MaskedCardNumber;
        hist.FEC_Insurance_Flag__c = FEC_CommonUltils.normalizeInsuranceFlag(m.InsuranceFlag);
        hist.FEC_Customer_Segment__c = m.CustomerSegment;
        hist.FEC_Expiry_Date__c = m.ExpiryDate;
        hist.FEC_Plastic_ID__c = m.PlasticIndicator;
        hist.FEC_Product_Code__c = m.Product;
        hist.FEC_Block_Code__c = m.BlockCode;
        hist.FEC_Block_Date__c = m.BlckDate;
        hist.FEC_Card_Activation_Status__c = FEC_CommonUltils.checkActiveAndInacive(m.ActivatedFlag);
        hist.FEC_Card_Activation_Date__c = activationDateParsed;

        if (result != null) {
            result.plasticID = m.PlasticIndicator;
        }
    }

    private static void applyCardSecInfoFromApi(
        FEC_Customer_History__c hist,
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes
    ) {
        if (hist == null || cardSecRes == null || cardSecRes.CardSecInfo == null) {
            return;
        }

        FEC_GetCardSecInfo.CardSecInfo info = cardSecRes.CardSecInfo;

        FEC_GetCardSecInfo.MainCardProduct product = info.MainCardProduct;
        if (product != null) {
            hist.FEC_Daily_Retail_Limit__c = product.DailyRetailLimit;
            hist.FEC_Daily_Retail_Number__c = product.DailyRetailNumber;
            hist.FEC_Daily_Cash_Limit__c = product.DailyCashLimit;
            hist.FEC_Daily_Cash_Number__c = product.DailyCashNumber;
            hist.FEC_Last_Credit_Limit__c = product.LastCreditLimit;
            hist.FEC_Last_Credit_Limit_Date__c = product.LastCreditLimitDate;
            hist.FEC_Delinquency_Date__c = product.LastDelinquencyDate;
            hist.FEC_Statement_Notification_Type__c = product.StatementNotificationType;
        }

        FEC_GetCardSecInfo.MainCardPlastic plastic = info.MainCardPlastic;
        if (plastic != null) {
            hist.FEC_Embossing_Name__c = plastic.EmbossingName;
            if (plastic.EcomActiveFlag != null) {
                hist.FEC_E_Commerce_Status__c = FEC_CommonUltils.checkEcomFlag(plastic.EcomActiveFlag);
            }
        }

        FEC_GetCardSecInfo.MainCardBalance balance = info.MainCardBalance;
        if (balance != null) {
            hist.FEC_Current_Balance__c = balance.CurrentBalance;
            hist.FEC_Total_Balance__c = balance.TotalBalance;
        }

        FEC_GetCardSecInfo.PassDue passDue = info.PassDue;
        if (passDue != null) {
            hist.FEC_Responsible_Unit__c = passDue.ResponsibleUnit;
            hist.FEC_Responsible_Person__c = passDue.ResposiblePerson;
            hist.FEC_Date_Assigned__c = passDue.DateAssgined;
        }
    }

    private static void applyOutstandingAuthFromApi(
        FEC_Customer_History__c hist,
        FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper authRes
    ) {
        if (hist == null || hist.Id == null || authRes == null || authRes.VMXMsgOut == null) {
            return;
        }
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> auths = authRes.VMXMsgOut.Auths;
        if (auths == null || auths.isEmpty()) {
            return;
        }

        Map<String, FEC_Transaction__c> existingByKey = new Map<String, FEC_Transaction__c>();
        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Transaction_Code__c,
                   FEC_Effective_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Merchant_Description__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :hist.Id
        ]) {
            String key = buildOutstandingAuthKey(tx);
            if (String.isNotBlank(key)) {
                existingByKey.put(key, tx);
            }
        }

        List<FEC_Transaction__c> toUpsert = new List<FEC_Transaction__c>();
        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth : auths) {
            if (auth == null) {
                continue;
            }

            String authCode = auth.AUTHORIZATION_CODE;
            String amtRaw = pickFirstNonBlank(auth.AUTH_AMOUNT, auth.DTL_AUTH_AMT);
            Date effDate = FEC_CommonUltils.toDate(auth.EFF_DATE);
            if (effDate == null) {
                effDate = FEC_CommonUltils.toDate(auth.EFF_DATE_AUTH_DETAIL);
            }
            if (effDate == null) {
                effDate = FEC_CommonUltils.toDate(auth.POSTING_DATE);
            }
            Decimal amt = FEC_CommonUltils.parseAmountSafe(amtRaw);
            if (effDate == null && amt == null && String.isBlank(authCode)) {
                continue;
            }

            FEC_Transaction__c rec = new FEC_Transaction__c(
                FEC_Customer_History__c = hist.Id
            );
            rec.FEC_Effective_Date__c = effDate;
            rec.FEC_Post_Date__c = FEC_CommonUltils.toDate(auth.POSTING_DATE);
            rec.FEC_Transaction_Amount__c = amt;
            rec.FEC_Merchant_Description__c = pickFirstNonBlank(
                auth.Description,
                auth.DTL_MERC_NAME_LOC
            );
            rec.FEC_Credit_Debit_Flag__c = auth.CreditDebitFlag;
            rec.FEC_Transaction_Plan__c = pickFirstNonBlank(auth.CREDIT_PLAN, auth.DTL_CR_PLAN);
            rec.FEC_Transaction_Code__c = String.isNotBlank(authCode)
                ? authCode.trim()
                : 'OUTSTANDING_AUTH';
            rec.FEC_Authorization_Code__c = authCode;
            rec.FEC_Merchant_Category_Code__c = pickFirstNonBlank(auth.MERCH_CAT, auth.DTL_MERCH_CAT);
            rec.FEC_Currency_Code__c = pickFirstNonBlank(auth.TXN_CURR_CODE, auth.DTL_TXN_CURR_CODE);
            rec.FEC_Approval_Code__c = auth.AUTH_CD;
            rec.FEC_Authorization_Response__c = auth.FINAL_ACTN;
            rec.FEC_Decline_Description__c = auth.ACTN_RSN_DESC;

            String key = buildOutstandingAuthKey(rec);
            if (String.isNotBlank(key) && existingByKey.containsKey(key)) {
                rec.Id = existingByKey.get(key).Id;
            }
            toUpsert.add(rec);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }

    private static String buildOutstandingAuthKey(FEC_Transaction__c tx) {
        if (tx == null) {
            return null;
        }
        String code = tx.FEC_Transaction_Code__c != null
            ? tx.FEC_Transaction_Code__c.trim()
            : '';
        String eff = tx.FEC_Effective_Date__c != null
            ? String.valueOf(tx.FEC_Effective_Date__c)
            : '';
        String amt = tx.FEC_Transaction_Amount__c != null
            ? String.valueOf(tx.FEC_Transaction_Amount__c)
            : '';
        if (String.isNotBlank(code)) {
            return code + '|' + eff + '|' + amt;
        }
        String merchant = tx.FEC_Merchant_Description__c != null
            ? tx.FEC_Merchant_Description__c.trim()
            : '';
        return eff + '|' + amt + '|' + merchant;
    }

    private static String pickFirstNonBlank(String a, String b) {
        if (String.isNotBlank(a)) {
            return a.trim();
        }
        if (String.isNotBlank(b)) {
            return b.trim();
        }
        return null;
    }

    private static List<FEC_IPP__c> buildIppRecordsFromThreeApis(
        FEC_Customer_History__c hist,
        String accountNumber,
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes,
        FEC_GetCardPlanInfo.CardPlanResult cardPlanRes
    ) {
        List<FEC_IPP__c> toInsert = new List<FEC_IPP__c>();
        if (hist == null || hist.Id == null || String.isBlank(accountNumber)) {
            return toInsert;
        }

        List<FEC_GetCardSecInfo.IPP> orderedIppList = buildOrderedIppListFromCardSecInfo(cardSecRes);
        List<FEC_GetCardPlanInfo.CardPlan> cardPlans = new List<FEC_GetCardPlanInfo.CardPlan>();
        if (cardPlanRes != null && cardPlanRes.plans != null && !cardPlanRes.plans.isEmpty()) {
            cardPlans = cardPlanRes.plans;
        }

        Boolean hasPlans = !cardPlans.isEmpty();
        Boolean hasIpps = orderedIppList != null && !orderedIppList.isEmpty();
        if (!hasPlans && !hasIpps) {
            return toInsert;
        }

        Integer planCount = cardPlans.size();
        Integer ippCount = orderedIppList.size();
        Integer maxSize = Math.max(planCount, ippCount);
        String todayStr = Datetime.now().formatGmt(FEC_ConstantCommon.DATE_FORMAT);

        for (Integer i = 0; i < maxSize; i++) {
            FEC_GetCardPlanInfo.CardPlan cardPlan = (i < planCount) ? cardPlans[i] : null;
            FEC_GetCardSecInfo.IPP ipp = (i < ippCount) ? orderedIppList[i] : null;
            FEC_IPP__c rec;

            if (cardPlan != null) {
                String planNumberKey = String.isNotBlank(cardPlan.planNumber)
                    ? cardPlan.planNumber.trim()
                    : '';
                if (String.isBlank(planNumberKey)) {
                    continue;
                }
                rec = buildIppRecordFromCardPlanAndSecIpp(hist.Id, cardPlan, ipp, planNumberKey);
            } else {
                if (ipp == null) {
                    continue;
                }
                rec = buildIppRecordFromSecIppOnly(hist.Id, ipp);
            }

            if (rec == null) {
                continue;
            }

            enrichIppRecordFromDetailsApi(rec, accountNumber, rec.FEC_IPP_Plan__c, todayStr);
            toInsert.add(rec);
        }

        return toInsert;
    }

    private static FEC_IPP__c buildIppRecordFromCardPlanAndSecIpp(
        Id customerHistoryId,
        FEC_GetCardPlanInfo.CardPlan cardPlan,
        FEC_GetCardSecInfo.IPP ipp,
        String planNumberKey
    ) {
        FEC_IPP__c rec = new FEC_IPP__c(
            FEC_Customer_History__c = customerHistoryId,
            FEC_IPP_Plan__c = planNumberKey,
            FEC_IPP_Open_Date__c = FEC_CommonUltils.parseDate(cardPlan.openDate),
            FEC_IPP_Balance__c = cardPlan.currentBalance
        );

        if (ipp != null) {
            rec.FEC_IPP_Record_No__c = ipp.IPPRecordNo != null ? ipp.IPPRecordNo.trim() : null;
            rec.FEC_IPP_First_Due_Date__c = FEC_CommonUltils.parseDate(ipp.IPPStartDate);
            rec.FEC_IPP_Mature_Date__c = FEC_CommonUltils.parseDate(ipp.IPPMatureDate);
            rec.FEC_IPP_Current_Balance__c = ipp.IPPCurrentBalance;
            rec.FEC_IPP_Current_Term__c = ipp.currentTerm;
        }

        return rec;
    }

    private static FEC_IPP__c buildIppRecordFromSecIppOnly(
        Id customerHistoryId,
        FEC_GetCardSecInfo.IPP ipp
    ) {
        if (ipp == null) {
            return null;
        }

        String planNumberKey = String.isNotBlank(ipp.IPPPlan) ? ipp.IPPPlan.trim() : '';
        if (String.isBlank(planNumberKey)) {
            planNumberKey = FEC_ConstantCommon.STR_DASH;
        }

        return new FEC_IPP__c(
            FEC_Customer_History__c = customerHistoryId,
            FEC_IPP_Plan__c = planNumberKey,
            FEC_IPP_Record_No__c = ipp.IPPRecordNo != null ? ipp.IPPRecordNo.trim() : null,
            FEC_IPP_Balance__c = ipp.IPPBalance,
            FEC_IPP_First_Due_Date__c = FEC_CommonUltils.parseDate(ipp.IPPStartDate),
            FEC_IPP_Mature_Date__c = FEC_CommonUltils.parseDate(ipp.IPPMatureDate),
            FEC_IPP_Current_Balance__c = ipp.IPPCurrentBalance,
            FEC_IPP_Current_Term__c = ipp.currentTerm,
            FEC_IPP_Interest_Rate__c = ipp.InterestRate
        );
    }

    private static void persistIppRecords(Id customerHistoryId, List<FEC_IPP__c> toInsert) {
        if (customerHistoryId == null || toInsert == null || toInsert.isEmpty()) {
            return;
        }
        deleteExistingIppRecords(customerHistoryId);
        insert toInsert;
    }

    private static void applyCardPlanFromApi(
        FEC_Customer_History__c hist,
        FEC_GetCardPlanInfo.CardPlanResult cardPlanRes
    ) {
        if (hist == null
            || hist.Id == null
            || cardPlanRes == null
            || cardPlanRes.plans == null
            || cardPlanRes.plans.isEmpty()
            || cardPlanRes.responseCode != '1') {
            return;
        }

        Map<String, FEC_Card_Payment__c> existingByKey = new Map<String, FEC_Card_Payment__c>();
        for (FEC_Card_Payment__c row : [
            SELECT Id, FEC_Rec__c, FEC_Plan__c
            FROM FEC_Card_Payment__c
            WHERE FEC_Customer_History__c = :hist.Id
        ]) {
            existingByKey.put(buildCardPlanSyncKey(row.FEC_Rec__c, row.FEC_Plan__c), row);
        }

        List<FEC_Card_Payment__c> toInsert = new List<FEC_Card_Payment__c>();
        List<FEC_Card_Payment__c> toUpdate = new List<FEC_Card_Payment__c>();

        for (FEC_GetCardPlanInfo.CardPlan plan : cardPlanRes.plans) {
            if (plan == null) {
                continue;
            }

            String key = buildCardPlanSyncKey(plan.recordNumber, plan.planNumber);
            FEC_Card_Payment__c record = buildCardPaymentFromPlan(plan, hist.Id);
            if (existingByKey.containsKey(key)) {
                record.Id = existingByKey.get(key).Id;
                toUpdate.add(record);
            } else {
                toInsert.add(record);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static String buildCardPlanSyncKey(String rec, String plan) {
        return (rec != null ? rec.trim() : '') + '_' + (plan != null ? plan.trim() : '');
    }

    private static FEC_Card_Payment__c buildCardPaymentFromPlan(
        FEC_GetCardPlanInfo.CardPlan plan,
        Id customerHistoryId
    ) {
        FEC_Card_Payment__c record = new FEC_Card_Payment__c(
            FEC_Customer_History__c = customerHistoryId,
            FEC_Rec__c = plan.recordNumber,
            FEC_Plan__c = plan.planNumber,
            FEC_REF_Number__c = plan.refNumber,
            FEC_Open_Date__c = FEC_CommonUltils.parseDate(plan.openDate),
            FEC_Begin_Date__c = FEC_CommonUltils.parseDate(plan.beginDate)
        );

        Decimal currentBalance = plan.currentBalance != null ? plan.currentBalance : 0;
        Decimal accruedInterest = plan.accruedInterest != null ? plan.accruedInterest : 0;
        Decimal perDiem = plan.perDiem != null ? plan.perDiem : 0;
        Decimal deferredInterest = plan.deferredInterest != null ? plan.deferredInterest : 0;
        Decimal ippAccruedInterest = plan.additionalAccruedInt != null ? plan.additionalAccruedInt : 0;

        record.FEC_Current_Balance__c = currentBalance;
        record.FEC_Base_Rate__c = (plan.baseRate != null ? plan.baseRate / 100 : null);
        record.FEC_Deferred_Interest__c = deferredInterest;
        record.FEC_Accrued_Interest__c = accruedInterest;
        record.FEC_Per_Diem__c = perDiem;
        record.FEC_IPP_Interest__c = plan.ippInterest;
        record.FEC_IPP_Accrued_Interest__c = ippAccruedInterest;

        Decimal closeFeePercent = 0;
        if (plan.closeFeeIndicator == 'Y' && currentBalance > 0 && plan.closeFeeIndicatorAmt != null) {
            closeFeePercent = (plan.closeFeeIndicatorAmt / currentBalance) * 100;
            closeFeePercent = closeFeePercent.setScale(2, RoundingMode.HALF_UP);
        }
        record.FEC_Close_Fee__c = closeFeePercent;
        record.FEC_Close_Fee_Amount__c = plan.closeFeeIndicatorAmt != null
            ? plan.closeFeeIndicatorAmt
            : 0;
        record.FEC_Plan_Payment_Amount__c = plan.totalPaymentAmount != null
            ? plan.totalPaymentAmount
            : 0;

        return record;
    }

    private static List<FEC_GetCardSecInfo.IPP> buildOrderedIppListFromCardSecInfo(
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes
    ) {
        List<FEC_GetCardSecInfo.IPP> orderedList = new List<FEC_GetCardSecInfo.IPP>();
        if (cardSecRes == null
            || cardSecRes.CardSecInfo == null
            || cardSecRes.CardSecInfo.IPPs == null) {
            return orderedList;
        }

        Set<String> seen = new Set<String>();
        for (FEC_GetCardSecInfo.IPP ipp : cardSecRes.CardSecInfo.IPPs) {
            if (ipp == null) {
                continue;
            }
            String key = (ipp.IPPRecordNo != null ? ipp.IPPRecordNo.trim() : '') + '_'
                + (ipp.IPPPlan != null ? ipp.IPPPlan.trim() : '');
            if (!seen.contains(key)) {
                seen.add(key);
                orderedList.add(ipp);
            }
        }
        return orderedList;
    }

    private static void enrichIppRecordFromDetailsApi(
        FEC_IPP__c rec,
        String accountNumber,
        String planNumber,
        String todayStr
    ) {
        if (rec == null
            || String.isBlank(planNumber)
            || FEC_ConstantCommon.STR_DASH.equals(planNumber)) {
            return;
        }

        try {
            FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
            req.accountNumber = accountNumber;
            req.effectiveDate = todayStr;
            req.amount = 1;
            req.postingDate = todayStr;
            req.planNumber = planNumber;

            FEC_GetIPPDetailsCallout.IPPDetailsResponse detailResp =
                FEC_GetIPPDetailsCallout.getIPPDetails(req);

            Boolean isSuccess = detailResp != null && (
                detailResp.status == FEC_ConstantCommon.SUCCESS_MESSAGE
                || detailResp.status == FEC_ConstantCommon.SUCCESS_STATUS_CODE
                || (detailResp.sysMessage != null
                    && detailResp.sysMessage.equalsIgnoreCase(FEC_ConstantCommon.SUCCESS_MESSAGE))
            );

            if (isSuccess) {
                if (detailResp.interestRate != null) {
                    rec.FEC_IPP_Interest_Rate__c = detailResp.interestRate;
                }
                if (String.isNotBlank(detailResp.ippTerm)) {
                    rec.FEC_IPP_Term__c = Decimal.valueOf(detailResp.ippTerm.trim());
                }
            }
        } catch (Exception e) {
            System.debug('### GetIPPDetails ERROR for plan ' + planNumber + ': ' + e.getMessage());
        }
    }

    private static void deleteExistingIppRecords(Id customerHistoryId) {
        if (customerHistoryId == null) {
            return;
        }

        List<FEC_IPP__c> existing = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }
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

    private class ProvinceAddressResolve {
        Id provinceId;
        String countryFecCode;
    }

    private static void applyAddressesListFromApi(
        FEC_Customer_History__c hist,
        List<FEC_GetAddressesList.AddressInfo> rawAddresses
    ) {
        if (hist == null || hist.Id == null || rawAddresses == null || rawAddresses.isEmpty()) {
            return;
        }

        List<FEC_GetAddressesList.AddressInfo> addressesToSync =
            filterDuplicatePermanentAddressTypes(rawAddresses);
        if (addressesToSync == null || addressesToSync.isEmpty()) {
            return;
        }

        Map<String, Id> districtMap = new Map<String, Id>();
        for (FEC_District__c d : [SELECT Id, FEC_Code__c FROM FEC_District__c]) {
            districtMap.put(d.FEC_Code__c, d.Id);
        }

        List<FEC_Country__c> allCountries = [
            SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c
            FROM FEC_Country__c
            ORDER BY FEC_Code__c NULLS LAST, Name
        ];
        Map<Id, FEC_Country__c> countryById = buildCountryByIdMap(allCountries);

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

        for (FEC_GetAddressesList.AddressInfo ai : addressesToSync) {
            if (ai == null) {
                continue;
            }

            String type = mapApiAddressTypeToSF(ai.AddressType);
            if (String.isBlank(type)) {
                continue;
            }

            FEC_Address_Info__c addr;
            if (existingMap.containsKey(type)) {
                addr = existingMap.get(type);
            } else {
                addr = new FEC_Address_Info__c();
                addr.Name = type.left(80);
                addr.FEC_Customer_History__c = hist.Id;
                addr.FEC_Address_Type__c = type;
                toInsert.add(addr);
            }

            addr.FEC_Building__c = ai.Building;
            addr.FEC_Number__c = ai.NumberStr;
            addr.FEC_Street__c = ai.Street;
            addr.FEC_ZipCode__c = ai.ZipCode;
            addr.FEC_Ward__c = null;
            addr.FEC_Ward_Text__c = null;

            ProvinceAddressResolve pr = resolveProvinceForAddressSync(ai.City);
            if (pr.provinceId != null) {
                addr.FEC_Province__c = pr.provinceId;
                addr.FEC_Province_Text__c = null;
            } else if (String.isNotBlank(ai.City)) {
                addr.FEC_Province__c = null;
                addr.FEC_Province_Text__c = ai.City;
            } else {
                addr.FEC_Province__c = null;
                addr.FEC_Province_Text__c = null;
            }

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

            Id countryId = resolveCountryIdFromApiAddressInfo(ai, allCountries);
            if (countryId != null) {
                countryId = remapCountryIdToApiMaster(countryId, countryById);
                addr.FEC_Country__c = countryId;
                addr.FEC_Country_Text__c = null;
            } else {
                addr.FEC_Country__c = null;
                addr.FEC_Country_Text__c = ai.CountryName;
            }

            if (addr.Id != null) {
                toUpdate.add(addr);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

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

    private static Id remapCountryIdToApiMaster(Id countryId, Map<Id, FEC_Country__c> countryById) {
        if (countryId == null || countryById == null || !countryById.containsKey(countryId)) {
            return null;
        }
        FEC_Country__c src = countryById.get(countryId);
        String code = (src.FEC_Code__c != null) ? src.FEC_Code__c.trim() : '';
        if (ADDR_COUNTRY_MASTER_API.equals(code) || !ADDR_COUNTRY_MASTER_LEGACY.equals(code)) {
            return countryId;
        }
        String matchVn = String.isNotBlank(src.FEC_Name_VN__c) ? src.FEC_Name_VN__c.trim() : null;
        String matchNm = (src.Name != null) ? src.Name.trim() : null;
        for (FEC_Country__c t : countryById.values()) {
            if (t == null || t.Id == src.Id) {
                continue;
            }
            String tc = (t.FEC_Code__c != null) ? t.FEC_Code__c.trim() : '';
            if (!ADDR_COUNTRY_MASTER_API.equals(tc)) {
                continue;
            }
            String tvn = String.isNotBlank(t.FEC_Name_VN__c) ? t.FEC_Name_VN__c.trim() : '';
            String tnm = (t.Name != null) ? t.Name.trim() : '';
            if (String.isNotBlank(matchVn)
                && (matchVn.equalsIgnoreCase(tvn) || matchVn.equalsIgnoreCase(tnm))) {
                return t.Id;
            }
            if (String.isNotBlank(matchNm)
                && (matchNm.equalsIgnoreCase(tvn) || matchNm.equalsIgnoreCase(tnm))) {
                return t.Id;
            }
        }
        return countryId;
    }

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
            if (ADDR_COUNTRY_MASTER_API.equals(fc)) {
                preferApi = c.Id;
                break;
            }
            if (anyId == null) {
                anyId = c.Id;
            }
        }
        return preferApi != null ? preferApi : anyId;
    }

    private static ProvinceAddressResolve resolveProvinceForAddressSync(String cityCode) {
        ProvinceAddressResolve out = new ProvinceAddressResolve();
        if (String.isBlank(cityCode)) {
            return out;
        }
        String codeTrim = FEC_UpdateCustomerAddress.remapProvinceCityCodeForCountryTwo(
            cityCode.trim()
        );
        List<FEC_Province__c> srcRows = [
            SELECT Id, Name, FEC_Name_VN__c, FEC_Country__r.FEC_Code__c
            FROM FEC_Province__c
            WHERE FEC_Code__c = :codeTrim
            LIMIT 1
        ];
        if (srcRows.isEmpty()) {
            return out;
        }
        FEC_Province__c src = srcRows[0];
        String countryCode = (src.FEC_Country__r != null && src.FEC_Country__r.FEC_Code__c != null)
            ? src.FEC_Country__r.FEC_Code__c.trim()
            : '';
        if (!ADDR_COUNTRY_MASTER_LEGACY.equals(countryCode)) {
            out.provinceId = src.Id;
            out.countryFecCode = countryCode;
            return out;
        }
        String matchName = String.isNotBlank(src.FEC_Name_VN__c) ? src.FEC_Name_VN__c.trim() : null;
        if (String.isBlank(matchName)) {
            matchName = (src.Name != null) ? src.Name.trim() : null;
        }
        if (String.isBlank(matchName)) {
            out.provinceId = src.Id;
            out.countryFecCode = countryCode;
            return out;
        }
        List<FEC_Province__c> targetRows = [
            SELECT Id
            FROM FEC_Province__c
            WHERE FEC_Country__r.FEC_Code__c = :ADDR_COUNTRY_MASTER_API
              AND (FEC_Name_VN__c = :matchName OR Name = :matchName)
        ];
        if (targetRows.size() == 1) {
            out.provinceId = targetRows[0].Id;
            out.countryFecCode = ADDR_COUNTRY_MASTER_API;
            return out;
        }
        out.provinceId = src.Id;
        out.countryFecCode = countryCode;
        return out;
    }

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
}
