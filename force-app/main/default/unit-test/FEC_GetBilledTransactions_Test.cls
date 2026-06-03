@IsTest
private class FEC_GetBilledTransactions_Test {

    // XML mẫu dựa trên cấu trúc Soap của bạn
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetBilledTransactionsResponse>' +
        '      <SysResponse>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2025-12-16 10:00:00</DateTime>' +
        '        <Status>0</Status>' +
        '        <Description>Success</Description>' +
        '      </SysResponse>' +
        '      <AccountRecords>' +
        '        <AccountRecord>' +
        '          <AccountNumber>ACC999</AccountNumber>' +
        '          <CustomerName>Nguyen Van A</CustomerName>' +
        '        </AccountRecord>' +
        '      </AccountRecords>' +
        '      <TransactionRecords>' +
        '        <TransactionRecord>' +
        '          <Description>Thanh toan the</Description>' +
        '          <Amount>500000</Amount>' +
        '        </TransactionRecord>' +
        '      </TransactionRecords>' +
        '    </GetBilledTransactionsResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetBilledTransactions_Success() {
        // Thiết lập Mock cho Http callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        // Gọi phương thức chính
        FEC_GetBilledTransactions.ResponseWrapper res = FEC_GetBilledTransactions.callGetBilledTransactions(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM,
            '2025-12-16 10:00:00',
            'ACC999',
            '12'
        );
        Test.stopTest();

        // Xác thực kết quả parse
        System.assertEquals(0, res.Sys.Status, 'Status code phải là 0.');
        System.assertEquals('ACC999', res.Account.AccountNumber);
        System.assertEquals(1, res.Transactions.size());
        System.assertEquals('Thanh toan the', res.Transactions[0].Description);
    }

    @IsTest
    static void testValidateRequest_InvalidParams() {
        Test.startTest();
        try {
            // Test lỗi validation (StatementMonth sai định dạng)
            FEC_GetBilledTransactions.callGetBilledTransactions('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2025-12-16 10:00:00', 'ACC1', '13');
            System.assert(false, 'Phải ném ngoại lệ khi StatementMonth không hợp lệ.');
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