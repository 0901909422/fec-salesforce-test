@IsTest
private class FEC_GetDNBCalloutService_Test {

    // =========================================================================
    // DỮ LIỆU MOCK JSON
    // =========================================================================
    
    // 1. Phản hồi thành công (code = "0")
    private static final String MOCK_JSON_SUCCESS = 
        '{' +
        '  "sys": {' +
        '    "code": "0",' +
        '    "message": "Success",' +
        '    "trans_id": "TXN12345"' +
        '  },' +
        '  "result": [' +
        '    {' +
        '      "nid": "123456789",' +
        '      "do_not_bother": true,' +
        '      "full_name": "Nguyen Van A",' +
        '      "reason": "Customer requested"' +
        '    }' +
        '  ]' +
        '}';

    // 2. Phản hồi lỗi nghiệp vụ từ API (code != "0")
    private static final String MOCK_JSON_BUSINESS_ERROR = 
        '{' +
        '  "sys": {' +
        '    "code": "1",' +
        '    "message": "Invalid input param",' +
        '    "trans_id": "TXN12345",' +
        '    "list_invalid": ["phone"]' +
        '  }' +
        '}';

    // 3. Phản hồi thiếu block "sys"
    private static final String MOCK_JSON_MISSING_SYS = 
        '{' +
        '  "result": []' +
        '}';

    // =========================================================================
    // TEST SETUP
    // =========================================================================
    @TestSetup
    static void setupData() {
        // Thiết lập Custom Setting để tránh lỗi Endpoint bị Null
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn'
        );
        insert apiSetting;
    }

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testGetDNB_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        // Chuẩn bị Request
        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = '0901234567';
        req.nid = '123456789';
        req.email = null; // Kiểm tra logic tự động gán '' khi email null

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_GetDNBCalloutService.getDNB(req);
        Test.stopTest();

        // Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals(true, res.success, 'Kết quả API phải thành công.');
        System.assertEquals('0', res.sys2.code, 'Mã Code trả về phải là 0.');
        System.assertEquals(1, res.result.size(), 'Phải chứa 1 bản ghi ResultItem.');
        System.assertEquals(true, res.result[0].do_not_bother, 'Trường do_not_bother phải được map đúng.');
        System.assertEquals('123456789', res.result[0].nid);
    }

    @IsTest
    static void testGetDNB_BusinessError() {
        // Giả lập API gọi thành công nhưng trả về code = 1 kèm list_invalid
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_BUSINESS_ERROR));

        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = 'invalid_phone';
        req.nid = '123456789';

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_GetDNBCalloutService.getDNB(req);
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(false, res.success, 'Kết quả phải thất bại do Code khác 0.');
        System.assert(res.errorMessage.contains('Invalid input param'), 'Lỗi phải chứa message từ server.');
        System.assert(res.errorMessage.contains('phone'), 'Lỗi phải nối thêm phần tử từ list_invalid.');
    }

    @IsTest
    static void testGetDNB_HttpError() {
        // Giả lập lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = '0901234567';
        req.nid = '123456789';

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_GetDNBCalloutService.getDNB(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assert(res.errorMessage.contains('500'), 'Lỗi phải chứa HTTP Status code.');
    }

    @IsTest
    static void testGetDNB_MissingSys() {
        // Giả lập JSON không chứa node "sys"
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_MISSING_SYS));

        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = '0901234567';
        req.nid = '123456789';

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_GetDNBCalloutService.getDNB(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals(System.Label.FEC_CS_CASE_SYS_MISSING_MSG, res.errorMessage, 'Phải báo lỗi thiếu sys block.');
    }

    @IsTest
    static void testGetDNB_ParseError() {
        // Giả lập JSON lỗi cú pháp để ép throw Exception trong khối try-catch
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{ invalid json ]'));

        FEC_GetDNBCalloutService.DNBRequest req = new FEC_GetDNBCalloutService.DNBRequest();
        req.phone = '0901234567';
        req.nid = '123456789';

        Test.startTest();
        FEC_GetDNBCalloutService.DNBResult res = FEC_GetDNBCalloutService.getDNB(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.errorMessage, 'Phải bắt được ngoại lệ JSONException.');
    }

    @IsTest
    static void testValidationFailures() {
        Test.startTest();
        
        // 1. Request bị Null
        FEC_GetDNBCalloutService.DNBResult res1 = FEC_GetDNBCalloutService.getDNB(null);
        System.assertEquals(false, res1.success);
        System.assertEquals(System.Label.FEC_CS_CASE_STATUS_REQUEST_INVALID_MSG, res1.errorMessage);

        // 2. Thiếu Phone
        FEC_GetDNBCalloutService.DNBRequest req2 = new FEC_GetDNBCalloutService.DNBRequest();
        req2.phone = '';
        req2.nid = '123456';
        FEC_GetDNBCalloutService.DNBResult res2 = FEC_GetDNBCalloutService.getDNB(req2);
        System.assertEquals(false, res2.success);
        System.assertEquals(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG, res2.errorMessage);

        // 3. Thiếu NID
        FEC_GetDNBCalloutService.DNBRequest req3 = new FEC_GetDNBCalloutService.DNBRequest();
        req3.phone = '0901234567';
        req3.nid = '';
        FEC_GetDNBCalloutService.DNBResult res3 = FEC_GetDNBCalloutService.getDNB(req3);
        System.assertEquals(false, res3.success);
        System.assertEquals(System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG, res3.errorMessage);

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