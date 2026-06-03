@IsTest
private class FEC_GetStatus_Test {

    // XML mẫu giả lập phản hồi SOAP
    private static final String MOCK_XML_SUCCESS =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:cms="http://fecredit.com.vn/CMS_DeliveryCardStatusWS">' +
        '  <soapenv:Body>' +
        '    <cms:GetStatusResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-05-25T10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <Info>' +
        '        <AccountNumber>ACC999</AccountNumber>' +
        '        <CardNumber>1234567890</CardNumber>' +
        '        <Status>Delivered</Status>' +
        '        <ReceiverName>Nguyen Van A</ReceiverName>' +
        '      </Info>' +
        '    </cms:GetStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testGetDeliveryStatus_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetStatus.CardDeliveryInfo res = FEC_GetStatus.getDeliveryStatus('ACC999');
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals('1', res.responseCode, 'Mã Code trả về phải là 1.');
        System.assertEquals('ACC999', res.accountNumber);
        System.assertEquals('Delivered', res.status);
        System.assertEquals('Nguyen Van A', res.receiverName);
    }

    @IsTest
    static void testGetDeliveryStatus_ApiError() {
        // XML phản hồi lỗi (Code = 0)
        String mockError = MOCK_XML_SUCCESS.replace('<Code>1</Code>', '<Code>0</Code>');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, mockError));

        Test.startTest();
        try {
            FEC_GetStatus.getDeliveryStatus('ACC999');
            System.assert(false, 'Phải ném ngoại lệ khi API code != 1.');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Failures() {
        Test.startTest();
        // Kiểm tra lỗi validate AccountNumber
        try {
            FEC_GetStatus.getDeliveryStatus('');
            System.assert(false, 'Phải ném lỗi khi AccountNumber rỗng.');
        } catch (Exception e) {
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
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}