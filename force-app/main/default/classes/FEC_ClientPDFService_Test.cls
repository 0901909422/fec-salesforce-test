@IsTest
private class FEC_ClientPDFService_Test {

    private static final String VALID_TEMPLATE_CODE = 'TBCV_LTN';
    private static final String INVALID_TEMPLATE_CODE = 'NON_EXISTENT_TEMPLATE_XYZ';

    private static Case insertTestCase() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                Subject = 'Client PDF Test',
                Status = 'New',
                FEC_ID_Search__c = 'PDF-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
            return c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetTemplateData_Success() {
        Test.startTest();
        Map<String, String> result = FEC_ClientPDFService.getTemplateData(VALID_TEMPLATE_CODE);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result không được null.');
        System.assertEquals(VALID_TEMPLATE_CODE, result.get('templateCode'));
        System.assert(String.isNotBlank(result.get('htmlBody')), 'htmlBody phải có giá trị.');
    }

    @IsTest
    static void testGetTemplateData_TemplateNotFound() {
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData(INVALID_TEMPLATE_CODE);
            System.assert(false, 'Phải throw AuraHandledException khi template không tồn tại.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetTemplateData_NullCode() {
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData(null);
            System.assert(false, 'Phải throw AuraHandledException khi code null.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetTemplateData_EmptyCode() {
        Test.startTest();
        try {
            FEC_ClientPDFService.getTemplateData('');
            System.assert(false, 'Phải throw AuraHandledException khi code rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSavePdfToCase_Success() {
        Case c = insertTestCase();
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 test content'));

        Test.startTest();
        Id contentVersionId = FEC_ClientPDFService.savePdfToCase(
            base64Data,
            'ContractClosure',
            c.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, contentVersionId, 'Phải trả về ContentVersion Id.');
        ContentVersion cv = [
            SELECT Id, Title, FirstPublishLocationId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        System.assertEquals('ContractClosure', cv.Title);
        System.assertEquals(c.Id, cv.FirstPublishLocationId);
    }

    @IsTest
    static void testSavePdfToCase_BlankBase64() {
        Case c = insertTestCase();

        Test.startTest();
        try {
            FEC_ClientPDFService.savePdfToCase('', 'file.pdf', c.Id);
            System.assert(false, 'Phải throw AuraHandledException khi base64 rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSavePdfToCase_BlankFileName() {
        Case c = insertTestCase();
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('pdf'));

        Test.startTest();
        try {
            FEC_ClientPDFService.savePdfToCase(base64Data, '', c.Id);
            System.assert(false, 'Phải throw AuraHandledException khi fileName rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSavePdfToCase_BlankCaseId() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('pdf'));

        Test.startTest();
        try {
            FEC_ClientPDFService.savePdfToCase(base64Data, 'file.pdf', '');
            System.assert(false, 'Phải throw AuraHandledException khi caseId rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}
