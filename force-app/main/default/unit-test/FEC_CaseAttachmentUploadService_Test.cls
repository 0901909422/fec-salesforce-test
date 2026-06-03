@IsTest
private class FEC_CaseAttachmentUploadService_Test {

    private static Case createCaseRow() {
        Case c = new Case(
            Subject = 'Attachment Upload Test',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static FEC_CaseAttachmentUploadService.FileB64 fileRow(String name, String bodyText) {
        FEC_CaseAttachmentUploadService.FileB64 row = new FEC_CaseAttachmentUploadService.FileB64();
        row.fileName = name;
        row.base64Data = EncodingUtil.base64Encode(Blob.valueOf(bodyText));
        return row;
    }

    @IsTest
    static void testAttachFilesToCase_successAndFilenameTrim() {
        Case c = createCaseRow();
        String longName = '';
        for (Integer i = 0; i < 300; i++) {
            longName += 'A';
        }

        List<FEC_CaseAttachmentUploadService.FileB64> files =
            new List<FEC_CaseAttachmentUploadService.FileB64>{
                fileRow('short-file.txt', 'hello'),
                fileRow(longName, 'long-name'),
                null
            };

        Test.startTest();
        Integer insertedCount = FEC_CaseAttachmentUploadService.attachFilesToCase(c.Id, files);
        Test.stopTest();

        System.assertEquals(2, insertedCount, 'Only valid rows should be inserted.');

        List<ContentVersion> versions = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, versions.size());
        System.assertEquals('short-file.txt', versions[0].Title);
        System.assertEquals(255, versions[1].Title.length(), 'Title must be truncated to 255 chars.');

        System.assert(
            [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :c.Id
            ] > 0,
            'ContentDocumentLink should be automatically created for case.'
        );
    }

    @IsTest
    static void testAttachFilesToCase_returnsZeroForNullOrInvalidRows() {
        Case c = createCaseRow();
        FEC_CaseAttachmentUploadService.FileB64 missingBody = new FEC_CaseAttachmentUploadService.FileB64();
        missingBody.fileName = 'empty.txt';
        missingBody.base64Data = '';

        Test.startTest();
        Integer nullList = FEC_CaseAttachmentUploadService.attachFilesToCase(c.Id, null);
        Integer emptyList = FEC_CaseAttachmentUploadService.attachFilesToCase(
            c.Id,
            new List<FEC_CaseAttachmentUploadService.FileB64>()
        );
        Integer allSkipped = FEC_CaseAttachmentUploadService.attachFilesToCase(
            c.Id,
            new List<FEC_CaseAttachmentUploadService.FileB64>{ null, missingBody }
        );
        Test.stopTest();

        System.assertEquals(0, nullList);
        System.assertEquals(0, emptyList);
        System.assertEquals(0, allSkipped);
    }

    @IsTest
    static void testAttachFilesToCase_throwsForInvalidCaseId() {
        Account a = new Account(Name = 'Attachment Test Account');
        insert a;

        Test.startTest();
        try {
            FEC_CaseAttachmentUploadService.attachFilesToCase(null, new List<FEC_CaseAttachmentUploadService.FileB64>());
            System.assert(false, 'Expected exception when caseId is null.');
        } catch (AuraHandledException exNullId) {
            System.assertNotEquals(null, exNullId.getMessage());
        }

        try {
            FEC_CaseAttachmentUploadService.attachFilesToCase(
                a.Id,
                new List<FEC_CaseAttachmentUploadService.FileB64>{ fileRow('a.txt', 'abc') }
            );
            System.assert(false, 'Expected exception when id type is not Case.');
        } catch (AuraHandledException exWrongType) {
            System.assertNotEquals(null, exWrongType.getMessage());
        }
        Test.stopTest();
    }
}
