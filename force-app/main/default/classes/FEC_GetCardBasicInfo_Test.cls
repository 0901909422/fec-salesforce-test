@IsTest
private class FEC_GetCardBasicInfo_Test {

    // XML mẫu dựa trên cấu trúc Response của bạn
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCardBasicInfoResponse>' +
        '      <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '      <CardBasicInfo>' +
        '        <MainCard>' +
        '          <Product>Credit Card</Product>' +
        '          <Status>Active</Status>' +
        '          <Limit>50000000</Limit>' +
        '        </MainCard>' +
        '        <Statement>' +
        '          <StatemenBalance>1000000</StatemenBalance>' +
        '        </Statement>' +
        '        <Transactions>' +
        '           <Transaction>' +
        '               <Description>Payment</Description>' +
        '               <TRNXAmount>200000</TRNXAmount>' +
        '           </Transaction>' +
        '        </Transactions>' +
        '      </CardBasicInfo>' +
        '    </GetCardBasicInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetCardBasicInfo_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        FEC_GetCardBasicInfo.ResponseWrapper res = FEC_GetCardBasicInfo.callGetCardBasicInfo(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-01-10 10:00:00',
            'ACC123'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertNotEquals(null, res.CardBasicInfo, 'CardBasicInfo không được null.');
        System.assertEquals('Credit Card', res.CardBasicInfo.MainCard.Product);
        System.assertEquals(1000000, res.CardBasicInfo.Statement.StatementBalance);
        System.assertEquals(1, res.CardBasicInfo.Transactions.size());
        System.assertEquals('Payment', res.CardBasicInfo.Transactions[0].Description);
    }

    @IsTest
    static void testValidateRequest_Invalid() {
        Test.startTest();
        try {
            // Test lỗi validation (Sai requestorID)
            FEC_GetCardBasicInfo.callGetCardBasicInfo('TXN1', 'INVALID', '2026-01-10 10:00:00', 'ACC1');
            System.assert(false, 'Phải ném ngoại lệ khi RequestorID sai.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Helper class Mock
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