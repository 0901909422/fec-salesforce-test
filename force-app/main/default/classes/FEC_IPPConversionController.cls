/****************************************************************************************
 * File Name    : FEC_IPPConversionController.cls
 * Description  : RC34.01/RC34.02 IPP Conversion: API 41 GetUnbilledTransactions → eligible tx → Tenor (GetAccountDetails) → details (GetIPPDetails) → convertIPP (AddIPP).
 ****************************************************************************************/

public without sharing class FEC_IPPConversionController {

    public static final Integer MAX_RETRY_COUNT = 3;

    @TestVisible private static Boolean denyTransactionAccessForTest = false;
    @TestVisible private static Boolean denyCaseAccessForTest = false;
    @TestVisible private static Boolean denyCaseUpdateForTest = false;
    @TestVisible private static Boolean denyActionCountUpdateForTest = false;
    @TestVisible private static Integer addIppTestMode = 0;
    @TestVisible private static Integer unbilledApiTestMode = 0;
    @TestVisible private static FEC_GetUnbilledTransactions.ResponseWrapper unbilledApiTestResponse;
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
        List<EligibleTransactionDTO> fromApi = loadIppUnbilledTransactions(caseId);
        if (!fromApi.isEmpty()) {
            return fromApi;
        }
        return loadEligibleTransactionsFromDb(caseId);
    }

    /**
     * RC34.01 – lưu/xóa Transaction đã chọn trên Case.FEC_IPP_Transaction__c khi user chọn/bỏ chọn radio.
     */
    @AuraEnabled
    public static void saveSelectedTransaction(Id caseId, Id transactionId) {
        if (caseId == null || !isCaseUpdatable()) {
            return;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey('FEC_IPP_Transaction__c')
            || !caseFieldMap.get('FEC_IPP_Transaction__c').getDescribe().isUpdateable()) {
            return;
        }
        if (transactionId == null) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                update new Case(Id = caseId, FEC_IPP_Transaction__c = null);
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
            return;
        }
        if (!isTransactionReadable()) {
            return;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Customer_History__c
            FROM FEC_Transaction__c
            WHERE Id = :transactionId
            LIMIT 1
        ];
        if (txs.isEmpty()) {
            return;
        }
        Case c = loadCaseForIPPConversion(caseId);
        if (c == null || c.FEC_Account_or_Contract__c == null
            || txs[0].FEC_Customer_History__c != c.FEC_Account_or_Contract__c) {
            return;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = caseId, FEC_IPP_Transaction__c = transactionId);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    /**
     * RC34.01 – khôi phục Transaction đã chọn trước đó khi user mở lại IPP Conversion.
     */
    @AuraEnabled(cacheable=false)
    public static String getSavedIppTransactionId(Id caseId) {
        if (caseId == null || !isCaseReadable()) {
            return null;
        }
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!caseFieldMap.containsKey('FEC_IPP_Transaction__c')) {
            return null;
        }
        List<Case> cases = [
            SELECT Id, FEC_IPP_Transaction__c, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return null;
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        if (decision.getRecords().isEmpty()) {
            return null;
        }
        Case c = (Case) decision.getRecords()[0];
        Map<String, Object> populated = c.getPopulatedFieldsAsMap();
        if (!populated.containsKey('FEC_IPP_Transaction__c') || c.FEC_IPP_Transaction__c == null) {
            return null;
        }
        if (!isTransactionReadable()) {
            return null;
        }
        List<FEC_Transaction__c> txs = [
            SELECT Id, FEC_Customer_History__c
            FROM FEC_Transaction__c
            WHERE Id = :c.FEC_IPP_Transaction__c
            LIMIT 1
        ];
        if (txs.isEmpty() || txs[0].FEC_Customer_History__c != c.FEC_Account_or_Contract__c) {
            return null;
        }
        return txs[0].Id;
    }

    @TestVisible
    private static List<EligibleTransactionDTO> loadIppUnbilledTransactions(Id caseId) {
        List<EligibleTransactionDTO> result = new List<EligibleTransactionDTO>();
        Case c = loadCaseForIPPConversion(caseId);
        if (c == null || c.FEC_Account_or_Contract__c == null) {
            return result;
        }
        String accountNumber = getAccountNumberForGetIPPDetails(caseId, null);
        if (String.isBlank(accountNumber)) {
            return result;
        }
        FEC_GetUnbilledTransactions.ResponseWrapper apiRes;
        try {
            apiRes = callGetUnbilledTransactionsApi(accountNumber);
        } catch (Exception e) {
            System.debug('### loadIppUnbilledTransactions API ERROR: ' + e.getMessage());
            return result;
        }
        if (apiRes == null || apiRes.Transactions == null || apiRes.Transactions.isEmpty()) {
            return result;
        }
        List<FEC_Transaction__c> synced = syncUnbilledTransactionsFromApi(
            caseId,
            c.FEC_Account_or_Contract__c,
            apiRes.Transactions
        );
        for (FEC_Transaction__c tx : synced) {
            if (!isIppEligibleForDisplay(tx)) {
                continue;
            }
            result.add(mapTransactionToEligibleDto(tx));
        }
        result.sort(new EligibleTransactionDateComparator());
        return result;
    }

    @TestVisible
    private static FEC_GetUnbilledTransactions.ResponseWrapper callGetUnbilledTransactionsApi(String accountNumber) {
        if (unbilledApiTestMode == 1) {
            return unbilledApiTestResponse;
        }
        return FEC_GetUnbilledTransactions.callGetUnbilledTransactions(
            FEC_CommonUltils.generateTransactionId(),
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
            accountNumber
        );
    }

    @TestVisible
    private static List<FEC_Transaction__c> syncUnbilledTransactionsFromApi(
        Id caseId,
        Id customerHistoryId,
        List<FEC_GetUnbilledTransactions.TransactionRecord> apiRows
    ) {
        List<FEC_Transaction__c> result = new List<FEC_Transaction__c>();
        if (caseId == null || customerHistoryId == null || apiRows == null || apiRows.isEmpty()) {
            return result;
        }

        Map<String, FEC_Transaction__c> existingByKey = loadExistingUnbilledTransactionsByKey(customerHistoryId);
        Map<String, FEC_Transaction__c> toUpsertByKey = new Map<String, FEC_Transaction__c>();
        Map<String, Schema.SObjectField> txFieldMap = Schema.SObjectType.FEC_Transaction__c.fields.getMap();

        for (FEC_GetUnbilledTransactions.TransactionRecord row : apiRows) {
            if (row == null) {
                continue;
            }
            FEC_Transaction__c rec = mapApiRowToTransaction(caseId, customerHistoryId, row, txFieldMap);
            if (rec == null) {
                continue;
            }
            String key = buildUnbilledSyncKey(rec);
            if (String.isBlank(key)) {
                continue;
            }
            if (existingByKey.containsKey(key)) {
                rec.Id = existingByKey.get(key).Id;
            }
            toUpsertByKey.put(key, rec);
        }
        if (toUpsertByKey.isEmpty()) {
            return result;
        }
        try {
            upsert toUpsertByKey.values();
        } catch (Exception e) {
            System.debug('### syncUnbilledTransactionsFromApi upsert: ' + e.getMessage());
            for (FEC_Transaction__c rec : toUpsertByKey.values()) {
                if (rec.Id == null) {
                    String failKey = buildUnbilledSyncKey(rec);
                    if (existingByKey.containsKey(failKey)) {
                        rec.Id = existingByKey.get(failKey).Id;
                    }
                }
            }
        }
        Set<Id> syncedIds = collectSyncedTransactionIds(toUpsertByKey.values(), existingByKey);
        if (syncedIds.isEmpty()) {
            return result;
        }
        String selectFields = 'Id, FEC_Effective_Date__c, FEC_Post_Date__c, FEC_Transaction_Amount__c,' +
            ' FEC_Merchant_Description__c, FEC_Transaction_Plan__c, FEC_Transaction_Code__c';
        if (txFieldMap.containsKey('FEC_IPPEligibilityFlag__c')) {
            selectFields += ', FEC_IPPEligibilityFlag__c';
        }
        for (FEC_Transaction__c tx : Database.query(
            'SELECT ' + selectFields + ' FROM FEC_Transaction__c WHERE Id IN :syncedIds'
        )) {
            result.add(tx);
        }
        return result;
    }

    @TestVisible
    private static Map<String, FEC_Transaction__c> loadExistingUnbilledTransactionsByKey(Id customerHistoryId) {
        Map<String, FEC_Transaction__c> existingByKey = new Map<String, FEC_Transaction__c>();
        String unbilledType = FEC_ConstantCommon.TRANSACTION_TYPE_UNBILLED;
        Map<String, Schema.SObjectField> txFieldMap = Schema.SObjectType.FEC_Transaction__c.fields.getMap();
        String query = 'SELECT Id, FEC_Post_Date__c, FEC_Transaction_Amount__c, FEC_Transaction_Code__c';
        if (txFieldMap.containsKey('FEC_Type__c')) {
            query += ', FEC_Type__c';
        }
        query += ' FROM FEC_Transaction__c WHERE FEC_Customer_History__c = :customerHistoryId';
        if (txFieldMap.containsKey('FEC_Type__c')) {
            query += ' AND FEC_Type__c = :unbilledType';
        }
        for (FEC_Transaction__c tx : Database.query(query)) {
            String key = buildUnbilledSyncKey(tx);
            if (String.isNotBlank(key)) {
                existingByKey.put(key, tx);
            }
        }
        return existingByKey;
    }

    @TestVisible
    private static FEC_Transaction__c mapApiRowToTransaction(
        Id caseId,
        Id customerHistoryId,
        FEC_GetUnbilledTransactions.TransactionRecord row,
        Map<String, Schema.SObjectField> txFieldMap
    ) {
        Date postDate = FEC_CommonUltils.toDateStr(row.PostingDate);
        if (postDate == null || row.Amount == null) {
            return null;
        }
        FEC_Transaction__c rec = new FEC_Transaction__c(
            FEC_Customer_History__c = customerHistoryId
        );
        if (txFieldMap.containsKey('FEC_Case__c')) {
            rec.put('FEC_Case__c', caseId);
        }
        if (txFieldMap.containsKey('FEC_Type__c')) {
            rec.put('FEC_Type__c', FEC_ConstantCommon.TRANSACTION_TYPE_UNBILLED);
        }
        rec.FEC_Post_Date__c = postDate;
        rec.FEC_Transaction_Amount__c = row.Amount;
        rec.FEC_Merchant_Description__c = row.Description;
        rec.FEC_Transaction_Code__c = row.TransactionCode;
        rec.FEC_Effective_Date__c = resolveEffectiveDateFromApi(row);
        rec.FEC_Transaction_Plan__c = row.TransactionPlan;
        if (txFieldMap.containsKey('FEC_IPPEligibilityFlag__c')) {
            rec.put('FEC_IPPEligibilityFlag__c', row.IPPEligibilityFlag);
        }
        return rec;
    }

    @TestVisible
    private static Date resolveEffectiveDateFromApi(FEC_GetUnbilledTransactions.TransactionRecord row) {
        if (row == null) {
            return null;
        }
        Date eff = FEC_CommonUltils.toDateStr(row.EffectiveDate);
        if (eff != null) {
            return eff;
        }
        return FEC_CommonUltils.toDateStr(row.TransactionDate);
    }

    @TestVisible
    private static String buildUnbilledSyncKey(FEC_Transaction__c tx) {
        if (tx == null) {
            return null;
        }
        String code = tx.FEC_Transaction_Code__c != null ? tx.FEC_Transaction_Code__c.trim() : '';
        String post = tx.FEC_Post_Date__c != null ? String.valueOf(tx.FEC_Post_Date__c) : '';
        String amt = tx.FEC_Transaction_Amount__c != null ? String.valueOf(tx.FEC_Transaction_Amount__c) : '';
        if (String.isBlank(code) && String.isBlank(post) && String.isBlank(amt)) {
            return null;
        }
        return code + '|' + post + '|' + amt;
    }

    @TestVisible
    private static Boolean isIppEligibleForDisplay(FEC_Transaction__c tx) {
        if (tx == null) {
            return false;
        }
        String txCode = tx.FEC_Transaction_Code__c != null ? tx.FEC_Transaction_Code__c.trim() : '';
        if (String.isBlank(txCode) || !FEC_ConstantCommon.IPP_ELIGIBLE_TRANSACTION_CODES.contains(txCode)) {
            return false;
        }
        Map<String, Schema.SObjectField> txFieldMap = Schema.SObjectType.FEC_Transaction__c.fields.getMap();
        if (!txFieldMap.containsKey('FEC_IPPEligibilityFlag__c')) {
            return true;
        }
        Map<String, Object> populated = tx.getPopulatedFieldsAsMap();
        if (!populated.containsKey('FEC_IPPEligibilityFlag__c')) {
            return true;
        }
        Object flagObj = populated.get('FEC_IPPEligibilityFlag__c');
        String flag = flagObj != null ? String.valueOf(flagObj).trim() : '';
        return flag == FEC_ConstantCommon.IPP_ELIGIBILITY_FLAG_RETAIL;
    }

    @TestVisible
    private static Set<Id> collectSyncedTransactionIds(
        List<FEC_Transaction__c> upserted,
        Map<String, FEC_Transaction__c> existingByKey
    ) {
        Set<Id> syncedIds = new Set<Id>();
        if (upserted == null || upserted.isEmpty()) {
            return syncedIds;
        }
        for (FEC_Transaction__c tx : upserted) {
            if (tx == null) {
                continue;
            }
            if (tx.Id != null) {
                syncedIds.add(tx.Id);
                continue;
            }
            String key = buildUnbilledSyncKey(tx);
            if (String.isNotBlank(key) && existingByKey != null && existingByKey.containsKey(key)) {
                Id existingId = existingByKey.get(key).Id;
                if (existingId != null) {
                    syncedIds.add(existingId);
                }
            }
        }
        return syncedIds;
    }

    @TestVisible
    private static EligibleTransactionDTO mapTransactionToEligibleDto(FEC_Transaction__c tx) {
        EligibleTransactionDTO dto = new EligibleTransactionDTO();
        dto.transactionId = tx.Id;
        dto.transactionCode = tx.FEC_Transaction_Code__c != null ? tx.FEC_Transaction_Code__c : FEC_ConstantCommon.STR_EMPTY;
        dto.effectiveDateStr = tx.FEC_Effective_Date__c != null ? String.valueOf(tx.FEC_Effective_Date__c) : FEC_ConstantCommon.STR_EMPTY;
        dto.transactionPlan = tx.FEC_Transaction_Plan__c != null ? tx.FEC_Transaction_Plan__c : FEC_ConstantCommon.STR_EMPTY;
        dto.amount = tx.FEC_Transaction_Amount__c;
        dto.postingDateStr = tx.FEC_Post_Date__c != null ? String.valueOf(tx.FEC_Post_Date__c) : FEC_ConstantCommon.STR_EMPTY;
        dto.merchant = tx.FEC_Merchant_Description__c != null ? tx.FEC_Merchant_Description__c : FEC_ConstantCommon.STR_EMPTY;
        return dto;
    }

    private class EligibleTransactionDateComparator implements System.Comparator<EligibleTransactionDTO> {
        public Integer compare(EligibleTransactionDTO a, EligibleTransactionDTO b) {
            Date da = parseEligibleDate(a != null ? a.effectiveDateStr : null);
            Date db = parseEligibleDate(b != null ? b.effectiveDateStr : null);
            if (da == null && db == null) {
                return 0;
            }
            if (da == null) {
                return 1;
            }
            if (db == null) {
                return -1;
            }
            if (da == db) {
                return 0;
            }
            return da > db ? -1 : 1;
        }
    }

    @TestVisible
    private static Date parseEligibleDate(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Date.valueOf(raw.trim());
        } catch (Exception e) {
            return FEC_CommonUltils.toDateStr(raw);
        }
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
                   FEC_Transaction_Code__c, FEC_Authorization_Code__c, FEC_Customer_History__c,
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
                return dto;
            }
            if (detailResp.status != null && detailResp.status.equalsIgnoreCase(FEC_ConstantCommon.CASE_STATUS_ERROR)) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                return dto;
            }
            if (!isGetIPPDetailsResponseSuccess(detailResp)) {
                dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
                return dto;
            }
            dto.interestRate = detailResp.interestRate;
            dto.fee = detailResp.conversionFee;
            dto.emi = detailResp.emi != null ? detailResp.emi : detailResp.installmentAmount;
        } catch (Exception e) {
            dto.errorMessage = System.Label.FEC_MSG_IPP_Sync_Failed;
        }
        return dto;
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
                   FEC_Transaction_Code__c, FEC_Authorization_Code__c, FEC_Customer_History__c
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
        result.maxRetriesExceeded = false;
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
        String cardNo = resolveCardNumberForGetIppDetails(c);
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
        result.maxRetriesExceeded = false;
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
        String cardNo = resolveCardNumberForGetIppDetails(c);
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
        String transactionPlan = tx.FEC_Transaction_Plan__c;
        if (String.isNotBlank(transactionPlan)) {
            req.planNumber = transactionPlan;
            req.transactionPlan = transactionPlan;
        }
        req.ippTerm = resolveIppTermForGetIppDetails(tx, tenor);
        String refNo = resolveReferenceNumberForIpp(tx, tx.Id);
        if (String.isNotBlank(refNo)) {
            req.referenceNumber = refNo;
        }
        req.cardNumber = resolveCardNumberForGetIppDetails(c);
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
        String refNo = resolveReferenceNumberForIpp(tx, tx.Id);
        req.referenceNumber = refNo;
        req.transactionPlan = tx.FEC_Transaction_Plan__c;
        req.postingDate = postDate;
        req.cardNumber = resolveCardNumberForGetIppDetails(c);
        req.cardSeq = 0;
        req.ippKey = refNo;
        return req;
    }

    @TestVisible
    private static Integer resolveIppTermForGetIppDetails(FEC_Transaction__c tx, Integer tenor) {
        if (tx != null) {
            Map<String, Schema.SObjectField> txFieldMap = Schema.SObjectType.FEC_Transaction__c.fields.getMap();
            if (txFieldMap.containsKey('FEC_IPP_Term__c')) {
                Map<String, Object> populated = tx.getPopulatedFieldsAsMap();
                if (populated.containsKey('FEC_IPP_Term__c') && tx.get('FEC_IPP_Term__c') != null) {
                    Integer savedTerm = Integer.valueOf(String.valueOf(tx.get('FEC_IPP_Term__c')));
                    if (savedTerm > 0) {
                        return savedTerm;
                    }
                }
            }
        }
        return tenor;
    }

    @TestVisible
    private static Integer resolveIppTermForAddIpp(Case c, Integer tenor) {
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
    private static String resolveReferenceNumberForIpp(FEC_Transaction__c tx, Id transactionId) {
        if (tx != null && String.isNotBlank(tx.FEC_Transaction_Code__c)) {
            return tx.FEC_Transaction_Code__c;
        }
        if (tx != null && String.isNotBlank(tx.FEC_Authorization_Code__c)) {
            return tx.FEC_Authorization_Code__c;
        }
        return transactionId != null ? String.valueOf(transactionId) : null;
    }

    private static Case loadCaseForIPPConversion(Id caseId) {
        if (caseId == null || !isCaseReadable()) {
            return null;
        }
        // 2026-06-16 linhdev – load Case for IPP Conversion (account/card context)
        String caseQuery = 'SELECT Id, FEC_Account_Number__c, FEC_Account_Contract_Number_Text__c, FEC_Account_or_Contract__c,' +
            ' FEC_Process_Action_Count__c, FEC_Is_Test_API__c,' +
            ' FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.Name,' +
            ' FEC_Account_or_Contract__r.Name, FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Account_or_Contract__r.FEC_Card_Number__c' +
            ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<Case> cases = Database.query(caseQuery);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, cases);
        List<SObject> recs = decision.getRecords();
        return recs.isEmpty() ? null : (Case) recs[0];
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
    private static String resolveAccountNumberForAddIPP(Case c) {
        if (c == null) {
            return null;
        }
        Map<String, Object> cPopulated = c.getPopulatedFieldsAsMap();
        if (accountContractTextForTest != null && String.isNotBlank(accountContractTextForTest)) {
            return accountContractTextForTest.trim();
        }
        if (cPopulated.containsKey('FEC_Account_or_Contract__r')) {
            String accFromName = accountNumberIfValidFormat(c.FEC_Account_or_Contract__r?.Name);
            if (accFromName != null) {
                return accFromName;
            }
            if (String.isNotBlank(c.FEC_Account_or_Contract__r?.FEC_Account_Number__c)) {
                return c.FEC_Account_or_Contract__r.FEC_Account_Number__c.trim();
            }
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