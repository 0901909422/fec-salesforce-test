@IsTest
private class FEC_DownloadReportService_Test {

    private static Report findReportForTest() {
        Set<String> configuredNames = new Set<String>();
        for (Map<String, String> config : FEC_ConstantCommon.REPORT_CONFIGS) {
            configuredNames.add(config.get('uniqueName'));
        }

        List<Report> configuredReports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :configuredNames
            LIMIT 1
        ];
        if (!configuredReports.isEmpty()) {
            return configuredReports[0];
        }

        List<Report> anyReports = [SELECT Id, DeveloperName FROM Report LIMIT 1];
        return anyReports.isEmpty() ? null : anyReports[0];
    }

    @IsTest
    static void testGenerateDailyReports_doesNotThrow() {
        Test.startTest();
        FEC_DownloadReportService.generateDailyReports();
        Test.stopTest();

        System.assert(true, 'generateDailyReports should complete without throwing.');
    }

    @IsTest
    static void testProcessReportAsync_invalidReportId_swallowsException() {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = Date.today().format();

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Test Report',
            'FEC_RP_TEST_' + String.valueOf(System.currentTimeMillis()),
            UserInfo.getUserId(),
            baseUrl,
            today
        );
        Test.stopTest();

        System.assert(true, 'processReportAsync should catch errors for invalid report id.');
    }

    @IsTest
    static void testProcessReportAsync_createsDownloadRecord() {
        Report reportRec = findReportForTest();
        System.assertNotEquals(null, reportRec, 'Org must have at least one Report.');

        String uniqueName = reportRec.DeveloperName;
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = Date.today().format();

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Unit Test Report',
            uniqueName,
            String.valueOf(reportRec.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        List<FEC_Download_Report__c> created = [
            SELECT FEC_Link__c
            FROM FEC_Download_Report__c
            WHERE FEC_Report_Unique_Name__c = :uniqueName
              AND Name LIKE :(today + '%')
            LIMIT 1
        ];
        System.assert(!created.isEmpty(), 'Should create FEC_Download_Report__c.');
        System.assertNotEquals(null, created[0].FEC_Link__c, 'FEC_Link__c should be populated.');
    }

    @IsTest
    static void testProcessReportAsync_updatesExistingRecord() {
        Report reportRec = findReportForTest();
        System.assertNotEquals(null, reportRec, 'Org must have at least one Report.');

        String uniqueName = reportRec.DeveloperName;
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = Date.today().format();

        FEC_Download_Report__c existing = new FEC_Download_Report__c(
            Name = today + ' - Existing Report',
            FEC_Report_Unique_Name__c = uniqueName
        );
        insert existing;

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Unit Test Report Existing',
            uniqueName,
            String.valueOf(reportRec.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        FEC_Download_Report__c updated = [
            SELECT FEC_Link__c
            FROM FEC_Download_Report__c
            WHERE Id = :existing.Id
        ];
        System.assertNotEquals(null, updated.FEC_Link__c);
    }

    @IsTest
    static void testReportDataProcessing_withLiveReport() {
        Report reportRec = findReportForTest();
        System.assertNotEquals(null, reportRec, 'Org must have at least one Report for coverage.');

        Reports.ReportResults results =
            Reports.ReportManager.runReport(reportRec.Id, true);

        List<String> headers = FEC_DownloadReportService.buildExcelHeaders(results);
        System.assert(!headers.isEmpty(), 'Report should expose detail columns.');

        List<String> sheetRowParts = new List<String>();
        sheetRowParts.add(FEC_DownloadReportService.buildOoxmlHeaderRow(headers));
        FEC_DownloadReportService.appendReportRowsOoxml(results, sheetRowParts);

        Blob xlsx = FEC_DownloadReportService.buildXlsxBlob(sheetRowParts);
        System.assertNotEquals(null, xlsx);
        System.assert(xlsx.size() > 0);

        Map<String, Reports.ReportFact> factMap = results.getFactMap();
        for (String key : factMap.keySet()) {
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
            Reports.ReportDetailRow row = section.getRows()[0];
            List<Reports.ReportDataCell> cells = row.getDataCells();
            if (cells != null && !cells.isEmpty()) {
                System.assertNotEquals(
                    null,
                    FEC_DownloadReportService.resolveCellLabel(cells[0])
                );
                System.assertNotEquals(
                    '',
                    FEC_DownloadReportService.buildOoxmlDataRow(2, row)
                );
            }
            break;
        }
    }

    @IsTest
    static void testBuildOoxmlCell() {
        String cellXml = FEC_DownloadReportService.buildOoxmlCell(3, 2, 'Test &amp; Value');
        System.assert(cellXml.contains('r="C3"'));
        System.assert(cellXml.contains('Test &amp;amp; Value'));
    }

    @IsTest
    static void testEscapeXml_andStripHtml() {
        System.assertEquals('', FEC_DownloadReportService.escapeXml(null));
        System.assertEquals(
            'A&amp;B&lt;C&gt;&quot;D&apos;E',
            FEC_DownloadReportService.escapeXml('A&B<C>"D\'E')
        );
        System.assertEquals('', FEC_DownloadReportService.stripHtml(null));
        System.assertEquals(
            'Hello World',
            FEC_DownloadReportService.stripHtml('<b>Hello</b> <span>World</span>')
        );
    }

    @IsTest
    static void testColumnLetter() {
        System.assertEquals('A', FEC_DownloadReportService.columnLetter(0));
        System.assertEquals('Z', FEC_DownloadReportService.columnLetter(25));
        System.assertEquals('AA', FEC_DownloadReportService.columnLetter(26));
        System.assertEquals('AB', FEC_DownloadReportService.columnLetter(27));
    }

    @IsTest
    static void testBuildOoxmlHeaderRow_andXlsxBlob() {
        String headerRow = FEC_DownloadReportService.buildOoxmlHeaderRow(
            new List<String>{ 'Col A', 'Col & B' }
        );
        System.assert(headerRow.contains('Col A'));
        System.assert(headerRow.contains('Col &amp; B'));

        Blob xlsx = FEC_DownloadReportService.buildXlsxBlob(
            new List<String>{ headerRow }
        );
        System.assertNotEquals(null, xlsx);
        System.assert(xlsx.size() > 0, 'XLSX blob should not be empty.');
    }
}
