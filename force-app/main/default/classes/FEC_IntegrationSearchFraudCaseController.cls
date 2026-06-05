global with sharing class FEC_IntegrationSearchFraudCaseController {

    public static final Boolean DEBUG_LOG = true;
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
     * Returns all TK cases belonging to an FH case.
     * Hierarchy: FH → BU → TK
     * UI only displays TK cases, BU layer is hidden.
     *
     * @param fraudCaseId  FH case identifier (ex: FH-10001)
     * @return Map<String, Object> containing:
     *         - pageRecords : List<FEC_Integration_Case__c>  (TK cases)
     *         - total       : Integer  (number of TK cases)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getFraudSubCases(String fraudCaseId) {
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
        String likeBUValue = caseField.CASEBU + '%';
        String likeTKValue = caseField.CASETK + '%';
        log('getFraudSubCases called with fraudCaseId = ' + fraudCaseId);

        if (String.isBlank(fraudCaseId)) {
            log('fraudCaseId is blank — returning empty result');
            return new Map<String,Object>{
                'pageRecords' => new List<FEC_Integration_Case__c>(),
                'total' => 0
            };
        }

        // Step 1: Load BU under FH
        List<FEC_Integration_Case__c> existParent = [
            SELECT Id, FEC_CaseID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_Parent_CaseID__c = :fraudCaseId 
            AND FEC_CaseID__c LIKE :likeBUValue
        ];

        log('BU cases found: ' + existParent.size());

        if (existParent.isEmpty()) {
            log('No BU cases found — returning empty result');
            return new Map<String,Object>{
                'pageRecords' => new List<FEC_Integration_Case__c>(),
                'total' => 0
            };
        }

        // Step 2: Collect BU IDs
        Set<String> buIds = new Set<String>();
        for (FEC_Integration_Case__c bu : existParent) {
            buIds.add(bu.FEC_CaseID__c);
        }

        log('BU ID set: ' + buIds);

        // Step 3: Load TK under those BU       
        List<FEC_Integration_Case__c> allRecords = [
            SELECT 
            Id, Name, FEC_CaseID__c, FEC_Service_Case_ID__c, FEC_Parent_CaseID__c,
            FEC_Case_Status__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c,
            FEC_Remark__c, CreatedDate, FEC_Sys_Channel__c, FEC_Creator_Email__c, 
            CreatedBy.Id, CreatedBy.Name, CreatedBy.Email,FEC_Integrate_Case_ID__c 
            FROM FEC_Integration_Case__c
            WHERE FEC_Parent_CaseID__c IN :buIds
            AND FEC_CaseID__c LIKE :likeTKValue
            ORDER BY CreatedDate ASC
        ];

        log('TK cases found: ' + allRecords.size());

        Integer total = allRecords.size();

        // Step 4: Build page list
        List<FEC_Integration_Case__c> pageList = new List<FEC_Integration_Case__c>();
        for (FEC_Integration_Case__c rec : allRecords) {
            pageList.add(rec);
        }

        log('pageList size: ' + pageList.size());

        // Step 5: Load account numbers
        Map<Id, String> accountNumberMap = new Map<Id, String>();

        if (!pageList.isEmpty()) {
            List<FEC_Integration_Case_Info__c> acctInfos = [
                SELECT FEC_Parent_Case__c, FEC_Info_ID__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Parent_Case__c IN :pageList
                AND FEC_Info_ID__c = :FEC_FraudConstantCommon.INFO_ACCOUNT_NUMBER
            ];

            log('Account info records: ' + acctInfos.size());

            for (FEC_Integration_Case_Info__c info : acctInfos) {
                accountNumberMap.put(info.FEC_Parent_Case__c, info.FEC_Info_Value__c);
            }
        }

        log('accountNumberMap size: ' + accountNumberMap.size());

        // Step 6: Final response
        Map<String,Object> response = getFormatResponseSearchIntegrationFraudCase(
            pageList, 
            accountNumberMap, 
            total
        );

        log('Final response prepared: ' + response.keySet());

        return response;
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
    String sortDirection) {

        Integer pageNum  = normalizePageNumber(pageNumber);
        pageSize = normalizePageSize(pageSize);
        List<String> parentWhere = buildParentWhere(fraudCaseId);
    
        Map<String, List<String>> infoFilterMap =
            buildInfoFilterMap(nationalId, phoneNumber, applicationId, contractNumber, accountNumber);
    
        log('infoFilterMap: ' + infoFilterMap);
        Set<Id> matchedIds = findMatchedCaseIdsFromInfo(infoFilterMap);
        log('matchedIds: ' + matchedIds);
        if (!infoFilterMap.isEmpty() && matchedIds.isEmpty()) {
            return new Map<String,Object>{
                'total' => 0,
                'pageRecords' => new List<Map<String,Object>>()
            };
        }
    
        applyMatchedCaseIds(parentWhere, matchedIds);
        applyCaseTypeGuard(parentWhere);
        String sortField = normalizeSortBy(sortBy);
        String sortDir   = normalizeSortDirection(sortDirection);
    
        Boolean isAccountNumberSort = (sortBy == 'AccountNumber');
        String effectiveSortField = isAccountNumberSort ? 'CreatedDate' : sortField;

        List<FEC_Integration_Case__c> all =
            executeParentQuery(parentWhere, effectiveSortField, isAccountNumberSort ? 'DESC' : sortDir);

        // For AccountNumber sort, load all account numbers first, then sort in memory
        if (isAccountNumberSort) {
            Map<Id, String> allAccountMap = loadAccountNumbers(all);
            all = sortByAccountNumber(all, allAccountMap, sortDir);
        }
    
        List<FEC_Integration_Case__c> page =
            paginate(all, pageNum, pageSize);
    
        Map<Id, String> accountMap = isAccountNumberSort 
            ? loadAccountNumbers(page) 
            : loadAccountNumbers(page);
        Map<String, Integer> childCountMap = buildChildCountMap(page);
    
        Map<String,Object> response =
            getFormatResponseSearchIntegrationFraudCase(page, accountMap, all.size());
    
        response.put('childCountMap', childCountMap);
        return response;
    }
    
    /**
     * Ensures the page number is always valid.
     * - Defaults to 1 if the input is null or less than 1
     * - Prevents invalid pagination values
     */
    private static Integer normalizePageNumber(Integer pageNumber) {
        return (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
    }
    
    /**
     * Ensures the page size is always valid.
     * - Defaults to 10 if the input is null or less than 1
     * - Helps avoid invalid LIMIT values in SOQL
     */
    private static Integer normalizePageSize(Integer pageSize) {
        return (pageSize == null || pageSize < 1) ? 10 : pageSize;
    }
    
    /**
     * Builds WHERE conditions for searching parent fraud cases.
     * - Matches the keyword against both Case ID fields
     * - Escapes single quotes to prevent SOQL injection
     * - Uses LIKE with wildcards for partial matching
     *
     * @param fraudCaseId Search keyword entered by the user
     * @return List of WHERE clause conditions to be joined later
     */
    private static List<String> buildParentWhere(String fraudCaseId) {
        List<String> whereList = new List<String>();
    
        if (String.isNotBlank(fraudCaseId)) {
            String keyword =
                '%' + String.escapeSingleQuotes(fraudCaseId.trim()) + '%';
    
            whereList.add(
                '(FEC_CaseID__c LIKE \'' + keyword +
                '\' OR FEC_Service_Case_ID__c LIKE \'' + keyword + '\')'
            );
        }
    
        return whereList;
    }
    
    
    /**
     * Builds a mapping between search values and their corresponding Info IDs.
     *
     * Each non-blank input value (national ID, phone number, etc.)
     * is used as a key in the map, and maps to a list of Info Type IDs
     * that should be matched against that value.
     *
     * This structure allows dynamic filtering where:
     * - One search value can be applied to multiple info types
     * - Only provided (non-blank) filters are included
     *
     * @param nationalId     National ID entered by the user
     * @param phoneNumber    Phone number entered by the user
     * @param applicationId  Application ID entered by the user
     * @param contractNumber Contract number entered by the user
     * @param accountNumber  Account number entered by the user
     * @return Map of search value → list of related Info Type IDs
     */
    private static Map<String, List<String>> buildInfoFilterMap(
        String nationalId,
        String phoneNumber,
        String applicationId,
        String contractNumber,
        String accountNumber
    ) {
        Map<String, List<String>> mapValueToInfoIds = new Map<String, List<String>>();
    
        if (String.isNotBlank(nationalId)) {
            mapValueToInfoIds.put(nationalId, new List<String>{
                FEC_FraudConstantCommon.INFO_NATION_ID,
                FEC_FraudConstantCommon.INFO_NATION_IDS
            });
        }
    
        if (String.isNotBlank(applicationId)) {
            mapValueToInfoIds.put(applicationId, new List<String>{
                FEC_FraudConstantCommon.INFO_APPLICATION_ID,
                FEC_FraudConstantCommon.INFO_APPLICATION_IDS
            });
        }
    
        if (String.isNotBlank(phoneNumber)) {
            mapValueToInfoIds.put(phoneNumber, new List<String>{
                FEC_FraudConstantCommon.INFO_PHONE_NUMBER
            });
        }
    
        if (String.isNotBlank(contractNumber)) {
            mapValueToInfoIds.put(contractNumber, new List<String>{
                FEC_FraudConstantCommon.INFO_CONTRACT_NUMBER
            });
        }
    
        if (String.isNotBlank(accountNumber)) {
            mapValueToInfoIds.put(accountNumber, new List<String>{
                FEC_FraudConstantCommon.INFO_ACCOUNT_NUMBER
            });
        }
    
        return mapValueToInfoIds;
    }
    
    /**
     * Finds parent case IDs that match all provided Info filters.
     *
     * For each search value:
     * - Query case info records by Info ID
     * - Check if the stored info value contains the search value
     * - Collect matching parent case IDs
     *
     * Multiple filters are combined using AND logic
     * (intersection of matched case IDs).
     *
     * @param valueToInfoIds Map of search value → list of Info IDs
     * @return Set of parent case IDs matching all filters
     */
    private static Set<Id> findMatchedCaseIdsFromInfo(
        Map<String, List<String>> valueToInfoIds
    ) {
        Set<Id> matchedCaseIds = new Set<Id>();
        Boolean isFirstFilter = true;
        log('findMatchedCaseIdsFromInfo: valueToInfoIds: ' + valueToInfoIds);
    
    
        for (String value : valueToInfoIds.keySet()) {
            List<String> infoIds = valueToInfoIds.get(value);
    
            List<FEC_Integration_Case_Info__c> rows = [
                SELECT FEC_Parent_Case__c, FEC_Info_Value__c
                FROM FEC_Integration_Case_Info__c
                WHERE FEC_Info_ID__c = :infoIds
            ];
            log('findMatchedCaseIdsFromInfo: infoIds: ' + infoIds);
    
            Set<Id> currentMatches = new Set<Id>();
            for (FEC_Integration_Case_Info__c r : rows) {
                if (r.FEC_Info_Value__c != null &&
                    r.FEC_Info_Value__c.contains(value)) {
                    currentMatches.add(r.FEC_Parent_Case__c);
                }
            }
            log('findMatchedCaseIdsFromInfo: currentMatches: ' + currentMatches);
            if (isFirstFilter) {
                matchedCaseIds.addAll(currentMatches);
                isFirstFilter = false;
            } else {
                matchedCaseIds.retainAll(currentMatches);
            }
            log('findMatchedCaseIdsFromInfo: matchedCaseIds: ' + matchedCaseIds);
            if (matchedCaseIds.isEmpty()) break;
        }
    
        return matchedCaseIds;
    }
    
    /**
     * Adds a WHERE condition to filter parent cases by matched case IDs.
     *
     * Converts the Set<Id> into an IN clause and appends it
     * to the existing parent WHERE conditions.
     *
     * @param parentWhere     List of parent WHERE clauses
     * @param matchedCaseIds  Case IDs matched from info filtering
     */
    private static void applyMatchedCaseIds(
        List<String> parentWhere,
        Set<Id> matchedCaseIds
    ) {
        // parentWhere.add('Id IN :matchedCaseIds
        if (!matchedCaseIds.isEmpty()) {
            List<String> idStrings = new List<String>();
                for (Id caseId : matchedCaseIds) {
                    idStrings.add(String.valueOf(caseId));
                }

                parentWhere.add(
                    'Id IN (\'' + String.join(idStrings, '\',\'') + '\')'
                );


        }
    }
    
    /**
     * Validates and normalizes the sort field.
     *
     * Only allows predefined, safe fields to prevent SOQL injection.
     * Defaults to CreatedDate if the input is invalid.
     *
     * @param sortBy Requested sort field
     * @return Safe sort field name
     */
    private static String normalizeSortBy(String sortBy) {
        Set<String> allowed = new Set<String>{
            'FEC_CaseID__c',
            'FEC_Service_Case_ID__c',
            'FEC_Category__c',
            'FEC_Sub_Category__c',
            'FEC_Sub_Code__c',
            'FEC_Case_Status__c',
            'FEC_Sys_Channel__c',
            'FEC_Creator_Email__c',
            'CreatedDate',
            'AccountNumber'
        };
    
        return allowed.contains(sortBy) ? sortBy : 'CreatedDate';
    }

    /**
     * Enforces allowed case type prefixes.
     *
     * Ensures that only FH / TK / SFT / Service cases
     * are included in the parent case query.
     *
     * This guard is always applied regardless of user filters.
     *
     * @param parentWhere List of parent WHERE clauses
     */
    private static void applyCaseTypeGuard(
        List<String> parentWhere
    ) {
        FEC_FraudConstantCommon.IntegrationField caseField = new FEC_FraudConstantCommon.IntegrationField();
       
        // Always enforce FH / TK / SFT / Service       
        parentWhere.add(
            '(FEC_CaseID__c LIKE \'' + caseField.CASEFH + '%\' ' +
            'OR FEC_CaseID__c LIKE \'' + caseField.CASETK + '%\' ' +
            'OR FEC_CaseID__c LIKE \'' + caseField.CASESFT + '%\' ' +
            'OR FEC_CaseID__c LIKE \'' + caseField.CASE_SERVICE + '%\')'
        );

    }
    
    /**
     * Normalizes sort direction.
     *
     * Only allows ASC explicitly; defaults to DESC
     * for any other value to ensure safety.
     *
     * @param direction Requested sort direction
     * @return Normalized sort direction
     */
    private static String normalizeSortDirection(String direction) {
        return (direction == 'ASC') ? 'ASC' : 'DESC';
    }
    

    /**
     * Executes the dynamic SOQL query for parent cases.
     *
     * - Applies all WHERE conditions
     * - Applies sorting
     *
     * @param parentWhere   List of WHERE clauses
     * @param sortBy        Sort field
     * @param sortDirection Sort direction
     * @return List of matching parent cases
     */
    private static List<FEC_Integration_Case__c> executeParentQuery(
        List<String> parentWhere,
        String sortBy,
        String sortDirection
    ) {
        String soql =
            'SELECT Id, Name, FEC_CaseID__c, FEC_Service_Case_ID__c, ' +
            'FEC_Parent_CaseID__c, FEC_Case_Status__c, FEC_Category__c, ' +
            'FEC_Sub_Category__c, FEC_Sub_Code__c, FEC_Remark__c, ' +
            'CreatedDate, FEC_Sys_Channel__c, FEC_Creator_Email__c, ' +
            'CreatedBy.Id, CreatedBy.Name, CreatedBy.Email, FEC_Integrate_Case_ID__c ' +
            'FROM FEC_Integration_Case__c';
    
        if (!parentWhere.isEmpty()) {
            soql += ' WHERE ' + String.join(parentWhere, ' AND ');
        }
    
        soql += ' ORDER BY ' + sortBy + ' ' + sortDirection;
    
        return Database.query(soql);
    }
    
    
    /**
     * Returns a sublist of records for the requested page.
     *
     * @param allRecords Full result list
     * @param pageNumber Current page number (1-based)
     * @param pageSize   Number of records per page
     * @return Records for the current page
     */
    private static List<FEC_Integration_Case__c> paginate(
        List<FEC_Integration_Case__c> allRecords,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx = Math.min(startIdx + pageSize, allRecords.size());
    
        List<FEC_Integration_Case__c> page = new List<FEC_Integration_Case__c>();
        for (Integer i = startIdx; i < endIdx; i++) {
            page.add(allRecords[i]);
        }
        return page;
    }

    /**
     * Loads account numbers for the given parent cases.
     *
     * Queries account number info records and maps them
     * to their corresponding parent case IDs.
     *
     * @param pageList List of parent cases on the current page
     * @return Map of Case ID → Account Number
     */
    private static Map<Id, String> loadAccountNumbers(
        List<FEC_Integration_Case__c> pageList
    ) {
        Map<Id, String> accountNumberMap = new Map<Id, String>();

        if (pageList == null || pageList.isEmpty()) {
            return accountNumberMap;
        }

        List<FEC_Integration_Case_Info__c> acctInfos = [
            SELECT FEC_Parent_Case__c, FEC_Info_Value__c
            FROM FEC_Integration_Case_Info__c
            WHERE FEC_Parent_Case__c IN :pageList
            AND FEC_Info_ID__c = :FEC_FraudConstantCommon.INFO_ACCOUNT_NUMBER
        ];

        for (FEC_Integration_Case_Info__c info : acctInfos) {
            accountNumberMap.put(
                info.FEC_Parent_Case__c,
                info.FEC_Info_Value__c
            );
        }

        return accountNumberMap;
    }

    /**
     * Sorts a list of fraud cases by their associated Account Number in memory.
     *
     * Since AccountNumber is stored in a related info record (not a direct field),
     * it cannot be sorted via SOQL ORDER BY. This method performs an in-memory sort
     * using a wrapper class that implements Comparable.
     *
     * Null account numbers are sorted to the end regardless of direction.
     *
     * @param cases         List of cases to sort
     * @param accountMap    Map of Case Id → Account Number
     * @param sortDirection ASC or DESC
     * @return Sorted list of cases
     */
    private static List<FEC_Integration_Case__c> sortByAccountNumber(
        List<FEC_Integration_Case__c> cases,
        Map<Id, String> accountMap,
        String sortDirection
    ) {
        List<AccountNumberSortWrapper> wrappers = new List<AccountNumberSortWrapper>();
        for (FEC_Integration_Case__c c : cases) {
            String acctNum = accountMap.containsKey(c.Id) ? accountMap.get(c.Id) : null;
            wrappers.add(new AccountNumberSortWrapper(c, acctNum, sortDirection));
        }
        wrappers.sort();

        List<FEC_Integration_Case__c> sorted = new List<FEC_Integration_Case__c>();
        for (AccountNumberSortWrapper w : wrappers) {
            sorted.add(w.record);
        }
        return sorted;
    }

    /**
     * Wrapper class to enable sorting FEC_Integration_Case__c records
     * by their associated Account Number value.
     */
    private class AccountNumberSortWrapper implements Comparable {
        public FEC_Integration_Case__c record;
        public String accountNumber;
        public Integer directionMultiplier;

        public AccountNumberSortWrapper(FEC_Integration_Case__c record, String accountNumber, String sortDirection) {
            this.record = record;
            this.accountNumber = accountNumber;
            this.directionMultiplier = (sortDirection == 'ASC') ? 1 : -1;
        }

        public Integer compareTo(Object other) {
            AccountNumberSortWrapper otherWrapper = (AccountNumberSortWrapper) other;
            String a = this.accountNumber;
            String b = otherWrapper.accountNumber;

            // Nulls go to the end
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;

            return a.compareTo(b) * directionMultiplier;
        }
    }
      
        
    /**
     * Builds a map of FH case ID → total number of TK child cases.
     *
     * Hierarchy handled:
     *   FH (parent)
     *    └── BU (child)
     *          └── TK (grandchild)
     *
     * For each FH case in the current page:
     * - Find BU cases under that FH
     * - Count TK cases under each BU
     * - Sum all TK counts per FH
     *
     * @param pageList List of parent cases on the current page
     * @return Map of FH Case ID → total TK child count
     */
    private static Map<String, Integer> buildChildCountMap(
    List<FEC_Integration_Case__c> pageList
    ) {
        FEC_FraudConstantCommon.IntegrationField fraudConstant = new FEC_FraudConstantCommon.IntegrationField();
        
        String likeBUValue = fraudConstant.CASEBU + '%';
        String likeTKValue = fraudConstant.CASETK + '%';
        Map<String, Integer> childCountMap = new Map<String, Integer>();

        if (pageList == null || pageList.isEmpty()) {
            return childCountMap;
        }

        /* ================= FH cases ================= */
        Set<String> fhCaseIds = new Set<String>();
        for (FEC_Integration_Case__c c : pageList) {
            if (c.FEC_CaseID__c != null && c.FEC_CaseID__c.startsWith(fraudConstant.CASEFH)) {
                fhCaseIds.add(c.FEC_CaseID__c);
            }
        }

        if (fhCaseIds.isEmpty()) {
            return childCountMap;
        }

        /* ================= BU under FH ================= */
        List<FEC_Integration_Case__c> buCases = [
            SELECT FEC_CaseID__c, FEC_Parent_CaseID__c
            FROM FEC_Integration_Case__c
            WHERE FEC_Parent_CaseID__c IN :fhCaseIds
            AND FEC_CaseID__c LIKE :likeBUValue
        ];

        Map<String, Set<String>> fhToBuMap = new Map<String, Set<String>>();
        Set<String> allBuIds = new Set<String>();

        for (FEC_Integration_Case__c bu : buCases) {
            //Apex-safe replacement for computeIfAbsent
            if (!fhToBuMap.containsKey(bu.FEC_Parent_CaseID__c)) {
                fhToBuMap.put(bu.FEC_Parent_CaseID__c, new Set<String>());
            }

            fhToBuMap.get(bu.FEC_Parent_CaseID__c).add(bu.FEC_CaseID__c);
            allBuIds.add(bu.FEC_CaseID__c);
        }

        if (allBuIds.isEmpty()) {
            return childCountMap;
        }

        /* ================= TK count per BU ================= */
        List<AggregateResult> tkCounts = [
            SELECT FEC_Parent_CaseID__c parentId, COUNT(Id) cnt
            FROM FEC_Integration_Case__c
            WHERE FEC_Parent_CaseID__c IN :allBuIds
            AND FEC_CaseID__c LIKE :likeTKValue
            GROUP BY FEC_Parent_CaseID__c
        ];

        Map<String, Integer> buToTkCount = new Map<String, Integer>();
        for (AggregateResult ar : tkCounts) {
            buToTkCount.put(
                (String) ar.get('parentId'),
                (Integer) ar.get('cnt')
            );
        }

        /* ================= Sum TK per FH ================= */
        for (String fhId : fhToBuMap.keySet()) {
            Integer totalTk = 0;

            for (String buId : fhToBuMap.get(fhId)) {
                totalTk += buToTkCount.containsKey(buId)
                    ? buToTkCount.get(buId)
                    : 0;
            }

            childCountMap.put(fhId, totalTk);
        }

        return childCountMap;
    }



    /**
     * Formats the search result response for Integration Fraud Case search.
     *
     * Converts raw case records into a UI-friendly structure used by LWC:
     * - Flattens case fields
     * - Formats dates
     * - Injects derived fields (account number, links)
     * - Wraps results with pagination metadata
     *
     * @param pageList         List of cases for the current page
     * @param accountNumberMap Map of Case ID → Account Number
     * @param total            Total number of matched records
     * @return Response map containing total count and formatted page records
     */
    private static Map<String,Object> getFormatResponseSearchIntegrationFraudCase(List<FEC_Integration_Case__c> pageList, Map<Id, String> accountNumberMap, Integer total) {
        List<Map<String,Object>> finalRows = new List<Map<String,Object>>();
        FEC_FraudConstantCommon.IntegrationField fraudConstant = new FEC_FraudConstantCommon.IntegrationField();
        for (FEC_Integration_Case__c c : pageList) {
            finalRows.add(new Map<String,Object>{
                'Id'                     => c.Id,
                'FEC_CaseID__c'          => c.FEC_CaseID__c,
                'FEC_Service_Case_ID__c' => c.FEC_Service_Case_ID__c,
                'FEC_Category__c'        => c.FEC_Category__c,
                'FEC_Sub_Category__c'    => c.FEC_Sub_Category__c,
                'FEC_Sub_Code__c'        => c.FEC_Sub_Code__c,
                'FEC_Case_Status__c'     => c.FEC_Case_Status__c,
                'CreatedDate'            => FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate),
                'FEC_Sys_Channel__c'     => c.FEC_Sys_Channel__c,
                
                //Correct Account Number from AdditionalInfo
                'AccountNumber'          => accountNumberMap.containsKey(c.Id)
                                        ? accountNumberMap.get(c.Id)
                                        : null,
                'CreatedByEmail' => c.FEC_Creator_Email__c,
                'CreatedByName'  => c.CreatedBy.Name,                                       

                //Hyperlink for LWC
                 'ServiceCaseLink'        => (c.FEC_Service_Case_ID__c != null && (c.FEC_Service_Case_ID__c.startsWith(fraudConstant.CASE_SERVICE)))
                ? + FEC_FraudConstantCommon.SERVICE_CASE_LINK + c.FEC_Integrate_Case_ID__c + '/view'
                : + FEC_FraudConstantCommon.SERVICE_SFT_CASE_LINK + c.FEC_Integrate_Case_ID__c + '/view',
                'FraudCaseLink'        => (c.FEC_CaseID__c != null && (c.FEC_CaseID__c.startsWith(fraudConstant.CASEFH) || c.FEC_CaseID__c.startsWith(fraudConstant.CASETK)))
                ? '/lightning/n/'+ FEC_FraudConstantCommon.FRAUD_HANDLING_CASE_DETAIL_PATH + '?c__caseId=' + c.FEC_CaseID__c
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