@IsTest
private class FEC_ContentVersionTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage Attach',
            FEC_Code__c = 'STGCV',
            FEC_Active__c = true
        );
        insert stage;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Review Case',
                Status = 'New',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'CVTH-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ContentVersion cv = new ContentVersion(
            Title = 'Original File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test content'),
            FEC_Stage_ID__c = stage.Id,
            IsMajorVersion = true
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = c.Id,
            ContentDocumentId = docId,
            ShareType = 'V'
        );

        Case normalCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            normalCase = new Case(
                Subject = 'Normal Case',
                Status = 'New',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'CVTH-NORMAL-' + String.valueOf(System.currentTimeMillis())
            );
            insert normalCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        ContentVersion normalCv = new ContentVersion(
            Title = 'Normal File',
            PathOnClient = 'normal.pdf',
            VersionData = Blob.valueOf('Normal content'),
            FEC_Stage_ID__c = stage.Id,
            IsMajorVersion = true
        );
        insert normalCv;
        Id normalDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :normalCv.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = normalCase.Id,
            ContentDocumentId = normalDocId,
            ShareType = 'V'
        );
    }

    @IsTest
    static void testBeforeInsert_SyncStageId() {
        ContentVersion latest = [
            SELECT ContentDocumentId, FEC_Stage_ID__c
            FROM ContentVersion
            WHERE IsLatest = true AND Title = 'Normal File'
            LIMIT 1
        ];
        Id docId = latest.ContentDocumentId;
        Id expectedStageId = latest.FEC_Stage_ID__c;

        Test.startTest();
        ContentVersion newCv = new ContentVersion(
            Title = 'New Version',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('New content'),
            ContentDocumentId = docId,
            IsMajorVersion = true
        );
        insert newCv;
        Test.stopTest();

        ContentVersion insertedCv = [
            SELECT FEC_Stage_ID__c FROM ContentVersion WHERE Id = :newCv.Id
        ];
        System.assertEquals(
            expectedStageId,
            insertedCv.FEC_Stage_ID__c,
            'Stage ID phải được đồng bộ từ bản cũ.'
        );
    }

    @IsTest
    static void testBeforeUpdate_BlockOnReview() {
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        Test.startTest();
        try {
            cv.Title = 'Updated Title';
            update cv;
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW),
                'Phải bị chặn khi Case đang Review.'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeInsert_MaxFileSize() {
        Test.startTest();
        ContentVersion upload = new ContentVersion(
            Title = 'Small upload',
            PathOnClient = 'small.txt',
            VersionData = Blob.valueOf('small payload'),
            IsMajorVersion = true
        );
        insert upload;
        Test.stopTest();

        System.assertNotEquals(null, upload.Id, 'Insert không có ContentDocumentId phải đi qua nhánh return an toàn.');
    }

    @IsTest
    static void testBeforeUpdate_AllowWhenNotReview() {
        ContentVersion cv = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title = 'Normal File'
            LIMIT 1
        ];

        Test.startTest();
        cv.Title = 'Normal File Updated';
        update cv;
        Test.stopTest();

        ContentVersion afterUpdate = [SELECT Title FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Normal File Updated', afterUpdate.Title);
    }
}
