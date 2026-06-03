@IsTest
private class FEC_GetCardPaymentInfo_Test {

    // XML mẫu giả lập phản hồi thành công từ server
    private static final String MOCK_SUCCESS_XML = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <cif:GetCardPaymentInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <Code>0</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <PaymentInfo>' +
        '        <FullPaymentAmount>500000</FullPaymentAmount>' +
        '      </PaymentInfo>' +
        '    </cif:GetCardPaymentInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testGetCardPaymentInfo_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_SUCCESS_XML));

        Test.startTest();
        // Giả lập ngày gọi là hôm nay
        FEC_GetCardPaymentInfo.CardPaymentResult res = FEC_GetCardPaymentInfo.getCardPaymentInfo('ACC123456', Date.today());
        Test.stopTest();

        // Xác thực kết quả
        System.assertNotEquals(null, res);
        System.assertEquals(500000, res.fullPaymentAmount);
        System.assertEquals('TXN123', res.transId);
    }

    @IsTest
    static void testValidateRequest_InvalidAccountNumber() {
        Test.startTest();
        try {
            // Test AccountNumber rỗng sẽ gây lỗi validation trong validateRequest
            FEC_GetCardPaymentInfo.getCardPaymentInfo('', Date.today());
            System.assert(false, 'Hệ thống phải báo lỗi khi AccountNumber trống.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetCardPaymentInfo_HttpError() {
        // Mock phản hồi lỗi 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetCardPaymentInfo.getCardPaymentInfo('ACC123', Date.today());
            System.assert(false, 'Hệ thống phải ném lỗi khi API phản hồi khác 200.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code; String body;
        MockHttpResponseGenerator(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}