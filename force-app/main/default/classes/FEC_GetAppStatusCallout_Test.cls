@IsTest
private class FEC_GetAppStatusCallout_Test {

    // Mock JSON Response
    private static final String MOCK_JSON_RESPONSE = 
        '{' +
        '  "Sys": {"Code": "1", "Description": "Success", "TransID": "TXN123"},' +
        '  "Applications": [{' +
        '    "Application": {' +
        '      "AppID": "APP001", ' +
        '      "BusinessStatus": "Approved", ' +
        '      "Status": "Active"' +
        '    }' +
        '  }]' +
        '}';

    @IsTest
    static void testGetAppStatus_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_RESPONSE));

        Test.startTest();
        // Gọi service
        FEC_GetAppStatusCallout.ResultWrapper res = FEC_GetAppStatusCallout.getAppStatusWithValidation('123456', 17, '');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(true, res.isSuccess, 'Kết quả phải thành công.');
        System.assertEquals('APP001', res.applicationData.appId);
        System.assertEquals('Approved', res.applicationData.businessStatus);
    }

    @IsTest
    static void testValidateRequest_Invalid() {
        Test.startTest();
        // Test lỗi format ApplicationID (chữ thay vì số)
        FEC_GetAppStatusCallout.ResultWrapper res = FEC_GetAppStatusCallout.getAppStatusWithValidation('ABC', 17, '');
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assertEquals('VALIDATION_ERROR', res.errorCode);
    }

    @IsTest
    static void testGetAppStatus_HttpError() {
        // Thiết lập Mock trả về lỗi 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetAppStatusCallout.ResultWrapper res = FEC_GetAppStatusCallout.getAppStatusWithValidation('123456', 17, '');
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assertEquals('500', res.errorCode);
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code;
        String body;
        MockHttpResponseGenerator(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}