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

    /* =====================================================
       DTO
       ===================================================== */
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

        /* ===============================
           PENDING - CALL OUT
           =============================== */
        res.pendingTransactions = loadPendingRealtime(accNumber,ch.Id);

        /* ===============================
           HISTORY
           =============================== */
        if (!unbilled.isEmpty()) {
            upsertHistory(ch.Id, unbilled, financial);
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
    private static List<TransactionDTO> loadPendingRealtime(String accNumber,  Id historyId) {

        List<TransactionDTO> result = new List<TransactionDTO>();

        try {
            FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper res =
                FEC_MFASOUTSTANDINGAUTHINQ.callService(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    FEC_ConstantCommon.REQUESTOR_VMXVERSION,
                    FEC_ConstantCommon.REQUESTOR_CONTEXT,
                    UserInfo.getUserId(),
                    FEC_ConstantCommon.REQUESTOR_ORG,
                    accNumber
                );

            if (res == null || res.VMXMsgOut == null) return result;
            FEC_Transaction__c tx;

            List<FEC_Transaction__c> existed = [
                SELECT Id
                FROM FEC_Transaction__c
                WHERE FEC_Customer_History__c = :historyId
                LIMIT 1
            ];

            if (!existed.isEmpty()) {
                tx = existed[0];  
            } else {
                tx = new FEC_Transaction__c(
                    FEC_Customer_History__c = historyId
                );
            }

            tx.FEC_Transaction_Code__c = res.VMXMsgOut.REQ_TYPE;
            upsert tx;

            TransactionDTO dto = new TransactionDTO();
            dto.Id = tx.Id;
            //dto.effectiveDate = FEC_CommonUltils.toDate(res.VMXMsgOut.EFF_DATE);
            //dto.transactionAmount = res.VMXMsgOut.AUTH_AMT;
            //dto.merchantDescription = res.VMXMsgOut.MERC_NAME_LOC;
            //dto.transactionPlan = res.VMXMsgOut.CR_PLAN;
            dto.transactionCode = res.VMXMsgOut.REQ_TYPE;
            //dto.authorizationCode = res.VMXMsgOut.AUTH_CD;
            //dto.approvalCode = res.VMXMsgOut.AUTH_CD;
            //dto.authorizationResponse = res.VMXMsgOut.FINAL_ACTN;
            //dto.declineDescription = res.VMXMsgOut.ACTN_RSN_DESC;
            //dto.merchantCategoryCode = res.VMXMsgOut.MERCH_CAT;
            //dto.currencyCode = res.VMXMsgOut.TXN_CURR_CODE;

            dto.helpTexts = FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);
            result.add(dto);

        } catch (Exception e) {
            return new List<TransactionDTO>();
        }

        return result;
    }

    /* =====================================================
       UPSERT HISTORY
       ===================================================== */
   private static void upsertHistory(
        Id historyId,
        List<FEC_GetUnbilledTransactions.TransactionRecord> uList,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList
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
            rec.FEC_Currency_Code__c = u.CurrencyCode;

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

    /* =====================================================
       COMMON
       ===================================================== */
    private static FEC_Customer_History__c getCustomerHistory(Id caseId) {
        Case c = [
            SELECT FEC_Account_or_Contract__c, FEC_Product_Type__r.Name
            FROM Case
            WHERE Id = :caseId
        ];
        if (c.FEC_Account_or_Contract__c == null)
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);

        return [
            SELECT Id, FEC_Account_Number__c,FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
        ];
    }

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