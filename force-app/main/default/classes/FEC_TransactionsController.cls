/****************************************************************************************
 * File Name    : FEC_TransactionsController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_TransactionsController {

    private static final String M_FAS_API_CONFIG = 'FEC_MFASOUTSTANDINGAUTHINQ';

    public class TransactionDTO {
        @AuraEnabled public Map<String, String> helpTexts;

        @AuraEnabled public Id Id;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date postingDate;
        @AuraEnabled public Decimal transactionAmount;
        @AuraEnabled public String merchantDescription;
        @AuraEnabled public String creditDebitFlag;
        @AuraEnabled public String transactionPlan;
        @AuraEnabled public String transactionCode;
        @AuraEnabled public String authorizationCode;
        @AuraEnabled public String merchantCategoryCode;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String otpSent;

        // realtime only
        @AuraEnabled public String approvalCode;
        @AuraEnabled public String authorizationResponse;
        @AuraEnabled public String declineReasonCode;
        @AuraEnabled public String declineDescription;
    }

    public class TransactionsResponse {
        @AuraEnabled public List<TransactionDTO> unbilledTransactions;
        @AuraEnabled public List<TransactionDTO> pendingTransactions;
    }

    /* =====================================================
       MAIN
       ===================================================== */
    @AuraEnabled(cacheable=false)
    public static TransactionsResponse loadTransactions(Id caseId) {
        
        Case c = [
            SELECT FEC_Account_or_Contract__c, FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
        ];
        
        FEC_Customer_History__c ch = [
            SELECT Id, FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
        ];

        String accNumber = FEC_CommonUltils.resolveAccountNumber(
            c.FEC_Product_Type__r.Name,
            ch.FEC_Account_Number__c,
            ch.FEC_Contract_Number__c
        );
    
        TransactionsResponse res = new TransactionsResponse();
        res.unbilledTransactions = new List<TransactionDTO>();
        res.pendingTransactions  = new List<TransactionDTO>();

        /* ===============================
           HISTORY - CALL OUT
           =============================== */
        List<FEC_GetUnbilledTransactions.TransactionRecord> unbilled =
            callUnbilledSafe(accNumber);

        List<FEC_GetCardFinancialTransactions.FinancialTransaction> financial =
            callFinancialSafe(accNumber);

        FEC_GetCardBasicInfo.ResponseWrapper cardBasicRes = callCardBasicSafe(accNumber);
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTxns =
            (cardBasicRes != null
                && cardBasicRes.CardBasicInfo != null
                && cardBasicRes.CardBasicInfo.Transactions != null)
                    ? cardBasicRes.CardBasicInfo.Transactions
                    : new List<FEC_GetCardBasicInfo.TransactionInfo>();

        Map<String, String> trnxCurrencyByKey = buildTrnxCurrencyCodeByKey(cardTxns);
        Set<String> numericCodes = new Set<String>();
        for (String code : trnxCurrencyByKey.values()) {
            if (!String.isBlank(code)) {
                numericCodes.add(code);
            }
        }
        for (FEC_GetUnbilledTransactions.TransactionRecord u : unbilled) {
            if (!String.isBlank(u.CurrencyCode)) {
                numericCodes.add(u.CurrencyCode.trim());
            }
        }
        Map<String, String> currencyDisplayMap =
            FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(numericCodes);

        /* ===============================
           PENDING - CALL OUT
           =============================== */
        res.pendingTransactions = loadPendingRealtime(accNumber);

        /* ===============================
           HISTORY
           =============================== */
        if (!unbilled.isEmpty()) {
            upsertHistory(ch.Id, unbilled, financial, trnxCurrencyByKey, currencyDisplayMap);
            res.unbilledTransactions = loadHistoryForUI(ch.Id);
        }

        return res;
    }

    /* =====================================================
       HISTORY – LOAD UI
       ===================================================== */
    private static List<TransactionDTO> loadHistoryForUI(Id customerHistoryId) {

        List<TransactionDTO> result = new List<TransactionDTO>();

        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Effective_Date__c,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Merchant_Description__c,
                   FEC_Credit_Debit_Flag__c,
                   FEC_Transaction_Plan__c,
                   FEC_Transaction_Code__c,
                   FEC_Authorization_Code__c,
                   FEC_Merchant_Category_Code__c,
                   FEC_Currency_Code__c,
                   FEC_OTP_Sent__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :customerHistoryId
            ORDER BY FEC_Effective_Date__c DESC
        ]) {
            result.add(mapHistory(tx));
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static TransactionDTO loadTransactionDetail(Id transactionId) {
        if (transactionId == null) return null;

        FEC_Transaction__c tx = [
            SELECT Id,
                FEC_Effective_Date__c,
                FEC_Post_Date__c,
                FEC_Transaction_Amount__c,
                FEC_Merchant_Description__c,
                FEC_Credit_Debit_Flag__c,
                FEC_Transaction_Plan__c,
                FEC_Transaction_Code__c,
                FEC_Authorization_Code__c,
                FEC_Merchant_Category_Code__c,
                FEC_Currency_Code__c,
                FEC_OTP_Sent__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        TransactionDTO dto = mapHistory(tx);
        return dto;
    }

    private static TransactionDTO mapHistory(FEC_Transaction__c tx) {
        TransactionDTO dto = new TransactionDTO();
        dto.Id = tx.Id;
        dto.effectiveDate = tx.FEC_Effective_Date__c;
        dto.postingDate = tx.FEC_Post_Date__c;
        dto.transactionAmount = tx.FEC_Transaction_Amount__c;
        dto.merchantDescription = tx.FEC_Merchant_Description__c;
        dto.creditDebitFlag = tx.FEC_Credit_Debit_Flag__c;
        dto.transactionPlan = tx.FEC_Transaction_Plan__c;
        dto.transactionCode = tx.FEC_Transaction_Code__c;
        dto.authorizationCode = tx.FEC_Authorization_Code__c;
        dto.merchantCategoryCode = tx.FEC_Merchant_Category_Code__c;
        dto.currencyCode = tx.FEC_Currency_Code__c;
        dto.otpSent = tx.FEC_OTP_Sent__c;
        dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);
        return dto;
    }

    /* =====================================================
       PENDING 
       ===================================================== */
    private static List<TransactionDTO> loadPendingRealtime(String accNumber) {
        List<TransactionDTO> result = new List<TransactionDTO>();
        String acctForApi = resolveMfasAccountNumber(
            accNumber,
            M_FAS_API_CONFIG
        );
        if (String.isBlank(acctForApi)) {
            return result;
        }

        try {
            FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper res =
                FEC_MFASOUTSTANDINGAUTHINQ.callVmxAuthDetailInqService(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    FEC_ConstantCommon.REQUESTOR_VMXVERSION,
                    FEC_ConstantCommon.REQUESTOR_CONTEXT,
                    UserInfo.getUserId(),
                    FEC_ConstantCommon.REQUESTOR_ORG,
                    acctForApi
                );

            if (res == null
                || res.VMXMsgOut == null
                || res.VMXMsgOut.Auths == null
                || res.VMXMsgOut.Auths.isEmpty()) {
                return result;
            }

            Map<String, String> helpTemplate =
                FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

            for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : res.VMXMsgOut.Auths) {
                TransactionDTO dto = mapPendingAuthRow(ar, helpTemplate);
                if (dto != null) {
                    result.add(dto);
                }
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.WARN,
                'FEC_TransactionsController.loadPendingRealtime: ' + e.getMessage()
            );
        }

        return result;
    }

    private static TransactionDTO mapPendingAuthRow(
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar,
        Map<String, String> helpTemplate
    ) {
        Date effDetail = FEC_CommonUltils.toDateStr(ar.EFF_DATE_AUTH_DETAIL);
        Date effTable = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
        if (effTable == null) {
            effTable = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
        }
        Date effPrimary = effDetail != null ? effDetail : effTable;
        if (effPrimary == null) {
            return null;
        }

        Decimal amt = parseDecimalFromApi(
            firstNonBlankStr(ar.DTL_AUTH_AMT, ar.AUTH_AMOUNT)
        );
        String merchDesc = firstNonBlankStr(ar.DTL_MERC_NAME_LOC, ar.Description);
        String plan = firstNonBlankStr(ar.DTL_CR_PLAN, ar.CREDIT_PLAN);
        String merchCat = firstNonBlankStr(ar.DTL_MERCH_CAT, ar.MERCH_CAT);
        String curr = firstNonBlankStr(ar.DTL_TXN_CURR_CODE, ar.TXN_CURR_CODE);
        String approval = firstNonBlankStr(
            ar.MSGOUT_AUTH_CD,
            firstNonBlankStr(ar.AUTH_CD, ar.AUTHORIZATION_CODE)
        );
        String authResp = firstNonBlankStr(ar.DTL_FINAL_ACTN, ar.FINAL_ACTN);
        String decline = firstNonBlankStr(ar.DTL_ACTN_RSN_DESC, ar.ACTN_RSN_DESC);

        TransactionDTO dto = new TransactionDTO();
        dto.Id = null;
        dto.helpTexts = helpTemplate;
        dto.effectiveDate = effPrimary;
        dto.transactionAmount = amt;
        dto.merchantDescription = merchDesc;
        dto.transactionPlan = plan;
        dto.merchantCategoryCode = merchCat;
        dto.currencyCode = curr;
        dto.approvalCode = approval;
        dto.authorizationResponse = authResp;
        dto.declineDescription = decline;
        return dto;
    }

    /**
     * Non-Production: account from {@code FEC_API_Config__mdt.FEC_Account_Number_Hard_Code__c}.
     * Production: Case-resolved account only (no Apex fallback).
     */
    private static String resolveMfasAccountNumber(
        String resolvedAccountNumber,
        String apiConfigDeveloperName
    ) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (String.isNotBlank(apiSetting?.FEC_Enviroment__c)
            && apiSetting.FEC_Enviroment__c
                == FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION) {
            FEC_API_Config__mdt apiConfig =
                FEC_API_Config__mdt.getInstance(apiConfigDeveloperName);
            if (String.isNotBlank(apiConfig?.FEC_Account_Number_Hard_Code__c)) {
                return apiConfig.FEC_Account_Number_Hard_Code__c.trim();
            }
        }
        if (String.isNotBlank(resolvedAccountNumber)) {
            return resolvedAccountNumber.trim();
        }
        return null;
    }

    private static String firstNonBlankStr(String a, String b) {
        if (!String.isBlank(a)) {
            return a.trim();
        }
        if (!String.isBlank(b)) {
            return b.trim();
        }
        return null;
    }

    private static Decimal parseDecimalFromApi(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Decimal.valueOf(raw.trim().replace(',', ''));
        } catch (Exception e) {
            return null;
        }
    }

    /* =====================================================
       UPSERT HISTORY
       ===================================================== */
   private static void upsertHistory(
        Id historyId,
        List<FEC_GetUnbilledTransactions.TransactionRecord> uList,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList,
        Map<String, String> trnxCurrencyByKey,
        Map<String, String> currencyDisplayMap
    ) {

        /* ===============================
           1. Build Financial map
           Key = PostDate + Amount + Debit/Credit
           =============================== */
        Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction> finMap =
            new Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction>();

        for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
            Date postDate = FEC_CommonUltils.toDateStr(f.PostingDate);
            if (postDate == null || f.TRNXAmount == null) continue;

            String key = buildKey(
                postDate,
                f.TRNXAmount,
                f.CreditDebitFlag
            );

            finMap.put(key, f);
        }

        /* ===============================
           2. Load existed transactions
           =============================== */
        Map<String, FEC_Transaction__c> existed = new Map<String, FEC_Transaction__c>();
        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Credit_Debit_Flag__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :historyId
        ]) {
            String key = buildKey(
                tx.FEC_Post_Date__c,
                tx.FEC_Transaction_Amount__c,
                tx.FEC_Credit_Debit_Flag__c
            );
            existed.put(key, tx);
        }

        /* ===============================
           3. Merge Unbilled + Financial
           =============================== */
        Map<String, FEC_Transaction__c> working = new Map<String, FEC_Transaction__c>();

        for (FEC_GetUnbilledTransactions.TransactionRecord u : uList) {
            Date postDate = FEC_CommonUltils.toDateStr(u.PostingDate);
            if (postDate == null || u.Amount == null) continue;

            String key = buildKey(
                postDate,
                u.Amount,
                u.TransactionType
            );

            FEC_Transaction__c rec =
                working.containsKey(key)
                    ? working.get(key)
                    : existed.containsKey(key)
                        ? existed.get(key)
                        : new FEC_Transaction__c(
                            FEC_Customer_History__c = historyId
                        );

            // ===== Base fields (Unbilled) =====
            rec.FEC_Effective_Date__c = FEC_CommonUltils.toDateStr(u.TransactionDate);
            rec.FEC_Post_Date__c = postDate;
            rec.FEC_Transaction_Amount__c = u.Amount;
            rec.FEC_Credit_Debit_Flag__c = u.TransactionType;
            rec.FEC_Merchant_Description__c = u.MerchantName;
            rec.FEC_Merchant_Category_Code__c = u.MCC;

            String rawCurr;
            if (trnxCurrencyByKey != null && trnxCurrencyByKey.containsKey(key)) {
                rawCurr = trnxCurrencyByKey.get(key);
            } else {
                rawCurr = null;
            }
            if (String.isBlank(rawCurr) && !String.isBlank(u.CurrencyCode)) {
                rawCurr = u.CurrencyCode.trim();
            }
            if (String.isBlank(rawCurr)) {
                rec.FEC_Currency_Code__c = null;
            } else if (currencyDisplayMap != null && currencyDisplayMap.containsKey(rawCurr)) {
                rec.FEC_Currency_Code__c = currencyDisplayMap.get(rawCurr);
            } else {
                rec.FEC_Currency_Code__c = rawCurr;
            }

            // ===== Enrich from Financial =====
            if (finMap.containsKey(key)) {
                FEC_GetCardFinancialTransactions.FinancialTransaction f = finMap.get(key);
                rec.FEC_Transaction_Code__c = f.TransactionCode;
                rec.FEC_Transaction_Plan__c = f.Plan;
                rec.FEC_Authorization_Code__c = f.AuthCode;
                rec.FEC_OTP_Sent__c = f.OTPSent == 1 ? 'Yes' : 'No';
            } else {
                rec.FEC_Transaction_Code__c = 'UNBILLED';
            }

            working.put(key, rec);
        }

        if (!working.isEmpty()) {
            upsert working.values();
        }
    }



    /* =====================================================
       SAFE CALLS
       ===================================================== */
    private static List<FEC_GetUnbilledTransactions.TransactionRecord>
    callUnbilledSafe(String acc) {
        try {
            FEC_GetUnbilledTransactions.ResponseWrapper res =
                FEC_GetUnbilledTransactions.callGetUnbilledTransactions(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    acc
                );
            return res != null && res.Transactions != null
                ? res.Transactions
                : new List<FEC_GetUnbilledTransactions.TransactionRecord>();
        } catch (Exception e) {
            return new List<FEC_GetUnbilledTransactions.TransactionRecord>();
        }
    }

    private static List<FEC_GetCardFinancialTransactions.FinancialTransaction>
    callFinancialSafe(String acc) {
        try {
            FEC_GetCardFinancialTransactions.ResponseWrapper res =
                FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                   FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    acc,
                    Date.today().addMonths(-3),
                    Date.today()
                );
            return res != null && res.Transactions != null
                ? res.Transactions
                : new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();
        } catch (Exception e) {
            return new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();
        }
    }

    private static FEC_GetCardBasicInfo.ResponseWrapper callCardBasicSafe(String accNumber) {
        try {
            return FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accNumber
            );
        } catch (Exception e) {
            return null;
        }
    }

    private static Map<String, String> buildTrnxCurrencyCodeByKey(
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTxns
    ) {
        Map<String, String> m = new Map<String, String>();
        if (cardTxns == null || cardTxns.isEmpty()) {
            return m;
        }
        for (FEC_GetCardBasicInfo.TransactionInfo ti : cardTxns) {
            Date postDate = ti.PostingDate;
            if (postDate == null || ti.Amount == null) {
                continue;
            }
            String key = buildKey(postDate, ti.Amount, ti.CreditDebitFlag);
            if (key == null || String.isBlank(ti.TRNXCurrencyCode)) {
                continue;
            }
            m.put(key, ti.TRNXCurrencyCode.trim());
        }
        return m;
    }

    /* =====================================================
       COMMON
       ===================================================== */
    private static String buildKey(
        Date postDate,
        Decimal amount,
        String creditDebit
    ) {
        if (postDate == null || amount == null) return null;

        return postDate.format() + '_' +
            amount.setScale(2) + '_' +
            normDebitCredit(creditDebit);
    }

    private static String normDebitCredit(String s) {
        if (String.isBlank(s)) return '';

        s = s.trim().toUpperCase();

        if (s == 'D' || s == 'DEBIT' || s == 'DR') return 'DEBIT';
        if (s == 'C' || s == 'CREDIT' || s == 'CR') return 'CREDIT';

        return s;
    }
}