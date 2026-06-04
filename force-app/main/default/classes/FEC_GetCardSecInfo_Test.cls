@IsTest
private class FEC_GetCardSecInfo_Test {

    // XML mẫu giả lập Response SOAP phức tạp
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCardSecInfoResponse>' +
        '      <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '      <CardSecInfo>' +
        '        <MainCardProduct><PurchaseLimit>50000000</PurchaseLimit></MainCardProduct>' +
        '        <IPPs>' +
        '          <IPP>' +
        '            <IPPPlan>TestPlan</IPPPlan>' +
        '            <OPENING_BALANCE_1>1000000</OPENING_BALANCE_1>' +
        '          </IPP>' +
        '        </IPPs>' +
        '        <FinancialTransactions>' +
        '           <FinancialTransaction>' +
        '               <Description>Payment Test</Description>' +
        '               <TRNXAmount>200000</TRNXAmount>' +
        '           </FinancialTransaction>' +
        '        </FinancialTransactions>' +
        '      </CardSecInfo>' +
        '    </GetCardSecInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetCardSecInfo_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        FEC_GetCardSecInfo.ResponseWrapper res = FEC_GetCardSecInfo.callGetCardSecInfo(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2026-05-22 10:00:00',
            'ACC123',
            false
        );
        Test.stopTest();

        System.assertEquals(1, res.Sys.Code);
        System.assertNotEquals(null, res.CardSecInfo.MainCardProduct);
        System.assertEquals(50000000, res.CardSecInfo.MainCardProduct.PurchaseLimit);
        System.assertEquals(1, res.CardSecInfo.IPPs.size());
        System.assertEquals(1000000, res.CardSecInfo.IPPs[0].OpeningBalance);
        System.assertEquals(1, res.CardSecInfo.FinancialTransactions.size());
    }

    @IsTest
    static void testValidateRequest_ThrowsException() {
        Test.startTest();
        try {
            // Test lỗi validation do AccountNumber quá dài (>255)
            FEC_GetCardSecInfo.callGetCardSecInfo('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-22 10:00:00', 'A'.repeat(256), false);
            System.assert(false, 'Phải ném ngoại lệ khi AccountNumber quá dài.');
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