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
        if (String.isBlank(contractNumber)) {
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

        saveApiDataToCustomerHistory(c.FEC_Account_or_Contract__c, loanResponse, schemeID, schemeDesc, installmentsRemaining);
    }

    /** Load Loan Account Info: gọi API trực tiếp, map response → result, ghi DB là side effect. */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadLoanAccountInfo(Id caseId) {
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
            return new Map<String, Object>();
        }

        List<FEC_Customer_History__c> chList = [
            SELECT Id, FEC_Contract_Number__c, FEC_Account_Number__c,
                   FEC_Contract_Type__c, FEC_Contract_Status__c, FEC_Agreement_Date__c,
                   FEC_Application_ID__c, FEC_Company_Name__c, FEC_Account_Status_Change_Date__c,
                   FEC_Product_Code__c, FEC_Charge_Off_Date__c, FEC_Rate__c,
                   FEC_Loan_Amount__c, FEC_EMI__c, FEC_Tenure__c, FEC_Insurance_Amount__c,
                   FEC_First_Payment_Date__c, FEC_Last_Payment_Date__c, FEC_Next_Due_Date__c,
                   FEC_Days_Past_Due__c, FEC_Scheme_ID__c, FEC_Scheme_Desc__c,
                   FEC_Installments_Remaining__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
        if (chList.isEmpty()) {
            return new Map<String, Object>();
        }
        FEC_Customer_History__c ch = chList[0];

        String contractNumber = ch.FEC_Contract_Number__c;
        String accountNumber  = ch.FEC_Account_Number__c;

        if (String.isBlank(contractNumber)) {
            return mapCustomerHistoryToResult(ch);
        }

        String transId     = FEC_CommonUltils.generateTransactionId();
        String dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);

        // Gọi API GetLoanBasicInfo
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse = null;
        try {
            loanResponse = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, contractNumber
            );
        } catch (Exception e) {
            System.debug('### GET LOAN BASIC INFO ERROR: ' + e.getMessage());
        }

        // Gọi API GetCustomerList (lấy scheme)
        String schemeID = null;
        String schemeDesc = null;
        if (String.isNotBlank(accountNumber)) {
            try {
                FEC_GetCustomerList.ResponseWrapper custResponse = FEC_GetCustomerList.getCustomerList(
                    FEC_ConstantCommon.REQUESTOR_CRM, null, false, null, null, null, null,
                    accountNumber, null, null, null
                );
                Map<String, String> scheme = extractScheme(custResponse, contractNumber);
                schemeID   = scheme.get('schemeID');
                schemeDesc = scheme.get('schemeDesc');
            } catch (Exception e) {
                System.debug('### GET CUSTOMER LIST ERROR: ' + e.getMessage());
            }
        }

        // Gọi API GetLoanSecInfo
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

        // Ghi DB (side effect, không ảnh hưởng data trả về)
        saveApiDataToCustomerHistory(c.FEC_Account_or_Contract__c, loanResponse, schemeID, schemeDesc, installmentsRemaining);

        // Map trực tiếp từ API response nếu có, fallback về DB
        return mapApiResponseToResult(ch, loanResponse, schemeID, schemeDesc, installmentsRemaining);
    }

    private static Map<String, Object> mapApiResponseToResult(
        FEC_Customer_History__c ch,
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse,
        String schemeID,
        String schemeDesc,
        Integer installmentsRemaining
    ) {
        FEC_GetLoanBasicInfo.Loan    loan    = loanResponse?.LoanBasicInfo?.Loan;
        FEC_GetLoanBasicInfo.Product product = loanResponse?.LoanBasicInfo?.Product;
        FEC_GetLoanBasicInfo.TerminationSimulation termSim = loanResponse?.LoanBasicInfo?.TerminationSimulation;
        FEC_GetLoanBasicInfo.PassDue passDue = loanResponse?.LoanBasicInfo?.PassDue;

        Map<String, Object> result = new Map<String, Object>();

        result.put('contractNumber',         loan != null && String.isNotBlank(loan.ContractNumber) ? loan.ContractNumber : ch.FEC_Contract_Number__c);
        result.put('contractStatus',         loan != null ? loan.ContractStatus        : ch.FEC_Contract_Status__c);
        result.put('agreementDate',          loan != null ? FEC_CommonUltils.formatDateDDMMYYYY(loan.AgreementDate) : FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Agreement_Date__c));
        result.put('contractType',           loan != null ? loan.ContractType          : ch.FEC_Contract_Type__c);
        result.put('applicationId',          loan != null ? loan.ApplicationID         : ch.FEC_Application_ID__c);
        result.put('companyName',            loan != null ? loan.CompanyName           : ch.FEC_Company_Name__c);
        result.put('accountStatusChangeDate',product != null ? FEC_CommonUltils.formatDateDDMMYYYY(product.ClosureDate) : FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Account_Status_Change_Date__c));
        result.put('productCode',            product != null ? product.Product         : ch.FEC_Product_Code__c);
        result.put('chargeOffDate',          product != null ? FEC_CommonUltils.formatDate(product.ChargeOffDate) : FEC_CommonUltils.formatDate(ch.FEC_Charge_Off_Date__c));
        result.put('rate',                   product != null && product.Rate != null ? String.valueOf(product.Rate) + '%' : (ch.FEC_Rate__c != null ? String.valueOf(ch.FEC_Rate__c) + '%' : null));
        result.put('loanAmount',             product != null ? FEC_CommonUltils.formatCurrency(product.LoanAmount, 0) : FEC_CommonUltils.formatCurrency(ch.FEC_Loan_Amount__c, 0));
        result.put('emi',                    product != null ? FEC_CommonUltils.formatCurrency(product.EMI, 0)        : FEC_CommonUltils.formatCurrency(ch.FEC_EMI__c, 0));
        result.put('tenure',                 product != null && product.Tenure != null ? String.valueOf(product.Tenure) : (ch.FEC_Tenure__c != null ? String.valueOf(ch.FEC_Tenure__c) : null));
        result.put('insuranceAmount',        product != null ? FEC_CommonUltils.formatCurrency(product.InsuranceAmount, 0) : FEC_CommonUltils.formatCurrency(ch.FEC_Insurance_Amount__c, 0));
        result.put('firstPaymentDate',       product != null ? FEC_CommonUltils.formatDateDDMMYYYY(product.FirstPaymentDate) : FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_First_Payment_Date__c));
        result.put('lastPaymentDate',        product != null ? FEC_CommonUltils.formatDateDDMMYYYY(product.LastPaymentDate)  : FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Last_Payment_Date__c));
        result.put('nextDueDate',            termSim != null ? FEC_CommonUltils.formatDateDDMMYYYY(termSim.NextDueDate) : FEC_CommonUltils.formatDateDDMMYYYY(ch.FEC_Next_Due_Date__c));
        result.put('daysPastDue',            passDue != null && passDue.DPD != null ? String.valueOf(passDue.DPD) : (ch.FEC_Days_Past_Due__c != null ? String.valueOf(ch.FEC_Days_Past_Due__c) : null));
        result.put('schemeID',               schemeID   != null ? schemeID   : ch.FEC_Scheme_ID__c);
        result.put('schemeDesc',             schemeDesc != null ? schemeDesc : ch.FEC_Scheme_Desc__c);
        result.put('installmentRemaining',   installmentsRemaining != null ? String.valueOf(installmentsRemaining) : (ch.FEC_Installments_Remaining__c != null ? String.valueOf(ch.FEC_Installments_Remaining__c) : null));
        result.put('helpTexts',              FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));

        return result;
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
        Integer installmentsRemaining
    ) {
        if (customerHistoryId == null || loanResponse?.LoanBasicInfo == null) {
            return;
        }

        FEC_GetLoanBasicInfo.Loan loan       = loanResponse.LoanBasicInfo.Loan;
        FEC_GetLoanBasicInfo.Product product  = loanResponse.LoanBasicInfo.Product;
        FEC_GetLoanBasicInfo.PassDue passDue  = loanResponse.LoanBasicInfo.PassDue;

        FEC_Customer_History__c rec = new FEC_Customer_History__c(Id = customerHistoryId);

        if (loan != null) {
            // Chỉ ghi ContractNumber từ API khi có giá trị (không gán loan.ContractNumber trước — null sẽ bị update vào DB và xóa số đã lưu).
            if (String.isNotBlank(loan.ContractNumber)) {
                rec.FEC_Contract_Number__c = loan.ContractNumber;
            }
            rec.FEC_Contract_Type__c    = loan.ContractType;
            String contractStatusValue = resolveContractStatusPicklistValue(loan.ContractStatus);
            if (contractStatusValue != null) {
                rec.FEC_Contract_Status__c = contractStatusValue;
            }
            rec.FEC_Agreement_Date__c   = loan.AgreementDate;
            rec.FEC_Application_ID__c   = loan.ApplicationID;
            rec.FEC_Company_Name__c     = loan.CompanyName;
        }

        if (product != null) {
            rec.FEC_Product_Code__c               = product.Product;
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

    /** CIF trả CHARGE OFF; picklist Closed_Active_Charge_Off dùng Charge-Off / Active / Closed. */
    private static String resolveContractStatusPicklistValue(String apiStatus) {
        if (String.isBlank(apiStatus)) {
            return null;
        }
        String normalized = apiStatus.trim().toUpperCase().replaceAll('[^A-Z0-9]', '');
        Map<String, String> known = new Map<String, String>{
            'CHARGEOFF' => 'Charge-Off',
            'ACTIVE'    => 'Active',
            'CLOSED'    => 'Closed'
        };
        if (known.containsKey(normalized)) {
            return known.get(normalized);
        }
        for (Schema.PicklistEntry entry :
            FEC_Customer_History__c.FEC_Contract_Status__c.getDescribe().getPicklistValues()) {
            String valueKey = entry.getValue().toUpperCase().replaceAll('[^A-Z0-9]', '');
            String labelKey = entry.getLabel().toUpperCase().replaceAll('[^A-Z0-9]', '');
            if (valueKey == normalized || labelKey == normalized) {
                return entry.getValue();
            }
        }
        return null;
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
