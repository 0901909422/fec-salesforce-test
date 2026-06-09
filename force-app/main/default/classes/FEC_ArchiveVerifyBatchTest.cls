/**
 * FEC_ArchiveVerifyBatch_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_ArchiveVerifyBatch (verify archive status + delete cases).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_ArchiveVerifyBatchTest {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock trả về tất cả case đều ARCHIVED */
    private class ArchivedMock implements HttpCalloutMock {
        private List<String> caseIds;
        public ArchivedMock(List<String> caseIds) {
            this.caseIds = caseIds;
        }
        public HttpResponse respond(HttpRequest req) {
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (String cId : caseIds) {
                results.add(new Map<String, String>{ 'caseId' => cId, 'status' => 'ARCHIVED' });
            }
            Map<String, Object> body = new Map<String, Object>{
                'code' => 200,
                'message' => 'OK',
                'data' => new Map<String, Object>{ 'results' => results }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    /** Mock trả về tất cả case đều PENDING */
    private class PendingMock implements HttpCalloutMock {
        private List<String> caseIds;
        public PendingMock(List<String> caseIds) {
            this.caseIds = caseIds;
        }
        public HttpResponse respond(HttpRequest req) {
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (String cId : caseIds) {
                results.add(new Map<String, String>{ 'caseId' => cId, 'status' => 'PENDING' });
            }
            Map<String, Object> body = new Map<String, Object>{
                'code' => 200,
                'message' => 'OK',
                'data' => new Map<String, Object>{ 'results' => results }
            };
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    /** Mock trả 500 → callout fail */
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    private static List<Case> createCasesForVerify(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status = 'Closed',
                Subject = 'Verify Test ' + i,
                FEC_Archive_Status__c = 'Processing',
                FEC_Attachment_Status__c = 'Completed'
            ));
        }
        insert cases;
        return [
            SELECT Id, CaseNumber, FEC_ID_Search__c
            FROM Case WHERE Id IN :cases
        ];
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testExecute_Archived_DeletesCases() {
        List<Case> cases = createCasesForVerify(2);
        List<String> searchIds = new List<String>();
        for (Case c : cases) {
            searchIds.add(c.FEC_ID_Search__c);
        }

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<Case> remaining = [SELECT Id FROM Case WHERE Id IN :cases];
        System.assertEquals(0, remaining.size(), 'Cases with ARCHIVED status should be deleted');
    }

    @IsTest
    static void testExecute_Pending_CasesRemain() {
        List<Case> cases = createCasesForVerify(2);
        List<String> searchIds = new List<String>();
        for (Case c : cases) {
            searchIds.add(c.FEC_ID_Search__c);
        }

        Test.setMock(HttpCalloutMock.class, new PendingMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<Case> remaining = [SELECT Id FROM Case WHERE Id IN :cases];
        System.assertEquals(2, remaining.size(), 'Cases with PENDING status should NOT be deleted');
    }

    @IsTest
    static void testExecute_CalloutFails_CasesRemain() {
        List<Case> cases = createCasesForVerify(2);

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<Case> remaining = [SELECT Id FROM Case WHERE Id IN :cases];
        System.assertEquals(2, remaining.size(), 'Cases should remain when callout fails');
    }

    @IsTest
    static void testExecute_EmptyScope() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, new List<Case>());
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Empty scope should not throw');
    }

    @IsTest
    static void testRun_NoMatchingCases() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch.run();
        Test.stopTest();

        System.assert(true, 'run() should complete without error');
    }

    @IsTest
    static void testRun_WithBatchSize() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch.run(50);
        Test.stopTest();

        System.assert(true, 'run(batchSize) should complete without error');
    }

    @IsTest
    static void testDeleteCasesAndRelated_WithRemarks() {
        List<Case> cases = createCasesForVerify(1);
        // Tạo remarks liên quan
        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c(
            FEC_Case__c = cases[0].Id,
            FEC_Case_Remarks__c = 'Test remark'
        );
        insert remark;

        List<String> searchIds = new List<String>();
        for (Case c : cases) {
            searchIds.add(c.FEC_ID_Search__c);
        }

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<FEC_Case_Remarks__c> remainingRemarks = [
            SELECT Id FROM FEC_Case_Remarks__c WHERE Id = :remark.Id
        ];
        System.assertEquals(0, remainingRemarks.size(), 'Remarks should be deleted with case');
    }
}
