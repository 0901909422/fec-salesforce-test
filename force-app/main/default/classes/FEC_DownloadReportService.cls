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
        String today   = formatReportDate(Date.today().addDays(-1));

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
                runReportWithReportIdFields((Id) reportId);

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
    // REPORT RUN 
    // =========================================================
    @TestVisible
    private static Reports.ReportResults runReportWithReportIdFields(Id reportId) {
        Reports.ReportDescribeResult describeResult =
            Reports.ReportManager.describeReport(reportId);
        Reports.ReportMetadata reportMetadata = describeResult.getReportMetadata();

        List<String> detailColumns = reportMetadata.getDetailColumns();
        List<String> reportColumns = ensureReportIdColumns(detailColumns);

        if (!detailColumns.equals(reportColumns)) {
            reportMetadata.setDetailColumns(reportColumns);
            return Reports.ReportManager.runReport(reportId, reportMetadata, true);
        }

        return Reports.ReportManager.runReport(reportId, true);
    }

    @TestVisible
    private static List<String> ensureReportIdColumns(List<String> detailColumns) {
        List<String> result = swapToReportIdColumns(detailColumns);
        String prefix = resolveCaseColumnPrefix(detailColumns);

        if (!hasColumnEndingWith(result, 'FEC_Interaction_ID_Report__c')) {
            result.add(0, prefix + 'FEC_Interaction_ID_Report__c');
        }

        if (!hasColumnEndingWith(result, 'FEC_Case_ID_Report__c')) {
            result.add(findCaseIdInsertIndex(result), prefix + 'FEC_Case_ID_Report__c');
        }

        return result;
    }

    @TestVisible
    private static String resolveCaseColumnPrefix(List<String> columns) {
        for (String column : columns) {
            Integer dotIndex = column.indexOf('.');
            if (dotIndex > 0) {
                return column.substring(0, dotIndex + 1);
            }
        }
        return 'Case.';
    }

    @TestVisible
    private static Boolean hasColumnEndingWith(List<String> columns, String suffix) {
        for (String column : columns) {
            if (column.endsWith(suffix)) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private static Integer findCaseIdInsertIndex(List<String> columns) {
        for (Integer i = 0; i < columns.size(); i++) {
            String lowerCol = columns[i].toLowerCase();
            if (
                lowerCol.contains('case_status') ||
                lowerCol.endsWith('fec_case_status__c')
            ) {
                return i;
            }
        }

        for (Integer i = 0; i < columns.size(); i++) {
            if (columns[i].endsWith('FEC_Interaction_ID_Report__c')) {
                Integer nextIndex = i + 1;
                return nextIndex < columns.size() ? nextIndex : columns.size();
            }
        }

        return columns.size();
    }

    @TestVisible
    private static List<String> swapToReportIdColumns(List<String> detailColumns) {
        List<String> result = new List<String>();
        for (String column : detailColumns) {
            result.add(swapColumnToReportField(column));
        }
        return result;
    }

    @TestVisible
    private static String swapColumnToReportField(String column) {
        if (
            column.endsWith('FEC_Case_ID__c') &&
            !column.contains('FEC_Case_ID_Report__c')
        ) {
            return column.replace('FEC_Case_ID__c', 'FEC_Case_ID_Report__c');
        }
        if (
            column.endsWith('FEC_Interaction_ID__c') &&
            !column.contains('FEC_Interaction_ID_Report__c')
        ) {
            return column.replace('FEC_Interaction_ID__c', 'FEC_Interaction_ID_Report__c');
        }
        return column;
    }

    // =========================================================
    // REPORT DATA
    // =========================================================
    @TestVisible
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

    @TestVisible
    private static void appendReportRowsOoxml(
        Reports.ReportResults results,
        List<String> sheetRowParts
    ) {
        List<String> detailColumns =
            results.getReportMetadata().getDetailColumns();
        Map<String, Reports.DetailColumn> columnMeta =
            results.getReportExtendedMetadata().getDetailColumnInfo();

        List<String> columnDataTypes = new List<String>();
        List<String> columnLabels = new List<String>();
        for (String colName : detailColumns) {
            String dataType = null;
            String colLabel = colName;
            if (columnMeta != null && columnMeta.containsKey(colName)) {
                Reports.DetailColumn col = columnMeta.get(colName);
                dataType = col.getDataType() != null
                    ? String.valueOf(col.getDataType())
                    : null;
                colLabel = col.getLabel();
            }
            columnDataTypes.add(dataType);
            columnLabels.add(colLabel);
        }

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
                String rowXml = buildOoxmlDataRow(
                    rowNum,
                    row,
                    columnDataTypes,
                    columnLabels,
                    detailColumns
                );
                if (String.isNotBlank(rowXml)) {
                    sheetRowParts.add(rowXml);
                    rowNum++;
                }
            }
        }
    }

    private static final Set<String> DATETIME_COLUMN_LABELS = new Set<String>{
        'Interaction Created On',
        'Last Updated On',
        'Case Created On',
        'Submitted On',
        'Assigned On'
    };

    @TestVisible
    private static String resolveCellLabel(
        Reports.ReportDataCell cell,
        String dataType,
        String columnLabel,
        String columnName
    ) {
        if (cell == null) {
            return '';
        }

        Object value = cell.getValue();
        if (value instanceof DateTime) {
            return ((DateTime) value).format('dd/MM/yyyy, HH:mm');
        }

        String label = extractCellText(cell);
        label = stripHtml(label);

        if (!shouldFormatAsDateTime(dataType, columnLabel, columnName)) {
            return label;
        }

        String formatted = formatDateTimeString(label);
        return String.isNotBlank(formatted) ? formatted : label;
    }

    @TestVisible
    private static String extractCellText(Reports.ReportDataCell cell) {
        if (
            cell.getLabel() != null &&
            String.isNotBlank(String.valueOf(cell.getLabel())) &&
            !String.valueOf(cell.getLabel()).equals('null')
        ) {
            return String.valueOf(cell.getLabel());
        }
        if (
            cell.getValue() != null &&
            !String.valueOf(cell.getValue()).equals('null')
        ) {
            return String.valueOf(cell.getValue());
        }
        return '';
    }

    @TestVisible
    private static Boolean shouldFormatAsDateTime(
        String dataType,
        String columnLabel,
        String columnName
    ) {
        if (String.isNotBlank(dataType) && dataType.equalsIgnoreCase('datetime')) {
            return true;
        }
        if (String.isNotBlank(columnLabel) && DATETIME_COLUMN_LABELS.contains(columnLabel)) {
            return true;
        }
        if (String.isNotBlank(columnName)) {
            String lowerName = columnName.toLowerCase();
            if (
                lowerName.contains('created_on') ||
                lowerName.contains('updated_on') ||
                lowerName.contains('submitted_on') ||
                lowerName.contains('assigned_on') ||
                lowerName.contains('last_updated')
            ) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private static String formatDateTimeString(String label) {
        if (String.isBlank(label)) {
            return null;
        }

        String trimmed = label.trim();

        if (Pattern.compile('^\\d{2}/\\d{2}/\\d{4}, \\d{2}:\\d{2}$').matcher(trimmed).matches()) {
            return trimmed;
        }

        if (Pattern.compile('^\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}$').matcher(trimmed).matches()) {
            return trimmed.replace(' ', ', ');
        }

        Matcher ddmmMatch = Pattern.compile(
            '^(\\d{1,2})/(\\d{1,2})/(\\d{4}),?\\s+(\\d{1,2}):(\\d{2})$'
        ).matcher(trimmed);
        if (ddmmMatch.matches()) {
            Integer firstPart = Integer.valueOf(ddmmMatch.group(1));
            Integer secondPart = Integer.valueOf(ddmmMatch.group(2));
            Integer year = Integer.valueOf(ddmmMatch.group(3));
            Integer hour = Integer.valueOf(ddmmMatch.group(4));
            Integer minute = Integer.valueOf(ddmmMatch.group(5));

            Integer day;
            Integer month;
            if (firstPart > 12) {
                day = firstPart;
                month = secondPart;
            } else if (secondPart > 12) {
                month = firstPart;
                day = secondPart;
            } else {
                day = secondPart;
                month = firstPart;
            }

            return pad2(day) + '/' + pad2(month) + '/' + year + ', ' +
                pad2(hour) + ':' + pad2(minute);
        }

        Matcher us12Match = Pattern.compile(
            '^(\\d{1,2})/(\\d{1,2})/(\\d{4}),?\\s+(\\d{1,2}):(\\d{2})\\s*(AM|PM)$'
        ).matcher(trimmed.toUpperCase());
        if (us12Match.matches()) {
            Integer month = Integer.valueOf(us12Match.group(1));
            Integer day = Integer.valueOf(us12Match.group(2));
            Integer year = Integer.valueOf(us12Match.group(3));
            Integer hour = Integer.valueOf(us12Match.group(4));
            Integer minute = Integer.valueOf(us12Match.group(5));
            String ampm = us12Match.group(6);

            if (ampm.equalsIgnoreCase('PM') && hour != 12) {
                hour += 12;
            } else if (ampm.equalsIgnoreCase('AM') && hour == 12) {
                hour = 0;
            }

            return pad2(day) + '/' + pad2(month) + '/' + year + ', ' +
                pad2(hour) + ':' + pad2(minute);
        }

        return null;
    }

    @TestVisible
    private static String formatReportDate(Date reportDate) {
        return DateTime.newInstance(
            reportDate.year(),
            reportDate.month(),
            reportDate.day()
        ).format(FEC_ConstantCommon.DATE_FORMAT_DDMMYYYY);
    }

    @TestVisible
    private static String pad2(Integer val) {
        return val < 10 ? '0' + String.valueOf(val) : String.valueOf(val);
    }

    @TestVisible
    private static String resolveCellLabel(Reports.ReportDataCell cell) {
        return resolveCellLabel(cell, null, null, null);
    }

    // =========================================================
    // BUILD XLSX (Office Open XML)
    // =========================================================
    @TestVisible
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

    @TestVisible
    private static String buildOoxmlHeaderRow(List<String> headers) {
        List<String> cells = new List<String>();
        for (Integer i = 0; i < headers.size(); i++) {
            cells.add(buildOoxmlCell(1, i, headers[i]));
        }
        return '<row r="1">' + String.join(cells, '') + '</row>';
    }

    @TestVisible
    private static String buildOoxmlDataRow(
        Integer rowNum,
        Reports.ReportDetailRow row,
        List<String> columnDataTypes,
        List<String> columnLabels,
        List<String> columnNames
    ) {

        List<Reports.ReportDataCell> dataCells = row.getDataCells();

        if (dataCells == null || dataCells.isEmpty()) {
            return '';
        }

        List<String> cells = new List<String>();
        for (Integer i = 0; i < dataCells.size(); i++) {
            String dataType = i < columnDataTypes.size() ? columnDataTypes[i] : null;
            String columnLabel = i < columnLabels.size() ? columnLabels[i] : null;
            String columnName = i < columnNames.size() ? columnNames[i] : null;
            cells.add(buildOoxmlCell(
                rowNum,
                i,
                resolveCellLabel(dataCells[i], dataType, columnLabel, columnName)
            ));
        }

        return '<row r="' + rowNum + '">' + String.join(cells, '') + '</row>';
    }

    @TestVisible
    private static String buildOoxmlCell(Integer rowNum, Integer colIndex, String value) {
        String cellRef = columnLetter(colIndex) + String.valueOf(rowNum);
        return '<c r="' + cellRef + '" t="inlineStr"><is><t>' +
            escapeXml(value) +
            '</t></is></c>';
    }

    @TestVisible
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
    @TestVisible
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
    @TestVisible
    private static String stripHtml(String val) {

        if (String.isBlank(val)) return '';

        return val.replaceAll('<[^>]+>', '').trim();
    }
}
