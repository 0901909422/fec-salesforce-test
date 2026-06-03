@IsTest
private class FEC_ContentDocumentLinkService_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo bản ghi Case mồi
        Case testCase = new Case(Subject = 'Test Service Case');
        insert testCase;

        // 2. Tạo File mồi (ContentVersion)
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
    }

    /**
     * Kịch bản 1: Tạo liên kết mới thành công.
     */
    @IsTest
    static void testLinkContentDocument_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        FEC_ContentDocumentLinkService.LinkContentDocumentResult result = 
            FEC_ContentDocumentLinkService.linkContentDocumentToRecord(docId, c.Id, 'V', 'AllUsers');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Việc tạo liên kết phải thành công.');
        System.assertNotEquals(null, result.contentDocumentLinkId, 'Link Id không được null.');
    }

    /**
     * Kịch bản 2: Kiểm tra việc trả về kết quả cho liên kết đã tồn tại (không lỗi).
     */
    @IsTest
    static void testLinkContentDocument_AlreadyExists() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        // Tạo trước một link
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = c.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        FEC_ContentDocumentLinkService.LinkContentDocumentResult result = 
            FEC_ContentDocumentLinkService.linkContentDocumentToRecord(docId, c.Id, null, null);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(cdl.Id, result.contentDocumentLinkId, 'Phải trả về ID của link đã tồn tại.');
    }

    /**
     * Kịch bản 3: Kiểm tra tham số đầu vào bị null.
     */
    @IsTest
    static void testLinkContentDocument_NullInput() {
        Test.startTest();
        FEC_ContentDocumentLinkService.LinkContentDocumentResult result = 
            FEC_ContentDocumentLinkService.linkContentDocumentToRecord(null, null, null, null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Kết quả phải trả về false khi tham số đầu vào là null.');
    }

    /**
     * Kịch bản 4: Kiểm tra bẫy lỗi DML Exception.
     */
    @IsTest
    static void testLinkContentDocument_DmlException() {
        // Case và DocId tồn tại
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        // Gửi tham số ShareType không hợp lệ (ví dụ: chuỗi quá dài hoặc sai định dạng để gây lỗi DML nếu có validation)
        // Lưu ý: ContentDocumentLink.ShareType có validation chặt chẽ (phải là 'V', 'C', 'I')
        FEC_ContentDocumentLinkService.LinkContentDocumentResult result = 
            FEC_ContentDocumentLinkService.linkContentDocumentToRecord(docId, c.Id, 'INVALID_TYPE', 'AllUsers');
        Test.stopTest();

        // Kết quả sẽ trả về success = false và có message lỗi từ catch block
        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.message);
    }
}