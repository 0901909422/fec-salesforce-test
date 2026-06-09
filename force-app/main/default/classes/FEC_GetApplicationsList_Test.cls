@IsTest
private class FEC_GetApplicationsList_Test {

    // Mock response XML mẫu
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetApplicationsListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-01-10 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Applications>' +
        '        <Application>' +
        '          <ApplicationID>APP001</ApplicationID>' +
        '          <ProductGroup>Card</ProductGroup>' +
        '          <LastStatus>Approved</LastStatus>' +
        '        </Application>' +
        '      </Applications>' +
        '    </GetApplicationsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetApplicationsList_Success() {
        // Thiết lập Mock cho Http callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        // Gọi phương thức chính
        FEC_GetApplicationsList.ResponseWrapper res = FEC_GetApplicationsList.callGetApplicationsList(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-10 10:00:00',
            'CIF999'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(1, res.Sys.Code, 'Mã Code trả về phải là 1.');
        System.assertEquals('CIF999', res.CIFNumber, 'CIF Number phải khớp.');
        System.assertEquals(1, res.Applications.size(), 'Phải có 1 application.');
        System.assertEquals('APP001', res.Applications[0].ApplicationID);
    }

    @IsTest
    static void testValidateRequest_InvalidData() {
        Test.startTest();
        try {
            // Test lỗi validation (Sai requestorID)
            FEC_GetApplicationsList.callGetApplicationsList('TXN1', 'INVALID', '2026-01-10 10:00:00', 'CIF1');
            System.assert(false, 'Phải ném ngoại lệ khi RequestorID không hợp lệ.');
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