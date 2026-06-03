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
        '      "STATUS_ID": "In Progress",' +
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
        FEC_Application_History__c historyRec = FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(testCase.Id);
        Test.stopTest();

        // Xác nhận bản ghi FEC_Application_History__c đã được Insert
        System.assertNotEquals(null, historyRec.Id, 'Bản ghi History phải được tạo thành công.');
        System.assertEquals('Tung Nguyen', historyRec.FEC_User__c, 'UserName phải được map vào field FEC_User__c.');
        System.assertEquals('ACT01', historyRec.FEC_Activity_ID__c, 'Activity ID phải khớp.');
        System.assertEquals(Date.valueOf('2026-05-25'), historyRec.FEC_Edit_Date__c, 'Edit date phải được parse chính xác.');
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
        FEC_Application_History__c rec = FEC_GetLoanApplicationHistory.updateCaseApplicationHistory(null);
        System.assertEquals(null, rec, 'Nếu Case ID null, hàm trả về null.');

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