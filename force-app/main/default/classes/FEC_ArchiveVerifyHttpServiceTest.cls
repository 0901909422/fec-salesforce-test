/**
 * FEC_ArchiveVerifyHttpService_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_ArchiveVerifyHttpService (check archive status từ Java API).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_ArchiveVerifyHttpServiceTest {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Map<String, Object> body = new Map<String, Object>{
                'code' => 200,
                'message' => 'OK',
                'data' => new Map<String, Object>{
                    'results' => new List<Object>{
                        new Map<String, String>{ 'caseId' => 'CASE-001', 'status' => 'ARCHIVED' },
                        new Map<String, String>{ 'caseId' => 'CASE-002', 'status' => 'PENDING' }
                    }
                }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(body));
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

    // ══════════════════════════════════════════════════════════════════════════
    // Tests
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCheckArchiveStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        List<String> caseIds = new List<String>{ 'CASE-001', 'CASE-002' };

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 results');
        System.assertEquals('ARCHIVED', result.get('CASE-001'), 'CASE-001 should be ARCHIVED');
        System.assertEquals('PENDING', result.get('CASE-002'), 'CASE-002 should be PENDING');
    }

    @IsTest
    static void testCheckArchiveStatus_ServerError_Throws() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        List<String> caseIds = new List<String>{ 'CASE-001' };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        } catch (FEC_ArchiveVerifyHttpService.VerifyCalloutException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('500'),
                'Exception should contain status code');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw VerifyCalloutException on server error');
    }

    @IsTest
    static void testCheckArchiveStatus_EmptyList() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(new List<String>());
        Test.stopTest();

        // API vẫn trả về mock data, nhưng test đảm bảo không crash
        System.assertNotEquals(null, result, 'Should return a map even with empty input');
    }
}
