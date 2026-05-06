/****************************************************************************************
 * File Name    : FEC_IPPConversionController.cls
 * Description  : Controller for IPP Conversion (RC34.01 Retail, RC34.02 Balance). Eligible transactions, Check IPP Details, Convert IPP (AddIPP).
 ****************************************************************************************/

public without sharing class FEC_IPPConversionController {

    public static final Integer MAX_RETRY_COUNT = 3;

    public class EligibleTransactionDTO {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String transactionCode;
        @AuraEnabled public String effectiveDateStr;
        @AuraEnabled public String transactionPlan;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String postingDateStr;
        @AuraEnabled public String authorizationCode;
        @AuraEnabled public String merchant;
    }

    public class IPPDetailsDTO {
        @AuraEnabled public List<Integer> tenorOptions;
        @AuraEnabled public Decimal interestRate;
        @AuraEnabled public Decimal fee;
        @AuraEnabled public Decimal emi;
        @AuraEnabled public String errorMessage;
    }

    public class ConvertResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Decimal actionCount;
    }

    public class ActionStatusDTO {
        @AuraEnabled public Decimal actionCount;
        @AuraEnabled public Boolean canConvert;
    }

    /**
     * Get eligible retail transactions (unbilled, valid for IPP conversion). Uses FEC_TransactionsController.loadTransactions.
     * Fallback: when API returns no unbilled, load from FEC_Transaction__c by Case's Customer History (e.g. for test data).
     */
    @AuraEnabled(cacheable=false)
    public static List<EligibleTransactionDTO> getEligibleTransactions(Id caseId) {
        if (caseId == null) {
            return new List<EligibleTransactionDTO>();
        }
        FEC_TransactionsController.TransactionsResponse res = FEC_TransactionsController.loadTransactions(caseId);
        List<EligibleTransactionDTO> result = new List<EligibleTransactionDTO>();
        if (res != null && res.unbilledTransactions != null && !res.unbilledTransactions.isEmpty()) {
            for (FEC_TransactionsController.TransactionDTO tx : res.unbilledTransactions) {
                if (tx.Id == null) continue;
                EligibleTransactionDTO dto = new EligibleTransactionDTO();
                dto.transactionId = tx.Id;
                dto.transactionCode = tx.transactionCode != null ? tx.transactionCode : FEC_ConstantCommon.STR_EMPTY;
                dto.effectiveDateStr = tx.effectiveDate != null ? String.valueOf(tx.effectiveDate) : FEC_ConstantCommon.STR_EMPTY;
                dto.transactionPlan = tx.transactionPlan != null ? tx.transactionPlan : FEC_ConstantCommon.STR_EMPTY;
                dto.amount = tx.transactionAmount;
                dto.postingDateStr = tx.postingDate != null ? String.valueOf(tx.postingDate) : FEC_ConstantCommon.STR_EMPTY;
                dto.authorizationCode = tx.authorizationCode != null ? tx.authorizationCode : FEC_ConstantCommon.STR_EMPTY;
                dto.merchant = tx.merchantDescription != null ? tx.merchantDescription : FEC_ConstantCommon.STR_EMPTY;
                result.add(dto);
            }
            return result;
        }
        return loadEligibleTransactionsFromDb(caseId);
    }

    private static List<EligibleTransactionDTO> loadEligibleTransactionsFromDb(Id caseId) {
        List<EligibleTransactionDTO> result = new List<EligibleTransactionDTO>();
        if (caseId == null) return result;
        if (!Schema.sObjectType.Case.isAccessible() || !Schema.sObjectType.FEC_Transaction__c.isAccessible()) {
            return result;
        }
        List<Case> cases = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
            return result;
        }
        Id chId = cases[0].FEC_Account_or_Contract__c;
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Amount__c, FEC_Merchant_Description__c,
                   FEC_Transaction_Plan__c, FEC_Transaction_Code__c, FEC_Authorization_Code__c
            FROM FEC_Transaction__c
            WHERE FEC_Customer_History__c = :chId
            ORDER BY FEC_Effective_Date__c DESC
        ];
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, txs);
        for (SObject so : decision.getRecords()) {
            FEC_Transaction__c tx = (FEC_Transaction__c) so;
            EligibleTransactionDTO dto = new EligibleTransactionDTO();
            dto.transactionId = tx.Id;
            dto.transactionCode = tx.FEC_Transaction_Code__c != null ? tx.FEC_Transaction_Code__c : FEC_ConstantCommon.STR_EMPTY;
            dto.effectiveDateStr = tx.FEC_Effective_Date__c != null ? String.valueOf(tx.FEC_Effective_Date__c) : FEC_ConstantCommon.STR_EMPTY;
            dto.transactionPlan = tx.FEC_Transaction_Plan__c != null ? tx.FEC_Transaction_Plan__c : FEC_ConstantCommon.STR_EMPTY;
            dto.amount = tx.FEC_Transaction_Amount__c;
            dto.postingDateStr = tx.FEC_Post_Date__c != null ? String.valueOf(tx.FEC_Post_Date__c) : FEC_ConstantCommon.STR_EMPTY;
            dto.authorizationCode = tx.FEC_Authorization_Code__c != null ? tx.FEC_Authorization_Code__c : FEC_ConstantCommon.STR_EMPTY;
            dto.merchant = tx.FEC_Merchant_Description__c != null ? tx.FEC_Merchant_Description__c : FEC_ConstantCommon.STR_EMPTY;
            result.add(dto);
        }
        return result;
    }

    /**
     * Check IPP details for a transaction via FEC_GetIPPDetailsCallout (tenor options, interest, fee, EMI).
     */
    @AuraEnabled(cacheable=false)
    public static IPPDetailsDTO checkIPPDetails(Id caseId, Id transactionId) {
        IPPDetailsDTO dto = new IPPDetailsDTO();
        dto.tenorOptions = new List<Integer>();
        dto.interestRate = null;
        dto.fee = null;
        dto.emi = null;
        dto.errorMessage = null;
        if (transactionId == null) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Transaction Id' });
            return dto;
        }
        if (!Schema.sObjectType.FEC_Transaction__c.isAccessible()) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return dto;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Plan__c,
                   FEC_Transaction_Code__c, FEC_Authorization_Code__c, FEC_Customer_History__c,
                   FEC_Customer_History__r.FEC_Account_Number__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
        SObjectAccessDecision txDecision = Security.stripInaccessible(AccessType.READABLE, txs);
        txs = (List<FEC_Transaction__c>) txDecision.getRecords();
        if (txs.isEmpty()) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return dto;
        }
        FEC_Transaction__c tx = txs[0];
        if (tx.FEC_Transaction_Amount__c == null || tx.FEC_Transaction_Amount__c <= 0) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{ 'Amount', '0' });
            return dto;
        }
        String chAcc = (tx.FEC_Customer_History__c != null && tx.FEC_Customer_History__r != null) ? tx.FEC_Customer_History__r.FEC_Account_Number__c : null;
        String accountNumber = getAccountNumberForGetIPPDetails(caseId, chAcc);
        if (String.isBlank(accountNumber)) {
            dto.errorMessage = System.Label.FEC_MSG_AccountNumber_Invalid;
            return dto;
        }
        Date effDate = tx.FEC_Effective_Date__c != null ? tx.FEC_Effective_Date__c : Date.today();
        Date postDate = tx.FEC_Post_Date__c != null ? tx.FEC_Post_Date__c : effDate;
        FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
        req.accountNumber = accountNumber;
        req.effectiveDate = FEC_CommonUltils.formatDateYYYYMMDD(effDate);
        req.amount = tx.FEC_Transaction_Amount__c;
        req.postingDate = FEC_CommonUltils.formatDateYYYYMMDD(postDate);
        if (String.isNotBlank(tx.FEC_Transaction_Plan__c)) {
            req.planNumber = tx.FEC_Transaction_Plan__c;
            req.transactionPlan = tx.FEC_Transaction_Plan__c;
        }
        if (String.isNotBlank(tx.FEC_Transaction_Code__c)) {
            req.referenceNumber = tx.FEC_Transaction_Code__c;
        }
        try {
            FEC_GetIPPDetailsCallout.IPPDetailsResponse detailResp = FEC_GetIPPDetailsCallout.getIPPDetails(req);
            if (detailResp == null) {
                dto.errorMessage = System.Label.FEC_MSG_Response_Null;
                return dto;
            }
            if (detailResp.status != null && detailResp.status.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_ERROR)) {
                dto.errorMessage = String.isNotBlank(detailResp.sysMessage) ? detailResp.sysMessage : System.Label.FEC_MSG_Response_Null;
                return dto;
            }
            if (!isGetIPPDetailsResponseSuccess(detailResp)) {
                dto.errorMessage = String.isNotBlank(detailResp.sysMessage) ? detailResp.sysMessage : System.Label.FEC_MSG_Response_Null;
                return dto;
            }
            dto.tenorOptions = parseTenorOptionsFromIppTerm(detailResp.ippTerm);
            dto.interestRate = detailResp.interestRate;
            dto.fee = detailResp.conversionFee;
            dto.emi = detailResp.emi != null ? detailResp.emi : detailResp.installmentAmount;
        } catch (Exception e) {
            dto.errorMessage = e.getMessage();
        }
        return dto;
    }

    @AuraEnabled(cacheable=false)
    public static ActionStatusDTO getConvertActionStatus(Id caseId) {
        ActionStatusDTO dto = new ActionStatusDTO();
        dto.actionCount = null;
        dto.canConvert = true;
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return dto;
        }
        List<Case> cases = [
            SELECT Id, FEC_Process_Action_Count__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return dto;
        }
        dto.actionCount = cases[0].FEC_Process_Action_Count__c;
        dto.canConvert = dto.actionCount == null
            || (dto.actionCount != -1 && dto.actionCount < MAX_RETRY_COUNT);
        return dto;
    }

    /**
     * Convert IPP: build AddIPP request from Case + selected transaction + tenor, call FEC_AddIPP.addIPP, return result.
     */
    @AuraEnabled
    public static ConvertResultDTO convertIPP(Id caseId, Id transactionId, Integer tenor) {
        ConvertResultDTO result = new ConvertResultDTO();
        result.success = false;
        result.message = null;
        result.errorMessage = null;
        if (caseId == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return result;
        }
        if (transactionId == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Transaction Id' });
            return result;
        }
        if (tenor == null || tenor <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Tenor' });
            return result;
        }
        Case c = loadCaseForIPPConversion(caseId);
        String accountNumber = resolveAccountNumberForAddIPP(c);
        if (String.isBlank(accountNumber)) {
            result.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return result;
        }
        if (!Schema.sObjectType.FEC_Transaction__c.isAccessible()) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return result;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Plan__c,
                   FEC_Transaction_Code__c, FEC_Authorization_Code__c, FEC_Customer_History__c,
                   FEC_Customer_History__r.FEC_Card_Number__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
        SObjectAccessDecision txDec = Security.stripInaccessible(AccessType.READABLE, txs);
        txs = (List<FEC_Transaction__c>) txDec.getRecords();
        if (txs.isEmpty()) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return result;
        }
        FEC_Transaction__c tx = txs[0];
        if (tx.FEC_Transaction_Amount__c == null || tx.FEC_Transaction_Amount__c <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{ 'Amount', '0' });
            return result;
        }
        if (String.isBlank(tx.FEC_Transaction_Plan__c)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Plan Number' });
            return result;
        }
        String cardNo = resolveCardNumberForAddIpp(tx, c);
        if (String.isBlank(cardNo)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Number' });
            return result;
        }
        Date effectiveDate = tx.FEC_Effective_Date__c != null ? tx.FEC_Effective_Date__c : Date.today();
        Date postingDate = tx.FEC_Post_Date__c != null ? tx.FEC_Post_Date__c : effectiveDate;
        String refNo = String.isNotBlank(tx.FEC_Transaction_Code__c) ? tx.FEC_Transaction_Code__c : tx.FEC_Authorization_Code__c;
        if (String.isBlank(refNo)) {
            refNo = String.valueOf(transactionId);
        }
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();
        req.accountNumber = accountNumber;
        req.effectiveDate = effectiveDate;
        req.amount = tx.FEC_Transaction_Amount__c;
        req.planNumber = tx.FEC_Transaction_Plan__c;
        req.ippTerm = tenor;
        req.referenceNumber = refNo;
        req.transactionPlan = tx.FEC_Transaction_Plan__c;
        req.postingDate = postingDate;
        req.cardNumber = cardNo;
        req.cardSeq = 0;
        req.ippKey = refNo;
        try {
            FEC_AddIPP.AddIPPResult addResult = FEC_AddIPP.addIPP(req);
            applyAddIppResultToConvertResult(addResult, result);
            updateCaseActionCountForConvertResult(c, result.success == true);
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            updateCaseActionCountForConvertResult(c, false);
        }
        result.actionCount = c != null ? c.FEC_Process_Action_Count__c : null;
        return result;
    }

    /**
     * Convert IPP from manual retail entry (RC34.01 - transaction not in list). Section Properties 12 fields.
     * Dates in yyyy-MM-dd. conversionInterestRate as percentage (e.g. 12).
     */
    @AuraEnabled
    public static ConvertResultDTO convertIPPManualRetail(Id caseId, String verificationInfo, String callback, String cardType2,
            String statementDateStr, String dueDateStr, String transactionDateStr, Decimal transactionAmount,
            String approvalCode, String transactionPlan, Decimal installmentAmount, Integer installmentTerm, Decimal conversionInterestRate) {
        ConvertResultDTO result = new ConvertResultDTO();
        result.success = false;
        result.message = null;
        result.errorMessage = null;
        if (caseId == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return result;
        }
        if (transactionAmount == null || transactionAmount <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{ 'Số tiền GD', '0' });
            return result;
        }
        if (installmentTerm == null || installmentTerm <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Kỳ hạn góp' });
            return result;
        }
        Case c = loadCaseForIPPConversion(caseId);
        String accountNumber = resolveAccountNumberForAddIPP(c);
        if (String.isBlank(accountNumber)) {
            result.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return result;
        }
        if (String.isBlank(transactionPlan)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Plan Number' });
            return result;
        }
        String cardNo = resolveCardNumberForAddIpp(null, c);
        if (String.isBlank(cardNo)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Number' });
            return result;
        }
        Date effDate = Date.today();
        if (String.isNotBlank(transactionDateStr)) {
            try {
                effDate = Date.valueOf(transactionDateStr);
            } catch (Exception e) {
                effDate = Date.today();
            }
        }
        Date postDate = effDate;
        if (String.isNotBlank(statementDateStr)) {
            try {
                postDate = Date.valueOf(statementDateStr);
            } catch (Exception e) {
                postDate = effDate;
            }
        }
        String refNo = String.isNotBlank(approvalCode) ? approvalCode : null;
        if (String.isBlank(refNo)) {
            refNo = String.isNotBlank(verificationInfo) ? verificationInfo : String.valueOf(caseId);
        }
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();
        req.accountNumber = accountNumber;
        req.effectiveDate = effDate;
        req.amount = transactionAmount;
        req.planNumber = transactionPlan;
        req.ippTerm = installmentTerm;
        req.referenceNumber = refNo;
        req.transactionPlan = transactionPlan;
        req.postingDate = postDate;
        req.cardNumber = cardNo;
        req.cardSeq = 0;
        req.ippKey = refNo;
        try {
            FEC_AddIPP.AddIPPResult addResult = FEC_AddIPP.addIPP(req);
            applyAddIppResultToConvertResult(addResult, result);
            updateCaseActionCountForConvertResult(c, result.success == true);
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            updateCaseActionCountForConvertResult(c, false);
        }
        result.actionCount = c != null ? c.FEC_Process_Action_Count__c : null;
        return result;
    }

    /**
     * Convert IPP from manual entry (RC34.02 balance conversion). Section Properties 9 fields.
     * Dates in yyyy-MM-dd. statementDateStr, dueDateStr, planIPP, installmentAmount optional.
     */
    @AuraEnabled
    public static ConvertResultDTO convertIPPManual(Id caseId, Decimal amount, Integer tenor, String planNumber, String effectiveDateStr,
            String statementDateStr, String dueDateStr, String planIPP, Decimal installmentAmount) {
        ConvertResultDTO result = new ConvertResultDTO();
        result.success = false;
        result.message = null;
        result.errorMessage = null;
        if (caseId == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return result;
        }
        if (amount == null || amount <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{ 'Dư nợ gốc hiện tại', '0' });
            return result;
        }
        if (tenor == null || tenor <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Kỳ hạn góp' });
            return result;
        }
        Case c = loadCaseForIPPConversion(caseId);
        String accountNumber = resolveAccountNumberForAddIPP(c);
        if (String.isBlank(accountNumber)) {
            result.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return result;
        }
        String planForApi = String.isNotBlank(planNumber) ? planNumber : planIPP;
        if (String.isBlank(planForApi)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Plan Number' });
            return result;
        }
        String cardNo = resolveCardNumberForAddIpp(null, c);
        if (String.isBlank(cardNo)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Number' });
            return result;
        }
        Date effDate = Date.today();
        if (String.isNotBlank(effectiveDateStr)) {
            try {
                effDate = Date.valueOf(effectiveDateStr);
            } catch (Exception e) {
                effDate = Date.today();
            }
        } else if (String.isNotBlank(statementDateStr)) {
            try {
                effDate = Date.valueOf(statementDateStr);
            } catch (Exception e) { }
        }
        Date postDate = effDate;
        if (String.isNotBlank(statementDateStr)) {
            try {
                postDate = Date.valueOf(statementDateStr);
            } catch (Exception e) { }
        }
        String refNo = String.isNotBlank(planIPP) ? planIPP : String.valueOf(caseId);
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();
        req.accountNumber = accountNumber;
        req.effectiveDate = effDate;
        req.amount = amount;
        req.planNumber = planForApi;
        req.ippTerm = tenor;
        req.referenceNumber = refNo;
        req.transactionPlan = planForApi;
        req.postingDate = postDate;
        req.cardNumber = cardNo;
        req.cardSeq = 0;
        req.ippKey = planForApi;
        try {
            FEC_AddIPP.AddIPPResult addResult = FEC_AddIPP.addIPP(req);
            applyAddIppResultToConvertResult(addResult, result);
            updateCaseActionCountForConvertResult(c, result.success == true);
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            updateCaseActionCountForConvertResult(c, false);
        }
        result.actionCount = c != null ? c.FEC_Process_Action_Count__c : null;
        return result;
    }

    private static String resolveCardNumberForAddIpp(FEC_Transaction__c tx, Case c) {
        if (tx != null && tx.FEC_Customer_History__c != null && tx.FEC_Customer_History__r != null
                && String.isNotBlank(tx.FEC_Customer_History__r.FEC_Card_Number__c)) {
            return tx.FEC_Customer_History__r.FEC_Card_Number__c;
        }
        if (c != null && c.FEC_Account_or_Contract__r != null) {
            return c.FEC_Account_or_Contract__r.FEC_Card_Number__c;
        }
        return null;
    }

    private static Case loadCaseForIPPConversion(Id caseId) {
        if (caseId == null || !Schema.sObjectType.Case.isAccessible()) {
            return null;
        }
        List<Case> cases = [
            SELECT Id, FEC_Account_Number__c, FEC_Account_Contract_Number_Text__c, FEC_Account_or_Contract__c,
                   FEC_Process_Action_Count__c, FEC_Is_Test_API__c,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Card_Number__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        List<SObject> recs = decision.getRecords();
        return recs.isEmpty() ? null : (Case) recs[0];
    }

    private static String resolveAccountNumberForAddIPP(Case c) {
        if (c == null) {
            return null;
        }
        if (String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return c.FEC_Account_Contract_Number_Text__c.trim();
        }
        if (c.FEC_Account_or_Contract__c != null && String.isNotBlank(c.FEC_Account_or_Contract__r?.FEC_Account_Number__c)) {
            return c.FEC_Account_or_Contract__r.FEC_Account_Number__c;
        }
        return c.FEC_Account_Number__c;
    }

    private static String accountNumberIfValidFormat(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String t = raw.trim();
        return Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, t) ? t : null;
    }

    private static String getAccountNumberForGetIPPDetails(Id caseId, String customerHistoryAccountNumber) {
        String acc = accountNumberIfValidFormat(customerHistoryAccountNumber);
        if (acc != null) {
            return acc;
        }
        if (caseId == null) {
            return null;
        }
        Case c = loadCaseForIPPConversion(caseId);
        if (c == null) {
            return null;
        }
        acc = accountNumberIfValidFormat(c.FEC_Account_or_Contract__r?.FEC_Account_Number__c);
        if (acc != null) {
            return acc;
        }
        acc = accountNumberIfValidFormat(c.FEC_Account_Number__c);
        if (acc != null) {
            return acc;
        }
        return accountNumberIfValidFormat(c.FEC_Account_Contract_Number_Text__c);
    }

    private static Boolean isGetIPPDetailsResponseSuccess(FEC_GetIPPDetailsCallout.IPPDetailsResponse r) {
        return r != null && (
            r.status == FEC_ConstantCommon.SUCCESS_MESSAGE ||
            r.status == FEC_ConstantCommon.SUCCESS_STATUS_CODE ||
            (r.sysMessage != null && r.sysMessage.equalsIgnoreCase(FEC_ConstantCommon.SUCCESS_MESSAGE))
        );
    }

    private static List<Integer> parseTenorOptionsFromIppTerm(String ippTermStr) {
        List<Integer> opts = new List<Integer>();
        if (String.isBlank(ippTermStr)) {
            return opts;
        }
        for (String part : ippTermStr.trim().split(',')) {
            String p = part.trim();
            if (String.isBlank(p)) {
                continue;
            }
            try {
                opts.add(Integer.valueOf(p));
            } catch (Exception e) {
            }
        }
        return opts;
    }

    private static void applyAddIppResultToConvertResult(FEC_AddIPP.AddIPPResult addResult, ConvertResultDTO result) {
        if (addResult == null) {
            result.success = false;
            result.errorMessage = System.Label.FEC_MSG_IPP_AddIpp_Default_Failed;
            return;
        }
        result.success = (addResult.success == true);
        if (result.success) {
            if (String.isNotBlank(addResult.responseDescription)) {
                result.message = addResult.responseDescription;
            } else if (String.isNotBlank(addResult.description)) {
                result.message = addResult.description;
            } else {
                result.message = System.Label.FEC_MSG_IPP_AddIpp_Default_Success;
            }
        } else {
            if (String.isNotBlank(addResult.errorMessage)) {
                result.errorMessage = addResult.errorMessage;
            } else if (String.isNotBlank(addResult.description)) {
                result.errorMessage = addResult.description;
            } else {
                result.errorMessage = System.Label.FEC_MSG_IPP_AddIpp_Default_Failed;
            }
        }
    }

    private static void updateCaseActionCountForConvertResult(Case c, Boolean isSuccess) {
        if (c == null || c.Id == null) {
            return;
        }
        if (!Schema.sObjectType.Case.isUpdateable()
            || !Schema.sObjectType.Case.fields.FEC_Process_Action_Count__c.isUpdateable()) {
            return;
        }
        if (isSuccess) {
            c.FEC_Process_Action_Count__c = -1;
        } else {
            if (c.FEC_Process_Action_Count__c == null || c.FEC_Process_Action_Count__c < 0) {
                c.FEC_Process_Action_Count__c = 0;
            }
            c.FEC_Process_Action_Count__c += 1;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        update c;
    }
}