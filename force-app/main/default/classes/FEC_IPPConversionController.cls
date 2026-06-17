/****************************************************************************************
 * File Name    : FEC_IPPConversionController.cls
 * Description  : RC34.01/RC34.02 IPP Conversion: eligible tx → Tenor (GetAccountDetails) → details (GetIPPDetails) → convertIPP (AddIPP).
 *                Load tx: GetCardBasicInfo + M_FAS_OUTSTANDING_AUTH_INQ (fallback FEC_Transaction__c).
 ****************************************************************************************/

public without sharing class FEC_IPPConversionController {

    public static final Integer MAX_RETRY_COUNT = 3;

    @TestVisible private static Boolean denyTransactionAccessForTest = false;
    @TestVisible private static Boolean denyCaseAccessForTest = false;
    @TestVisible private static Boolean denyCaseUpdateForTest = false;
    @TestVisible private static Boolean denyIppTermUpdateForTest = false;
    @TestVisible private static Boolean denyActionCountUpdateForTest = false;
    @TestVisible private static Integer addIppTestMode = 0;
    @TestVisible private static String accountContractTextForTest;

    @TestVisible
    private static Boolean isTransactionReadable() {
        return !denyTransactionAccessForTest && Schema.sObjectType.FEC_Transaction__c.isAccessible();
    }

    @TestVisible
    private static Boolean isCaseReadable() {
        return !denyCaseAccessForTest && Schema.sObjectType.Case.isAccessible();
    }

    @TestVisible
    private static Boolean isCaseUpdatable() {
        return !denyCaseUpdateForTest && Schema.sObjectType.Case.isUpdateable();
    }

    @TestVisible
    private static Boolean isIppTermFieldUpdateable() {
        if (denyIppTermUpdateForTest) {
            return false;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.sObjectType.Case.fields.getMap();
        return caseFieldMap.containsKey('FEC_IPP_Term__c')
            && caseFieldMap.get('FEC_IPP_Term__c').getDescribe().isUpdateable();
    }

    @TestVisible
    private static Boolean isActionCountFieldUpdateable() {
        return !denyActionCountUpdateForTest
            && Schema.sObjectType.Case.fields.FEC_Process_Action_Count__c.isUpdateable();
    }

    @TestVisible
    private static FEC_AddIPP.AddIPPResult callAddIpp(FEC_AddIPP.IPPRequest req, Boolean isTestApi) {
        if (addIppTestMode == 1) {
            throw new CalloutException('Simulated AddIPP failure');
        }
        return FEC_AddIPP.addIPP(req, isTestApi);
    }

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

    public class AccountTenorDTO {
        @AuraEnabled public List<Integer> tenorOptions;
        @AuraEnabled public String planNumber;
        @AuraEnabled public Integer savedTenor;
        @AuraEnabled public Decimal savedInterestRate;
        @AuraEnabled public Decimal savedFee;
        @AuraEnabled public Decimal savedEmi;
        @AuraEnabled public String errorMessage;
    }

    public class ConvertResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Decimal actionCount;
        @AuraEnabled public Boolean maxRetriesExceeded;
    }

    public class ActionStatusDTO {
        @AuraEnabled public Decimal actionCount;
        @AuraEnabled public Boolean canConvert;
    }

    /**
     * Get eligible retail transactions via API 41 GetUnbilledTransactions, sync to FEC_Transaction__c, apply display filter.
     * Fallback: load from FEC_Transaction__c by Case Customer History when API returns no eligible rows.
     */
    @AuraEnabled(cacheable=false)
    public static List<EligibleTransactionDTO> getEligibleTransactions(Id caseId) {
        if (caseId == null) {
            return new List<EligibleTransactionDTO>();
        }
        FEC_TransactionsController.TransactionsResponse res = FEC_TransactionsController.loadTransactions(caseId);
        return resolveEligibleTransactions(caseId, res);
    }

    @TestVisible
    private static List<EligibleTransactionDTO> resolveEligibleTransactions(Id caseId, FEC_TransactionsController.TransactionsResponse res) {
        List<EligibleTransactionDTO> apiMapped = mapUnbilledApiTransactions(res);
        if (!apiMapped.isEmpty()) {
            return apiMapped;
        }
        return loadEligibleTransactionsFromDb(caseId);
    }

    @TestVisible
    private static List<EligibleTransactionDTO> mapUnbilledApiTransactions(FEC_TransactionsController.TransactionsResponse res) {
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
        }
        return result;
    }

    @TestVisible
    private static List<EligibleTransactionDTO> loadEligibleTransactionsFromDb(Id caseId) {
        List<EligibleTransactionDTO> result = new List<EligibleTransactionDTO>();
        if (caseId == null) return result;
        if (!isCaseReadable() || !isTransactionReadable()) {
            return result;
        }
        List<Case> cases = [SELECT FEC_Account_or_Contract__c FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].FEC_Account_or_Contract__c == null) {
            return result;
        }
        Id chId = cases[0].FEC_Account_or_Contract__c;
        Map<String, Schema.SObjectField> txFieldMap = Schema.SObjectType.FEC_Transaction__c.fields.getMap();
        String query = 'SELECT Id, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Amount__c,' +
            ' FEC_Merchant_Description__c, FEC_Transaction_Plan__c, FEC_Transaction_Code__c';
        if (txFieldMap.containsKey('FEC_IPPEligibilityFlag__c')) {
            query += ', FEC_IPPEligibilityFlag__c';
        }
        query += ' FROM FEC_Transaction__c WHERE FEC_Customer_History__c = :chId ORDER BY FEC_Effective_Date__c DESC';
        List<FEC_Transaction__c> txs = Database.query(query);
        for (FEC_Transaction__c tx : txs) {
            if (!isIppEligibleForDisplay(tx)) {
                continue;
            }
            result.add(mapTransactionToEligibleDto(tx));
        }
        return result;
    }

    /**
     * RC34.01 – Service 38 GetAccountDetails: load Tenor picklist (MinTenure..MaxTenure, step 3).
     * 2026-06-16 linhdev
     */
    @AuraEnabled(cacheable=false)
    public static AccountTenorDTO loadIppTenorOptions(Id caseId) {
        AccountTenorDTO dto = new AccountTenorDTO();
        dto.tenorOptions = new List<Integer>();
        if (caseId == null) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return dto;
        }
        Case c = loadCaseForIPPConversion(caseId);
        String accountNumber = resolveAccountNumberForAddIPP(c);
        if (String.isBlank(accountNumber)) {
            dto.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return dto;
        }
        applySavedIppFieldsToTenorDto(c, dto);
        try {
            FEC_GetAccountDetails.ResponseWrapper accountRes = FEC_GetAccountDetails.callGetAccountDetails(
                FEC_CommonUltils.generateTransactionId(),
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
                accountNumber
            );
            if (accountRes == null || accountRes.Account == null) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                return dto;
            }
            if (accountRes.Account.CashIPPInfo != null) {
                applyCashIppTenorOptions(dto, accountRes.Account.CashIPPInfo);
            }
            if (dto.tenorOptions.isEmpty()
                && accountRes.Account.RetailIPPInfo != null
                && String.isNotBlank(accountRes.Account.RetailIPPInfo.PlanNumber)) {
                dto.planNumber = accountRes.Account.RetailIPPInfo.PlanNumber;
            }
            if (dto.tenorOptions.isEmpty()) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
            }
        } catch (Exception e) {
            dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
            System.debug('### loadIppTenorOptions ERROR: ' + e.getMessage());
        }
        return dto;
    }

    @TestVisible
    private static void applyCashIppTenorOptions(AccountTenorDTO dto, FEC_GetAccountDetails.CashIPPInfo cashIpp) {
        if (dto == null || cashIpp == null) {
            return;
        }
        dto.tenorOptions = cashIpp.TenureList != null
            ? cashIpp.TenureList
            : FEC_GetAccountDetails.buildTenureList(
                cashIpp.MinTenure,
                cashIpp.MaxTenure
            );
        if (String.isNotBlank(cashIpp.PlanNumber)) {
            dto.planNumber = cashIpp.PlanNumber;
        }
    }

    /**
     * Check IPP details for a transaction via FEC_GetIPPDetailsCallout (interest, fee, EMI) after Tenor selected.
     * 2026-06-16 linhdev – Service 40 GetIPPDetails; Tenor from GetAccountDetails (loadIppTenorOptions).
     */
    @AuraEnabled(cacheable=false)
    public static IPPDetailsDTO checkIPPDetails(Id caseId, Id transactionId, Integer tenor) {
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
        if (caseId == null) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' });
            return dto;
        }
        if (tenor == null || tenor <= 0) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Tenor' });
            return dto;
        }
        if (!isTransactionReadable()) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return dto;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Plan__c,
                   FEC_Transaction_Code__c, FEC_Reference_Number__c, FEC_Authorization_Code__c, FEC_Customer_History__c,
                   FEC_Card_Seq__c, FEC_IPP_Key__c,
                   FEC_Customer_History__r.FEC_Account_Number__c,
                   FEC_Customer_History__r.FEC_Card_Number__c
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
        Case c = loadCaseForIPPConversion(caseId);
        if (c == null || c.FEC_Account_or_Contract__c == null) {
            dto.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return dto;
        }
        if (tx.FEC_Customer_History__c != c.FEC_Account_or_Contract__c) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return dto;
        }
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
        Integer ippTerm = resolveIppTermForAddIpp(c, tenor);
        if (ippTerm == null || ippTerm <= 0) {
            dto.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Tenor' });
            return dto;
        }
        System.debug('### checkIPPDetails GetIPPDetails caseId=' + caseId + ', transactionId=' + transactionId + ', tenor=' + ippTerm);
        FEC_GetIPPDetailsCallout.IPPRequest req = buildGetIppDetailsRequest(c, tx, tenor, accountNumber);
        try {
            FEC_GetIPPDetailsCallout.IPPDetailsResponse detailResp = callGetIppDetails(req);
            if (detailResp == null) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                clearCaseIppDetailFields(caseId);
                return dto;
            }
            if (detailResp.status != null && detailResp.status.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_ERROR)) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                clearCaseIppDetailFields(caseId);
                return dto;
            }
            if (!isGetIPPDetailsResponseSuccess(detailResp)) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                clearCaseIppDetailFields(caseId);
                return dto;
            }
            dto.interestRate = detailResp.interestRate;
            dto.fee = detailResp.conversionFee;
            dto.emi = detailResp.emi != null ? detailResp.emi : detailResp.installmentAmount;
            updateCaseIppConversionFields(
                caseId,
                ippTerm,
                dto.interestRate,
                dto.fee,
                dto.emi
            );
        } catch (Exception e) {
            dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
            clearCaseIppDetailFields(caseId);
        }
        return dto;
    }

    /**
     * RC34.01 – lưu FEC_IPP_Term__c khi user chọn Tenor (tách DML khỏi callout GetIPPDetails).
     * 2026-06-16 linhdev
     */
    @AuraEnabled
    public static void saveCaseIppTerm(Id caseId, Integer tenor) {
        updateCaseIppTermOnly(caseId, tenor);
    }

    @AuraEnabled(cacheable=false)
    public static ActionStatusDTO getConvertActionStatus(Id caseId) {
        ActionStatusDTO dto = new ActionStatusDTO();
        dto.actionCount = null;
        dto.canConvert = true;
        if (caseId == null || !isCaseReadable()) {
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
     * Convert IPP (RC34.01 & RC34.02): build AddIPP request from Case + selected transaction + tenor, call FEC_AddIPP.addIPP, return result.
     */
    @AuraEnabled
    public static ConvertResultDTO convertIPP(Id caseId, Id transactionId, Integer tenor) {
        ConvertResultDTO result = new ConvertResultDTO();
        result.success = false;
        result.message = null;
        result.errorMessage = null;
        result.maxRetriesExceeded = false;
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
        if (c == null || c.FEC_Account_or_Contract__c == null) {
            result.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return result;
        }
        if (!isTransactionReadable()) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return result;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Transaction_Amount__c, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Plan__c,
                   FEC_Reference_Number__c, FEC_Card_Seq__c, FEC_IPP_Key__c, FEC_Customer_History__c
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
        if (tx.FEC_Customer_History__c != c.FEC_Account_or_Contract__c) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Not_Found, new List<String>{ 'Transaction' });
            return result;
        }
        if (tx.FEC_Transaction_Amount__c == null || tx.FEC_Transaction_Amount__c <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{ 'Amount', '0' });
            return result;
        }
        if (String.isBlank(tx.FEC_Transaction_Plan__c)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Plan Number' });
            return result;
        }
        String accountNumber = getAccountNumberForGetIPPDetails(caseId, null);
        if (String.isBlank(accountNumber)) {
            result.errorMessage = System.Label.FEC_MSG_Not_Account_Linked;
            return result;
        }
        if (String.isBlank(tx.FEC_Reference_Number__c)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Reference Number' });
            return result;
        }
        Integer cardSeq = parseCardSeqForGetIppDetails(tx.FEC_Card_Seq__c);
        if (cardSeq == null) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Seq' });
            return result;
        }
        if (String.isBlank(tx.FEC_IPP_Key__c)) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'IPP Key' });
            return result;
        }
        if (String.isBlank(resolveCardNumberForGetIppDetails(c))) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Card Number' });
            return result;
        }
        Integer ippTerm = resolveIppTermForAddIpp(c, tenor);
        if (ippTerm == null || ippTerm <= 0) {
            result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Tenor' });
            return result;
        }
        FEC_AddIPP.IPPRequest req = buildAddIppRequest(c, tx, accountNumber, ippTerm);
        try {
            FEC_AddIPP.AddIPPResult addResult = callAddIpp(req, c != null ? c.FEC_Is_Test_API__c : false);
            applyAddIppResultToConvertResult(addResult, result);
            updateCaseActionCountForConvertResult(c, result.success == true);
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            updateCaseActionCountForConvertResult(c, false);
        } finally {
            logConvertIppProcessActionHistory(c, result.success == true);
        }
        result.actionCount = c != null ? c.FEC_Process_Action_Count__c : null;
        result.maxRetriesExceeded = (result.success != true && c != null && c.FEC_Process_Action_Count__c != null && c.FEC_Process_Action_Count__c >= MAX_RETRY_COUNT);
        return result;
    }

    private static void logConvertIppProcessActionHistory(Case c, Boolean isSuccess) {
        if (c != null) {
            FEC_CommonUltils.createProcessActionHistory(FEC_AddIPP.API_CONFIG_NAME, c, isSuccess == true);
        }
    }

    @TestVisible
    private static FEC_GetIPPDetailsCallout.IPPRequest buildGetIppDetailsRequest(
        Case c,
        FEC_Transaction__c tx,
        Integer tenor,
        String accountNumber
    ) {
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
        req.ippTerm = resolveIppTermForAddIpp(c, tenor);
        if (String.isNotBlank(tx.FEC_Reference_Number__c)) {
            req.referenceNumber = tx.FEC_Reference_Number__c;
        }
        req.cardNumber = resolveCardNumberForGetIppDetails(c);
        req.cardSeq = parseCardSeqForGetIppDetails(tx.FEC_Card_Seq__c);
        req.ippKey = tx.FEC_IPP_Key__c;
        return req;
    }

    @TestVisible
    private static FEC_AddIPP.IPPRequest buildAddIppRequest(
        Case c,
        FEC_Transaction__c tx,
        String accountNumber,
        Integer ippTerm
    ) {
        Date effDate = tx.FEC_Effective_Date__c != null ? tx.FEC_Effective_Date__c : Date.today();
        Date postDate = tx.FEC_Post_Date__c != null ? tx.FEC_Post_Date__c : effDate;
        FEC_AddIPP.IPPRequest req = new FEC_AddIPP.IPPRequest();
        req.accountNumber = accountNumber;
        req.effectiveDate = effDate;
        req.amount = tx.FEC_Transaction_Amount__c;
        req.planNumber = tx.FEC_Transaction_Plan__c;
        req.ippTerm = ippTerm;
        req.referenceNumber = tx.FEC_Reference_Number__c;
        req.transactionPlan = tx.FEC_Transaction_Plan__c;
        req.postingDate = postDate;
        req.cardNumber = resolveCardNumberForGetIppDetails(c);
        req.cardSeq = parseCardSeqForGetIppDetails(tx.FEC_Card_Seq__c);
        req.ippKey = tx.FEC_IPP_Key__c;
        return req;
    }

    @TestVisible
    private static Integer resolveIppTermForAddIpp(Case c, Integer tenor) {
        if (c != null) {
            Map<String, Object> populated = c.getPopulatedFieldsAsMap();
            Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
            if (caseFieldMap.containsKey('FEC_IPP_Term__c') && populated.containsKey('FEC_IPP_Term__c') && c.get('FEC_IPP_Term__c') != null) {
                Integer savedTerm = Integer.valueOf(String.valueOf(c.get('FEC_IPP_Term__c')));
                if (savedTerm > 0) {
                    return savedTerm;
                }
            }
        }
        return tenor;
    }

    @TestVisible
    private static String resolveCardNumberForGetIppDetails(Case c) {
        if (c == null || c.FEC_Account_or_Contract__c == null) {
            return null;
        }
        Map<String, Object> cPop = c.getPopulatedFieldsAsMap();
        if (cPop.containsKey('FEC_Account_or_Contract__r')) {
            FEC_Customer_History__c chRel = (FEC_Customer_History__c) c.getSObject('FEC_Account_or_Contract__r');
            if (chRel != null && String.isNotBlank(chRel.FEC_Card_Number__c)) {
                return chRel.FEC_Card_Number__c;
            }
        }
        return null;
    }

    @TestVisible
    private static Integer parseCardSeqForGetIppDetails(String cardSeqText) {
        if (String.isBlank(cardSeqText)) {
            return null;
        }
        try {
            return Integer.valueOf(cardSeqText.trim());
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static String resolveCardNumberForAddIpp(FEC_Transaction__c tx, Case c) {
        if (tx != null && tx.FEC_Customer_History__c != null) {
            Map<String, Object> txPop = tx.getPopulatedFieldsAsMap();
            if (txPop.containsKey('FEC_Customer_History__r')) {
                FEC_Customer_History__c chRel = (FEC_Customer_History__c) tx.getSObject('FEC_Customer_History__r');
                if (chRel != null && String.isNotBlank(chRel.FEC_Card_Number__c)) {
                    return chRel.FEC_Card_Number__c;
                }
            }
        }
        if (c != null && c.FEC_Account_or_Contract__r != null) {
            return c.FEC_Account_or_Contract__r.FEC_Card_Number__c;
        }
        return null;
    }

    private static Case loadCaseForIPPConversion(Id caseId) {
        if (caseId == null || !isCaseReadable()) {
            return null;
        }
        // 2026-06-16 linhdev – restore Tenor/Interest/Fee/EMI sau refresh Case nếu field đã có trên org
        String caseQuery = 'SELECT Id, FEC_Account_Number__c, FEC_Account_Contract_Number_Text__c, FEC_Account_or_Contract__c,' +
            ' FEC_Process_Action_Count__c, FEC_Is_Test_API__c,' +
            ' FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.Name,' +
            ' FEC_Account_or_Contract__r.Name, FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Card_Number__c';
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (caseFieldMap.containsKey('FEC_IPP_Term__c')) {
            caseQuery += ', FEC_IPP_Term__c';
        }
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c')) {
            caseQuery += ', FEC_IPP_Interest__c';
        }
        if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')) {
            caseQuery += ', FEC_Conversion_Fee__c';
        }
        if (caseFieldMap.containsKey('FEC_EMI__c')) {
            caseQuery += ', FEC_EMI__c';
        }
        caseQuery += ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<Case> cases = Database.query(caseQuery);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        List<SObject> recs = decision.getRecords();
        return recs.isEmpty() ? null : (Case) recs[0];
    }

    @TestVisible
    private static void applySavedIppFieldsToTenorDto(Case c, AccountTenorDTO dto) {
        if (c == null || dto == null) {
            return;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        Map<String, Object> populated = c.getPopulatedFieldsAsMap();
        if (caseFieldMap.containsKey('FEC_IPP_Term__c') && populated.containsKey('FEC_IPP_Term__c') && c.get('FEC_IPP_Term__c') != null) {
            dto.savedTenor = Integer.valueOf(String.valueOf(c.get('FEC_IPP_Term__c')));
        }
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c') && populated.containsKey('FEC_IPP_Interest__c')) {
            dto.savedInterestRate = (Decimal) c.get('FEC_IPP_Interest__c');
        }
        if (caseFieldMap.containsKey('FEC_Conversion_Fee__c') && populated.containsKey('FEC_Conversion_Fee__c')) {
            dto.savedFee = (Decimal) c.get('FEC_Conversion_Fee__c');
        }
        if (caseFieldMap.containsKey('FEC_EMI__c') && populated.containsKey('FEC_EMI__c')) {
            dto.savedEmi = (Decimal) c.get('FEC_EMI__c');
        }
    }

    @TestVisible
    private static Integer ippDetailsTestMode = 0;

    @TestVisible
    private static FEC_GetIPPDetailsCallout.IPPDetailsResponse callGetIppDetails(FEC_GetIPPDetailsCallout.IPPRequest req) {
        if (ippDetailsTestMode == 1) {
            return null;
        }
        return FEC_GetIPPDetailsCallout.getIPPDetails(req);
    }

    @TestVisible
    private static void updateCaseIppTermOnly(Id caseId, Integer tenor) {
        if (caseId == null || tenor == null || tenor <= 0 || !isCaseUpdatable()) {
            return;
        }
        if (!isIppTermFieldUpdateable()) {
            return;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = caseId, FEC_IPP_Term__c = Decimal.valueOf(tenor));
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @TestVisible
    private static void clearCaseIppDetailFields(Id caseId) {
        if (caseId == null || !isCaseUpdatable()) {
            return;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        Case c = new Case(Id = caseId);
        Boolean hasUpdate = false;
        if (caseFieldMap.containsKey('FEC_IPP_Interest__c')
            && caseFieldMap.get('FEC_IPP_Interest__c').getDescribe().isUpdateable()) {
            c.put('FEC_IPP_Interest__c', null);
            hasUpdate = true;
        }
        if (caseFieldMap.containsKey('FEC_Conversion_Fee__c')
            && caseFieldMap.get('FEC_Conversion_Fee__c').getDescribe().isUpdateable()) {
            c.put('FEC_Conversion_Fee__c', null);
            hasUpdate = true;
        }
        if (caseFieldMap.containsKey('FEC_EMI__c')
            && caseFieldMap.get('FEC_EMI__c').getDescribe().isUpdateable()) {
            c.put('FEC_EMI__c', null);
            hasUpdate = true;
        }
        if (hasUpdate) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                update c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    @TestVisible
    private static void updateCaseIppConversionFields(
        Id caseId,
        Integer tenor,
        Decimal interestRate,
        Decimal fee,
        Decimal emi
    ) {
        if (caseId == null || !isCaseUpdatable()) {
            return;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        Case c = new Case(Id = caseId);
        Boolean hasUpdate = false;
        if (tenor != null && caseFieldMap.containsKey('FEC_IPP_Term__c')
            && caseFieldMap.get('FEC_IPP_Term__c').getDescribe().isUpdateable()) {
            c.put('FEC_IPP_Term__c', Decimal.valueOf(tenor));
            hasUpdate = true;
        }
        if (interestRate != null && caseFieldMap.containsKey('FEC_IPP_Interest__c')
            && caseFieldMap.get('FEC_IPP_Interest__c').getDescribe().isUpdateable()) {
            c.put('FEC_IPP_Interest__c', interestRate);
            hasUpdate = true;
        }
        if (fee != null && caseFieldMap.containsKey('FEC_Conversion_Fee__c')
            && caseFieldMap.get('FEC_Conversion_Fee__c').getDescribe().isUpdateable()) {
            c.put('FEC_Conversion_Fee__c', fee);
            hasUpdate = true;
        }
        if (emi != null && caseFieldMap.containsKey('FEC_EMI__c')
            && caseFieldMap.get('FEC_EMI__c').getDescribe().isUpdateable()) {
            c.put('FEC_EMI__c', emi);
            hasUpdate = true;
        }
        if (hasUpdate) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                update c;
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    @TestVisible
    private static String resolveAccountNumberForAddIPP(Case c) {
        if (c == null) {
            return null;
        }
        Map<String, Object> cPopulated = c.getPopulatedFieldsAsMap();
        if (accountContractTextForTest != null && String.isNotBlank(accountContractTextForTest)) {
            return accountContractTextForTest.trim();
        }
        if (cPopulated.containsKey('FEC_Account_Contract_Number_Text__c') && String.isNotBlank(c.FEC_Account_Contract_Number_Text__c)) {
            return c.FEC_Account_Contract_Number_Text__c.trim();
        }
        return cPopulated.containsKey('FEC_Account_Number__c') ? c.FEC_Account_Number__c : null;
    }

    @TestVisible
    private static String accountNumberIfValidFormat(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String t = raw.trim();
        return Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, t) ? t : null;
    }

    @TestVisible
    private static String getAccountNumberForGetIPPDetails(Id caseId, String customerHistoryAccountNumber) {
        if (caseId != null) {
            Case c = loadCaseForIPPConversion(caseId);
            if (c != null) {
                Map<String, Object> cPop = c.getPopulatedFieldsAsMap();
                String acc = accountNumberIfValidFormat(c.FEC_Account_or_Contract__r?.Name);
                if (acc != null) {
                    return acc;
                }
                acc = accountNumberIfValidFormat(c.FEC_Account_or_Contract__r?.FEC_Account_Number__c);
                if (acc != null) {
                    return acc;
                }
                acc = accountNumberIfValidFormat(cPop.containsKey('FEC_Account_Number__c') ? c.FEC_Account_Number__c : null);
                if (acc != null) {
                    return acc;
                }
                String contractText = accountContractTextForTest != null
                    ? accountContractTextForTest
                    : (cPop.containsKey('FEC_Account_Contract_Number_Text__c') ? c.FEC_Account_Contract_Number_Text__c : null);
                acc = accountNumberIfValidFormat(contractText);
                if (acc != null) {
                    return acc;
                }
            }
        }
        return accountNumberIfValidFormat(customerHistoryAccountNumber);
    }

    @TestVisible
    private static Boolean isGetIPPDetailsResponseSuccess(FEC_GetIPPDetailsCallout.IPPDetailsResponse r) {
        // 2026-06-16 linhdev – chấp nhận Success/SUCCESS/0 từ GetIPPDetails
        return r != null && (
            (r.status != null && r.status.equalsIgnoreCase(FEC_ConstantCommon.SUCCESS_MESSAGE)) ||
            r.status == FEC_ConstantCommon.SUCCESS_STATUS_CODE ||
            (r.sysMessage != null && r.sysMessage.equalsIgnoreCase(FEC_ConstantCommon.SUCCESS_MESSAGE))
        );
    }

    @TestVisible
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

    @TestVisible
    private static void updateCaseActionCountForConvertResult(Case c, Boolean isSuccess) {
        if (c == null || c.Id == null) {
            return;
        }
        if (!isCaseUpdatable()
            || !isActionCountFieldUpdateable()) {
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