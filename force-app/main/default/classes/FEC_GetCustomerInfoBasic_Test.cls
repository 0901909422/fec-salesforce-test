@IsTest
private class FEC_GetCustomerInfoBasic_Test {

    // XML mẫu giả lập phản hồi SOAP phức tạp
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCustomerInfoBasicResponse>' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-01-07 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CustomerBasicInfo>' +
        '        <CIFNumber>CIF999</CIFNumber>' +
        '        <FullName>Nguyen Van A</FullName>' +
        '        <CurrentAddresses>' +
        '           <Address><AddressId>ADR01</AddressId><City>HCMC</City></Address>' +
        '        </CurrentAddresses>' +
        '      </CustomerBasicInfo>' +
        '    </GetCustomerInfoBasicResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetCustomerInfoBasic_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        // Gọi phương thức chính với dữ liệu hợp lệ
        FEC_GetCustomerInfoBasic.ResponseWrapper res = FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-07T10:00:00.000Z',
            '123456'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertEquals('1', res.Sys.Code, 'Mã Code trả về phải là 1.');
        System.assertEquals('CIF999', res.CustomerBasicInfo.CIFNumber);
        System.assertEquals('Nguyen Van A', res.CustomerBasicInfo.FullName);
        System.assertEquals(1, res.CustomerBasicInfo.CurrentAddresses.size());
        System.assertEquals('ADR01', res.CustomerBasicInfo.CurrentAddresses[0].Address.AddressId);
    }

    @IsTest
    static void testValidateRequest_Invalid() {
        Test.startTest();
        try {
            // Test lỗi validation: CIF Number không phải số
            FEC_GetCustomerInfoBasic.callGetCustomerInfoBasic(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-07T10:00:00.000Z', 'ABC'
            );
            System.assert(false, 'Phải ném ngoại lệ khi CIFNumber không phải là số.');
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