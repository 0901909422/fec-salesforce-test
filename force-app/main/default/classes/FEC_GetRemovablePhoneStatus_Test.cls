@IsTest
private class FEC_GetRemovablePhoneStatus_Test {

    // XML mẫu giả lập phản hồi SOAP
    private static final String MOCK_XML_SUCCESS =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:pc="http://fecredit.com.vn/PhoneCheckWS">' +
        '  <soapenv:Body>' +
        '    <pc:GetRemovablePhoneStatusResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-03-11T10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '    </pc:GetRemovablePhoneStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    private static final String MOCK_XML_ERROR =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:pc="http://fecredit.com.vn/PhoneCheckWS">' +
        '  <soapenv:Body>' +
        '    <pc:GetRemovablePhoneStatusResponse>' +
        '      <Sys>' +
        '        <Code>2</Code>' +
        '        <Description>Not Eligible</Description>' +
        '      </Sys>' +
        '    </pc:GetRemovablePhoneStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testGetRemovablePhoneStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetRemovablePhoneStatus.PhoneCheckResult res = FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus('0901234567');
        Test.stopTest();

        System.assertEquals(true, res.success, 'Kết quả API phải thành công.');
        System.assertEquals('1', res.code, 'Mã Code trả về phải là 1.');
        FEC_GetRemovablePhoneStatus.logApiResponse(); // Phủ mã log
    }

    @IsTest
    static void testGetRemovablePhoneStatus_NotEligible() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_ERROR));

        Test.startTest();
        FEC_GetRemovablePhoneStatus.PhoneCheckResult res = FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus('0901234567');
        Test.stopTest();

        System.assertEquals(false, res.success, 'Kết quả phải thất bại khi Code != 1.');
        System.assertEquals('Not Eligible', res.errorMessage);
    }

    @IsTest
    static void testGetRemovablePhoneStatus_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_GetRemovablePhoneStatus.PhoneCheckResult res = FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus('0901234567');
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest
    static void testValidation_EmptyPhone() {
        Test.startTest();
        try {
            FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus('');
            System.assert(false, 'Phải ném Exception khi phone trống.');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidation_LongPhone() {
        Test.startTest();
        try {
            FEC_GetRemovablePhoneStatus.getRemovablePhoneStatus('12345678901234567890123456789012345678901');
            System.assert(false, 'Phải ném Exception khi phone quá dài.');
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