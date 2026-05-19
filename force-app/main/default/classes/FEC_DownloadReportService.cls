public without sharing class FEC_DownloadReportService {


    public static void generateDailyReports() {

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today   = Date.today().format();

        for (Map<String, String> config : FEC_ConstantCommon.REPORT_CONFIGS) {

            try {

                List<Report> reports = [
                    SELECT Id 
                    FROM Report 
                    WHERE DeveloperName = :config.get('uniqueName')
                    LIMIT 1
                ];

                if (reports.isEmpty()) {
                    continue;
                }

                config.put('reportId', String.valueOf(reports[0].Id));
                processReport(config, baseUrl, today);

            } catch (Exception e) {
                System.debug('ERROR [' + config.get('name') + '] => ' + e.getMessage());
            }
        }
    }

    // =========================================================
    // PROCESS REPORT
    // =========================================================
    private static void processReport(
        Map<String, String> config,
        String baseUrl,
        String today
    ) {

        String reportId   = config.get('reportId');
        String reportName = config.get('name');
        String uniqueName = config.get('uniqueName');

        String endpoint =
            baseUrl +
            '/services/data/' + FEC_ConstantCommon.API_VERSION +
            '/analytics/reports/' + reportId +
            '?includeDetails=true';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);

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

        List<String> headers = new List<String>();

        for (Object col : detailColumns) {

            String colName = String.valueOf(col);

            if (columnMeta.containsKey(colName)) {
                Map<String, Object> colInfo =
                    (Map<String, Object>) columnMeta.get(colName);
                headers.add(String.valueOf(colInfo.get('label')));
            } else {
                headers.add(colName);
            }
        }

        List<String> csvLines = new List<String>();
        csvLines.add('\uFEFFsep=,');
        csvLines.add(buildCsvRow(headers));

        Map<String, Object> factMap =
            (Map<String, Object>) reportData.get('factMap');

        List<String> factKeys = new List<String>(factMap.keySet());
        factKeys.sort();

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

                    if (cell.get('label') != null &&
                        !String.valueOf(cell.get('label')).equals('null') &&
                        !String.valueOf(cell.get('label')).equals('')
                    ) {
                        label = String.valueOf(cell.get('label'));

                    } else if (cell.get('value') != null &&
                        !String.valueOf(cell.get('value')).equals('null')
                    ) {
                        label = String.valueOf(cell.get('value'));
                    }

                    rowValues.add(label);
                }

                csvLines.add(buildCsvRow(rowValues));
            }
        }

        String csvContent = String.join(csvLines, '\n');

        String fileName = today.replace('/', '') + '_' + uniqueName + '.csv';

        ContentVersion cv  = new ContentVersion();
        cv.Title           = today + ' - ' + reportName;
        cv.PathOnClient    = fileName;
        cv.VersionData     = Blob.valueOf(csvContent);
        cv.IsMajorVersion  = true;

        insert cv;

        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        String fileLink =
            baseUrl +
            '/sfc/servlet.shepherd/document/download/' +
            cv.ContentDocumentId;

        List<Download_Report__c> existing =
            [
                SELECT Id
                FROM Download_Report__c
                WHERE FEC_Report_Unique_Name__c = :uniqueName
                AND Name LIKE :(today + '%')
                LIMIT 1
            ];

        if (!existing.isEmpty()) {

            existing[0].FEC_Link__c = fileLink;
            update existing[0];

        } else {

            Download_Report__c rec          = new Download_Report__c();
            rec.Name                        = today + ' - ' + reportName;
            rec.FEC_Report_Unique_Name__c   = uniqueName;
            rec.FEC_Link__c                 = fileLink;

            insert rec;
        }
    }

    private static String buildCsvRow(List<String> values) {
        List<String> escaped = new List<String>();
        for (String val : values) {
            if (val == null) val = '';
            val = val.replace('"', '""');
            if (val.contains(',') || val.contains('\n') || val.contains('"')) {
                val = '"' + val + '"';
            }

            escaped.add(val);
        }

        return String.join(escaped, ',');
    }
}