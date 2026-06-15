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
    static void testExportWorkbook_validXlsxWithDataRows_success() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Subject' },
                new List<String>{ 'SRCH-001', 'Row 1' }
            }
        );
        ContentVersion cv = createTemplateVersion('export_success.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-NEW', 'Subject New' }
        };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        String base64 = FEC_BCH_TemplateExportService.exportWorkbookBase64(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
        System.assertNotEquals(null, resp.base64Body);
        System.assertNotEquals(null, base64);
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

    @IsTest
    static void testExportWorkbook_withStatusErrorsInsert_success() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('export_status_errors.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-001', 'Subject 1' }
        };
        req.insertColumnsBeforeIndex = 2;
        req.insertColumnHeaders = new List<String>{ '__Status', '__Errors' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Failed', 'Remark too long' }
        };
        req.preserveSourceWorksheetColIndex = 1;
        req.sourceDataRowIndexes = new List<Integer>{ 0 };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
        System.assertNotEquals(null, resp.base64Body);
    }

    @IsTest
    static void testExportWorkbook_withPropertyInsertColumns_success() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('export_property_insert.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-002', 'Subject 2' }
        };
        req.insertColumnsBeforeIndex = 1;
        req.insertColumnHeaders = new List<String>{ 'Property Info' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Extra value' }
        };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
    }

    @IsTest
    static void testExportWorkbook_rowLimitExceeded() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('export_row_limit.xlsx', workbook);

        List<List<String>> dataRows = new List<List<String>>();
        for (Integer i = 0; i < 5001; i++) {
            dataRows.add(new List<String>{ 'CASE-' + String.valueOf(i) });
        }

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = dataRows;

        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));

        System.assertEquals(false, resp.success);
        System.assertEquals('ROW_LIMIT', resp.errorCode);
    }

    @IsTest
    static void testReadImportCellText_successAndGuardClauses() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('read_cell.xlsx', workbook);

        Test.startTest();
        String cellText = FEC_BCH_TemplateExportService.readImportCellText(cv.Id, 'Result', 1, 0);
        Integer cellLen = FEC_BCH_TemplateExportService.readImportCellTextLength(cv.Id, 'Result', 1, 0);
        String blankText = FEC_BCH_TemplateExportService.readImportCellText(null, null, 0, 0);
        Integer blankLen = FEC_BCH_TemplateExportService.readImportCellTextLength(null, null, 0, 0);
        Test.stopTest();

        System.assertEquals('SRCH-001', cellText);
        System.assertEquals(8, cellLen);
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, blankText);
        System.assertEquals(0, blankLen);
    }

    @IsTest
    static void testResolveMappedColumnIndexesForHeaders_usesCache() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('resolve_cache.xlsx', workbook);
        List<String> headers = new List<String>{ 'Case ID', 'Subject' };

        Test.startTest();
        List<Integer> first = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            0,
            'Result',
            headers
        );
        List<Integer> second = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            0,
            'Result',
            headers
        );
        Test.stopTest();

        System.assertEquals(2, first.size());
        System.assertEquals(first, second);
    }

    @IsTest
    static void testParseBatchImportWorkbook_guardClauses() {
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult nullResult =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(null);
        System.assertEquals(false, nullResult.parseSuccess);

        ContentVersion invalidCv = createTemplateVersion('invalid_import.xlsx', Blob.valueOf('not-a-zip'));
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult invalidResult =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(invalidCv.Id);
        System.assertEquals(false, invalidResult.parseSuccess);
    }

    @IsTest
    static void testParseBatchImportWorkbook_validMinimalWorkbook() {
        ContentVersion cv = new ContentVersion(
            Title = 'MinimalImport',
            PathOnClient = 'MinimalImport.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64())
        );
        insert cv;

        Test.startTest();
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult result =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        Test.stopTest();

        System.assertEquals(true, result.parseSuccess, result.errorMessage);
        System.assertEquals(1, result.inputRows.size());
        Map<String, Object> row = (Map<String, Object>) result.inputRows[0];
        System.assertEquals('CASE-001', row.get('caseIdSearch'));
        System.assertEquals('Reject', row.get('routingAction'));
        System.assertEquals('test remark', row.get('inputtedRemarks'));
    }

    @IsTest
    static void testHelperMethods_shiftMergeEncodeAndResolve() {
        List<List<String>> dataRows = new List<List<String>>();
        List<String> row = new List<String>();
        for (Integer i = 0; i < 24; i++) {
            row.add('c' + String.valueOf(i));
        }
        row[21] = 'ROUTING';
        row[22] = 'REMARK_LONG';
        dataRows.add(row);

        Test.startTest();
        Integer logicalWidth = FEC_BCH_TemplateExportService.resolveDataRowsLogicalWidth(dataRows);
        List<List<String>> merged = FEC_BCH_TemplateExportService.mergeInsertColumnValues(
            dataRows,
            new List<List<String>>{ new List<String>{ 'Failed', 'Remark too long' } },
            2,
            logicalWidth
        );
        List<Integer> mapped = new List<Integer>();
        for (Integer i = 0; i < 35; i++) {
            mapped.add(i);
        }
        List<Integer> shifted = FEC_BCH_TemplateExportService.shiftMappedColumnIndexes(mapped, 8, 2);
        String encoded = FEC_BCH_TemplateExportService.encodeInlineStrLineBreaks(
            'Err A\nErr B &amp; long text over forty characters here'
        );
        String cell = FEC_BCH_TemplateExportService.buildInlineCell('Z99', ' s="1"', encoded);
        Integer rowNum = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(SAMPLE_WORKSHEET_XML, 0);
        String shiftedXml = FEC_BCH_TemplateExportService.shiftAllSheetDataRowsUpTo(
            '<sheetData><row r="1"><c r="V1" s="14"/><c r="W1" s="16"/></row></sheetData>',
            1,
            21,
            4
        );
        Test.stopTest();

        System.assertEquals(24, logicalWidth);
        System.assertEquals(26, merged[0].size());
        System.assertEquals(37, shifted.size());
        System.assert(cell.contains('&#10;'));
        System.assertEquals(1, rowNum);
        System.assert(shiftedXml.contains('r="Z1"'));
    }

    @IsTest
    static void testExportWorkbook_multipleDataRows_success() {
        Blob workbook = buildResultTemplateWorkbook();
        ContentVersion cv = createTemplateVersion('export_multi_row.xlsx', workbook);

        List<List<String>> dataRows = new List<List<String>>();
        for (Integer i = 0; i < 5; i++) {
            dataRows.add(new List<String>{ 'CASE-' + String.valueOf(i), 'Subject ' + String.valueOf(i) });
        }

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = dataRows;

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
    }

    @IsTest
    static void testExportWorkbook_withMultilineData_success() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Subject' },
                new List<String>{ 'SRCH-001', 'Row 1' }
            },
            new Set<Integer>{ 1 }
        );
        ContentVersion cv = createTemplateVersion('export_multiline.xlsx', workbook);

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.templateSheetName = 'Result';
        req.headerRowIndex = 0;
        req.mappedColumnIndexes = new List<Integer>{ 0, 1 };
        req.dataRows = new List<List<String>>{
            new List<String>{ 'CASE-ML', 'Line1\nLine2 &amp; special' }
        };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
    }

    @IsTest
    static void testResolveTemplateDataRowNum_branches() {
        String withDataRow =
            '<?xml version="1.0"?><worksheet><sheetData>' +
            '<row r="5"><c r="A5" t="inlineStr"><is><t>Case ID</t></is></c></row>' +
            '<row r="6"><c r="A6" t="inlineStr"><is><t>data</t></is></c></row>' +
            '</sheetData></worksheet>';
        String headerOnly =
            '<?xml version="1.0"?><worksheet><sheetData>' +
            '<row r="3"><c r="A3" t="inlineStr"><is><t>Case ID</t></is></c></row>' +
            '</sheetData></worksheet>';

        Test.startTest();
        Integer afterHeader = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(withDataRow, 4);
        Integer fallbackHeader = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(headerOnly, 2);
        Test.stopTest();

        System.assertEquals(6, afterHeader);
        System.assertEquals(3, fallbackHeader);
    }

    @IsTest
    static void testTestVisibleXmlHelpers() {
        String mergeXml =
            '<?xml version="1.0"?><worksheet><mergeCells count="1">' +
            '<mergeCell ref="A2:B2"/><mergeCell ref="A3:A5"/>' +
            '</mergeCells><sheetData></sheetData></worksheet>';
        String sqrefXml =
            '<x14:dataValidation><xm:sqref>D3:D100 E6:E510</xm:sqref></x14:dataValidation>';
        String spansXml = '<row r="1" spans="1:5"><c r="A1"/></row>';

        Test.startTest();
        String decoded = FEC_BCH_TemplateExportService.decodeXlsxTextFragment('A&amp;B&#10;C');
        String merged = FEC_BCH_TemplateExportService.removeDataRowColumnMergeCells(mergeXml, 2, 5);
        String shiftedSqref = FEC_BCH_TemplateExportService.shiftWorksheetX14Sqrefs(sqrefXml, 3, 2);
        String shiftedSpans = FEC_BCH_TemplateExportService.shiftWorksheetRowSpans(spansXml, 2, 2);
        String cellText = FEC_BCH_TemplateExportService.cellTextAtWorksheetColumn(
            new Map<Integer, String>{ 0 => 'Case ID', 1 => 'Subject' },
            1
        );
        Test.stopTest();

        System.assert(decoded.contains('A&B'));
        System.assert(!merged.contains('A2:B2'));
        System.assert(shiftedSqref.contains('F3:F100'));
        System.assert(shiftedSpans.contains('spans="1:7"'));
        System.assertEquals('Subject', cellText);
    }

    @IsTest
    static void testExportWorkbook_replicatesImportResultArtifactFlow() {
        ContentVersion cv = new ContentVersion(
            Title = 'ArtifactFlowImport',
            PathOnClient = 'ArtifactFlowImport.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64())
        );
        insert cv;

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);

        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            parsed.headerRowIndex0,
            parsed.sheetName,
            parsed.importHeaders
        );
        System.assert(mapped.size() > 0);

        List<String> cells = new List<String>();
        for (Integer colIdx : mapped) {
            cells.add(
                FEC_BCH_TemplateExportService.readImportCellText(cv.Id, parsed.sheetName, 1, colIdx)
            );
        }
        while (cells.size() < parsed.importHeaders.size()) {
            cells.add(FEC_ConstantCommon.STR_EMPTY);
        }

        Integer remarkHeaderIdx = -1;
        for (Integer i = 0; i < parsed.importHeaders.size(); i++) {
            String header = parsed.importHeaders[i];
            if (header != null && header.toLowerCase().contains('remark')) {
                remarkHeaderIdx = i;
                break;
            }
        }
        Integer preserveCol = remarkHeaderIdx >= 0 && remarkHeaderIdx < mapped.size()
            ? mapped[remarkHeaderIdx]
            : null;

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.headerRowIndex = parsed.headerRowIndex0;
        req.mappedColumnIndexes = mapped;
        req.templateSheetName = parsed.sheetName;
        req.dataRows = new List<List<String>>{ cells };
        req.insertColumnsBeforeIndex = mapped[mapped.size() - 1] + 1;
        req.insertColumnHeaders = new List<String>{ '__Status', '__Errors' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Success', FEC_ConstantCommon.STR_EMPTY }
        };
        req.preserveSourceWorksheetColIndex = preserveCol;
        req.sourceDataRowIndexes = new List<Integer>{ 1 };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        String base64 = FEC_BCH_TemplateExportService.exportWorkbookBase64(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
        System.assertNotEquals(null, base64);
    }

    @IsTest
    static void testParseBatchImportWorkbook_cofStyleWorkbook() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-COF-001', 'Approve', 'COF import remark' }
            }
        );
        ContentVersion cv = createTemplateVersion('cof_import_parse.xlsx', workbook);

        Test.startTest();
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult result =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        Test.stopTest();

        System.assertEquals(true, result.parseSuccess, result.errorMessage);
        System.assertEquals(1, result.inputRows.size());
        Map<String, Object> row = (Map<String, Object>) result.inputRows[0];
        System.assertEquals('SRCH-COF-001', row.get('caseIdSearch'));
        System.assertEquals('Approve', row.get('routingAction'));
        System.assertEquals('COF import remark', row.get('inputtedRemarks'));
    }

    @IsTest
    static void testExportWorkbook_cofImportTemplateWithResultColumns() {
        Blob workbook = FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Routing Action', 'Inputted Remarks' },
                new List<String>{ 'SRCH-COF-002', 'Reject', 'Long remark for result export' }
            },
            new Set<Integer>{ 2 }
        );
        ContentVersion cv = createTemplateVersion('cof_result_export.xlsx', workbook);

        FEC_BCH_TemplateExportService.ImportWorkbookParseResult parsed =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(true, parsed.parseSuccess, parsed.errorMessage);

        List<Integer> mapped = FEC_BCH_TemplateExportService.resolveMappedColumnIndexesForHeaders(
            cv.Id,
            parsed.headerRowIndex0,
            parsed.sheetName,
            parsed.importHeaders
        );

        List<String> cells = new List<String>();
        for (Integer colIdx : mapped) {
            cells.add(
                FEC_BCH_TemplateExportService.readImportCellText(cv.Id, parsed.sheetName, 1, colIdx)
            );
        }

        FEC_BCH_TemplateExportService.ExportRequest req = new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = cv.Id;
        req.headerRowIndex = parsed.headerRowIndex0;
        req.mappedColumnIndexes = mapped;
        req.templateSheetName = parsed.sheetName;
        req.dataRows = new List<List<String>>{ cells };
        req.insertColumnsBeforeIndex = mapped[mapped.size() - 1] + 1;
        req.insertColumnHeaders = new List<String>{ '__Status', '__Errors' };
        req.insertColumnValues = new List<List<String>>{
            new List<String>{ 'Failed', 'Remark too long' }
        };
        req.preserveSourceWorksheetColIndex = mapped.size() > 2 ? mapped[2] : null;
        req.sourceDataRowIndexes = new List<Integer>{ 1 };

        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse resp =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();

        System.assertEquals(true, resp.success, resp.errorCode + ': ' + resp.errorMessage);
    }

    @IsTest
    static void testMatchColumnByHeaderRules_additionalBranches() {
        Map<String, String> mainHeaders = new Map<String, String>{
            'AE' => 'routingaction',
            'AF' => 'assignmentroutingaction',
            'AB' => 'cssupportdanhgiayeucau'
        };

        Test.startTest();
        String routingCol = FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
            mainHeaders,
            new List<String>{ 'routingaction' },
            new List<String>{ 'assignmentrouting' },
            false
        );
        String csSupportCol = FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
            mainHeaders,
            new List<String>{ 'cssupport', 'danhgia' },
            null,
            true
        );
        Test.stopTest();

        System.assertEquals('AE', routingCol);
        System.assertEquals('AB', csSupportCol);
    }

    private static Blob buildResultTemplateWorkbook() {
        return FEC_BatchCaseHandlingResultXlsxBuilder.buildWorkbookBlob(
            new List<List<String>>{
                new List<String>{ 'Case ID', 'Subject' },
                new List<String>{ 'SRCH-001', 'Row 1' }
            }
        );
    }

    private static String buildMinimalImportWorkbookBase64() {
        return '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';
    }
}
