/**
 * FEC_AttachmentExportBatch_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_AttachmentExportBatch (upload attachments lên S3 + POST metadata).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_AttachmentExportBatchTest {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock cho cả upload + batch metadata POST thành công */
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/upload')) {
                res.setBody('{"data":{"uploadedFiles":[{"filename":"test.pdf","s3Key":"cases/123/test.pdf","fileSize":1024}]}}');
            } else {
                res.setBody('{"status":"success"}');
            }
            return res;
        }
    }

    /** Mock trả 500 cho mọi request */
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

    private static List<Case> createCasesForAttachment(Integer n) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < n; i++) {
            cases.add(new Case(
                Status = 'Closed',
                Subject = 'Attachment Test ' + i,
                FEC_Archive_Status__c = 'Processing'
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
    static void testExecute_NoCaseAttachments_MarksCompleted() {
        List<Case> cases = createCasesForAttachment(1);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Attachment_Status__c FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_COMPLETED,
            updated.FEC_Attachment_Status__c,
            'Case without attachments should still be marked Completed');
    }

    @IsTest
    static void testExecute_WithAttachment_Success() {
        List<Case> cases = createCasesForAttachment(1);

        // Tạo ContentDocument + link tới Case
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('test content')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = cases[0].Id,
            ShareType = 'V'
        );
        insert cdl;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, cases);
        Test.stopTest();

        Case updated = [
            SELECT FEC_Attachment_Status__c FROM Case WHERE Id = :cases[0].Id
        ];
        System.assertEquals(FEC_AttachmentExportBatch.STATUS_COMPLETED,
            updated.FEC_Attachment_Status__c,
            'Case should be marked Completed after successful upload');
    }

    @IsTest
    static void testExecute_EmptyScope() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.execute(null, new List<Case>());
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Empty scope should not throw');
    }

    @IsTest
    static void testRun() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch.run();
        Test.stopTest();

        System.assert(true, 'run() should complete without error');
    }

    @IsTest
    static void testFinish() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_AttachmentExportBatch batch = new FEC_AttachmentExportBatch();
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'finish() should complete without error');
    }
}
