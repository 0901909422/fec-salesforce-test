global with sharing class FEC_IntegrationFraudCaseDetailController {

    public static final Boolean DEBUG_LOG = true;
    public static final String userLang = UserInfo.getLanguage();
    private static final String ERR_CASEID_REQUIRED = System.Label.LBL_CaseIdRequired;
    private static final String ERR_ROOT_NOT_FOUND  = System.Label.LBL_RootCaseNotFound;


    /**
     * Retrieves detailed information of a Fraud Case by Case ID.
     *
     * This method is exposed to LWC and is cacheable for better performance.
     * It acts as a public API wrapper that delegates the actual business logic
     * to the internal service method.
     *
     * @param caseId  The Fraud Case ID to retrieve information for
     * @return        A map containing Fraud Case details and related data
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFraudCaseDetail(String caseId) {
        return getFraudHandlingCaseDetail(caseId);
    }

    /**
     * Retrieves full Fraud Case details and builds the complete case hierarchy.
     *
     * This method loads and constructs the Fraud Case structure in the following order:
     *   1. Root case (FH-*)
     *   2. Business unit cases (BU-*)
     *   3. Task cases (TK-*)
     *
     * It then:
     *   • Builds the hierarchical tree: FH → BU → TK
     *   • Loads all related information records (FEC_Integration_Case_Info__c)
     *   • Constructs a task list from TK cases only
     *   • Formats all data into a UI-ready response structure
     *
     * The final response contains:
     *   - "hierarchy": ordered case hierarchy with full case and info details
     *   - "tasks": list of TK tasks with display fields and hyperlinks
     *
     * @param  caseId   The root Fraud Case ID (expected format: FH-*)
     * @return          A map containing:
     *                    • hierarchy → structured case data
     *                    • tasks     → list of task objects
     *
     * @throws AuraHandledException if caseId is blank or root case cannot be found
     */
    private static Map<String, Object> getFraudHandlingCaseDetail(String caseId) {

        log('==============================');
        log('[START] getFraudCaseDetail');
        log('Input caseId = ' + caseId);
        log('==============================');
        FEC_IntegrationFraudCaseUtil.IntegrationField caseField = new FEC_IntegrationFraudCaseUtil.IntegrationField();

        if (String.isBlank(caseId)) {
            throw new AuraHandledException(ERR_CASEID_REQUIRED);
        }

        // =====================================================
        // 1) LOAD ROOT (FH) + BU
        // =====================================================
        log('Query ROOT + BU cases');

        List<FEC_Integration_Case__c> rootAndBu = [
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

        log('rootAndBu size = ' + rootAndBu.size());

        // =====================================================
        // 2) COLLECT BU CASE IDs
        // =====================================================
        Set<String> buCaseIds = new Set<String>();
        FEC_Integration_Case__c rootCase;

        for (FEC_Integration_Case__c c : rootAndBu) {
            if (c.FEC_CaseID__c == caseId) {
                rootCase = c;
            } else if (c.FEC_Parent_CaseID__c == caseId) {
                buCaseIds.add(c.FEC_CaseID__c);
            }
        }

        if (rootCase == null) {
            throw new AuraHandledException(ERR_ROOT_NOT_FOUND + ': ' + caseId);
        }

        log('BU CaseIDs = ' + buCaseIds);

        // =====================================================
        // 3) LOAD TK (CHILDREN OF BU)
        // =====================================================
        List<FEC_Integration_Case__c> tkCases = new List<FEC_Integration_Case__c>();

        if (!buCaseIds.isEmpty()) {
            log('Query TK cases');

            tkCases = [
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

        log('tkCases size = ' + tkCases.size());

        // =====================================================
        // 4) BUILD HIERARCHY (FH → BU → TK)
        // =====================================================
        List<FEC_Integration_Case__c> hierarchy = new List<FEC_Integration_Case__c>();
        hierarchy.add(rootCase);

        for (FEC_Integration_Case__c bu : rootAndBu) {
            if (bu.FEC_Parent_CaseID__c == caseId) {
                hierarchy.add(bu);

                for (FEC_Integration_Case__c tk : tkCases) {
                    if (tk.FEC_Parent_CaseID__c == bu.FEC_CaseID__c) {
                        hierarchy.add(tk);
                    }
                }
            }
        }

        log('Hierarchy order:');
        for (FEC_Integration_Case__c c : hierarchy) {
            log('   • ' + c.FEC_CaseID__c);
        }

        // =====================================================
        // 5) LOAD ALL INFO RECORDS FOR HIERARCHY
        // =====================================================
        log('Query FEC_Integration_Case_Info__c');

        Map<Id, List<FEC_Integration_Case_Info__c>> infoByCaseId =
            new Map<Id, List<FEC_Integration_Case_Info__c>>();

        List<FEC_Integration_Case_Info__c> infoRecords = [
            SELECT Id,
                FEC_Info_ID__c,
                FEC_Info_Value__c,
                FEC_Parent_Case__c
            FROM FEC_Integration_Case_Info__c
            WHERE FEC_Parent_Case__c IN :hierarchy
            ORDER BY FEC_Parent_Case__c, FEC_Info_ID__c
        ];

        log('Info records size = ' + infoRecords.size());

        for (FEC_Integration_Case_Info__c inf : infoRecords) {
            if (!infoByCaseId.containsKey(inf.FEC_Parent_Case__c)) {
                infoByCaseId.put(inf.FEC_Parent_Case__c,
                    new List<FEC_Integration_Case_Info__c>());
            }
            infoByCaseId.get(inf.FEC_Parent_Case__c).add(inf);
        }

        // =====================================================
        // 6) BUILD TASK LIST (TK-* ONLY)
        // =====================================================
        log('Build task list');

        List<Map<String, Object>> taskList = new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {

            if (!c.FEC_CaseID__c.startsWith(caseField.CASETK)) continue;

            Map<String, String> taskInfoMap = new Map<String, String>();

            if (infoByCaseId.containsKey(c.Id)) {
                for (FEC_Integration_Case_Info__c inf : infoByCaseId.get(c.Id)) {
                    taskInfoMap.put(inf.FEC_Info_ID__c, inf.FEC_Info_Value__c);
                }
            }

            taskList.add(new Map<String, Object>{
                'Id'               => c.Id,
                'TaskId'           => c.FEC_CaseID__c,
                'FraudTaskId'      => c.FEC_Service_Case_ID__c,
                'InvestigationConclusion' => c.FEC_Investigation_Conclusion__c,
                'FraudTaskUrl'     => c.FEC_Service_Case_ID__c != null
                        ? '/lightning/n/Service_Fraud_Task_Case_Action?c__caseId=' + c.FEC_Service_Case_ID__c
                        : null,
                'TaskName'         => taskInfoMap.get('TaskName'),
                'UIC'              => taskInfoMap.get('UIC'),
                'AppId'            => taskInfoMap.get('AppID'),
                'ViolationType'    => taskInfoMap.get('ViolationType'),                
                'Status'           => c.FEC_Case_Status__c,
                'Deadline'         => FEC_IntegrationFraudCaseUtil.formatDDMMYYYY(taskInfoMap.get('Deadline')),
                'CreatedDate'      => FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate),
                'LastModifiedDate' => FEC_IntegrationFraudCaseUtil.formatDateTime(c.LastModifiedDate)
            });
        }

        log('📊 taskList size = ' + taskList.size());

        // =====================================================
        // 7) BUILD FINAL HIERARCHY RESPONSE
        // =====================================================
        List<Map<String, Object>> hierarchyResponse = new List<Map<String, Object>>();

        for (FEC_Integration_Case__c c : hierarchy) {

            List<Map<String, String>> infos = new List<Map<String, String>>();

            if (infoByCaseId.containsKey(c.Id)) {
                for (FEC_Integration_Case_Info__c inf : infoByCaseId.get(c.Id)) {
                    //FEC_Source_Id__c='ApproDoc' AND FEC_Source_Parent_Id__c='CC02-06'                    
                    List<FEC_Master_Data_Integration__c> exist = [
                        SELECT FEC_Source_Field_Type__c FROM FEC_Master_Data_Integration__c WHERE FEC_Source_Id__c = :inf.FEC_Info_ID__c LIMIT 1
                        //SELECT FEC_Source_Field_Type__c FROM FEC_Master_Data_Integration__c WHERE FEC_Source_Id__c = :inf.FEC_Info_ID__c AND FEC_Source_Parent_Id__c = :c.FEC_Sub_Code__c  LIMIT 1
                    ];
                    String fileType = null;
                    String fileName = null;                    
                    if (!exist.isEmpty()) {
                        fileType = exist[0].FEC_Source_Field_Type__c;
                    }
                    if (fileType == 'file' && String.isNotBlank(inf.FEC_Info_Value__c)) {

                        String rawValue = inf.FEC_Info_Value__c;
                    
                        Integer firstSep = rawValue.indexOf('|');
                        Integer secondSep = rawValue.indexOf('|', firstSep + 1);
                    
                        if (firstSep > -1 && secondSep > -1) {
                            fileName = rawValue.substring(0, firstSep);
                        }
                    }
                    infos.add(new Map<String, String>{
                        'id'    => inf.FEC_Info_ID__c,
                        'value' => inf.FEC_Info_Value__c,
                        'fileType' => fileType,
                        'fileName' => fileName
                    });
                }
            }

            hierarchyResponse.add(new Map<String, Object>{
                'Id'                     => c.Id,
                'FEC_CaseID__c'          => c.FEC_CaseID__c,
                'FEC_Parent_CaseID__c'   => c.FEC_Parent_CaseID__c,
                'FEC_Service_Case_ID__c' => c.FEC_Service_Case_ID__c,
                'FEC_Case_Status__c'     => c.FEC_Case_Status__c,
                'FEC_Category__c'        => c.FEC_Category__c,
                'FEC_Sub_Category__c'    => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'        => c.FEC_Sub_Code__c,
                'FEC_Remark__c'          => c.FEC_Remark__c,
                'FEC_CS_Remark__c'          => c.FEC_CS_Remark__c,                
                'FEC_Investigation_Conclusion__c' => c.FEC_Investigation_Conclusion__c,
                'FEC_Sys_Channel__c'     => c.FEC_Sys_Channel__c,
                'FEC_Creator_Email__c'   => c.FEC_Creator_Email__c,
                'CreatedDate'            => FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate),
                'LastModifiedDate'       => FEC_IntegrationFraudCaseUtil.formatDateTime(c.LastModifiedDate),
                'Infos'                  => infos
            });
        }

        log('[END] getFraudCaseDetail');

        return new Map<String, Object>{
            'hierarchy' => hierarchyResponse,
            'tasks'     => taskList
        };
    }
    
    /**
     * Writes a log message to the debug log if debugging is enabled.
     *
     * This method centralizes logging behavior and ensures that debug
     * messages are only printed when the DEBUG_LOG flag is set to true.
     * It helps control log noise and improves performance in production
     * environments by avoiding unnecessary debug statements.
     *
     * @param msg The message to be written to the debug log.
     */
    private static void log(String msg) {
        if (DEBUG_LOG) {
            System.debug(LoggingLevel.INFO, msg);
        }
    }
    
}