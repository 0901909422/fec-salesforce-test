public with sharing class FEC_GetServiceCases {

    private static final List<String> RESOLVED_SERVICE_CASE_STATUSES = new List<String>{
        FEC_ConstantCommon.CASE_STATUS_RESOLVED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
        FEC_ConstantCommon.CASE_STATUS_AUTO_CANCELLED,
        FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER
    };

    @AuraEnabled
    public static List<PendingCaseRow> getPendingServiceCases() {
        if (!Schema.sObjectType.Case.isAccessible()) {
            return new List<PendingCaseRow>();
        }
        List<String> rtNames = new List<String>{
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };
        List<String> resolvedStatuses = RESOLVED_SERVICE_CASE_STATUSES;
        String soql =
            'SELECT Id, FEC_ID_Search__c, FEC_Case_Status__c, ' +
            'FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Product_Type__c, FEC_Product_Type__r.Name, ' +
            'FEC_Category__r.Name, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Name_VN__c, ' +
            'FEC_Interaction__c, FEC_Interaction__r.FEC_ID_Search__c, ' +
            'FEC_Channel__c, FEC_Interaction_Subchannel__c, ' +
            'FEC_Case_Created_On__c, FEC_Case_Created_By__c, ' +
            'FEC_Last_Updated_On__c, FEC_Last_Updated_By__c ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN :rtNames AND IsClosed = false ' +
            'AND (FEC_Case_Status__c = null OR FEC_Case_Status__c NOT IN :resolvedStatuses) ' +
            'ORDER BY FEC_Case_Created_On__c DESC NULLS LAST';
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
        List<PendingCaseRow> rows = new List<PendingCaseRow>();
        for (Case c : cases) {
            PendingCaseRow row = new PendingCaseRow();
            row.caseId = c.Id;
            row.caseIdText = c.FEC_ID_Search__c != null ? c.FEC_ID_Search__c : FEC_ConstantCommon.STR_EMPTY;
            row.caseStatus = c.FEC_Case_Status__c;
            row.accountContractNumber = c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null;
            row.productTypeId = c.FEC_Product_Type__c;
            row.productType = c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
            row.category = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
            row.subCategory = c.FEC_SubCategory__r != null ? c.FEC_SubCategory__r.FEC_Name_VN__c : null;
            row.subCode = c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Name_VN__c : null;
            row.interactionId = c.FEC_Interaction__c;
            row.interactionIdText = c.FEC_Interaction__r != null ? c.FEC_Interaction__r.FEC_ID_Search__c : null;
            row.channel = c.FEC_Channel__c;
            row.interactionSubChannel = c.FEC_Interaction_Subchannel__c;
            row.caseCreatedOn = c.FEC_Case_Created_On__c;
            row.caseCreatedBy = c.FEC_Case_Created_By__c;
            row.lastUpdatedOn = c.FEC_Last_Updated_On__c;
            row.lastUpdatedBy = c.FEC_Last_Updated_By__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static List<ClosedCaseRow> getClosedServiceCases() {
        if (!Schema.sObjectType.Case.isAccessible()) {
            return new List<ClosedCaseRow>();
        }
        List<String> rtNames = new List<String>{
            FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME,
            FEC_ConstantCommon.CASE_INTERNAL_RECORD_TYPE_DEV_NAME
        };
        List<String> resolvedStatuses = RESOLVED_SERVICE_CASE_STATUSES;
        //DateTime archiveThreshold = DateTime.now().addMonths(-3);
        String soql =
            'SELECT Id, FEC_ID_Search__c, FEC_Case_Status__c, ' +
            'FEC_Account_or_Contract__r.FEC_Account_Number__c, FEC_Product_Type__c, FEC_Product_Type__r.Name, ' +
            'FEC_Category__r.Name, FEC_SubCategory__r.FEC_Name_VN__c, FEC_SubCode__r.FEC_Name_VN__c, ' +
            'FEC_Interaction__c, FEC_Interaction__r.FEC_ID_Search__c, ' +
            'FEC_Channel__c, FEC_Interaction_Subchannel__c, ' +
            'FEC_Case_Created_On__c, FEC_Case_Created_By__c, ' +
            'FEC_Last_Updated_On__c, FEC_Last_Updated_By__c ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN :rtNames AND FEC_Case_Status__c IN :resolvedStatuses ' +
            //'AND (ClosedDate = null OR ClosedDate >= :archiveThreshold) ' +
            'ORDER BY FEC_Case_Created_On__c DESC NULLS LAST';
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
        List<ClosedCaseRow> rows = new List<ClosedCaseRow>();
        for (Case c : cases) {
            ClosedCaseRow row = new ClosedCaseRow();
            row.caseId = c.Id;
            row.caseIdText = c.FEC_ID_Search__c != null ? c.FEC_ID_Search__c : FEC_ConstantCommon.STR_EMPTY;
            row.caseStatus = c.FEC_Case_Status__c;
            row.accountContractNumber = c.FEC_Account_or_Contract__r != null ? c.FEC_Account_or_Contract__r.FEC_Account_Number__c : null;
            row.productTypeId = c.FEC_Product_Type__c;
            row.productType = c.FEC_Product_Type__r != null ? c.FEC_Product_Type__r.Name : null;
            row.category = c.FEC_Category__r != null ? c.FEC_Category__r.Name : null;
            row.subCategory = c.FEC_SubCategory__r != null ? c.FEC_SubCategory__r.FEC_Name_VN__c : null;
            row.subCode = c.FEC_SubCode__r != null ? c.FEC_SubCode__r.FEC_Name_VN__c : null;
            row.interactionId = c.FEC_Interaction__c;
            row.interactionIdText = c.FEC_Interaction__r != null ? c.FEC_Interaction__r.FEC_ID_Search__c : null;
            row.channel = c.FEC_Channel__c;
            row.interactionSubChannel = c.FEC_Interaction_Subchannel__c;
            row.caseCreatedOn = c.FEC_Case_Created_On__c;
            row.caseCreatedBy = c.FEC_Case_Created_By__c;
            row.lastUpdatedOn = c.FEC_Last_Updated_On__c;
            row.lastUpdatedBy = c.FEC_Last_Updated_By__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCaseFieldHelpTexts() {
        return FEC_CommonUltils.buildHelpTextMap(Case.SObjectType);
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