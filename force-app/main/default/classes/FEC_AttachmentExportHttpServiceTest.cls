/**
 * FEC_AttachmentExportHttpService_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_AttachmentExportHttpService (upload files + POST metadata).
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_AttachmentExportHttpServiceTest {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    private class UploadSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/upload')) {
                res.setBody('{"data":{"uploadedFiles":[{"filename":"doc.pdf","s3Key":"cases/001/doc.pdf","fileSize":2048}]}}');
            } else {
                res.setBody('{"status":"ok"}');
            }
            return res;
        }
    }

    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"bad request"}');
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests: processAttachments
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testProcessAttachments_NoFiles() {
        Case c = new Case(Status = 'Closed', Subject = 'No files');
        insert c;

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(c.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Case without files should return empty list');
    }

    @IsTest
    static void testProcessAttachments_WithFile() {
        Case c = new Case(Status = 'Closed', Subject = 'With file');
        insert c;

        ContentVersion cv = new ContentVersion(
            Title = 'Report',
            PathOnClient = 'Report.pdf',
            VersionData = Blob.valueOf('pdf content here')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(c.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 attachment');
        System.assertEquals('Report.pdf', result[0].get('filename'), 'Filename should match');
        System.assertEquals('application/pdf', result[0].get('contentType'), 'ContentType should be pdf');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests: postAttachmentFiles
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testPostAttachmentFiles_Success() {
        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        List<Map<String, Object>> attachments = new List<Map<String, Object>>{
            new Map<String, Object>{
                'filename' => 'test.pdf',
                'contentType' => 'application/pdf',
                'blobData' => Blob.valueOf('test data')
            }
        };

        Test.startTest();
        String response = FEC_AttachmentExportHttpService.postAttachmentFiles('CASE-001', attachments);
        Test.stopTest();

        System.assert(response.contains('uploadedFiles'), 'Response should contain uploadedFiles');
    }

    @IsTest
    static void testPostAttachmentFiles_ServerError_Throws() {
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        List<Map<String, Object>> attachments = new List<Map<String, Object>>{
            new Map<String, Object>{
                'filename' => 'test.pdf',
                'contentType' => 'application/pdf',
                'blobData' => Blob.valueOf('test')
            }
        };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_AttachmentExportHttpService.postAttachmentFiles('CASE-001', attachments);
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw after retries on server error');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Tests: postAttachments (batch metadata)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testPostAttachments_Success() {
        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        List<Map<String, Object>> payload = new List<Map<String, Object>>{
            new Map<String, Object>{
                'caseId' => 'CASE-001',
                'caseNumber' => '00001',
                'attachments' => new List<Map<String, Object>>()
            }
        };

        Test.startTest();
        FEC_AttachmentExportHttpService.postAttachments(payload);
        Test.stopTest();

        System.assert(true, 'postAttachments should complete without error');
    }

    @IsTest
    static void testPostAttachments_BadRequest_Throws() {
        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        List<Map<String, Object>> payload = new List<Map<String, Object>>{
            new Map<String, Object>{
                'caseId' => 'CASE-001',
                'caseNumber' => '00001',
                'attachments' => new List<Map<String, Object>>()
            }
        };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_AttachmentExportHttpService.postAttachments(payload);
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('400'), 'Should contain 400 status');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw on 4xx');
    }
}
