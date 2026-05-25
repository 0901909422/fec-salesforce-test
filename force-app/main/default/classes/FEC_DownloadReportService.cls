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

            List<String> xmlParts = new List<String>();
            xmlParts.add(buildExcelXmlStart(excelHeaders));
            appendReportRowsXml(results, xmlParts);
            xmlParts.add(buildExcelXmlEnd());

            results = null;

            String excelContent = String.join(xmlParts, '');
            xmlParts = null;

            String fileName = today.replace('/', '') + '_' + uniqueName + '.xls';

            ContentVersion cv = new ContentVersion();
            cv.Title          = today + ' - ' + reportName;
            cv.PathOnClient   = fileName;
            cv.VersionData    = Blob.valueOf(excelContent);
            cv.IsMajorVersion = true;

            insert cv;

            excelContent = null;

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

            List<FEC_Download_Report__c> existing = [
                SELECT Id
                FROM FEC_Download_Report__c
                WHERE FEC_Report_Unique_Name__c = :uniqueName
                AND Name LIKE :(today + '%')
                LIMIT 1
            ];

            if (!existing.isEmpty()) {

                existing[0].FEC_Link__c = fileLink;
                update existing[0];

            } else {

                FEC_Download_Report__c rec    = new FEC_Download_Report__c();
                rec.Name                      = today + ' - ' + reportName;
                rec.FEC_Report_Unique_Name__c = uniqueName;
                rec.FEC_Link__c               = fileLink;

                insert rec;
            }

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

    private static void appendReportRowsXml(
        Reports.ReportResults results,
        List<String> xmlParts
    ) {
        Map<String, Reports.ReportFact> factMap = results.getFactMap();
        List<String> factKeys = new List<String>(factMap.keySet());
        factKeys.sort();

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
                xmlParts.add(buildExcelRowXml(row));
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
    // BUILD EXCEL
    // =========================================================
    private static String buildExcelXmlStart(List<String> headers) {

        String xml = '<?xml version="1.0" encoding="UTF-8"?>';
        xml += '<?mso-application progid="Excel.Sheet"?>';
        xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"';
        xml += ' xmlns:o="urn:schemas-microsoft-com:office:office"';
        xml += ' xmlns:x="urn:schemas-microsoft-com:office:excel"';
        xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">';
        xml += '<Worksheet ss:Name="Report"><Table>';
        xml += '<Row>';

        for (String h : headers) {
            xml += '<Cell><Data ss:Type="String">' + escapeXml(h) + '</Data></Cell>';
        }

        xml += '</Row>';
        return xml;
    }

    private static String buildExcelRowXml(Reports.ReportDetailRow row) {

        List<Reports.ReportDataCell> dataCells = row.getDataCells();

        if (dataCells == null || dataCells.isEmpty()) {
            return '';
        }

        String xml = '<Row>';

        for (Reports.ReportDataCell cell : dataCells) {
            xml += '<Cell><Data ss:Type="String">' +
                escapeXml(resolveCellLabel(cell)) +
                '</Data></Cell>';
        }

        xml += '</Row>';
        return xml;
    }

    private static String buildExcelXmlEnd() {
        return '</Table></Worksheet></Workbook>';
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
