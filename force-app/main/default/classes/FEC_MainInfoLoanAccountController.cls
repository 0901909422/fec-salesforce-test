/** Controller LWC fec_MainInfoLoanAccount. Load từ API; ghi FEC_Customer_History__c sau khi API thành công. */
public without sharing class FEC_MainInfoLoanAccountController {

    private class LoanAccountContext {
        Id customerHistoryId;
        String contractNumber;
        String accountNumber;
        String applicationId;
    }

    /** Sync Loan Account từ API (GetLoanBasicInfo + GetCustomerList + GetLoanSecInfo) → FEC_Customer_History__c. */
    @AuraEnabled
    public static void syncLoanAccountFromAPI(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        LoanAccountContext ctx = resolveLoanAccountContext(caseId);
        if (ctx == null) {
            return;
        }
        if (String.isBlank(ctx.contractNumber)) {
            return;
        }

        ApiLoanAccountData apiData = fetchLoanAccountFromApis(
            ctx.contractNumber,
            ctx.accountNumber,
            ctx.applicationId
        );
        saveApiDataToCustomerHistory(
            ctx.customerHistoryId,
            apiData.loanResponse,
            apiData.schemeID,
            apiData.schemeDesc,
            apiData.installmentsRemaining
        );
    }

    /** Load Loan Account Info: chỉ map từ API; không fallback FEC_Customer_History__c. */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadLoanAccountInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'})
            );
        }

        LoanAccountContext ctx = resolveLoanAccountContext(caseId);
        if (ctx == null) {
            return new Map<String, Object>();
        }
        if (String.isBlank(ctx.contractNumber)) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ContractNumber'})
            );
        }

        ApiLoanAccountData apiData = fetchLoanAccountFromApis(
            ctx.contractNumber,
            ctx.accountNumber,
            ctx.applicationId
        );

        saveApiDataToCustomerHistory(
            ctx.customerHistoryId,
            apiData.loanResponse,
            apiData.schemeID,
            apiData.schemeDesc,
            apiData.installmentsRemaining
        );

        return mapApiResponseToResult(
            apiData.loanResponse,
            apiData.schemeID,
            apiData.schemeDesc,
            apiData.installmentsRemaining
        );
    }

    private class ApiLoanAccountData {
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse;
        String schemeID;
        String schemeDesc;
        Integer installmentsRemaining;
    }

    /** Chỉ lấy Id + số HĐ/tài khoản từ Case lookup — không load field hiển thị từ DB. */
    private static LoanAccountContext resolveLoanAccountContext(Id caseId) {
        List<Case> cases = [
            SELECT Id,
                   FEC_Contract_Number__c,
                   FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Application_ID__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
            return null;
        }

        Case c = cases[0];
        LoanAccountContext ctx = new LoanAccountContext();
        ctx.customerHistoryId = c.FEC_Account_or_Contract__c;
        ctx.contractNumber = resolveContractNumber(c);
        ctx.accountNumber = c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        ctx.applicationId = c.FEC_Account_or_Contract__r.FEC_Application_ID__c;
        return ctx;
    }

    /** Ưu tiên FEC_Contract_Number__c trên Customer History; fallback Case.FEC_Contract_Number__c. */
    private static String resolveContractNumber(Case c) {
        String histContractNumber = c.FEC_Account_or_Contract__r.FEC_Contract_Number__c;
        if (String.isNotBlank(histContractNumber)) {
            return histContractNumber;
        }
        return String.isNotBlank(c.FEC_Contract_Number__c) ? c.FEC_Contract_Number__c : null;
    }

    private static ApiLoanAccountData fetchLoanAccountFromApis(
        String contractNumber,
        String accountNumber,
        String applicationId
    ) {
        String transId = FEC_CommonUltils.generateTransactionId();
        String dateTimeStr = Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT);

        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            ApiLoanAccountData data = new ApiLoanAccountData();

            try {
                data.loanResponse = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                    transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, contractNumber
                );
            } catch (Exception e) {
                throw new AuraHandledException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{e.getMessage()})
                );
            } finally {
                FEC_GetLoanBasicInfo.logApiResponse();
            }

            fetchSchemeFromCustomerList(data, contractNumber, accountNumber, applicationId);

            try {
                FEC_GetLoanSecInfo.ResponseWrapper secResponse = FEC_GetLoanSecInfo.callGetLoanSecInfo(
                    transId, FEC_ConstantCommon.REQUESTOR_CRM, dateTimeStr, contractNumber
                );
                if (secResponse?.LoanSecInfo?.PassDue != null) {
                    data.installmentsRemaining = secResponse.LoanSecInfo.PassDue.InstallmentsRemaining;
                }
            } catch (Exception e) {
                System.debug('### GET LOAN SEC INFO ERROR: ' + e.getMessage());
            }

            return data;
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }
    }

    private static Map<String, Object> mapApiResponseToResult(
        FEC_GetLoanBasicInfo.ResponseWrapper loanResponse,
        String schemeID,
        String schemeDesc,
        Integer installmentsRemaining
    ) {
        if (loanResponse?.LoanBasicInfo == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{'LoanBasicInfo'})
            );
        }

        FEC_GetLoanBasicInfo.Loan loan = loanResponse.LoanBasicInfo.Loan;
        FEC_GetLoanBasicInfo.Product product = loanResponse.LoanBasicInfo.Product;
        FEC_GetLoanBasicInfo.TerminationSimulation termSim = loanResponse.LoanBasicInfo.TerminationSimulation;
        FEC_GetLoanBasicInfo.PassDue passDue = loanResponse.LoanBasicInfo.PassDue;

        Map<String, Object> result = new Map<String, Object>();

        result.put('contractNumber', loan?.ContractNumber);
        result.put('contractStatus', loan?.ContractStatus);
        result.put('agreementDate', FEC_CommonUltils.formatDateDDMMYYYY(loan?.AgreementDate));
        result.put('contractType', loan?.ContractType);
        result.put('applicationId', loan?.ApplicationID);
        result.put('companyName', loan?.CompanyName);
        result.put('accountStatusChangeDate', FEC_CommonUltils.formatDateDDMMYYYY(product?.ClosureDate));
        result.put('productCode', String.isNotBlank(product?.Product) ? product.Product : null);
        result.put('chargeOffDate', FEC_CommonUltils.formatDate(product?.ChargeOffDate));
        result.put('rate', product?.Rate != null ? String.valueOf(product.Rate) + '%' : null);
        result.put('loanAmount', FEC_CommonUltils.formatCurrency(product?.LoanAmount, 0));
        result.put('emi', FEC_CommonUltils.formatCurrency(product?.EMI, 0));
        result.put('tenure', product?.Tenure != null ? String.valueOf(product.Tenure) : null);
        result.put('insuranceAmount', FEC_CommonUltils.formatCurrency(product?.InsuranceAmount, 0));
        result.put('firstPaymentDate', FEC_CommonUltils.formatDateDDMMYYYY(product?.FirstPaymentDate));
        result.put('lastPaymentDate', FEC_CommonUltils.formatDateDDMMYYYY(product?.LastPaymentDate));
        result.put('nextDueDate', FEC_CommonUltils.formatDateDDMMYYYY(termSim?.NextDueDate));
        result.put('daysPastDue', passDue?.DPD != null ? String.valueOf(passDue.DPD) : null);
        result.put('schemeID', schemeID);
        result.put('schemeDesc', schemeDesc);
        result.put('installmentRemaining', installmentsRemaining != null ? String.valueOf(installmentsRemaining) : null);
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
            if (String.isNotBlank(product.Product)) {
                rec.FEC_Product_Code__c = product.Product;
            }
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
        String normalized = apiStatus.trim().toUpperCase()
            .replaceAll(FEC_ConstantCommon.PATTERN_NON_ALNUM_UPPER, FEC_ConstantCommon.STR_EMPTY);
        if (FEC_ConstantCommon.API_CONTRACT_STATUS_TO_PICKLIST.containsKey(normalized)) {
            return FEC_ConstantCommon.API_CONTRACT_STATUS_TO_PICKLIST.get(normalized);
        }
        for (Schema.PicklistEntry entry :
            FEC_Customer_History__c.FEC_Contract_Status__c.getDescribe().getPicklistValues()) {
            String valueKey = entry.getValue().toUpperCase()
                .replaceAll(FEC_ConstantCommon.PATTERN_NON_ALNUM_UPPER, FEC_ConstantCommon.STR_EMPTY);
            String labelKey = entry.getLabel().toUpperCase()
                .replaceAll(FEC_ConstantCommon.PATTERN_NON_ALNUM_UPPER, FEC_ConstantCommon.STR_EMPTY);
            if (valueKey == normalized || labelKey == normalized) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static void fetchSchemeFromCustomerList(
        ApiLoanAccountData data,
        String contractNumber,
        String accountNumber,
        String applicationId
    ) {
        String resolvedApplicationId = String.isNotBlank(applicationId)
            ? applicationId
            : data.loanResponse?.LoanBasicInfo?.Loan?.ApplicationID;

        if (String.isBlank(accountNumber)
            && String.isBlank(resolvedApplicationId)
            && String.isBlank(contractNumber)) {
            return;
        }

        try {
            FEC_GetCustomerList.ResponseWrapper custResponse = callGetCustomerListForScheme(
                accountNumber,
                resolvedApplicationId,
                contractNumber
            );
            Map<String, String> scheme = extractScheme(
                custResponse,
                contractNumber,
                resolvedApplicationId
            );
            data.schemeID = scheme.get('schemeID');
            data.schemeDesc = scheme.get('schemeDesc');
        } catch (Exception e) {
            if (FEC_GetCustomerList.responseLog != null) {
                FEC_GetCustomerList.responseLog.errorMessage = e.getMessage();
            }
            System.debug('### GET CUSTOMER LIST ERROR: ' + e.getMessage());
        } finally {
            FEC_CommonUltils.logApiResponse(FEC_GetCustomerList.responseLog);
        }
    }

    private static FEC_GetCustomerList.ResponseWrapper callGetCustomerListForScheme(
        String accountNumber,
        String applicationId,
        String contractNumber
    ) {
        if (String.isNotBlank(accountNumber)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_CRM, null, false, null, null, null, null,
                accountNumber, null, null, null
            );
        }
        if (String.isNotBlank(applicationId)) {
            return FEC_GetCustomerList.getCustomerList(
                FEC_ConstantCommon.REQUESTOR_CRM, null, false, null, null, applicationId, null,
                null, null, null, null
            );
        }
        return FEC_GetCustomerList.getCustomerList(
            FEC_ConstantCommon.REQUESTOR_CRM, null, false, null, null, null, null,
            null, contractNumber, null, null
        );
    }

    /* Extract schemeID/schemeDesc from GetCustomerList by contractNumber or applicationId */

    private static Map<String, String> extractScheme(
        FEC_GetCustomerList.ResponseWrapper response,
        String contractNumber,
        String applicationId
    ) {
        Map<String, String> scheme = new Map<String, String>();
        if (response?.Customers == null || response.Customers.isEmpty()) {
            return scheme;
        }

        for (FEC_GetCustomerList.Customer customer : response.Customers) {
            if (customer.Applications == null) {
                continue;
            }
            for (FEC_GetCustomerList.Application app : customer.Applications) {
                Boolean contractMatch = String.isNotBlank(contractNumber)
                    && contractNumber.equals(app.ContractNumber);
                Boolean applicationMatch = String.isNotBlank(applicationId)
                    && applicationId.equals(app.ApplicationID);
                if (contractMatch || applicationMatch) {
                    scheme.put('schemeID', app.SchemeID);
                    scheme.put('schemeDesc', app.SchemeDesc);
                    return scheme;
                }
            }
        }
        return scheme;
    }

}
