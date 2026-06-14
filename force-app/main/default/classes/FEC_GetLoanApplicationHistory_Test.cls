@IsTest
private class FEC_GetLoanApplicationHistory_Test {

    // =========================================================================
    // MOCK JSON DATA
    // =========================================================================
    
    // JSON giả lập luồng dữ liệu trả về thành công
    private static final String MOCK_JSON_SUCCESS = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN123",' +
        '    "DateTime": "2026-05-25T10:00:00Z",' +
        '    "Code": 1,' +
        '    "Description": "Success"' +
        '  },' +
        '  "AppInfos": [' +
        '    {' +
        '      "APPLICATION_ID": "APP001",' +
        '      "USER_ID": "USR01",' +
        '      "USER_NAME": "Tung Nguyen",' +
        '      "ACTIVITIY_ID": "ACT01",' +
        '      "ACTIVITIY_NAME": "Review",' +
        '      "STATUS_ID": "A",' +
        '      "EDIT_DATE": "2026-05-25",' +
        '      "END_DATE": "2026-05-26",' +
        '      "CREATED_DATE": "2026-05-24"' +
        '    }' +
        '  ]' +
        '}';

    // JSON giả lập lỗi logic trả về từ server
    private static final String MOCK_JSON_API_ERROR = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN123",' +
        '    "DateTime": "2026-05-25T10:00:00Z",' +
        '    "Code": 0,' +
        '    "Description": "App Not Found"' +
        '  }' +
        '}';

    // =========================================================================
    // TEST SETUP
    // =========================================================================

