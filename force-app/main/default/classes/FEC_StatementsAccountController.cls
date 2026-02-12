public with sharing class FEC_StatementsAccountController {

    /* =====================================================
       DTO
       ===================================================== */
    public class GeneralStatementInfoDTO {
        @AuraEnabled public Id statementId;
        @AuraEnabled public Date statementDate;
        @AuraEnabled public Decimal totalPaymentDue;
        @AuraEnabled public Decimal minimumPaymentDue;
        @AuraEnabled public Date paymentDueDate;
        @AuraEnabled public Date totalPastDue;
    }

    public class StatementPeriodDTO {
        @AuraEnabled public Id statementId;
        @AuraEnabled public Date statementDate;
        @AuraEnabled public Decimal totalPaymentDue;
        @AuraEnabled public Decimal minimumPaymentDue;
        @AuraEnabled public Date paymentDueDate;
    }

    public class BilledTransactionDTO {
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
        @AuraEnabled public String otpSent;
    }

    /* =====================================================
        GET CUSTOMER HISTORY FROM CASE
       ===================================================== */
    private static FEC_Customer_History__c getCustomerHistory(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        return [
            SELECT Id, FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
    }

    /* =====================================================
       SYNC STATEMENT + TRANSACTION FROM API
       ===================================================== */
    @AuraEnabled
    public static void syncStatementFromAPI(Id caseId) {

        if (caseId == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Case Id'}));
        }

        /* ===== 1. CUSTOMER HISTORY ===== */
        FEC_Customer_History__c ch = getCustomerHistory(caseId);

        /* ===== 2. CALL API ===== */
        FEC_GetCardBasicInfo.ResponseWrapper res;
        try {
            res = FEC_GetCardBasicInfo.callGetCardBasicInfo(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                ch.FEC_Account_Number__c
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        if (res == null || res.CardBasicInfo == null || res.CardBasicInfo.Statement == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Response_Null);
        }

        FEC_GetCardBasicInfo.CardBasicInfo info = res.CardBasicInfo;
        Date statementDate = info.Statement.LastStatementDate;

        if (statementDate == null) {
            throw new AuraHandledException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'StatementDate'}));
        }

        /* ===== 3. UPDATE FIRST – NOT EXISTS → INSERT ===== */
        List<FEC_Statement__c> existed = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :ch.Id
            AND FEC_Statement_Date__c = :statementDate
            LIMIT 1
        ];

        FEC_Statement__c stmt;
        if (!existed.isEmpty()) {
            stmt = existed[0];
        } else {
            stmt = new FEC_Statement__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Statement_Date__c  = statementDate
            );
        }

        /* ===== 4. MAP FIELD ===== */
        stmt.FEC_Total_Payment_Due__c   = info.Statement.StatementBalance;
        stmt.FEC_Minimum_Payment_Due__c = info.Statement.LastStatementMPA;
        stmt.FEC_Payment_Due_Date__c    = info.Statement.LastStatementDueDate;

        if (stmt.Id == null) {
            insert stmt;
        } else {
            update stmt;
        }

        /* ===== 5. UPSERT TRANSACTIONS ===== */
        if (info.Transactions != null && !info.Transactions.isEmpty()) {
            upsertTransactions(stmt.Id, ch.Id, info.Transactions);

        }
    }

    /* =====================================================
       UPSERT TRANSACTIONS
       ===================================================== */
    private static void upsertTransactions(
        Id statementId,
        Id customerHistoryId,
        List<FEC_GetCardBasicInfo.TransactionInfo> apiTxs
    ) {

        Map<String, FEC_Transaction__c> existedMap = new Map<String, FEC_Transaction__c>();

        for (FEC_Transaction__c tx : [
            SELECT Id, FEC_Authorization_Code__c
            FROM FEC_Transaction__c
            WHERE FEC_Statement__c = :statementId
            AND FEC_Authorization_Code__c != null
        ]) {
            existedMap.put(tx.FEC_Authorization_Code__c, tx);
        }

        List<FEC_Transaction__c> toUpsert = new List<FEC_Transaction__c>();

        for (FEC_GetCardBasicInfo.TransactionInfo apiTx : apiTxs) {

            if (String.isBlank(apiTx.RRN)) continue;

            FEC_Transaction__c rec =
                existedMap.containsKey(apiTx.RRN)
                ? existedMap.get(apiTx.RRN)
                : new FEC_Transaction__c(
                    FEC_Statement__c = statementId,
                    FEC_Customer_History__c = customerHistoryId,
                    FEC_Authorization_Code__c = apiTx.RRN
                );

            rec.FEC_Effective_Date__c =
                apiTx.TRNXDateTime != null ? apiTx.TRNXDateTime.date() : null;
            rec.FEC_Post_Date__c              = apiTx.PostingDate;
            rec.FEC_Transaction_Amount__c     = apiTx.Amount;
            rec.FEC_Merchant_Description__c   = apiTx.Description;
            rec.FEC_Credit_Debit_Flag__c      = apiTx.CreditDebitFlag;
            rec.FEC_Transaction_Plan__c       = apiTx.Plan;
            rec.FEC_Transaction_Code__c       = apiTx.TransactionCode;
            rec.FEC_Merchant_Category_Code__c = apiTx.MerchantName;
            rec.FEC_OTP_Sent__c =
                apiTx.OTPSent == 1 ? 'Yes' :
                apiTx.OTPSent == 0 ? 'No' : 'N/A';

            toUpsert.add(rec);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }

    /* =====================================================
        GENERAL INFO
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static GeneralStatementInfoDTO loadGeneralStatementInfo(Id caseId) {

        FEC_Customer_History__c ch = getCustomerHistory(caseId);

        List<FEC_Statement__c> stmts = [
            SELECT Id, FEC_Statement_Date__c,
                   FEC_Total_Payment_Due__c,
                   FEC_Minimum_Payment_Due__c,
                   FEC_Payment_Due_Date__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :ch.Id
            ORDER BY FEC_Statement_Date__c DESC
            LIMIT 1
        ];

        if (stmts.isEmpty()) {
            return new GeneralStatementInfoDTO();
        }

        FEC_Statement__c s = stmts[0];
        GeneralStatementInfoDTO dto = new GeneralStatementInfoDTO();
        dto.statementId       = s.Id;
        dto.statementDate     = s.FEC_Statement_Date__c;
        dto.totalPaymentDue   = s.FEC_Total_Payment_Due__c;
        dto.minimumPaymentDue = s.FEC_Minimum_Payment_Due__c;
        dto.paymentDueDate    = s.FEC_Payment_Due_Date__c;
        return dto;
    }

    /* =====================================================
        STATEMENT LIST
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<StatementPeriodDTO> loadStatementDetails(Id caseId) {

        FEC_Customer_History__c ch = getCustomerHistory(caseId);
        List<StatementPeriodDTO> result = new List<StatementPeriodDTO>();

        for (FEC_Statement__c s : [
            SELECT Id, FEC_Statement_Date__c,
                   FEC_Total_Payment_Due__c,
                   FEC_Minimum_Payment_Due__c,
                   FEC_Payment_Due_Date__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :ch.Id
            ORDER BY FEC_Statement_Date__c DESC
        ]) {
            StatementPeriodDTO dto = new StatementPeriodDTO();
            dto.statementId       = s.Id;
            dto.statementDate     = s.FEC_Statement_Date__c;
            dto.totalPaymentDue   = s.FEC_Total_Payment_Due__c;
            dto.minimumPaymentDue = s.FEC_Minimum_Payment_Due__c;
            dto.paymentDueDate    = s.FEC_Payment_Due_Date__c;
            result.add(dto);
        }
        return result;
    }

    /* =====================================================
       STATEMENT DETAIL
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static FEC_Statement__c loadStatementDetail(Id statementId) {
        if (statementId == null) return null;

        return [
            SELECT Id,
                   FEC_Statement_Date__c,
                   FEC_Total_Payment_Due__c,
                   FEC_Minimum_Payment_Due__c,
                   FEC_Payment_Due_Date__c
            FROM FEC_Statement__c
            WHERE Id = :statementId
            LIMIT 1
        ];
    }

    /* =====================================================
       READ: TRANSACTIONS
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<BilledTransactionDTO> getBilledTransactions(Id statementId) {

        List<BilledTransactionDTO> result = new List<BilledTransactionDTO>();

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
                   FEC_OTP_Sent__c
            FROM FEC_Transaction__c
            WHERE FEC_Statement__c = :statementId
            ORDER BY FEC_Post_Date__c DESC
        ]) {
            BilledTransactionDTO dto = new BilledTransactionDTO();
            dto.Id                  = tx.Id;
            dto.effectiveDate       = tx.FEC_Effective_Date__c;
            dto.postDate            = tx.FEC_Post_Date__c;
            dto.transactionAmount   = tx.FEC_Transaction_Amount__c;
            dto.merchantDescription = tx.FEC_Merchant_Description__c;
            dto.creditDebitFlag     = tx.FEC_Credit_Debit_Flag__c;
            dto.transactionPlan     = tx.FEC_Transaction_Plan__c;
            dto.transactionCode     = tx.FEC_Transaction_Code__c;
            dto.authorizationCode   = tx.FEC_Authorization_Code__c;
            dto.merchantCategoryCode= tx.FEC_Merchant_Category_Code__c;
            dto.otpSent             = tx.FEC_OTP_Sent__c;
            result.add(dto);
        }
        return result;
    }
}