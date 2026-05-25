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
    @future(callout=true)
    public static void processReportAsync(
        String reportName,
        String uniqueName,
        String reportId,
        String baseUrl,
        String today
    ) {
        try {

            String endpoint = String.format(
                FEC_ConstantCommon.REPORT_EXPORT_ENDPOINT,
                new List<String>{
                    baseUrl,
                    FEC_ConstantCommon.API_VERSION,
                    reportId
                }
            );

            Map<String,String> headers = new Map<String,String>{
                'Authorization' => 'Bearer ' + UserInfo.getSessionId(),
                'Content-Type'  => FEC_ConstantCommon.API_CONTENT_TYPE_JSON
            };

            HttpResponse res = FEC_CommonUltils.calloutApiWithHeaders(
                endpoint,
                'GET',
                headers,
                null
            );

            if (res.getStatusCode() != 200) {
                throw new CalloutException(
                    'Export failed [' + res.getStatusCode() + '] => ' + res.getBody()
                );
            }

            Map<String, Object> reportData =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

            Map<String, Object> extMeta =
                (Map<String, Object>) reportData.get('reportExtendedMetadata');

            Map<String, Object> columnMeta =
                (Map<String, Object>) extMeta.get('detailColumnInfo');

            Map<String, Object> reportMetadata =
                (Map<String, Object>) reportData.get('reportMetadata');

            List<Object> detailColumns =
                (List<Object>) reportMetadata.get('detailColumns');

            List<String> excelHeaders = new List<String>();

            for (Object col : detailColumns) {

                String colName = String.valueOf(col);

                if (columnMeta.containsKey(colName)) {
                    Map<String, Object> colInfo =
                        (Map<String, Object>) columnMeta.get(colName);
                    excelHeaders.add(String.valueOf(colInfo.get('label')));
                } else {
                    excelHeaders.add(colName);
                }
            }

            Map<String, Object> factMap =
                (Map<String, Object>) reportData.get('factMap');

            List<String> factKeys = new List<String>(factMap.keySet());
            factKeys.sort();

            List<List<String>> dataRows = new List<List<String>>();

            for (String key : factKeys) {

                if (!key.endsWith('!T')) continue;

                Map<String, Object> section =
                    (Map<String, Object>) factMap.get(key);

                if (!section.containsKey('rows')) continue;

                List<Object> rows = (List<Object>) section.get('rows');

                if (rows == null || rows.isEmpty()) continue;

                for (Object rowObj : rows) {

                    Map<String, Object> row =
                        (Map<String, Object>) rowObj;

                    List<Object> dataCells =
                        (List<Object>) row.get('dataCells');

                    if (dataCells == null) continue;

                    List<String> rowValues = new List<String>();

                    for (Object cellObj : dataCells) {

                        Map<String, Object> cell =
                            (Map<String, Object>) cellObj;

                        String label = '';

                        if (
                            cell.get('label') != null &&
                            !String.valueOf(cell.get('label')).equals('null') &&
                            !String.valueOf(cell.get('label')).equals('')
                        ) {
                            label = String.valueOf(cell.get('label'));

                        } else if (
                            cell.get('value') != null &&
                            !String.valueOf(cell.get('value')).equals('null')
                        ) {
                            label = String.valueOf(cell.get('value'));
                        }

                        label = stripHtml(label);
                        rowValues.add(label);
                    }

                    dataRows.add(rowValues);
                }
            }

            String excelContent = buildExcelXml(excelHeaders, dataRows);
            String fileName     = today.replace('/', '') + '_' + uniqueName + '.xls';

            ContentVersion cv = new ContentVersion();
            cv.Title          = today + ' - ' + reportName;
            cv.PathOnClient   = fileName;
            cv.VersionData    = Blob.valueOf(excelContent);
            cv.IsMajorVersion = true;

            insert cv;

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
    // BUILD EXCEL
    // =========================================================
    private static String buildExcelXml(List<String> headers, List<List<String>> rows) {

        String xml = '<?xml version="1.0" encoding="UTF-8"?>';
        xml += '<?mso-application progid="Excel.Sheet"?>'; // <-- thêm dòng này
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

        for (List<String> row : rows) {
            xml += '<Row>';
            for (String val : row) {
                xml += '<Cell><Data ss:Type="String">' + escapeXml(val) + '</Data></Cell>';
            }
            xml += '</Row>';
        }

        xml += '</Table></Worksheet></Workbook>';
        return xml;
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