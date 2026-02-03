public with sharing class FEC_TransactionsController {

    /* =====================================================
       DTO
       ===================================================== */
    public class TransactionsDTO {
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String lastRefreshTime;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<TransactionDisplayRecord> transactions;
    }

    public class TransactionDisplayRecord {
        @AuraEnabled public Id Id;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date postingDate;
        @AuraEnabled public String merchantDescription;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String transactionCode;
        @AuraEnabled public String creditDebitFlag;
        @AuraEnabled public String plan;
        @AuraEnabled public String authCode;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String merchantCategoryCode;
        @AuraEnabled public String otpSent;
        @AuraEnabled public String approvalCode;
        @AuraEnabled public String authorizationResponse;
        @AuraEnabled public String declineReasonCode;
        @AuraEnabled public String declineDescription;

    }

    /* =====================================================
       MAIN
       ===================================================== */
    @AuraEnabled(cacheable=false)
    public static TransactionsDTO loadUnbilledTransactions(Id caseId) {

        FEC_Customer_History__c ch = getCustomerHistory(caseId);
        String accNumber = ch.FEC_Account_Number__c;

        /* ===== CALL UNBILLED API ===== */
        List<FEC_GetUnbilledTransactions.TransactionRecord> unbilledTxs =
            new List<FEC_GetUnbilledTransactions.TransactionRecord>();

        FEC_GetUnbilledTransactions.ResponseWrapper uRes =
            FEC_GetUnbilledTransactions.callGetUnbilledTransactions(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accNumber
            );

        if (uRes != null && uRes.Transactions != null) {
            unbilledTxs = uRes.Transactions;
        }

        /* ===== CALL FINANCIAL API ===== */
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> financialTxs =
            new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();

        FEC_GetCardFinancialTransactions.ResponseWrapper fRes =
            FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                accNumber,
                Date.today().addMonths(-3),
                Date.today()
            );

        if (fRes != null && fRes.Transactions != null) {
            financialTxs = fRes.Transactions;
        }

        /* ===== UPSERT ===== */
        upsertTransactions(ch.Id, unbilledTxs, financialTxs);

        /* ===== LOAD FOR UI ===== */
        List<TransactionDisplayRecord> records = new List<TransactionDisplayRecord>();

        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Effective_Date__c,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Merchant_Description__c,
                   FEC_Merchant_Category_Code__c,
                   FEC_Currency_Code__c,
                   FEC_Transaction_Code__c,
                   FEC_Credit_Debit_Flag__c,
                   FEC_Transaction_Plan__c,
                   FEC_Authorization_Code__c,
                   FEC_OTP_Sent__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :ch.Id
            ORDER BY FEC_Post_Date__c DESC
        ]) {

            TransactionDisplayRecord dto = new TransactionDisplayRecord();
            dto.Id = tx.Id;
            dto.effectiveDate = tx.FEC_Effective_Date__c;
            dto.postingDate = tx.FEC_Post_Date__c;
            dto.amount = tx.FEC_Transaction_Amount__c;
            dto.merchantDescription = tx.FEC_Merchant_Description__c;
            dto.merchantCategoryCode = tx.FEC_Merchant_Category_Code__c;
            dto.currencyCode = tx.FEC_Currency_Code__c;
            dto.transactionCode = tx.FEC_Transaction_Code__c;
            dto.creditDebitFlag = tx.FEC_Credit_Debit_Flag__c;
            dto.plan = tx.FEC_Transaction_Plan__c;
            dto.authCode = tx.FEC_Authorization_Code__c;
            dto.otpSent = tx.FEC_OTP_Sent__c;

            records.add(dto);
        }

        TransactionsDTO res = new TransactionsDTO();
        res.accountNumber = accNumber;
        res.transactions = records;
        res.totalCount = records.size();
        res.lastRefreshTime = Datetime.now().format('dd/MM/yyyy HH:mm:ss');

        return res;
    }

    /* =====================================================
       LOAD TRANSACTION DETAIL (BY RECORD ID)
       ===================================================== */
    @AuraEnabled(cacheable=true)
    public static TransactionDisplayRecord loadTransactionDetail(Id transactionId) {

        if (transactionId == null) {
            throw new AuraHandledException('Transaction Id is required');
        }

        FEC_Transaction__c tx = [
            SELECT Id,
                   FEC_Effective_Date__c,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Transaction_Code__c,
                   FEC_Credit_Debit_Flag__c,
                   FEC_Transaction_Plan__c,
                   FEC_Authorization_Code__c,
                   FEC_OTP_Sent__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        TransactionDisplayRecord dto = new TransactionDisplayRecord();
        dto.Id = tx.Id;
        dto.effectiveDate = tx.FEC_Effective_Date__c;
        dto.postingDate = tx.FEC_Post_Date__c;
        dto.amount = tx.FEC_Transaction_Amount__c;
        dto.transactionCode = tx.FEC_Transaction_Code__c;
        dto.creditDebitFlag = tx.FEC_Credit_Debit_Flag__c;
        dto.plan = tx.FEC_Transaction_Plan__c;
        dto.authCode = tx.FEC_Authorization_Code__c;
        dto.otpSent = tx.FEC_OTP_Sent__c;

        return dto;
    }


    /* =====================================================
       GET CUSTOMER HISTORY
       ===================================================== */
    private static FEC_Customer_History__c getCustomerHistory(Id caseId) {

        Case c = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException('Case chưa có Customer History');
        }

        return [
            SELECT Id, FEC_Account_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
            LIMIT 1
        ];
    }

    /* =====================================================
       UPSERT LOGIC
       ===================================================== */
    private static void upsertTransactions(
        Id customerHistoryId,
        List<FEC_GetUnbilledTransactions.TransactionRecord> uList,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList
    ) {

        Map<String, FEC_Transaction__c> existedMap = new Map<String, FEC_Transaction__c>();

        for (FEC_Transaction__c tx : [
            SELECT Id, FEC_Post_Date__c, FEC_Transaction_Amount__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            existedMap.put(tx.FEC_Post_Date__c + '_' + tx.FEC_Transaction_Amount__c, tx);
        }

        List<FEC_Transaction__c> toUpsert = new List<FEC_Transaction__c>();

        for (FEC_GetUnbilledTransactions.TransactionRecord u : uList) {

            Date postDate = FEC_CommonUltils.toDate(u.PostingDate);
            if (postDate == null || u.Amount == null) continue;

            String key = postDate + '_' + u.Amount;
            FEC_Transaction__c rec =
                existedMap.containsKey(key)
                ? existedMap.get(key)
                : new FEC_Transaction__c(FEC_Customer_History__c = customerHistoryId);

            // ===== UNBILLED =====
            rec.FEC_Effective_Date__c = FEC_CommonUltils.toDate(u.TransactionDate);
            rec.FEC_Post_Date__c = postDate;
            rec.FEC_Transaction_Amount__c = u.Amount;
            rec.FEC_Merchant_Description__c = u.Description;
            rec.FEC_Merchant_Category_Code__c = u.MCC;
            rec.FEC_Currency_Code__c = u.CurrencyCode;

            // ===== FINANCIAL =====
            for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
                if (f.TRNXAmount == null) continue;
                if (Math.abs(f.TRNXAmount - u.Amount) > 1) continue;
                if (FEC_CommonUltils.toDate(f.PostingDate) != null && FEC_CommonUltils.toDate(f.PostingDate) != postDate) continue;

                rec.FEC_Transaction_Code__c = f.TransactionCode;
                rec.FEC_Credit_Debit_Flag__c = f.CreditDebitFlag;
                rec.FEC_Transaction_Plan__c = f.Plan;
                rec.FEC_Authorization_Code__c = f.AuthCode;
                rec.FEC_OTP_Sent__c =
                    f.OTPSent == 1 ? 'Yes' :
                    f.OTPSent == 0 ? 'No' : null;
                break;
            }

            toUpsert.add(rec);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }

}