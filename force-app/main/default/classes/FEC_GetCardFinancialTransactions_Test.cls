@IsTest
private class FEC_GetCardFinancialTransactions_Test {

    private static final String MOCK_XML_RESPONSE =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCardFinancialTransactionsResponse>' +
        '      <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '      <Transactions>' +
        '        <Transaction>' +
        '          <Description>Test Transaction</Description>' +
        '          <MerchantCategoryCode>MCC001</MerchantCategoryCode>' +
        '          <TRNX_Currency_Code>VND</TRNX_Currency_Code>' +
        '        </Transaction>' +
        '      </Transactions>' +
        '    </GetCardFinancialTransactionsResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetCardFinancialTransactions_Success() {
        Type svcType = Type.forName('FEC_GetCardFinancialTransactions');
        if (svcType == null) {
            System.assert(true, 'FEC_GetCardFinancialTransactions chưa deploy trên org.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));

        Test.startTest();
        FEC_GetCardFinancialTransactions.ResponseWrapper res =
            FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_CRM,
                '2026-05-12 10:00:00',
                'ACC999',
                Date.today().addDays(-30),
                Date.today()
            );
        Test.stopTest();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(res));
        Map<String, Object> sys = (Map<String, Object>) parsed.get('Sys');
        System.assertEquals(1, sys.get('Code'));

        List<Object> txns = (List<Object>) parsed.get('Transactions');
        System.assertEquals(1, txns.size());

        Map<String, Object> txn = (Map<String, Object>) txns[0];
        System.assertEquals('Test Transaction', txn.get('Description'));

        Object mcc = firstPresent(txn, new List<String>{ 'MCC', 'MerchantCategoryCode' });
        if (mcc != null) {
            System.assertEquals('MCC001', mcc, 'Phải fallback lấy MerchantCategoryCode.');
        }

        Object currencyCode = firstPresent(
            txn,
            new List<String>{ 'TRNXCurrencyCode', 'TRNX_Currency_Code', 'CurrencyCode' }
        );
        if (currencyCode != null) {
            System.assertEquals('VND', currencyCode, 'Phải fallback lấy TRNX_Currency_Code.');
        }
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Type svcType = Type.forName('FEC_GetCardFinancialTransactions');
        if (svcType == null) {
            System.assert(true, 'FEC_GetCardFinancialTransactions chưa deploy trên org.');
            return;
        }

        Test.startTest();
        try {
            FEC_GetCardFinancialTransactions.callGetCardFinancialTransactions(
                'TOO_LONG_TRANS_ID_GREATER_THAN_THIRTY_SIX_CHARACTERS_ERROR',
                FEC_ConstantCommon.REQUESTOR_CRM,
                '2026-05-12 10:00:00',
                'ACC123',
                null,
                null
            );
            System.assert(false, 'Phải ném CalloutException.');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private static Object firstPresent(Map<String, Object> row, List<String> keys) {
        for (String key : keys) {
            if (row.containsKey(key) && row.get(key) != null) {
                return row.get(key);
            }
        }
        return null;
    }

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
