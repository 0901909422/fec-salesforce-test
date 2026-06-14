@IsTest
private class FEC_BCH_TemplateExportServiceTest {

    @IsTest
    static void export_blankRequest_returnsErrorCode() {
        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse r1 =
            FEC_BCH_TemplateExportService.exportWorkbook(null);
        FEC_BCH_TemplateExportService.ExportWorkbookResponse r2 =
            FEC_BCH_TemplateExportService.exportWorkbook('{}');
        Test.stopTest();
        System.assertEquals(false, r1.success);
        System.assertEquals('EMPTY_REQUEST', r1.errorCode);
        System.assertEquals(false, r2.success);
    }

    @IsTest
    static void export_missingVersion_returnsInvalidRequest() {
        FEC_BCH_TemplateExportService.ExportRequest req =
            new FEC_BCH_TemplateExportService.ExportRequest();
        req.contentVersionId = null;
        req.headerRowIndex = 3;
        req.mappedColumnIndexes = new List<Integer>{ 0 };
        req.dataRows = new List<List<String>>{ new List<String>{ 'CASE-1' } };
        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse res =
            FEC_BCH_TemplateExportService.exportWorkbook(JSON.serialize(req));
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assertEquals('INVALID_REQUEST', res.errorCode);
    }

    @IsTest
    static void export_controllerDelegates() {
        Test.startTest();
        FEC_BCH_TemplateExportService.ExportWorkbookResponse res =
            FEC_BatchCaseHandlingController.exportTemplateWorkbook(null);
        Test.stopTest();
        System.assertEquals(false, res.success);
        System.assertEquals('EMPTY_REQUEST', res.errorCode);
    }

    @IsTest
    static void export_matchRoutingColumnByHeaderName() {
        Map<String, String> mainHeaders = new Map<String, String>{
            'AE' => 'routingaction',
            'AF' => 'assignmentroutingaction',
            'AH' => 'classificationbycs'
        };
        String routingCol = FEC_BCH_TemplateExportService.matchColumnByHeaderRules(
            mainHeaders,
            new List<String>{ 'routingaction' },
            new List<String>{ 'assignmentrouting' },
            false
        );
        System.assertEquals('AE', routingCol);
    }

    @IsTest
    static void export_matchAddressUpdateRoutingAndCsSupportColumns() {
        Map<String, String> mainHeaders = new Map<String, String>{
            'Z' => 'routingaction',
            'AA' => 'inputtedremarks',
            'AB' => 'cssupportdanhgiayeucau'
        };
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
        System.assertEquals('Z', routingCol);
        System.assertEquals('AB', csSupportCol);
    }

    @IsTest
    static void resolveTemplateDataRowNum_usesFirstDataRowAfterHeader() {
        String xml =
            '<?xml version="1.0"?><worksheet><sheetData>' +
            '<row r="5"><c r="A5" t="inlineStr"><is><t>Case ID</t></is></c></row>' +
            '<row r="6"><c r="A6" t="inlineStr"><is><t>data</t></is></c></row>' +
            '</sheetData></worksheet>';
        Integer rowNum = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(xml, 4);
        System.assertEquals(6, rowNum);
    }

    @IsTest
    static void resolveTemplateDataRowNum_fallsBackToHeaderRowWhenNoDataRow() {
        String xml =
            '<?xml version="1.0"?><worksheet><sheetData>' +
            '<row r="3"><c r="A3" t="inlineStr"><is><t>Case ID</t></is></c></row>' +
            '</sheetData></worksheet>';
        Integer rowNum = FEC_BCH_TemplateExportService.resolveTemplateDataRowNum(xml, 2);
        System.assertEquals(3, rowNum);
    }

