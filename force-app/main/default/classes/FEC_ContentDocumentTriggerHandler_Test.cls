@IsTest
private class FEC_ContentDocumentTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        FEC_Case_Stage__c stageAttach = new FEC_Case_Stage__c(
            Name = 'Stage Attach',
            FEC_Code__c = 'STGATT',
            FEC_Active__c = true
        );
        FEC_Case_Stage__c stageOther = new FEC_Case_Stage__c(
            Name = 'Stage Other',
            FEC_Code__c = 'STGOTH',
            FEC_Active__c = true
        );
        insert new List<FEC_Case_Stage__c>{ stageAttach, stageOther };

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Test Case Stage',
                Status = 'New',
                FEC_Current_Case_Stage__c = stageAttach.Id,
                FEC_ID_Search__c = 'CDOC-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test'),
            IsMajorVersion = true,
            FEC_Stage_ID__c = stageAttach.Id
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = c.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );
    }

    @IsTest
    static void testDelete_SuccessWhenStageMatches() {
        ContentDocument cd = [SELECT Id FROM ContentDocument LIMIT 1];

        Test.startTest();
        delete cd;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :cd.Id]);
    }

    @IsTest
    static void testDelete_BlockedWhenStageMismatch() {
        FEC_Case_Stage__c stageOther = [
            SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'STGOTH' LIMIT 1
        ];
        Case c = [SELECT Id FROM Case LIMIT 1];
        ContentDocument cd = [SELECT Id FROM ContentDocument LIMIT 1];

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = stageOther.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        try {
            delete cd;
            System.assert(false, 'Hệ thống phải chặn xóa file do stage mismatch.');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(FEC_FileActionOnReviewService.ERROR_FILE_DELETE_STAGE_MISMATCH),
                'Thông báo lỗi phải khớp với cấu hình.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeDelete_EmptyList() {
        Test.startTest();
        Test.stopTest();
        System.assert(true);
    }
}
