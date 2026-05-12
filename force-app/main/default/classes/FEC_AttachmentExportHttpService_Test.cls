/**
 * FEC_AttachmentExportHttpService_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests cho FEC_AttachmentExportHttpService
 * Cover các methods: postAttachmentFiles, postAttachments, processAttachments
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_AttachmentExportHttpService_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // HTTP Mocks
    // ══════════════════════════════════════════════════════════════════════════

    /** Mock upload endpoint trả 200 OK */
    private class UploadSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success","data":{"uploadedFiles":[{"filename":"test.pdf","s3Key":"cases/123/attachments/uuid_test.pdf","fileSize":1024}]}}');
            return res;
        }
    }

    /** Mock batch endpoint trả 200 OK */
    private class BatchSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    /** Mock trả 500 Server Error - trigger retry logic */
    private class ServerErrorMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /** Mock trả 400 Bad Request - không retry */
    private class BadRequestMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad payload"}');
            return res;
        }
    }

    /** Mock trả 500 lần đầu, 200 lần sau - test retry success */
    private class RetrySuccessMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (callCount == 1) {
                res.setStatusCode(500);
                res.setBody('Internal Server Error');
            } else {
                res.setStatusCode(200);
                if (req.getEndpoint().contains('/upload')) {
                    res.setBody('{"status":"success","data":{"uploadedFiles":[{"filename":"test.pdf","s3Key":"cases/123/attachments/uuid_test.pdf","fileSize":1024}]}}');
                } else {
                    res.setBody('{"status":"success"}');
                }
            }
            return res;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test data helpers
    // ══════════════════════════════════════════════════════════════════════════

    private static Case createTestCase() {
        Case testCase = new Case(
            Status = 'Closed',
            Subject = 'Test Case for Attachment',
            FEC_Archive_Status__c = 'Processing'
        );
        insert testCase;
        return testCase;
    }

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

    // ══════════════════════════════════════════════════════════════════════════
    // Test 1: processAttachments - Case không có file
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testProcessAttachmentsNoFiles() {
        Case testCase = createTestCase();

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(testCase.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Case không có file phải trả về list rỗng');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 2: processAttachments - Case có 1 file PDF
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testProcessAttachmentsWithPdfFile() {
        Case testCase = createTestCase();
        createAttachmentForCase(testCase.Id, 'contract', 'pdf');

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(testCase.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Phải trả về 1 attachment');
        System.assertEquals('contract.pdf', result[0].get('filename'), 'Filename phải đúng');
        System.assertEquals('application/pdf', result[0].get('contentType'), 'Content-Type phải là application/pdf');
        System.assertNotEquals(null, result[0].get('blobData'), 'blobData không được null');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 3: processAttachments - Case có nhiều file với các extension khác nhau
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testProcessAttachmentsMultipleFiles() {
        Case testCase = createTestCase();
        createAttachmentForCase(testCase.Id, 'document', 'pdf');
        createAttachmentForCase(testCase.Id, 'image', 'jpg');
        createAttachmentForCase(testCase.Id, 'photo', 'png');
        createAttachmentForCase(testCase.Id, 'spreadsheet', 'xlsx');

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(testCase.Id);
        Test.stopTest();

        System.assertEquals(4, result.size(), 'Phải trả về 4 attachments');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 4: processAttachments - Test các content types
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testProcessAttachmentsContentTypes() {
        Case testCase = createTestCase();
        
        // Tạo files với các extension khác nhau
        createAttachmentForCase(testCase.Id, 'file1', 'jpeg');
        createAttachmentForCase(testCase.Id, 'file2', 'gif');
        createAttachmentForCase(testCase.Id, 'file3', 'doc');
        createAttachmentForCase(testCase.Id, 'file4', 'docx');
        createAttachmentForCase(testCase.Id, 'file5', 'xls');
        createAttachmentForCase(testCase.Id, 'file6', 'csv');
        createAttachmentForCase(testCase.Id, 'file7', 'txt');
        createAttachmentForCase(testCase.Id, 'file8', 'unknown');

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(testCase.Id);
        Test.stopTest();

        System.assertEquals(8, result.size(), 'Phải trả về 8 attachments');
        
        // Verify content types được map đúng
        Map<String, String> contentTypeMap = new Map<String, String>();
        for (Map<String, Object> att : result) {
            String filename = (String) att.get('filename');
            String contentType = (String) att.get('contentType');
            contentTypeMap.put(filename, contentType);
        }
        
        System.assertEquals('image/jpeg', contentTypeMap.get('file1.jpeg'), 'JPEG content type');
        System.assertEquals('image/gif', contentTypeMap.get('file2.gif'), 'GIF content type');
        System.assertEquals('application/msword', contentTypeMap.get('file3.doc'), 'DOC content type');
        System.assertEquals('application/vnd.openxmlformats-officedocument.wordprocessingml.document', contentTypeMap.get('file4.docx'), 'DOCX content type');
        System.assertEquals('application/vnd.ms-excel', contentTypeMap.get('file5.xls'), 'XLS content type');
        System.assertEquals('text/csv', contentTypeMap.get('file6.csv'), 'CSV content type');
        System.assertEquals('text/plain', contentTypeMap.get('file7.txt'), 'TXT content type');
        System.assertEquals('application/octet-stream', contentTypeMap.get('file8.unknown'), 'Unknown extension content type');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 5: postAttachmentFiles - Upload thành công
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesSuccess() {
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        attachments.add(new Map<String, Object>{
            'filename' => 'test.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('Test content')
        });

        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        Test.startTest();
        String response = FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response không được null');
        System.assert(response.contains('success'), 'Response phải chứa success');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 6: postAttachmentFiles - Upload nhiều files
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesMultiple() {
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        attachments.add(new Map<String, Object>{
            'filename' => 'file1.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('Content 1')
        });
        attachments.add(new Map<String, Object>{
            'filename' => 'file2.jpg',
            'contentType' => 'image/jpeg',
            'blobData' => Blob.valueOf('Content 2')
        });
        attachments.add(new Map<String, Object>{
            'filename' => 'file3.png',
            'contentType' => 'image/png',
            'blobData' => Blob.valueOf('Content 3')
        });

        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        Test.startTest();
        String response = FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response không được null');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 7: postAttachmentFiles - Bad Request (400)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesBadRequest() {
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        attachments.add(new Map<String, Object>{
            'filename' => 'test.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('Test content')
        });

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        try {
            FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
            System.assert(false, 'Phải throw exception khi HTTP 400');
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            System.assert(ex.getMessage().contains('400'), 'Exception message phải chứa status code');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 8: postAttachmentFiles - Server Error với retry
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesServerError() {
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        attachments.add(new Map<String, Object>{
            'filename' => 'test.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('Test content')
        });

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        try {
            FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
            System.assert(false, 'Phải throw exception sau khi retry hết');
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            System.assert(ex.getMessage().contains('retry'), 'Exception message phải mention retry');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 9: postAttachments - Batch POST thành công
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentsSuccess() {
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        batchPayload.add(new Map<String, Object>{
            'caseId' => '12345',
            'caseNumber' => '00001234',
            'attachments' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'filename' => 'test.pdf',
                    's3Key' => 'cases/12345/attachments/uuid_test.pdf',
                    'fileSize' => 1024
                }
            }
        });

        Test.setMock(HttpCalloutMock.class, new BatchSuccessMock());

        Test.startTest();
        // postAttachments không return gì, chỉ cần verify không throw exception
        FEC_AttachmentExportHttpService.postAttachments(batchPayload);
        Test.stopTest();

        System.assert(true, 'postAttachments phải chạy thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 10: postAttachments - Bad Request (400)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentsBadRequest() {
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        batchPayload.add(new Map<String, Object>{
            'caseId' => '12345',
            'caseNumber' => '00001234',
            'attachments' => new List<Object>()
        });

        Test.setMock(HttpCalloutMock.class, new BadRequestMock());

        Test.startTest();
        try {
            FEC_AttachmentExportHttpService.postAttachments(batchPayload);
            System.assert(false, 'Phải throw exception khi HTTP 400');
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            System.assert(ex.getMessage().contains('400'), 'Exception message phải chứa status code');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 11: postAttachments - Server Error với retry
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentsServerError() {
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        batchPayload.add(new Map<String, Object>{
            'caseId' => '12345',
            'caseNumber' => '00001234',
            'attachments' => new List<Object>()
        });

        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        try {
            FEC_AttachmentExportHttpService.postAttachments(batchPayload);
            System.assert(false, 'Phải throw exception sau khi retry hết');
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            System.assert(ex.getMessage().contains('retry'), 'Exception message phải mention retry');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 12: postAttachments - Empty payload
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentsEmptyPayload() {
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();

        Test.setMock(HttpCalloutMock.class, new BatchSuccessMock());

        Test.startTest();
        FEC_AttachmentExportHttpService.postAttachments(batchPayload);
        Test.stopTest();

        System.assert(true, 'Empty payload phải được xử lý không lỗi');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 13: processAttachments - File không có extension
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testProcessAttachmentsNoExtension() {
        Case testCase = createTestCase();
        
        // Tạo file không có extension
        ContentVersion cv = new ContentVersion();
        cv.Title = 'noextension';
        cv.PathOnClient = 'noextension';
        cv.VersionData = Blob.valueOf('Test content');
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = testCase.Id;
        cdl.ShareType = 'V';
        insert cdl;

        Test.startTest();
        List<Map<String, Object>> result = FEC_AttachmentExportHttpService.processAttachments(testCase.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Phải trả về 1 attachment');
        System.assertEquals('application/octet-stream', result[0].get('contentType'), 
            'File không có extension phải có content-type là application/octet-stream');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 14: postAttachmentFiles - Retry thành công sau lần đầu fail
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesRetrySuccess() {
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        attachments.add(new Map<String, Object>{
            'filename' => 'test.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('Test content')
        });

        Test.setMock(HttpCalloutMock.class, new RetrySuccessMock());

        Test.startTest();
        String response = FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response không được null sau retry');
        System.assert(response.contains('success'), 'Response phải chứa success');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 15: postAttachments - Multiple cases in batch
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentsMultipleCases() {
        List<Map<String, Object>> batchPayload = new List<Map<String, Object>>();
        
        for (Integer i = 0; i < 5; i++) {
            batchPayload.add(new Map<String, Object>{
                'caseId' => '1234' + i,
                'caseNumber' => '0000123' + i,
                'attachments' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'filename' => 'file' + i + '.pdf',
                        's3Key' => 'cases/1234' + i + '/attachments/uuid_file.pdf',
                        'fileSize' => 1024 * (i + 1)
                    }
                }
            });
        }

        Test.setMock(HttpCalloutMock.class, new BatchSuccessMock());

        Test.startTest();
        FEC_AttachmentExportHttpService.postAttachments(batchPayload);
        Test.stopTest();

        System.assert(true, 'Batch với nhiều cases phải chạy thành công');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 16: AttachmentCalloutException - Custom exception
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testAttachmentCalloutException() {
        Test.startTest();
        try {
            throw new FEC_AttachmentExportHttpService.AttachmentCalloutException('Test error message');
        } catch (FEC_AttachmentExportHttpService.AttachmentCalloutException ex) {
            System.assertEquals('Test error message', ex.getMessage(), 'Exception message phải đúng');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Test 17: postAttachmentFiles - File với base64 padding cases
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPostAttachmentFilesBase64Padding() {
        // Test với các kích thước file khác nhau để cover các case base64 padding
        List<Map<String, Object>> attachments = new List<Map<String, Object>>();
        
        // File size tạo ra base64 với == padding
        attachments.add(new Map<String, Object>{
            'filename' => 'file1.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('A') // 1 byte -> base64 có ==
        });
        
        // File size tạo ra base64 với = padding
        attachments.add(new Map<String, Object>{
            'filename' => 'file2.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('AB') // 2 bytes -> base64 có =
        });
        
        // File size tạo ra base64 không có padding
        attachments.add(new Map<String, Object>{
            'filename' => 'file3.pdf',
            'contentType' => 'application/pdf',
            'blobData' => Blob.valueOf('ABC') // 3 bytes -> base64 không có padding
        });

        Test.setMock(HttpCalloutMock.class, new UploadSuccessMock());

        Test.startTest();
        String response = FEC_AttachmentExportHttpService.postAttachmentFiles('12345', attachments);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response không được null');
    }
}
