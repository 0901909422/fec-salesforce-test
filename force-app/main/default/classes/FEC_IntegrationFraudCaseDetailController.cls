/**
 * Controller responsible for loading Fraud Case detail data
 * including hierarchy (Root → BU → TK), tasks, and case infos
 * for Lightning Web Components.
 */
global with sharing class FEC_IntegrationFraudCaseDetailController {

    /** Enable / disable debug logging centrally */
    public static final Boolean DEBUG_LOG = true;

    /** Current user language (can be used for localization later) */
    public static final String userLang = UserInfo.getLanguage();

    /** Error message when CaseId is missing */
    private static final String ERR_CASEID_REQUIRED = System.Label.LBL_CaseIdRequired;

    /** Error message when root case cannot be found */
    private static final String ERR_ROOT_NOT_FOUND  = System.Label.LBL_RootCaseNotFound;

    /**
     * Entry point for LWC.
     * Returns full fraud case detail including hierarchy and tasks.
     *
     * @param caseId Root case identifier
     * @return Map containing hierarchy and task list
     */
    @AuraEnabled(cacheable = true)
    public static Map<String, Object> getFraudCaseDetail(String caseId) {
        return getFraudHandlingCaseDetail(caseId);
    }

    /**
     * Returns mapping between case prefix and integration case field name.
     * Used by frontend to determine case type (FH, BU, TK, etc.).
     */
    @AuraEnabled(cacheable = true)
    public static Map<String, String> getCasePrefixes() {
        FEC_FraudConstantCommon.IntegrationField caseField =
            new FEC_FraudConstantCommon.IntegrationField();

        return new Map<String, String>{
            'FH'  => caseField.CASEFH,
            'TK'  => caseField.CASETK,
            'SFT' => caseField.CASESFT
        };
    }

    /**
     * Returns supported integration field data types.
     * Used by UI to render values correctly (file, text, date, etc.).
     */
    @AuraEnabled(cacheable = true)
    public static Map<String, String> getIntegrationFieldTypes() {
        FEC_FraudConstantCommon.IntegrationFieldType fieldType =
            new FEC_FraudConstantCommon.IntegrationFieldType();

        return new Map<String, String>{
            'FILE'     => fieldType.TYPE_FILE,
            'TEXT'     => fieldType.TYPE_TEXT,
            'STRING'   => fieldType.TYPE_STRING,
            'NUMBER'   => fieldType.TYPE_NUMBER,
            'DATE'     => fieldType.TYPE_DATE,
            'DATETIME' => fieldType.TYPE_DATETIME,
            'BOOLEAN'  => fieldType.TYPE_BOOLEAN,
            'OBJECT'   => fieldType.TYPE_OBJECT,
            'ARRAY'    => fieldType.TYPE_ARRAY
        };
    }

    /**
     * Core orchestration method.
     * - Validates input
     * - Loads root / BU / TK cases
     * - Builds hierarchy
     * - Loads case infos
     * - Prepares task list and response payload
     */
    private static Map<String, Object> getFraudHandlingCaseDetail(String caseId) {

        validateCaseId(caseId);

        FEC_FraudConstantCommon.IntegrationField caseField =
            new FEC_FraudConstantCommon.IntegrationField();
        FEC_FraudConstantCommon.IntegrationFieldType fileTypeConstant =
            new FEC_FraudConstantCommon.IntegrationFieldType();

        // Load root case and BU cases
        RootAndBuResult rootAndBu = loadRootAndBuCases(caseId);

        // Load TK cases under BU cases
        List<FEC_Integration_Case__c> tkCases =
            loadTkCases(rootAndBu.buCaseIds);

        // Build hierarchical order: Root → BU → TK
        List<FEC_Integration_Case__c> hierarchy =
            buildHierarchy(
                caseId,
                rootAndBu.rootCase,
                rootAndBu.allCases,
                tkCases
            );

        // Load info records grouped by case Id
        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId =
            loadCaseInfos(hierarchy);

        // Build list of TK tasks for UI
        List<Map<String, Object>> taskList =
            buildTaskList(hierarchy, infoByCaseId, caseField);

        // Build hierarchy response for UI
        List<Map<String, Object>> hierarchyResponse =
            buildHierarchyResponse(
                hierarchy,
                infoByCaseId,
                fileTypeConstant
            );

        log('[END] getFraudCaseDetail');

        return new Map<String, Object>{
            'hierarchy' => hierarchyResponse,
            'tasks'     => taskList
        };
    }

    /**
     * Validates that caseId is provided.
     * Throws AuraHandledException for LWC handling.
     */
    private static void validateCaseId(String caseId) {
        if (String.isBlank(caseId)) {
            throw new AuraHandledException(ERR_CASEID_REQUIRED);
        }
    }

    /**
     * Wrapper object holding:
     * - Root case
     * - BU case IDs
     * - All related cases
     */
    private class RootAndBuResult {
        FEC_Integration_Case__c rootCase;
        Set<String> buCaseIds = new Set<String>();
        List<FEC_Integration_Case__c> allCases;
    }

    /**
     * Loads root case and direct BU child cases.
     *
     * @param caseId Root case ID
     * @return RootAndBuResult with root + BU case data
     */
    private static RootAndBuResult loadRootAndBuCases(String caseId) {

        log('Query ROOT + BU cases');

        List<FEC_Integration_Case__c> records = [
            SELECT Id,
                   FEC_CaseID__c,
                   FEC_Parent_CaseID__c,
                   FEC_Service_Case_ID__c,
                   FEC_Case_Status__c,
                   FEC_Category__c,
                   FEC_Sub_Category__c,
                   FEC_Sub_Code__c,
                   FEC_Remark__c,
                   FEC_CS_Remark__c,
                   FEC_Investigation_Conclusion__c,
                   FEC_Sys_Channel__c,
                   FEC_Creator_Email__c,
                   CreatedDate,
                   LastModifiedDate
            FROM FEC_Integration_Case__c
            WHERE FEC_CaseID__c = :caseId
               OR FEC_Parent_CaseID__c = :caseId
            ORDER BY CreatedDate
        ];

        RootAndBuResult result = new RootAndBuResult();
        result.allCases = records;

        // Identify root and BU cases
        for (FEC_Integration_Case__c c : records) {
            if (c.FEC_CaseID__c == caseId) {
                result.rootCase = c;
            } else if (c.FEC_Parent_CaseID__c == caseId) {
                result.buCaseIds.add(c.FEC_CaseID__c);
            }
        }

        // Root case must exist
        if (result.rootCase == null) {
            throw new AuraHandledException(
                ERR_ROOT_NOT_FOUND + ': ' + caseId
            );
        }

        log('BU CaseIDs = ' + result.buCaseIds);
        return result;
    }

    /**
     * Loads TK cases that belong to BU cases.
     */
    private static List<FEC_Integration_Case__c> loadTkCases(Set<String> buCaseIds) {

        if (buCaseIds.isEmpty()) {
            return new List<FEC_Integration_Case__c>();
        }

        log('Query TK cases');

        return [
            SELECT Id,
                   FEC_CaseID__c,
                   FEC_Parent_CaseID__c,
                   FEC_Service_Case_ID__c,
                   FEC_Case_Status__c,
                   FEC_Category__c,
                   FEC_Sub_Category__c,
                   FEC_Sub_Code__c,
                   FEC_Remark__c,
                   FEC_CS_Remark__c,
                   FEC_Sys_Channel__c,
                   FEC_Creator_Email__c,
                   FEC_Investigation_Conclusion__c,
                   CreatedDate,
                   LastModifiedDate
            FROM FEC_Integration_Case__c
            WHERE FEC_Parent_CaseID__c IN :buCaseIds
            ORDER BY CreatedDate
        ];
    }

    /**
     * Builds ordered hierarchy list:
     * Root → BU → TK
     */
    private static List<FEC_Integration_Case__c> buildHierarchy(
        String rootCaseId,
        FEC_Integration_Case__c rootCase,
        List<FEC_Integration_Case__c> rootAndBu,
        List<FEC_Integration_Case__c> tkCases
    ) {
        List<FEC_Integration_Case__c> hierarchy =
            new List<FEC_Integration_Case__c>();

        hierarchy.add(rootCase);

        for (FEC_Integration_Case__c bu : rootAndBu) {
            if (bu.FEC_Parent_CaseID__c == rootCaseId) {
                hierarchy.add(bu);

                for (FEC_Integration_Case__c tk : tkCases) {
                    if (tk.FEC_Parent_CaseID__c == bu.FEC_CaseID__c) {
                        hierarchy.add(tk);
                    }
                }
            }
        }
        return hierarchy;
    }

    /**
     * Loads case info records and groups them by parent case Id.
     */
    private static Map<Id, List<FEC_Integration_Case_Info__c>>
        loadCaseInfos(List<FEC_Integration_Case__c> hierarchy) {

        log('Query FEC_Integration_Case_Info__c');

        Map<Id, List<FEC_Integration_Case_Info__c>> result =
            new Map<Id, List<FEC_Integration_Case_Info__c>>();

        List<FEC_Integration_Case_Info__c> infos = [
            SELECT Id,
                   FEC_Info_ID__c,
                   FEC_Info_Value__c,
                   FEC_Parent_Case__c
            FROM FEC_Integration_Case_Info__c
            WHERE FEC_Parent_Case__c IN :hierarchy
            ORDER BY FEC_Parent_Case__c, FEC_Info_ID__c
        ];

        for (FEC_Integration_Case_Info__c inf : infos) {
            if (!result.containsKey(inf.FEC_Parent_Case__c)) {
                result.put(
                    inf.FEC_Parent_Case__c,
                    new List<FEC_Integration_Case_Info__c>()
                );
            }
            result.get(inf.FEC_Parent_Case__c).add(inf);
        }
        return result;
    }

    /**
     * Builds task list from TK cases only.
     * Used for task panel in UI.
     */
    private static List<Map<String, Object>> buildTaskList(
        List<FEC_Integration_Case__c> hierarchy,
        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId,
        FEC_FraudConstantCommon.IntegrationField caseField
    ) {
        List<Map<String, Object>> tasks =
            new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {

            // Only TK cases are considered tasks
            if (!c.FEC_CaseID__c.startsWith(caseField.CASETK)) {
                continue;
            }
            Map<String, String> taskInfoMap = new Map<String, String>();

            if (infoByCaseId.containsKey(c.Id)) {
                for (FEC_Integration_Case_Info__c inf : infoByCaseId.get(c.Id)) {
                    taskInfoMap.put(inf.FEC_Info_ID__c, inf.FEC_Info_Value__c);
                }
            }

            tasks.add(new Map<String, Object>{
                FEC_FraudConstantCommon.KEY_ID =>
                    c.Id,
            
                FEC_FraudConstantCommon.KEY_TASK_ID =>
                    c.FEC_CaseID__c,
            
                FEC_FraudConstantCommon.KEY_FRAUD_TASK_ID =>
                    c.FEC_Service_Case_ID__c,
            
                FEC_FraudConstantCommon.KEY_INVESTIGATION_CONCLUSION =>
                    c.FEC_Investigation_Conclusion__c,
            
                FEC_FraudConstantCommon.KEY_FRAUD_TASK_URL =>
                    c.FEC_Service_Case_ID__c != null
                        ? FEC_FraudConstantCommon.SERVICE_CASE_LINK + c.FEC_Service_Case_ID__c
                        : null,
            
                FEC_FraudConstantCommon.TASK_NAME =>
                    taskInfoMap.get(FEC_FraudConstantCommon.TASK_NAME),
            
                FEC_FraudConstantCommon.INFO_UIC =>
                    taskInfoMap.get(FEC_FraudConstantCommon.INFO_UIC),
            
                FEC_FraudConstantCommon.INFO_APPLICATION_ID =>
                    taskInfoMap.get(FEC_FraudConstantCommon.INFO_APPLICATION_ID),
            
                FEC_FraudConstantCommon.INFO_VIOLATIONTYPE =>
                    taskInfoMap.get(FEC_FraudConstantCommon.INFO_VIOLATIONTYPE),
            
                FEC_FraudConstantCommon.KEY_STATUS =>
                    c.FEC_Case_Status__c,
            
                FEC_FraudConstantCommon.KEY_DEADLINE =>
                    FEC_IntegrationFraudCaseUtil.formatDDMMYYYY(
                        taskInfoMap.get(FEC_FraudConstantCommon.KEY_DEADLINE)
                    ),
            
                FEC_FraudConstantCommon.KEY_CREATED_DATE =>
                    FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate),
            
                FEC_FraudConstantCommon.KEY_LAST_MODIFIED_DATE =>
                    FEC_IntegrationFraudCaseUtil.formatDateTime(c.LastModifiedDate)
                    
            });
        }
            
        return tasks;
    }

    /**
     * Builds full hierarchy response with case info list.
     */
    private static List<Map<String, Object>> buildHierarchyResponse(
        List<FEC_Integration_Case__c> hierarchy,
        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId,
        FEC_FraudConstantCommon.IntegrationFieldType fileTypeConstant
    ) {
        List<Map<String, Object>> response =
            new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {
            response.add(new Map<String, Object>{
                'Id'                          => c.Id,
                'FEC_CaseID__c'               => c.FEC_CaseID__c,
                'FEC_Service_Case_ID__c'      => c.FEC_Service_Case_ID__c,
                'FEC_Case_Status__c'          => c.FEC_Case_Status__c,
                'FEC_Creator_Email__c'        => c.FEC_Creator_Email__c,
                'FEC_Category__c'             => c.FEC_Category__c,
                'FEC_Sub_Category__c'         => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'             => c.FEC_Sub_Code__c,
                'FEC_CS_Remark__c'            => c.FEC_CS_Remark__c,
                'FEC_Investigation_Conclusion__c'
                                             => c.FEC_Investigation_Conclusion__c,
                'CreatedDate'                 => c.CreatedDate,
                'LastModifiedDate'            => c.LastModifiedDate,
                'Infos'        => buildInfoList(
                    c,
                    infoByCaseId,
                    fileTypeConstant
                )
            });
        }
        return response;
    }

    /**
     * Builds info list for a case.
     * Handles file-type info parsing (file name extraction).
     */
    private static List<Map<String, String>> buildInfoList(
        FEC_Integration_Case__c caseRec,
        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId,
        FEC_FraudConstantCommon.IntegrationFieldType fileTypeConstant
    ) {
        List<Map<String, String>> infos =
            new List<Map<String, String>>();

        if (!infoByCaseId.containsKey(caseRec.Id)) {
            return infos;
        }

        for (FEC_Integration_Case_Info__c inf :
            infoByCaseId.get(caseRec.Id)) {

            String fileType;
            String fileName;

            // Determine field type from master data
            List<FEC_Master_Data_Integration__c> exist = [
                SELECT FEC_Source_Field_Type__c
                FROM FEC_Master_Data_Integration__c
                WHERE FEC_Source_Id__c = :inf.FEC_Info_ID__c
                LIMIT 1
            ];

            if (!exist.isEmpty()) {
                fileType = exist[0].FEC_Source_Field_Type__c;
            }

            // Extract file name if info represents a file
            if (fileType == fileTypeConstant.TYPE_FILE &&
                String.isNotBlank(inf.FEC_Info_Value__c)) {

                String rawValue = inf.FEC_Info_Value__c;
                Integer firstSep  = rawValue.indexOf('|');
                Integer secondSep = rawValue.indexOf('|', firstSep + 1);

                if (firstSep > -1 && secondSep > -1) {
                    fileName = rawValue.substring(0, firstSep);
                }
            }

            infos.add(new Map<String, String>{
                'id'        => inf.FEC_Info_ID__c,
                'value'     => inf.FEC_Info_Value__c,
                'fileType'  => fileType,
                'fileName'  => fileName
            });
        }
        return infos;
    }

    /**
     * Centralized logging helper.
     */
    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }
}