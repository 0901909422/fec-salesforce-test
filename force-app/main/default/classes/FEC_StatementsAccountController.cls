/****************************************************************************************
 * File Name    : FEC_StatementsAccountController.Apex
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
   1.1      2026-05-12     Agent                Billed tx: GetCardFinancialTransactions by statement period; VN column labels
   1.2      2026-05-13     Agent                Billed API: FromDate/ToDate from statement cycle only (no fixed window / fallback / bypass)
   1.3      2026-05-13     Agent                Billed: API FromDate = stmt - 2mo, ToDate = stmt; filter by PostingDate vs prev/current stmt dates
 
****************************************************************************************/

public without sharing class FEC_StatementsAccountController {

    /** SOAP window before statement date (posting delay / cycle mismatch). */
    private static final Integer BILLED_FIN_TXN_API_MONTHS_BACK = -2;

    /* =====================================================
       DTO
       ===================================================== */
    public class GeneralStatementInfoDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public Id statementId;
        @AuraEnabled public Decimal billingCycle;
        @AuraEnabled public Date lastStatementDate;
        @AuraEnabled public Decimal totalPaymentDue;
        @AuraEnabled public Decimal minimumPaymentDue;
        @AuraEnabled public Date paymentDueDate;
        @AuraEnabled public Date nextStatementDate;
    }

    public class StatementPeriodDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public Id statementId;
        @AuraEnabled public Date statementDate;
        @AuraEnabled public Decimal totalPaymentDue;
        @AuraEnabled public Decimal minimumPaymentDue;
        @AuraEnabled public Date paymentDueDate;
        @AuraEnabled public Decimal currentPaymentDue;
        @AuraEnabled public Decimal totalPastDue;
        @AuraEnabled public Decimal beginningBalance;
        @AuraEnabled public Decimal endBalance;
        @AuraEnabled public Decimal totalInterest;
        @AuraEnabled public Decimal iPPPrincipal;
        @AuraEnabled public Decimal iPPInterest;
    }

    public class BilledTransactionDTO {
        @AuraEnabled public Map<String, String> helpTexts;
        @AuraEnabled public Id Id;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date postDate;
        @AuraEnabled public Decimal transactionAmount;
        @AuraEnabled public String merchantDescription;
        @AuraEnabled public String creditDebitFlag;
        @AuraEnabled public String transactionPlan;
        @AuraEnabled public String transactionCode;
        @AuraEnabled public String authorizationCode;
        @AuraEnabled public String merchantCategoryCode;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String otpSent;
        /** Sort key for LWC (epoch ms from TRNXDateAndTime / effective date). */
        @AuraEnabled public Long effectiveSortEpoch;
    }

    /* =====================================================
       SYNC FROM API
       ===================================================== */
    @AuraEnabled
    public static void syncStatementFromAPI(Id caseId) {

        if (caseId == null) {
           throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        /* ================= LOAD CASE ================= */
        Case c = [
            SELECT FEC_Account_or_Contract__c, FEC_Product_Type__r.Name, FEC_Is_Test_API__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        FEC_Customer_History__c ch = [
            SELECT Id, FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

       String accountNumber = FEC_CommonUltils.resolveAccountNumber(
                c.FEC_Product_Type__r.Name,
                ch.FEC_Account_Number__c,
                ch.FEC_Contract_Number__c
            );

        /* ================= 1.CALL API GetCardBasicInfo ================= */
        FEC_GetCardBasicInfo.ResponseWrapper resCard;

        try {   
            resCard = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accountNumber
            );

        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{e.getMessage()}));
        }
        
        /* ================= 2.CALL API GetCardBasicInfo ================= */
        FEC_GetCardSecInfo.ResponseWrapper cardSecRes;

        try {
           cardSecRes =  FEC_GetCardSecInfo.callGetCardSecInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber,
                    c.FEC_Is_Test_API__c
                );
        } catch (Exception e) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{e.getMessage()}));
        }

        FEC_GetCardBasicInfo.CardBasicInfo info = resCard.CardBasicInfo;
        List<FEC_GetCardSecInfo.CardStatement> cardStatements = cardSecRes?.CardSecInfo?.CardStatements;

        /* =====================================================
           HEADER STATEMENT
           ===================================================== */

        List<FEC_Statement__c> headers = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :ch.Id
            AND FEC_Statement_Date__c = NULL
            LIMIT 1
        ];

        FEC_Statement__c header;

        if (!headers.isEmpty()) {
            header = headers[0];
        } else {
            header = new FEC_Statement__c(
                FEC_Customer_History__c = ch.Id
            );
        }

        /* ===== GENERAL INFO ===== */
        header.FEC_Billing_Cycle__c       = info.MainCard.BillingCycle;
        header.FEC_Last_Statement_Date__c = info.Statement.LastStatementDate;
        header.FEC_Next_Statement_Date__c = info.Statement.NextStatementDate;

        /* ===== PAYMENT ===== */
        header.FEC_Total_Payment_Due__c   = info?.Statement?.StatementBalance;
        header.FEC_Minimum_Payment_Due__c = info?.Statement?.LastStatementMPA;
        header.FEC_Payment_Due_Date__c    = info?.Statement?.LastStatementDueDate;

        upsert header;

        /* =====================================================
           STATEMENT PERIODS
           ===================================================== */

        Map<Date, FEC_Statement__c> existingByDate = new Map<Date, FEC_Statement__c>();

        for (FEC_Statement__c stmt : [
            SELECT Id, FEC_Statement_Date__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :ch.Id
            AND FEC_Statement_Date__c != NULL
        ]) {
            existingByDate.put(stmt.FEC_Statement_Date__c, stmt);
        }

        List<FEC_Statement__c> toUpsert = new List<FEC_Statement__c>();

        for(FEC_GetCardSecInfo.CardStatement cs : cardStatements){

            if(cs.StatementDate == null) continue;

            Date stmtDate = cs.StatementDate;

            FEC_Statement__c s;

            if(existingByDate.containsKey(stmtDate)){
                s = existingByDate.get(stmtDate);
            } else {
                s = new FEC_Statement__c(
                    FEC_Customer_History__c = ch.Id,
                    FEC_Statement_Date__c = stmtDate
                );
            }

            s.FEC_Total_Payment_Due__c   = cs.QualGraceBal ;
            s.FEC_Minimum_Payment_Due__c = cs.TotalPaymentDue ;
            s.FEC_Current_Payment_Due__c = cs.MPAStructure;

            s.FEC_Payment_Due_Date__c = cs.DueDate;

            s.FEC_Beginning_Balance__c = cs.BalanceForBeginningOfPeriod;
            s.FEC_End_Balance__c       = cs.BalanceForEndOfPeriod;

            s.FEC_Total_Interest__c = cs.TotalInterest;
            s.FEC_IPP_Principal__c  = cs.IPPPrincipal;
            s.FEC_IPP_Interest__c   = cs.IPPInterest;

            s.FEC_Total_Past_Due__c = cs.TotalPastDue;

            toUpsert.add(s);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }

    /* =====================================================
       GET LATEST STATEMENT ID
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static Id getLatestStatementId(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        List<FEC_Statement__c> stmts = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
            ORDER BY FEC_Statement_Date__c DESC, CreatedDate DESC
            LIMIT 1
        ];

        return stmts.isEmpty() ? null : stmts[0].Id;
    }

    /* =====================================================
       READ – GENERAL STATEMENT INFO
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static GeneralStatementInfoDTO loadGeneralStatementInfo(Id statementId) {

        if (statementId == null) return null;

        FEC_Statement__c s = [
            SELECT Id,
                FEC_Billing_Cycle__c,
                FEC_Last_Statement_Date__c,
                FEC_Total_Payment_Due__c,
                FEC_Minimum_Payment_Due__c,
                FEC_Payment_Due_Date__c,
                FEC_Next_Statement_Date__c
            FROM FEC_Statement__c
            WHERE Id = :statementId
            LIMIT 1
        ];

        GeneralStatementInfoDTO dto = new GeneralStatementInfoDTO();
        dto.helpTexts         = FEC_CommonUltils.buildHelpTextMap(FEC_Statement__c.SObjectType);
        dto.statementId       = s.Id;
        dto.billingCycle      = s.FEC_Billing_Cycle__c;
        dto.lastStatementDate = s.FEC_Last_Statement_Date__c;
        dto.totalPaymentDue   = s.FEC_Total_Payment_Due__c;
        dto.minimumPaymentDue = s.FEC_Minimum_Payment_Due__c;
        dto.paymentDueDate    = s.FEC_Payment_Due_Date__c;
        dto.nextStatementDate = s.FEC_Next_Statement_Date__c;

        return dto;
    }

    /* =====================================================
       READ – STATEMENT DETAILS
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<StatementPeriodDTO> loadStatementDetails(Id statementId) {

        if (statementId == null) return new List<StatementPeriodDTO>();

        FEC_Statement__c header = [
            SELECT FEC_Customer_History__c
            FROM FEC_Statement__c
            WHERE Id = :statementId
            LIMIT 1
        ];

        Map<String, String> helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Statement__c.SObjectType);
        List<StatementPeriodDTO> result = new List<StatementPeriodDTO>();

        for (FEC_Statement__c s : [
            SELECT Id,
                   FEC_Statement_Date__c,
                   FEC_Total_Payment_Due__c,
                   FEC_Minimum_Payment_Due__c,
                   FEC_Payment_Due_Date__c,
                   FEC_Current_Payment_Due__c,
                   FEC_Beginning_Balance__c,
                   FEC_End_Balance__c,
                   FEC_Total_Past_Due__c,
                   FEC_Total_Interest__c,
                   FEC_IPP_Principal__c,
                   FEC_IPP_Interest__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :header.FEC_Customer_History__c
              AND FEC_Statement_Date__c != NULL
            ORDER BY FEC_Statement_Date__c DESC
        ]) {

            StatementPeriodDTO dto = new StatementPeriodDTO();
            dto.helpTexts         = helpTexts;
            dto.statementId       = s.Id;
            dto.statementDate     = s.FEC_Statement_Date__c;
            dto.totalPaymentDue   = s.FEC_Total_Payment_Due__c;
            dto.minimumPaymentDue = s.FEC_Minimum_Payment_Due__c;
            dto.paymentDueDate    = s.FEC_Payment_Due_Date__c;
            dto.currentPaymentDue = s.FEC_Current_Payment_Due__c;
            dto.beginningBalance  = s.FEC_Beginning_Balance__c;
            dto.endBalance        = s.FEC_End_Balance__c;
            dto.totalPastDue      = s.FEC_Total_Past_Due__c;
            dto.totalInterest     = s.FEC_Total_Interest__c;
            dto.iPPPrincipal      = s.FEC_IPP_Principal__c;
            dto.iPPInterest       = s.FEC_IPP_Interest__c;

            result.add(dto);
        }

        return result;
    }

    /* =====================================================
     BILLED TRANSACTIONS — GetCardFinancialTransactions
     SOAP: FromDate = statement date + BILLED_FIN_TXN_API_MONTHS_BACK, ToDate = statement date.
     Rows: PostingDate > previous statement date AND PostingDate <= current statement date
     (PostingDate only; no previous stmt → lower bound = same SOAP FromDate, inclusive).
     ===================================================== */
    @AuraEnabled(cacheable=false)
    public static List<BilledTransactionDTO> getBilledTransactions(Id statementId) {

        if (statementId == null) {
            return new List<BilledTransactionDTO>();
        }

        FEC_Statement__c stmt = [
            SELECT Id,
                FEC_Statement_Date__c,
                FEC_Customer_History__c,
                FEC_Customer_History__r.FEC_Account_Number__c,
                FEC_Customer_History__r.FEC_Contract_Number__c
            FROM FEC_Statement__c
            WHERE Id = :statementId
            LIMIT 1
        ];

        if (stmt.FEC_Statement_Date__c == null) {
            return new List<BilledTransactionDTO>();
        }

        String productTypeName = null;
        List<Case> caseRows = [
            SELECT FEC_Product_Type__r.Name
            FROM Case
            WHERE FEC_Account_or_Contract__c = :stmt.FEC_Customer_History__c
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!caseRows.isEmpty()) {
            productTypeName = caseRows[0].FEC_Product_Type__r.Name;
        }

        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            productTypeName,
            stmt.FEC_Customer_History__r.FEC_Account_Number__c,
            stmt.FEC_Customer_History__r.FEC_Contract_Number__c
        );

        if (String.isBlank(accountNumber)) {
            return new List<BilledTransactionDTO>();
        }

        Date currentStmtDate = stmt.FEC_Statement_Date__c;
        Date apiFromDate = currentStmtDate.addMonths(BILLED_FIN_TXN_API_MONTHS_BACK);
        Date apiToDate = currentStmtDate;

        Date prevStatementDate = null;
        List<FEC_Statement__c> prevStmtRows = [
            SELECT FEC_Statement_Date__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :stmt.FEC_Customer_History__c
                AND FEC_Statement_Date__c != null
                AND FEC_Statement_Date__c < :currentStmtDate
            ORDER BY FEC_Statement_Date__c DESC
            LIMIT 1
        ];
        if (!prevStmtRows.isEmpty()) {
            prevStatementDate = prevStmtRows[0].FEC_Statement_Date__c;
        }

        Map<String, String> helpTemplate =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

        try {
            FEC_GetCardFinancialTransactions.ResponseWrapper apiRes =
                FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    accountNumber,
                    apiFromDate,
                    apiToDate
                );

            if (apiRes == null || apiRes.Transactions == null) {
                return new List<BilledTransactionDTO>();
            }

            List<FEC_GetCardFinancialTransactions.FinancialTransaction> billedFinTxns =
                new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();
            for (
                FEC_GetCardFinancialTransactions.FinancialTransaction ft : apiRes.Transactions
            ) {
                if (ft == null) {
                    continue;
                }
                if (!finTxnBelongsToBilledCycle(ft, prevStatementDate, currentStmtDate, apiFromDate)) {
                    continue;
                }
                billedFinTxns.add(ft);
            }

            Map<String, Id> transactionIdsByKey =
                upsertBilledFinancialTransactions(
                    stmt.FEC_Customer_History__c,
                    billedFinTxns
                );

            List<BilledTransactionDTO> result = new List<BilledTransactionDTO>();
            for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : billedFinTxns) {
                String key = buildBilledFinancialTransactionKey(ft);
                result.add(
                    buildBilledDtoFromFinancialTxn(
                        ft,
                        helpTemplate,
                        String.isNotBlank(key) ? transactionIdsByKey.get(key) : null
                    )
                );
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{e.getMessage()})
            );
        }
    }

    /**
     * Billed cycle by posting date: {@code PostingDate > prev statement date}
     * and {@code PostingDate <= current statement date}.
     * When there is no prior statement, lower bound is {@code apiFromDate} (same as SOAP FromDate), inclusive.
     */
    private static Boolean finTxnBelongsToBilledCycle(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft,
        Date prevStatementDate,
        Date currentStmtDate,
        Date apiFromDate
    ) {
        if (ft == null) {
            return false;
        }
        Date postD = FEC_CommonUltils.parseDate(ft.PostingDate);
        if (postD == null) {
            return false;
        }
        if (prevStatementDate != null) {
            return postD > prevStatementDate && postD <= currentStmtDate;
        }
        return postD >= apiFromDate && postD <= currentStmtDate;
    }

    private static BilledTransactionDTO buildBilledDtoFromFinancialTxn(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft,
        Map<String, String> helpTemplate,
        Id transactionId
    ) {
        Date effDate = effectiveDateFromFinancialTxn(ft);
        Date postD = FEC_CommonUltils.parseDate(ft.PostingDate);

        BilledTransactionDTO dto = new BilledTransactionDTO();
        dto.helpTexts = helpTemplate;
        dto.Id = transactionId;
        dto.effectiveDate = effDate;
        dto.postDate = postD;
        dto.transactionAmount = ft.TRNXAmount;
        dto.merchantDescription = firstNonBlank(ft.MerchantName, ft.Description);
        dto.creditDebitFlag = ft.CreditDebitFlag;
        dto.transactionPlan = ft.Plan;
        dto.transactionCode = ft.TransactionCode;
        dto.authorizationCode = ft.AuthCode;
        dto.merchantCategoryCode = ft.MCC;
        dto.currencyCode = ft.TRNXCurrencyCode;
        dto.otpSent = formatOtpSent(ft.OTPSent);
        dto.effectiveSortEpoch = effectiveSortEpochFromFinancialTxn(ft, effDate);
        return dto;
    }

    private static Map<String, Id> upsertBilledFinancialTransactions(
        Id customerHistoryId,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> finTxns
    ) {
        Map<String, Id> idsByKey = new Map<String, Id>();
        if (customerHistoryId == null || finTxns == null || finTxns.isEmpty()) {
            return idsByKey;
        }

        Map<String, FEC_Transaction__c> existingByKey =
            loadExistingBilledTransactionsByKey(customerHistoryId, finTxns);
        Map<String, FEC_Transaction__c> recordsByKey =
            new Map<String, FEC_Transaction__c>();

        for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : finTxns) {
            String key = buildBilledFinancialTransactionKey(ft);
            if (String.isBlank(key)) {
                continue;
            }

            FEC_Transaction__c record = existingByKey.containsKey(key)
                ? existingByKey.get(key)
                : new FEC_Transaction__c(FEC_Customer_History__c = customerHistoryId);

            applyFinancialTransaction(record, ft);
            recordsByKey.put(key, record);
        }

        if (!recordsByKey.isEmpty()) {
            upsert recordsByKey.values();
            for (String key : recordsByKey.keySet()) {
                idsByKey.put(key, recordsByKey.get(key).Id);
            }
        }
        return idsByKey;
    }

    private static Map<String, FEC_Transaction__c> loadExistingBilledTransactionsByKey(
        Id customerHistoryId,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> finTxns
    ) {
        Map<String, FEC_Transaction__c> existingByKey =
            new Map<String, FEC_Transaction__c>();
        Date minPostDate;
        Date maxPostDate;

        for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : finTxns) {
            Date postDate = FEC_CommonUltils.parseDate(ft.PostingDate);
            if (postDate == null) {
                continue;
            }
            minPostDate = minPostDate == null || postDate < minPostDate
                ? postDate
                : minPostDate;
            maxPostDate = maxPostDate == null || postDate > maxPostDate
                ? postDate
                : maxPostDate;
        }

        if (minPostDate == null || maxPostDate == null) {
            return existingByKey;
        }

        for (FEC_Transaction__c tx : [
            SELECT Id,
                FEC_Post_Date__c,
                FEC_Transaction_Amount__c,
                FEC_Credit_Debit_Flag__c,
                FEC_Transaction_Code__c,
                FEC_Authorization_Code__c,
                FEC_Transaction_Plan__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :customerHistoryId
                AND FEC_Post_Date__c >= :minPostDate
                AND FEC_Post_Date__c <= :maxPostDate
        ]) {
            String key = buildBilledKey(
                tx.FEC_Post_Date__c,
                tx.FEC_Transaction_Amount__c,
                tx.FEC_Credit_Debit_Flag__c,
                tx.FEC_Transaction_Code__c,
                tx.FEC_Authorization_Code__c,
                tx.FEC_Transaction_Plan__c
            );
            if (String.isNotBlank(key)) {
                existingByKey.put(key, tx);
            }
        }
        return existingByKey;
    }

    private static void applyFinancialTransaction(
        FEC_Transaction__c record,
        FEC_GetCardFinancialTransactions.FinancialTransaction ft
    ) {
        Date effDate = effectiveDateFromFinancialTxn(ft);
        Date postDate = FEC_CommonUltils.parseDate(ft.PostingDate);

        record.FEC_Effective_Date__c = effDate;
        record.FEC_Post_Date__c = postDate;
        record.FEC_Transaction_Amount__c = ft.TRNXAmount;
        record.FEC_Merchant_Description__c =
            firstNonBlank(ft.MerchantName, ft.Description);
        record.FEC_Credit_Debit_Flag__c = ft.CreditDebitFlag;
        record.FEC_Transaction_Plan__c = ft.Plan;
        record.FEC_Transaction_Code__c = ft.TransactionCode;
        record.FEC_Authorization_Code__c = ft.AuthCode;
        record.FEC_Merchant_Category_Code__c = ft.MCC;
        record.FEC_Currency_Code__c = ft.TRNXCurrencyCode;
        record.FEC_OTP_Sent__c = formatOtpSent(ft.OTPSent);
    }

    private static String buildBilledFinancialTransactionKey(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft
    ) {
        if (ft == null) {
            return null;
        }
        return buildBilledKey(
            FEC_CommonUltils.parseDate(ft.PostingDate),
            ft.TRNXAmount,
            ft.CreditDebitFlag,
            ft.TransactionCode,
            ft.AuthCode,
            ft.Plan
        );
    }

    private static String buildBilledKey(
        Date postDate,
        Decimal amount,
        String creditDebit,
        String transactionCode,
        String authorizationCode,
        String transactionPlan
    ) {
        if (postDate == null || amount == null) {
            return null;
        }
        return String.join(
            new List<String>{
                postDate.format(),
                String.valueOf(amount.setScale(2)),
                normalizeText(creditDebit),
                normalizeText(transactionCode),
                normalizeText(authorizationCode),
                normalizeText(transactionPlan)
            },
            '|'
        );
    }

    private static String normalizeText(String value) {
        return String.isBlank(value) ? '' : value.trim().toUpperCase();
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        if (String.isNotBlank(firstValue)) {
            return firstValue.trim();
        }
        if (String.isNotBlank(secondValue)) {
            return secondValue.trim();
        }
        return null;
    }

    private static Date effectiveDateFromFinancialTxn(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft
    ) {
        if (ft == null) {
            return null;
        }
        Datetime trnxDt = FEC_CommonUltils.parseDateTime(ft.TRNXDateAndTime);
        if (trnxDt != null) {
            return trnxDt.date();
        }
        return FEC_CommonUltils.parseDate(ft.TRNXDateAndTime);
    }

    private static Long effectiveSortEpochFromFinancialTxn(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft,
        Date effDateFallback
    ) {
        if (ft != null) {
            Datetime trnxDt = FEC_CommonUltils.parseDateTime(ft.TRNXDateAndTime);
            if (trnxDt != null) {
                return trnxDt.getTime();
            }
        }
        if (effDateFallback != null) {
            return Datetime.newInstanceGmt(
                    effDateFallback,
                    Time.newInstance(0, 0, 0, 0)
                )
                .getTime();
        }
        return 0L;
    }

    private static String formatOtpSent(Integer otp) {
        if (otp == null) {
            return null;
        }
        return String.valueOf(otp);
    }
}