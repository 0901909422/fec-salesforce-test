/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class for ArchiveInteractionCaseController
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/16     Thanh Van          Init
------------------------------------------------------------*/
@isTest
private class ArchiveCaseAttachmentController_Test {

    @testSetup
    static void setup() {
        // Create a Case with dummy JSON metadata in ArchiveAttachment__c
        String mockJson = '[' +
            '{' +
                '"s3Key": "key123",' +
                '"filename": "test_doc.pdf",' +
                '"contentType": "application/pdf",' +
                '"fileSize": 1024,' +
                '"uploadedAt": "2026-05-04",' +
                '"uploadedBy": "Thanh Van"' +
            '}' +
        ']';
        
        Case c = new Case(Subject = 'Test Case', ArchiveAttachment__c = mockJson);
        insert c;
    }

    @isTest
    static void testGetAttachments_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        List<ArchiveCaseAttachmentController.AttachmentInfo> results = ArchiveCaseAttachmentController.getAttachments(c.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetAttachments_Empty() {
        Test.startTest();
        List<ArchiveCaseAttachmentController.AttachmentInfo> results = ArchiveCaseAttachmentController.getAttachments(null);
        Test.stopTest();
    }

    @isTest
    static void testDownloadFile_Success() {
        // Set the mock callout
        Test.setMock(HttpCalloutMock.class, new MockS3Response(200));

        Test.startTest();
        ArchiveCaseAttachmentController.DownloadResult res = ArchiveCaseAttachmentController.downloadFile('key123', 'test.pdf', 'application/pdf');
        Test.stopTest();
    }

    @isTest
    static void testDownloadFile_Failure() {
        // Set the mock callout to return a 404
        Test.setMock(HttpCalloutMock.class, new MockS3Response(404));

        Test.startTest();
        ArchiveCaseAttachmentController.DownloadResult res = ArchiveCaseAttachmentController.downloadFile('key123', 'test.pdf', 'application/pdf');
        Test.stopTest();
    }

    // Inner class to mock the HTTP Callout
    private class MockS3Response implements HttpCalloutMock {
        Integer code;
        MockS3Response(Integer code) {
            this.code = code;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            if (code == 200) {
                res.setBodyAsBlob(Blob.valueOf('Mock file content'));
            } else {
                res.setBody('{"error": "Not Found"}');
            }
            return res;
        }
    }
}