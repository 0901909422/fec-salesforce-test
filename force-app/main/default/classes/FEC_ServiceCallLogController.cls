global with sharing class FEC_ServiceCallLogController {
    
    
     /**
     * Search service logs with filter, sorting and pagination.
     *
     * @param caseId         Case Id used to filter logs
     * @param operationName  Service/operation name used to filter logs
     * @param startDate      Start datetime filter (records created after this)
     * @param endDate        End datetime filter (records created before this)
     * @param pageNumber     Page number for pagination
     * @param pageSize       Number of records per page
     * @param sortBy         Field name used for sorting
     * @param sortDirection  Sort direction (ASC / DESC)
     *
     * @return Map<String,Object>
     *         - records: list of service logs for current page
     *         - totalRecords: total number of records found
     */
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> searchServiceLogs(
        String caseId,
        String operationName,
        String startDate,
        String endDate,
        Integer pageNumber,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ){
        Map<String,Object> results = new Map<String,Object>();

        Integer pageNum  = normalizePageNumber(pageNumber);
        pageSize = normalizePageSize(pageSize);
        String sortField = normalizeSortBy(sortBy);
        String sortDir   = normalizeSortDirection(sortDirection);

        List<String> queryWhere = buildQueryWhere(caseId, operationName, startDate, endDate);        
        
        List<FEC_Integration_Service_Log__c> all =
            executeQuery(queryWhere, sortField, sortDir);
        List<FEC_Integration_Service_Log__c> page =
            paginate(all, pageNum, pageSize);
        results = getFormatResponseSearchServiceCallLog(page, all.size());
        return results;

    }

    /**
     * Load detail information of a specific service log by Id.
     *
     * @param recordId  Id of the service log record
     * @return FEC_Integration_Service_Log__c
     *         Service log record with detailed fields
     */
    @AuraEnabled(cacheable=true)
    public static FEC_Integration_Service_Log__c loadServiceCallLogDetailById(Id recordId) {        
        List<FEC_Integration_Service_Log__c> logs = [
            SELECT Id,
                FEC_Request_Data__c,
                FEC_Response_Data__c
            FROM FEC_Integration_Service_Log__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (!logs.isEmpty()) {
            return logs[0];
        }

        return null;
    }
    

    private static Map<String,Object> getFormatResponseSearchServiceCallLog(List<FEC_Integration_Service_Log__c> pageList, Integer total) {
        List<Map<String,Object>> finalRows = new List<Map<String,Object>>();
        for (FEC_Integration_Service_Log__c c : pageList) {
            finalRows.add(new Map<String,Object>{
                'Id'                     => c.Id,
                'FEC_Service_Case_Id__c'          => c.FEC_Integration_Case_Id__c != null? c.FEC_Integration_Case_Id__c: c.FEC_Service_Case_Id__c,
                'FEC_Service_Name__c' => c.FEC_Service_Name__c,
                'FEC_Description__c'        => c.FEC_Description__c,
                'FEC_Message_Status__c'    => c.FEC_Message_Status__c,               
                'CreatedDate'            => FEC_IntegrationFraudCaseUtil.formatDateTime(c.CreatedDate),
                'FEC_Requestor__c'  => c.FEC_Requestor__c
            });
        }

        return new Map<String,Object>{
            'total' => total,
            'pageRecords' => finalRows
        };
    }

    /**
     * Returns a sublist of records for the requested page.
     *
     * @param allRecords Full result list
     * @param pageNumber Current page number (1-based)
     * @param pageSize   Number of records per page
     * @return Records for the current page
     */
    private static List<FEC_Integration_Service_Log__c> paginate(
        List<FEC_Integration_Service_Log__c> allRecords,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx = Math.min(startIdx + pageSize, allRecords.size());
    
        List<FEC_Integration_Service_Log__c> page = new List<FEC_Integration_Service_Log__c>();
        for (Integer i = startIdx; i < endIdx; i++) {
            page.add(allRecords[i]);
        }
        return page;
    }

    private static List<FEC_Integration_Service_Log__c> executeQuery(
            List<String> queryWhere,
            String sortBy,
            String sortDirection
    ) {
        String soql =
            'SELECT Id, Name, FEC_Service_Name__c, FEC_Channel__c,' +
                ' FEC_Integration_Case_Id__c, FEC_Service_Case_Id__c,' +
                ' FEC_Message_Status__c, FEC_Requestor__c,' +
                ' FEC_Description__c, CreatedDate ' +
                'FROM FEC_Integration_Service_Log__c';
    
        if (!queryWhere.isEmpty()) {
            soql += ' WHERE ' + String.join(queryWhere, ' AND ');
        }
    
        soql += ' ORDER BY ' + sortBy + ' ' + sortDirection;
        System.debug('buildQueryWhere result: ' + soql);
        return Database.query(soql);
    }

     private static List<String> buildQueryWhere(String caseId, String operationName, String startDate, String endDate) {
        List<String> whereList = new List<String>();

        Datetime startDateTime;
        Datetime endDateTime;
        String keyword = null;

        try{
            if(String.isNotBlank(startDate)){
                startDateTime = Datetime.valueOfGmt(startDate.replace('T',' ').replace('Z',''));
            }
        }catch(Exception e){
            System.debug('StartDate parse error: ' + e.getMessage());
            startDateTime = null;
        }

        try{
            if(String.isNotBlank(endDate)){
                endDateTime = Datetime.valueOfGmt(endDate.replace('T',' ').replace('Z',''));
            }
        }catch(Exception e){
            System.debug('StarEndDate tDate parse error: ' + e.getMessage());
            endDateTime = null;
        }
    
        if(String.isNotBlank(caseId)){
            keyword =
                '%' + String.escapeSingleQuotes(caseId.trim()) + '%';
             whereList.add(
                '(FEC_Integration_Case_Id__c LIKE \'' + keyword +
                '\' OR FEC_Service_Case_Id__c LIKE \'' + keyword + '\')'
            );
        }

        if(String.isNotBlank(operationName)){
             keyword =
                '%' + String.escapeSingleQuotes(operationName.trim()) + '%';
            whereList.add(
                '(FEC_Service_Name__c LIKE \'' + keyword + '\')'
            );
        }

       if(startDateTime != null){
            String startStr = startDateTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            whereList.add('(CreatedDate >= ' + startStr + ')');
        }

        if(endDateTime != null){
            String endStr = endDateTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            whereList.add('(CreatedDate <= ' + endStr + ')');
        }  
   
        return whereList;
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

     private static String normalizeSortBy(String sortBy) {
        Set<String> allowed = new Set<String>{
            'FEC_Integration_Case_Id__c',
            'FEC_Service_Case_Id__c',
            'FEC_Service_Name__c',
            'FEC_Description__c',
            'FEC_Message_Status__c',
            'CreatedDate',
            'FEC_Requestor__c'
        };
    
        return allowed.contains(sortBy) ? sortBy : 'CreatedDate';
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
    
}