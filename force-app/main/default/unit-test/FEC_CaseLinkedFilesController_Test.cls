@IsTest
private class FEC_CaseLinkedFilesController_Test {
    @IsTest
    static void testGetLinkedFilesForCase_NullCaseId() {
        Test.startTest();
        List<FEC_CaseLinkedFilesController.CaseLinkedFileRow> rows =
            FEC_CaseLinkedFilesController.getLinkedFilesForCase(null);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(0, rows.size(), 'Null case id should return empty list.');
    }

    @IsTest
    static void testGetLinkedFilesForCase_WithLinkedDocument() {
        Case c = new Case(
            Subject = 'Case linked files test',
            Status = 'New',
            Origin = 'Phone'
        );
        insert c;

        ContentVersion cv = new ContentVersion(
            Title = 'LinkedFile_Test',
            PathOnClient = 'LinkedFile_Test.pdf',
            VersionData = Blob.valueOf('sample test content')
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        insert new ContentDocumentLink(
            LinkedEntityId = c.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        List<FEC_CaseLinkedFilesController.CaseLinkedFileRow> rows =
            FEC_CaseLinkedFilesController.getLinkedFilesForCase(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Expected one linked file row.');

        FEC_CaseLinkedFilesController.CaseLinkedFileRow row = rows[0];
        System.assertNotEquals(null, row.linkId, 'linkId should be populated.');
        System.assertEquals(insertedCv.ContentDocumentId, row.contentDocumentId);
        System.assertEquals('LinkedFile_Test', row.title);
        System.assertEquals('pdf', row.fileExtension);
        System.assertNotEquals(null, row.ownerName);
        System.assertNotEquals(null, row.lastModifiedDate);
        System.assert(row.contentSize > 0, 'contentSize should be greater than zero.');
        System.assertNotEquals(null, row.linkedCreatedDate);
    }
}
