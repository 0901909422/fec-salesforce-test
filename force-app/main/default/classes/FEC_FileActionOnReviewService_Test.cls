@IsTest
private class FEC_FileActionOnReviewService_Test {

    private static Id interactionRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        return byDev.containsKey(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME)
            ? byDev.get(FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME).getRecordTypeId()
            : null;
    }

    private static Id caseStageId() {
        String stageCode = 'STGFAR-' + String.valueOf(System.currentTimeMillis());
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage FAR',
            FEC_Code__c = stageCode,
            FEC_Active__c = true
        );
        insert stage;
        return stage.Id;
    }

    private static Case insertCase(String subject, String viewMode) {
        Case c = new Case(
            Subject = subject,
            Status = 'New',
            FEC_Current_Case_Stage__c = caseStageId(),
            FEC_Interaction_View_Mode__c = viewMode,
            FEC_ID_Search__c = 'FAR-' + subject + '-' + String.valueOf(System.currentTimeMillis())
        );
        Id interactionRtId = interactionRecordTypeId();
        if (interactionRtId != null) {
            c.RecordTypeId = interactionRtId;
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        ensureCaseInHandlingMode(c.Id);
        return c;
    }

    private static void ensureCaseInHandlingMode(Id caseId) {
        Case c = [
            SELECT FEC_Interaction_View_Mode__c, RecordType.DeveloperName
            FROM Case
            WHERE Id = :caseId
        ];
        Boolean isInteraction = FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME.equals(
            c.RecordType != null ? c.RecordType.DeveloperName : null
        );
        if (isInteraction
            && !FEC_ConstantCommon.INTERACTION_HANDLING_MODE.equals(c.FEC_Interaction_View_Mode__c)) {
            setCaseViewMode(caseId, FEC_ConstantCommon.INTERACTION_HANDLING_MODE);
        }
    }

    private static void setCaseViewMode(Id caseId, String viewMode) {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = caseId, FEC_Interaction_View_Mode__c = viewMode);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Id insertContentDocument() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    /** Gắn file khi Case đang Handling; trigger CDL chặn nếu Case đã Review. */
    private static void linkFileToCaseWhileHandling(Id caseId, Id contentDocumentId) {
        ensureCaseInHandlingMode(caseId);
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = caseId,
            ShareType = 'V'
        );
    }

    @IsTest
    static void testGetCaseIdsThatBlockFileActions() {
        Case reviewCase = insertCase(
            'Review Case',
            FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );
        Case handlingCase = insertCase(
            'Handling Case',
            FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );
        setCaseViewMode(reviewCase.Id, FEC_ConstantCommon.INTERACTION_REVIEW_MODE);

        Set<Id> caseIds = new Set<Id>{ reviewCase.Id, handlingCase.Id };

        Test.startTest();
        Set<Id> blockedCases = FEC_FileActionOnReviewService.getCaseIdsThatBlockFileActions(caseIds);
        Test.stopTest();

        System.assert(blockedCases.contains(reviewCase.Id), 'Case Review phải bị chặn.');
        System.assert(!blockedCases.contains(handlingCase.Id), 'Case Handling không được chặn.');
    }

    @IsTest
    static void testGetContentDocumentIdsLinkedToReviewCases() {
        Case reviewCase = insertCase(
            'Review Case',
            FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );
        Id docId = insertContentDocument();

        linkFileToCaseWhileHandling(reviewCase.Id, docId);
        setCaseViewMode(reviewCase.Id, FEC_ConstantCommon.INTERACTION_REVIEW_MODE);

        Test.startTest();
        Set<Id> blockedDocs = FEC_FileActionOnReviewService.getContentDocumentIdsLinkedToReviewCases(
            new Set<Id>{ docId }
        );
        Test.stopTest();

        System.assert(blockedDocs.contains(docId), 'File gắn với Review Case phải bị chặn.');
    }
}