    // 30/05/2026 15:10 linhdev - Result export: không dùng xml:space; xuống dòng encode &#10;
    @IsTest
    static void buildInlineCell_avoidsXmlSpaceAndEncodesNewlines() {
        String escaped = 'Err A&#10;Err B &amp; long text over forty characters here';
        String encoded = FEC_BCH_TemplateExportService.encodeInlineStrLineBreaks(
            'Err A\nErr B &amp; long text over forty characters here'
        );
        System.assertEquals(escaped, encoded);

        String cell = FEC_BCH_TemplateExportService.buildInlineCell('Z99', ' s="1"', encoded);
        System.assert(!cell.contains('xml:space'), cell);
        System.assert(cell.contains('<t>' + escaped + '</t>'), cell);
        System.assert(cell.contains('&#10;'), cell);
    }

    @IsTest
    static void buildDataValidationXml_includesXrUidPrefix() {
        String node = FEC_BCH_TemplateExportService.buildDataValidationXml(
            'Sheet1!$A$1:$A$5',
            'E6:E510',
            '{384C5710-23BE-435C-862B-000000000001}'
        );
        System.assert(node.contains('xr:uid='), node);
        System.assert(node.contains('<xm:sqref>E6:E510</xm:sqref>'), node);
    }

    // 01/06/2026 12:00 linhdev - parseBatchImportWorkbook (Apex import thay SheetJS)
    @IsTest
    static void parseBatchImportWorkbook_nullContentVersion_returnsRequireFile() {
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult res =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(null);
        System.assertEquals(false, res.parseSuccess);
        System.assertEquals(System.Label.FEC_BCH_RequireFile, res.errorMessage);
    }

    @IsTest
    static void parseBatchImportWorkbook_invalidBlob_returnsHeaderInvalid() {
        ContentVersion cv = new ContentVersion(
            Title = 'InvalidImport',
            PathOnClient = 'InvalidImport.xlsx',
            VersionData = Blob.valueOf('not-a-zip')
        );
        insert cv;
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult res =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(false, res.parseSuccess);
        System.assertEquals(System.Label.FEC_BCH_HeaderInvalid, res.errorMessage);
    }

    @IsTest
    static void parseBatchImportWorkbook_validMinimalWorkbook_parsesDataRow() {
        ContentVersion cv = new ContentVersion(
            Title = 'MinimalImport',
            PathOnClient = 'MinimalImport.xlsx',
            VersionData = EncodingUtil.base64Decode(buildMinimalImportWorkbookBase64())
        );
        insert cv;
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult res =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(true, res.parseSuccess, res.errorMessage);
        System.assertEquals(1, res.inputRows.size());
        Map<String, Object> row = (Map<String, Object>) res.inputRows[0];
        System.assertEquals('CASE-001', row.get('caseIdSearch'));
        System.assertEquals('Reject', row.get('routingAction'));
        System.assertEquals('test remark', row.get('inputtedRemarks'));
    }

