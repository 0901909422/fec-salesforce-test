/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class for ArchiveCaseAttachmentQueueable
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/07     Thanh Van          Init
------------------------------------------------------------*/
@IsTest
private class ArchiveCaseAttachmentQueueable_Test {

    // Mock: S3 returns file bytes successfully
    public class S3SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('fake-file-content'));
            return res;
        }
    }

    // Mock: S3 returns error
    public class S3ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    static List<Map<String, Object>> buildAttachments() {
        List<Map<String, Object>> atts = new List<Map<String, Object>>();
        atts.add(new Map<String, Object>{
            's3Key'       => 'cases/CASE-999/attachments/a1-b2-c3_contract.pdf',
            'filename'    => 'contract.pdf',
            'contentType' => 'application/pdf',
            'fileSize'    => 25600,
            'uploadedAt'  => '2026-03-01T08:00:00Z',
            'uploadedBy'  => 'system_bot'
        });
        atts.add(new Map<String, Object>{
            's3Key'       => 'cases/CASE-999/attachments/d4-e5-f6_signature.png',
            'filename'    => 'signature.png',
            'contentType' => 'image/png',
            'fileSize'    => 512000,
            'uploadedAt'  => '2026-03-02T15:30:45Z',
            'uploadedBy'  => 'agent_07'
        });
        return atts;
    }

    @isTest
    static void testExecute_S3Error_SkipsInsert() {
        Case c = new Case(Status = 'New', Origin = 'Phone');
        insert c;

        ArchiveCaseAttachmentQueueable.disableChaining = true;
        Test.setMock(HttpCalloutMock.class, new S3ErrorMock());

        Test.startTest();
            System.enqueueJob(new ArchiveCaseAttachmentQueueable(c.Id, buildAttachments(), 0));
        Test.stopTest();

        List<Attachment> inserted = [SELECT Id FROM Attachment WHERE ParentId = :c.Id];
        System.assertEquals(0, inserted.size(), 'Should not insert attachment when S3 returns error');
    }

    @isTest
    static void testExecute_EmptyS3Key_SkipsInsert() {
        Case c = new Case(Status = 'New', Origin = 'Phone');
        insert c;

        ArchiveCaseAttachmentQueueable.disableChaining = true;
        List<Map<String, Object>> atts = new List<Map<String, Object>>{
            new Map<String, Object>{ 's3Key' => '', 'filename' => 'empty.pdf', 'contentType' => 'application/pdf' }
        };

        Test.setMock(HttpCalloutMock.class, new S3SuccessMock());

        Test.startTest();
            System.enqueueJob(new ArchiveCaseAttachmentQueueable(c.Id, atts, 0));
        Test.stopTest();

        List<Attachment> inserted = [SELECT Id FROM Attachment WHERE ParentId = :c.Id];
        System.assertEquals(0, inserted.size(), 'Should skip when s3Key is blank');
    }

    @isTest
    static void testExecute_IndexOutOfBounds_DoesNothing() {
        Case c = new Case(Status = 'New', Origin = 'Phone');
        insert c;

        ArchiveCaseAttachmentQueueable.disableChaining = true;
        Test.setMock(HttpCalloutMock.class, new S3SuccessMock());

        Test.startTest();
            System.enqueueJob(new ArchiveCaseAttachmentQueueable(c.Id, buildAttachments(), 5));
        Test.stopTest();

        List<Attachment> inserted = [SELECT Id FROM Attachment WHERE ParentId = :c.Id];
        System.assertEquals(0, inserted.size(), 'Should do nothing when index is out of bounds');
    }

    @isTest
    static void testExecute_NullContentType_UsesDefault() {
        Case c = new Case(Status = 'New', Origin = 'Phone');
        insert c;

        ArchiveCaseAttachmentQueueable.disableChaining = true;
        List<Map<String, Object>> atts = new List<Map<String, Object>>{
            new Map<String, Object>{ 's3Key' => 'cases/x/file.bin', 'filename' => 'file.bin', 'contentType' => null }
        };

        Test.setMock(HttpCalloutMock.class, new S3SuccessMock());

        Test.startTest();
            System.enqueueJob(new ArchiveCaseAttachmentQueueable(c.Id, atts, 0));
        Test.stopTest();

        List<Attachment> inserted = [SELECT Id, ContentType FROM Attachment WHERE ParentId = :c.Id];
        System.assertEquals(1, inserted.size());
        System.assertEquals('application/octet-stream', inserted[0].ContentType,
            'Should default to application/octet-stream when contentType is null');
    }
}