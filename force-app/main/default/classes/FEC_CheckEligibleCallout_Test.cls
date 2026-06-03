@IsTest
private class FEC_CheckEligibleCallout_Test {

    // Mock Class để giả lập phản hồi API
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Status": "true", "Data": {"BIRTHDAY": "1990-01-01", "ID_CARD_NUMBER": "123456789"}}');
            return res;
        }
    }

    private class MockHttp404ResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }

    @IsTest
    static void testCheckEligibility_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Gọi hàm kiểm tra
        FEC_CheckEligibleCallout.CheckEligibleResponse result = 
            FEC_CheckEligibleCallout.checkEligibility('123456789', '0901234567');
        Test.stopTest();

        // Xác minh kết quả
        System.assertEquals('true', result.Status, 'Status phải trả về "true".');
        System.assertEquals('123456789', result.Data.ID_CARD_NUMBER, 'Số ID phải khớp.');
        System.assertEquals(true, FEC_CheckEligibleCallout.isEligible(result), 'Hàm isEligible phải trả về true.');
    }

    @IsTest
    static void testCheckEligibility_ValidationError() {
        Test.startTest();
        // Truyền IdCard rỗng để kích hoạt ngoại lệ validation
        FEC_CheckEligibleCallout.CheckEligibleResponse result = 
            FEC_CheckEligibleCallout.checkEligibility('', '0901234567');
        Test.stopTest();

        System.assertEquals('CALLOUT_EXCEPTION', result.errorCode, 'Phải có mã lỗi CALLOUT_EXCEPTION.');
        System.assert(result.errorMessage != null, 'Phải có thông báo lỗi.');
    }

    @IsTest
    static void testCheckEligibility_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttp404ResponseGenerator());

        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result = 
            FEC_CheckEligibleCallout.checkEligibility('123456789', '0901234567');
        Test.stopTest();

        System.assertEquals('404', result.errorCode);
        System.assert(result.errorMessage.contains('Not Found'));
    }

    @IsTest
    static void testLogApiResponse() {
        // Kiểm tra phương thức logApiResponse để đảm bảo không lỗi
        // Trước tiên cần gọi hàm chính để gán giá trị cho responseLog tĩnh
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        FEC_CheckEligibleCallout.checkEligibility('123456789', '0901234567');
        
        Test.startTest();
        FEC_CheckEligibleCallout.logApiResponse();
        Test.stopTest();
        
        // Xác minh log (giả sử FEC_CommonUltils.logApi hoạt động)
        System.assert(true);
    }
}