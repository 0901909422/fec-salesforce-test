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

        /** Sort key for unbilled/pending tables (epoch ms). */
        @AuraEnabled public Long effectiveSortEpoch;

        /* Unbilled list/detail: BasicInfo (GetUnbilledTransactions) | M_FAS (GetCardFinancialTransactions) */
        @AuraEnabled public String effectiveDateDualDisplay;
        @AuraEnabled public String postDateDualDisplay;
        @AuraEnabled public String transactionAmountDualDisplay;
        @AuraEnabled public String authorizationCodeDualDisplay;
        @AuraEnabled public String transactionPlanDualDisplay;

        /* Pending list/detail: M_FAS AUTH_GRP summary | VMX AUTH detail (DTL_*) */
        @AuraEnabled public String approvalCode;
        @AuraEnabled public String authorizationResponse;
        @AuraEnabled public String declineReasonCode;
        @AuraEnabled public String declineDescription;
        @AuraEnabled public String merchantDescriptionDualDisplay;
        @AuraEnabled public String merchantCategoryDualDisplay;
        @AuraEnabled public String currencyCodeDualDisplay;
        @AuraEnabled public String approvalCodeDualDisplay;
        @AuraEnabled public String authorizationResponseDualDisplay;
        @AuraEnabled public String declineDescriptionDualDisplay;
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
            SELECT FEC_Account_or_Contract__c,
                   FEC_Product_Type__r.Name,
                   FEC_Account_Number__c,
                   FEC_Account_Contract_Number_Text__c
            FROM Case
            WHERE Id = :caseId
        ];

        if (c.FEC_Account_or_Contract__c == null) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }

        FEC_Customer_History__c ch = [
            SELECT Id, FEC_Account_Number__c, FEC_Contract_Number__c
            FROM FEC_Customer_History__c
            WHERE Id = :c.FEC_Account_or_Contract__c
        ];

        String accNumber = resolveAccountForTransactions(c, ch);
        if (String.isBlank(accNumber)) {
            throw new AuraHandledException(System.Label.FEC_MSG_Not_Account_Linked);
        }
    
        TransactionsResponse res = new TransactionsResponse();
        res.unbilledTransactions = new List<TransactionDTO>();
        res.pendingTransactions  = new List<TransactionDTO>();

        /* ===============================
           HISTORY - CALL OUT
           =============================== */
        FEC_CommonUltils.beginDeferredApiLogging();
        List<FEC_GetUnbilledTransactions.TransactionRecord> unbilled;
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> financial;
        try {
            unbilled = callUnbilledSafe(accNumber);
            financial = callFinancialSafe(accNumber);
            res.pendingTransactions = loadPendingRealtime(accNumber, ch.Id);
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        /* ===============================
           Persist + build UI from live API (Fields List mapping)
           =============================== */
        if (!unbilled.isEmpty() || !financial.isEmpty()) {
            upsertHistory(ch.Id, unbilled, financial);
        }

        Map<String, Id> idsByCompositeKey = loadTransactionIdsByCompositeKey(ch.Id);
        res.unbilledTransactions = buildUnbilledTransactionsForUi(
            unbilled,
            financial,
            idsByCompositeKey
        );
        if (res.unbilledTransactions.isEmpty()) {
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
              AND FEC_Approval_Code__c = NULL
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
                FEC_OTP_Sent__c,
                FEC_Approval_Code__c,
                FEC_Authorization_Response__c,
                FEC_Decline_Reason_Code__c,
                FEC_Decline_Description__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        TransactionDTO dto = mapHistory(tx);
        dto.approvalCode = tx.FEC_Approval_Code__c;
        dto.authorizationResponse = tx.FEC_Authorization_Response__c;
        dto.declineReasonCode = tx.FEC_Decline_Reason_Code__c;
        dto.declineDescription = tx.FEC_Decline_Description__c;
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
        dto.effectiveSortEpoch = effectiveSortEpochFromRaw(
            tx.FEC_Effective_Date__c,
            null
        );
        return dto;
    }

    /* =====================================================
       PENDING 
       ===================================================== */
    private static List<TransactionDTO> loadPendingRealtime(String accNumber, Id historyId) {

        List<TransactionDTO> result = new List<TransactionDTO>();

        try {
            FEC_VMXAUTHDETAILINQ.ResponseWrapper res =
                FEC_VMXAUTHDETAILINQ.callService(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    FEC_ConstantCommon.VMX_VERSION_DEFAULT,
                    FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                    FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                    accNumber,
                    FEC_ConstantCommon.STR_EMPTY
                );

            if (res == null
                || res.VMXMsgOut == null
                || res.VMXMsgOut.Auths == null
                || res.VMXMsgOut.Auths.isEmpty()) {
                return result;
            }

            List<FEC_VMXAUTHDETAILINQ.AuthTableRow> auths = res.VMXMsgOut.Auths;
            List<String> txCodes = new List<String>();

            Integer idx = 0;
            for (FEC_VMXAUTHDETAILINQ.AuthTableRow auth : auths) {
                idx++;
                txCodes.add(resolvePendingTxCode(auth, idx));
            }

            Map<String, FEC_Transaction__c> existedByCode = new Map<String, FEC_Transaction__c>();
            for (FEC_Transaction__c tx : [
                SELECT Id, FEC_Transaction_Code__c
                FROM FEC_Transaction__c
                WHERE FEC_Customer_History__c = :historyId
                  AND FEC_Transaction_Code__c IN :txCodes
            ]) {
                existedByCode.put(tx.FEC_Transaction_Code__c, tx);
            }

            List<FEC_Transaction__c> toUpsert = new List<FEC_Transaction__c>();
            idx = 0;
            for (FEC_VMXAUTHDETAILINQ.AuthTableRow auth : auths) {
                idx++;
                String txCode = txCodes[idx - 1];
                FEC_Transaction__c tx = existedByCode.containsKey(txCode)
                    ? existedByCode.get(txCode)
                    : new FEC_Transaction__c(FEC_Customer_History__c = historyId);
                mapPendingAuthToTransaction(tx, auth, txCode);
                toUpsert.add(tx);
            }

            if (!toUpsert.isEmpty()) {
                upsert toUpsert;
            }

            Map<String, String> helpTexts =
                FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

            idx = 0;
            for (FEC_Transaction__c tx : toUpsert) {
                idx++;
                result.add(mapPendingToDto(tx, auths[idx - 1], helpTexts));
            }

        } catch (Exception e) {
            System.debug('### PENDING TXN ERROR: ' + e.getMessage());
            return new List<TransactionDTO>();
        }

        return result;
    }

    private static String resolvePendingTxCode(
        FEC_VMXAUTHDETAILINQ.AuthTableRow auth,
        Integer idx
    ) {
        if (String.isNotBlank(auth.AUTHORIZATION_CODE)) {
            return auth.AUTHORIZATION_CODE;
        }
        if (String.isNotBlank(auth.AUTH_CD)) {
            return auth.AUTH_CD;
        }
        String stableKey = String.join(
            new List<String>{
                auth.EFF_DATE,
                auth.AUTH_AMOUNT,
                auth.Description,
                String.valueOf(idx)
            },
            '|'
        );
        return 'PENDING_' + String.valueOf(Math.abs(stableKey.hashCode()));
    }

    private static void mapPendingAuthToTransaction(
        FEC_Transaction__c tx,
        FEC_VMXAUTHDETAILINQ.AuthTableRow auth,
        String txCode
    ) {
        Date effDate = FEC_CommonUltils.toDateStr(
            String.isNotBlank(auth.EFF_DATE) ? auth.EFF_DATE : auth.EFF_DATE_AUTH_DETAIL
        );
        Date postDate = FEC_CommonUltils.toDateStr(auth.POSTING_DATE);
        if (postDate == null) {
            postDate = effDate;
        }

        String authCode = String.isNotBlank(auth.AUTHORIZATION_CODE)
            ? auth.AUTHORIZATION_CODE
            : auth.AUTH_CD;

        tx.FEC_Transaction_Code__c = txCode;
        tx.FEC_Effective_Date__c = effDate;
        tx.FEC_Post_Date__c = postDate;
        tx.FEC_Transaction_Amount__c = FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT);
        tx.FEC_Merchant_Description__c = auth.Description;
        tx.FEC_Transaction_Plan__c = auth.CREDIT_PLAN;
        tx.FEC_Authorization_Code__c = authCode;
        tx.FEC_Approval_Code__c = auth.AUTH_CD;
        tx.FEC_Authorization_Response__c = String.isNotBlank(auth.FINAL_ACTN)
            ? auth.FINAL_ACTN
            : auth.DTL_FINAL_ACTN;
        tx.FEC_Decline_Description__c = String.isNotBlank(auth.ACTN_RSN_DESC)
            ? auth.ACTN_RSN_DESC
            : auth.DTL_ACTN_RSN_DESC;
        tx.FEC_Merchant_Category_Code__c = auth.MERCH_CAT;
        tx.FEC_Currency_Code__c = auth.TXN_CURR_CODE;
    }

    private static TransactionDTO mapPendingToDto(
        FEC_Transaction__c tx,
        FEC_VMXAUTHDETAILINQ.AuthTableRow auth,
        Map<String, String> helpTexts
    ) {
        TransactionDTO dto = new TransactionDTO();
        dto.Id = tx.Id;
        dto.effectiveDate = tx.FEC_Effective_Date__c;
        dto.postingDate = tx.FEC_Post_Date__c;
        dto.transactionAmount = tx.FEC_Transaction_Amount__c;
        dto.merchantDescription = tx.FEC_Merchant_Description__c;
        dto.transactionPlan = tx.FEC_Transaction_Plan__c;
        dto.transactionCode = tx.FEC_Transaction_Code__c;
        dto.authorizationCode = tx.FEC_Authorization_Code__c;
        dto.approvalCode = tx.FEC_Approval_Code__c;
        dto.authorizationResponse = tx.FEC_Authorization_Response__c;
        dto.declineDescription = tx.FEC_Decline_Description__c;
        dto.merchantCategoryCode = tx.FEC_Merchant_Category_Code__c;
        dto.currencyCode = tx.FEC_Currency_Code__c;
        dto.helpTexts = helpTexts;
        dto.effectiveSortEpoch = effectiveSortEpochFromRaw(
            tx.FEC_Effective_Date__c,
            auth != null ? auth.EFF_DATE : null
        );

        if (auth != null) {
            applyPendingDualDisplayFromAuth(dto, auth);
        }
        return dto;
    }

    /* =====================================================
       FIELDS LIST – API → UI (see inline mapping per method)
       ===================================================== */

    /**
     * Unbilled table: dual column = BasicInfo | M_FAS
     * - BasicInfo: GetUnbilledTransactions (E-Statement)
     * - M_FAS: GetCardFinancialTransactions (CIF Card Info)
     */
    private static List<TransactionDTO> buildUnbilledTransactionsForUi(
        List<FEC_GetUnbilledTransactions.TransactionRecord> uList,
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList,
        Map<String, Id> idsByCompositeKey
    ) {
        List<TransactionDTO> result = new List<TransactionDTO>();
        Map<String, String> helpTexts =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

        Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction> finMap =
            buildFinancialMap(fList);
        Set<String> processedFinKeys = new Set<String>();

        if (uList != null) {
            for (FEC_GetUnbilledTransactions.TransactionRecord u : uList) {
                Date postDate = FEC_CommonUltils.toDateStr(u.PostingDate);
                if (postDate == null || u.Amount == null) {
                    continue;
                }
                String key = buildKey(postDate, u.Amount, u.TransactionType);
                FEC_GetCardFinancialTransactions.FinancialTransaction f =
                    finMap.containsKey(key) ? finMap.get(key) : null;
                if (key != null && f != null) {
                    processedFinKeys.add(key);
                }
                result.add(
                    buildUnbilledDto(u, f, idsByCompositeKey.get(key), helpTexts)
                );
            }
        }

        if (fList != null) {
            for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
                Date postDate = FEC_CommonUltils.toDateStr(f.PostingDate);
                if (postDate == null || f.TRNXAmount == null) {
                    continue;
                }
                String key = buildKey(postDate, f.TRNXAmount, f.CreditDebitFlag);
                if (key == null || processedFinKeys.contains(key)) {
                    continue;
                }
                result.add(
                    buildUnbilledDto(null, f, idsByCompositeKey.get(key), helpTexts)
                );
            }
        }

        return result;
    }

    private static Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction>
    buildFinancialMap(List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList) {
        Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction> finMap =
            new Map<String, FEC_GetCardFinancialTransactions.FinancialTransaction>();
        if (fList == null) {
            return finMap;
        }
        for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
            Date postDate = FEC_CommonUltils.toDateStr(f.PostingDate);
            if (postDate == null || f.TRNXAmount == null) {
                continue;
            }
            String key = buildKey(postDate, f.TRNXAmount, f.CreditDebitFlag);
            if (key != null) {
                finMap.put(key, f);
            }
        }
        return finMap;
    }

    private static TransactionDTO buildUnbilledDto(
        FEC_GetUnbilledTransactions.TransactionRecord u,
        FEC_GetCardFinancialTransactions.FinancialTransaction f,
        Id recordId,
        Map<String, String> helpTexts
    ) {
        TransactionDTO dto = new TransactionDTO();
        dto.Id = recordId;
        dto.helpTexts = helpTexts;

        String biTransactionDate = u != null ? u.TransactionDate : null;
        String biPostingDate = u != null ? u.PostingDate : null;
        String biAmount = formatAmountForDual(u != null ? u.Amount : null);
        String biAuthCode = null;
        String biPlan = null;

        String mfTransactionDate = f != null ? f.TRNXDateAndTime : null;
        String mfPostingDate = f != null ? f.PostingDate : null;
        String mfAmount = formatAmountForDual(f != null ? f.TRNXAmount : null);
        String mfAuthCode = f != null ? f.AuthCode : null;
        String mfPlan = f != null ? f.Plan : null;

        dto.effectiveDateDualDisplay = dualDisplay(biTransactionDate, mfTransactionDate);
        dto.postDateDualDisplay = dualDisplay(biPostingDate, mfPostingDate);
        dto.transactionAmountDualDisplay = dualDisplay(biAmount, mfAmount);
        dto.authorizationCodeDualDisplay = dualDisplay(biAuthCode, mfAuthCode);
        dto.transactionPlanDualDisplay = dualDisplay(biPlan, mfPlan);

        dto.effectiveDate = FEC_CommonUltils.toDateStr(biTransactionDate);
        if (dto.effectiveDate == null && f != null) {
            dto.effectiveDate = FEC_CommonUltils.toDateStr(f.TRNXDateAndTime);
            if (dto.effectiveDate == null) {
                dto.effectiveDate = FEC_CommonUltils.toDateStr(f.PostingDate);
            }
        }
        dto.postingDate = FEC_CommonUltils.toDateStr(biPostingDate);
        if (dto.postingDate == null && f != null) {
            dto.postingDate = FEC_CommonUltils.toDateStr(f.PostingDate);
        }
        dto.transactionAmount = u != null ? u.Amount : (f != null ? f.TRNXAmount : null);
        dto.creditDebitFlag = u != null
            ? u.TransactionType
            : (f != null ? f.CreditDebitFlag : null);
        dto.merchantDescription = u != null
            ? u.MerchantName
            : (f != null
                ? (String.isBlank(f.MerchantName) ? f.Description : f.MerchantName)
                : null);
        dto.merchantCategoryCode = u != null ? u.MCC : null;
        dto.currencyCode = u != null
            ? u.CurrencyCode
            : (f != null ? f.TRNXCurrencyCode : null);
        dto.transactionPlan = f != null ? f.Plan : null;
        dto.transactionCode = f != null && String.isNotBlank(f.TransactionCode)
            ? f.TransactionCode
            : 'UNBILLED';
        dto.authorizationCode = f != null ? f.AuthCode : null;
        if (f != null && f.OTPSent != null) {
            dto.otpSent = f.OTPSent == 1 ? 'Yes' : (f.OTPSent == 0 ? 'No' : null);
        }

        dto.effectiveSortEpoch = effectiveSortEpochFromRaw(
            dto.effectiveDate,
            String.isNotBlank(mfTransactionDate) ? mfTransactionDate : biTransactionDate
        );
        return dto;
    }

    /**
     * Pending table: dual column = M_FAS AUTH_GRP (summary) | VMX detail (DTL_* / EFF_DATE_AUTH_DETAIL)
     */
    private static void applyPendingDualDisplayFromAuth(
        TransactionDTO dto,
        FEC_VMXAUTHDETAILINQ.AuthTableRow auth
    ) {
        String mfasEff = auth.EFF_DATE;
        String vmxEff = String.isNotBlank(auth.EFF_DATE_AUTH_DETAIL)
            ? auth.EFF_DATE_AUTH_DETAIL
            : auth.EFF_DATE;

        dto.effectiveDateDualDisplay = dualDisplay(mfasEff, vmxEff);
        dto.transactionAmountDualDisplay = dualDisplay(
            auth.AUTH_AMOUNT,
            auth.DTL_AUTH_AMT
        );
        dto.merchantDescriptionDualDisplay = dualDisplay(
            auth.Description,
            auth.DTL_MERC_NAME_LOC
        );
        dto.transactionPlanDualDisplay = dualDisplay(
            auth.CREDIT_PLAN,
            auth.DTL_CR_PLAN
        );
        dto.merchantCategoryDualDisplay = dualDisplay(
            auth.MERCH_CAT,
            auth.DTL_MERCH_CAT
        );
        dto.currencyCodeDualDisplay = dualDisplay(
            auth.TXN_CURR_CODE,
            auth.DTL_TXN_CURR_CODE
        );
        dto.approvalCodeDualDisplay = dualDisplay(
            auth.AUTH_CD,
            auth.MSGOUT_AUTH_CD
        );
        dto.authorizationResponseDualDisplay = dualDisplay(
            auth.FINAL_ACTN,
            auth.DTL_FINAL_ACTN
        );
        dto.declineDescriptionDualDisplay = dualDisplay(
            auth.ACTN_RSN_DESC,
            auth.DTL_ACTN_RSN_DESC
        );
    }

    private static Map<String, Id> loadTransactionIdsByCompositeKey(Id customerHistoryId) {
        Map<String, Id> result = new Map<String, Id>();
        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Credit_Debit_Flag__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :customerHistoryId
        ]) {
            String key = buildKey(
                tx.FEC_Post_Date__c,
                tx.FEC_Transaction_Amount__c,
                tx.FEC_Credit_Debit_Flag__c
            );
            if (key != null) {
                result.put(key, tx.Id);
            }
        }
        return result;
    }

    /**
     * Fields List dual column: "BasicInfo | M_FAS" (or M_FAS | VMX detail for pending).
     * If only one source has data, return that value (no "- |" prefix).
     */
    private static String dualDisplay(String left, String right) {
        String l = String.isBlank(left) ? null : left.trim();
        String r = String.isBlank(right) ? null : right.trim();
        if (l == null && r == null) {
            return null;
        }
        if (l == null) {
            return r;
        }
        if (r == null) {
            return l;
        }
        if (l == r) {
            return l;
        }
        return l + ' | ' + r;
    }

    private static String formatAmountForDual(Decimal amount) {
        return amount == null ? null : String.valueOf(amount.setScale(2));
    }

    private static Long effectiveSortEpochFromRaw(Date fallbackDate, String rawDateTime) {
        if (String.isNotBlank(rawDateTime)) {
            Datetime dt = FEC_CommonUltils.parseDateTime(rawDateTime);
            if (dt != null) {
                return dt.getTime();
            }
        }
        if (fallbackDate != null) {
            return Datetime.newInstance(fallbackDate, Time.newInstance(0, 0, 0, 0)).getTime();
        }
        return 0L;
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

        /* ===============================
           4. Financial-only rows (no unbilled match)
           =============================== */
        for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
            Date postDate = FEC_CommonUltils.toDateStr(f.PostingDate);
            if (postDate == null || f.TRNXAmount == null) {
                continue;
            }

            String key = buildKey(postDate, f.TRNXAmount, f.CreditDebitFlag);
            if (key == null || working.containsKey(key)) {
                continue;
            }

            FEC_Transaction__c rec = existed.containsKey(key)
                ? existed.get(key)
                : new FEC_Transaction__c(FEC_Customer_History__c = historyId);

            Date effDate = FEC_CommonUltils.toDateStr(f.TRNXDateAndTime);
            if (effDate == null) {
                effDate = postDate;
            }

            rec.FEC_Effective_Date__c = effDate;
            rec.FEC_Post_Date__c = postDate;
            rec.FEC_Transaction_Amount__c = f.TRNXAmount;
            rec.FEC_Credit_Debit_Flag__c = f.CreditDebitFlag;
            rec.FEC_Merchant_Description__c = String.isBlank(f.MerchantName)
                ? f.Description
                : f.MerchantName;
            rec.FEC_Transaction_Code__c = f.TransactionCode;
            rec.FEC_Transaction_Plan__c = f.Plan;
            rec.FEC_Authorization_Code__c = f.AuthCode;
            rec.FEC_Currency_Code__c = f.TRNXCurrencyCode;
            rec.FEC_OTP_Sent__c = f.OTPSent == 1 ? 'Yes' : (f.OTPSent == 0 ? 'No' : null);

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
    private static String resolveAccountForTransactions(
        Case c,
        FEC_Customer_History__c ch
    ) {
        String fromHistory = FEC_CommonUltils.resolveAccountNumber(
            c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null,
            ch.FEC_Account_Number__c,
            ch.FEC_Contract_Number__c
        );
        if (String.isNotBlank(fromHistory)) {
            return fromHistory.trim();
        }
        if (String.isNotBlank(c.FEC_Account_Number__c)) {
            return c.FEC_Account_Number__c.trim();
        }
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return c.FEC_Account_Contract_Number_Text__c.trim();
        }
        return null;
    }

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