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
        /** Full datetime from API (GetCardBasicInfo TRNXDateTime or M_FAS EFF_DATE+TRANS_TIME). */
        @AuraEnabled public Datetime effectiveDateTime;
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

        /* Unbilled list/detail: BasicInfo (GetCardBasicInfo) | M_FAS (M_FAS_OUTSTANDING_AUTH_INQ) */
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
           UNBILLED – API calls (GetCardBasicInfo + M_FAS_OUTSTANDING_AUTH_INQ only)
           =============================== */
        FEC_CommonUltils.beginDeferredApiLogging();
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTransactions;
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> outstandingAuths;
        try {
            cardTransactions = callCardBasicInfoSafe(accNumber);
            outstandingAuths = callOutstandingAuthSafe(accNumber);

            /* ===============================
               PENDING – unchanged (FEC_VMXAUTHDETAILINQ)
               =============================== */
            res.pendingTransactions = loadPendingRealtime(accNumber, ch.Id);
        } finally {
            FEC_CommonUltils.flushDeferredApiLogs();
        }

        /* ===============================
           UNBILLED – persist + build UI
           =============================== */
        if (!cardTransactions.isEmpty()
            || (outstandingAuths != null && !outstandingAuths.isEmpty())) {
            upsertUnbilledHistory(ch.Id, cardTransactions, outstandingAuths);
        }

        Map<String, Id> idsByCompositeKey = loadTransactionIdsByCompositeKey(ch.Id);
        res.unbilledTransactions = buildUnbilledTransactionsForUi(
            cardTransactions,
            outstandingAuths,
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
                FEC_Customer_History__c,
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
                FEC_Decline_Description__c,
                FEC_Customer_History__r.FEC_Account_Number__c,
                FEC_Customer_History__r.FEC_Contract_Number__c,
                FEC_Customer_History__r.FEC_Case__r.FEC_Account_Number__c,
                FEC_Customer_History__r.FEC_Case__r.FEC_Account_Contract_Number_Text__c,
                FEC_Customer_History__r.FEC_Case__r.FEC_Product_Type__r.Name
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        TransactionDTO dto = mapHistory(tx);
        dto.approvalCode = tx.FEC_Approval_Code__c;
        dto.authorizationResponse = tx.FEC_Authorization_Response__c;
        dto.declineReasonCode = tx.FEC_Decline_Reason_Code__c;
        dto.declineDescription = tx.FEC_Decline_Description__c;

        if (String.isBlank(tx.FEC_Approval_Code__c)) {
            enrichUnbilledDetailFromCardBasic(dto, tx);
        }

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
     * - BasicInfo: GetCardBasicInfo.CardBasicInfo.Transactions
     * - M_FAS: M_FAS_OUTSTANDING_AUTH_INQ.AUTHS_TABLE
     */
    @TestVisible
    private static List<TransactionDTO> buildUnbilledTransactionsForUi(
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTxList,
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authList,
        Map<String, Id> idsByCompositeKey
    ) {
        List<TransactionDTO> result = new List<TransactionDTO>();
        Map<String, String> helpTexts =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authMap =
            buildOutstandingAuthMap(authList);
        Set<String> processedAuthKeys = new Set<String>();

        if (cardTxList != null) {
            for (FEC_GetCardBasicInfo.TransactionInfo cardTx : cardTxList) {
                if (cardTx == null || cardTx.PostingDate == null || cardTx.Amount == null) {
                    continue;
                }
                FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth = findOutstandingAuth(
                    authMap,
                    cardTx.PostingDate,
                    cardTx.Amount,
                    cardTx.AuthCode
                );
                if (auth != null) {
                    String authKey = buildAuthMatchKey(cardTx.PostingDate, cardTx.Amount);
                    if (authKey != null) {
                        processedAuthKeys.add(authKey);
                    }
                }
                String key = buildUnbilledKey(
                    cardTx.PostingDate,
                    cardTx.Amount,
                    cardTx.CreditDebitFlag,
                    resolveUnbilledTransactionCode(cardTx, auth)
                );
                result.add(
                    buildUnbilledDto(
                        cardTx,
                        auth,
                        idsByCompositeKey.get(key),
                        helpTexts
                    )
                );
            }
        }

        if (authList != null) {
            for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth : authList) {
                if (auth == null) {
                    continue;
                }
                Date postDate = FEC_CommonUltils.parseDate(auth.POSTING_DATE);
                Decimal amt = FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT);
                String authKey = buildAuthMatchKey(postDate, amt);
                if (authKey == null || processedAuthKeys.contains(authKey)) {
                    continue;
                }
                String key = buildUnbilledKey(
                    postDate,
                    amt,
                    auth.CreditDebitFlag,
                    resolveUnbilledTransactionCode(null, auth)
                );
                result.add(
                    buildUnbilledDto(null, auth, idsByCompositeKey.get(key), helpTexts)
                );
            }
        }

        return result;
    }

    private static TransactionDTO buildUnbilledDto(
        FEC_GetCardBasicInfo.TransactionInfo cardTx,
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth,
        Id recordId,
        Map<String, String> helpTexts
    ) {
        TransactionDTO dto = new TransactionDTO();
        dto.Id = recordId;
        dto.helpTexts = helpTexts;

        String biTransactionDate = formatCardBasicEffDateTime(cardTx);
        String biPostingDate = cardTx != null && cardTx.PostingDate != null
            ? formatDateDdMmYyyy(cardTx.PostingDate)
            : null;
        String biAmount = formatAmountForDual(cardTx != null ? cardTx.Amount : null);
        String biAuthCode = cardTx != null ? cardTx.AuthCode : null;
        String biPlan = cardTx != null ? cardTx.Plan : null;

        String mfTransactionDate = auth != null
            ? formatOutstandingAuthEffDateTime(auth)
            : null;
        String mfPostingDate = auth != null
            ? formatOutstandingAuthPostDate(auth)
            : null;
        String mfAmount = auth != null
            ? formatAmountForDual(FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT))
            : null;
        String mfAuthCode = auth != null ? auth.AUTHORIZATION_CODE : null;
        String mfPlan = auth != null ? auth.CREDIT_PLAN : null;

        dto.effectiveDateDualDisplay = dualDisplay(biTransactionDate, mfTransactionDate);
        dto.postDateDualDisplay = dualDisplay(biPostingDate, mfPostingDate);
        dto.transactionAmountDualDisplay = dualDisplay(biAmount, mfAmount);
        dto.authorizationCodeDualDisplay = dualDisplay(biAuthCode, mfAuthCode);
        dto.transactionPlanDualDisplay = dualDisplay(biPlan, mfPlan);

        if (cardTx != null && cardTx.TRNXDateTime != null) {
            dto.effectiveDateTime = cardTx.TRNXDateTime;
            dto.effectiveDate = cardTx.TRNXDateTime.date();
        } else if (auth != null) {
            dto.effectiveDateTime = resolveAuthEffectiveDateTime(auth);
            if (dto.effectiveDateTime != null) {
                dto.effectiveDate = dto.effectiveDateTime.date();
            }
        }
        if (dto.effectiveDate == null && auth != null) {
            dto.effectiveDate = FEC_CommonUltils.parseDate(auth.EFF_DATE);
        }
        dto.postingDate = cardTx != null ? cardTx.PostingDate : null;
        if (dto.postingDate == null && auth != null) {
            dto.postingDate = FEC_CommonUltils.parseDate(auth.POSTING_DATE);
        }
        if (cardTx != null) {
            dto.transactionAmount = cardTx.Amount;
        } else if (auth != null) {
            dto.transactionAmount = FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT);
        }
        dto.creditDebitFlag = cardTx != null
            ? cardTx.CreditDebitFlag
            : (auth != null ? auth.CreditDebitFlag : null);
        dto.merchantDescription = cardTx != null
            ? (String.isBlank(cardTx.MerchantName) ? cardTx.Description : cardTx.MerchantName)
            : (auth != null ? auth.Description : null);
        dto.merchantCategoryCode = cardTx != null
            ? cardTx.MCC
            : (auth != null ? auth.MERCH_CAT : null);
        dto.currencyCode = cardTx != null
            ? cardTx.TRNXCurrencyCode
            : (auth != null ? auth.TXN_CURR_CODE : null);
        dto.transactionPlan = auth != null
            ? auth.CREDIT_PLAN
            : (cardTx != null ? cardTx.Plan : null);
        dto.transactionCode = cardTx != null && String.isNotBlank(cardTx.TransactionCode)
            ? cardTx.TransactionCode
            : (auth != null && String.isNotBlank(auth.AUTHORIZATION_CODE)
                ? auth.AUTHORIZATION_CODE
                : 'UNBILLED');
        dto.authorizationCode = auth != null
            ? auth.AUTHORIZATION_CODE
            : (cardTx != null ? cardTx.AuthCode : null);
        if (cardTx != null && cardTx.OTPSent != null) {
            dto.otpSent = cardTx.OTPSent == 1 ? 'Yes' : (cardTx.OTPSent == 0 ? 'No' : null);
        }

        if (dto.effectiveDateTime != null) {
            dto.effectiveSortEpoch = dto.effectiveDateTime.getTime();
        } else {
            dto.effectiveSortEpoch = effectiveSortEpochFromRaw(
                dto.effectiveDate,
                String.isNotBlank(mfTransactionDate) ? mfTransactionDate : biTransactionDate
            );
        }
        return dto;
    }

    private static Datetime resolveAuthEffectiveDateTime(
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth
    ) {
        if (auth == null) {
            return null;
        }
        Date effDate = FEC_CommonUltils.parseDate(auth.EFF_DATE);
        if (effDate == null) {
            return null;
        }
        String timePart = formatHostTime(auth.TRANS_TIME);
        if (String.isBlank(timePart)) {
            return Datetime.newInstance(effDate, Time.newInstance(0, 0, 0, 0));
        }
        List<String> parts = timePart.split(':');
        if (parts.size() < 3) {
            return Datetime.newInstance(effDate, Time.newInstance(0, 0, 0, 0));
        }
        return Datetime.newInstance(
            effDate,
            Time.newInstance(
                Integer.valueOf(parts[0]),
                Integer.valueOf(parts[1]),
                Integer.valueOf(parts[2]),
                0
            )
        );
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

    @TestVisible
    private static Map<String, Id> loadTransactionIdsByCompositeKey(Id customerHistoryId) {
        Map<String, Id> result = new Map<String, Id>();
        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Credit_Debit_Flag__c,
                   FEC_Transaction_Code__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :customerHistoryId
              AND FEC_Approval_Code__c = NULL
        ]) {
            String key = buildUnbilledKey(
                tx.FEC_Post_Date__c,
                tx.FEC_Transaction_Amount__c,
                tx.FEC_Credit_Debit_Flag__c,
                tx.FEC_Transaction_Code__c
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

    private static Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> buildOutstandingAuthMap(
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authList
    ) {
        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authMap =
            new Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
        if (authList == null) {
            return authMap;
        }
        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth : authList) {
            if (auth == null) {
                continue;
            }
            Date postDate = FEC_CommonUltils.parseDate(auth.POSTING_DATE);
            Decimal amt = FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT);
            String key = buildAuthMatchKey(postDate, amt);
            if (key != null) {
                authMap.put(key, auth);
            }
            if (String.isNotBlank(auth.AUTHORIZATION_CODE)) {
                authMap.put(
                    'AUTH:' + auth.AUTHORIZATION_CODE.trim(),
                    auth
                );
            }
        }
        return authMap;
    }

    private static FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow findOutstandingAuth(
        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authMap,
        Date postDate,
        Decimal amount,
        String authCode
    ) {
        if (authMap == null || authMap.isEmpty()) {
            return null;
        }
        String key = buildAuthMatchKey(postDate, amount);
        if (key != null && authMap.containsKey(key)) {
            return authMap.get(key);
        }
        if (String.isNotBlank(authCode)) {
            String authCodeKey = 'AUTH:' + authCode.trim();
            if (authMap.containsKey(authCodeKey)) {
                return authMap.get(authCodeKey);
            }
        }
        return null;
    }

    private static String formatCardBasicEffDateTime(
        FEC_GetCardBasicInfo.TransactionInfo cardTx
    ) {
        if (cardTx == null || cardTx.TRNXDateTime == null) {
            return null;
        }
        Datetime dt = cardTx.TRNXDateTime;
        return formatDateDdMmYyyy(dt.date())
            + ' '
            + pad2(dt.hour())
            + ':'
            + pad2(dt.minute())
            + ':'
            + pad2(dt.second());
    }

    /**
     * Detail tab reads FEC_Effective_Date__c (Date only) → UI shows 07:00:00 VN.
     * Re-match API/mock row to restore full TRNXDateTime for effectiveDateDualDisplay.
     */
    private static void enrichUnbilledDetailFromCardBasic(
        TransactionDTO dto,
        FEC_Transaction__c tx
    ) {
        if (dto == null || tx == null || tx.FEC_Customer_History__c == null) {
            return;
        }

        String acc = resolveAccountFromTransaction(tx);
        if (String.isBlank(acc)) {
            return;
        }

        FEC_GetCardBasicInfo.TransactionInfo cardTx = findCardBasicMatch(
            callCardBasicInfoSafe(acc),
            tx
        );
        if (cardTx == null || cardTx.TRNXDateTime == null) {
            return;
        }

        dto.effectiveDateTime = cardTx.TRNXDateTime;
        dto.effectiveDate = cardTx.TRNXDateTime.date();
        dto.effectiveDateDualDisplay = formatCardBasicEffDateTime(cardTx);
        dto.effectiveSortEpoch = cardTx.TRNXDateTime.getTime();
    }

    private static FEC_GetCardBasicInfo.TransactionInfo findCardBasicMatch(
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTxList,
        FEC_Transaction__c tx
    ) {
        if (cardTxList == null || cardTxList.isEmpty() || tx == null) {
            return null;
        }

        if (String.isNotBlank(tx.FEC_Authorization_Code__c)) {
            for (FEC_GetCardBasicInfo.TransactionInfo cardTx : cardTxList) {
                if (tx.FEC_Authorization_Code__c == cardTx.AuthCode) {
                    return cardTx;
                }
            }
        }

        for (FEC_GetCardBasicInfo.TransactionInfo cardTx : cardTxList) {
            if (matchesUnbilledStoredTx(cardTx, tx)) {
                return cardTx;
            }
        }
        return null;
    }

    private static Boolean matchesUnbilledStoredTx(
        FEC_GetCardBasicInfo.TransactionInfo cardTx,
        FEC_Transaction__c tx
    ) {
        if (cardTx == null || tx == null) {
            return false;
        }
        if (cardTx.PostingDate != tx.FEC_Post_Date__c) {
            return false;
        }
        if (cardTx.Amount != tx.FEC_Transaction_Amount__c) {
            return false;
        }
        if (normDebitCredit(cardTx.CreditDebitFlag)
            != normDebitCredit(tx.FEC_Credit_Debit_Flag__c)) {
            return false;
        }
        if (String.isNotBlank(tx.FEC_Transaction_Code__c)
            && String.isNotBlank(cardTx.TransactionCode)
            && tx.FEC_Transaction_Code__c != cardTx.TransactionCode) {
            return false;
        }
        return true;
    }

    private static String buildAuthMatchKey(Date postDate, Decimal amount) {
        if (postDate == null || amount == null) {
            return null;
        }
        return postDate.format() + '_' + amount.setScale(2);
    }

    private static String formatOutstandingAuthEffDateTime(
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth
    ) {
        if (auth == null) {
            return null;
        }
        Date effDate = FEC_CommonUltils.parseDate(auth.EFF_DATE);
        String datePart = effDate != null
            ? formatDateDdMmYyyy(effDate)
            : auth.EFF_DATE;
        String timePart = formatHostTime(auth.TRANS_TIME);
        if (String.isBlank(datePart)) {
            return null;
        }
        return String.isNotBlank(timePart) ? datePart + ' ' + timePart : datePart;
    }

    private static String formatOutstandingAuthPostDate(
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth
    ) {
        if (auth == null) {
            return null;
        }
        Date postDate = FEC_CommonUltils.parseDate(auth.POSTING_DATE);
        return postDate != null
            ? formatDateDdMmYyyy(postDate)
            : auth.POSTING_DATE;
    }

    private static String formatDateDdMmYyyy(Date d) {
        if (d == null) {
            return null;
        }
        return pad2(d.day()) + '/' + pad2(d.month()) + '/' + String.valueOf(d.year());
    }

    private static String formatHostTime(String timeRaw) {
        if (String.isBlank(timeRaw)) {
            return null;
        }
        String t = timeRaw.trim();
        if (t.length() < 6 || !t.isNumeric()) {
            return null;
        }
        try {
            Integer hh = Integer.valueOf(t.substring(0, 2));
            Integer mm = Integer.valueOf(t.substring(2, 4));
            Integer ss = Integer.valueOf(t.substring(4, 6));
            return pad2(hh) + ':' + pad2(mm) + ':' + pad2(ss);
        } catch (Exception e) {
            return null;
        }
    }

    private static String pad2(Integer n) {
        if (n == null) {
            return '00';
        }
        return n < 10 ? '0' + String.valueOf(n) : String.valueOf(n);
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
       UNBILLED – UPSERT HISTORY (does not touch pending rows)
       ===================================================== */
   private static void upsertUnbilledHistory(
        Id historyId,
        List<FEC_GetCardBasicInfo.TransactionInfo> cardTxList,
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authList
    ) {
        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> authMap =
            buildOutstandingAuthMap(authList);

        Map<String, FEC_Transaction__c> existed = new Map<String, FEC_Transaction__c>();
        for (FEC_Transaction__c tx : [
            SELECT Id,
                   FEC_Post_Date__c,
                   FEC_Transaction_Amount__c,
                   FEC_Credit_Debit_Flag__c,
                   FEC_Transaction_Code__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :historyId
              AND FEC_Approval_Code__c = NULL
        ]) {
            String key = buildUnbilledKey(
                tx.FEC_Post_Date__c,
                tx.FEC_Transaction_Amount__c,
                tx.FEC_Credit_Debit_Flag__c,
                tx.FEC_Transaction_Code__c
            );
            existed.put(key, tx);
        }

        Map<String, FEC_Transaction__c> working = new Map<String, FEC_Transaction__c>();
        Set<String> processedAuthKeys = new Set<String>();

        if (cardTxList != null) {
            for (FEC_GetCardBasicInfo.TransactionInfo cardTx : cardTxList) {
                if (cardTx == null || cardTx.PostingDate == null || cardTx.Amount == null) {
                    continue;
                }

                FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth = findOutstandingAuth(
                    authMap,
                    cardTx.PostingDate,
                    cardTx.Amount,
                    cardTx.AuthCode
                );
                if (auth != null) {
                    String authKey = buildAuthMatchKey(cardTx.PostingDate, cardTx.Amount);
                    if (authKey != null) {
                        processedAuthKeys.add(authKey);
                    }
                }

                String key = buildUnbilledKey(
                    cardTx.PostingDate,
                    cardTx.Amount,
                    cardTx.CreditDebitFlag,
                    resolveUnbilledTransactionCode(cardTx, auth)
                );

                FEC_Transaction__c rec = working.containsKey(key)
                    ? working.get(key)
                    : existed.containsKey(key)
                        ? existed.get(key)
                        : new FEC_Transaction__c(FEC_Customer_History__c = historyId);

                rec.FEC_Effective_Date__c = cardTx.TRNXDateTime != null
                    ? cardTx.TRNXDateTime.date()
                    : cardTx.PostingDate;
                rec.FEC_Post_Date__c = cardTx.PostingDate;
                rec.FEC_Transaction_Amount__c = cardTx.Amount;
                rec.FEC_Credit_Debit_Flag__c = cardTx.CreditDebitFlag;
                rec.FEC_Merchant_Description__c = String.isBlank(cardTx.MerchantName)
                    ? cardTx.Description
                    : cardTx.MerchantName;
                rec.FEC_Merchant_Category_Code__c = cardTx.MCC;
                rec.FEC_Currency_Code__c = cardTx.TRNXCurrencyCode;
                rec.FEC_Transaction_Code__c = String.isNotBlank(cardTx.TransactionCode)
                    ? cardTx.TransactionCode
                    : 'UNBILLED';
                rec.FEC_Transaction_Plan__c = cardTx.Plan;
                rec.FEC_Authorization_Code__c = cardTx.AuthCode;
                rec.FEC_OTP_Sent__c = cardTx.OTPSent == 1
                    ? 'Yes'
                    : (cardTx.OTPSent == 0 ? 'No' : null);

                if (auth != null) {
                    if (String.isNotBlank(auth.CREDIT_PLAN)) {
                        rec.FEC_Transaction_Plan__c = auth.CREDIT_PLAN;
                    }
                    if (String.isNotBlank(auth.AUTHORIZATION_CODE)) {
                        rec.FEC_Authorization_Code__c = auth.AUTHORIZATION_CODE;
                    }
                }

                working.put(key, rec);
            }
        }

        if (authList != null) {
            for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth : authList) {
                if (auth == null) {
                    continue;
                }
                Date postDate = FEC_CommonUltils.parseDate(auth.POSTING_DATE);
                Decimal amt = FEC_CommonUltils.parseAmountSafe(auth.AUTH_AMOUNT);
                String authKey = buildAuthMatchKey(postDate, amt);
                if (authKey == null || processedAuthKeys.contains(authKey)) {
                    continue;
                }

                String key = buildUnbilledKey(
                    postDate,
                    amt,
                    auth.CreditDebitFlag,
                    resolveUnbilledTransactionCode(null, auth)
                );
                FEC_Transaction__c rec = working.containsKey(key)
                    ? working.get(key)
                    : existed.containsKey(key)
                        ? existed.get(key)
                        : new FEC_Transaction__c(FEC_Customer_History__c = historyId);

                rec.FEC_Effective_Date__c = FEC_CommonUltils.parseDate(auth.EFF_DATE);
                if (rec.FEC_Effective_Date__c == null) {
                    rec.FEC_Effective_Date__c = postDate;
                }
                rec.FEC_Post_Date__c = postDate;
                rec.FEC_Transaction_Amount__c = amt;
                rec.FEC_Merchant_Description__c = auth.Description;
                rec.FEC_Credit_Debit_Flag__c = auth.CreditDebitFlag;
                rec.FEC_Transaction_Plan__c = auth.CREDIT_PLAN;
                rec.FEC_Transaction_Code__c = String.isNotBlank(auth.AUTHORIZATION_CODE)
                    ? auth.AUTHORIZATION_CODE
                    : 'UNBILLED';
                rec.FEC_Authorization_Code__c = auth.AUTHORIZATION_CODE;
                rec.FEC_Merchant_Category_Code__c = auth.MERCH_CAT;
                rec.FEC_Currency_Code__c = auth.TXN_CURR_CODE;

                working.put(key, rec);
            }
        }

        if (!working.isEmpty()) {
            upsert working.values();
        }
    }



    /* =====================================================
       SAFE CALLS
       ===================================================== */
    private static List<FEC_GetCardBasicInfo.TransactionInfo>
    callCardBasicInfoSafe(String acc) {
        try {
            FEC_GetCardBasicInfo.ResponseWrapper res =
                FEC_GetCardBasicInfo.callGetCardBasicInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    acc
                );
            return res != null
                && res.CardBasicInfo != null
                && res.CardBasicInfo.Transactions != null
                ? res.CardBasicInfo.Transactions
                : new List<FEC_GetCardBasicInfo.TransactionInfo>();
        } catch (Exception e) {
            return new List<FEC_GetCardBasicInfo.TransactionInfo>();
        }
    }

    private static List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>
    callOutstandingAuthSafe(String acc) {
        try {
            FEC_MFASOUTSTANDINGAUTHINQ.ResponseWrapper res =
                FEC_MFASOUTSTANDINGAUTHINQ.callService(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    FEC_ConstantCommon.VMX_VERSION_DEFAULT,
                    FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                    FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT,
                    FEC_ConstantCommon.REQUESTOR_ORG,
                    acc
                );
            return res != null
                && res.VMXMsgOut != null
                && res.VMXMsgOut.Auths != null
                ? res.VMXMsgOut.Auths
                : new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
        } catch (Exception e) {
            return new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
        }
    }

    /* =====================================================
       COMMON
       ===================================================== */
    private static String resolveAccountFromTransaction(FEC_Transaction__c tx) {
        if (tx == null || tx.FEC_Customer_History__r == null) {
            return null;
        }

        String fromHistory = FEC_CommonUltils.resolveAccountNumber(
            tx.FEC_Customer_History__r.FEC_Case__r?.FEC_Product_Type__r?.Name,
            tx.FEC_Customer_History__r.FEC_Account_Number__c,
            tx.FEC_Customer_History__r.FEC_Contract_Number__c
        );
        if (String.isNotBlank(fromHistory)) {
            return fromHistory.trim();
        }
        if (String.isNotBlank(tx.FEC_Customer_History__r.FEC_Case__r?.FEC_Account_Number__c)) {
            return tx.FEC_Customer_History__r.FEC_Case__r.FEC_Account_Number__c.trim();
        }
        if (String.isNotBlank(
            tx.FEC_Customer_History__r.FEC_Case__r?.FEC_Account_Contract_Number_Text__c
        )) {
            return tx.FEC_Customer_History__r.FEC_Case__r.FEC_Account_Contract_Number_Text__c.trim();
        }
        return null;
    }

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

    private static String resolveUnbilledTransactionCode(
        FEC_GetCardBasicInfo.TransactionInfo cardTx,
        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow auth
    ) {
        if (cardTx != null && String.isNotBlank(cardTx.TransactionCode)) {
            return cardTx.TransactionCode;
        }
        if (auth != null && String.isNotBlank(auth.AUTHORIZATION_CODE)) {
            return auth.AUTHORIZATION_CODE;
        }
        return 'UNBILLED';
    }

    private static String buildUnbilledKey(
        Date postDate,
        Decimal amount,
        String creditDebit,
        String transactionCode
    ) {
        if (postDate == null || amount == null) {
            return null;
        }

        String code = String.isBlank(transactionCode)
            ? 'UNBILLED'
            : transactionCode.trim().toUpperCase();

        return postDate.format() + '_' +
            amount.setScale(2) + '_' +
            normDebitCredit(creditDebit) + '_' +
            code;
    }

    private static String normDebitCredit(String s) {
        if (String.isBlank(s)) return '';

        s = s.trim().toUpperCase();

        if (s == 'D' || s == 'DEBIT' || s == 'DR') return 'DEBIT';
        if (s == 'C' || s == 'CREDIT' || s == 'CR') return 'CREDIT';

        return s;
    }
}