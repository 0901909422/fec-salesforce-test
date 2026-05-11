/**
 * FEC_AttachmentExportBatch_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_AttachmentExportBatch (upload attachments lên S3 + POST metadata).
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
private class FEC_AttachmentExportBatch_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock API trả 200 OK cho cả upload và batch endpoint */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            // Check endpoint để trả response phù hợp
            if (req.getEndpoint().contains('/upload')) {
                // Response cho upload endpoint
                res.setBody('{"status":"success","data":{"uploadedFiles":[{"filename":"test.pdf","s3Key":"cases/123/attachments/uuid_test.pdf","fileSize":1024}]}}');
            } else {
                // Response cho batch endpoint
                res.setBody('{"status":"success"}');
            }
            return res;
        }
    }

    /** Mock API luôn trả 500 → execute() sẽ catch và đánh dấu failed */
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

    /** Mock cho case không có attachment - chỉ gọi batch endpoint */
    private class NoAttachmentSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Tạo Case với Status = Closed và FEC_Archive_Status__c = 'Processing'
     * (điều kiện để batch pick up)
     */
    private static List<Case> createProcessingCases(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status = 'Closed',
                Subject = 'Test Case ' + i,
                FEC_Archive_Status__c = 'Processing'
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
     * Tạo ContentVersion (file) và link với Case
     */
    private static void createAttachmentForCase(Id caseId, String fileName, String fileExtension) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName + '.' + fileExtension;
        cv.VersionData = Blob.valueOf('Test file content for ' + fileName);
        insert cv;

        // Query lại để lấy ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link file với Case
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = caseId;
        cdl.ShareType = 'V';
        insert cdl;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: execute() thành công với Case không có attachment
    // → FEC_Attachment_Status__c = 'Completed'
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteSuccessNoAttachment() {
        List<Case> cases = createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT Id, FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_COMPLETED, updated.FEC_Attachment_Status__c,
            'FEC_Attachment_Status__c phải là Completed sau khi xử lý thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: execute() thành công với Case có attachment
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteSuccessWithAttachment() {
        List<Case> cases = createProcessingCases(1);
        createAttachmentForCase(cases[0].Id, 'contract', 'pdf');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT Id, FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_COMPLETED, updated.FEC_Attachment_Status__c,
            'FEC_Attachment_Status__c phải là Completed sau khi upload thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: execute() với lỗi upload → FEC_Attachment_Status__c = 'Failed'
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteUploadFailure() {
        List<Case> cases = createProcessingCases(1);
        createAttachmentForCase(cases[0].Id, 'document', 'pdf');

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT Id, FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_FAILED, updated.FEC_Attachment_Status__c,
            'FEC_Attachment_Status__c phải là Failed khi upload lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: execute() với scope rỗng → không lỗi, không callout
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteEmptyScope() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, new List<Case>());
        Test.stopTest();

        System.assert(true, 'execute() với scope rỗng phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: Full batch via run() — không có case nào match điều kiện
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testRunNoMatchingCases() {
        // Cases mới tạo: ClosedDate ~= now → không match ClosedDate <= now - 90 days
        createProcessingCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch.run();
        Test.stopTest();

        // Không có case nào bị update vì ClosedDate không đủ 90 ngày
        Integer completedCount = [
            SELECT COUNT() FROM Case
            WHERE FEC_Attachment_Status__c = 'Completed'
        ];
        System.assertEquals(0, completedCount,
            'Không case nào được xử lý vì ClosedDate < 90 ngày');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: Full batch execution qua Database.executeBatch
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFullBatchExecution() {
        createProcessingCases(2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_AttachmentExportBatch(), 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId,
            'Database.executeBatch phải trả về jobId hợp lệ');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: finish() chạy không lỗi
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFinishMethod() {
        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'finish() phải chạy không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: start() query locator với điều kiện đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStartQueryLocator() {
        createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_AttachmentExportBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, JobType
            FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertNotEquals(null, job, 'Batch job phải được tạo');
        System.assertEquals('BatchApex', job.JobType, 'Job type phải là BatchApex');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 9: execute() với nhiều Cases
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteMultipleCases() {
        List<Case> cases = createProcessingCases(3);

        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Integer completedCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :cases AND FEC_Attachment_Status__c = 'Completed'
        ];
        System.assertEquals(3, completedCount,
            'Tất cả 3 cases phải có status Completed');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 10: Stateful accumulation - verify success/failed counters
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testStatefulAccumulation() {
        // Test chỉ verify rằng batch instance có thể xử lý nhiều cases
        // và finish() chạy không lỗi sau khi có kết quả
        List<Case> cases = createProcessingCases(3);

        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        // Gọi execute với tất cả cases trong 1 lần (giống thực tế batch size > 1)
        batch.execute(null, cases);
        batch.finish(null);
        Test.stopTest();

        Integer completedCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :cases AND FEC_Attachment_Status__c = 'Completed'
        ];
        System.assertEquals(3, completedCount,
            'Cả 3 cases phải có status Completed');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 11: execute() với Case có nhiều attachments
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteWithMultipleAttachments() {
        List<Case> cases = createProcessingCases(1);
        createAttachmentForCase(cases[0].Id, 'contract', 'pdf');
        createAttachmentForCase(cases[0].Id, 'image', 'png');
        createAttachmentForCase(cases[0].Id, 'document', 'docx');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT Id, FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_COMPLETED, updated.FEC_Attachment_Status__c,
            'Case với nhiều attachments phải được xử lý thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 12: Server error 500 → retry logic
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteServerError() {
        List<Case> cases = createProcessingCases(1);
        createAttachmentForCase(cases[0].Id, 'test', 'pdf');

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT Id, FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_FAILED, updated.FEC_Attachment_Status__c,
            'FEC_Attachment_Status__c phải là Failed sau server error');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 13: Verify constants được định nghĩa đúng
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testConstants() {
        System.assertEquals('Completed', FEC_AttachmentExportBatch.STATUS_COMPLETED,
            'STATUS_COMPLETED phải là Completed');
        System.assertEquals('Failed', FEC_AttachmentExportBatch.STATUS_FAILED,
            'STATUS_FAILED phải là Failed');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 14: finish() với mixed success và failure
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testFinishWithMixedResults() {
        List<Case> successCases = createProcessingCases(2);
        List<Case> failCases = createProcessingCases(1);
        createAttachmentForCase(failCases[0].Id, 'fail', 'pdf');

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();

        // Batch 1: Success (no attachments)
        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());
        batch.execute(null, successCases);

        // Batch 2: Failure
        Test.setMock(HttpCalloutMock.class, new BadRequestMock());
        batch.execute(null, failCases);

        batch.finish(null);
        Test.stopTest();

        // Verify success cases
        Integer successCount = [
            SELECT COUNT() FROM Case
            WHERE Id IN :successCases AND FEC_Attachment_Status__c = 'Completed'
        ];
        System.assertEquals(2, successCount, '2 cases thành công phải có status Completed');

        // Verify fail case
        Case failCase = [
            SELECT FEC_Attachment_Status__c
            FROM Case WHERE Id = :failCases[0].Id
        ];
        System.assertEquals('Failed', failCase.FEC_Attachment_Status__c,
            'Case fail phải có status Failed');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 15: execute() với BatchableContext có jobId
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteWithBatchContext() {
        createProcessingCases(1);

        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());

        Test.startTest();
        Id jobId = Database.executeBatch(new FEC_AttachmentExportBatch(), 1);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status, 'Batch job phải complete');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 16: Case không có FEC_ID_Search__c
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testExecuteCaseWithoutFecIdSearch() {
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Test Case without FEC_ID_Search',
            FEC_Archive_Status__c = 'Processing'
        );
        insert testCase;

        List<Case> cases = [
            SELECT Id, CaseNumber, FEC_ID_Search__c
            FROM Case WHERE Id = :testCase.Id
        ];

        Test.setMock(HttpCalloutMock.class, new NoAttachmentSuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Attachment_Status__c
            FROM Case WHERE Id = :testCase.Id
        ];
        System.assertEquals('Completed', updated.FEC_Attachment_Status__c,
            'Case không có FEC_ID_Search__c vẫn phải được xử lý');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 17: Test các loại file extension khác nhau
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testDifferentFileExtensions() {
        List<Case> cases = createProcessingCases(1);
        
        // Tạo các loại file khác nhau
        createAttachmentForCase(cases[0].Id, 'document', 'pdf');
        createAttachmentForCase(cases[0].Id, 'image', 'jpg');
        createAttachmentForCase(cases[0].Id, 'spreadsheet', 'xlsx');
        createAttachmentForCase(cases[0].Id, 'text', 'txt');

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Attachment_Status__c
            FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals('Completed', updated.FEC_Attachment_Status__c,
            'Case với nhiều loại file phải được xử lý thành công');
    }
}
