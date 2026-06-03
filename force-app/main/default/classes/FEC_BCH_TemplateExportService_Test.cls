@IsTest
private class FEC_BCH_TemplateExportService_Test {

    private static final String SAMPLE_WORKSHEET_XML =
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
        '<sheetData>' +
        '<row r="1">' +
        '<c r="A1"><is><t>Case ID</t></is></c>' +
        '<c r="B1"><is><t>Subject</t></is></c>' +
        '</row>' +
        '</sheetData>' +
        '</worksheet>';

    private static ContentVersion createTemplateVersion(String pathOnClient, Blob versionData) {
        ContentVersion cv = new ContentVersion(
            Title = pathOnClient,
            PathOnClient = pathOnClient,
            VersionData = versionData == null ? Blob.valueOf('dummy') : versionData
        );
        insert cv;
        return [SELECT Id, PathOnClient, Title FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }

    @IsTest
    static void testExportWorkbook_guardClauses() {
        FEC_BCH_TemplateExportService.ExportWorkbookResponse nullResp =
            FEC_BCH_TemplateExportService.exportWorkbook(null);
        System.assertEquals(false, nullResp.success);
        System.assertEquals('EMPTY_REQUEST', nullResp.errorCode);

        FEC_BCH_TemplateExportService.ExportWorkbookResponse blankResp =
            FEC_BCH_TemplateExportService.exportWorkbook('');
        System.assertEquals(false, blankResp.success);
        System.assertEquals('EMPTY_REQUEST', blankResp.errorCode);

        FEC_BCH_TemplateExportService.ExportWorkbookResponse invalidResp =
            FEC_BCH_TemplateExportService.exportWorkbook('{}');
        System.assertEquals(false, invalidResp.success);
        System.assertEquals('INVALID_REQUEST', invalidResp.errorCode);
    }

    @IsTest
    static void testExportWorkbookBase64_failedRequestReturnsNull() {
        System.assertEquals(null, FEC_BCH_TemplateExportService.exportWorkbookBase64(null));
        System.assertEquals(null, FEC_BCH_TemplateExportService.exportWorkbookBase64('{}'));
    }

    @IsTest
    static void testResolveMappedColumnIndexesForHeaders_nullInputs() {
        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            null,
            0,
            null,
            null
        );
        System.assertEquals(0, mapped.size());
    }

    @IsTest
    static void testExportWorkbook_dummyBlobReturnsZipReadEmpty() {
        ContentVersion cv = createTemplateVersion('export_dummy.xlsx', null);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-001' }
        };

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('ZIP_READ_EMPTY', resp.errorCode);
        System.assertNotEquals(null, resp.errorMessage);
    }

    @IsTest
    static void testExportWorkbook_templateNotFound() {
        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = (Id) '068000000000001AAA';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-001' }
        };

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('TEMPLATE_NOT_FOUND', resp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_validXlsxNoDataRows() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Subject' },
                new List<String>{ 'SRCH-001', 'Row 1' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_valid.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = new List<List<String>>();

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('NO_DATA_ROWS', resp.errorCode);
    }

    @IsTest
    static void testResolveMappedColumnIndexesForHeaders_validXlsx() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Subject' }
            }
        );
        ContentVersion cv = createTemplateVersion('resolve_headers.xlsx', workbook);

        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            0,
            'Result',
            new List<String>{ 'Case ID', 'Subject' }
        );

        System.assertEquals(2, mapped.size());
    }

    @IsTest
    static void testResolveMappedColumnIndexesFromHeaderRow_sampleXml() {
        List<Integer> indexes = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesFromHeaderRow(
            SAMPLE_WORKSHEET_XML,
            1,
            new List<String>(),
            new List<String>{ 'Case ID', 'Subject' }
        );

        System.assertEquals(2, indexes.size());
        System.assertEquals(0, indexes[0]);
        System.assertEquals(1, indexes[1]);
    }

    @IsTest
    static void testMatchColumnByHeaderRules() {
        Map<String, String> colToHeader = new Map<String, String>{
            'A' => 'routingactionmain',
            'B' => 'assignmentroutingaction',
            'C' => 'inputtedremarks'
        };

        String routingCol = FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
            colToHeader,
            new List<String>{ 'routingaction' },
            new List<String>{ 'assignmentrouting' },
            false
        );
        System.assertEquals('A', routingCol);

        String anyMatchCol = FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
            colToHeader,
            new List<String>{ 'cssupport', 'danhgia' },
            null,
            true
        );
        System.assertEquals(null, anyMatchCol);
    }

    @IsTest
    static void testBuildDataValidationXml() {
        String xml = FEC_BCH_TemplateExportService.buildDataValidationXml(
            'Sheet1!$A$2:$A$10',
            'D3:D100',
            '{384C5710-23BE-435C-862B-000000000001}'
        );

        System.assert(xml.contains('Sheet1!$A$2:$A$10'));
        System.assert(xml.contains('D3:D100'));
        System.assert(xml.contains('384C5710-23BE-435C-862B-000000000001'));
    }
}
