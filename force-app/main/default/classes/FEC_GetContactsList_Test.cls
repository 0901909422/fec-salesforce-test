@IsTest
private class FEC_GetContactsList_Test {

    // Mock XML phản hồi từ API
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetContactsListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-01-17 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Contacts>' +
        '        <Contact>' +
        '          <ContactId>C001</ContactId>' +
        '          <Channel>SMS</Channel>' +
        '          <ContactString>0901234567</ContactString>' +
        '        </Contact>' +
        '      </Contacts>' +
        '    </GetContactsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetContactsList_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        // Gọi service
        FEC_GetContactsList.ResponseWrapper res = FEC_GetContactsList.callGetContactsList(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-17 10:00:00',
            'CIF999'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(1, res.Sys.Code, 'Code trả về phải là 1 (thành công).');
        System.assertEquals('CIF999', res.CIFNumber);
        System.assertEquals(1, res.Contacts.size());
        System.assertEquals('0901234567', res.Contacts[0].ContactString);
    }

    @IsTest
    static void testValidateRequest_InvalidCif() {
        Test.startTest();
        try {
            // Test lỗi validation: CIF Number quá dài
            String longCif = 'A'.repeat(256);
            FEC_GetContactsList.callGetContactsList('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', longCif);
            System.assert(false, 'Phải ném ngoại lệ khi CIFNumber quá dài.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
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