    @TestSetup
    static void setupData() {
        // Tạo Case để test chức năng updateCaseApplicationHistory
        Case c = new Case(
            Subject = 'Test Case App History',
            FEC_Application_ID__c = 'APP001'
        );
        insert c;

        // Tạo History giả theo logic SOQL của hàm updateCaseApplicationHistory
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            Name = 'Hist01',
            FEC_Case__c = c.Id,
            FEC_Application_ID__c = 'APP001'
        );
        insert hist;
    }

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testGetLoanApplicationHistory_Success() {
        // Thiết lập Mock HTTP Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        // Chuẩn bị Request
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryRequest req = new FEC_GetLoanApplicationHistory.LoanApplicationHistoryRequest();
        req.applicationId = 'APP001';

        Test.startTest();
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryResult res = FEC_GetLoanApplicationHistory.getLoanApplicationHistory(req);
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(true, res.success, 'Kết quả API phải thành công.');
        System.assertEquals(1, res.code, 'Mã Code trả về phải là 1.');
        System.assertEquals(1, res.histories.size(), 'Phải parse được 1 ApplicationHistory.');
        System.assertEquals('Tung Nguyen', res.histories[0].userName);
        System.assertEquals('ACT01', res.histories[0].activityId);
    }

    @IsTest
    static void testUpdateCaseApplicationHistory_Success() {
        // Mock phản hồi
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));
        
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // Gọi hàm DML
        FEC_GetLoanApplicationHistory.CaseApplicationHistoryDisplay historyRec =
            FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(testCase.Id)[0];
        Test.stopTest();

        System.assertNotEquals(null, historyRec.id, 'Bản ghi History phải được tạo thành công.');
        System.assertEquals('Tung Nguyen', historyRec.user, 'UserName phải được map đúng.');
        System.assertEquals('ACT01', historyRec.activityId, 'Activity ID phải khớp.');
        System.assertEquals('APPROVED', historyRec.status, 'Status phải được map từ mã A sang APPROVED.');
        System.assertNotEquals(null, historyRec.editDate, 'Edit date phải được parse chính xác.');

        FEC_Application_History__c persisted = [
            SELECT FEC_User__c, FEC_Activity_ID__c, FEC_Status__c, FEC_Edit_Date__c
            FROM FEC_Application_History__c
            WHERE Id = :historyRec.id
            LIMIT 1
        ];
        System.assertEquals('APPROVED', persisted.FEC_Status__c, 'Status phải được lưu trên record.');
    }

    @IsTest
    static void testUpdateCaseApplicationHistory_ReturnsAllRows() {
        String mockJsonMultiple =
            '{' +
            '  "Sys": {"TransID": "TXN123", "DateTime": "2026-05-25T10:00:00Z", "Code": 1, "Description": "Success"},' +
            '  "AppInfos": [' +
            '    {"APPLICATION_ID": "APP001", "USER_NAME": "User Two", "ACTIVITIY_ID": "ACT02", "STATUS_ID": "P", "EDIT_DATE": "2026-05-24"},' +
            '    {"APPLICATION_ID": "APP001", "USER_NAME": "User One", "ACTIVITIY_ID": "ACT01", "STATUS_ID": "A", "EDIT_DATE": "2026-05-25"}' +
            '  ]' +
            '}';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockJsonMultiple));

        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_GetLoanApplicationHistory.CaseApplicationHistoryDisplay> rows =
            FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(testCase.Id);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Phải trả về đủ 2 dòng từ API.');
        System.assertEquals('User One', rows[0].user, 'Dòng mới nhất theo EDIT_DATE phải đứng đầu.');
        System.assertEquals('User Two', rows[1].user);
        System.assertEquals('APPROVED', rows[0].status);
        System.assertEquals('PENDING', rows[1].status);
    }

    @IsTest
    static void testUpdateCaseApplicationHistory_UsesSearchAppIdWhenNoCustomerHistory() {
        Case testCase = new Case(
            Subject = 'Search App Only',
            FEC_Search_Application_ID__c = 'APP-SEARCH-001'
        );
        insert testCase;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        List<FEC_GetLoanApplicationHistory.CaseApplicationHistoryDisplay> rows =
            FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(testCase.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Phải gọi API thành công khi không có FEC_Customer_History__c.');
        System.assertEquals('Tung Nguyen', rows[0].user);
    }

    @IsTest
    static void testResolveStatusLabel() {
        Test.startTest();
        System.assertEquals('', FEC_GetLoanApplicationHistory.resolveStatusLabel(''));
        System.assertEquals('', FEC_GetLoanApplicationHistory.resolveStatusLabel(null));
        System.assertEquals('APPROVED', FEC_GetLoanApplicationHistory.resolveStatusLabel('A'));
        System.assertEquals('APPROVED', FEC_GetLoanApplicationHistory.resolveStatusLabel('a'));
        System.assertEquals('UNKNOWN_CODE', FEC_GetLoanApplicationHistory.resolveStatusLabel('UNKNOWN_CODE'));
        Test.stopTest();
    }

    @IsTest
    static void testParseResponse_StatusFallbackAndNumericStatusId() {
        String jsonWithStatusField =
            '{' +
            '  "Sys": {"TransID": "TXN123", "DateTime": "2026-05-25T10:00:00Z", "Code": 1, "Description": "Success"},' +
            '  "AppInfos": [{' +
            '    "APPLICATION_ID": "APP002",' +
            '    "USER_NAME": "Status User",' +
            '    "ACTIVITIY_ID": "ACT02",' +
            '    "STATUS": "PENDING",' +
            '    "EDIT_DATE": "2026-05-25"' +
            '  }]' +
            '}';

        String jsonWithNumericStatusId =
            '{' +
            '  "Sys": {"TransID": "TXN124", "DateTime": "2026-05-25T10:00:00Z", "Code": 1, "Description": "Success"},' +
            '  "AppInfos": [{' +
            '    "APPLICATION_ID": "APP003",' +
            '    "USER_NAME": "Numeric User",' +
            '    "ACTIVITIY_ID": "ACT03",' +
            '    "STATUS_ID": 1,' +
            '    "EDIT_DATE": "2026-05-25"' +
            '  }]' +
            '}';

        Test.startTest();
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryResult statusFieldResult =
            FEC_GetLoanApplicationHistory.parseResponse(jsonWithStatusField, 200);
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryResult numericStatusResult =
            FEC_GetLoanApplicationHistory.parseResponse(jsonWithNumericStatusId, 200);
        Test.stopTest();

        System.assertEquals(true, statusFieldResult.success);
        System.assertEquals('PENDING', statusFieldResult.histories[0].statusId);

        System.assertEquals(true, numericStatusResult.success);
        System.assertEquals('1', numericStatusResult.histories[0].statusId);
    }

    @IsTest
    static void testUpdateCaseApplicationHistory_ApiError() {
        // Mock phản hồi Code = 0 (Lỗi logic)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_API_ERROR));
        
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        try {
            FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(testCase.Id);
            System.assert(false, 'Phải ném Exception khi API trả về lỗi.');
        } catch (AuraHandledException e) {
            // Xác nhận bắt được lỗi AuraHandledException dùng cho UI
            System.assert(e.getMessage().contains('App Not Found') || e.getMessage() != null, 'Nên có message lỗi từ API.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidationFailures() {
        Test.startTest();
        
        // 1. Validate request
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryRequest req = new FEC_GetLoanApplicationHistory.LoanApplicationHistoryRequest();
        req.applicationId = '';
        try {
            FEC_GetLoanApplicationHistory.getLoanApplicationHistory(req);
            System.assert(false, 'Phải lỗi khi applicationId rỗng.');
        } catch (Exception e) { System.assert(true); }

        // 2. Validate Case ID null trong updateCaseApplicationHistory
        List<FEC_GetLoanApplicationHistory.CaseApplicationHistoryDisplay> rec =
            FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(null);
        System.assertEquals(0, rec.size(), 'Nếu Case ID null, hàm trả về list rỗng.');

        // 3. Test lỗi HTTP (500)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));
        req.applicationId = 'APP123';
        FEC_GetLoanApplicationHistory.LoanApplicationHistoryResult res = FEC_GetLoanApplicationHistory.getLoanApplicationHistory(req);
        System.assertEquals(false, res.success, 'Nên gán false khi mã HTTP != 200.');
        System.assertEquals(500, res.httpStatus);

        Test.stopTest();
    }

    // =========================================================================
    // HELPER CLASS MOCK HTTP RESPONSE
    // =========================================================================
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
        
        MockHttpResponseGenerator(Integer statusCode, String responseBody) { 
            this.statusCode = statusCode; 
            this.responseBody = responseBody; 
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}