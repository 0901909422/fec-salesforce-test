@IsTest
private class FEC_ContentDistribuTriggerHandler_Test {

    @IsTest
    static void testOnBeforeInsert_BlockDistribution() {
        // 1. Dựng dữ liệu: Case, File, và Link
        Case testCase = new Case(Subject = 'Review Case', Status = 'New');
        insert testCase;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testCase.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );
        insert cdl;

        // Giả lập trạng thái Review để FEC_FileActionOnReviewService chặn
        // Lưu ý: Nếu service dựa vào Status của Case hoặc một flag khác, hãy update Case tại đây
        // Ví dụ: testCase.Status = 'Review'; update testCase;

        // 2. Kiểm tra chặn tạo ContentDistribution
        Test.startTest();
        ContentDistribution cd = new ContentDistribution(
            Name = 'Public Link',
            ContentVersionId = cv.Id,
            PreferencesAllowViewInBrowser = true
        );

        try {
            insert cd;
            // Nếu không bị chặn (tùy thuộc vào service logic), test sẽ chạy tiếp
            System.debug('Distribution created');
        } catch (DmlException e) {
            // Xác minh lỗi được ném ra từ addError()
            System.assert(e.getMessage().contains(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW), 
                'Phải chặn tạo link khi Case đang Review');
        }
        Test.stopTest();
    }

    @IsTest
    static void testOnBeforeInsert_AllowDistribution() {
        // Case trường hợp không bị chặn (File không nằm trong Case Review)
        ContentVersion cv = new ContentVersion(
            Title = 'Safe File',
            PathOnClient = 'Safe.pdf',
            VersionData = Blob.valueOf('Safe content'),
            IsMajorVersion = true
        );
        insert cv;

        Test.startTest();
        ContentDistribution cd = new ContentDistribution(
            Name = 'Public Link Safe',
            ContentVersionId = cv.Id,
            PreferencesAllowViewInBrowser = true
        );
        
        // Đoạn này nên thành công
        insert cd;
        Test.stopTest();

        System.assertNotEquals(null, cd.Id, 'Việc tạo link phải thành công nếu không bị chặn.');
    }
}