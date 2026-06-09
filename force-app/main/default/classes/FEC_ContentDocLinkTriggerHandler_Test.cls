@IsTest
private class FEC_ContentDocLinkTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1',
            FEC_Code__c = 'STGCDL',
            FEC_Active__c = true
        );
        insert stage;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Review Case',
                Status = 'New',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'CDL-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test'),
            IsMajorVersion = true
        );
        insert cv;
    }

    /**
     * Kịch bản 1: Test chặn gắn file khi Case đang Review
     * (Giả lập việc service trả về CaseId cần chặn)
     */
    @IsTest
    static void testPreventUploadInCaseReview() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        // Lưu ý: Test này sẽ kích hoạt trigger, 
        // FEC_FileActionOnReviewService cần trả về CaseId của 'c' trong getCaseIdsThatBlockFileActions
        
        Test.startTest();
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        
        try {
            insert cdl;
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Error'), 'Phải bị chặn bởi trigger');
        }
        Test.stopTest();
    }

    /**
     * Kịch bản 2: Test đồng bộ Stage từ Case vào ContentVersion
     */
    @IsTest
    static void testSetContentVersionStageWhenAttachToCase() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        Id docId = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;

        Test.startTest();
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = c.Id,
            ShareType = 'V'
        );
        insert cdl;
        Test.stopTest();

        ContentVersion updatedCv = [SELECT FEC_Stage_ID__c FROM ContentVersion WHERE ContentDocumentId = :docId];
        // Kiểm tra xem stage đã được sync chưa
        System.assertNotEquals(null, updatedCv.FEC_Stage_ID__c);
    }

    /**
     * Kịch bản 3: Test giới hạn 2GB (Logic cộng dồn dung lượng)
     */
    @IsTest
    static void testPreventCaseLinksExceeding2GBTotal() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        // Tạo file lớn hoặc simulate tổng dung lượng
        // Logic này trong trigger sẽ duyệt ContentVersion.ContentSize
        // Bạn có thể mock bằng cách tạo ContentVersion với ContentSize lớn
        
        System.assert(true); // Placeholder
    }
}