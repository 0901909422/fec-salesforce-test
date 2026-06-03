@IsTest
private class FEC_CardLockUnlockServiceCallout_Test {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assertNotEquals(null, req.getHeader('TransID'));
            System.assertNotEquals(null, req.getHeader('DateTime'));
            System.assertEquals('PEGA_CSM', req.getHeader('RequestorID'));
            System.assert(req.getBody().contains('"blockCode":"L1"'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"pxObjClass":"CardUnlockResponse","sys2":{"blockCode":"L1","code":"00","datetime_x":"2026-06-02T14:00:00.000+07:00","description":"Success","pxObjClass":"Sys2","transID":"mock-trans-id"}}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('500 Internal Server Error');
            res.setBody('{"message":"internal error"}');
            return res;
        }
    }

    private static FEC_CardLockUnlockServiceCallout.CardUnlockRequest buildRequest() {
        FEC_CardLockUnlockServiceCallout.CardRequestBody body =
            new FEC_CardLockUnlockServiceCallout.CardRequestBody();
        body.blockCode = 'L1';
        body.fucn = 'LOCK';
        body.lasr4Digits = '1234';
        body.accountNumber = '0001500010000000261';

        FEC_CardLockUnlockServiceCallout.CardUnlockRequest req =
            new FEC_CardLockUnlockServiceCallout.CardUnlockRequest();
        req.body = body;
        return req;
    }

    @IsTest
    static void testCardUnlock_successResponse() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CardLockUnlockServiceCallout.CardUnlockResponse resp =
            FEC_CardLockUnlockServiceCallout.cardUnlock(buildRequest());
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertNotEquals(null, resp.sys2);
        System.assertEquals('00', resp.sys2.code);
        System.assertEquals('Success', resp.sys2.description);
        System.assertEquals('mock-trans-id', resp.sys2.transID);
    }

    @IsTest
    static void testCardUnlock_httpErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        FEC_CardLockUnlockServiceCallout.CardUnlockResponse resp =
            FEC_CardLockUnlockServiceCallout.cardUnlock(buildRequest());
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertNotEquals(null, resp.sys2);
        System.assertEquals('500', resp.sys2.code);
        System.assert(resp.sys2.description.contains('HTTP Error'));
        System.assertNotEquals(null, resp.sys2.transID, 'Transaction id should be set on error.');
    }
}
