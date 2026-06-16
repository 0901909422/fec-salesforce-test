@IsTest
private class FEC_GetAccountDetails_Test {

    private static final String MOCK_XML_SUCCESS =
        '<?xml version=\'1.0\' encoding=\'utf-8\'?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body>' +
        '<NS1:GetAccountDetailsResponse xmlns:NS1="http://esbservice.fecredit.org/EStatementService/">' +
        '<NS1:SysResponse>' +
        '<TransID>d414cd9c-ab7e-4378-8146-7ee31bd844ff</TransID>' +
        '<DateTime>2026-03-26T15:11:52.118344+07:00</DateTime>' +
        '<Status>0</Status>' +
        '<Description>Success</Description>' +
        '</NS1:SysResponse>' +
        '<UnbilledTransactionView>9999</UnbilledTransactionView>' +
        '<BilledTransactionView>9999</BilledTransactionView>' +
        '<NS1:AccountRecords>' +
        '<AccountRecord>' +
        '<AccountNumber>0001500020000461725</AccountNumber>' +
        '<AccountStatus/>' +
        '<CustomerName/>' +
        '<CreditLimit>0</CreditLimit>' +
        '<CurrentBalance>0</CurrentBalance>' +
        '<AvailableCredit>0</AvailableCredit>' +
        '<CashLimit>0</CashLimit>' +
        '<AvailableCashLimit>0</AvailableCashLimit>' +
        '<LastStatementDate/>' +
        '<MinimumPaymentDue>0</MinimumPaymentDue>' +
        '<PaymentDueDate/>' +
        '<DateLastPayment/>' +
        '<EmailAddress/>' +
        '<OpeningPoints>0</OpeningPoints>' +
        '<ClosingPoints>0</ClosingPoints>' +
        '<RewardPoints>0</RewardPoints>' +
        '<RedeemedPoints>0</RedeemedPoints>' +
        '<EarnedPoints>0</EarnedPoints>' +
        '<BonusPoints>0</BonusPoints>' +
        '<IPPEligibilityFlag>Y</IPPEligibilityFlag>' +
        '<RetailIPPInfo>' +
        '<PlanNumber/>' +
        '<InterestRate/>' +
        '</RetailIPPInfo>' +
        '<CashIPPInfo>' +
        '<PlanNumber>90003</PlanNumber>' +
        '<InterestRate>24</InterestRate>' +
        '<MinTenure>6</MinTenure>' +
        '<MaxTenure>12</MaxTenure>' +
        '</CashIPPInfo>' +
        '</AccountRecord>' +
        '</NS1:AccountRecords>' +
        '<NS1:TransactionRecords/>' +
        '</NS1:GetAccountDetailsResponse>' +
        '</soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetAccountDetails_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetAccountDetails.ResponseWrapper res = FEC_GetAccountDetails.callGetAccountDetails(
            'd414cd9c-ab7e-4378-8146-7ee31bd844ff',
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.newInstance(2026, 3, 26, 8, 11, 51)),
            '0001500020000461725'
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals(0, res.Sys.Status, 'Status trả về phải là 0.');
        System.assertEquals(9999, res.UnbilledTransactionView);
        System.assertEquals(9999, res.BilledTransactionView);
        System.assertNotEquals(null, res.Account);
        System.assertEquals('0001500020000461725', res.Account.AccountNumber);
        System.assertEquals('Y', res.Account.IPPEligibilityFlag);
        System.assertNotEquals(null, res.Account.CashIPPInfo);
        System.assertEquals('90003', res.Account.CashIPPInfo.PlanNumber);
        System.assertEquals(24, res.Account.CashIPPInfo.InterestRate);
        System.assertEquals(6, res.Account.CashIPPInfo.MinTenure);
        System.assertEquals(12, res.Account.CashIPPInfo.MaxTenure);
        System.assertEquals(new List<Integer>{ 6, 9, 12 }, res.Account.CashIPPInfo.TenureList);
    }

    @IsTest
    static void testGetAccountDetails_AuraEnabled() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        FEC_GetAccountDetails.ResponseWrapper res =
            FEC_GetAccountDetails.getAccountDetails('0001500020000461725');
        Test.stopTest();

        System.assertEquals(0, res.Sys.Status);
    }

    @IsTest
    static void testCallGetAccountDetails_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'd414cd9c-ab7e-4378-8146-7ee31bd844ff',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
                '0001500020000461725'
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

        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                '',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
                '0001500020000461725'
            );
            System.assert(false, 'Phải báo lỗi khi TransID trống.');
        } catch (Exception e) {
            System.assert(true);
        }

        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'd414cd9c-ab7e-4378-8146-7ee31bd844ff',
                'INVALID_ID',
                FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
                '0001500020000461725'
            );
            System.assert(false, 'Phải báo lỗi khi RequestorID sai.');
        } catch (Exception e) {
            System.assert(true);
        }

        try {
            FEC_GetAccountDetails.callGetAccountDetails(
                'd414cd9c-ab7e-4378-8146-7ee31bd844ff',
                FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
                '',
                '0001500020000461725'
            );
            System.assert(false, 'Phải báo lỗi khi DateTime trống.');
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }

    @IsTest
    static void testBuildTenureList() {
        System.assertEquals(new List<Integer>(), FEC_GetAccountDetails.buildTenureList(null, 12));
        System.assertEquals(new List<Integer>(), FEC_GetAccountDetails.buildTenureList(6, null));
        System.assertEquals(new List<Integer>(), FEC_GetAccountDetails.buildTenureList(12, 6));
        System.assertEquals(new List<Integer>{ 3, 6, 9, 12 }, FEC_GetAccountDetails.buildTenureList(3, 12));
        System.assertEquals(new List<Integer>{ 6, 9, 12 }, FEC_GetAccountDetails.buildTenureList(6, 12));
    }

    @IsTest
    static void testLogApiResponse_Null() {
        FEC_GetAccountDetails.logApiResponse();
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
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}
