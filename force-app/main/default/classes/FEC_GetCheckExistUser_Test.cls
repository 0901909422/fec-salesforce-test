@IsTest
private class FEC_GetCheckExistUser_Test {

    private class CheckExistUserMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{' +
                '"pxObjClass":"FEC-Data-CheckExistUser",' +
                '"pxResults":"true",' +
                '"response_GET":{' +
                '"pxObjClass":"FEC-Data-Sys",' +
                '"Code2":1,' +
                '"Description":"Success",' +
                '"DateTime2":"2026-06-04T10:00:00Z",' +
                '"TransID":"TXN-001"' +
                '},' +
                '"pxReqParameters":{' +
                '"NationalID":"079123456789",' +
                '"PhoneNumber":"0901234567"' +
                '}' +
                '}'
            );
            return res;
        }
    }

    @IsTest
    static void testGetCheckExistUser_Success() {
        Test.setMock(HttpCalloutMock.class, new CheckExistUserMock());

        Test.startTest();
        FEC_GetCheckExistUser.ResponseWrapper result =
            FEC_GetCheckExistUser.getCheckExistUser('0901234567', '079123456789');
        FEC_GetCheckExistUser.logApiResponse();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('true', result.pxResults);
        System.assertNotEquals(null, result.Sys);
        System.assertEquals(1, result.Sys.Code2);
        System.assertEquals('Success', result.Sys.Description);
        System.assertNotEquals(null, result.RequestParams);
        System.assertEquals('079123456789', result.RequestParams.NationalID);
        System.assertEquals('0901234567', result.RequestParams.PhoneNumber);
    }

    @IsTest
    static void testNormalizePhoneNumber() {
        Test.startTest();
        System.assertEquals('0901234567', FEC_GetCheckExistUser.normalizePhoneNumber('+84901234567'));
        System.assertEquals('0901234567', FEC_GetCheckExistUser.normalizePhoneNumber('0901234567'));
        System.assertEquals(null, FEC_GetCheckExistUser.normalizePhoneNumber(null));
        Test.stopTest();
    }

    @IsTest
    static void testCallGetCheckExistUser_ValidationErrors() {
        Test.startTest();
        try {
            FEC_GetCheckExistUser.getCheckExistUser(null, '079123456789');
            System.assert(false, 'Expected validation error for blank phone.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_GetCheckExistUser.getCheckExistUser('0901234567', null);
            System.assert(false, 'Expected validation error for blank national ID.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            FEC_GetCheckExistUser.callGetCheckExistUser('0901234567', '079123456789', true);
            System.assert(false, 'Expected test API failure.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetCheckExistUser_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());

        Test.startTest();
        try {
            FEC_GetCheckExistUser.getCheckExistUser('0901234567', '079123456789');
            System.assert(false, 'Expected HTTP error.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('');
            return res;
        }
    }
}
