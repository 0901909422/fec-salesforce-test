/****************************************************************************************
* File Name    : FEC_DownloadReportService
* Author       : Quangdv7
* Date         : 2026-05-20
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-05-20    Quangdv7             Create
 
****************************************************************************************/

public without sharing class FEC_DownloadReportService {

    public static void generateDailyReports() {

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today   = Date.today().format();

        for (Map<String, String> config : FEC_ConstantCommon.REPORT_CONFIGS) {

            String name       = config.get('name');
            String uniqueName = config.get('uniqueName');

            try {

                List<Report> reports = [
                    SELECT Id
                    FROM Report
                    WHERE DeveloperName = :uniqueName
                    LIMIT 1
                ];

                if (reports.isEmpty()) {
                    continue;
                }

                processReportAsync(
                    name,
                    uniqueName,
                    String.valueOf(reports[0].Id),
                    baseUrl,
                    today
                );

            } catch (Exception e) {
                System.debug(e.getMessage());
            }
        }
    }

    // =========================================================
    // FUTURE METHOD
    // =========================================================
    @future
    public static void processReportAsync(
        String reportName,
        String uniqueName,
        String reportId,
        String baseUrl,
        String today
    ) {
        try {

            Reports.ReportResults results =
                Reports.ReportManager.runReport((Id) reportId, true);

            List<String> excelHeaders = buildExcelHeaders(results);

            List<String> sheetRowParts = new List<String>();
            sheetRowParts.add(buildOoxmlHeaderRow(excelHeaders));
            appendReportRowsOoxml(results, sheetRowParts);

            results = null;

            Blob xlsxBlob = buildXlsxBlob(sheetRowParts);
            sheetRowParts = null;

            String fileName = today.replace('/', '') + '_' + uniqueName + '.xlsx';

            List<FEC_Download_Report__c> existing = [
                SELECT Id
                FROM FEC_Download_Report__c
                WHERE FEC_Report_Unique_Name__c = :uniqueName
                AND Name LIKE :(today + '%')
                LIMIT 1
            ];

            Id reportRecordId;
            if (!existing.isEmpty()) {
                reportRecordId = existing[0].Id;
            } else {
                FEC_Download_Report__c rec = new FEC_Download_Report__c();
                rec.Name = today + ' - ' + reportName;
                rec.FEC_Report_Unique_Name__c = uniqueName;
                insert rec;
                reportRecordId = rec.Id;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = today + ' - ' + reportName;
            cv.PathOnClient = fileName;
            cv.VersionData = xlsxBlob;
            cv.IsMajorVersion = true;
            cv.FirstPublishLocationId = reportRecordId;
            insert cv;

            xlsxBlob = null;

            cv = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            String fileLink = String.format(
                FEC_ConstantCommon.CONTENT_DOWNLOAD_ENDPOINT,
                new List<String>{
                    baseUrl,
                    cv.ContentDocumentId
                }
            );

            update new FEC_Download_Report__c(
                Id = reportRecordId,
                FEC_Link__c = fileLink
            );

        } catch (Exception e) {
            System.debug(e.getMessage());
        }
    }

    // =========================================================
    // REPORT DATA
    // =========================================================
    private static List<String> buildExcelHeaders(Reports.ReportResults results) {

        List<String> excelHeaders = new List<String>();
        List<String> detailColumns =
            results.getReportMetadata().getDetailColumns();

        Map<String, Reports.DetailColumn> columnMeta =
            results.getReportExtendedMetadata().getDetailColumnInfo();

        for (String colName : detailColumns) {

            if (columnMeta != null && columnMeta.containsKey(colName)) {
                excelHeaders.add(columnMeta.get(colName).getLabel());
            } else {
                excelHeaders.add(colName);
            }
        }

        return excelHeaders;
    }

    private static void appendReportRowsOoxml(
        Reports.ReportResults results,
        List<String> sheetRowParts
    ) {
        Map<String, Reports.ReportFact> factMap = results.getFactMap();
        List<String> factKeys = new List<String>(factMap.keySet());
        factKeys.sort();

        Integer rowNum = 2;

        for (String key : factKeys) {

            if (!key.endsWith('!T')) {
                continue;
            }

            Reports.ReportFact fact = factMap.get(key);

            if (!(fact instanceof Reports.ReportFactWithDetails)) {
                continue;
            }

            Reports.ReportFactWithDetails section =
                (Reports.ReportFactWithDetails) fact;

            if (section.getRows() == null || section.getRows().isEmpty()) {
                continue;
            }

            for (Reports.ReportDetailRow row : section.getRows()) {
                String rowXml = buildOoxmlDataRow(rowNum, row);
                if (String.isNotBlank(rowXml)) {
                    sheetRowParts.add(rowXml);
                    rowNum++;
                }
            }
        }
    }

    private static String resolveCellLabel(Reports.ReportDataCell cell) {

        String label = '';

        if (
            cell.getLabel() != null &&
            String.isNotBlank(String.valueOf(cell.getLabel())) &&
            !String.valueOf(cell.getLabel()).equals('null')
        ) {
            label = String.valueOf(cell.getLabel());

        } else if (
            cell.getValue() != null &&
            !String.valueOf(cell.getValue()).equals('null')
        ) {
            label = String.valueOf(cell.getValue());
        }

        return stripHtml(label);
    }

    // =========================================================
    // BUILD XLSX (Office Open XML)
    // =========================================================
    private static Blob buildXlsxBlob(List<String> sheetRowParts) {

        String sheetXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
            '<sheetData>' + String.join(sheetRowParts, '') + '</sheetData>' +
            '</worksheet>';

        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry('[Content_Types].xml', Blob.valueOf(buildContentTypesXml()));
        writer.addEntry('_rels/.rels', Blob.valueOf(buildRootRelsXml()));
        writer.addEntry('xl/workbook.xml', Blob.valueOf(buildWorkbookXml()));
        writer.addEntry('xl/_rels/workbook.xml.rels', Blob.valueOf(buildWorkbookRelsXml()));
        writer.addEntry('xl/styles.xml', Blob.valueOf(buildStylesXml()));
        writer.addEntry('xl/worksheets/sheet1.xml', Blob.valueOf(sheetXml));

        return writer.getArchive();
    }

    private static String buildContentTypesXml() {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
            '</Types>';
    }

    private static String buildRootRelsXml() {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
            '</Relationships>';
    }

    private static String buildWorkbookXml() {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<sheets><sheet name="Report" sheetId="1" r:id="rId1"/></sheets>' +
            '</workbook>';
    }

    private static String buildWorkbookRelsXml() {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
            '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
            '</Relationships>';
    }

    private static String buildStylesXml() {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
            '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>' +
            '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' +
            '<borders count="1"><border/></borders>' +
            '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellXfs>' +
            '</styleSheet>';
    }

    private static String buildOoxmlHeaderRow(List<String> headers) {
        List<String> cells = new List<String>();
        for (Integer i = 0; i < headers.size(); i++) {
            cells.add(buildOoxmlCell(1, i, headers[i]));
        }
        return '<row r="1">' + String.join(cells, '') + '</row>';
    }

    private static String buildOoxmlDataRow(Integer rowNum, Reports.ReportDetailRow row) {

        List<Reports.ReportDataCell> dataCells = row.getDataCells();

        if (dataCells == null || dataCells.isEmpty()) {
            return '';
        }

        List<String> cells = new List<String>();
        for (Integer i = 0; i < dataCells.size(); i++) {
            cells.add(buildOoxmlCell(rowNum, i, resolveCellLabel(dataCells[i])));
        }

        return '<row r="' + rowNum + '">' + String.join(cells, '') + '</row>';
    }

    private static String buildOoxmlCell(Integer rowNum, Integer colIndex, String value) {
        String cellRef = columnLetter(colIndex) + String.valueOf(rowNum);
        return '<c r="' + cellRef + '" t="inlineStr"><is><t>' +
            escapeXml(value) +
            '</t></is></c>';
    }

    private static String columnLetter(Integer colIndex) {
        String letters = '';
        Integer idx = colIndex;
        while (idx >= 0) {
            letters = String.fromCharArray(new List<Integer>{ 65 + Math.mod(idx, 26) }) + letters;
            idx = (idx / 26) - 1;
        }
        return letters;
    }

    // =========================================================
    // ESCAPE XML
    // =========================================================
    private static String escapeXml(String val) {

        if (String.isBlank(val)) return '';

        return val
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }

    // =========================================================
    // STRIP HTML
    // =========================================================
    private static String stripHtml(String val) {

        if (String.isBlank(val)) return '';

        return val.replaceAll('<[^>]+>', '').trim();
    }
}
