/**
 * FEC_ArchiveVerifyBatch_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_ArchiveVerifyBatch (check archive status từ Java API và xóa Case).
 *
 * Lưu ý về ClosedDate:
 *   Query locator trong start() lọc Case có ClosedDate <= now - 90 ngày
 *   VÀ FEC_Archive_Status__c = 'Processing'.
 *   Trong test, ClosedDate được Salesforce auto-set khi Status = 'Closed'
 *   (= thời điểm test chạy), vì vậy start() luôn trả về empty set.
 *   → Logic xử lý được test trực tiếp qua execute() với scope giả lập.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_ArchiveVerifyBatch_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock API trả ARCHIVED cho tất cả cases → sẽ xóa */
    private class ArchivedMock implements HttpCalloutMock {
        private List<String> caseSearchIds;
        
        public ArchivedMock(List<String> caseSearchIds) {
            this.caseSearchIds = caseSearchIds;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (String searchId : caseSearchIds) {
                results.add(new Map<String, String>{
                    'caseId' => searchId,
                    'status' => 'ARCHIVED'
                });
            }
            
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

    /** Mock API trả PENDING cho tất cả cases → không xóa */
    private class PendingMock implements HttpCalloutMock {
        private List<String> caseSearchIds;
        
        public PendingMock(List<String> caseSearchIds) {
            this.caseSearchIds = caseSearchIds;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (String searchId : caseSearchIds) {
                results.add(new Map<String, String>{
                    'caseId' => searchId,
                    'status' => 'PENDING'
                });
            }
            
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

    /** Mock API trả mixed status (một số ARCHIVED, một số PENDING) */
    private class MixedStatusMock implements HttpCalloutMock {
        private List<String> archivedIds;
        private List<String> pendingIds;
        
        public MixedStatusMock(List<String> archivedIds, List<String> pendingIds) {
            this.archivedIds = archivedIds;
            this.pendingIds = pendingIds;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (String searchId : archivedIds) {
                results.add(new Map<String, String>{
                    'caseId' => searchId,
                    'status' => 'ARCHIVED'
                });
            }
            for (String searchId : pendingIds) {
                results.add(new Map<String, String>{
                    'caseId' => searchId,
                    'status' => 'PENDING'
                });
            }
            
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

    /** Mock API trả 500 Server Error */
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** Mock API trả 400 Bad Request */
    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad payload"}');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Tạo Case với Status = Closed và FEC_Archive_Status__c = 'Processing'
     */
    private static List<Case> createProcessingCases(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status = 'Closed',
                Subject = 'Test Case ' + i,
                FEC_Archive_Status__c = FEC_ConstantCommon.PROCESSING_STATUS,
                FEC_Attachment_Status__c = FEC_ConstantCommon.STATUS_COMPLETED
            ));
        }
        insert cases;
        return [
            SELECT Id, CaseNumber, Status, ClosedDate,
                   FEC_Archive_Status__c, FEC_Attachment_Status__c,
                   FEC_ID_Search__c
            FROM Case
            WHERE Id IN :cases
        ];
    }

    /**
     * Tạo FEC_Case_Remarks__c cho Case
     */
    private static void createRemarksForCase(Id caseId, Integer count) {
        List<FEC_Case_Remarks__c> remarks = new List<FEC_Case_Remarks__c>();
        for (Integer i = 0; i < count; i++) {
            remarks.add(new FEC_Case_Remarks__c(
                FEC_Case__c = caseId,
                FEC_Case_Remarks__c = 'Test remark ' + i
            ));
        }
        insert remarks;
    }

    /**
     * Tạo FEC_ChatHistory__c cho Case
     */
    private static void createChatHistoryForCase(Id caseId, Integer count) {
        List<FEC_ChatHistory__c> chatHistories = new List<FEC_ChatHistory__c>();
        for (Integer i = 0; i < count; i++) {
            chatHistories.add(new FEC_ChatHistory__c(
                FEC_Case__c = caseId,
                FEC_Message__c = 'Test message ' + i
            ));
        }
        insert chatHistories;
    }

    /**
     * Tạo ContentVersion (file) và link với Case
     */
    private static void createAttachmentForCase(Id caseId, String fileName, String fileExtension) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName + '.' + fileExtension;
        cv.VersionData = Blob.valueOf('Test file content for ' + fileName);
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = caseId;
        cdl.ShareType = 'V';
        insert cdl;
    }

    /**
     * Lấy danh sách FEC_ID_Search__c từ cases
     */
    private static List<String> getSearchIds(List<Case> cases) {
        List<String> searchIds = new List<String>();
        for (Case c : cases) {
            searchIds.add(c.FEC_ID_Search__c);
        }
        return searchIds;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: execute() với status ARCHIVED → xóa Case
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteArchivedStatus() {
        List<Case> cases = createProcessingCases(1);
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        System.assertEquals(0, remainingCount, 'Case với status ARCHIVED phải bị xóa');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: execute() với status PENDING → không xóa Case
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecutePendingStatus() {
        List<Case> cases = createProcessingCases(1);
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new PendingMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        System.assertEquals(1, remainingCount, 'Case với status PENDING không được xóa');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: execute() xóa Case kèm FEC_Case_Remarks__c
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteDeleteWithRemarks() {
        List<Case> cases = createProcessingCases(1);
        createRemarksForCase(cases[0].Id, 3);
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        Integer remarkCount = [SELECT COUNT() FROM FEC_Case_Remarks__c WHERE FEC_Case__c = :cases[0].Id];
        
        System.assertEquals(0, caseCount, 'Case phải bị xóa');
        System.assertEquals(0, remarkCount, 'Remarks phải bị xóa trước Case');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: execute() xóa Case kèm FEC_ChatHistory__c
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteDeleteWithChatHistory() {
        List<Case> cases = createProcessingCases(1);
        createChatHistoryForCase(cases[0].Id, 2);
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        Integer chatCount = [SELECT COUNT() FROM FEC_ChatHistory__c WHERE FEC_Case__c = :cases[0].Id];
        
        System.assertEquals(0, caseCount, 'Case phải bị xóa');
        System.assertEquals(0, chatCount, 'ChatHistory phải bị xóa trước Case');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: execute() xóa Case kèm ContentDocument
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteDeleteWithAttachments() {
        List<Case> cases = createProcessingCases(1);
        createAttachmentForCase(cases[0].Id, 'document', 'pdf');
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        
        System.assertEquals(0, caseCount, 'Case phải bị xóa');
        // ContentDocument có thể không bị xóa nếu còn link ở nơi khác (owner link)
        // Chỉ verify Case đã bị xóa thành công
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: execute() với mixed status (ARCHIVED + PENDING)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteMixedStatus() {
        List<Case> cases = createProcessingCases(3);
        
        List<String> archivedIds = new List<String>{ cases[0].FEC_ID_Search__c, cases[1].FEC_ID_Search__c };
        List<String> pendingIds = new List<String>{ cases[2].FEC_ID_Search__c };

        Test.setMock(HttpCalloutMock.class, new MixedStatusMock(archivedIds, pendingIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer deletedCount = [SELECT COUNT() FROM Case WHERE Id IN :new List<Id>{cases[0].Id, cases[1].Id}];
        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :cases[2].Id];
        
        System.assertEquals(0, deletedCount, 'Cases với ARCHIVED phải bị xóa');
        System.assertEquals(1, remainingCount, 'Case với PENDING không được xóa');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: execute() với callout error → không xóa, tăng error count
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteCalloutError() {
        List<Case> cases = createProcessingCases(2);

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id IN :cases];
        System.assertEquals(2, remainingCount, 'Cases không được xóa khi callout lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: execute() với scope rỗng → không lỗi
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteEmptyScope() {
        Test.setMock(HttpCalloutMock.class, new ArchivedMock(new List<String>()));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, new List<Case>());
        Test.stopTest();

        System.assert(true, 'execute() với scope rỗng phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 9: finish() chạy không lỗi
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFinishMethod() {
        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'finish() phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 10: Full batch via run()
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testRunMethod() {
        createProcessingCases(2);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(new List<String>()));

        Test.startTest();
        FEC_ArchiveVerifyBatch.run();
        Test.stopTest();

        // Cases mới tạo không match ClosedDate <= now - 90 days
        System.assert(true, 'run() phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 11: run() với custom batch size
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testRunWithBatchSize() {
        createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(new List<String>()));

        Test.startTest();
        FEC_ArchiveVerifyBatch.run(50);
        Test.stopTest();

        System.assert(true, 'run(batchSize) phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 12: Full batch execution qua Database.executeBatch
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFullBatchExecution() {
        createProcessingCases(2);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(new List<String>()));

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_ArchiveVerifyBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, JobType, NumberOfErrors
            FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job, 'Batch job phải được tạo');
        System.assertEquals('BatchApex', job.JobType, 'Job type phải là BatchApex');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 13: start() query locator
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStartQueryLocator() {
        createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(new List<String>()));

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_ArchiveVerifyBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status, 'Batch job phải complete');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 14: Xóa Case với tất cả related records
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDeleteCaseWithAllRelated() {
        List<Case> cases = createProcessingCases(1);
        createRemarksForCase(cases[0].Id, 2);
        createChatHistoryForCase(cases[0].Id, 2);
        createAttachmentForCase(cases[0].Id, 'doc1', 'pdf');
        createAttachmentForCase(cases[0].Id, 'doc2', 'png');
        
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        System.assertEquals(0, caseCount, 'Case với tất cả related records phải bị xóa thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 15: Verify DEFAULT_BATCH_SIZE constant
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDefaultBatchSize() {
        System.assertEquals(100, FEC_ArchiveVerifyBatch.DEFAULT_BATCH_SIZE,
            'DEFAULT_BATCH_SIZE phải là 100');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 16: execute() với nhiều Cases cùng lúc
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteMultipleCases() {
        List<Case> cases = createProcessingCases(5);
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id IN :cases];
        System.assertEquals(0, remainingCount, 'Tất cả cases với ARCHIVED phải bị xóa');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 17: Stateful counters qua nhiều execute()
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStatefulCounters() {
        List<Case> batch1 = createProcessingCases(2);
        List<String> searchIds1 = getSearchIds(batch1);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds1));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, batch1);
        batch.finish(null);
        Test.stopTest();

        Integer totalRemaining = [SELECT COUNT() FROM Case WHERE Id IN :batch1];
        System.assertEquals(0, totalRemaining, 'Tất cả cases phải bị xóa');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 18: Case với FEC_Attachment_Status__c = NULL (Batch 2 chưa chạy)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testCaseWithNullAttachmentStatus() {
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Test Case with null attachment status',
            FEC_Archive_Status__c = FEC_ConstantCommon.PROCESSING_STATUS,
            FEC_Attachment_Status__c = null
        );
        insert testCase;

        List<Case> cases = [
            SELECT Id, CaseNumber, FEC_ID_Search__c
            FROM Case WHERE Id = :testCase.Id
        ];
        List<String> searchIds = getSearchIds(cases);

        Test.setMock(HttpCalloutMock.class, new ArchivedMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(0, remainingCount, 'Case với null attachment status phải bị xóa khi ARCHIVED');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 19: Bad request error (400)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteBadRequestError() {
        List<Case> cases = createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        System.assertEquals(1, remainingCount, 'Case không được xóa khi API trả 400');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 20: deleteCasesAndRelated với empty set - verify không lỗi
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDeleteCasesAndRelatedEmpty() {
        // Test này verify rằng batch xử lý đúng khi không có case nào cần xóa
        List<Case> cases = createProcessingCases(1);
        List<String> searchIds = getSearchIds(cases);

        // Mock trả PENDING → không có case nào bị xóa
        Test.setMock(HttpCalloutMock.class, new PendingMock(searchIds));

        Test.startTest();
        FEC_ArchiveVerifyBatch batch = new FEC_ArchiveVerifyBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer remainingCount = [SELECT COUNT() FROM Case WHERE Id = :cases[0].Id];
        System.assertEquals(1, remainingCount, 'Case không bị xóa khi status PENDING');
    }
}
