@IsTest
private class FEC_GetCusSaleDisburseInfoCallout_Test {

    // JSON Mock mô phỏng phản hồi thành công từ API
    // Chú ý: API trả về "DateTime" nhưng class sẽ tự động replace thành "DateTime_x" trước khi deserialize
    private static final String MOCK_JSON_SUCCESS = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN-12345",' +
        '    "DateTime": "2026-10-25T10:00:00.000Z",' +
        '    "Code": 1,' +
        '    "Description": "Success"' +
        '  },' +
        '  "CustomerSaleInfos": [' +
        '    {' +
        '      "APPLICATION_ID": "APP001",' +
        '      "BANK_NAME": "TEST BANK",' +
        '      "DISB_AMT": 50000000.00,' +
        '      "DISB_STATUS": "Disbursed"' +
        '    }' +
        '  ]' +
        '}';

    // JSON Mock mô phỏng API trả về mã lỗi logic (Code = 0)
    private static final String MOCK_JSON_LOGIC_ERROR = 
        '{' +
        '  "Sys": {' +
        '    "TransID": "TXN-12345",' +
        '    "DateTime": "2026-10-25T10:00:00.000Z",' +
        '    "Code": 0,' +
        '    "Description": "Application Not Found"' +
        '  }' +
        '}';

    @IsTest
    static void testGetCustomerSaleDisburseInfo_Success() {
        // Thiết lập Mock cho HTTP Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        // Gọi hàm chính (bao gồm validation và convert)
        FEC_GetCustomerSaleDisburseInfoCallout.ResultWrapper res = 
            FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfoWithValidation('APP001');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(true, res.isSuccess, 'Kết quả phải thành công.');
        System.assertEquals('TXN-12345', res.transId, 'TransID phải khớp với Mock.');
        System.assertNotEquals(null, res.salesInfo, 'Dữ liệu salesInfo không được null.');
        System.assertEquals('APP001', res.salesInfo.applicationId, 'Application ID phải khớp.');
        System.assertEquals('TEST BANK', res.salesInfo.bankName, 'Bank Name phải khớp.');
        System.assertEquals(50000000.00, res.salesInfo.disbAmt, 'Số tiền giải ngân phải khớp.');
    }

    @IsTest
    static void testGetCustomerSaleDisburseInfo_ValidationError() {
        Test.startTest();
        // Gọi hàm với Application ID rỗng để kích hoạt lỗi Validation
        FEC_GetCustomerSaleDisburseInfoCallout.ResultWrapper res = 
            FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfoWithValidation('');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(false, res.isSuccess, 'Kết quả phải thất bại do validation.');
        System.assertEquals('VALIDATION_ERROR', res.errorCode, 'Mã lỗi phải là VALIDATION_ERROR.');
    }

    @IsTest
    static void testGetCustomerSaleDisburseInfo_HttpError() {
        // Giả lập lỗi HTTP 500 từ Server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetCustomerSaleDisburseInfoCallout.ResultWrapper res = 
            FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfoWithValidation('APP001');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(false, res.isSuccess, 'Kết quả phải thất bại do lỗi HTTP.');
        System.assertEquals('500', res.errorCode, 'Mã lỗi phải chứa HTTP Status Code.');
    }

    @IsTest
    static void testGetCustomerSaleDisburseInfo_ApiLogicError() {
        // Giả lập API gọi thành công (HTTP 200) nhưng trả về Code = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_LOGIC_ERROR));

        Test.startTest();
        FEC_GetCustomerSaleDisburseInfoCallout.ResultWrapper res = 
            FEC_GetCustomerSaleDisburseInfoCallout.getCustomerSaleDisburseInfoWithValidation('APP001');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(false, res.isSuccess, 'Kết quả phải thất bại do Code != 1.');
        System.assert(res.errorMessage.contains('Application Not Found'), 'Message lỗi phải chứa Description từ API.');
    }

    @IsTest
    static void testHelperAndDirectMethods() {
        Test.startTest();
        
        // 1. Kiểm tra validateRequestHeaders trực tiếp
        FEC_GetCustomerSaleDisburseInfoCallout.ValidationResult headerVal1 = 
            FEC_GetCustomerSaleDisburseInfoCallout.validateRequestHeaders('', '2026-10-25T10:00:00.000Z', 'CRM');
        System.assertEquals(false, headerVal1.isValid, 'Phải false vì thiếu TransID.');

        FEC_GetCustomerSaleDisburseInfoCallout.ValidationResult headerVal2 = 
            FEC_GetCustomerSaleDisburseInfoCallout.validateRequestHeaders('TXN123', 'invalid-date', 'CRM');
        System.assertEquals(false, headerVal2.isValid, 'Phải false vì sai format Date.');

        // 2. Kiểm tra isSuccess và getFirstSaleInfo khi truyền null
        Boolean isSucc = FEC_GetCustomerSaleDisburseInfoCallout.isSuccess(null);
        System.assertEquals(false, isSucc);

        FEC_GetCustomerSaleDisburseInfoCallout.CustomerSaleInfo firstInfo = 
            FEC_GetCustomerSaleDisburseInfoCallout.getFirstSaleInfo(null);
        System.assertEquals(null, firstInfo);

        Test.stopTest();
    }

    // Helper class để Mock HTTP Callout
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