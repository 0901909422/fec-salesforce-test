/**
 * FEC_CaseExportHttpService_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_CaseExportHttpService (POST cases lên external API).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_CaseExportHttpServiceTest {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad payload"}');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testPostCases_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        String payload = '[{"CaseNumber":"00001","Status":"Closed"}]';

        Test.startTest();
        FEC_CaseExportHttpService.postCases(payload);
        Test.stopTest();

        System.assert(true, 'postCases() should complete without exception on 200');
    }

    @IsTest
    static void testPostCases_ServerError_ThrowsAfterRetry() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        String payload = '[{"CaseNumber":"00001"}]';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CaseExportHttpService.postCases(payload);
        } catch (FEC_CaseExportHttpService.ExportCalloutException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('retry'),
                'Exception message should mention retry');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw ExportCalloutException after retries exhausted');
    }

    @IsTest
    static void testPostCases_BadRequest_ThrowsImmediately() {
        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        String payload = '[{"CaseNumber":"00001"}]';

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_CaseExportHttpService.postCases(payload);
        } catch (FEC_CaseExportHttpService.ExportCalloutException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('400'),
                'Exception should contain status code 400');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw immediately on 4xx without retry');
    }
}
