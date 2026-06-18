@IsTest
private class FEC_GetAccountDetails_Test {

    private static final String MOCK_XML_SUCCESS =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body>' +
        '<NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
        '<NS1:SysResponse><TransID>t1</TransID><DateTime>2026-03-26T15:11:52</DateTime>' +
        '<Status>0</Status><Description>Success</Description></NS1:SysResponse>' +
        '<UnbilledTransactionView>1</UnbilledTransactionView>' +
        '<BilledTransactionView>1</BilledTransactionView>' +
        '<NS1:AccountRecords><AccountRecord>' +
        '<AccountNumber>0001500060000003</AccountNumber>' +
        '<AccountStatus>Active</AccountStatus>' +
        '<CustomerName>Test Customer</CustomerName>' +
        '<CreditLimit>10000000</CreditLimit>' +
        '<CurrentBalance>500000</CurrentBalance>' +
        '<IPPEligibilityFlag>Y</IPPEligibilityFlag>' +
        '<RetailIPPInfo><PlanNumber>90001</PlanNumber><InterestRate>18</InterestRate></RetailIPPInfo>' +
        '<CashIPPInfo><PlanNumber>90003</PlanNumber><InterestRate>24</InterestRate>' +
        '<MinTenure>6</MinTenure><MaxTenure>12</MaxTenure></CashIPPInfo>' +
        '</AccountRecord></NS1:AccountRecords>' +
        '<TransactionRecords><TransactionRecord>' +
        '<TransactionDate>2026-03-01</TransactionDate><PostingDate>2026-03-02</PostingDate>' +
        '<Description>Purchase</Description><Amount>100000</Amount><CurrencyCode>VND</CurrencyCode>' +
        '<ReferenceNumber>REF001</ReferenceNumber><TransactionType>Retail</TransactionType>' +
        '<MerchantName>Store</MerchantName><MCC>5411</MCC><Location>HCM</Location>' +
        '</TransactionRecord></TransactionRecords>' +
        '</NS1:GetAccountDetailsResponse></soapenv:Body></soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testBuildTenureList() {
        List<Integer> tenures = FEC_GetAccountDetails.buildTenureList(6, 12);
        System.assertEquals(3, tenures.size());
        System.assertEquals(6, tenures[0]);
        System.assertEquals(9, tenures[1]);
        System.assertEquals(12, tenures[2]);
        System.assertEquals(0, FEC_GetAccountDetails.buildTenureList(null, 12).size());
        System.assertEquals(0, FEC_GetAccountDetails.buildTenureList(12, 6).size());
    }

    @IsTest
    static void testGetAccountDetails_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetAccountDetails.ResponseWrapper res =
            FEC_GetAccountDetails.getAccountDetails('0001500060000003');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(0, res.Sys.Status);
        System.assertNotEquals(null, res.Account);
        System.assertEquals('0001500060000003', res.Account.AccountNumber);
        System.assertEquals('90001', res.Account.RetailIPPInfo.PlanNumber);
        System.assertEquals(3, res.Account.CashIPPInfo.TenureList.size());
        System.assertEquals(1, res.Transactions.size());
        System.assertEquals('Purchase', res.Transactions[0].Description);
    }

    @IsTest
    static void testCallGetAccountDetails_ValidationFail() {
        Test.startTest();
        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'TXN1',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                '2026-03-26T15:11:52',
                null
            );
            System.assert(false, 'Expected validation exception for blank account number.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetAccountDetails_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                '2026-03-26T15:11:52',
                '0001500060000003'
            );
            System.assert(false, 'Expected HTTP error exception.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetAccountDetails_ApiErrorStatus() {
        String errorXml =
            '<?xml version="1.0"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
            '<NS1:SysResponse><Status>1</Status><Description>API Error</Description></NS1:SysResponse>' +
            '</NS1:GetAccountDetailsResponse></soapenv:Body></soapenv:Envelope>';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, errorXml));

        Test.startTest();
        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'TXN12345678901234567890123456789012',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                '2026-03-26T15:11:52',
                '0001500060000003'
            );
            System.assert(false, 'Expected API error exception.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
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