    // 02/06/2026 15:25 linhdev - không drop dòng có dữ liệu gốc dù cột import trống
    @IsTest
    static void parseBatchImportWorkbook_rowWithOnlyNonImportCells_stillIncluded() {
        ContentVersion cv = new ContentVersion(
            Title = 'ImportRowRetention',
            PathOnClient = 'ImportRowRetention.xlsx',
            VersionData = EncodingUtil.base64Decode(buildImportWorkbookBase64_WithNonImportOnlyRow())
        );
        insert cv;
        FEC_BCH_TemplateExportService.ImportWorkbookParseResult res =
            FEC_BCH_TemplateExportService.parseBatchImportWorkbook(cv.Id);
        System.assertEquals(true, res.parseSuccess, res.errorMessage);
        System.assertEquals(2, res.inputRows.size());
        Map<String, Object> rowWithBlankImportCols = (Map<String, Object>) res.inputRows[1];
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, (String) rowWithBlankImportCols.get('caseIdSearch'));
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, (String) rowWithBlankImportCols.get('routingAction'));
        System.assertEquals(FEC_ConstantCommon.STR_EMPTY, (String) rowWithBlankImportCols.get('inputtedRemarks'));
    }

    @IsTest
    static void mergeInsertColumnValues_insertsAtLogicalEnd_notWorksheetColumnIndex() {
        List<List<String>> dataRows = new List<List<String>>();
        List<String> row = new List<String>();
        for (Integer i = 0; i < 24; i++) {
            row.add('c' + String.valueOf(i));
        }
        row[21] = 'ROUTING';
        row[22] = 'REMARK_LONG';
        dataRows.add(row);
        List<List<String>> insertValues = new List<List<String>>{
            new List<String>{ 'Failed', 'Remark too long' }
        };
        Integer logicalWidth = FEC_BCH_TemplateExportService.resolveDataRowsLogicalWidth(dataRows);
        System.assertEquals(24, logicalWidth);
        List<List<String>> merged = FEC_BCH_TemplateExportService.mergeInsertColumnValues(
            dataRows,
            insertValues,
            2,
            logicalWidth
        );
        System.assertEquals(1, merged.size());
        System.assertEquals(26, merged[0].size());
        System.assertEquals('ROUTING', merged[0][21]);
        System.assertEquals('REMARK_LONG', merged[0][22]);
        System.assertEquals('Failed', merged[0][24]);
        System.assertEquals('Remark too long', merged[0][25]);
        List<List<String>> misaligned = FEC_BCH_TemplateExportService.mergeInsertColumnValues(
            dataRows,
            insertValues,
            2,
            22
        );
        System.assertEquals('Failed', misaligned[0][22]);
        System.assertEquals('REMARK_LONG', misaligned[0][24]);
    }

    @IsTest
    static void shiftMappedColumnIndexes_preservesValueColumnOrder() {
        List<Integer> mapped = new List<Integer>();
        for (Integer i = 0; i < 35; i++) {
            mapped.add(i);
        }
        List<Integer> shifted = FEC_BCH_TemplateExportService.shiftMappedColumnIndexes(mapped, 8, 2);
        System.assertEquals(37, shifted.size());
        System.assertEquals(0, shifted[0]);
        System.assertEquals(7, shifted[7]);
        System.assertEquals(10, shifted[8]);
        System.assertEquals(21, shifted[19]);
        System.assertEquals(36, shifted[34]);
        System.assertEquals(8, shifted[35]);
        System.assertEquals(9, shifted[36]);
        List<Integer> shiftedEnd = FEC_BCH_TemplateExportService.shiftMappedColumnIndexes(mapped, 35, 2);
        System.assertEquals(37, shiftedEnd.size());
        System.assertEquals(34, shiftedEnd[34]);
        System.assertEquals(35, shiftedEnd[35]);
        System.assertEquals(36, shiftedEnd[36]);
    }

    // 13/06/2026 00:30 linhdev - row 1: V1/W1 (Ghi chú/Mandatory) phải dịch sang Z1/AA1 khi chèn Property
    @IsTest
    static void shiftAllSheetDataRowsUpTo_shiftsNoteCellsOnRow1() {
        String row1 =
            '<row r="1"><c r="U1" s="12"/><c r="V1" s="14"/><c r="W1" s="16" t="s"><v>1</v></c><c r="X1" s="14" t="s"><v>2</v></c></row>';
        String xml = '<sheetData>' + row1 + '</sheetData>';
        Test.startTest();
        String out = FEC_BCH_TemplateExportService.shiftAllSheetDataRowsUpTo(xml, 1, 21, 4);
        Test.stopTest();
        System.assert(out.contains('r="Z1"'), 'V1 phải dịch sang Z1');
        System.assert(out.contains('r="AA1"'), 'W1 (Ghi chú) phải dịch sang AA1');
        System.assert(out.contains('r="AB1"'), 'X1 (Mandatory) phải dịch sang AB1');
        System.assert(!out.contains('r="V1"'), 'V1 cũ không được giữ');
        System.assert(!out.contains('r="W1"'), 'W1 cũ không được giữ');
    }

    @TestVisible
    private static String buildMinimalImportWorkbookBase64() {
        return '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';
    }

    @TestVisible
    private static String buildImportWorkbookBase64_WithNonImportOnlyRow() {
        return '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';
    }
}