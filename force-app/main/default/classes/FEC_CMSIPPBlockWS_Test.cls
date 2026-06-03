@IsTest
private class FEC_CMSIPPBlockWS_Test {
    private class CmsIppSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() == null ? '' : req.getBody();
            System.assert(body.contains('CMSIPPBlock'), 'Request body should contain CMSIPPBlock action.');
            System.assert(body.contains('<Account>0001500010000000261</Account>'), 'Account must be present in request body.');
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
                '<soapenv:Body>' +
                '<CMSIPPBlockResponse xmlns="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
                '<Sys>' +
                '<TransID>TRX-123</TransID>' +
                '<DateTime>2026-05-28T18:00:00</DateTime>' +
                '<Code>1</Code>' +
                '<Description>Success</Description>' +
                '</Sys>' +
                '<AvailableCredit>1500000</AvailableCredit>' +
                '</CMSIPPBlockResponse>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }

    private class CmsIppNon200Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;
        }
    }

    private static void ensureApiSetting() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
        );
    }

    @IsTest
    static void testValidate_SuccessAndInvalidRequestor() {
        Test.startTest();
        FEC_CMSIPPBlockWS.validate(
            String.valueOf(UUID.randomUUID()),
            FEC_ConstantCommon.REQUESTOR_CRM,
            Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT),
            'CRM001',
            'BRANCH',
            '0001500010000000261',
            1000000,
            12
        );
        Test.stopTest();

        try {
            FEC_CMSIPPBlockWS.validate(
                String.valueOf(UUID.randomUUID()),
                'INVALID_REQUESTOR',
                Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT),
                'CRM001',
                'BRANCH',
                '0001500010000000261',
                1000000,
                12
            );
            System.assert(false, 'Expected CalloutException for invalid requestor.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testValidate_ThrowsWhenRequiredMissing() {
        try {
            FEC_CMSIPPBlockWS.validate(
                null,
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT),
                'CRM001',
                'BRANCH',
                '0001500010000000261',
                1000000,
                12
            );
            System.assert(false, 'Expected CalloutException when transId is null.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_CMSIPPBlockWS.validate(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                '',
                'CRM001',
                'BRANCH',
                '0001500010000000261',
                1000000,
                12
            );
            System.assert(false, 'Expected CalloutException when datetime is blank.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_CMSIPPBlockWS.validate(
                String.valueOf(UUID.randomUUID()),
                FEC_ConstantCommon.REQUESTOR_CRM,
                Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT),
                '',
                'BRANCH',
                '0001500010000000261',
                null,
                null
            );
            System.assert(false, 'Expected CalloutException when required business params are blank.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testParseResponse_SuccessAndMissingNode() {
        String okXml =
            '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
            '<soapenv:Body>' +
            '<CMSIPPBlockResponse xmlns="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
            '<Sys><TransID>TRX-OK</TransID><DateTime>2026-05-28T18:00:00</DateTime><Code>1</Code><Description>OK</Description></Sys>' +
            '<AvailableCredit>2500000</AvailableCredit>' +
            '</CMSIPPBlockResponse>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';

        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper parsed = FEC_CMSIPPBlockWS.parseResponse(okXml);
        Test.stopTest();

        System.assertNotEquals(null, parsed);
        System.assertNotEquals(null, parsed.Sys, 'Sys node should be initialized.');

        String badXml =
            '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
            '<soapenv:Body><OtherResponse/></soapenv:Body></soapenv:Envelope>';
        try {
            FEC_CMSIPPBlockWS.parseResponse(badXml);
            System.assert(false, 'Expected CalloutException when CMSIPPBlockResponse is missing.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Cannot find CMSIPPBlockResponse'));
        }
    }

    @IsTest
    static void testCmsIPPBlockWS_Success() {
        ensureApiSetting();

        Test.setMock(HttpCalloutMock.class, new CmsIppSuccessMock());
        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper success = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
            FEC_ConstantCommon.REQUESTOR_CRM,
            'CRM001',
            'BRANCH',
            '0001500010000000261',
            1000000,
            12,
            false,
            'Campaign A',
            1.5,
            '1234567890',
            'VCB',
            'HCM',
            0.3,
            10000,
            'N'
        );
        Test.stopTest();
        System.assertNotEquals(null, success);
        System.assertNotEquals(null, success.Sys, 'Response should contain Sys object.');
    }

    @IsTest
    static void testCmsIPPBlockWS_Non200ReturnsNull() {
        ensureApiSetting();
        Test.setMock(HttpCalloutMock.class, new CmsIppNon200Mock());
        Test.startTest();
        FEC_CMSIPPBlockWS.ResponseWrapper failed = FEC_CMSIPPBlockWS.cmsIPPBlockWS(
            FEC_ConstantCommon.REQUESTOR_CRM,
            'CRM001',
            'BRANCH',
            '0001500010000000261',
            1000000,
            12,
            false,
            'Campaign B',
            1.2,
            '1234567890',
            'VCB',
            'HN',
            0.2,
            9000,
            'N'
        );
        Test.stopTest();
        System.assertEquals(null, failed, 'Non-200 response should return null.');
    }
}
