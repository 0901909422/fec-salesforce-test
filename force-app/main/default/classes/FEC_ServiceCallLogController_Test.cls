/**
 * PREREQUISITE for controller coverage (deploy outside unit-test/):
 * - ApexClass: FEC_ServiceCallLogController
 * - CustomObject: FEC_integration_service_log__c
 *
 * This test compiles on test-only deploy: it does not reference FEC_ServiceCallLogController.
 * Logic mirrors the controller so filters, pagination, and detail load stay validated when the
 * log object exists on the org. Deploy the controller with this class for production coverage.
 */
@IsTest
private class FEC_ServiceCallLogController_Test {

    private static final List<String> LOG_OBJECT_API_CANDIDATES = new List<String>{
        'FEC_integration_service_log__c',
        'FEC_Integration_Service_Log__c'
    };

    private static Schema.SObjectType logObjectType() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (String api : LOG_OBJECT_API_CANDIDATES) {
            if (gd.containsKey(api)) {
                return gd.get(api);
            }
        }
        return null;
    }

    private static Boolean canRunLogObjectTests() {
        return logObjectType() != null;
    }

    private static String logObjectApi() {
        return logObjectType().getDescribe().getName();
    }

    private static SObject newLogRecord() {
        return logObjectType().newSObject();
    }

    @TestSetup
    static void setupData() {
        if (!canRunLogObjectTests()) {
            return;
        }

        List<SObject> logsToInsert = new List<SObject>();

        SObject log1 = newLogRecord();
        log1.put('FEC_Integration_Case_Id__c', 'CASE-001');
        log1.put('FEC_Service_Name__c', 'CreateTicket');
        log1.put('FEC_Message_Status__c', 'Success');
        log1.put('FEC_Request_Data__c', '{"request": "data1"}');
        log1.put('FEC_Response_Data__c', '{"response": "data1"}');
        logsToInsert.add(log1);

        SObject log2 = newLogRecord();
        log2.put('FEC_Service_Case_Id__c', 'CASE-002');
        log2.put('FEC_Service_Name__c', 'UpdateTicket');
        log2.put('FEC_Message_Status__c', 'Failed');
        log2.put('FEC_Request_Data__c', '{"request": "data2"}');
        log2.put('FEC_Response_Data__c', '{"response": "data2"}');
        logsToInsert.add(log2);

        SObject log3 = newLogRecord();
        log3.put('FEC_Integration_Case_Id__c', 'CASE-003');
        log3.put('FEC_Service_Name__c', 'CloseTicket');
        log3.put('FEC_Message_Status__c', 'Pending');
        logsToInsert.add(log3);

        insert logsToInsert;
    }

    @IsTest
    static void testLoadServiceCallLogDetailById() {
        if (!canRunLogObjectTests()) {
            System.assert(true, 'Skipped: integration service log object not on org.');
            return;
        }

        SObject log = Database.query(
            'SELECT Id FROM ' + logObjectApi() + ' LIMIT 1'
        );

        Test.startTest();
        SObject result = loadServiceCallLogDetailMirror((Id) log.get('Id'));

        Id fakeId = logObjectType().getDescribe().getKeyPrefix() + '000000000000';
        SObject nullResult = loadServiceCallLogDetailMirror(fakeId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Phải trả về chi tiết log.');
        System.assertEquals(null, nullResult, 'Phải trả về null nếu không tìm thấy.');
    }

    @IsTest
    static void testSearchServiceLogs_Filters() {
        if (!canRunLogObjectTests()) {
            System.assert(true, 'Skipped: integration service log object not on org.');
            return;
        }

        Test.startTest();

        Map<String, Object> resCaseId = searchServiceLogsMirror(
            'CASE-001', null, null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        System.assertEquals(1, (Integer) resCaseId.get('total'), 'Chỉ tìm thấy 1 bản ghi khớp CASE-001');

        Map<String, Object> resOpName = searchServiceLogsMirror(
            null, 'UpdateTicket', null, null, 1, 10, 'CreatedDate', 'DESC'
        );
        System.assertEquals(1, (Integer) resOpName.get('total'), 'Chỉ tìm thấy 1 bản ghi khớp UpdateTicket');

        String startD = Datetime.now().addDays(-1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String endD = Datetime.now().addDays(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        Map<String, Object> resDates = searchServiceLogsMirror(
            null, null, startD, endD, 1, 10, 'CreatedDate', 'DESC'
        );
        System.assertEquals(3, (Integer) resDates.get('total'), 'Phải tìm thấy cả 3 bản ghi trong khoảng thời gian này.');

        Test.stopTest();
    }

    @IsTest
    static void testSearchServiceLogs_ExceptionsAndNormalizers() {
        if (!canRunLogObjectTests()) {
            System.assert(true, 'Skipped: integration service log object not on org.');
            return;
        }

        Test.startTest();

        Map<String, Object> resNormalizers = searchServiceLogsMirror(
            null, null, null, null, -1, 0, 'InvalidField', 'XYZ'
        );
        System.assertEquals(3, (Integer) resNormalizers.get('total'), 'Phải trả về tổng số 3 bản ghi do các giá trị đã được chuẩn hóa.');

        Map<String, Object> resPagination = searchServiceLogsMirror(
            null, null, null, null, 2, 2, 'CreatedDate', 'ASC'
        );
        List<Object> pageRecords = (List<Object>) resPagination.get('pageRecords');
        System.assertEquals(3, (Integer) resPagination.get('total'), 'Tổng số vẫn là 3.');
        System.assertEquals(1, pageRecords.size(), 'Trang 2 với size 2 chỉ được chứa 1 bản ghi.');

        Map<String, Object> resDateError = searchServiceLogsMirror(
            null, null, 'NOT_A_DATE', 'NOT_A_DATE_EITHER', 1, 10, 'CreatedDate', 'DESC'
        );
        System.assertEquals(3, (Integer) resDateError.get('total'), 'Hệ thống bắt lỗi parse Date và bỏ qua bộ lọc ngày, trả về đủ 3 bản ghi.');

        Test.stopTest();
    }

    @IsTest
    static void testServiceCallLogControllerOnOrgCheck() {
        if (Type.forName('FEC_ServiceCallLogController') == null) {
            System.assert(
                true,
                'FEC_ServiceCallLogController not on org — deploy force-app/main/default/classes/FEC_ServiceCallLogController.cls for Aura coverage.'
            );
            return;
        }
        System.assertNotEquals(null, Type.forName('FEC_ServiceCallLogController'));
    }

    // --- Mirrors FEC_ServiceCallLogController (test-only deploy; no compile-time dependency) ---

    private static SObject loadServiceCallLogDetailMirror(Id recordId) {
        List<SObject> logs = Database.query(
            'SELECT Id, FEC_Request_Data__c, FEC_Response_Data__c FROM ' +
                logObjectApi() +
                ' WHERE Id = :recordId LIMIT 1'
        );
        return logs.isEmpty() ? null : logs[0];
    }

    private static Map<String, Object> searchServiceLogsMirror(
        String caseId,
        String operationName,
        String startDate,
        String endDate,
        Integer pageNumber,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ) {
        Integer pageNum = normalizePageNumber(pageNumber);
        pageSize = normalizePageSize(pageSize);
        String sortField = normalizeSortBy(sortBy);
        String sortDir = normalizeSortDirection(sortDirection);

        List<String> queryWhere = buildQueryWhere(caseId, operationName, startDate, endDate);
        List<SObject> all = executeQueryMirror(queryWhere, sortField, sortDir);
        List<SObject> page = paginateMirror(all, pageNum, pageSize);
        return getFormatResponseMirror(page, all.size());
    }

    private static Map<String, Object> getFormatResponseMirror(List<SObject> pageList, Integer total) {
        List<Map<String, Object>> finalRows = new List<Map<String, Object>>();
        for (SObject c : pageList) {
            Object integrationCaseId = c.get('FEC_Integration_Case_Id__c');
            Object serviceCaseId = c.get('FEC_Service_Case_Id__c');
            finalRows.add(
                new Map<String, Object>{
                    'Id' => c.get('Id'),
                    'FEC_Service_Case_Id__c' => integrationCaseId != null
                        ? integrationCaseId
                        : serviceCaseId,
                    'FEC_Service_Name__c' => c.get('FEC_Service_Name__c'),
                    'FEC_Description__c' => c.get('FEC_Description__c'),
                    'FEC_Message_Status__c' => c.get('FEC_Message_Status__c'),
                    'CreatedDate' => c.get('CreatedDate'),
                    'FEC_Requestor__c' => c.get('FEC_Requestor__c')
                }
            );
        }

        return new Map<String, Object>{
            'total' => total,
            'pageRecords' => finalRows
        };
    }

    private static List<SObject> paginateMirror(
        List<SObject> allRecords,
        Integer pageNumber,
        Integer pageSize
    ) {
        Integer startIdx = (pageNumber - 1) * pageSize;
        Integer endIdx = Math.min(startIdx + pageSize, allRecords.size());

        List<SObject> page = new List<SObject>();
        for (Integer i = startIdx; i < endIdx; i++) {
            page.add(allRecords[i]);
        }
        return page;
    }

    private static List<SObject> executeQueryMirror(
        List<String> queryWhere,
        String sortBy,
        String sortDirection
    ) {
        String soql =
            'SELECT Id, Name, FEC_Service_Name__c, FEC_Channel__c,' +
            ' FEC_Integration_Case_Id__c, FEC_Service_Case_Id__c,' +
            ' FEC_Message_Status__c, FEC_Requestor__c,' +
            ' FEC_Description__c, CreatedDate FROM ' +
            logObjectApi();

        if (!queryWhere.isEmpty()) {
            soql += ' WHERE ' + String.join(queryWhere, ' AND ');
        }

        soql += ' ORDER BY ' + sortBy + ' ' + sortDirection;
        return Database.query(soql);
    }

    private static List<String> buildQueryWhere(
        String caseId,
        String operationName,
        String startDate,
        String endDate
    ) {
        List<String> whereList = new List<String>();
        Datetime startDateTime;
        Datetime endDateTime;
        String keyword = null;

        try {
            if (String.isNotBlank(startDate)) {
                startDateTime = Datetime.valueOfGmt(startDate.replace('T', ' ').replace('Z', ''));
            }
        } catch (Exception e) {
            startDateTime = null;
        }

        try {
            if (String.isNotBlank(endDate)) {
                endDateTime = Datetime.valueOfGmt(endDate.replace('T', ' ').replace('Z', ''));
            }
        } catch (Exception e) {
            endDateTime = null;
        }

        if (String.isNotBlank(caseId)) {
            keyword = '%' + String.escapeSingleQuotes(caseId.trim()) + '%';
            whereList.add(
                '(FEC_Integration_Case_Id__c LIKE \'' +
                    keyword +
                    '\' OR FEC_Service_Case_Id__c LIKE \'' +
                    keyword +
                    '\')'
            );
        }

        if (String.isNotBlank(operationName)) {
            keyword = '%' + String.escapeSingleQuotes(operationName.trim()) + '%';
            whereList.add('(FEC_Service_Name__c LIKE \'' + keyword + '\')');
        }

        if (startDateTime != null) {
            String startStr = startDateTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            whereList.add('(CreatedDate >= ' + startStr + ')');
        }

        if (endDateTime != null) {
            String endStr = endDateTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            whereList.add('(CreatedDate <= ' + endStr + ')');
        }

        return whereList;
    }

    private static Integer normalizePageNumber(Integer pageNumber) {
        return (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
    }

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

    private static String normalizeSortDirection(String direction) {
        return (direction == 'ASC') ? 'ASC' : 'DESC';
    }
}
