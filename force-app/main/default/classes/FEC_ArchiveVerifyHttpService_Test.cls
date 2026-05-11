/**
 * FEC_ArchiveVerifyHttpService_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_ArchiveVerifyHttpService.checkArchiveStatus().
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_ArchiveVerifyHttpService_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock trả về status thành công với list results tùy ý */
    private class SuccessMock implements HttpCalloutMock {
        private List<Map<String, String>> results;

        public SuccessMock(List<Map<String, String>> results) {
            this.results = results;
        }

        public HttpResponse respond(HttpRequest req) {
            // Verify request metadata
            System.assertEquals('POST', req.getMethod(), 'Method phải là POST');
            System.assert(
                req.getEndpoint().endsWith('/archival/dispatcher/api/v1/cases/archive-status'),
                'Endpoint phải đúng path'
            );
            System.assertEquals(
                FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
                req.getHeader('Content-Type'),
                'Content-Type phải là JSON'
            );
            System.assertEquals(
                FEC_ConstantArchive.X_API_KEY_ARCHIVE,
                req.getHeader('X-API-KEY'),
                'X-API-KEY phải được set'
            );
            System.assertNotEquals(null, req.getBody(), 'Body không được null');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            Map<String, Object> responseBody = new Map<String, Object>{
                'code' => 200,
                'message' => 'OK',
                'data' => new Map<String, Object>{
                    'results' => results
                }
            };
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }

    /** Mock trả về HTTP 500 */
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** Mock trả về HTTP 400 */
    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad payload"}');
            return res;
        }
    }

    /** Mock trả về HTTP 401 Unauthorized */
    private class UnauthorizedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('Unauthorized');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: Response thành công với nhiều status khác nhau
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusSuccess() {
        List<String> caseIds = new List<String>{ 'CASE-001', 'CASE-002', 'CASE-003' };
        List<Map<String, String>> mockResults = new List<Map<String, String>>{
            new Map<String, String>{ 'caseId' => 'CASE-001', 'status' => 'ARCHIVED' },
            new Map<String, String>{ 'caseId' => 'CASE-002', 'status' => 'PENDING' },
            new Map<String, String>{ 'caseId' => 'CASE-003', 'status' => 'FAILED' }
        };

        Test.setMock(HttpCalloutMock.class, new SuccessMock(mockResults));

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        Test.stopTest();

        System.assertEquals(3, result.size(), 'Phải có 3 entries trong map');
        System.assertEquals('ARCHIVED', result.get('CASE-001'), 'CASE-001 phải là ARCHIVED');
        System.assertEquals('PENDING', result.get('CASE-002'), 'CASE-002 phải là PENDING');
        System.assertEquals('FAILED', result.get('CASE-003'), 'CASE-003 phải là FAILED');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: Response thành công với results rỗng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusEmptyResults() {
        List<String> caseIds = new List<String>{ 'CASE-001' };
        List<Map<String, String>> mockResults = new List<Map<String, String>>();

        Test.setMock(HttpCalloutMock.class, new SuccessMock(mockResults));

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Map phải rỗng khi results rỗng');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: Gọi với caseIds rỗng vẫn hoạt động
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusEmptyCaseIds() {
        List<Map<String, String>> mockResults = new List<Map<String, String>>();

        Test.setMock(HttpCalloutMock.class, new SuccessMock(mockResults));

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Kết quả không được null');
        System.assertEquals(0, result.size(), 'Map phải rỗng');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: Single case ARCHIVED
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusSingleCase() {
        List<String> caseIds = new List<String>{ 'CASE-SINGLE' };
        List<Map<String, String>> mockResults = new List<Map<String, String>>{
            new Map<String, String>{ 'caseId' => 'CASE-SINGLE', 'status' => 'ARCHIVED' }
        };

        Test.setMock(HttpCalloutMock.class, new SuccessMock(mockResults));

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Phải có 1 entry');
        System.assertEquals('ARCHIVED', result.get('CASE-SINGLE'));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: HTTP 500 → VerifyCalloutException
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusServerError() {
        List<String> caseIds = new List<String>{ 'CASE-001' };

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Boolean exceptionThrown = false;
        String exceptionMessage = '';

        Test.startTest();
        try {
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        } catch (FEC_ArchiveVerifyHttpService.VerifyCalloutException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Phải throw VerifyCalloutException khi HTTP 500');
        System.assert(
            exceptionMessage.contains('500'),
            'Exception message phải chứa status code 500'
        );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: HTTP 400 → VerifyCalloutException
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusBadRequest() {
        List<String> caseIds = new List<String>{ 'CASE-001' };

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        } catch (FEC_ArchiveVerifyHttpService.VerifyCalloutException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('400'),
                'Exception message phải chứa status code 400'
            );
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Phải throw VerifyCalloutException khi HTTP 400');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: HTTP 401 → VerifyCalloutException
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusUnauthorized() {
        List<String> caseIds = new List<String>{ 'CASE-001' };

        Test.setMock(HttpCalloutMock.class, new UnauthorizedMock());

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        } catch (FEC_ArchiveVerifyHttpService.VerifyCalloutException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Phải throw VerifyCalloutException khi HTTP 401');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: Verify request body chứa đúng caseIds
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusRequestBody() {
        List<String> caseIds = new List<String>{ 'CASE-A', 'CASE-B' };
        List<Map<String, String>> mockResults = new List<Map<String, String>>{
            new Map<String, String>{ 'caseId' => 'CASE-A', 'status' => 'ARCHIVED' },
            new Map<String, String>{ 'caseId' => 'CASE-B', 'status' => 'PENDING' }
        };

        Test.setMock(HttpCalloutMock.class, new RequestBodyValidatorMock(caseIds, mockResults));

        Test.startTest();
        Map<String, String> result = FEC_ArchiveVerifyHttpService.checkArchiveStatus(caseIds);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Phải có 2 entries');
    }

    /** Mock validate request body chứa đúng caseIds */
    private class RequestBodyValidatorMock implements HttpCalloutMock {
        private List<String> expectedCaseIds;
        private List<Map<String, String>> results;

        public RequestBodyValidatorMock(List<String> expectedCaseIds, List<Map<String, String>> results) {
            this.expectedCaseIds = expectedCaseIds;
            this.results = results;
        }

        public HttpResponse respond(HttpRequest req) {
            Map<String, Object> reqBody =
                (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            List<Object> bodyCaseIds = (List<Object>) reqBody.get('caseIds');

            System.assertEquals(
                expectedCaseIds.size(),
                bodyCaseIds.size(),
                'Số lượng caseIds trong body phải đúng'
            );
            for (Integer i = 0; i < expectedCaseIds.size(); i++) {
                System.assertEquals(
                    expectedCaseIds[i],
                    (String) bodyCaseIds[i],
                    'caseId trong body phải khớp'
                );
            }

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            Map<String, Object> responseBody = new Map<String, Object>{
                'code' => 200,
                'message' => 'OK',
                'data' => new Map<String, Object>{ 'results' => results }
            };
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 9: HTTP 299 (biên trên của success range) → thành công
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusStatusCode299() {
        Test.setMock(HttpCalloutMock.class, new StatusCodeMock(299));

        Test.startTest();
        Map<String, String> result =
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(new List<String>{ 'CASE-001' });
        Test.stopTest();

        System.assertNotEquals(null, result, 'Status 299 vẫn phải được xem là success');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 10: HTTP 300 → VerifyCalloutException (boundary test)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCheckArchiveStatusStatusCode300() {
        Test.setMock(HttpCalloutMock.class, new StatusCodeMock(300));

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            FEC_ArchiveVerifyHttpService.checkArchiveStatus(new List<String>{ 'CASE-001' });
        } catch (FEC_ArchiveVerifyHttpService.VerifyCalloutException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Status 300 phải throw exception');
    }

    /** Mock trả về status code tùy ý, body JSON hợp lệ với results rỗng */
    private class StatusCodeMock implements HttpCalloutMock {
        private Integer statusCode;

        public StatusCodeMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            Map<String, Object> responseBody = new Map<String, Object>{
                'code' => statusCode,
                'message' => 'Test',
                'data' => new Map<String, Object>{
                    'results' => new List<Map<String, String>>()
                }
            };
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 11: Exception class có thể construct được
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testVerifyCalloutExceptionConstruction() {
        FEC_ArchiveVerifyHttpService.VerifyCalloutException ex =
            new FEC_ArchiveVerifyHttpService.VerifyCalloutException('Test message');

        System.assertEquals('Test message', ex.getMessage(), 'Message phải khớp');
    }
}
