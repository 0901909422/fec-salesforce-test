global with sharing class FEC_IntegrationSearchFraudCaseController {

    public static final Boolean DEBUG_LOG = true;
    public static final String FRAUD_HANDLING_CASE_DETAIL_PATH = 'integration_fraud_handling_case_detail';
    

    /**
     * Searches fraud cases with flexible filtering, sorting, and pagination.
     *
     * This method acts as the public API endpoint for Lightning components.
     * It forwards all search parameters to the internal service method
     * `searchIntegrationFraudCase` and returns the result map in a
     * UI-friendly structure.
     *
     * @param fraudCaseId     Optional fraud case identifier filter
     * @param nationalId     Optional customer national ID filter
     * @param phoneNumber    Optional customer phone number filter
     * @param applicationId  Optional application ID filter
     * @param contractNumber Optional contract number filter
     * @param accountNumber  Optional account number filter
     * @param pageNumber     Page number for pagination (1-based)
     * @param pageSize       Number of records per page
     * @param sortBy         Field name used for sorting
     * @param sortDirection  Sort direction: ASC or DESC
     *
     * @return Map<String, Object> containing:
     *         - data  : List of fraud case records
     *         - total : Total number of matching records
     */
    @AuraEnabled(cacheable=false)
    public static Map<String,Object> searchFraudCases(
        String fraudCaseId,
        String nationalId,
        String phoneNumber,
        String applicationId,
        String contractNumber,
        String accountNumber,
        Integer pageNumber,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ) {
        Map<String,Object> results = new Map<String,Object>();
        results = searchIntegrationFraudCase(fraudCaseId, nationalId, phoneNumber, applicationId, contractNumber, accountNumber, pageNumber, pageSize, sortBy, sortDirection);
        return results;
    }


    /**
     * Performs a paginated, searchable, and sortable query of Fraud Cases
     * with support for filtering on both parent case fields and related
     * Additional Info records.
     *
     * This method is designed specifically for LWC data tables and provides:
     *  - Flexible filtering by case fields and AdditionalInfo values
     *  - Safe dynamic SOQL construction with strict sort field validation
     *  - Server-side paging logic
     *  - Data enrichment (Account Number from Additional Info)
     *  - UI-ready result structure
     *
     * Search behavior:
     *  1. Applies direct filters on parent case fields (e.g. Fraud Case ID).
     *  2. Applies Additional Info filters using SOQL + Apex text matching.
     *  3. Enforces business constraint: Case ID must start with 'FH-' or 'TK-'.
     *  4. Applies controlled sorting using a whitelist of allowed fields.
     *  5. Loads full result set, then slices results for paging.
     *  6. Enriches records with Account Number from Additional Info.
     *  7. Transforms records into UI-friendly maps for LWC consumption.
     *
     * @param fraudCaseId     Partial or full Fraud Case ID
     * @param nationalId     National ID filter (Additional Info)
     * @param phoneNumber    Phone number filter (Additional Info)
     * @param applicationId  Application ID filter (Additional Info)
     * @param contractNumber Contract number filter (Additional Info)
     * @param accountNumber  Account number filter (Additional Info)
     * @param pageNumber     Page number for pagination (1-based)
     * @param pageSize       Number of records per page
     * @param sortBy         Field name used for sorting (validated whitelist)
     * @param sortDirection  Sort direction: ASC or DESC
     *
     * @return Map<String, Object> containing:
     *         - 'total'       : total number of matched records
     *         - 'pageRecords' : List of UI-ready record maps for the requested page
     */
    private static Map<String,Object> searchIntegrationFraudCase(
        String fraudCaseId,        
        String nationalId,
        String phoneNumber,
        String applicationId,
        String contractNumber,
        String accountNumber,
        Integer pageNumber,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ) {
        log('START searchFraudCases');

        // Paging defaults
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 1) pageSize = 10;

        // =====================================================
        // 1. Parent Case Filters
        // =====================================================
        List<String> parentWhere = new List<String>();

        if (String.isNotBlank(fraudCaseId)) {
            parentWhere.add(
                'FEC_CaseID__c LIKE \'%' + String.escapeSingleQuotes(fraudCaseId) + '%\''
            );
        }

        // =====================================================
        // 2. Additional Info Filters (Apex filtering allowed)
        // =====================================================
        Map<String,String> infoFilters = new Map<String,String>{
            'nationalId'     => nationalId,
            'phoneNumber'    => phoneNumber,
            'applicationId'  => applicationId,
            'contractNumber' => contractNumber,
            'accountNumber'  => accountNumber
        };

        Set<Id> matchedCaseIds = new Set<Id>();
        Integer activeFilterCount = 0;

        for (String key : infoFilters.keySet()) {
            String val = infoFilters.get(key);
            if (String.isNotBlank(val)) {

                activeFilterCount++;
                log('Filtering AdditionalInfo field: ' + key + ' LIKE %' + val + '%');

                // Step 1 — Filter by Info ID (allowed SOQL filter)
                List<FEC_Integration_Case_Info__c> rows = [
                    SELECT FEC_Parent_Case__c, FEC_Info_ID__c, FEC_Info_Value__c
                    FROM FEC_Integration_Case_Info__c
                    WHERE FEC_Info_ID__c = :key
                ];

                // Step 2 — Apex filtering for text contains
                for (FEC_Integration_Case_Info__c r : rows) {
                    if (r.FEC_Info_Value__c != null &&
                        r.FEC_Info_Value__c.contains(val)) {

                        matchedCaseIds.add(r.FEC_Parent_Case__c);
                    }
                }
            }
        }

        log('AdditionalInfo matchedCaseIds before combining: ' + matchedCaseIds);

        if (activeFilterCount > 0 && matchedCaseIds.isEmpty()) {
            return new Map<String,Object>{
                'total' => 0,
                'pageRecords' => new List<Map<String,Object>>()
            };
        }

        if (!matchedCaseIds.isEmpty()) {
            parentWhere.add('Id IN :matchedCaseIds');
        }
        // Always enforce FH / TK
        parentWhere.add('(FEC_CaseID__c LIKE \'FH-%\' OR FEC_CaseID__c LIKE \'TK-%\')');

        // =====================================================
        // 3. Sorting
        // =====================================================
        Set<String> allowedSortFields = new Set<String>{
            'FEC_CaseID__c',
            'FEC_Service_Case_ID__c',
            'FEC_Category__c',
            'FEC_Sub_Category__c',
            'FEC_Sub_Code__c',
            'FEC_Case_Status__c',
            'CreatedDate'
        };

        if (String.isBlank(sortBy) || !allowedSortFields.contains(sortBy))
            sortBy = 'CreatedDate';

        if (sortDirection != 'ASC' && sortDirection != 'DESC')
            sortDirection = 'DESC';

        // =====================================================
        // 4. Build Final SOQL query
        // =====================================================
        String query =
            'SELECT Id, Name, FEC_CaseID__c, FEC_Service_Case_ID__c, FEC_Parent_CaseID__c,' +
            'FEC_Case_Status__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,' +
            'FEC_Remark__c, CreatedDate, FEC_Sys_Channel__c, FEC_Creator_Email__c, ' +
            'CreatedBy.Id, CreatedBy.Name, CreatedBy.Email ' +
            'FROM FEC_Integration_Case__c ';

        if (!parentWhere.isEmpty()) {
            query += ' WHERE ' + String.join(parentWhere, ' AND ');
        }
        

        query += ' ORDER BY ' + sortBy + ' ' + sortDirection;

        log('FINAL QUERY: ' + query);

        List<FEC_Integration_Case__c> allRecords = Database.query(query);
        Integer total = allRecords.size();

        // =====================================================
        // 5. Paging
        // =====================================================
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx   = Math.min(startIdx + pageSize, total);

        List<FEC_Integration_Case__c> pageList = new List<FEC_Integration_Case__c>();
        for (Integer i = startIdx; i < endIdx; i++) {
            pageList.add(allRecords[i]);
        }

        // =====================================================
        // 6. Load Account Number from AdditionalInfo
        // =====================================================
        Map<Id, String> accountNumberMap = new Map<Id, String>();

        if (!pageList.isEmpty()) {
            List<FEC_Integration_Case_Info__c> acctInfos = [
                SELECT FEC_Parent_Case__c, FEC_Info_ID__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c IN :pageList
                AND FEC_Info_ID__c = 'AccountNumber'
            ];

            for (FEC_Integration_Case_Info__c info : acctInfos) {
                accountNumberMap.put(info.FEC_Parent_Case__c, info.FEC_Info_Value__c);
            }
        }

        // =====================================================
        // 7. Prepare final rows for LWC
        // =====================================================
        List<Map<String,Object>> finalRows = new List<Map<String,Object>>();

        for (FEC_Integration_Case__c c : pageList) {
            finalRows.add(new Map<String,Object>{
                'Id'                     => c.Id,
                'FEC_CaseID__c'          => c.FEC_CaseID__c,
                'FEC_Service_Case_ID__c' => c.FEC_Service_Case_ID__c,
                'FEC_Category__c'        => c.FEC_Category__c,
                'FEC_Sub_Category__c'    => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'        => c.FEC_Sub_Code__c,
                'FEC_Case_Status__c'     => c.FEC_Case_Status__c,
                'CreatedDate'            => formatDateTime(c.CreatedDate),
                'FEC_Sys_Channel__c'     => c.FEC_Sys_Channel__c,
                
                //Correct Account Number from AdditionalInfo
                'AccountNumber'          => accountNumberMap.containsKey(c.Id)
                                        ? accountNumberMap.get(c.Id)
                                        : null,
                'CreatedByEmail' => c.FEC_Creator_Email__c,
                'CreatedByName'  => c.CreatedBy.Name,                                       

                // 🔗 Hyperlink for LWC
                'ServiceCaseLink' => (c.FEC_Service_Case_ID__c != null ? '/' + c.FEC_Service_Case_ID__c : null),
                'FraudCaseLink'        => (c.FEC_CaseID__c != null && c.FEC_CaseID__c.startsWith('FH-'))
                ? '/lightning/n/'+ FRAUD_HANDLING_CASE_DETAIL_PATH + '?c__caseId=' + c.FEC_CaseID__c
                : null,
                'FraudCaseDisplay'      => c.FEC_CaseID__c
            });
        }

        return new Map<String,Object>{
            'total' => total,
            'pageRecords' => finalRows
        };
    }

    /**
     * Formats a DateTime value into a human-readable string.
     *
     * This helper method standardizes date-time display across the application
     * using the format: dd/MM/yyyy HH:mm:ss
     *
     * Example output:
     *  24/12/2025 09:15:30
     *
     * @param dt The DateTime value to be formatted
     * @return   Formatted date-time string, or null if input is null
     */
    private static String formatDateTime(DateTime dt) {
        return dt != null ? dt.format('dd/MM/yyyy HH:mm:ss') : null;
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