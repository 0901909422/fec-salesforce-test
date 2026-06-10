/** Controller LWC fec_SecondaryInfoLoanAccount. Hiển thị từ API; ghi FEC_Customer_History__c sau khi API thành công. */
public without sharing class FEC_SecondaryInfoLoanAccountController {

    private class SecondaryLoanContext {
        Id customerHistoryId;
        String contractNumber;
        String applicationId;
    }

    private class ApiBundle {
        FEC_GetLoanBasicInfo.ResponseWrapper loanBasic;
        FEC_GetLoanSecInfo.ResponseWrapper loanSec;
        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleDisburse;
    }

    /* ===================== LOAD DISBURSEMENT (INIT SCREEN) ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadSecondaryLoanInfo(Id caseId) {
        return loadSecondaryLoanDisbursement(caseId);
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadSecondaryLoanDisbursement(Id caseId) {
        SecondaryLoanContext ctx = resolveContext(caseId);
        ApiBundle bundle = new ApiBundle();

        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            String applicationId = resolveApplicationId(ctx, bundle, true);
            bundle.saleDisburse = callSaleDisburseRequired(applicationId);
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        saveApiDataToCustomerHistory(ctx.customerHistoryId, bundle);
        return mapDisbursementResult(bundle);
    }

    /* ===================== LAZY: COLLECTIONS ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadSecondaryLoanCollections(Id caseId) {
        SecondaryLoanContext ctx = resolveContext(caseId);
        if (String.isBlank(ctx.contractNumber)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        ApiBundle bundle = new ApiBundle();
        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            bundle.loanBasic = callLoanBasicRequired(ctx.contractNumber);
            bundle.loanSec = callLoanSecRequired(ctx.contractNumber);
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        saveApiDataToCustomerHistory(ctx.customerHistoryId, bundle);
        return mapCollectionsResult(bundle);
    }

    /* ===================== LAZY: SALES ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> loadSecondaryLoanSales(Id caseId) {
        SecondaryLoanContext ctx = resolveContext(caseId);
        ApiBundle bundle = new ApiBundle();

        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            String applicationId = resolveApplicationId(ctx, bundle, true);
            bundle.saleDisburse = callSaleDisburseRequired(applicationId);
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        saveApiDataToCustomerHistory(ctx.customerHistoryId, bundle);
        return mapSalesResult(bundle);
    }

    /* ===================== REFRESH BUTTON ===================== */

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> refreshSecondaryLoanInfo(Id caseId) {
        SecondaryLoanContext ctx = resolveContext(caseId);
        if (String.isBlank(ctx.contractNumber)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        ApiBundle bundle = new ApiBundle();
        FEC_CommonUltils.beginDeferredApiLogging();
        try {
            bundle.loanBasic = callLoanBasicRequired(ctx.contractNumber);
            bundle.loanSec = callLoanSecRequired(ctx.contractNumber);
            String applicationId = resolveApplicationIdFromBundle(ctx, bundle);
            if (String.isNotBlank(applicationId)) {
                bundle.saleDisburse = callSaleDisburseRequired(applicationId);
            }
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        saveApiDataToCustomerHistory(ctx.customerHistoryId, bundle);
        return mapFullResult(bundle);
    }

    /* ===================== CONTEXT & API CALLS ===================== */

    /** Chỉ lấy Id + số HĐ/Application từ Case lookup — không load field hiển thị từ DB. */
    private static SecondaryLoanContext resolveContext(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' })
            );
        }

        List<Case> cases = [
            SELECT FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                   FEC_Account_or_Contract__r.FEC_Application_ID__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        Case c = cases[0];
        SecondaryLoanContext ctx = new SecondaryLoanContext();
        ctx.customerHistoryId = c.FEC_Account_or_Contract__c;
        ctx.contractNumber = c.FEC_Account_or_Contract__r.FEC_Contract_Number__c;
        ctx.applicationId = c.FEC_Account_or_Contract__r.FEC_Application_ID__c;
        return ctx;
    }

    private static String resolveApplicationId(
        SecondaryLoanContext ctx,
        ApiBundle bundle,
        Boolean required
    ) {
        String applicationId = ctx.applicationId;

        if (String.isBlank(applicationId) && String.isNotBlank(ctx.contractNumber)) {
            bundle.loanBasic = callLoanBasicRequired(ctx.contractNumber);
            applicationId = bundle.loanBasic?.LoanBasicInfo?.Loan?.ApplicationID;
        }

        if (required && String.isBlank(applicationId)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }
        return applicationId;
    }

    private static String resolveApplicationIdFromBundle(SecondaryLoanContext ctx, ApiBundle bundle) {
        String applicationId = bundle.loanBasic?.LoanBasicInfo?.Loan?.ApplicationID;
        return String.isNotBlank(applicationId) ? applicationId : ctx.applicationId;
    }

    private static FEC_GetLoanBasicInfo.ResponseWrapper callLoanBasicRequired(String contractNumber) {
        try {
            FEC_GetLoanBasicInfo.ResponseWrapper res = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                contractNumber
            );
            if (res?.LoanBasicInfo == null) {
                throw new AuraHandledException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{ 'LoanBasicInfo' })
                );
            }
            return res;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{ e.getMessage() })
            );
        } finally {
            FEC_GetLoanBasicInfo.logApiResponse();
        }
    }

    private static FEC_GetLoanSecInfo.ResponseWrapper callLoanSecRequired(String contractNumber) {
        try {
            FEC_GetLoanSecInfo.ResponseWrapper res = FEC_GetLoanSecInfo.callGetLoanSecInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                contractNumber
            );
            if (res?.LoanSecInfo == null) {
                throw new AuraHandledException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{ 'LoanSecInfo' })
                );
            }
            return res;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }
    }

    private static FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse callSaleDisburseRequired(
        String applicationId
    ) {
        if (String.isBlank(applicationId)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Error_API_Label);
        }

        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleDisburseInfoResponse saleRes =
            FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfo(applicationId);

        if (!FEC_GetCustomerSaleDisburseInfoCallout.isSuccess(saleRes)
            || FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(saleRes) == null) {
            String err = saleRes?.errorMessage;
            if (String.isBlank(err) && saleRes?.Sys != null) {
                err = saleRes.Sys.Description;
            }
            if (String.isBlank(err)) {
                err = 'CustomerSaleDisburseInfo';
            }
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{ err })
            );
        }
        return saleRes;
    }

    /* ===================== SAVE API → DB ===================== */

    private static void saveApiDataToCustomerHistory(Id customerHistoryId, ApiBundle bundle) {
        if (customerHistoryId == null || bundle == null) {
            return;
        }

        FEC_Customer_History__c rec = new FEC_Customer_History__c(Id = customerHistoryId);
        Boolean hasUpdate = false;

        if (bundle.loanBasic?.LoanBasicInfo != null) {
            if (bundle.loanBasic.LoanBasicInfo.PassDue != null) {
                rec.FEC_Responsible_Unit__c = bundle.loanBasic.LoanBasicInfo.PassDue.ResponsibleUnit;
                hasUpdate = true;
            }
            if (bundle.loanBasic.LoanBasicInfo.Loan != null
                && String.isNotBlank(bundle.loanBasic.LoanBasicInfo.Loan.ApplicationID)) {
                rec.FEC_Application_ID__c = bundle.loanBasic.LoanBasicInfo.Loan.ApplicationID;
                hasUpdate = true;
            }
        }

        if (bundle.loanSec?.LoanSecInfo?.PassDue != null) {
            FEC_GetLoanSecInfo.PassDue passDue = bundle.loanSec.LoanSecInfo.PassDue;
            rec.FEC_Responsible_Person__c = passDue.ResponsiblePerson;
            rec.FEC_Date_Assigned__c = passDue.DateAssigned;
            hasUpdate = true;
        }

        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo saleInfo =
            FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(bundle.saleDisburse);
        if (saleInfo != null) {
            rec.FEC_CC_Code__c = saleInfo.CC_CODE;
            rec.FEC_CC_Name__c = saleInfo.CC_NAME;
            rec.FEC_DSA_Code__c = saleInfo.DSA_CODE;
            rec.FEC_DSA_Name__c = saleInfo.DSA_NAME;
            rec.FEC_TSA_Code__c = saleInfo.TSA_CODE;
            rec.FEC_TSA_Name__c = saleInfo.TSA_NAME;
            rec.FEC_Bank_Name__c = saleInfo.BANK_NAME;
            rec.FEC_Branch_Name__c = saleInfo.BRANCH_NAME;
            rec.FEC_Account_Number__c = saleInfo.BANK_ACCOUNT_NUMBER;
            rec.FEC_Disbursement_Channel__c = saleInfo.DISB_CHANNEL;
            rec.FEC_Disbursement_Date__c = FEC_CommonUltils.parseDate(saleInfo.DATE_STATUS);
            rec.FEC_Is_Top_Up_Account__c = saleInfo.TOPUP_FLAG;
            rec.FEC_Top_Up_Loan_Amount_Requested__c = saleInfo.TOP_UP_LOAN_AMT;
            rec.FEC_Top_Up_Old_A_c_Outstanding__c = saleInfo.TOP_UP_OLD_AC_OUSTANDING;
            rec.FEC_Top_Up_Old_Account_App_ID__c = saleInfo.TOP_UP_AGREEMENT_ID;
            hasUpdate = true;
        }

        if (hasUpdate) {
            update rec;
        }
    }

    /* ===================== MAP API → RESULT SLICES ===================== */

    private static Map<String, Object> mapFullResult(ApiBundle bundle) {
        Map<String, Object> result = new Map<String, Object>();
        putDisbursementFieldsFromApi(result, bundle);
        putCollectionsFieldsFromApi(result, bundle);
        putSalesFieldsFromApi(result, bundle);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));
        return result;
    }

    private static Map<String, Object> mapDisbursementResult(ApiBundle bundle) {
        Map<String, Object> result = new Map<String, Object>();
        putDisbursementFieldsFromApi(result, bundle);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));
        return result;
    }

    private static Map<String, Object> mapCollectionsResult(ApiBundle bundle) {
        Map<String, Object> result = new Map<String, Object>();
        putCollectionsFieldsFromApi(result, bundle);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));
        return result;
    }

    private static Map<String, Object> mapSalesResult(ApiBundle bundle) {
        Map<String, Object> result = new Map<String, Object>();
        putDisbursementFieldsFromApi(result, bundle);
        putCollectionsFieldsFromApi(result, bundle);
        putSalesFieldsFromApi(result, bundle);
        result.put('helpTexts', FEC_CommonUltils.buildHelpTextMap(FEC_Customer_History__c.SObjectType));
        return result;
    }

    private static void putDisbursementFieldsFromApi(Map<String, Object> result, ApiBundle bundle) {
        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo s =
            FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(bundle?.saleDisburse);
        if (s == null) {
            return;
        }

        result.put('bankName', s.BANK_NAME);
        result.put('branchName', s.BRANCH_NAME);
        result.put('accountNumber', s.BANK_ACCOUNT_NUMBER);
        result.put('disbursementChannel', s.DISB_CHANNEL);
        result.put('disbursementDate', FEC_CommonUltils.formatDateDDMMYYYY(FEC_CommonUltils.parseDate(s.DATE_STATUS)));
        result.put(
            'isTopUpAccount',
            s.TOPUP_FLAG == null ? null : (s.TOPUP_FLAG == 'Y' ? 'Yes' : 'No')
        );
        result.put('topUpLoanAmountRequested', FEC_CommonUltils.formatCurrency(s.TOP_UP_LOAN_AMT, 2));
        result.put('topUpOldAcOutstanding', FEC_CommonUltils.formatCurrency(s.TOP_UP_OLD_AC_OUSTANDING, 2));
        result.put('topUpOldAcAppId', s.TOP_UP_AGREEMENT_ID);
    }

    private static void putCollectionsFieldsFromApi(Map<String, Object> result, ApiBundle bundle) {
        if (bundle?.loanBasic?.LoanBasicInfo?.PassDue != null) {
            result.put('responsibleUnit', bundle.loanBasic.LoanBasicInfo.PassDue.ResponsibleUnit);
        }

        if (bundle?.loanSec?.LoanSecInfo?.PassDue != null) {
            FEC_GetLoanSecInfo.PassDue passDue = bundle.loanSec.LoanSecInfo.PassDue;
            result.put('responsiblePerson', passDue.ResponsiblePerson);
            result.put(
                'dateAssigned',
                passDue.DateAssigned != null ? FEC_CommonUltils.formatDate(passDue.DateAssigned) : '0'
            );
        }
    }

    private static void putSalesFieldsFromApi(Map<String, Object> result, ApiBundle bundle) {
        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo s =
            FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(bundle?.saleDisburse);
        if (s == null) {
            return;
        }

        result.put('ccCode', s.CC_CODE);
        result.put('ccName', s.CC_NAME);
        result.put('dsaCode', s.DSA_CODE);
        result.put('dsaName', s.DSA_NAME);
        result.put('tsaCode', s.TSA_CODE);
        result.put('tsaName', s.TSA_NAME);
    }
}
