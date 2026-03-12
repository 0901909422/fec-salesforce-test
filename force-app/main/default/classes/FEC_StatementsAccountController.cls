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
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        FEC_Customer_History__c ch = [
            SELECT Id, FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];

        /* ================= 1.CALL API GetCardBasicInfo ================= */
        FEC_GetCardBasicInfo.ResponseWrapper resCard;

        try {   
            resCard = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                ch.FEC_Account_Number__c
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
                    ch.FEC_Account_Number__c
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

        if (info.Statements != null && !info.Statements.isEmpty()) {

            Map<Date, FEC_Statement__c> existingByDate = new Map<Date, FEC_Statement__c>();
            Map<Date, FEC_GetCardSecInfo.CardStatement> secStatementMap = new Map<Date, FEC_GetCardSecInfo.CardStatement>();
            if(cardStatements != null){
                for(FEC_GetCardSecInfo.CardStatement cs : cardStatements){
                    if(cs.StatementDate != null){
                        secStatementMap.put(cs.StatementDate, cs);
                    }
                }
            }

            for (FEC_Statement__c s : [
                SELECT Id, FEC_Statement_Date__c
                FROM FEC_Statement__c
                WHERE FEC_Customer_History__c = :ch.Id
                  AND FEC_Statement_Date__c != NULL
            ]) {
                existingByDate.put(s.FEC_Statement_Date__c, s);
            }

            List<FEC_Statement__c> toUpsert = new List<FEC_Statement__c>();

            for (FEC_GetCardBasicInfo.StatementPeriod p : info.Statements) {

                if (p.StatementDate == null) continue;

                FEC_Statement__c s;

                if (existingByDate.containsKey(p.StatementDate)) {
                    s = existingByDate.get(p.StatementDate);
                } else {
                    s = new FEC_Statement__c(
                        FEC_Customer_History__c = ch.Id,
                        FEC_Statement_Date__c   = p.StatementDate
                    );
                }

                s.FEC_Total_Payment_Due__c   = info?.Statement?.StatementBalance;
                s.FEC_Minimum_Payment_Due__c = info?.Statement?.LastStatementMPA;
                s.FEC_Payment_Due_Date__c    = info?.Statement?.LastStatementDueDate;

                s.FEC_Current_Payment_Due__c = p.MPA;
                s.FEC_Beginning_Balance__c   = p.BalanceBegin;
                s.FEC_End_Balance__c         = p.BalanceEnd;

                FEC_GetCardSecInfo.CardStatement cs = secStatementMap.get(p.StatementDate);
                if(cs != null){
                    s.FEC_Total_Past_Due__c  = cs.TotalPastDue;
                    s.FEC_Total_Interest__c  = cs.TotalInterest;
                    s.FEC_IPP_Principal__c   = cs.IPPPrincipal;
                    s.FEC_IPP_Interest__c    = cs.IPPInterest;
                }

                toUpsert.add(s);
            }

            if (!toUpsert.isEmpty()) {
                upsert toUpsert;
            }
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
     BILLED TRANSACTIONS
     ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<BilledTransactionDTO> getBilledTransactions(Id statementId) {

        if (statementId == null) {
            return new List<BilledTransactionDTO>();
        }

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
            ORDER BY FEC_Post_Date__c DESC
        ]) {
            BilledTransactionDTO dto = new BilledTransactionDTO();
            dto.Id                   = t.Id;
            dto.effectiveDate        = t.FEC_Effective_Date__c;
            dto.postDate             = t.FEC_Post_Date__c;
            dto.transactionAmount    = t.FEC_Transaction_Amount__c;
            dto.merchantDescription  = t.FEC_Merchant_Description__c;
            dto.creditDebitFlag      = t.FEC_Credit_Debit_Flag__c;
            dto.transactionPlan      = t.FEC_Transaction_Plan__c;
            dto.transactionCode      = t.FEC_Transaction_Code__c;
            dto.authorizationCode    = t.FEC_Authorization_Code__c;
            dto.merchantCategoryCode = t.FEC_Merchant_Category_Code__c;
            dto.currencyCode         = t.FEC_Currency_Code__c;
            dto.otpSent              = t.FEC_OTP_Sent__c;

            result.add(dto);
        }

        return result;
    }
}