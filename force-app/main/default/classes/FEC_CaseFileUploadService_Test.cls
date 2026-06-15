@IsTest
private class FEC_CaseFileUploadService_Test {

    private static Case createCaseRow() {
        Case c = new Case(
            Subject = 'Case File Upload Test',
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

    private static String buildPayload(String title, String pathOnClient, String body) {
        return title + '|' + pathOnClient + '|' + EncodingUtil.base64Encode(Blob.valueOf(body));
    }

    @IsTest
    static void testUploadFilesToCase_successAndPathNormalize() {
        Case c = createCaseRow();
        String longTitle = '';
        for (Integer i = 0; i < 280; i++) {
            longTitle += 'B';
        }

        List<String> payloads = new List<String>{
            buildPayload('normal-title.txt', 'folder/file-1.txt', 'file-1'),
            buildPayload(longTitle, '', 'file-2')
        };

        Test.startTest();
        FEC_CaseFileUploadService.uploadFilesToCase(c.Id, payloads);
        Test.stopTest();

        List<ContentVersion> versions = [
            SELECT Id, Title, PathOnClient, FirstPublishLocationId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, versions.size(), 'Expected 2 uploaded files.');
        System.assertEquals('normal-title.txt', versions[0].Title);
        System.assertEquals('/folder/file-1.txt', versions[0].PathOnClient, 'Path should be normalized with leading slash.');
        System.assertEquals(255, versions[1].Title.length(), 'Title should be trimmed to 255 chars.');
        System.assertEquals(true, versions[1].PathOnClient.startsWith('/'));
    }

    @IsTest
    static void testUploadFilesToCase_skipInvalidPayloads() {
        Case c = createCaseRow();

        List<String> payloads = new List<String>{
            null,
            '',
            'abc',
            'title|path-only',
            'title|path|',
            '|path|' + EncodingUtil.base64Encode(Blob.valueOf('x'))
        };

        Test.startTest();
        FEC_CaseFileUploadService.uploadFilesToCase(c.Id, payloads);
        Test.stopTest();

        Integer countCv = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
        ];
        System.assertEquals(0, countCv, 'Invalid payloads should be skipped.');
    }

    private static String buildMyCaseZipPayload(String fileName, String extension, Blob fileBody) {
        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry(fileName.toLowerCase(), fileBody);
        return fileName + '|' + extension + '|' + EncodingUtil.base64Encode(writer.getArchive());
    }

    @IsTest
    static void testUploadMyCaseDocumentsToCase_unzipsZipPayload() {
        Case c = createCaseRow();
        Blob pngBody = Blob.valueOf('fake-png-content');
        List<String> payloads = new List<String>{
            buildMyCaseZipPayload('Samplepic.png', 'png', pngBody)
        };

        Test.startTest();
        FEC_CaseFileUploadService.uploadMyCaseDocumentsToCase(c.Id, payloads);
        Test.stopTest();

        List<ContentVersion> versions = [
            SELECT Title, PathOnClient, VersionData
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
        ];
        System.assertEquals(1, versions.size(), 'ZIP payload should produce one extracted file.');
        System.assertEquals('Samplepic.png', versions[0].Title);
        System.assertEquals('/Samplepic.png', versions[0].PathOnClient);
        System.assertEquals('fake-png-content', versions[0].VersionData.toString());
    }

    @IsTest
    static void testIsZipBase64_detectsZipPrefix() {
        System.assertEquals(true, FEC_CaseFileUploadService.isZipBase64('UEsDBBQAAAAI'));
        System.assertEquals(false, FEC_CaseFileUploadService.isZipBase64('aGVsbG8='));
        System.assertEquals(false, FEC_CaseFileUploadService.isZipBase64(null));
    }

    @IsTest
    static void testUploadMyCaseDocumentsToCase_allowedOnReviewCaseDuringMyCaseCreate() {
        Id customerRtId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();
        Case reviewCase = new Case(
            Subject = 'Review upload',
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
            RecordTypeId = customerRtId,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_REVIEW_MODE
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        insert reviewCase;
        FEC_CaseTriggerHandler.isExecuting = false;

        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry('samplepic.png', Blob.valueOf('png-bytes'));
        String payload =
            'Samplepic.png|png|' + EncodingUtil.base64Encode(writer.getArchive());

        update new Case(
            Id = reviewCase.Id,
            FEC_Interaction_View_Mode__c = FEC_ConstantCommon.INTERACTION_HANDLING_MODE
        );

        Test.startTest();
        FEC_CaseFileUploadService.uploadMyCaseDocumentsToCase(
            reviewCase.Id,
            new List<String>{ payload }
        );
        Test.stopTest();

        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE FirstPublishLocationId = :reviewCase.Id
            LIMIT 1
        ];
        System.assertEquals('Samplepic.png', cv.Title);
        System.assertEquals('png-bytes', cv.VersionData.toString());
    }

    @IsTest
    static void testUploadMyCaseDocumentsToCase_rawFilePayload() {
        Case c = createCaseRow();
        String payload =
            'report.pdf|pdf|' + EncodingUtil.base64Encode(Blob.valueOf('pdf-content'));

        Test.startTest();
        FEC_CaseFileUploadService.uploadMyCaseDocumentsToCase(c.Id, new List<String>{ payload });
        Test.stopTest();

        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
            LIMIT 1
        ];
        System.assertEquals('report.pdf', cv.Title);
        System.assertEquals('pdf-content', cv.VersionData.toString());
    }

    @IsTest
    static void testUploadFilesToCase_guardClauses() {
        Case c = createCaseRow();

        Test.startTest();
        FEC_CaseFileUploadService.uploadFilesToCase(null, new List<String>{ buildPayload('a', 'a.txt', 'x') });
        FEC_CaseFileUploadService.uploadFilesToCase(c.Id, null);
        FEC_CaseFileUploadService.uploadFilesToCase(c.Id, new List<String>());
        Test.stopTest();

        Integer countCv = [
            SELECT COUNT()
            FROM ContentVersion
            WHERE FirstPublishLocationId = :c.Id
        ];
        System.assertEquals(0, countCv, 'Guard clauses should return without inserts.');
    }
}