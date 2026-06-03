@IsTest
private class FEC_ContentDistributionTrigger_Test {
    private static Case insertCaseRow(Case c) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static Id createVersionLinkedToCase(Id caseId, String titleSuffix) {
        ContentVersion cv = new ContentVersion(
            Title = 'UT File ' + titleSuffix,
            PathOnClient = 'ut_' + titleSuffix + '.txt',
            VersionData = Blob.valueOf('unit-test-content'),
            FirstPublishLocationId = caseId
        );
        insert cv;
        return [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].Id;
    }

    @IsTest
    static void testBeforeInsert_blockWhenOnlyReviewCase() {
        Case reviewCase = insertCaseRow(new Case(
            Subject = 'CD review case',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        ));
        Id versionId = createVersionLinkedToCase(reviewCase.Id, 'reviewOnly');
        reviewCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        update reviewCase;

        Boolean blocked = false;
        try {
            insert new ContentDistribution(
                Name = 'Blocked Public Link',
                ContentVersionId = versionId,
                PreferencesAllowViewInBrowser = true
            );
        } catch (DmlException ex) {
            blocked = ex.getMessage().contains(FEC_FileActionOnReviewService.ERROR_FILE_ACTION_IN_REVIEW);
        }
        System.assertEquals(true, blocked, 'Trigger should block public link for file linked only to review case.');
    }

    @IsTest
    static void testBeforeInsert_allowWhenHasNonBlockingCaseAlso() {
        Case reviewCase = insertCaseRow(new Case(
            Subject = 'CD review case 2',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        ));
        Id versionId = createVersionLinkedToCase(reviewCase.Id, 'mixed');
        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ].ContentDocumentId;

        Case normalCase = insertCaseRow(new Case(
            Subject = 'CD normal case',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        ));
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = normalCase.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        reviewCase.FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE;
        update reviewCase;

        Test.startTest();
        insert new ContentDistribution(
            Name = 'Allowed Public Link',
            ContentVersionId = versionId,
            PreferencesAllowViewInBrowser = true
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDistribution WHERE ContentVersionId = :versionId AND Name = 'Allowed Public Link'],
            'Trigger should allow distribution when file is also linked to a non-blocking case.'
        );
    }
}
