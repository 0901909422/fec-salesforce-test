@IsTest
private class FEC_FEOL2DNBServiceCallout_Test {
    private class Success200Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod(), 'Method must be POST.');
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assertEquals('PEGA_CSM', req.getHeader('source'));
            System.assertNotEquals(null, req.getHeader('requester'));
            System.assertNotEquals(null, req.getHeader('trans_id'));
            System.assertNotEquals(null, req.getHeader('confirmer'));
            System.assert(req.getBody().contains('reason-200'), 'Request payload should be serialized.');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"pxObjClass":"DNB","Sys":{"Code":"200","Description":"OK","pxObjClass":"Sys","RequestDateTime":"2026-01-01T00:00:00.000Z","TransID":"T-200"}}'
            );
            return res;
        }
    }

    private class Success201Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody(
                '{"pxObjClass":"DNB","Sys":{"Code":"201","Description":"Created","pxObjClass":"Sys","RequestDateTime":"2026-01-01T00:00:00.000Z","TransID":"T-201"}}'
            );
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;
        }
    }

    private static List<Object> buildReqList(String reasonSuffix) {
        FEC_FEOL2DNBServiceCallout.DNBRequest row = new FEC_FEOL2DNBServiceCallout.DNBRequest();
        row.reason = 'reason-' + reasonSuffix;
        row.full_name = 'User ' + reasonSuffix;
        row.nid = '0123456789';
        row.do_not_bother = true;
        row.type = 'PHONE';
        row.type_value = '0901234567';
        return new List<Object>{ row };
    }

    @IsTest
    static void testCreateDNB_success200() {
        Test.setMock(HttpCalloutMock.class, new Success200Mock());

        Test.startTest();
        FEC_FEOL2DNBServiceCallout.DNBResponse res =
            FEC_FEOL2DNBServiceCallout.createDNB(buildReqList('200'));
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null.');
        System.assertNotEquals(null, res.Sys, 'Sys object should be parsed.');
        System.assertEquals('200', res.Sys.Code);
        System.assertEquals('T-200', res.Sys.TransID);
    }

    @IsTest
    static void testCreateDNB_success201() {
        Test.setMock(HttpCalloutMock.class, new Success201Mock());

        Test.startTest();
        FEC_FEOL2DNBServiceCallout.DNBResponse res =
            FEC_FEOL2DNBServiceCallout.createDNB(buildReqList('201'));
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('201', res.Sys.Code);
    }

    @IsTest
    static void testCreateDNB_errorStatusThrows() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Boolean thrown = false;
        Test.startTest();
        try {
            FEC_FEOL2DNBServiceCallout.createDNB(buildReqList('500'));
        } catch (CalloutException ex) {
            thrown = ex.getMessage().contains('FEOL2 Error: 500');
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Should throw CalloutException on non-success status.');
    }
}
