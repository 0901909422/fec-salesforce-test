@IsTest
private class FEC_PINReissueServiceCallout_Test {

    // 1. Mock Class để giả lập phản hồi API
    public class PINReissueMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public PINReissueMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }

    @IsTest
    static void testCallPINReissue_Success() {
        // Giả lập JSON trả về thành công
        String jsonRes = '{"RespCode":"0", "TransID":"12345", "RespDesc":"Success"}';
        Test.setMock(HttpCalloutMock.class, new PINReissueMock(200, jsonRes));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse res = FEC_PINReissueServiceCallout.callPINReissue(
            '123456789', 'T123', '0901234567', true
        );
        // Kích hoạt log (nếu cần)
        FEC_PINReissueServiceCallout.logApiResponse();
        Test.stopTest();

        System.assertEquals(true, res.isSuccess, 'Kết quả phải trả về Success.');
        System.assertEquals('12345', res.TransID);
    }

    @IsTest
    static void testCallPINReissue_ErrorStatus() {
        // Giả lập lỗi server (500)
        Test.setMock(HttpCalloutMock.class, new PINReissueMock(500, 'Internal Server Error'));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse res = FEC_PINReissueServiceCallout.callPINReissue(
            '123456789', 'T123', '0901234567', true
        );
        Test.stopTest();

        System.assertEquals(false, res.isSuccess, 'Kết quả phải trả về Fail khi lỗi 500.');
        System.assertEquals('500', res.errorCode);
    }

    @IsTest
    static void testValidateRequest() {
        Test.startTest();
        // Kiểm tra trường hợp thiếu dữ liệu
        FEC_PINReissueServiceCallout.ValidationResult res1 = FEC_PINReissueServiceCallout.validateRequest('', 'T123', '090');
        FEC_PINReissueServiceCallout.ValidationResult res2 = FEC_PINReissueServiceCallout.validateRequest('123', '', '090');
        FEC_PINReissueServiceCallout.ValidationResult res3 = FEC_PINReissueServiceCallout.validateRequest('123', 'T123', '');
        FEC_PINReissueServiceCallout.ValidationResult resValid = FEC_PINReissueServiceCallout.validateRequest('123', 'T123', '090');
        Test.stopTest();

        System.assertEquals(false, res1.isValid);
        System.assertEquals(false, res2.isValid);
        System.assertEquals(false, res3.isValid);
        System.assertEquals(true, resValid.isValid);
    }

    @IsTest
    static void testCallPINReissue_Exception() {
        // Không set Mock -> gây ra ngoại lệ khi gọi calloutApi (nếu chưa config endpoint)
        // Hoặc truyền tham số ép nó lỗi
        Test.startTest();
        // Gọi với null để ép lỗi ở các dòng xử lý biến
        FEC_PINReissueServiceCallout.PINResponse res = FEC_PINReissueServiceCallout.callPINReissue(
            null, null, null, false
        );
        Test.stopTest();

        System.assertEquals(false, res.isSuccess);
        System.assertNotEquals(null, res.errorMessage);
    }
}