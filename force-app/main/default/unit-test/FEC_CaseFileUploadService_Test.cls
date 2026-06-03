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
