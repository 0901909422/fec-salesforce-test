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
}