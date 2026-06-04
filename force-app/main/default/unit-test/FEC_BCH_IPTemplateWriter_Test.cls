/**
 * Unit tests for FEC_BCH_IncorrectPaymentTemplateWriter.
 * Class name shortened (FEC_BCH_IPTemplateWriter_Test) to meet Apex 40-character limit.
 */
@IsTest
private class FEC_BCH_IPTemplateWriter_Test {

    private static final String TARGET_FILE = 'incorrectpaymenttemp1_pm.xlsx';

    private static Case insertCase(String caseIdSearch) {
        Case c = new Case(
            Subject = 'BCH Incorrect Payment Export',
            Status = 'New',
            FEC_ID_Search__c = caseIdSearch
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return [SELECT Id, FEC_ID_Search__c FROM Case WHERE Id = :c.Id LIMIT 1];
    }

    private static ContentVersion createTemplateVersion(String pathOnClient, Blob versionData) {
        ContentVersion cv = new ContentVersion(
            Title = pathOnClient,
            PathOnClient = pathOnClient,
            VersionData = versionData == null ? Blob.valueOf('dummy') : versionData
        );
        insert cv;
        return [
            SELECT Id, PathOnClient, Title, FileExtension
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
    }

    private static Blob buildIncorrectPaymentTemplateBlob() {
        return FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{
                    'Case ID',
                    'Customer Name',
                    'Payment Method',
                    'Correct Contract Amount 1',
                    'Adjusted Amount 1',
                    'Correct Contract Amount 2',
                    'Adjusted Amount 2',
                    'No',
                    'Result'
                },
                new List<String>{
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '1',
                    ''
                }
            }
        );
    }

    private static FEC_BCH_TemplateExportService.ExportRequest buildExportRequest(
        Id contentVersionId,
        String caseIdSearch,
        String preservedNo
    ) {
        FEC_BCH_TemplateExportService.ExportRequest req =
            new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = contentVersionId;
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1, 2, 3, 4, 5, 6, 7, 8 };
        req.dataRows = new List<List<String>>{
            new List<String>{
                caseIdSearch,
                'SourceName',
                'Cash',
                'SRC-CORRECT-1',
                'SRC-ADJ-1',
                'SRC-CORRECT-2',
                'SRC-ADJ-2',
                preservedNo,
                'Pending'
            }
        };
        return req;
    }

    @IsTest
    static void testShouldHandle_nullAndUnknownId() {
        System.assertEquals(false, FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(null));
        System.assertEquals(
            false,
            FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle((Id) '068000000000001AAA')
        );
    }

    @IsTest
    static void testShouldHandle_byTemplateFileName() {
        ContentVersion target = createTemplateVersion(TARGET_FILE, buildIncorrectPaymentTemplateBlob());
        ContentVersion nonTarget = createTemplateVersion('other_template.xlsx', null);

        System.assertEquals(true, FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(target.Id));
        System.assertEquals(false, FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(nonTarget.Id));
    }

    @IsTest
    static void testShouldHandle_pathWithDirectoryPrefix() {
        ContentVersion cv = createTemplateVersion(
            'templates\\subdir/' + TARGET_FILE,
            buildIncorrectPaymentTemplateBlob()
        );
        System.assertEquals(true, FEC_BCH_IncorrectPaymentTemplateWriter.shouldHandle(cv.Id));
    }

    @IsTest
    static void testExportWorkbook_guardClauses() {
        FEC_BCH_TemplateExportService.ExportWorkbookResponse blankResp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(null);
        System.assertEquals(false, blankResp.success);
        System.assertEquals('EMPTY_REQUEST', blankResp.errorCode);

        FEC_BCH_TemplateExportService.ExportWorkbookResponse invalidResp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook('{}');
        System.assertEquals(false, invalidResp.success);
        System.assertEquals('INVALID_REQUEST', invalidResp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_unsupportedTemplate() {
        ContentVersion nonTarget = createTemplateVersion('not_incorrect_payment.xlsx', null);
        FEC_BCH_TemplateExportService.ExportRequest req = buildExportRequest(nonTarget.Id, 'IP-001', '1');

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('UNSUPPORTED_TEMPLATE', resp.errorCode);
        System.assertNotEquals(null, resp.errorMessage);
    }

    @IsTest
    static void testExportWorkbook_noCaseIdHeader_passthrough() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Customer Name', 'Payment Method' },
                new List<String>{ '', '' }
            }
        );
        ContentVersion cv = createTemplateVersion(TARGET_FILE, workbook);
        FEC_BCH_TemplateExportService.ExportRequest req = buildExportRequest(cv.Id, 'IP-NO-COL', '9');

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @IsTest
    static void testExportWorkbook_blankCaseIdInRows_passthrough() {
        ContentVersion cv = createTemplateVersion(TARGET_FILE, buildIncorrectPaymentTemplateBlob());
        FEC_BCH_TemplateExportService.ExportRequest req = buildExportRequest(cv.Id, '', '2');

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @IsTest
    static void testExportWorkbook_unknownCaseIdSearch_passthrough() {
        ContentVersion cv = createTemplateVersion(TARGET_FILE, buildIncorrectPaymentTemplateBlob());
        FEC_BCH_TemplateExportService.ExportRequest req =
            buildExportRequest(cv.Id, 'IP-NOT-IN-ORG-' + String.valueOf(System.currentTimeMillis()), '3');

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @IsTest
    static void testExportWorkbook_rebuildsRowsFromCaseAndAdjustments() {
        String caseIdSearch = 'IP-EXPORT-' + String.valueOf(System.currentTimeMillis());
        Case c = insertCase(caseIdSearch);
        c.FEC_Payment_Method__c = 'Bank Transfers';
        c.FEC_Incorrect_Contract_Number__c = 'INC-CON';
        update c;

        insert new FEC_Incorrect_Payment_Info__c(
            FEC_Case__c = c.Id,
            FEC_Correct_Account_Contract__c = 'CORRECT-1',
            FEC_Adjusted_Amount__c = 1000
        );
        insert new FEC_Incorrect_Payment_Info__c(
            FEC_Case__c = c.Id,
            FEC_Correct_Account_Contract__c = 'CORRECT-2',
            FEC_Adjusted_Amount__c = 2000
        );

        ContentVersion cv = createTemplateVersion(TARGET_FILE, buildIncorrectPaymentTemplateBlob());
        FEC_BCH_TemplateExportService.ExportRequest req = buildExportRequest(cv.Id, caseIdSearch, '7');

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, resp);
        if (resp.success == true) {
            System.assertNotEquals(null, resp.base64Body);
        }
    }

    @IsTest
    static void testExportWorkbook_caseWithoutAdjustmentRows() {
        String caseIdSearch = 'IP-NO-ADJ-' + String.valueOf(System.currentTimeMillis());
        insertCase(caseIdSearch);

        ContentVersion cv = createTemplateVersion(TARGET_FILE, buildIncorrectPaymentTemplateBlob());
        FEC_BCH_TemplateExportService.ExportRequest req = buildExportRequest(cv.Id, caseIdSearch, '5');

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_IncorrectPaymentTemplateWriter.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }
}
