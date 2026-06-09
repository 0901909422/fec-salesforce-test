/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class FEC_AttachmentControllerTest {

    @testSetup
    static void setupData() {
        // Tạo Source Case (Interaction) và Target Case (Service)
        Case interactionCase = new Case(Subject = 'Interaction Case');
        Case serviceCase = new Case(Subject = 'Service Case');
        insert new List<Case>{interactionCase, serviceCase};

        // Tạo một ContentVersion (File) và tự động link với Interaction Case
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('This is test content'),
            FirstPublishLocationId = interactionCase.Id
        );
        insert cv;
    }

    @isTest
    static void testGetAttachmentsFromInteraction() {
        Case interactionCase = [SELECT Id FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];
        Case serviceCase = [SELECT Id FROM Case WHERE Subject = 'Service Case' LIMIT 1];
        
        Test.startTest();
        List<FEC_AttachmentController.FileAttachmentInfo> attachments = 
            FEC_AttachmentController.getAttachmentsFromInteraction(interactionCase.Id, serviceCase.Id);
        Test.stopTest();
        
        System.assertEquals(1, attachments.size(), 'Phải lấy được 1 file từ Interaction Case.');
        System.assertEquals('Test File', attachments[0].fileName, 'Tên file không khớp.');
        System.assertEquals(false, attachments[0].isAttached, 'File chưa được attach vào Service Case nên phải là false.');
    }

    @isTest
    static void testAttachFilesToServiceCase() {
        Case interactionCase = [SELECT Id FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];
        Case serviceCase = [SELECT Id FROM Case WHERE Subject = 'Service Case' LIMIT 1];
        
        // Lấy Document ID để test attach
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test File' LIMIT 1];
        List<String> docIds = new List<String>{cv.ContentDocumentId};
        
        Test.startTest();
        Boolean isSuccess = FEC_AttachmentController.attachFilesToServiceCase(serviceCase.Id, docIds);
        
        // Kiểm tra lại trạng thái read-only sau khi đã attach
        List<FEC_AttachmentController.FileAttachmentInfo> attachments = 
            FEC_AttachmentController.getAttachmentsFromInteraction(interactionCase.Id, serviceCase.Id);
        Test.stopTest();
        
        System.assert(isSuccess, 'Hàm attachFilesToServiceCase phải trả về true.');
        System.assertEquals(true, attachments[0].isAttached, 'File đã được attach nên isAttached phải là true.');
        System.assertEquals(true, attachments[0].isReadOnly, 'File đã được attach nên isReadOnly phải là true.');
    }

    @isTest
    static void testAttachFileToInteractionCase() {
        Case interactionCase = [SELECT Id FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('New File Content'));
        String uniqueMsgId = 'MSG-1001';
        
        Test.startTest();
        // Upload lần 1 -> Thành công
        FEC_AttachmentController.attachFileToInteractionCase(interactionCase.Id, base64Data, 'NewFile.txt', uniqueMsgId);
        
        // Upload lần 2 với cùng uniqueMessageId -> Sẽ bị bỏ qua (duplicate detection logic)
        FEC_AttachmentController.attachFileToInteractionCase(interactionCase.Id, base64Data, 'NewFile.txt', uniqueMsgId);
        Test.stopTest();
        
        List<ContentVersion> cvList = [SELECT Id, Title, Description FROM ContentVersion WHERE Description = :uniqueMsgId];
        System.assertEquals(1, cvList.size(), 'Chỉ nên có 1 file được upload do logic chống trùng lặp dựa trên Description.');
    }

    @isTest
    static void testDownloadAndSaveBase64() {
        Case interactionCase = [SELECT Id FROM Case WHERE Subject = 'Interaction Case' LIMIT 1];
        
        // Giả lập (Mock) HTTP Callout cho FEC_Utils.downloadFileAsBlob
        Test.setMock(HttpCalloutMock.class, new MockS3DownloadCallout());
        
        Test.startTest();
        FEC_AttachmentController.downloadAndSaveBase64(
            'https://fake-s3-url.com/file.pdf', 
            interactionCase.Id, 
            'DownloadedFile.pdf', 
            'MSG-2002'
        );
        Test.stopTest();
        
        List<ContentVersion> cvList = [SELECT Id, Title FROM ContentVersion WHERE Description = 'MSG-2002'];
        System.assertEquals(1, cvList.size(), 'File từ S3 phải được lưu thành công vào Case.');
        System.assertEquals('DownloadedFile.pdf', cvList[0].Title, 'Tên file download không khớp.');
    }

    // --- Mock Class để giả lập phản hồi HTTP từ S3 ---
    private class MockS3DownloadCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('Mocked PDF Content from S3'));
            res.setStatusCode(200);
            return res;
        }
    }
}