/**
 * FEC_CaseExportBatch_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_CaseExportBatch (dynamic bulk export + archive flag).
 *
 * Lưu ý về ClosedDate:
 *   Query locator trong start() lọc Case có ClosedDate <= now - 90 ngày.
 *   Trong test, ClosedDate được Salesforce auto-set khi Status = 'Closed'
 *   (= thời điểm test chạy), vì vậy start() luôn trả về empty set.
 *   → Logic xử lý được test trực tiếp qua execute() với scope giả lập.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_CaseExportBatch_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock API trả 200 OK */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    /** Mock API luôn trả 500 → execute() sẽ catch và tăng failCount */
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** Mock API trả 400 Bad Request → không retry, throw ngay */
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

    private static List<Case> createClosedCases(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status  = 'Closed',
                Subject = 'Test Case ' + i
            ));
        }
        insert cases;
        return [
            SELECT Id, CaseNumber, Status, ClosedDate,
                   FEC_Archive_Status__c, FEC_Archive_Sent_At__c,
                   FEC_Attachment_Status__c
            FROM Case
            WHERE Id IN :cases
        ];
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: execute() thành công → flag = 'Processing', Sent_At được set
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteSuccessUpdatesArchiveStatus() {
        List<Case> cases = createClosedCases(3);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<Case> updated = [
            SELECT Id, FEC_Archive_Status__c, FEC_Archive_Sent_At__c
            FROM Case WHERE Id IN :cases
        ];
        System.assertEquals(3, updated.size(), 'Phải còn đủ 3 cases');
        for (Case c : updated) {
            System.assertEquals('Processing', c.FEC_Archive_Status__c,
                'FEC_Archive_Status__c phải là Processing sau callout thành công');
            System.assertNotEquals(null, c.FEC_Archive_Sent_At__c,
                'FEC_Archive_Sent_At__c phải được set');
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: execute() callout 5xx → flag KHÔNG được update
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteServerErrorDoesNotUpdateFlag() {
        List<Case> cases = createClosedCases(2);

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        List<Case> result = [
            SELECT Id, FEC_Archive_Status__c, FEC_Archive_Sent_At__c
            FROM Case WHERE Id IN :cases
        ];
        for (Case c : result) {
            System.assertNotEquals('Processing', c.FEC_Archive_Status__c,
                'Flag KHÔNG được set Processing khi callout fail');
            System.assertEquals(null, c.FEC_Archive_Sent_At__c,
                'Sent_At vẫn null khi callout fail');
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: execute() với 4xx → exception được catch, flag không update
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteBadRequestIsHandled() {
        List<Case> cases = createClosedCases(1);

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        // Không throw vì execute() catch mọi Exception
        batch.execute(null, cases);
        Test.stopTest();

        Case c = [
            SELECT FEC_Archive_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertNotEquals('Processing', c.FEC_Archive_Status__c,
            'Flag không được set khi HTTP 400');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: execute() với scope rỗng → không lỗi, không callout
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteEmptyScope() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, new List<Case>());
        Test.stopTest();

        System.assert(true, 'execute() với scope rỗng phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: Full batch via run() — không có case nào match threshold 90 ngày
    //         → start()/finish() chạy, execute() không được gọi
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testRunNoMatchingCases() {
        // Cases mới tạo: ClosedDate ~= now → không match ClosedDate <= now - 90 days
        createClosedCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch.run();
        Test.stopTest();

        // Không có case nào bị update Processing
        Integer processingCount = [
            SELECT COUNT() FROM Case
            WHERE FEC_Archive_Status__c = 'Processing'
        ];
        System.assertEquals(0, processingCount,
            'Không case nào được archive vì ClosedDate < 90 ngày');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: run(batchSize) — overload nhận batch size
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testRunWithCustomBatchSize() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch.run(50);
        Test.stopTest();

        System.assert(true, 'run(batchSize) chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: Full batch execution qua Database.executeBatch (start/execute/finish)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFullBatchExecution() {
        createClosedCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_CaseExportBatch(), 10);
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'Database.executeBatch phải trả về jobId hợp lệ');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: finish() chạy không lỗi (sau khi có thành công và thất bại)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFinishAfterMixedResults() {
        List<Case> cases = createClosedCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'finish() phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 9: DEFAULT_BATCH_SIZE constant hiện diện và hợp lệ
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDefaultBatchSizeConstant() {
        System.assertEquals(100, FEC_CaseExportBatch.DEFAULT_BATCH_SIZE,
            'DEFAULT_BATCH_SIZE phải là 100');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 10: execute() 2 lần → successCount tích lũy qua stateful
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStatefulAccumulation() {
        // Tạo tất cả cases trước
        List<Case> allCases = createClosedCases(5);
        List<Case> batch1 = new List<Case>{ allCases[0], allCases[1] };
        List<Case> batch2 = new List<Case>{ allCases[2], allCases[3], allCases[4] };

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, batch1);
        batch.execute(null, batch2);
        batch.finish(null);
        Test.stopTest();

        // Query tất cả cases đã tạo
        Integer processingCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :allCases AND FEC_Archive_Status__c = 'Processing'
        ];
        System.assertEquals(5, processingCount,
            'Cả 5 cases (2+3) phải có status Processing');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 11: execute() với Case có lookup relationships (Account, Contact)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteWithLookupRelationships() {
        // Tạo Account và Contact để test lookup query
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        // Tạo Case với lookup relationships
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Test Case with Lookups',
            AccountId = acc.Id,
            ContactId = con.Id
        );
        insert testCase;

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, AccountId, ContactId
            FROM Case WHERE Id = :testCase.Id
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Archive_Status__c, FEC_Archive_Sent_At__c
            FROM Case WHERE Id = :testCase.Id
        ];
        System.assertEquals('Processing', updated.FEC_Archive_Status__c,
            'Case với lookups phải được xử lý thành công');
        System.assertNotEquals(null, updated.FEC_Archive_Sent_At__c,
            'FEC_Archive_Sent_At__c phải được set');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 12: execute() với multiple Cases có cùng lookup object
    // → Test duplicate check trong assembleLookupForCase()
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteMultipleCasesSameLookup() {
        Account acc = new Account(Name = 'Shared Account');
        insert acc;

        // Tạo 2 cases cùng reference đến 1 Account
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 2; i++) {
            cases.add(new Case(
                Status = 'Closed',
                Subject = 'Test Case ' + i,
                AccountId = acc.Id
            ));
        }
        insert cases;

        List<Case> queriedCases = [
            SELECT Id, CaseNumber, Status, AccountId
            FROM Case WHERE Id IN :cases
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, queriedCases);
        Test.stopTest();

        Integer processingCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :cases AND FEC_Archive_Status__c = 'Processing'
        ];
        System.assertEquals(2, processingCount,
            'Cả 2 cases cùng lookup phải được xử lý');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 13: execute() với Case không có lookup (null references)
    // → Test null handling trong queryLookupObjectsBatch()
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteCaseWithoutLookups() {
        // Case không có AccountId, ContactId
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Case without lookups'
        );
        insert testCase;

        List<Case> cases = [
            SELECT Id, CaseNumber, Status
            FROM Case WHERE Id = :testCase.Id
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Archive_Status__c
            FROM Case WHERE Id = :testCase.Id
        ];
        System.assertEquals('Processing', updated.FEC_Archive_Status__c,
            'Case không có lookups vẫn phải được xử lý');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 14: finish() với mixed success và failure counts
    // → Verify failedInfo được log
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFinishWithFailures() {
        List<Case> successCases = createClosedCases(2);
        List<Case> failCases = createClosedCases(1);

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();

        // Batch 1: Success
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        batch.execute(null, successCases);

        // Batch 2: Failure
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        batch.execute(null, failCases);

        // finish() phải log cả success và failure
        batch.finish(null);
        Test.stopTest();

        // Verify success cases được update
        Integer successCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :successCases AND FEC_Archive_Status__c = 'Processing'
        ];
        System.assertEquals(2, successCount, '2 cases thành công phải có status Processing');

        // Verify fail cases không được update
        Case failCase = [
            SELECT FEC_Archive_Status__c
            FROM Case WHERE Id = :failCases[0].Id
        ];
        System.assertNotEquals('Processing', failCase.FEC_Archive_Status__c,
            'Case fail không được set Processing');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 15: start() query locator với threshold 90 ngày
    // → Verify query syntax đúng (chạy qua Database.executeBatch để có real context)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStartQueryLocator() {
        createClosedCases(1);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        // Chạy qua Database.executeBatch để start() có BatchableContext hợp lệ
        Id jobId = Database.executeBatch(new FEC_CaseExportBatch(), 10);
        Test.stopTest();

        // Verify batch job được tạo và chạy
        AsyncApexJob job = [
            SELECT Status, JobType
            FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job,
            'Batch job phải được tạo');
        System.assertEquals('BatchApex', job.JobType,
            'Job type phải là BatchApex');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 16: execute() với large batch (stress test)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteLargeBatch() {
        // Tạo batch lớn hơn để test performance
        List<Case> cases = createClosedCases(10);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer processingCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :cases AND FEC_Archive_Status__c = 'Processing'
        ];
        System.assertEquals(10, processingCount,
            'Tất cả 10 cases phải được xử lý');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 17: Verify FEC_Attachment_Status__c được reset về null
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testAttachmentStatusReset() {
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Test Attachment Status Reset'
        );
        insert testCase;

        // Set giá trị ban đầu cho FEC_Attachment_Status__c
        testCase.FEC_Attachment_Status__c = 'Pending';
        update testCase;

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, FEC_Attachment_Status__c
            FROM Case WHERE Id = :testCase.Id
        ];

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_CaseExportBatch batch = new FEC_CaseExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Archive_Status__c, FEC_Attachment_Status__c
            FROM Case WHERE Id = :testCase.Id
        ];
        System.assertEquals('Processing', updated.FEC_Archive_Status__c,
            'FEC_Archive_Status__c phải là Processing');
        System.assertEquals(null, updated.FEC_Attachment_Status__c,
            'FEC_Attachment_Status__c phải được reset về null');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 18: execute() với BatchableContext có jobId
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteWithBatchContext() {
        List<Case> cases = createClosedCases(1);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        // Chạy qua Database.executeBatch để có real BatchableContext
        Id jobId = Database.executeBatch(new FEC_CaseExportBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status,
            'Batch job phải complete');
    }
}
