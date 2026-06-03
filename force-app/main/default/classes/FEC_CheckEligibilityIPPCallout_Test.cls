@IsTest
private class FEC_CheckEligibilityIPPCallout_Test {

    // 1. Mock Class cho HttpCallout
    private class MockResponseGenerator implements HttpCalloutMock {
        private String xmlBody;
        private Integer statusCode;

        public MockResponseGenerator(String xmlBody, Integer statusCode) {
            this.xmlBody = xmlBody;
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');
            res.setStatusCode(this.statusCode);
            res.setBody(this.xmlBody);
            return res;
        }
    }

    @IsTest
    static void testCheckAccountEligibility_Success() {
        // XML giả lập thành công
        String xmlResponse = 
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
            '<soapenv:Body><ns1:CheckEligibilityResponse>' +
            '<Sys><TransID>123</TransID><Code>0</Code><Description>Success</Description></Sys>' +
            '<Details><AccEligibility>true</AccEligibility><EligibleAmount>5000000</EligibleAmount>' +
            '<CampaignDetails><Type>IPP</Type><InterestRate>1.5</InterestRate><Tenure>6</Tenure></CampaignDetails>' +
            '</Details></ns1:CheckEligibilityResponse></soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new MockResponseGenerator(xmlResponse, 200));

        Test.startTest();
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult result = 
            FEC_CheckEligibilityIPPCallout.checkAccountEligibility('123456789');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Kết quả phải trả về thành công.');
        System.assertEquals('true', result.accEligibility);
        System.assertEquals(5000000, result.eligibleAmount);
        System.assertEquals(1, result.campaigns.size());
    }

    @IsTest
    static void testCheckAccountEligibility_ErrorResponse() {
        // XML giả lập lỗi (Code khác 0/1)
        String xmlResponse = 
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://fecredit.com.vn/CMS_IPP_BlockWS">' +
            '<soapenv:Body><ns1:CheckEligibilityResponse>' +
            '<Sys><Code>2</Code><Description>Account not found</Description></Sys>' +
            '</ns1:CheckEligibilityResponse></soapenv:Body></soapenv:Envelope>';

        Test.setMock(HttpCalloutMock.class, new MockResponseGenerator(xmlResponse, 200));

        Test.startTest();
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult result = 
            FEC_CheckEligibilityIPPCallout.checkAccountEligibility('INVALID_ACC');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('Account not found'));
    }

    @IsTest
    static void testCheckAccountEligibility_EmptyParam() {
        Test.startTest();
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult result = 
            FEC_CheckEligibilityIPPCallout.checkAccountEligibility('');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.errorMessage);
    }

    @IsTest
    static void testCheckAccountEligibility_CalloutException() {
        // Mock phản hồi lỗi Server 500
        Test.setMock(HttpCalloutMock.class, new MockResponseGenerator('Error', 500));

        Test.startTest();
        FEC_CheckEligibilityIPPCallout.CheckEligibilityResult result = 
            FEC_CheckEligibilityIPPCallout.checkAccountEligibility('123456789');
        Test.stopTest();

        System.assertEquals(500, result.httpStatus);
        System.assertEquals(false, result.success);
    }
}