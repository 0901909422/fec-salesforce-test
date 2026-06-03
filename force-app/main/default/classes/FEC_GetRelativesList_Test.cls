@IsTest
private class FEC_GetRelativesList_Test {

    // XML mẫu giả lập Response SOAP thành công
    private static final String MOCK_XML_SUCCESS =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
        '  <soapenv:Body>' +
        '    <cif:GetRelativesListResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-01-10T10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CIFNumber>CIF999</CIFNumber>' +
        '      <Relatives>' +
        '        <Relative>' +
        '          <RelationType>Mother</RelationType>' +
        '          <FullName>Nguyen Thi B</FullName>' +
        '          <PhoneNumber>0901234567</PhoneNumber>' +
        '          <City>Hanoi</City>' +
        '        </Relative>' +
        '      </Relatives>' +
        '    </cif:GetRelativesListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetRelativesList_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        // Gọi service
        FEC_GetRelativesList.ResponseWrapper res = FEC_GetRelativesList.callGetRelativesList(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-10T10:00:00',
            'CIF999'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals(1, res.Sys.Code, 'Code trả về phải là 1 (thành công).');
        System.assertEquals('CIF999', res.CIFNumber);
        System.assertEquals(1, res.Relatives.size());
        System.assertEquals('Nguyen Thi B', res.Relatives[0].FullName);
        System.assertEquals('0901234567', res.Relatives[0].PhoneNumber);
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Test.startTest();
        
        // Test lỗi: RequestorID không hợp lệ
        try {
            FEC_GetRelativesList.callGetRelativesList('TXN123', 'INVALID_ID', '2026-01-10T10:00:00', 'CIF123');
            System.assert(false, 'Phải ném Exception khi RequestorID sai.');
        } catch (CalloutException e) {
            System.assert(true);
        }

        // Test lỗi: TransID quá dài (>36)
        try {
            FEC_GetRelativesList.callGetRelativesList('A'.repeat(37), FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-10T10:00:00', 'CIF123');
            System.assert(false, 'Phải ném Exception khi TransID quá dài.');
        } catch (CalloutException e) {
            System.assert(true);
        }

        // Test lỗi: DateTime sai định dạng
        try {
            FEC_GetRelativesList.callGetRelativesList('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, 'invalid-date', 'CIF123');
            System.assert(false, 'Phải ném Exception khi DateTime sai định dạng.');
        } catch (CalloutException e) {
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