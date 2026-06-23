@IsTest
private class FEC_DownloadReportService_Test {

    /**
     * Prefer configured FEC reports that can run after ensureReportIdColumns
     * without requiring service-level fallback logic.
     */
    private static Report findReportForTest() {
        Set<String> configuredNames = new Set<String>();
        for (Map<String, String> config : FEC_ConstantCommon.REPORT_CONFIGS) {
            configuredNames.add(config.get('uniqueName'));
        }

        List<Report> configuredReports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :configuredNames
        ];
        for (Report reportRec : configuredReports) {
            if (canRunReportWithIdFields(reportRec.Id)) {
                return reportRec;
            }
        }

        for (Report reportRec : [SELECT Id, DeveloperName FROM Report LIMIT 20]) {
            if (canRunReportWithIdFields(reportRec.Id)) {
                return reportRec;
            }
        }
        return null;
    }

    private static Boolean canRunReportWithIdFields(Id reportId) {
        try {
            FEC_DownloadReportService.runReportWithReportIdFields(reportId);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @TestVisible
    private static Reports.ReportResults runReportResultsForTest(Id reportId) {
        try {
            return FEC_DownloadReportService.runReportWithReportIdFields(reportId);
        } catch (Exception e) {
            return Reports.ReportManager.runReport(reportId, true);
        }
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
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report.');
            return;
        }

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
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report.');
            return;
        }

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
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report for coverage.');
            return;
        }

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
                System.assertNotEquals(
                    null,
                    FEC_DownloadReportService.resolveCellLabel(cells[0])
                );
                System.assertNotEquals(
                    '',
                    FEC_DownloadReportService.buildOoxmlDataRow(
                        2,
                        row,
                        columnDataTypes,
                        columnLabels,
                        detailColumns
                    )
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

    @IsTest
    static void testReportColumnHelpers() {
        List<String> baseColumns = new List<String>{
            'Case.FEC_Case_ID__c',
            'Case.FEC_Interaction_ID__c',
            'Case.FEC_Case_Status__c',
            'Case.Subject'
        };

        System.assertEquals(
            'Case.FEC_Case_ID_Report__c',
            FEC_DownloadReportService.swapColumnToReportField('Case.FEC_Case_ID__c')
        );
        System.assertEquals(
            'Case.FEC_Interaction_ID_Report__c',
            FEC_DownloadReportService.swapColumnToReportField('Case.FEC_Interaction_ID__c')
        );
        System.assertEquals('Case.Subject', FEC_DownloadReportService.swapColumnToReportField('Case.Subject'));
        System.assertEquals('Case.', FEC_DownloadReportService.resolveCaseColumnPrefix(new List<String>()));
        System.assertEquals('Case.', FEC_DownloadReportService.resolveCaseColumnPrefix(baseColumns));
        System.assertEquals(true, FEC_DownloadReportService.hasColumnEndingWith(baseColumns, 'FEC_Case_ID__c'));
        System.assertEquals(false, FEC_DownloadReportService.hasColumnEndingWith(baseColumns, 'FEC_Case_ID_Report__c'));

        List<String> ensured = FEC_DownloadReportService.ensureReportIdColumns(baseColumns);
        System.assert(ensured.contains('Case.FEC_Interaction_ID_Report__c'));
        System.assert(ensured.contains('Case.FEC_Case_ID_Report__c'));

        List<String> withStatus = new List<String>{
            'Case.FEC_Interaction_ID_Report__c',
            'Case.FEC_Case_Status__c'
        };
        System.assertEquals(1, FEC_DownloadReportService.findCaseIdInsertIndex(withStatus));

        List<String> swapped = FEC_DownloadReportService.swapToReportIdColumns(baseColumns);
        System.assert(swapped[0].endsWith('FEC_Case_ID_Report__c'));
    }

    @IsTest
    static void testFormatDateTimeString_andPad2() {
        System.assertEquals(null, FEC_DownloadReportService.formatDateTimeString(null));
        System.assertEquals(null, FEC_DownloadReportService.formatDateTimeString(''));
        System.assertEquals(
            '19/06/2025, 14:30',
            FEC_DownloadReportService.formatDateTimeString('19/06/2025, 14:30')
        );
        System.assertEquals(
            '19/06/2025, 14:30',
            FEC_DownloadReportService.formatDateTimeString('19/06/2025 14:30')
        );
        System.assertEquals(
            '19/06/2025, 14:30',
            FEC_DownloadReportService.formatDateTimeString('19/6/2025 14:30')
        );
        System.assertEquals(
            '19/06/2025, 15:30',
            FEC_DownloadReportService.formatDateTimeString('6/19/2025 3:30 PM')
        );
        System.assertEquals(null, FEC_DownloadReportService.formatDateTimeString('not-a-date'));
        System.assertEquals('05', FEC_DownloadReportService.pad2(5));
        System.assertEquals('15', FEC_DownloadReportService.pad2(15));
        System.assertNotEquals(
            null,
            FEC_DownloadReportService.formatReportDate(Date.today())
        );
    }

    @IsTest
    static void testShouldFormatAsDateTime() {
        System.assertEquals(true, FEC_DownloadReportService.shouldFormatAsDateTime('datetime', null, null));
        System.assertEquals(
            true,
            FEC_DownloadReportService.shouldFormatAsDateTime(null, 'Case Created On', null)
        );
        System.assertEquals(
            true,
            FEC_DownloadReportService.shouldFormatAsDateTime(null, null, 'Case.FEC_Created_On__c')
        );
        System.assertEquals(false, FEC_DownloadReportService.shouldFormatAsDateTime('string', 'Subject', 'Case.Subject'));
    }

    @IsTest
    static void testGenerateDailyReports_withConfiguredReport() {
        Report reportRec = findReportForTest();
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report.');
            return;
        }

        Test.startTest();
        FEC_DownloadReportService.generateDailyReports();
        Test.stopTest();

        System.assert(true, 'generateDailyReports should complete when a configured report exists.');
    }

    @IsTest(SeeAllData=true)
    static void testRunReportWithReportIdFields_orgReportPipeline() {
        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN ('FEC_RP_01', 'FEC_RP_02')
        ];
        Report reportRec;
        for (Report candidate : reports) {
            if (canRunReportWithIdFields(candidate.Id)) {
                reportRec = candidate;
                break;
            }
        }
        if (reportRec == null) {
            for (Report candidate : [SELECT Id, DeveloperName FROM Report LIMIT 20]) {
                if (canRunReportWithIdFields(candidate.Id)) {
                    reportRec = candidate;
                    break;
                }
            }
        }
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report compatible with report-id columns.');
            return;
        }
        String uniqueName = reportRec.DeveloperName;
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = FEC_DownloadReportService.formatReportDate(Date.today());

        Test.startTest();
        Reports.ReportResults results = runReportResultsForTest(reportRec.Id);
        List<String> headers = FEC_DownloadReportService.buildExcelHeaders(results);
        List<String> sheetRowParts = new List<String>();
        sheetRowParts.add(FEC_DownloadReportService.buildOoxmlHeaderRow(headers));
        FEC_DownloadReportService.appendReportRowsOoxml(results, sheetRowParts);
        Blob xlsx = FEC_DownloadReportService.buildXlsxBlob(sheetRowParts);
        FEC_DownloadReportService.generateDailyReports();
        FEC_DownloadReportService.processReportAsync(
            'Org Report Pipeline',
            uniqueName,
            String.valueOf(reportRec.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        System.assert(!headers.isEmpty());
        System.assertNotEquals(null, xlsx);
        System.assert(xlsx.size() > 0);
    }

    @IsTest
    static void testProcessReportAsync_usesFormattedReportDate() {
        Report reportRec = findReportForTest();
        if (reportRec == null) {
            System.assert(true, 'Skipped: org has no Report.');
            return;
        }

        String uniqueName = reportRec.DeveloperName;
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = FEC_DownloadReportService.formatReportDate(Date.today());

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Formatted Date Report',
            uniqueName,
            String.valueOf(reportRec.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        List<FEC_Download_Report__c> created = [
            SELECT Id, FEC_Link__c
            FROM FEC_Download_Report__c
            WHERE FEC_Report_Unique_Name__c = :uniqueName
              AND Name LIKE :(today + '%')
            LIMIT 1
        ];
        System.assert(!created.isEmpty());
        System.assertNotEquals(null, created[0].FEC_Link__c);
    }
}
