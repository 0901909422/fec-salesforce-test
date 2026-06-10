public without sharing class FEC_GetInteractionCases {

    /**
     * Returns all non-archived Interaction records (Case with RecordType = Interaction).
     */
    @AuraEnabled
    public static List<InteractionRow> getAllInteractions(Id recordId) {
        if (!Schema.sObjectType.Case.isAccessible()) {
            return new List<InteractionRow>();
        }
        FEC_GetServiceCases.CustomerFilterContext filterCtx =
            FEC_GetServiceCases.resolveCustomerFilterContext(recordId);
        if (filterCtx == null) {
            return new List<InteractionRow>();
        }
        String filterAccountNumber = filterCtx.accountNumber;
        String filterContractNumber = filterCtx.contractNumber;
        String filterNationalId = filterCtx.nationalId;
        //DateTime archiveThreshold = DateTime.now().addMonths(-3);
        List<String> rtNames = new List<String>{
            FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
        };
        String soql =
            'SELECT Id, FEC_ID_Search__c, FEC_Interaction_Status__c, FEC_Created_On__c, ' +
            'FEC_Created_by__c, FEC_Interaction_Duration__c, FEC_Phone_Number__c, ' +
            'FEC_Channel__c, FEC_Interaction_Subchannel__c, FEC_External_Interaction_ID__c, ' +
            'FEC_Interaction_Email__c, FEC_Last_Updated_On_View__c, FEC_Last_Updated_By_View__c ' +
            'FROM Case ' +
            'WHERE RecordType.DeveloperName IN :rtNames ';
        soql += FEC_GetServiceCases.buildCustomerFilterClause(
            filterCtx,
            filterAccountNumber,
            filterContractNumber,
            filterNationalId
        );
        //'AND (IsClosed = false OR ClosedDate >= :archiveThreshold) ' +
        soql += 'ORDER BY FEC_Created_On__c DESC NULLS LAST';
        List<Case> cases = new List<Case>();
        try {
            cases = Database.query(soql);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        // FLS: CRUD checked above. Skip stripInaccessible to avoid FLS issues in scratch org.
        Set<String> stripped = null;
        List<InteractionRow> rows = new List<InteractionRow>();
        for (Case c : cases) {
            InteractionRow row = new InteractionRow();
            row.interactionId = c.Id;
            row.interactionIdText = (stripped != null && stripped.contains('FEC_ID_Search__c')) ? FEC_ConstantCommon.STR_EMPTY : (c.FEC_ID_Search__c != null ? c.FEC_ID_Search__c : FEC_ConstantCommon.STR_EMPTY);
            row.interactionStatus = (stripped != null && stripped.contains('FEC_Interaction_Status__c')) ? null : c.FEC_Interaction_Status__c;
            row.interactionCreatedOn = (stripped != null && stripped.contains('FEC_Created_On__c')) ? null : c.FEC_Created_On__c;
            row.interactionCreatedBy = (stripped != null && stripped.contains('FEC_Created_by__c')) ? FEC_ConstantCommon.STR_EMPTY : (c.FEC_Created_by__c != null ? String.valueOf(c.FEC_Created_by__c) : FEC_ConstantCommon.STR_EMPTY);
            row.interactionDuration = (stripped != null && stripped.contains('FEC_Interaction_Duration__c')) ? FEC_ConstantCommon.STR_EMPTY : (c.FEC_Interaction_Duration__c != null ? String.valueOf(c.FEC_Interaction_Duration__c) : FEC_ConstantCommon.STR_EMPTY);
            row.interactionPhone = (stripped != null && stripped.contains('FEC_Phone_Number__c')) ? null : c.FEC_Phone_Number__c;
            row.channel = (stripped != null && stripped.contains('FEC_Channel__c')) ? null : c.FEC_Channel__c;
            row.interactionSubChannel = (stripped != null && stripped.contains('FEC_Interaction_Subchannel__c')) ? null : c.FEC_Interaction_Subchannel__c;
            row.externalInteractionId = (stripped != null && stripped.contains('FEC_External_Interaction_ID__c')) ? null : c.FEC_External_Interaction_ID__c;
            row.interactionEmail = (stripped != null && stripped.contains('FEC_Interaction_Email__c')) ? null : c.FEC_Interaction_Email__c;
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

    public class InteractionRow {
        @AuraEnabled public Id interactionId;
        @AuraEnabled public String interactionIdText;
        @AuraEnabled public String interactionStatus;
        @AuraEnabled public DateTime interactionCreatedOn;
        @AuraEnabled public String interactionCreatedBy;
        @AuraEnabled public String interactionDuration;
        @AuraEnabled public String interactionPhone;
        @AuraEnabled public String channel;
        @AuraEnabled public String interactionSubChannel;
        @AuraEnabled public String externalInteractionId;
        @AuraEnabled public String interactionEmail;
        @AuraEnabled public DateTime lastUpdatedOn;
        @AuraEnabled public String lastUpdatedBy;
    }
}
