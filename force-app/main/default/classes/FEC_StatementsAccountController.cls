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
 
****************************************************************************************/

public without sharing class FEC_StatementsAccountController {

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
            SELECT FEC_Account_or_Contract__c,
                FEC_Product_Type__r.Name,
                FEC_Is_Test_API__c
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
        
        /* ================= 2.CALL API GetCardSecInfo ================= */
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

        if (cardStatements == null) {
            return;
        }

        for (FEC_GetCardSecInfo.CardStatement cs : cardStatements) {

            if (cs.StatementDate == null) {
                continue;
            }

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

        Date stmtEnd = stmt.FEC_Statement_Date__c;
        if (stmtEnd == null) {
            return new List<BilledTransactionDTO>();
        }

        Date prevStmtDate;
        List<FEC_Statement__c> prevRows = [
            SELECT FEC_Statement_Date__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :stmt.FEC_Customer_History__c
              AND FEC_Statement_Date__c < :stmtEnd
            ORDER BY FEC_Statement_Date__c DESC
            LIMIT 1
        ];
        if (!prevRows.isEmpty()) {
            prevStmtDate = prevRows[0].FEC_Statement_Date__c;
        } else {
            List<FEC_Statement__c> headerRows = [
                SELECT FEC_Last_Statement_Date__c
                FROM FEC_Statement__c
                WHERE FEC_Customer_History__c = :stmt.FEC_Customer_History__c
                  AND FEC_Statement_Date__c = NULL
                LIMIT 1
            ];
            prevStmtDate = headerRows.isEmpty()
                ? null
                : headerRows[0].FEC_Last_Statement_Date__c;
        }

        Date apiFromDate = prevStmtDate != null ? prevStmtDate : stmtEnd;
        Date apiToDate = stmtEnd;

        String accountNumber = FEC_CommonUltils.resolveAccountNumber(
            null,
            stmt.FEC_Customer_History__r.FEC_Account_Number__c,
            stmt.FEC_Customer_History__r.FEC_Contract_Number__c
        );
        if (String.isBlank(accountNumber)) {
            throw new AuraHandledException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'AccountNumber' }
                )
            );
        }

        FEC_GetCardFinancialTransactions.ResponseWrapper apiRes;
        try {
            apiRes = FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accountNumber,
                apiFromDate,
                apiToDate
            );
        } catch (Exception e) {
            System.debug('### BILLED API fallback DB: ' + e.getMessage());
            return loadBilledTransactionsFromDb(statementId);
        }

        if (apiRes == null || apiRes.Transactions == null || apiRes.Transactions.isEmpty()) {
            return loadBilledTransactionsFromDb(statementId);
        }

        List<FEC_GetCardFinancialTransactions.FinancialTransaction> billedRows =
            new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();
        for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : apiRes.Transactions) {
            if (ft == null) {
                continue;
            }
            Date postDate = FEC_CommonUltils.toDateStr(ft.PostingDate);
            if (postDate == null) {
                continue;
            }
            if (prevStmtDate != null) {
                if (postDate <= prevStmtDate || postDate > stmtEnd) {
                    continue;
                }
            } else if (postDate > stmtEnd) {
                continue;
            }
            billedRows.add(ft);
        }

        if (billedRows.isEmpty()) {
            return loadBilledTransactionsFromDb(statementId);
        }

        Map<String, Id> idsByKey = upsertBilledFromFinancial(
            stmt.FEC_Customer_History__c,
            statementId,
            billedRows
        );

        Map<String, String> helpTexts =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);
        List<BilledTransactionDTO> result = new List<BilledTransactionDTO>();

        for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : billedRows) {
            BilledTransactionDTO dto = toBilledDto(ft);
            dto.helpTexts = helpTexts;
            String key = billedTxnKey(ft);
            if (key != null && idsByKey.containsKey(key)) {
                dto.Id = idsByKey.get(key);
            }
            result.add(dto);
        }

        return result;
    }

    /** UAT / API empty: read FEC_Transaction__c already linked to this statement. */
    private static List<BilledTransactionDTO> loadBilledTransactionsFromDb(Id statementId) {
        Map<String, String> helpTexts =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);
        List<BilledTransactionDTO> result = new List<BilledTransactionDTO>();

        for (FEC_Transaction__c t : [
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
            WHERE FEC_Statement__c = :statementId
            ORDER BY FEC_Post_Date__c DESC, FEC_Effective_Date__c DESC
        ]) {
            BilledTransactionDTO dto = new BilledTransactionDTO();
            dto.helpTexts = helpTexts;
            dto.Id = t.Id;
            dto.effectiveDate = t.FEC_Effective_Date__c;
            dto.postDate = t.FEC_Post_Date__c;
            dto.transactionAmount = t.FEC_Transaction_Amount__c;
            dto.merchantDescription = t.FEC_Merchant_Description__c;
            dto.creditDebitFlag = t.FEC_Credit_Debit_Flag__c;
            dto.transactionPlan = t.FEC_Transaction_Plan__c;
            dto.transactionCode = t.FEC_Transaction_Code__c;
            dto.authorizationCode = t.FEC_Authorization_Code__c;
            dto.merchantCategoryCode = t.FEC_Merchant_Category_Code__c;
            dto.currencyCode = t.FEC_Currency_Code__c;
            dto.otpSent = t.FEC_OTP_Sent__c;
            result.add(dto);
        }
        return result;
    }

    private static Map<String, Id> upsertBilledFromFinancial(
        Id customerHistoryId,
        Id statementId,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> rows
    ) {
        Map<String, Id> idsByKey = new Map<String, Id>();
        if (rows == null || rows.isEmpty()) {
            return idsByKey;
        }

        Map<String, FEC_Transaction__c> existing = new Map<String, FEC_Transaction__c>();
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
        ]) {
            String key = billedTxnKey(tx);
            if (key != null) {
                existing.put(key, tx);
            }
        }

        Map<String, FEC_Transaction__c> toSave = new Map<String, FEC_Transaction__c>();
        for (FEC_GetCardFinancialTransactions.FinancialTransaction ft : rows) {
            String key = billedTxnKey(ft);
            if (key == null) {
                continue;
            }
            FEC_Transaction__c rec = toSave.containsKey(key)
                ? toSave.get(key)
                : existing.containsKey(key)
                    ? existing.get(key)
                    : new FEC_Transaction__c(FEC_Customer_History__c = customerHistoryId);

            Date postDate = FEC_CommonUltils.toDateStr(ft.PostingDate);
            Date effDate = FEC_CommonUltils.toDateStr(ft.TRNXDateAndTime);
            if (effDate == null) {
                effDate = postDate;
            }

            rec.FEC_Statement__c = statementId;
            rec.FEC_Effective_Date__c = effDate;
            rec.FEC_Post_Date__c = postDate;
            rec.FEC_Transaction_Amount__c = ft.TRNXAmount;
            rec.FEC_Merchant_Description__c = String.isBlank(ft.MerchantName)
                ? ft.Description
                : ft.MerchantName;
            rec.FEC_Credit_Debit_Flag__c = ft.CreditDebitFlag;
            rec.FEC_Transaction_Plan__c = ft.Plan;
            rec.FEC_Transaction_Code__c = ft.TransactionCode;
            rec.FEC_Authorization_Code__c = ft.AuthCode;
            rec.FEC_Currency_Code__c = ft.TRNXCurrencyCode;
            rec.FEC_OTP_Sent__c = ft.OTPSent == null
                ? null
                : (ft.OTPSent == 1 ? 'Yes' : (ft.OTPSent == 0 ? 'No' : 'N/A'));

            toSave.put(key, rec);
        }

        if (!toSave.isEmpty()) {
            upsert toSave.values();
            for (FEC_Transaction__c rec : toSave.values()) {
                String key = billedTxnKey(rec);
                if (key != null) {
                    idsByKey.put(key, rec.Id);
                }
            }
        }
        return idsByKey;
    }

    private static BilledTransactionDTO toBilledDto(
        FEC_GetCardFinancialTransactions.FinancialTransaction ft
    ) {
        Date postDate = FEC_CommonUltils.toDateStr(ft.PostingDate);
        Date effDate = FEC_CommonUltils.toDateStr(ft.TRNXDateAndTime);
        if (effDate == null) {
            effDate = postDate;
        }

        BilledTransactionDTO dto = new BilledTransactionDTO();
        dto.effectiveDate = effDate;
        dto.postDate = postDate;
        dto.transactionAmount = ft.TRNXAmount;
        dto.merchantDescription = String.isBlank(ft.MerchantName) ? ft.Description : ft.MerchantName;
        dto.creditDebitFlag = ft.CreditDebitFlag;
        dto.transactionPlan = ft.Plan;
        dto.transactionCode = ft.TransactionCode;
        dto.authorizationCode = ft.AuthCode;
        dto.merchantCategoryCode = null;
        dto.currencyCode = ft.TRNXCurrencyCode;
        dto.otpSent = ft.OTPSent == null
            ? null
            : (ft.OTPSent == 1 ? 'Yes' : (ft.OTPSent == 0 ? 'No' : 'N/A'));
        return dto;
    }

    private static String billedTxnKey(FEC_GetCardFinancialTransactions.FinancialTransaction ft) {
        Date postDate = FEC_CommonUltils.toDateStr(ft.PostingDate);
        if (postDate == null || ft.TRNXAmount == null) {
            return null;
        }
        return postDate.format()
            + '|' + ft.TRNXAmount.setScale(2)
            + '|' + String.valueOf(ft.CreditDebitFlag)
            + '|' + String.valueOf(ft.TransactionCode)
            + '|' + String.valueOf(ft.AuthCode)
            + '|' + String.valueOf(ft.Plan);
    }

    private static String billedTxnKey(FEC_Transaction__c tx) {
        if (tx.FEC_Post_Date__c == null || tx.FEC_Transaction_Amount__c == null) {
            return null;
        }
        return tx.FEC_Post_Date__c.format()
            + '|' + tx.FEC_Transaction_Amount__c.setScale(2)
            + '|' + String.valueOf(tx.FEC_Credit_Debit_Flag__c)
            + '|' + String.valueOf(tx.FEC_Transaction_Code__c)
            + '|' + String.valueOf(tx.FEC_Authorization_Code__c)
            + '|' + String.valueOf(tx.FEC_Transaction_Plan__c);
    }
}