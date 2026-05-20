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
   1.1      2026-05-12     Agent                Unbilled: GetCardBasicInfo + M_FAS (FEC account number), Effective Date first slice
   1.2      2026-05-12     Agent                Map Post Date, Amount, Merchant (Basic + AUTHS_TABLE)
   1.3      2026-05-12     Agent                Unbilled sheet: CreditDebit, Plan (FAS), Code, Auth, MCC, Currency, OTP
   1.4      2026-05-12     Agent                Currency: TRNXCurrencyCode from API as-is (trim); doc examples e.g. numeric codes illustrative only
   1.5      2026-05-12     Agent                Unbilled UI: dual-source display strings (BasicInfo | M_FAS) where mapping has two APIs
   1.6      2026-05-12     Agent                TransactionDTO.effectiveSortEpoch for LWC sort when effective column shows dual text
   1.7      2026-05-12     Agent                loadTransactionDetail: same Basic+M_FAS augment as list for dual-display fields
   1.8      2026-05-12     Agent                Dual-display cell text: value | value (no long API path prefixes)
   1.9      2026-05-12     Agent                Dual cells: omit " | ΓÇö" when only one side has data
   2.0      2026-05-12     Agent                Pending: rows from AUTHS_TABLE; dual M_FAS|Detail (detail null); new row fields for sheet
   2.1      2026-05-12     Agent                Pending: eff from POSTING if needed; MFAS AUTH_GRP + AUTH_AMT + pad when Auths empty
   2.2      2026-05-12     Agent                Pending DTOs from same fasAuthRows as unbilled M_FAS call (FEC ACCT); remove duplicate Case-ACCT callout
   2.3      2026-05-12     Agent                Pending effective: prefer AUTH_GRP EFF_DATE (VMX_AUTH_DETAIL path); dual detail|AUTHS_TABLE
   2.4      2026-05-12     Agent                M_FAS ACCT: use Case-resolved account (same as BasicInfo); hardcode only when blank
   2.5      2026-05-14     Agent                Currency display: TRNXCurrencyCode + GetCardFinancial + FEC_Currency_Code__c master (code-Name)
   2.6      2026-05-20     Agent                Pending: VMX_AUTH_DETAIL_INQ; account via FEC_API_Setting + FEC_MFASOUTSTANDINGAUTHINQ metadata
 
****************************************************************************************/

