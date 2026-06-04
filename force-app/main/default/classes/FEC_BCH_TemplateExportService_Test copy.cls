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
        '<row r="2">' +
        '<c r="A2"><is><t>SRCH-001</t></is></c>' +
        '<c r="B2"><is><t>Sample</t></is></c>' +
        '</row>' +
        '</sheetData>' +
        '</worksheet>';

    private static Blob buildImportStyleWorkbook(List<List<String>> rows) {
        return FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(rows);
    }

    private static String columnLetter(Integer zeroBasedCol) {
        Integer dividend = zeroBasedCol + 1;
        String columnName = '';
        while (dividend > 0) {
            Integer modulo = Math.mod(dividend - 1, 26);
            columnName = String.fromCharArray(new List<Integer>{ 65 + modulo }) + columnName;
            dividend = (dividend - modulo) / 26;
        }
        return columnName;
    }

    private static String inlineCell(String colLetter, Integer rowNum1, String value) {
        String safe = value == null ? '' : value;
        return '<c r="' + colLetter + rowNum1 + '" t="inlineStr"><is><t>' + safe + '</t></is></c>';
    }

    private static String buildSheetDataXml(List<List<String>> rows) {
        List<String> rowParts = new List<String>();
        for (Integer r = 0; r < rows.size(); r++) {
            List<String> cells = new List<String>();
            List<String> vals = rows[r];
            Integer colCount = vals == null ? 0 : vals.size();
            for (Integer c = 0; c < colCount; c++) {
                cells.add(inlineCell(columnLetter(c), r + 1, vals[c]));
            }
            rowParts.add('<row r="' + String.valueOf(r + 1) + '">' + String.join(cells, '') + '</row>');
        }
        return '<sheetData>' + String.join(rowParts, '') + '</sheetData>';
    }

    /** Workbook with Result + Sheet1 lookup to exercise list validations during export. */
    private static Blob buildDualSheetWorkbookBlob() {
        List<String> mainHeaders = new List<String>{
            'Case ID',
            'Routing Action',
            'Assignment Routing Action',
            'Inputted Remarks',
            'CS Support Assessment',
            'Risk Level',
            'Required Action',
            'Classification By CS',
            'Evaluation By CS',
            'Final Product'
        };
        List<String> mainData = new List<String>{
            'SRCH-WIDE-001',
            'Approve',
            'Assign Route',
            'Wide import remark',
            'Good',
            'Low',
            'Follow up',
            'Class A',
            'Eval A',
            'Product X'
        };
        String mainSheetXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
            'xmlns:xr="http://schemas.microsoft.com/office/spreadsheetml/2014/revision">' +
            buildSheetDataXml(new List<List<String>>{ mainHeaders, mainData }) +
            '<extLst><ext uri="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">' +
            '<x14:dataValidations xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">' +
            '<x14:dataValidation type="list" xr:uid="{384C5710-23BE-435C-862B-000000000001}">' +
            '<x14:formula1><xm:f>Sheet1!$A$2:$A$3</xm:f></x14:formula1>' +
            '<xm:sqref>B2:B2</xm:sqref></x14:dataValidation></x14:dataValidations></ext></extLst></worksheet>';

        List<String> lookupHeaders = new List<String>{
            'Routing Action',
            'Classification By CS',
            'Evaluation By CS',
            'Product Final'
        };
        String lookupSheetXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
            buildSheetDataXml(
                new List<List<String>>{
                    lookupHeaders,
                    new List<String>{ 'Approve', 'Class A', 'Eval A', 'Prod X' },
                    new List<String>{ 'Reject', 'Class B', 'Eval B', 'Prod Y' }
                }
            ) +
            '</worksheet>';

        String workbookXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<sheets>' +
            '<sheet name="Result" sheetId="1" r:id="rId1"/>' +
            '<sheet name="Sheet1" sheetId="2" r:id="rId2"/>' +
            '</sheets></workbook>';

        String workbookRelsXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>' +
            '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
            '</Relationships>';

        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry(
            '[Content_Types].xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
                '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
                '<Default Extension="xml" ContentType="application/xml"/>' +
                '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
                '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
                '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
                '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
                '</Types>'
            )
        );
        writer.addEntry(
            '_rels/.rels',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
                '</Relationships>'
            )
        );
        writer.addEntry('xl/_rels/workbook.xml.rels', Blob.valueOf(workbookRelsXml));
        writer.addEntry('xl/workbook.xml', Blob.valueOf(workbookXml));
        writer.addEntry(
            'xl/styles.xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
                '<fonts count="1"><font><sz val="11"/></font></fonts>' +
                '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' +
                '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
                '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
                '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>' +
                '</styleSheet>'
            )
        );
        writer.addEntry('xl/worksheets/sheet1.xml', Blob.valueOf(mainSheetXml));
        writer.addEntry('xl/worksheets/sheet2.xml', Blob.valueOf(lookupSheetXml));
        return writer.getArchive();
    }

    private static ContentVersion createTemplateVersion(String pathOnClient, Blob versionData) {
        ContentVersion cv = new ContentVersion(
            Title = pathOnClient,
            PathOnClient = pathOnClient,
            VersionData = versionData == null ? Blob.valueOf('dummy') : versionData
        );
        insert cv;
        return [SELECT Id, PathOnClient, Title FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }

    private static FEC_BCH_TemplateExportService.ExportRequest buildBasicExportRequest(
        Id contentVersionId,
        List<List<String>> dataRows
    ) {
        FEC_BCH_TemplateExportService.ExportRequest req =
            new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = contentVersionId;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1, 2 };
        req.dataRows = dataRows;
        return req;
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
    static void testExportWorkbookBase64_successAndFailure() {
        System.assertEquals(null, FEC_BCH_TemplateExportService.exportWorkbookBase64(null));
        System.assertEquals(null, FEC_BCH_TemplateExportService.exportWorkbookBase64('{}'));

        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Remark line' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_success.xlsx', workbook);
        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{ 'SRCH-001', 'Reject', 'Updated remark' }
            }
        );

        Test.startTest();
        String base64 = FEC_BCH_TemplateExportService.exportWorkbookBase64(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, base64);
        System.assert(base64.length() > 0);
    }

    @IsTest
    static void testExportWorkbook_success() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Template remark' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_patch.xlsx', workbook);
        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{ 'SRCH-002', 'Hold', 'Long remark with line' },
                new List<String>{ 'SRCH-003', 'Resolve', 'Second row' }
            }
        );

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success);
        System.assertNotEquals(null, resp.base64Body);
    }

    @IsTest
    static void testExportWorkbook_withStatusErrorsInsert() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Row template' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_result_cols.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{ 'SRCH-001', 'Approve', 'Done' }
            }
        );
        req.insertColumnsBeforeIndex = 2;
        req.insertColumnHeaders = new List<String>{ '__Status', '__Errors' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Success', '' }
        };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success);
    }

    @IsTest
    static void testExportWorkbook_withGenericInsertColumns() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Base' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_insert_col.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{ 'SRCH-001', 'Approve', 'Merged' }
            }
        );
        req.insertColumnsBeforeIndex = 1;
        req.insertColumnHeaders = new List<String>{ 'Extra Info' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Extra value' }
        };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success);
    }

    @IsTest
    static void testExportWorkbook_preserveSourceColumn() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Preserve me' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_preserve.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{ 'SRCH-001', 'Approve', 'Should not overwrite' }
            }
        );
        req.preserveSourceWorksheetColIndex = 2;
        req.sourceDataRowIndexes = new List<Integer>{ 1 };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success);
    }

    @IsTest
    static void testExportWorkbook_rowLimitExceeded() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Row' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_limit.xlsx', workbook);

        List<List<String>> manyRows = new List<List<String>>();
        for (Integer i = 0; i < 5001; i++) {
            manyRows.add(new List<String>{ 'ID-' + i, 'Approve', 'R' + i });
        }

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(cv.Id, manyRows);

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals('ROW_LIMIT', resp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_dummyBlobReturnsZipReadEmpty() {
        ContentVersion cv = createTemplateVersion('export_dummy.xlsx', null);
        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{ new List<String>{ 'CASE-001', 'Approve', 'X' } }
        );

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('ZIP_READ_EMPTY', resp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_templateNotFound() {
        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            (Id) '068000000000001AAA',
            new List<List<String>>{ new List<String>{ 'CASE-001', 'Approve', 'X' } }
        );

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('TEMPLATE_NOT_FOUND', resp.errorCode);
    }

    @IsTest
    static void testExportWorkbook_validXlsxNoDataRows() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Row 1' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_valid.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(cv.Id, new List<List<String>>());

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('NO_DATA_ROWS', resp.errorCode);
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
    static void testResolveMappedColumnIndexesForHeaders_validXlsx() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' }
            }
        );
        ContentVersion cv = createTemplateVersion('resolve_headers.xlsx', workbook);

        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            0,
            'Result',
            new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' }
        );

        System.assertEquals(3, mapped.size());
    }

    @IsTest
    static void testResolveMappedColumnIndexesFromHeaderRow_sampleXml() {
        List<Integer> indexes = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesFromHeaderRow(
            SAMPLE_WORKSHEET_XML,
            1,
            new List<String>(),
            new List<String>{ 'Case ID', 'Subject', 'Missing Header' }
        );

        System.assertEquals(3, indexes.size());
        System.assertEquals(0, indexes[0]);
        System.assertEquals(1, indexes[1]);
    }

    @IsTest
    static void testResolveTemplateDataRowNum() {
        Integer rowNum = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(SAMPLE_WORKSHEET_XML, 0);
        System.assertEquals(2, rowNum);
        System.assertEquals(null, FEC_BCH_TemplateExportService.resolveTemplateDataRowNum('', 0));
    }

    @IsTest
    static void testMatchColumnByHeaderRules() {
        Map<String, String> colToHeader = new Map<String, String>{
            'A' => 'routingactionmain',
            'B' => 'assignmentroutingaction',
            'C' => 'inputtedremarks',
            'D' => 'cssupportdanhgia'
        };

        System.assertEquals(
            'A',
            FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
                colToHeader,
                new List<String>{ 'routingaction' },
                new List<String>{ 'assignmentrouting' },
                false
            )
        );

        System.assertEquals(
            'D',
            FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
                colToHeader,
                new List<String>{ 'cssupport', 'danhgia' },
                null,
                true
            )
        );

        System.assertEquals(
            null,
            FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
                colToHeader,
                new List<String>{ 'notfound' },
                null,
                false
            )
        );

        System.assertEquals(
            null,
            FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
                null,
                new List<String>{ 'routingaction' },
                null,
                false
            )
        );
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

        String autoUid = FEC_BCH_TemplateExportService.buildDataValidationXml('List!$B$1', 'E2:E5', null);
        System.assert(autoUid.contains('x14:dataValidation'));
    }

    @IsTest
    static void testReadImportCellText_andLength() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Cell remark text' }
            }
        );
        ContentVersion cv = createTemplateVersion('read_cell.xlsx', workbook);

        System.assertEquals('', FEC_BCH_TemplateExportService.readImportCellText(null, 'Result', 1, 2));
        System.assertEquals(0, FEC_BCH_TemplateExportService.readImportCellTextLength(null, 'Result', 1, 2));

        String text = FEC_BCH_TemplateExportService.readImportCellText(cv.Id, 'Result', 1, 2);
        Integer len = FEC_BCH_TemplateExportService.readImportCellTextLength(cv.Id, 'Result', 1, 2);

        System.assertNotEquals(null, text);
        System.assert(len >= 0);
    }

    @IsTest
    static void testParseBatchImportWorkbook_nullAndInvalid() {
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult nullResult =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(null);
        System.assertEquals(false, nullResult.parseSuccess);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult missing =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook((Id) '068000000000001AAA');
        System.assertEquals(false, missing.parseSuccess);

        ContentVersion badZip = createTemplateVersion('bad_zip.xlsx', Blob.valueOf('not-a-zip'));
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult zipFail =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(badZip.Id);
        System.assertEquals(false, zipFail.parseSuccess);
    }

    @IsTest
    static void testParseBatchImportWorkbook_success() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-001', 'Approve', 'Import remark' },
                new List<String>{ 'SRCH-002', 'Reject', 'Second import row' }
            }
        );
        ContentVersion cv = createTemplateVersion('parse_import.xlsx', workbook);

        Test.startTest();
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        Test.stopTest();

        System.assertEquals(true, parsed.parseSuccess);
        System.assertEquals(2, parsed.inputRows.size());
        System.assertNotEquals(null, parsed.importHeaders);
        System.assert(parsed.importHeaders.size() >= 3);
    }

    @IsTest
    static void testParseBatchImportWorkbook_headerOnlyNoData() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' }
            }
        );
        ContentVersion cv = createTemplateVersion('parse_header_only.xlsx', workbook);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);

        System.assertEquals(false, parsed.parseSuccess);
    }

    @IsTest
    static void testParseBatchImportWorkbook_invalidHeaders() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{ 'Customer Name', 'Subject' },
                new List<String>{ 'A', 'B' }
            }
        );
        ContentVersion cv = createTemplateVersion('parse_bad_headers.xlsx', workbook);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);

        System.assertEquals(false, parsed.parseSuccess);
    }

    @IsTest
    static void testExportWorkbook_dualSheetWithLookupValidations() {
        ContentVersion cv = createTemplateVersion('dual_sheet.xlsx', buildDualSheetWorkbookBlob());

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{
                new List<String>{
                    'SRCH-EXP-001',
                    'Reject',
                    'Assign Hold',
                    'Export remark',
                    'OK',
                    'High',
                    'Action',
                    'Class B',
                    'Eval B',
                    'Product Y'
                }
            }
        );
        req.mappedColumnIndexes = new List<Integer>{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success);
        System.assertNotEquals(null, resp.base64Body);
    }

    @IsTest
    static void testExportWorkbook_worksheetNotFound() {
        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry(
            '[Content_Types].xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
                '<Default Extension="xml" ContentType="application/xml"/>' +
                '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
                '</Types>'
            )
        );
        writer.addEntry(
            'xl/workbook.xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
                'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
                '<sheets><sheet name="Ghost" sheetId="1" r:id="rId1"/></sheets></workbook>'
            )
        );
        writer.addEntry(
            'xl/_rels/workbook.xml.rels',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/missing.xml"/>' +
                '</Relationships>'
            )
        );
        ContentVersion cv = createTemplateVersion('broken_sheet_ref.xlsx', writer.getArchive());

        FEC_BCH_TemplateExportService.ExportRequest req = buildBasicExportRequest(
            cv.Id,
            new List<List<String>>{ new List<String>{ 'SRCH-001', 'Approve', 'X' } }
        );
        req.templateSheetName = 'Ghost';

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('WORKSHEET_NOT_FOUND', resp.errorCode);
    }

    @IsTest
    static void testParseBatchImportWorkbook_wideCofHeaders() {
        Blob workbook = buildDualSheetWorkbookBlob();
        ContentVersion cv = createTemplateVersion('parse_wide.xlsx', workbook);

        Test.startTest();
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        Test.stopTest();

        System.assertEquals(true, parsed.parseSuccess);
        System.assertEquals(1, parsed.inputRows.size());
        System.assertEquals(true, parsed.cofOrGsr);
        Map<String, Object> row = (Map<String, Object>) parsed.inputRows[0];
        System.assertEquals('SRCH-WIDE-001', row.get('caseIdSearch'));
        System.assertNotEquals(null, row.get('csSupportAssessment'));
    }

    @IsTest
    static void testParseBatchImportWorkbook_withStatusErrorsExcluded() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{
                new List<String>{
                    'Case ID',
                    'Routing Action',
                    'Inputted Remarks',
                    '__Status',
                    '__Errors'
                },
                new List<String>{ 'SRCH-ST-001', 'Approve', 'Remark', 'OK', 'None' }
            }
        );
        ContentVersion cv = createTemplateVersion('parse_status_cols.xlsx', workbook);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);

        System.assertEquals(true, parsed.parseSuccess);
        System.assertEquals(3, parsed.importHeaders.size());
    }

    @IsTest
    static void testMatchColumnByHeaderRules_mustNotContain() {
        Map<String, String> colToHeader = new Map<String, String>{
            'A' => 'routingactioninputtedremarks',
            'B' => 'pureassignmentroutingaction'
        };
        System.assertEquals(
            'B',
            FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
                colToHeader,
                new List<String>{ 'assignmentroutingaction' },
                new List<String>{ 'inputtedremarks' },
                false
            )
        );
    }

    @IsTest
    static void testCellTextAtWorksheetColumn() {
        Map<Integer, String> cols = new Map<Integer, String>{ 0 => 'A', 2 => 'C' };
        System.assertEquals('A', FEC_BCH_TemplateExportService.cellTextAtWorksheetColumn(cols, 0));
        System.assertEquals('', FEC_BCH_TemplateExportService.cellTextAtWorksheetColumn(cols, 1));
        System.assertEquals('', FEC_BCH_TemplateExportService.cellTextAtWorksheetColumn(null, 0));
    }

    @IsTest
    static void testResolveMappedColumnIndexesForHeaders_unknownSheetFallsBackToMain() {
        Blob workbook = buildImportStyleWorkbook(
            new List<List<String>>{ new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' } }
        );
        ContentVersion cv = createTemplateVersion('resolve_fallback_sheet.xlsx', workbook);

        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            0,
            'NoSuchSheet',
            new List<String>{ 'Case ID' }
        );

        System.assertEquals(1, mapped.size());
        System.assertEquals(0, mapped[0]);
    }
}
