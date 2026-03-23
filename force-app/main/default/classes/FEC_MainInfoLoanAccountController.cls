/** Controller LWC fec_MainInfoLoanAccount. Sync API → DB, load từ FEC_Customer_History__c. */
public with sharing class FEC_MainInfoLoanAccountController {

    /** Sync Loan Account từ API (GetLoanBasicInfo + GetCustomerList + GetLoanSecInfo) → FEC_Customer_History__c. */
    @AuraEnabled
    public static void syncLoanAccountFromAPI(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) {
            return;
        }

        List<FEC_Customer_History__c> chList = [
            SELECT Id, FEC_Contract_Number__c, FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (chList.isEmpty()) {
            return;
        }
        FEC_Customer_History__c ch = chList[0];
        String contractNumber = ch.FEC_Contract_Number__c;
        String accountNumber  = ch.FEC_Account_Number__c;
        if (String.isBlank(contractNumber) || String.isBlank(accountNumber)) {
            return;
        }

        String transId = FEC_CommonUltils.generateTransactionId();
        String dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);

        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse = null;
        try {
            loanResponse = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, contractNumber
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{e.getMessage()})
            );
        }

        String schemeID = null;
        String schemeDesc = null;
        try {
            FEC_GetCustomerList.ResponseWrapper custResponse = FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_CRM, null, false, null, null, null, null,
                accountNumber, null, null, null
            );
            Map<String, String> scheme = extractScheme(custResponse, contractNumber);
            schemeID   = scheme.get('schemeID');
            schemeDesc = scheme.get('schemeDesc');
        } catch (Exception e) {
            System.debug('### GET CUSTOMER LIST (Scheme) ERROR: ' + e.getMessage());
        }

        Integer installmentsRemaining = null;
        try {
            FEC_GetLoanSecInfo.ResponseWrapper secResponse = FEC_GetLoanSecInfo.callGetLoanSecInfo(
                transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, contractNumber
            );
            if (secResponse?.LoanSecInfo?.PassDue != null) {
                installmentsRemaining = secResponse.LoanSecInfo.PassDue.InstallmentsRemaining;
            }
        } catch (Exception e) {
            System.debug('### GET LOAN SEC INFO ERROR: ' + e.getMessage());
        }

        String productCodeFromCard = null;
        try {
            FEC_GetCardBasicInfo.ResponseWrapper cardRes = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, accountNumber
            );
            if (cardRes?.CardBasicInfo?.MainCard != null) {
                productCodeFromCard = cardRes.CardBasicInfo.MainCard.Product;
            }
        } catch (Exception e) {
            System.debug('### GET CARD BASIC INFO (Product Code) ERROR: ' + e.getMessage());
        }

        saveApiDataToCustomerHistory(c.FEC_Account_or_Contract__c, loanResponse, schemeID, schemeDesc, installmentsRemaining, productCodeFromCard);
    }

    /** Sync API rồi load từ DB (gọi mỗi khi load trang, giống loadSecondaryAccount / getSectionData). */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadLoanAccountInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        syncLoanAccountFromAPI(caseId);

        Case c = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (c.FEC_Account_or_Contract__c == null) {
            return new Map<String, Object>();
        }

        List<FEC_Customer_History__c> histories = [
            SELECT FEC_Contract_Number__c, FEC_Contract_Type__c, FEC_Contract_Status__c, FEC_Agreement_Date__c,
                   FEC_Application_ID__c, FEC_Company_Name__c, FEC_Account_Status_Change_Date__c, FEC_Product_Code__c,
                   FEC_Charge_Off_Date__c, FEC_Rate__c, FEC_Loan_Amount__c, FEC_EMI__c, FEC_Tenure__c,
                   FEC_Insurance_Amount__c, FEC_First_Payment_Date__c, FEC_Last_Payment_Date__c,
                   FEC_Next_Due_Date__c, FEC_Days_Past_Due__c, FEC_Scheme_ID__c, FEC_Scheme_Desc__c,
                   FEC_Installments_Remaining__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            return new Map<String, Object>();
        }

        return mapCustomerHistoryToResult(histories[0]);
    }

    /* Map FEC_Customer_History__c → result (load from DB) */

    private static Map<String, Object> mapCustomerHistoryToResult(FEC_Customer_History__c ch) {
        Map<String, Object> result = new Map<String, Object>();
        if (ch == null) {
            return result;
        }

        result.put('contractNumber', ch.FEC_Contract_Number__c);
        result.put('contractStatus', ch.FEC_Contract_Status__c);
        result.put('agreementDate', FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Agreement_Date__c));
        result.put('contractType', ch.FEC_Contract_Type__c);
        result.put('applicationId', ch.FEC_Application_ID__c);
        result.put('accountStatusChangeDate', FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Account_Status_Change_Date__c));
        result.put('productCode', ch.FEC_Product_Code__c);
        result.put('chargeOffDate', FEC_CommonUltils.formatDate(ch.FEC_Charge_Off_Date__c));
        result.put('rate', ch.FEC_Rate__c != null ? String.valueOf(ch.FEC_Rate__c) + '%' : null);
        result.put('loanAmount', FEC_CommonUltils.formatCurrency(ch.FEC_Loan_Amount__c, 0));
        result.put('tenure', ch.FEC_Tenure__c != null ? String.valueOf(ch.FEC_Tenure__c) : null);
        result.put('insuranceAmount', FEC_CommonUltils.formatCurrency(ch.FEC_Insurance_Amount__c, 0));
        result.put('emi', FEC_CommonUltils.formatCurrency(ch.FEC_EMI__c, 0));
        result.put('firstPaymentDate', FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_First_Payment_Date__c));
        result.put('lastPaymentDate', FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Last_Payment_Date__c));
        result.put('daysPastDue', ch.FEC_Days_Past_Due__c != null ? String.valueOf(ch.FEC_Days_Past_Due__c) : null);
        result.put('schemeID', ch.FEC_Scheme_ID__c);
        result.put('schemeDesc', ch.FEC_Scheme_Desc__c);
        result.put('installmentRemaining', ch.FEC_Installments_Remaining__c != null ? String.valueOf(ch.FEC_Installments_Remaining__c) : null);
        result.put('nextDueDate', FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Next_Due_Date__c));
        result.put('companyName', ch.FEC_Company_Name__c);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));

        return result;
    }

    /* Save API data to FEC_Customer_History__c */

    private static void saveApiDataToCustomerHistory(
        Id customerHistoryId,
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse,
        String schemeID,
        String schemeDesc,
        Integer installmentsRemaining,
        String productCodeFromCard
    ) {
        if (customerHistoryId == null || loanResponse?.LoanBasicInfo == null) {
            return;
        }

        FEC_GetLoanBasicInfo.Loan loan       = loanResponse.LoanBasicInfo.Loan;
        FEC_GetLoanBasicInfo.Product product  = loanResponse.LoanBasicInfo.Product;
        FEC_GetLoanBasicInfo.PassDue passDue  = loanResponse.LoanBasicInfo.PassDue;

        FEC_Customer_History__c rec = new FEC_Customer_History__c(Id = customerHistoryId);

        if (loan != null) {
            rec.FEC_Contract_Number__c  = loan.ContractNumber;
            // Chỉ ghi ContractNumber từ API khi có giá trị, tránh ghi đè làm mất số đang dùng làm param gọi API
            if (String.isNotBlank(loan.ContractNumber)) {
                rec.FEC_Contract_Number__c = loan.ContractNumber;
            }
            rec.FEC_Contract_Type__c    = loan.ContractType;
            rec.FEC_Contract_Status__c  = loan.ContractStatus;
            rec.FEC_Agreement_Date__c   = loan.AgreementDate;
            rec.FEC_Application_ID__c   = loan.ApplicationID;
            rec.FEC_Company_Name__c     = loan.CompanyName;
        }

        /* Product Code chỉ lấy từ GetCardBasicInfo → FEC_Customer_History__c.FEC_Product_Code__c */
        rec.FEC_Product_Code__c = productCodeFromCard;

        if (product != null) {
            rec.FEC_Charge_Off_Date__c            = product.ChargeOffDate;
            rec.FEC_Rate__c                       = product.Rate;
            rec.FEC_Account_Status_Change_Date__c = product.ClosureDate;
            rec.FEC_Loan_Amount__c                = product.LoanAmount;
            rec.FEC_EMI__c                        = product.EMI;
            rec.FEC_Tenure__c                     = product.Tenure;
            rec.FEC_Insurance_Amount__c           = product.InsuranceAmount;
            rec.FEC_First_Payment_Date__c         = product.FirstPaymentDate;
            rec.FEC_Last_Payment_Date__c          = product.LastPaymentDate;
        }

        FEC_GetLoanBasicInfo.TerminationSimulation termSim = loanResponse.LoanBasicInfo.TerminationSimulation;
        if (termSim != null) {
            rec.FEC_Next_Due_Date__c = termSim.NextDueDate;
        }

        if (passDue != null) {
            rec.FEC_Days_Past_Due__c = passDue.DPD;
        }

        rec.FEC_Scheme_ID__c              = schemeID;
        rec.FEC_Scheme_Desc__c            = schemeDesc;
        rec.FEC_Installments_Remaining__c = installmentsRemaining;

        update rec;
    }

    /* Extract schemeID/schemeDesc from GetCustomerList by contractNumber */

    private static Map<String, String> extractScheme(
        FEC_GetCustomerList.ResponseWrapper response,
        String contractNumber
    ) {
        Map<String, String> scheme = new Map<String, String>();
        if (response?.Customers == null || response.Customers.isEmpty()) {
            return scheme;
        }

        for (FEC_GetCustomerList.Customer customer : response.Customers) {
            if (customer.Applications == null) continue;
            for (FEC_GetCustomerList.Application app : customer.Applications) {
                if (String.isNotBlank(contractNumber)
                    && contractNumber.equals(app.ContractNumber)) {
                    scheme.put('schemeID', app.SchemeID);
                    scheme.put('schemeDesc', app.SchemeDesc);
                    return scheme;
                }
            }
        }
        return scheme;
    }

}