public without sharing class FEC_TransactionsController {

    /**
     * Fallback ACCT for M_FAS when {@code resolvedAccountNumber} is blank
     * (integration / non-prod only; prefer Case-resolved account).
     */
    private static final String M_FAS_UNBILLED_ACCOUNT_NUMBER = '0001500040000597830';
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

        /** Dual-source labels for unbilled: "value | value" (left GetCardBasicInfo, right M_FAS); null when no second source. */
        @AuraEnabled public String effectiveDateDualDisplay;
        @AuraEnabled public String postDateDualDisplay;
        @AuraEnabled public String transactionAmountDualDisplay;
        @AuraEnabled public String authorizationCodeDualDisplay;
        @AuraEnabled public String transactionPlanDualDisplay;

        /** Pending: dual M_FAS vs VMX_AUTH_DETAIL (detail side null until integrated). */
        @AuraEnabled public String merchantDescriptionDualDisplay;
        @AuraEnabled public String merchantCategoryDualDisplay;
        @AuraEnabled public String currencyCodeDualDisplay;
        @AuraEnabled public String approvalCodeDualDisplay;
        @AuraEnabled public String authorizationResponseDualDisplay;
        @AuraEnabled public String declineDescriptionDualDisplay;

        /** Millis at GMT midnight of merged effective date ΓÇö for client sort when UI shows dual strings. */
        @AuraEnabled public Long effectiveSortEpoch;
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
           HISTORY - GetCardBasicInfo (priority) + M_FAS AUTHS_TABLE
           =============================== */
        List<FEC_GetCardBasicInfo.TransactionInfo> basicTx =
            callBasicInfoSafe(accNumber);

        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasAuthRows =
            callMfasAuthsTableSafe(accNumber);

        List<FEC_GetCardFinancialTransactions.FinancialTransaction> financial =
            callFinancialSafe(accNumber);

        Set<String> numericCodes = new Set<String>();
        for (FEC_GetCardBasicInfo.TransactionInfo ti : basicTx) {
            if (String.isNotBlank(ti.TRNXCurrencyCode)) {
                numericCodes.add(ti.TRNXCurrencyCode.trim());
            }
        }
        for (FEC_GetCardFinancialTransactions.FinancialTransaction f : financial) {
            if (String.isNotBlank(f.TRNXCurrencyCode)) {
                numericCodes.add(f.TRNXCurrencyCode.trim());
            }
        }
        Map<String, String> currencyDisplayMap =
            FEC_CurrencyCodeLookup.buildNumericCodeToDisplayMap(numericCodes);
        Map<String, String> finTrnxCurrencyByKey = buildFinTrnxCurrencyByKey(financial);

        /* ===============================
           PENDING - VMX_AUTH_DETAIL_INQ (metadata FEC_MFASOUTSTANDINGAUTHINQ)
           =============================== */
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> pendingFasAuthRows =
            callVmxAuthDetailInqSafe(accNumber);
        res.pendingTransactions = buildPendingDtosFromAuthRows(pendingFasAuthRows);

        /* ===============================
           HISTORY
           =============================== */
        if (!basicTx.isEmpty() || !fasAuthRows.isEmpty()) {
            upsertHistoryFromBasicInfoAndFas(
                ch.Id,
                basicTx,
                fasAuthRows,
                finTrnxCurrencyByKey,
                currencyDisplayMap
            );
            res.unbilledTransactions = loadHistoryForUI(ch.Id);
            augmentUnbilledDtosWithDualDisplay(
                res.unbilledTransactions,
                basicTx,
                fasAuthRows
            );
        }

        return res;
    }

    /* =====================================================
       HISTORY ΓÇô LOAD UI
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
        if (transactionId == null) {
            return null;
        }

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
                FEC_Customer_History__r.FEC_Account_Number__c,
                FEC_Customer_History__r.FEC_Contract_Number__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];

        TransactionDTO dto = mapHistory(tx);

        if (tx.FEC_Customer_History__c != null) {
            String productTypeName = null;
            List<Case> caseRows = [
                SELECT FEC_Product_Type__r.Name
                FROM Case
                WHERE FEC_Account_or_Contract__c = :tx.FEC_Customer_History__c
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            if (!caseRows.isEmpty()) {
                productTypeName = caseRows[0].FEC_Product_Type__r.Name;
            }

            String accNumber = FEC_CommonUltils.resolveAccountNumber(
                productTypeName,
                tx.FEC_Customer_History__r.FEC_Account_Number__c,
                tx.FEC_Customer_History__r.FEC_Contract_Number__c
            );

            List<FEC_GetCardBasicInfo.TransactionInfo> basicTx =
                callBasicInfoSafe(accNumber);
            List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasAuthRows =
                callMfasAuthsTableSafe(accNumber);

            augmentUnbilledDtosWithDualDisplay(
                new List<TransactionDTO>{ dto },
                basicTx,
                fasAuthRows
            );
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
        return dto;
    }

    /**
     * Fills dual-display strings on unbilled DTOs by re-matching the same API payloads
     * used for upsert (composite key: posting date + amount + D/C).
     * Display format per field: left from GetCardBasicInfo, right from M_FAS AUTHS_TABLE;
     * uses " | " only when both sides have a value (otherwise one value, no trailing " | ΓÇö").
     */
    private static void augmentUnbilledDtosWithDualDisplay(
        List<TransactionDTO> dtos,
        List<FEC_GetCardBasicInfo.TransactionInfo> basicList,
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasRows
    ) {
        if (dtos == null || dtos.isEmpty()) {
            return;
        }

        Map<String, FEC_GetCardBasicInfo.TransactionInfo> basicByKey =
            indexBasicByCompositeKey(basicList);
        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasByKey =
            indexFasByCompositeKey(fasRows);

        for (TransactionDTO dto : dtos) {
            String k = buildKey(
                dto.postingDate,
                dto.transactionAmount,
                dto.creditDebitFlag
            );

            FEC_GetCardBasicInfo.TransactionInfo ti =
                String.isNotBlank(k) ? basicByKey.get(k) : null;
            FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar =
                String.isNotBlank(k) ? fasByKey.get(k) : null;

            Date effB = effectiveDateFromBasic(ti);
            Date effF = ar != null ? FEC_CommonUltils.toDateStr(ar.EFF_DATE) : null;
            dto.effectiveDateDualDisplay = dualDateLine(effB, effF);

            Date postB = postingDateFromBasic(ti);
            Date postF = postingDateFromFas(ar);
            dto.postDateDualDisplay = dualDateLine(postB, postF);

            Decimal amtB = ti != null ? ti.Amount : null;
            Decimal amtF = ar != null ? parseDecimalFromApi(ar.AUTH_AMOUNT) : null;
            dto.transactionAmountDualDisplay = dualDecimalLine(amtB, amtF);

            String authB = ti != null
                ? firstNonBlankStr(ti.AuthCode, null)
                : null;
            String authF =
                ar != null
                    ? firstNonBlankStr(ar.AUTHORIZATION_CODE, null)
                    : null;
            dto.authorizationCodeDualDisplay = dualTextLine(authB, authF);

            String planB = ti != null ? ti.Plan : null;
            String planF = ar != null ? ar.CREDIT_PLAN : null;
            dto.transactionPlanDualDisplay = dualTextLine(planB, planF);

            if (dto.effectiveDate != null) {
                dto.effectiveSortEpoch = Datetime.newInstanceGmt(
                        dto.effectiveDate,
                        Time.newInstance(0, 0, 0, 0)
                    )
                    .getTime();
            } else {
                dto.effectiveSortEpoch = null;
            }
        }
    }

    private static Map<String, FEC_GetCardBasicInfo.TransactionInfo> indexBasicByCompositeKey(
        List<FEC_GetCardBasicInfo.TransactionInfo> basicList
    ) {
        Map<String, FEC_GetCardBasicInfo.TransactionInfo> m =
            new Map<String, FEC_GetCardBasicInfo.TransactionInfo>();
        if (basicList == null) {
            return m;
        }
        for (FEC_GetCardBasicInfo.TransactionInfo ti : basicList) {
            String k = compositeKeyFromBasic(ti);
            if (String.isNotBlank(k)) {
                m.put(k, ti);
            }
        }
        return m;
    }

    private static Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> indexFasByCompositeKey(
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasRows
    ) {
        Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> m =
            new Map<String, FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
        if (fasRows == null) {
            return m;
        }
        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : fasRows) {
            String k = compositeKeyFromFas(ar);
            if (String.isNotBlank(k)) {
                m.put(k, ar);
            }
        }
        return m;
    }

    private static String compositeKeyFromBasic(FEC_GetCardBasicInfo.TransactionInfo ti) {
        if (ti == null) {
            return null;
        }
        Date effDate =
            ti.TRNXDateTime != null
                ? ti.TRNXDateTime.date()
                : ti.PostingDate;
        Date postDate = ti.PostingDate != null ? ti.PostingDate : effDate;
        if (postDate == null || ti.Amount == null) {
            return null;
        }
        return buildKey(postDate, ti.Amount, ti.CreditDebitFlag);
    }

    private static String compositeKeyFromFas(FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar) {
        if (ar == null) {
            return null;
        }
        Date eff = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
        Date postDateF = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
        if (postDateF == null) {
            postDateF = eff;
        }
        Decimal amtF = parseDecimalFromApi(ar.AUTH_AMOUNT);
        String cdRaw = String.isNotBlank(ar.CreditDebitFlag)
            ? ar.CreditDebitFlag
            : 'DEBIT';
        if (postDateF == null || amtF == null) {
            return null;
        }
        return buildKey(postDateF, amtF, cdRaw);
    }

    private static Date effectiveDateFromBasic(FEC_GetCardBasicInfo.TransactionInfo ti) {
        if (ti == null) {
            return null;
        }
        if (ti.TRNXDateTime != null) {
            return ti.TRNXDateTime.date();
        }
        return ti.PostingDate;
    }

    private static Date postingDateFromBasic(FEC_GetCardBasicInfo.TransactionInfo ti) {
        if (ti == null) {
            return null;
        }
        Date eff = effectiveDateFromBasic(ti);
        return ti.PostingDate != null ? ti.PostingDate : eff;
    }

    private static Date postingDateFromFas(FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar) {
        if (ar == null) {
            return null;
        }
        Date eff = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
        Date postF = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
        return postF != null ? postF : eff;
    }

    private static String dashIfNull(Date d) {
        return d == null ? '\u2014' : String.valueOf(d);
    }

    private static String dashIfNullDec(Decimal x) {
        return x == null ? '\u2014' : String.valueOf(x);
    }

    private static String dashIfBlank(String s) {
        return String.isBlank(s) ? '\u2014' : s.trim();
    }

    private static final String EM_DASH = '\u2014';

    /**
     * Renders "left | right" only when both sides have real values;
     * if exactly one side is present, returns that side only (no trailing " | ΓÇö").
     */
    private static String dualPairDisplay(String leftShown, String rightShown) {
        Boolean lMiss =
            String.isBlank(leftShown) || EM_DASH.equals(leftShown);
        Boolean rMiss =
            String.isBlank(rightShown) || EM_DASH.equals(rightShown);
        if (lMiss && rMiss) {
            return EM_DASH;
        }
        if (rMiss) {
            return leftShown;
        }
        if (lMiss) {
            return rightShown;
        }
        return leftShown + ' | ' + rightShown;
    }

    /** Left = GetCardBasicInfo, right = M_FAS AUTHS_TABLE (column header names the field). */
    private static String dualDateLine(Date basicVal, Date fasVal) {
        return dualPairDisplay(dashIfNull(basicVal), dashIfNull(fasVal));
    }

    private static String dualDecimalLine(Decimal basicVal, Decimal fasVal) {
        return dualPairDisplay(dashIfNullDec(basicVal), dashIfNullDec(fasVal));
    }

    private static String dualTextLine(String basicVal, String fasVal) {
        return dualPairDisplay(dashIfBlank(basicVal), dashIfBlank(fasVal));
    }

    /* =====================================================
       PENDING ΓÇö same M_FAS rows as unbilled; Effective Date prefers AUTH_GRP.EFF_DATE
       (VMX_AUTH_DETAILΓÇªMODULE007ΓÇªRETRV_AUTH_DTL_OUT.AUTH_GRP) when present in envelope.
       Dual effective column: detail EFF_DATE | AUTHS_TABLE EFF_DATE.
       Other Pending fields: primary from AUTH_GRP (MODULE007ΓÇªRETRV_AUTH_DTL_OUT);
       approval from VMX_MSGOUT.AUTH_CD; dual column shows AUTHS_TABLE where applicable.
       ===================================================== */
    private static List<TransactionDTO> buildPendingDtosFromAuthRows(
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> rows
    ) {
        List<TransactionDTO> result = new List<TransactionDTO>();
        if (rows == null || rows.isEmpty()) {
            return result;
        }

        Map<String, String> helpTemplate =
            FEC_CommonUltils.buildHelpTextMap(FEC_Transaction__c.SObjectType);

        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : rows) {
            Date effDetail = FEC_CommonUltils.toDateStr(ar.EFF_DATE_AUTH_DETAIL);
            Date effTable = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
            if (effTable == null) {
                effTable = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
            }
            Date effPrimary = effDetail != null ? effDetail : effTable;
            if (effPrimary == null) {
                continue;
            }

            Decimal amtDetail = parseDecimalFromApi(ar.DTL_AUTH_AMT);
            Decimal amtTable = parseDecimalFromApi(ar.AUTH_AMOUNT);
            Decimal amt = amtDetail != null ? amtDetail : amtTable;

            String descDetail = ar.DTL_MERC_NAME_LOC;
            String descTable = ar.Description;
            String descMfas = firstNonBlankStr(descDetail, descTable);

            String planDetail = ar.DTL_CR_PLAN;
            String planTable = ar.CREDIT_PLAN;
            String plan = firstNonBlankStr(planDetail, planTable);

            String mccDetail = ar.DTL_MERCH_CAT;
            String mccTable = ar.MERCH_CAT;
            String mcc = firstNonBlankStr(mccDetail, mccTable);

            String currDetail = ar.DTL_TXN_CURR_CODE;
            String currTable = ar.TXN_CURR_CODE;
            String curr = firstNonBlankStr(currDetail, currTable);

            String finalDetail = ar.DTL_FINAL_ACTN;
            String finalTable = ar.FINAL_ACTN;
            String finalActn = firstNonBlankStr(finalDetail, finalTable);

            String declineDetail = ar.DTL_ACTN_RSN_DESC;
            String declineTable = ar.ACTN_RSN_DESC;
            String decline = firstNonBlankStr(declineDetail, declineTable);

            String apprMsg = ar.MSGOUT_AUTH_CD;
            String apprRow = ar.AUTH_CD;

            TransactionDTO dto = new TransactionDTO();
            dto.Id = null;
            dto.helpTexts = helpTemplate;

            dto.effectiveDate = effPrimary;
            dto.transactionAmount = amt;

            dto.effectiveDateDualDisplay = dualDateLine(effDetail, effTable);
            dto.transactionAmountDualDisplay = dualDecimalLine(amtDetail, amtTable);
            dto.merchantDescriptionDualDisplay = dualTextLine(descDetail, descTable);
            dto.merchantDescription = descMfas;
            dto.transactionPlanDualDisplay = dualTextLine(planDetail, planTable);
            dto.transactionPlan = plan;
            dto.merchantCategoryDualDisplay = dualTextLine(mccDetail, mccTable);
            dto.merchantCategoryCode = mcc;
            dto.currencyCodeDualDisplay = dualTextLine(currDetail, currTable);
            dto.currencyCode = curr != null ? curr.trim() : null;
            dto.approvalCodeDualDisplay = dualTextLine(apprMsg, apprRow);
            dto.approvalCode = firstNonBlankStr(apprMsg, apprRow);
            dto.authorizationResponseDualDisplay = dualTextLine(finalDetail, finalTable);
            dto.authorizationResponse = finalActn;
            dto.declineDescriptionDualDisplay = dualTextLine(declineDetail, declineTable);
            dto.declineDescription = decline;

            dto.effectiveSortEpoch =
                Datetime.newInstanceGmt(effPrimary, Time.newInstance(0, 0, 0, 0))
                    .getTime();

            result.add(dto);
        }

        return result;
    }

    /* =====================================================
       UPSERT HISTORY ΓÇö GetCardBasicInfo (priority) + M_FAS rows
       ===================================================== */
    private static void upsertHistoryFromBasicInfoAndFas(
        Id historyId,
        List<FEC_GetCardBasicInfo.TransactionInfo> basicList,
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasRows,
        Map<String, String> finTrnxCurrencyByKey,
        Map<String, String> currencyDisplayMap
    ) {
        Map<String, FEC_Transaction__c> existed = loadExistingTxByCompositeKey(historyId);

        Map<String, FEC_Transaction__c> working = new Map<String, FEC_Transaction__c>();

        Map<String, String> creditPlanByCompositeFromFas =
            buildCreditPlanByCompositeFromFas(fasRows);

        Map<String, String> authCodeByCompositeFromFas =
            buildAuthCodeByCompositeFromFas(fasRows);

        List<FEC_GetCardBasicInfo.TransactionInfo> basicSorted =
            new List<FEC_GetCardBasicInfo.TransactionInfo>(basicList);
        basicSorted.sort(new TransactionInfoEffDescCmp());

        Integer basicFallback = 0;
        for (FEC_GetCardBasicInfo.TransactionInfo ti : basicSorted) {
            Date effDate =
                ti.TRNXDateTime != null
                    ? ti.TRNXDateTime.date()
                    : ti.PostingDate;

            Date postDate = ti.PostingDate != null ? ti.PostingDate : effDate;

            String key;
            if (postDate != null && ti.Amount != null) {
                key = buildKey(postDate, ti.Amount, ti.CreditDebitFlag);
            } else {
                key = 'BASIC_FALLBACK_' + String.valueOf(basicFallback++);
            }
            if (String.isBlank(key)) {
                continue;
            }

            FEC_Transaction__c rec =
                working.containsKey(key)
                    ? working.get(key)
                    : existed.containsKey(key)
                        ? existed.get(key)
                        : new FEC_Transaction__c(
                            FEC_Customer_History__c = historyId
                        );

            rec.FEC_Effective_Date__c = effDate;
            rec.FEC_Post_Date__c = postDate;
            rec.FEC_Transaction_Amount__c = ti.Amount;
            rec.FEC_Credit_Debit_Flag__c = ti.CreditDebitFlag;
            rec.FEC_Merchant_Description__c =
                !String.isBlank(ti.Description)
                    ? ti.Description
                    : ti.MerchantName;
            rec.FEC_Transaction_Plan__c = firstNonBlankStr(
                creditPlanByCompositeFromFas.get(key),
                ti.Plan
            );
            rec.FEC_Transaction_Code__c = ti.TransactionCode;
            rec.FEC_Authorization_Code__c = firstNonBlankStr(
                ti.AuthCode,
                firstNonBlankStr(authCodeByCompositeFromFas.get(key), ti.RRN)
            );
            rec.FEC_Merchant_Category_Code__c = ti.MCC;

            String rawCurr;
            if (finTrnxCurrencyByKey != null && finTrnxCurrencyByKey.containsKey(key)) {
                rawCurr = finTrnxCurrencyByKey.get(key);
            } else {
                rawCurr = null;
            }
            if (String.isBlank(rawCurr) && String.isNotBlank(ti.TRNXCurrencyCode)) {
                rawCurr = ti.TRNXCurrencyCode.trim();
            }
            if (String.isBlank(rawCurr)) {
                rec.FEC_Currency_Code__c = null;
            } else if (currencyDisplayMap != null && currencyDisplayMap.containsKey(rawCurr)) {
                rec.FEC_Currency_Code__c = currencyDisplayMap.get(rawCurr);
            } else {
                rec.FEC_Currency_Code__c = rawCurr;
            }

            rec.FEC_OTP_Sent__c =
                ti.OTPSent != null && ti.OTPSent == 1 ? 'Yes' : 'No';

            working.put(key, rec);
        }

        if (!fasRows.isEmpty()) {
            List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasSorted =
                new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>(fasRows);
            fasSorted.sort(new AuthTableRowEffDescCmp());

            Integer fasMapSeq = 0;
            List<FEC_Transaction__c> outstPool = [
                SELECT Id,
                    FEC_Effective_Date__c,
                    FEC_Post_Date__c,
                    FEC_Transaction_Amount__c
                FROM FEC_Transaction__c
                WHERE FEC_Customer_History__c = :historyId
                    AND FEC_Transaction_Code__c = 'OUTST_AUTH'
                ORDER BY CreatedDate
            ];

            for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : fasSorted) {
                Date eff = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
                if (eff == null) {
                    continue;
                }

                Date postDateF = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
                if (postDateF == null) {
                    postDateF = eff;
                }

                Decimal amtF = parseDecimalFromApi(ar.AUTH_AMOUNT);
                String cdRaw = String.isNotBlank(ar.CreditDebitFlag)
                    ? ar.CreditDebitFlag
                    : 'DEBIT';

                String fasComposite = null;
                if (postDateF != null && amtF != null) {
                    fasComposite = buildKey(postDateF, amtF, cdRaw);
                    if (String.isNotBlank(fasComposite)
                        && working.containsKey(fasComposite)) {
                        continue;
                    }
                }

                String mapKey;
                if (String.isNotBlank(fasComposite)) {
                    mapKey = fasComposite;
                } else {
                    mapKey =
                        'FAS_REC_' +
                        String.valueOf(fasMapSeq++) +
                        '_' +
                        eff.format();
                }

                FEC_Transaction__c rec = null;
                for (Integer i = 0; i < outstPool.size(); i++) {
                    FEC_Transaction__c slot = outstPool[i];
                    if (slot == null) {
                        continue;
                    }
                    if (slot.FEC_Effective_Date__c == eff) {
                        rec = new FEC_Transaction__c(
                            Id = slot.Id,
                            FEC_Customer_History__c = historyId
                        );
                        outstPool.set(i, null);
                        break;
                    }
                }
                if (rec == null) {
                    rec = new FEC_Transaction__c(
                        FEC_Customer_History__c = historyId
                    );
                }
                rec.FEC_Effective_Date__c = eff;
                rec.FEC_Post_Date__c = postDateF;
                rec.FEC_Transaction_Amount__c = amtF;
                rec.FEC_Credit_Debit_Flag__c = normDebitCredit(cdRaw);
                rec.FEC_Merchant_Description__c = ar.Description;
                rec.FEC_Transaction_Plan__c = ar.CREDIT_PLAN;
                rec.FEC_Authorization_Code__c = ar.AUTHORIZATION_CODE;
                rec.FEC_Transaction_Code__c = 'OUTST_AUTH';

                working.put(mapKey, rec);
            }
        }

        if (!working.isEmpty()) {
            upsert working.values();
        }
    }

    private static Map<String, FEC_Transaction__c> loadExistingTxByCompositeKey(
        Id historyId
    ) {
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
            if (String.isNotBlank(key)) {
                existed.put(key, tx);
            }
        }
        return existed;
    }

    /**
     * Sheet: Transaction Plan from M_FAS AUTHS_TABLE.CREDIT_PLAN ΓÇö index by
     * same composite key as Basic (posting + amount + D/C) for merge.
     */
    private static Map<String, String> buildCreditPlanByCompositeFromFas(
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasRows
    ) {
        Map<String, String> outMap = new Map<String, String>();
        if (fasRows == null || fasRows.isEmpty()) {
            return outMap;
        }
        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : fasRows) {
            if (String.isBlank(ar.CREDIT_PLAN)) {
                continue;
            }
            Date eff = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
            Date postDateF = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
            if (postDateF == null) {
                postDateF = eff;
            }
            Decimal amtF = parseDecimalFromApi(ar.AUTH_AMOUNT);
            String cdRaw = String.isNotBlank(ar.CreditDebitFlag)
                ? ar.CreditDebitFlag
                : 'DEBIT';
            if (postDateF == null || amtF == null) {
                continue;
            }
            String k = buildKey(postDateF, amtF, cdRaw);
            if (String.isNotBlank(k)) {
                outMap.put(k, ar.CREDIT_PLAN.trim());
            }
        }
        return outMap;
    }

    private static Map<String, String> buildAuthCodeByCompositeFromFas(
        List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> fasRows
    ) {
        Map<String, String> outMap = new Map<String, String>();
        if (fasRows == null || fasRows.isEmpty()) {
            return outMap;
        }
        for (FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar : fasRows) {
            if (String.isBlank(ar.AUTHORIZATION_CODE)) {
                continue;
            }
            Date eff = FEC_CommonUltils.toDateStr(ar.EFF_DATE);
            Date postDateF = FEC_CommonUltils.toDateStr(ar.POSTING_DATE);
            if (postDateF == null) {
                postDateF = eff;
            }
            Decimal amtF = parseDecimalFromApi(ar.AUTH_AMOUNT);
            String cdRaw = String.isNotBlank(ar.CreditDebitFlag)
                ? ar.CreditDebitFlag
                : 'DEBIT';
            if (postDateF == null || amtF == null) {
                continue;
            }
            String k = buildKey(postDateF, amtF, cdRaw);
            if (String.isNotBlank(k)) {
                outMap.put(k, ar.AUTHORIZATION_CODE.trim());
            }
        }
        return outMap;
    }

    private class TransactionInfoEffDescCmp
        implements Comparator<FEC_GetCardBasicInfo.TransactionInfo>
    {
        public Integer compare(
            FEC_GetCardBasicInfo.TransactionInfo a,
            FEC_GetCardBasicInfo.TransactionInfo b
        ) {
            Datetime da = a.TRNXDateTime;
            Datetime db = b.TRNXDateTime;
            if (da == null && db == null) {
                return 0;
            }
            if (da == null) {
                return 1;
            }
            if (db == null) {
                return -1;
            }
            if (da > db) {
                return -1;
            }
            if (da < db) {
                return 1;
            }
            return 0;
        }
    }

    private class AuthTableRowEffDescCmp
        implements Comparator<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>
    {
        public Integer compare(
            FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow a,
            FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow b
        ) {
            Date da = FEC_CommonUltils.toDateStr(a.EFF_DATE);
            Date db = FEC_CommonUltils.toDateStr(b.EFF_DATE);
            if (da == null && db == null) {
                return 0;
            }
            if (da == null) {
                return 1;
            }
            if (db == null) {
                return -1;
            }
            if (da > db) {
                return -1;
            }
            if (da < db) {
                return 1;
            }
            return 0;
        }
    }

    /* =====================================================
       SAFE CALLS
       ===================================================== */
    private static List<FEC_GetCardBasicInfo.TransactionInfo> callBasicInfoSafe(
        String acc
    ) {
        try {
            FEC_GetCardBasicInfo.ResponseWrapper res =
                FEC_GetCardBasicInfo.callGetCardBasicInfo(
                    FEC_CommonUltils.generateTransactionId(),
                    FEC_ConstantCommon.REQUESTOR_CRM,
                    Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT),
                    acc
                );
            if (res != null
                && res.CardBasicInfo != null
                && res.CardBasicInfo.Transactions != null) {
                return res.CardBasicInfo.Transactions;
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.WARN,
                'FEC_TransactionsController.callBasicInfoSafe: ' + e.getMessage()
            );
        }
        return new List<FEC_GetCardBasicInfo.TransactionInfo>();
    }

    /**
     * Pending: VMX_AUTH_DETAIL_INQ. Non-Production account from metadata; Production from Case.
     */
    private static List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>
    callVmxAuthDetailInqSafe(String resolvedAccountNumber) {
        String acctForApi = resolveMfasAccountNumber(
            resolvedAccountNumber,
            M_FAS_API_CONFIG
        );
        if (String.isBlank(acctForApi)) {
            return new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
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
            if (res != null
                && res.VMXMsgOut != null
                && res.VMXMsgOut.Auths != null) {
                return res.VMXMsgOut.Auths;
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.WARN,
                'FEC_TransactionsController.callVmxAuthDetailInqSafe: ' +
                    e.getMessage()
            );
        }
        return new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
    }

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

    private static List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>
    callMfasAuthsTableSafe(String resolvedAccountNumber) {
        String acctForMfas = String.isNotBlank(resolvedAccountNumber)
            ? resolvedAccountNumber.trim()
            : M_FAS_UNBILLED_ACCOUNT_NUMBER;
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
                    acctForMfas
                );
            if (res != null
                && res.VMXMsgOut != null
                && res.VMXMsgOut.Auths != null) {
                return res.VMXMsgOut.Auths;
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.WARN,
                'FEC_TransactionsController.callMfasAuthsTableSafe: ' +
                    e.getMessage()
            );
        }
        return new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
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
            System.debug(
                LoggingLevel.WARN,
                'FEC_TransactionsController.callFinancialSafe: ' + e.getMessage()
            );
            return new List<FEC_GetCardFinancialTransactions.FinancialTransaction>();
        }
    }

    private static Map<String, String> buildFinTrnxCurrencyByKey(
        List<FEC_GetCardFinancialTransactions.FinancialTransaction> fList
    ) {
        Map<String, String> m = new Map<String, String>();
        if (fList == null || fList.isEmpty()) {
            return m;
        }
        for (FEC_GetCardFinancialTransactions.FinancialTransaction f : fList) {
            Date postDate = FEC_CommonUltils.toDateStr(f.PostingDate);
            if (postDate == null || f.TRNXAmount == null) {
                continue;
            }
            String key = buildKey(postDate, f.TRNXAmount, f.CreditDebitFlag);
            if (key == null || String.isBlank(f.TRNXCurrencyCode)) {
                continue;
            }
            m.put(key, f.TRNXCurrencyCode.trim());
        }
        return m;
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

    private static String firstNonBlankStr(String a, String b) {
        if (!String.isBlank(a)) {
            return a.trim();
        }
        if (!String.isBlank(b)) {
            return b.trim();
        }
        return null;
    }
}
