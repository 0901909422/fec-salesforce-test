@IsTest
private class FEC_GetDisbInfoByAcctCallout_Test {

    // =========================================================================
    // DỮ LIỆU MOCK JSON
    // =========================================================================
    
    // 1. Phản hồi thành công (Code = "1")
    private static final String MOCK_JSON_SUCCESS = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN12345",' +
        '    "DateTime": "2026-05-25T10:00:00.000Z",' +
        '    "Code": "1",' +
        '    "Description": "Success"' +
        '  },' +
        '  "Applications": [' +
        '    {' +
        '      "Application": {' +
        '        "AccountNumber": "ACC999",' +
        '        "ApplicationID": "APP123",' +
        '        "DisbAmount": "50000000",' +
        '        "DisbStatus": "Completed"' +
        '      }' +
        '    }' +
        '  ]' +
        '}';

    // 2. Phản hồi lỗi nghiệp vụ API (Code = "0")
    private static final String MOCK_JSON_BUSINESS_ERROR = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN12345",' +
        '    "DateTime": "2026-05-25T10:00:00.000Z",' +
        '    "Code": "0",' +
        '    "Description": "Account Not Found"' +
        '  }' +
        '}';

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testGetDisbInfoByAcct_Success() {
        // Thiết lập Mock Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        // Gọi phương thức chính tích hợp validation
        FEC_GetDisbInfoByAcctCallout.ResultWrapper res = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctWithValidation('ACC999', 30);
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(true, res.isSuccess, 'Kết quả API phải thành công.');
        System.assertEquals('TXN12345', res.transId, 'TransID phải khớp với mock.');
        System.assertEquals('1', res.sysCode2, 'Mã Code2 sau khi replace phải là 1.');
        System.assertEquals(1, res.applications.size(), 'Phải chứa 1 bản ghi application.');
        System.assertEquals('APP123', res.applications[0].applicationId);
        System.assertEquals('Completed', res.applications[0].disbStatus);

        // Gọi logApiResponse để đạt độ phủ mã cho tính năng Stash Log
        FEC_GetDisbInfoByAcctCallout.logApiResponse();
    }

    @IsTest
    static void testGetDisbInfoByAcct_BusinessError() {
        // Giả lập API trả về 200 OK nhưng Code nghiệp vụ = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_BUSINESS_ERROR));

        Test.startTest();
        FEC_GetDisbInfoByAcctCallout.ResultWrapper res = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctWithValidation('ACC999', 30);
        Test.stopTest();

        System.assertEquals(false, res.isSuccess, 'Kết quả phải thất bại do Code = 0.');
        System.assertEquals('0', res.errorCode);
        System.assert(res.errorMessage.contains('Account Not Found'), 'Lỗi phải chứa Description từ server.');
    }

    @IsTest
    static void testGetDisbInfoByAcct_HttpError() {
        // Giả lập lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetDisbInfoByAcctCallout.ResultWrapper res = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctWithValidation('ACC999', 30);
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assertEquals('500', res.errorCode);
    }

    @IsTest
    static void testParseError_InvalidJson() {
        // Giả lập JSON lỗi cú pháp
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{ invalid_json ]'));

        Test.startTest();
        FEC_GetDisbInfoByAcctCallout.ResultWrapper res = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctWithValidation('ACC999', null);
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assertEquals('JSON_PARSE_ERROR', res.errorCode, 'Phải bắt được ngoại lệ JSONException.');
    }

    @IsTest
    static void testValidationFailures() {
        Test.startTest();

        // 1. Validation AccountNumber
        FEC_GetDisbInfoByAcctCallout.ValidationResult valAcct = 
            FEC_GetDisbInfoByAcctCallout.validateRequest('');
        System.assertEquals(false, valAcct.isValid, 'AccountNumber trống phải bị lỗi.');

        // 2. Validation Headers (Thiếu TransId)
        FEC_GetDisbInfoByAcctCallout.ValidationResult valHdr1 = 
            FEC_GetDisbInfoByAcctCallout.validateRequestHeaders('', '2026-05-25T10:00:00.000Z', 'CRM');
        System.assertEquals(false, valHdr1.isValid, 'TransId trống phải bị lỗi.');

        // 3. Validation Headers (Sai format Date)
        FEC_GetDisbInfoByAcctCallout.ValidationResult valHdr2 = 
            FEC_GetDisbInfoByAcctCallout.validateRequestHeaders('TXN1', 'sai-dinh-dang', 'CRM');
        System.assertEquals(false, valHdr2.isValid, 'Sai format DateTime phải bị lỗi.');

        // 4. Kích hoạt Validation Logic trong Execution Result
        FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctExecutionResult execRes1 =
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcctExecutionResult('', null);
        System.assertNotEquals(null, execRes1.logErrorMessage);

        FEC_GetDisbInfoByAcctCallout.logApiResponse();
        Test.stopTest();
    }

    @IsTest
    static void testOverloadedMethods() {
        // Mock success để test các hàm overload
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));
        
        Test.startTest();
        
        // Gọi các method Overload để phủ code (Coverage)
        FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctResponse res1 = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcct('ACC123', 10);
            
        FEC_GetDisbInfoByAcctCallout.GetDisbInfoByAcctResponse res2 = 
            FEC_GetDisbInfoByAcctCallout.getDisbInfoByAcct('ACC123', 10, true);
            
        System.assertEquals('1', res1.Sys2.Code2);
        System.assertEquals('1', res2.Sys2.Code2);

        Test.stopTest();
    }

    // =========================================================================
    // HELPER MOCK HTTP
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