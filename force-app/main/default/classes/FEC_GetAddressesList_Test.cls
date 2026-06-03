@IsTest
private class FEC_GetAddressesList_Test {

    // Mock response XML mẫu
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetAddressesListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-01-21 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Addresses>' +
        '        <Address>' +
        '          <AddressId>ADR001</AddressId>' +
        '          <Street>123 Le Loi</Street>' +
        '          <City>HCMC</City>' +
        '        </Address>' +
        '      </Addresses>' +
        '    </GetAddressesListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetAddressesList_Success() {
        // Thiết lập Mock cho Http callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        // Gọi phương thức chính
        FEC_GetAddressesList.ResponseWrapper res = FEC_GetAddressesList.callGetAddressesList(
            'TXN12345678901234567890123456789012', // 36 chars
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-21 10:00:00',
            'CIF999'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(1, res.Sys.Code);
        System.assertEquals('CIF999', res.CIFNumber);
        System.assertEquals('ADR001', res.Addresses[0].AddressId);
    }

    @IsTest
    static void testValidateRequest_ThrowsException() {
        Test.startTest();
        try {
            // Test lỗi validation (Sai định dạng Datetime)
            FEC_GetAddressesList.callGetAddressesList('TXN1', 'INVALID_REQ', 'invalid-date', 'CIF1');
            System.assert(false, 'Phải ném ngoại lệ khi dữ liệu sai.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Class Helper để Mock HTTP Response
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