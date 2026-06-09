@IsTest
private class FEC_ReplacementCardCallout_Test {

    // 1. Mock class giả lập phản hồi HTTP
    public class ReplacementCardMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public ReplacementCardMock(Integer statusCode, String responseBody) {
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
    static void testCallReplaceCard_Success() {
        // Giả lập JSON phản hồi thành công (Code = '1' dựa theo logic isSuccess của bạn)
        String jsonRes = '{"AccountNumber":"123", "Sys2":{"Code":"1", "Description":"Success"}}';
        Test.setMock(HttpCalloutMock.class, new ReplacementCardMock(200, jsonRes));

        Test.startTest();
        FEC_ReplacementCardCallout.ReplaceCardResponse res = FEC_ReplacementCardCallout.callReplaceCard(
            'T1', 'REQ1', 'BLK', '1234', 'Y', 'ACC123'
        );
        FEC_ReplacementCardCallout.logApiResponse(); // Cover phương thức log
        Test.stopTest();

        System.assertEquals(true, FEC_ReplacementCardCallout.isSuccess(res), 'Kết quả phải thành công.');
        System.assertEquals('1', res.Sys2.Code);
    }

    @IsTest
    static void testCallReplaceCard_HttpError() {
        // Giả lập lỗi 500
        Test.setMock(HttpCalloutMock.class, new ReplacementCardMock(500, 'Server Error'));

        Test.startTest();
        FEC_ReplacementCardCallout.ReplaceCardResponse res = FEC_ReplacementCardCallout.callReplaceCard(
            'T1', 'REQ1', 'BLK', '1234', 'Y', 'ACC123'
        );
        Test.stopTest();

        System.assertEquals('500', res.errorCode, 'Mã lỗi phải là 500.');
    }

    @IsTest
    static void testValidateRequest_InvalidCases() {
        Test.startTest();
        // Test thiếu TransID
        FEC_ReplacementCardCallout.ValidationResult res1 = FEC_ReplacementCardCallout.validateRequest('', 'R', 'B', '1234', 'Y', 'A');
        System.assertEquals(false, res1.isValid);

        // Test thiếu AccountNumber
        FEC_ReplacementCardCallout.ValidationResult res2 = FEC_ReplacementCardCallout.validateRequest('T', 'R', 'B', '1234', 'Y', '');
        System.assertEquals(false, res2.isValid);

        // Test quá độ dài (AccountNumber > 255)
        FEC_ReplacementCardCallout.ValidationResult res3 = FEC_ReplacementCardCallout.validateRequest('T', 'R', 'B', '1234', 'Y', 'A'.repeat(256));
        System.assertEquals(false, res3.isValid);
        
        // Test Valid
        FEC_ReplacementCardCallout.ValidationResult resValid = FEC_ReplacementCardCallout.validateRequest('T', 'R', 'B', '1234', 'Y', 'ACC');
        System.assertEquals(true, resValid.isValid);
        Test.stopTest();
    }

    @IsTest
    static void testCallReplaceCard_Exception() {
        // Gọi với tham số null để ép ngoại lệ trong try-catch (do lỗi trong JSON serialize hoặc callout)
        Test.startTest();
        FEC_ReplacementCardCallout.ReplaceCardResponse res = FEC_ReplacementCardCallout.callReplaceCard(
            null, null, null, null, null, null
        );
        Test.stopTest();
        
        System.assertEquals('CALLOUT_ERROR', res.errorCode);
    }
}