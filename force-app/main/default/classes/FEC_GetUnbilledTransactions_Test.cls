@IsTest
private class FEC_GetUnbilledTransactions_Test {

    // XML mẫu giả lập Response SOAP thành công
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <ns1:GetUnbilledTransactionsResponse xmlns:ns1="http://esbservice.fecredit.org/EStatementService/">' +
        '      <SysResponse>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2025-12-16 10:00:00</DateTime>' +
        '        <Status>0</Status>' +
        '        <Description>Success</Description>' +
        '      </SysResponse>' +
        '      <TransactionRecords>' +
        '        <TransactionRecord>' +
        '          <TransactionDate>2025-12-15</TransactionDate>' +
        '          <Amount>150000</Amount>' +
        '          <Description>Shopping</Description>' +
        '        </TransactionRecord>' +
        '      </TransactionRecords>' +
        '    </ns1:GetUnbilledTransactionsResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetUnbilledTransactions_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetUnbilledTransactions.ResponseWrapper res = FEC_GetUnbilledTransactions.callGetUnbilledTransactions(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM, 
            '2025-12-16 10:00:00',
            'ACC123'
        );
        Test.stopTest();

        // Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals(0, res.Sys.Status, 'Status trả về phải là 0.');
        System.assertEquals(1, res.Transactions.size(), 'Phải có 1 giao dịch được parse.');
        System.assertEquals(150000, res.Transactions[0].Amount);
    }

    @IsTest
    static void testCallGetUnbilledTransactions_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetUnbilledTransactions.callGetUnbilledTransactions(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2025-12-16 10:00:00', 'ACC123'
            );
            System.assert(false, 'Phải ném CalloutException khi status != 200.');
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Failures() {
        Test.startTest();
        
        // 1. TransID null
        try {
            FEC_GetUnbilledTransactions.callGetUnbilledTransactions('', FEC_ConstantCommon.REQUESTOR_CRM, '2025-12-16 10:00:00', 'ACC1');
            System.assert(false, 'Phải báo lỗi khi TransID trống.');
        } catch (Exception e) { System.assert(true); }

        // 2. RequestorID không hợp lệ
        try {
            FEC_GetUnbilledTransactions.callGetUnbilledTransactions('TXN1', 'INVALID_ID', '2025-12-16 10:00:00', 'ACC1');
            System.assert(false, 'Phải báo lỗi khi RequestorID sai.');
        } catch (Exception e) { System.assert(true); }

        // 3. DateTime không hợp lệ
        try {
            FEC_GetUnbilledTransactions.callGetUnbilledTransactions('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'invalid-date', 'ACC1');
            System.assert(false, 'Phải báo lỗi khi DateTime sai định dạng.');
        } catch (Exception e) { System.assert(true); }

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