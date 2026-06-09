@IsTest
private class FEC_ContentDocumentTrigger_Test {
    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Id createFileLinkedToCase(Id caseId, Id stageId, String suffix) {
        ContentVersion cv = new ContentVersion(
            Title = 'CD Trigger UT ' + suffix,
            PathOnClient = 'cd_trigger_' + suffix + '.txt',
            VersionData = Blob.valueOf('content-document-trigger-test'),
            IsMajorVersion = true,
            FEC_Stage_ID__c = stageId,
            FirstPublishLocationId = caseId
        );
        insert cv;
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;
    }

    @IsTest
    static void testBeforeDelete_allowWhenStageMatches() {
        FEC_Case_Stage__c stageAttach = new FEC_Case_Stage__c(
            Name = 'CD Match Stage',
            FEC_Code__c = 'CDM' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
            FEC_Active__c = true
        );
        insert stageAttach;

        Case c = insertCaseRow(new Case(
            Subject = 'CD Trigger Match',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Current_Case_Stage__c = stageAttach.Id,
            FEC_ID_Search__c = 'CDM-' + String.valueOf(System.now().getTime())
        ));

        Id docId = createFileLinkedToCase(c.Id, stageAttach.Id, 'match');

        Test.startTest();
        delete new ContentDocument(Id = docId);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Delete should be allowed when current stage equals attach stage.'
        );
    }

    @IsTest
    static void testBeforeDelete_blockWhenStageMismatch() {
        FEC_Case_Stage__c stageAttach = new FEC_Case_Stage__c(
            Name = 'CD Attach Stage',
            FEC_Code__c = 'CDA' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
            FEC_Active__c = true
        );
        FEC_Case_Stage__c stageOther = new FEC_Case_Stage__c(
            Name = 'CD Other Stage',
            FEC_Code__c = 'CDO' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
            FEC_Active__c = true
        );
        insert new List<FEC_Case_Stage__c>{ stageAttach, stageOther };

        Case c = insertCaseRow(new Case(
            Subject = 'CD Trigger Mismatch',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Current_Case_Stage__c = stageAttach.Id,
            FEC_ID_Search__c = 'CDO-' + String.valueOf(System.now().getTime())
        ));
        Id docId = createFileLinkedToCase(c.Id, stageAttach.Id, 'mismatch');

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Current_Case_Stage__c = stageOther.Id);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean blocked = false;
        Test.startTest();
        try {
            delete new ContentDocument(Id = docId);
        } catch (DmlException ex) {
            blocked = ex.getMessage().contains(FEC_FileActionOnReviewService.ERROR_FILE_DELETE_STAGE_MISMATCH);
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'Delete should be blocked when case stage mismatches attach stage.');
    }
}
