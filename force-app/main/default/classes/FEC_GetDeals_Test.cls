@IsTest
private class FEC_GetDeals_Test {

    // JSON Mock mô phỏng phản hồi thành công từ API
    private static final String MOCK_JSON_SUCCESS = 
        '{' +
        '  "Sys": {"TransID": "TXN123", "dateTimeStr": "2026-03-02T10:00:00Z"},' +
        '  "totalDeal": 1,' +
        '  "pageNumber": 1,' +
        '  "totalPage": 1,' +
        '  "errorCode": "00",' +
        '  "errorMessage": "Success",' +
        '  "result": [' +
        '    {' +
        '      "dealId": 101,' +
        '      "dealName": "Giảm giá 50% Highlands Coffee",' +
        '      "categoryId": 1,' +
        '      "categoryName": "F&B",' +
        '      "price": 25000.0,' +
        '      "originalPrice": 50000.0,' +
        '      "startDate": "2026-03-01T00:00:00Z",' +
        '      "expiredDate": "2026-03-31T23:59:59Z",' +
        '      "status": 1,' +
        '      "address": [' +
        '        {' +
        '          "id": 1,' +
        '          "name": "Highlands Láng Hạ",' +
        '          "address": "123 Láng Hạ, Đống Đa, Hà Nội"' +
        '        }' +
        '      ]' +
        '    }' +
        '  ]' +
        '}';

    @IsTest
    static void testCallGetDeals_Success() {
        // Thiết lập Mock cho HTTP Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_SUCCESS));

        Test.startTest();
        // Gọi hàm chính với các tham số hợp lệ
        FEC_GetDeals.GetDealsResponse res = FEC_GetDeals.callGetDeals(10, 1, 5, 20);
        Test.stopTest();

        // Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals('00', res.errorCode, 'Mã lỗi phải là 00 (Thành công).');
        System.assertEquals(1, res.totalDeal, 'Tổng số deal phải là 1.');
        System.assertEquals(1, res.result.size(), 'Phải có 1 deal trong danh sách result.');
        
        // Kiểm tra chi tiết Deal và Address để đảm bảo wrapper mapping đúng
        FEC_GetDeals.Deal firstDeal = res.result[0];
        System.assertEquals(101, firstDeal.dealId);
        System.assertEquals('Giảm giá 50% Highlands Coffee', firstDeal.dealName);
        System.assertEquals(1, firstDeal.address.size());
        System.assertEquals('Highlands Láng Hạ', firstDeal.address[0].name);
    }

    @IsTest
    static void testCallGetDeals_HttpError() {
        // Giả lập lỗi HTTP 500 từ Server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetDeals.GetDealsResponse res = FEC_GetDeals.callGetDeals(10, 1, null, null);
        Test.stopTest();

        // Xác thực kết quả xử lý lỗi
        System.assertEquals('500', res.errorCode, 'Mã lỗi phải bắt được HTTP Status Code.');
        System.assertEquals('Internal Server Error', res.errorMessage, 'Message lỗi phải chứa body từ server.');
    }

    @IsTest
    static void testCallGetDeals_Exception() {
        // Không set Mock để ép CalloutException (Uncommitted work pending hoặc Callout không được phép)
        // Hoặc truyền JSON sai định dạng để ép JSONException
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{ invalid_json ]'));

        Test.startTest();
        FEC_GetDeals.GetDealsResponse res = FEC_GetDeals.callGetDeals(10, 1, null, null);
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals('CALLOUT_ERROR', res.errorCode, 'Ngoại lệ phải được bắt và gán mã CALLOUT_ERROR.');
        System.assertNotEquals(null, res.errorMessage, 'Phải có nội dung lỗi.');
    }

    @IsTest
    static void testValidateRequest() {
        Test.startTest();
        
        // Test 1: PageSize null hoặc <= 0
        FEC_GetDeals.ValidationResult val1 = FEC_GetDeals.validateRequest(0, 1);
        System.assertEquals(false, val1.isValid, 'Phải invalid khi pageSize <= 0');

        // Test 2: PageNumber null hoặc <= 0
        FEC_GetDeals.ValidationResult val2 = FEC_GetDeals.validateRequest(10, 0);
        System.assertEquals(false, val2.isValid, 'Phải invalid khi pageNumber <= 0');

        // Test 3: Hợp lệ
        FEC_GetDeals.ValidationResult val3 = FEC_GetDeals.validateRequest(10, 1);
        System.assertEquals(true, val3.isValid, 'Phải valid khi các tham số đúng chuẩn.');
        
        Test.stopTest();
    }

    @IsTest
    static void testIsSuccess() {
        Test.startTest();
        
        FEC_GetDeals.GetDealsResponse res = new FEC_GetDeals.GetDealsResponse();
        res.errorCode = '00';
        System.assertEquals(true, FEC_GetDeals.isSuccess(res), 'Hàm isSuccess phải trả về true khi errorCode là 00.');
        
        res.errorCode = '01';
        System.assertEquals(false, FEC_GetDeals.isSuccess(res), 'Hàm isSuccess phải trả về false khi errorCode khác 00.');
        
        System.assertEquals(false, FEC_GetDeals.isSuccess(null), 'Hàm isSuccess phải trả về false khi response null.');

        Test.stopTest();
    }

    // Helper class để Mock HTTP Response
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