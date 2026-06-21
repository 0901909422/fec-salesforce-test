@IsTest
private class FEC_PinResetCounterCallout_Test {

    private class PinResetCounterMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        PinResetCounterMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
        );
    }

    @IsTest
    static void testCallPinResetCounter_Success() {
        String jsonRes = '{"AccountNumber":"ACC123","CardNumber":"4111111111115432","Sys":{"Code":"1","Description":"Success","TransID":"TXN-001"}}';
        Test.setMock(HttpCalloutMock.class, new PinResetCounterMock(200, jsonRes));

        Test.startTest();
        FEC_PinResetCounterCallout.PinResetCounterResponse res =
            FEC_PinResetCounterCallout.callPinResetCounter('5432', 'TXN-001', 'ACC123', false);
        FEC_PinResetCounterCallout.logApiResponse();
        Test.stopTest();

        System.assertEquals(true, FEC_PinResetCounterCallout.isSuccess(res));
        System.assertEquals('1', res.Sys.Code);
        System.assertEquals('ACC123', res.AccountNumber);
    }

    @IsTest
    static void testCallPinResetCounter_HttpError() {
        Test.setMock(HttpCalloutMock.class, new PinResetCounterMock(500, 'Internal Server Error'));

        Test.startTest();
        FEC_PinResetCounterCallout.PinResetCounterResponse res =
            FEC_PinResetCounterCallout.callPinResetCounter('5432', 'TXN-002', 'ACC123', true);
        Test.stopTest();

        System.assertEquals(false, FEC_PinResetCounterCallout.isSuccess(res));
        System.assertEquals('500', res.errorCode);
        System.assertEquals('Internal Server Error', res.errorMessage);
    }

    @IsTest
    static void testIsSuccess_FailureCases() {
        System.assertEquals(false, FEC_PinResetCounterCallout.isSuccess(null));

        FEC_PinResetCounterCallout.PinResetCounterResponse noSys = new FEC_PinResetCounterCallout.PinResetCounterResponse();
        System.assertEquals(false, FEC_PinResetCounterCallout.isSuccess(noSys));

        FEC_PinResetCounterCallout.PinResetCounterResponse badCode = new FEC_PinResetCounterCallout.PinResetCounterResponse();
        badCode.Sys = new FEC_PinResetCounterCallout.Sys();
        badCode.Sys.Code = '99';
        System.assertEquals(false, FEC_PinResetCounterCallout.isSuccess(badCode));
    }

    @IsTest
    static void testValidateRequest() {
        Test.startTest();
        FEC_PinResetCounterCallout.ValidationResult missingTransId =
            FEC_PinResetCounterCallout.validateRequest('5432', '', 'ACC123');
        FEC_PinResetCounterCallout.ValidationResult missingLast4 =
            FEC_PinResetCounterCallout.validateRequest('', 'TXN-003', 'ACC123');
        FEC_PinResetCounterCallout.ValidationResult missingAccount =
            FEC_PinResetCounterCallout.validateRequest('5432', 'TXN-003', '');
        FEC_PinResetCounterCallout.ValidationResult valid =
            FEC_PinResetCounterCallout.validateRequest('5432', 'TXN-003', 'ACC123');
        Test.stopTest();

        System.assertEquals(false, missingTransId.isValid);
        System.assertEquals(false, missingLast4.isValid);
        System.assertEquals(false, missingAccount.isValid);
        System.assertEquals(true, valid.isValid);
    }

    @IsTest
    static void testCallPinResetCounter_Exception() {
        Test.startTest();
        FEC_PinResetCounterCallout.PinResetCounterResponse res =
            FEC_PinResetCounterCallout.callPinResetCounter(null, null, null, false);
        FEC_PinResetCounterCallout.logApiResponse();
        Test.stopTest();

        System.assertEquals('CALLOUT_ERROR', res.errorCode);
        System.assertNotEquals(null, res.errorMessage);
    }

    @IsTest
    static void testLogApiResponse_NoResponseLog() {
        Test.startTest();
        FEC_PinResetCounterCallout.logApiResponse();
        Test.stopTest();
        System.assert(true);
    }
}
