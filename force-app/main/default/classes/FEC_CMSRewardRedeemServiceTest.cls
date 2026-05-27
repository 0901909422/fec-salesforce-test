@isTest
private class FEC_CMSRewardRedeemServiceTest {
    private class RewardRedeemMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        RewardRedeemMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    @isTest
    static void testGenerateMvoucherSuccess() {
        FEC_CMSRewardRedeemService.testEndpointOverride = 'https://unit.test/reward';
        FEC_CMSRewardRedeemService.testSoapActionOverride =
            'http://esbservice.fecredit.org/CMS_RewardWS/GenerateMvoucher';

        String response =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                    '<NS1:GenerateMvoucherResponse xmlns:NS1="http://esbservice.fecredit.org/CMS_RewardWS/">' +
                        '<SysResponse>' +
                            '<TransID>T-001</TransID>' +
                            '<DateTime>2026-04-11T16:19:27.952+07:00</DateTime>' +
                            '<Status>0</Status>' +
                            '<Description>Success</Description>' +
                        '</SysResponse>' +
                        '<RedeemRefID>R-001</RedeemRefID>' +
                        '<VoucherRefID>V-001</VoucherRefID>' +
                        '<AvailablePoints>279.58</AvailablePoints>' +
                        '<VoucherLink>https://v.gotit.vn/jHsN3xwY</VoucherLink>' +
                    '</NS1:GenerateMvoucherResponse>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new RewardRedeemMock(200, response));
        Test.startTest();
        FEC_CMSRewardRedeemService.RedeemResult result =
            FEC_CMSRewardRedeemService.generateMvoucher(buildRequest('MVoucher', 0));
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(0, result.status);
        System.assertEquals('R-001', result.redeemRefId);
        System.assertEquals('V-001', result.voucherRefId);
        System.assertEquals('https://v.gotit.vn/jHsN3xwY', result.voucherLink);
        System.assertEquals(279.58, result.availablePoints);
    }

    @isTest
    static void testGenerateEvoucherBusinessFail() {
        FEC_CMSRewardRedeemService.testEndpointOverride = 'https://unit.test/reward';
        FEC_CMSRewardRedeemService.testSoapActionOverride =
            'http://esbservice.fecredit.org/CMS_RewardWS/GenerateEvoucher';

        String response =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                    '<NS1:GenerateEvoucherResponse xmlns:NS1="http://esbservice.fecredit.org/CMS_RewardWS/">' +
                        '<SysResponse>' +
                            '<TransID>T-002</TransID>' +
                            '<DateTime>2026-04-15T17:16:23.048+07:00</DateTime>' +
                            '<Status>1</Status>' +
                            '<Description>Insufficient points</Description>' +
                        '</SysResponse>' +
                    '</NS1:GenerateEvoucherResponse>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new RewardRedeemMock(200, response));
        Test.startTest();
        FEC_CMSRewardRedeemService.RedeemResult result =
            FEC_CMSRewardRedeemService.generateEvoucher(buildRequest('EVoucher', 0));
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(1, result.status);
        System.assertEquals('Insufficient points', result.errorMessage);
    }

    @isTest
    static void testGenerateCashbackHttpError() {
        FEC_CMSRewardRedeemService.testEndpointOverride = 'https://unit.test/reward';
        FEC_CMSRewardRedeemService.testSoapActionOverride =
            'http://esbservice.fecredit.org/CMS_RewardWS/GenerateCashback';

        Test.setMock(HttpCalloutMock.class, new RewardRedeemMock(500, 'internal error'));
        Test.startTest();
        FEC_CMSRewardRedeemService.RedeemResult result =
            FEC_CMSRewardRedeemService.generateCashback(buildRequest('Cashback', 100000));
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(500, result.httpStatus);
        System.assert(result.errorMessage.contains('HTTP Error'));
    }

    @isTest
    static void testValidationFailed() {
        FEC_CMSRewardRedeemService.RedeemRequest req = buildRequest('EVoucher', 0);
        req.accountNumber = null;

        Test.startTest();
        FEC_CMSRewardRedeemService.RedeemResult result =
            FEC_CMSRewardRedeemService.generateEvoucher(req);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    private static FEC_CMSRewardRedeemService.RedeemRequest buildRequest(
        String productType,
        Decimal cashback
    ) {
        FEC_CMSRewardRedeemService.RedeemRequest req = new FEC_CMSRewardRedeemService.RedeemRequest();
        req.transId = '550e8400-e29b-41d4-a716-446655440000';
        req.requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        req.dateTimeStr = '20260411T161927.0 GMT';
        req.accountNumber = '0001500030000274373';
        req.customerName = 'TEST CUSTOMER';
        req.customerMobile = '84938089975';
        req.ticketId = 'PEGA20260411800655166';
        req.ticketPoint = 100000;
        req.adjustmentIndicator = '+';
        req.productId = '1443';
        req.productName = 'Sample Reward';
        req.productType = productType;
        req.priceId = '2791';
        req.price = 100000;
        req.cashback = cashback;
        req.redeemTypeId = 5;
        return req;
    }
}