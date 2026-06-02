/**
 * Controller for fecIntegrationManageFraudCase LWC.
 * 
 * Responsibilities:
 * 1. Determine actionMode (CreateMode / EditMode / ViewMode) based on fraud case status
 * 2. Load shared initial data for both Create and Update modes
 */
public with sharing class FEC_IntegrationManageFraudCaseCtrl {

    public static final Boolean DEBUG_LOG = true;

    /**
     * DTO returned to the LWC wrapper component.
     */
    public class ManageFraudCaseDTO {
        @AuraEnabled public String actionMode;
        @AuraEnabled public String fraudCaseId;
        @AuraEnabled public String serviceCaseId;
        @AuraEnabled public String natureOfCaseId;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public String integrateMappingId;
        @AuraEnabled public Map<String, Object> caseData;
    }

    /**
     * Determines the action mode and loads initial shared data.
     *
     * Logic:
     * - No FEC_Integration_Case__c found for serviceCaseId → CreateMode
     * - Exists with status Canceled or End → ViewMode
     * - Exists with any other status → EditMode
     *
     * @param serviceCaseId  The service case identifier
     * @param natureOfCaseId The nature of case Id
     * @return ManageFraudCaseDTO containing actionMode and shared data
     */
    @AuraEnabled
    public static ManageFraudCaseDTO initManageFraudCase(String serviceCaseId, String natureOfCaseId) {
        //log('[getAllValueCaseInfoByCaseId] serviceCaseId=' + serviceCaseId + ' | natureOfCaseId=' + natureOfCaseId);
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        ManageFraudCaseDTO dto = new ManageFraudCaseDTO();        
        dto.natureOfCaseId = natureOfCaseId;
        Boolean isConfigFraudIntegrate = false;

        if (String.isBlank(serviceCaseId)) {
            dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_CREATE_MODE;
            return dto;
        }

        // Step 1: Get FEC_ID_Search__c from Case
        Case cs = [
            SELECT FEC_ID_Search__c FROM Case WHERE Id = :serviceCaseId LIMIT 1
        ];

        // Step 2: Query fraud case
        String canceledStatus = FEC_FraudConstantCommon.CANCELED;
        List<FEC_Integration_Case__c> existing = [
            SELECT Id,
                   FEC_CaseID__c,
                   FEC_Case_Status__c,
                   FEC_Service_Case_ID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_Service_Case_ID__c = :cs.FEC_ID_Search__c
            AND FEC_Case_Status__c != :canceledStatus
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        dto.serviceCaseId = cs.FEC_ID_Search__c;

        if (existing.isEmpty()) {
            dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_CREATE_MODE;
            log('[initManageFraudCase] No fraud case found → CreateMode');
        } else {
            FEC_Integration_Case__c fraudCase = existing[0];
            isConfigFraudIntegrate = true;
            dto.fraudCaseId = fraudCase.FEC_CaseID__c;
            dto.caseStatus = fraudCase.FEC_Case_Status__c;
            Boolean isNotAllow = (fraudCase.FEC_CaseID__c != null && fraudCase.FEC_CaseID__c.startsWith(caseField.CASEFH))
            ? true: false;

            if (!isNotAllow) {
                dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_SUBMIT_MODE;
            }else if(isNotAllow && (fraudCase.FEC_Case_Status__c == FEC_FraudConstantCommon.CS_UPDATING
                || fraudCase.FEC_Case_Status__c == FEC_FraudConstantCommon.PROVIDE_INFORMATION)) {
                dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_EDIT_MODE;
            } else {
                dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_VIEW_MODE;
            }

            log('[initManageFraudCase] Fraud case found → ' + dto.actionMode
                + ' | status=' + dto.caseStatus);
        }

        // Load shared case data
        dto.caseData = getAllValueCaseInfoByCaseId(
            getCaseIdFromServiceCaseId(serviceCaseId)
        );
        //Check Not config Fraud Integration
        if(!isConfigFraudIntegrate) {
             // Resolve Integration Mapping Id from Nature Of Case
            dto.integrateMappingId = getIntegrateMappingIdByNatureOfCase(natureOfCaseId);
            if(String.isBlank(dto.integrateMappingId)) {
                dto.actionMode = FEC_FraudConstantCommon.INTEGRATING_FRAUD_NOTMAPPING_MODE;
            }
        }
       

        return dto;
    }

    @AuraEnabled
    public static Map<String, String> getCaseToFraudFieldMap(String natureOfCaseId, String serviceCaseId) {
        Map<String, String> result = new Map<String, String>();
        String integrateMappingId = getIntegrateMappingIdByNatureOfCase(natureOfCaseId);
        
        // Fallback: if no mapping found by natureOfCaseId, try from Case's Actual Nature of Case
        if (String.isBlank(integrateMappingId) && String.isNotBlank(serviceCaseId)) {
            List<Case> cases = [
                SELECT FEC_Actual_Nature_of_Case__c
                FROM Case
                WHERE Id = :serviceCaseId
                LIMIT 1
            ];
            if (!cases.isEmpty() && cases[0].FEC_Actual_Nature_of_Case__c != null) {
                integrateMappingId = getIntegrateMappingIdByNatureOfCase(cases[0].FEC_Actual_Nature_of_Case__c);
            }
        }

        if (String.isBlank(integrateMappingId)) {
            return result;
        }

        // Step 1: Get mapping info records        
        List<FEC_Data_Integration_Mapping_Info__c> mappingInfos = [
            SELECT Id,
                FEC_Auto_Mapping_Property__c,
                FEC_CSM_Property__c,
                FEC_CSM_Property_Type__c,
                FEC_Data_Integration_Mapping__c,
                FEC_Integrating_Property__c,
                FEC_Integrating_Property_Type__c,
                FEC_Mandatory__c,
                FEC_Auto_Mapping_Property_Source__c
            FROM FEC_Data_Integration_Mapping_Info__c           
            WHERE FEC_Data_Integration_Mapping__c = :integrateMappingId 
             AND (
                FEC_CSM_Property__c != null 
                OR FEC_Auto_Mapping_Property_Source__c != null
            )
        ];

        if (mappingInfos.isEmpty()) {
            return result;
        }

        for (FEC_Data_Integration_Mapping_Info__c info : mappingInfos) {
            String caseField = String.isNotBlank(info.FEC_Auto_Mapping_Property_Source__c)
                ? info.FEC_Auto_Mapping_Property_Source__c
                : info.FEC_CSM_Property__c;
            // Map: Case field → Fraud (Integrating) field
            result.put(caseField, info.FEC_Integrating_Property__c);
        }
        
        return result;
    }

    private static Map<String, Object> getAllValueCaseInfoByCaseId(Id caseId) {

        Map<String, Object> result = new Map<String, Object>();

        if (caseId == null) {
            return result;
        }

        // Get all accessible fields on Case
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        List<String> fieldNames = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (dfr.isAccessible()) {
                fieldNames.add(dfr.getName());
            }
        }

        if (fieldNames.isEmpty()) {
            return result;
        }

        // Build and execute dynamic SOQL
        String soql = 'SELECT ' + String.join(fieldNames, ', ')
                     + ' FROM Case WHERE Id = :caseId LIMIT 1';

        List<SObject> records = Database.query(soql);

        if (records.isEmpty()) {
            return result;
        }

        // Convert SObject to Map
        SObject rec = records[0];
        for (String fieldName : fieldNames) {
            result.put(fieldName, rec.get(fieldName));
        }

        log('[getAllValueCaseInfoByCaseId] caseId=' + caseId + ' | fields=' + result.size());
        return result;
    }

    /**
     * Resolves the Salesforce Case Id from a service case identifier.
     */
    private static Id getCaseIdFromServiceCaseId(String serviceCaseId) {
        if (String.isBlank(serviceCaseId)) {
            return null;
        }
        List<Case> cases = [
            SELECT Id FROM Case WHERE Id = :serviceCaseId LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0].Id;
    }

    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }

    /**
     * Resolves the Integration Mapping Id from a Nature Of Case Id.
     */
    private static String getIntegrateMappingIdByNatureOfCase(String natureOfCaseId) {
        if (String.isBlank(natureOfCaseId)) {
            return null;
        }
        List<FEC_Master_Data_Setting__c> mappings = [
            SELECT FEC_Data_Integration_Mapping__c
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
              AND FEC_Field_Status__c = true
              AND FEC_Data_Integration_Mapping__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!mappings.isEmpty()) {
            log('[getIntegrateMappingIdByNatureOfCase] Found mappingId=' + mappings[0].FEC_Data_Integration_Mapping__c);
            return mappings[0].FEC_Data_Integration_Mapping__c;
        }
        log('[getIntegrateMappingIdByNatureOfCase] No mapping found for natureOfCaseId=' + natureOfCaseId);
        return null;
    }
}