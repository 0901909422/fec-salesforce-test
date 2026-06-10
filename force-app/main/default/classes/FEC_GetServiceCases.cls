public without sharing class FEC_GetServiceCases {

    private static final List<String> RESOLVED_SERVICE_CASE_STATUSES = new List<String>{
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER
    };

    public class CustomerFilterContext {
        public String accountContractName;
        public List<String> nationalIds;
    }

    @AuraEnabled
    public static List<PendingCaseRow> getPendingServiceCases(Id recordId) {
        if (!Schema.sObjectType.Case.isAccessible()) {
            return new List<PendingCaseRow>();
        }
        CustomerFilterContext filterCtx = resolveCustomerFilterContext(recordId);
        if (filterCtx == null) {
            return new List<PendingCaseRow>();
        }
        List<String> rtNames = new List<String>{
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };
        List<String> resolvedStatuses = RESOLVED_SERVICE_CASE_STATUSES;
        String filterAccountContractName = filterCtx.accountContractName;
        List<String> filterNationalIds = filterCtx.nationalIds;
        String soql =
            'SELECT Id, FEC_ID_Search__c, FEC_Case_Status__c, ' +
            'FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Product_Type__c, FEC_Product_Type__r.Name, ' +
            'FEC_Category__r.Name, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Name_VN__c, ' +
            'FEC_Interaction__c, FEC_Interaction__r.FEC_ID_Search__c, ' +
            'FEC_Channel__c, FEC_Interaction_Subchannel__c, ' +
            'FEC_Case_Created_On__c, FEC_Case_Created_By__c, ' +
            'FEC_Last_Updated_On_View__c, FEC_Last_Updated_By_View__c ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN :rtNames AND IsClosed = false ' +
            'AND (FEC_Case_Status__c = null OR FEC_Case_Status__c NOT IN :resolvedStatuses) ';
        soql += buildCustomerFilterClause(filterCtx);
        soql += 'ORDER BY FEC_Case_Created_On__c DESC NULLS LAST';
        List<Case> cases = new List<Case>();
        try {
            cases = Database.query(soql);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.READABLE,
            cases
        );
        cases = (List<Case>) decision.getRecords();
        Set<String> stripped = decision.getRemovedFields().get('Case');
        List<PendingCaseRow> rows = new List<PendingCaseRow>();
        for (Case c : cases) {
            PendingCaseRow row = new PendingCaseRow();
            Map<String, Object> pop = c.getPopulatedFieldsAsMap();
            row.caseId = c.Id;
            row.caseIdText = (stripped != null && stripped.contains('FEC_ID_Search__c')) ? FEC_ConstantCommon.STR_EMPTY : (c.FEC_ID_Search__c != null ? c.FEC_ID_Search__c : FEC_ConstantCommon.STR_EMPTY);
            row.caseStatus = (stripped != null && stripped.contains('FEC_Case_Status__c')) ? null : c.FEC_Case_Status__c;
            row.accountContractNumber = pop.containsKey('FEC_Account_or_Contract__c') && c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null;
            row.productTypeId = (stripped != null && stripped.contains('FEC_Product_Type__c')) ? null : c.FEC_Product_Type__c;
            row.productType = pop.containsKey('FEC_Product_Type__c') && c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
            row.category = pop.containsKey('FEC_Category__c') && c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
            row.subCategory = pop.containsKey('FEC_SubCategory__c') && c.FEC_SubCategory__r != null ? c.FEC_SubCategory__r.FEC_Name_VN__c : null;
            row.subCode = pop.containsKey('FEC_SubCode__c') && c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Name_VN__c : null;
            row.interactionId = (stripped != null && stripped.contains('FEC_Interaction__c')) ? null : c.FEC_Interaction__c;
            row.interactionIdText = pop.containsKey('FEC_Interaction__c') && c.FEC_Interaction__r != null ? c.FEC_Interaction__r.FEC_ID_Search__c : null;
            row.channel = (stripped != null && stripped.contains('FEC_Channel__c')) ? null : c.FEC_Channel__c;
            row.interactionSubChannel = (stripped != null && stripped.contains('FEC_Interaction_Subchannel__c')) ? null : c.FEC_Interaction_Subchannel__c;
            row.caseCreatedOn = (stripped != null && stripped.contains('FEC_Case_Created_On__c')) ? null : c.FEC_Case_Created_On__c;
            row.caseCreatedBy = (stripped != null && stripped.contains('FEC_Case_Created_By__c')) ? null : c.FEC_Case_Created_By__c;
            row.lastUpdatedOn = (stripped != null && stripped.contains('FEC_Last_Updated_On_View__c')) ? null : c.FEC_Last_Updated_On_View__c;
            row.lastUpdatedBy = (stripped != null && stripped.contains('FEC_Last_Updated_By_View__c')) ? null : c.FEC_Last_Updated_By_View__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static List<ClosedCaseRow> getClosedServiceCases(Id recordId) {
        if (!Schema.sObjectType.Case.isAccessible()) {
            return new List<ClosedCaseRow>();
        }
        CustomerFilterContext filterCtx = resolveCustomerFilterContext(recordId);
        if (filterCtx == null) {
            return new List<ClosedCaseRow>();
        }
        List<String> rtNames = new List<String>{
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };
        List<String> resolvedStatuses = RESOLVED_SERVICE_CASE_STATUSES;
        String filterAccountContractName = filterCtx.accountContractName;
        List<String> filterNationalIds = filterCtx.nationalIds;
        //DateTime archiveThreshold = DateTime.now().addMonths(-3);
        String soql =
            'SELECT Id, FEC_ID_Search__c, FEC_Case_Status__c, ' +
            'FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Product_Type__c, FEC_Product_Type__r.Name, ' +
            'FEC_Category__r.Name, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Name_VN__c, ' +
            'FEC_Interaction__c, FEC_Interaction__r.FEC_ID_Search__c, ' +
            'FEC_Channel__c, FEC_Interaction_Subchannel__c, ' +
            'FEC_Case_Created_On__c, FEC_Case_Created_By__c, ' +
            'FEC_Last_Updated_On_View__c, FEC_Last_Updated_By_View__c ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN :rtNames AND FEC_Case_Status__c IN :resolvedStatuses ';
        soql += buildCustomerFilterClause(filterCtx);
        //'AND (ClosedDate = null OR ClosedDate >= :archiveThreshold) ' +
        soql += 'ORDER BY FEC_Case_Created_On__c DESC NULLS LAST';
        List<Case> cases = new List<Case>();
        try {
            cases = Database.query(soql);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.READABLE,
            cases
        );
        cases = (List<Case>) decision.getRecords();
        Set<String> stripped = decision.getRemovedFields().get('Case');
        List<ClosedCaseRow> rows = new List<ClosedCaseRow>();
        for (Case c : cases) {
            ClosedCaseRow row = new ClosedCaseRow();
            Map<String, Object> pop = c.getPopulatedFieldsAsMap();
            row.caseId = c.Id;
            row.caseIdText = (stripped != null && stripped.contains('FEC_ID_Search__c')) ? FEC_ConstantCommon.STR_EMPTY : (c.FEC_ID_Search__c != null ? c.FEC_ID_Search__c : FEC_ConstantCommon.STR_EMPTY);
            row.caseStatus = (stripped != null && stripped.contains('FEC_Case_Status__c')) ? null : c.FEC_Case_Status__c;
            row.accountContractNumber = pop.containsKey('FEC_Account_or_Contract__c') && c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null;
            row.productTypeId = (stripped != null && stripped.contains('FEC_Product_Type__c')) ? null : c.FEC_Product_Type__c;
            row.productType = pop.containsKey('FEC_Product_Type__c') && c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
            row.category = pop.containsKey('FEC_Category__c') && c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
            row.subCategory = pop.containsKey('FEC_SubCategory__c') && c.FEC_SubCategory__r != null ? c.FEC_SubCategory__r.FEC_Name_VN__c : null;
            row.subCode = pop.containsKey('FEC_SubCode__c') && c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Name_VN__c : null;
            row.interactionId = (stripped != null && stripped.contains('FEC_Interaction__c')) ? null : c.FEC_Interaction__c;
            row.interactionIdText = pop.containsKey('FEC_Interaction__c') && c.FEC_Interaction__r != null ? c.FEC_Interaction__r.FEC_ID_Search__c : null;
            row.channel = (stripped != null && stripped.contains('FEC_Channel__c')) ? null : c.FEC_Channel__c;
            row.interactionSubChannel = (stripped != null && stripped.contains('FEC_Interaction_Subchannel__c')) ? null : c.FEC_Interaction_Subchannel__c;
            row.caseCreatedOn = (stripped != null && stripped.contains('FEC_Case_Created_On__c')) ? null : c.FEC_Case_Created_On__c;
            row.caseCreatedBy = (stripped != null && stripped.contains('FEC_Case_Created_By__c')) ? null : c.FEC_Case_Created_By__c;
            row.lastUpdatedOn = (stripped != null && stripped.contains('FEC_Last_Updated_On_View__c')) ? null : c.FEC_Last_Updated_On_View__c;
            row.lastUpdatedBy = (stripped != null && stripped.contains('FEC_Last_Updated_By_View__c')) ? null : c.FEC_Last_Updated_By_View__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseFieldHelpTexts() {
        return FEC_CommonUltils.buildHelpTextMap(Case.SObjectType);
    }

    @TestVisible
    public static CustomerFilterContext resolveCustomerFilterContext(Id recordId) {
        if (recordId == null) {
            return null;
        }
        List<Case> ctxCases = [
            SELECT FEC_Account_or_Contract__c,
                   FEC_Account_or_Contract__r.Id,
                   FEC_Account_or_Contract__r.Name,
                   FEC_Account_or_Contract__r.FEC_Account_Number__c,
                   FEC_Account_or_Contract__r.FEC_Contract_Number__c,
                   FEC_Account_or_Contract__r.FEC_Customer_Type__c,
                   FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c
            FROM Case
            WHERE Id = :recordId
            LIMIT 1
        ];
        if (ctxCases.isEmpty() || ctxCases[0].FEC_Account_or_Contract__c == null) {
            return null;
        }
        Case ctx = ctxCases[0];
        String historyName = resolveHistoryAccountContractName(ctx.FEC_Account_or_Contract__r);

        CustomerFilterContext result = new CustomerFilterContext();
        if (String.isNotBlank(historyName)) {
            result.accountContractName = historyName;
            return result;
        }

        String searchResultNationalId = ctx.FEC_Account_or_Contract__r != null
            ? ctx.FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c
            : null;
        List<String> parsedNationalIds = FEC_CommonUltils.parseSearchResultNationalIds(searchResultNationalId);
        if (!parsedNationalIds.isEmpty()) {
            result.nationalIds = parsedNationalIds;
            return result;
        }
        return null;
    }

    @TestVisible
    private static String resolveHistoryAccountContractName(FEC_Customer_History__c history) {
        if (history == null) {
            return null;
        }
        String historyNameRaw = history.Name;
        if (String.isBlank(historyNameRaw)) {
            return null;
        }
        String historyName = historyNameRaw.trim();
        if (historyName.equalsIgnoreCase(FEC_ConstantCommon.PRODUCT_NON_EXISTING_CUSTOMER)) {
            return null;
        }
        if (isCustomerHistoryAutoName(historyName, history.Id)) {
            return null;
        }
        if (FEC_ConstantCommon.CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER.equalsIgnoreCase(history.FEC_Customer_Type__c)) {
            return null;
        }
        String accountNumber = history.FEC_Account_Number__c;
        String contractNumber = history.FEC_Contract_Number__c;
        if (String.isNotBlank(accountNumber) && historyName.equals(accountNumber.trim())) {
            return historyName;
        }
        if (String.isNotBlank(contractNumber) && historyName.equals(contractNumber.trim())) {
            return historyName;
        }
        if (FEC_CommonUltils.isValidAccountNumber(historyName)) {
            return historyName;
        }
        if (String.isBlank(accountNumber) && String.isBlank(contractNumber)) {
            return historyName;
        }
        return null;
    }

    @TestVisible
    private static Boolean isCustomerHistoryAutoName(String historyName, Id historyId) {
        if (String.isBlank(historyName) || historyId == null) {
            return false;
        }
        String trimmed = historyName.trim();
        String historyId18 = String.valueOf(historyId);
        if (trimmed == historyId18) {
            return true;
        }
        if (historyId18.length() == 18 && trimmed == historyId18.substring(0, 15)) {
            return true;
        }
        return false;
    }

    @TestVisible
    public static String buildCustomerFilterClause(CustomerFilterContext filterCtx) {
        if (filterCtx == null) {
            return 'AND Id = null ';
        }
        if (String.isNotBlank(filterCtx.accountContractName)) {
            return 'AND (FEC_Account_Number__c = :filterAccountContractName ' +
                'OR FEC_Contract_Number__c = :filterAccountContractName ' +
                'OR FEC_Account_or_Contract__r.FEC_Account_Number__c = :filterAccountContractName ' +
                'OR FEC_Account_or_Contract__r.FEC_Contract_Number__c = :filterAccountContractName ' +
                'OR FEC_Account_Contract_Number_Text__c = :filterAccountContractName) ';
        }
        if (filterCtx.nationalIds != null && !filterCtx.nationalIds.isEmpty()) {
            String clause = 'AND (FEC_National_ID_Passport_ID__c IN :filterNationalIds ' +
                'OR FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c IN :filterNationalIds ';
            for (String nationalId : filterCtx.nationalIds) {
                if (String.isBlank(nationalId)) {
                    continue;
                }
                String escapedNationalId = String.escapeSingleQuotes(nationalId.trim());
                clause += 'OR FEC_Account_or_Contract__r.FEC_Search_Result_National_ID__c LIKE \'%' + escapedNationalId + '%\' ';
                clause += 'OR FEC_Search_National_ID__c LIKE \'%' + escapedNationalId + '%\' ';
            }
            clause += ') ';
            return clause;
        }
        return 'AND Id = null ';
    }

    public class PendingCaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseIdText;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public String accountContractNumber;
        @AuraEnabled public Id productTypeId;
        @AuraEnabled public String productType;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String subCode;
        @AuraEnabled public Id interactionId;
        @AuraEnabled public String interactionIdText;
        @AuraEnabled public String channel;
        @AuraEnabled public String interactionSubChannel;
        @AuraEnabled public DateTime caseCreatedOn;
        @AuraEnabled public String caseCreatedBy;
        @AuraEnabled public DateTime lastUpdatedOn;
        @AuraEnabled public String lastUpdatedBy;
    }

    public class ClosedCaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseIdText;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public String accountContractNumber;
        @AuraEnabled public Id productTypeId;
        @AuraEnabled public String productType;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String subCode;
        @AuraEnabled public Id interactionId;
        @AuraEnabled public String interactionIdText;
        @AuraEnabled public String channel;
        @AuraEnabled public String interactionSubChannel;
        @AuraEnabled public DateTime caseCreatedOn;
        @AuraEnabled public String caseCreatedBy;
        @AuraEnabled public DateTime lastUpdatedOn;
        @AuraEnabled public String lastUpdatedBy;
    }
}
