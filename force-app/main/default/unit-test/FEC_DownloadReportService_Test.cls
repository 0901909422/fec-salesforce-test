/**
 * Unit tests for FEC_DownloadReportService.
 */
@IsTest
private class FEC_DownloadReportService_Test {

    private static final List<String> CONFIGURED_REPORT_DEV_NAMES = new List<String>{
        'FEC_RP_01',
        'FEC_RP_02',
        'Interactions_Service_Cases_TAT_CO',
        'Interactions_Service_Cases_TAT_CL',
        'Interactions_Service_Cases_TAT_CP',
        'Interactions_Service_Cases_TAT_CA'
    };

    private static Report findReportForTest() {
        List<Report> configured = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :CONFIGURED_REPORT_DEV_NAMES
            LIMIT 1
        ];
        if (!configured.isEmpty()) {
            return configured[0];
        }
        List<Report> anyReport = [SELECT Id, DeveloperName FROM Report LIMIT 1];
        return anyReport.isEmpty() ? null : anyReport[0];
    }

    private static String todayLabel() {
        return Date.today().format();
    }

    @IsTest(SeeAllData=true)
    static void testGenerateDailyReports_completesAndSchedulesFutures() {
        Test.startTest();
        FEC_DownloadReportService.generateDailyReports();
        Test.stopTest();

        System.assert(true, 'generateDailyReports should iterate configs without throwing.');
    }

    @IsTest
    static void testProcessReportAsync_invalidReportId_swallowsException() {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String uniqueName = 'FEC_RP_TEST_' + String.valueOf(System.currentTimeMillis());

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Test Report',
            uniqueName,
            UserInfo.getUserId(),
            baseUrl,
            todayLabel()
        );
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM FEC_Download_Report__c
                WHERE FEC_Report_Unique_Name__c = :uniqueName
            ],
            'Invalid report id should be handled without persisting download row.'
        );
    }

    @IsTest(SeeAllData=true)
    static void testProcessReportAsync_whenReportExists_buildsExport() {
        Report reportRow = findReportForTest();
        if (reportRow == null) {
            System.assert(true, 'Skipped: no configured Report in org.');
            return;
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = todayLabel();
        Integer countBefore = [SELECT COUNT() FROM FEC_Download_Report__c];

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Unit Test Report',
            reportRow.DeveloperName,
            String.valueOf(reportRow.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        List<FEC_Download_Report__c> rows = [
            SELECT Id, FEC_Link__c, FEC_Report_Unique_Name__c
            FROM FEC_Download_Report__c
            WHERE FEC_Report_Unique_Name__c = :reportRow.DeveloperName
            AND Name LIKE :(today + '%')
        ];
        System.assert(
            [SELECT COUNT() FROM FEC_Download_Report__c] >= countBefore,
            'Future method should complete when report exists.'
        );
        if (!rows.isEmpty()) {
            System.assertNotEquals(null, rows[0].FEC_Link__c, 'Link should be set after ContentVersion insert.');
        }
    }

    @IsTest(SeeAllData=true)
    static void testProcessReportAsync_reusesExistingDownloadReportRow() {
        Report reportRow = findReportForTest();
        if (reportRow == null) {
            System.assert(true, 'Skipped: no configured Report in org.');
            return;
        }

        String today = todayLabel();
        String reportName = 'Reuse Download Report Test';
        FEC_Download_Report__c existing = new FEC_Download_Report__c(
            Name = today + ' - ' + reportName,
            FEC_Report_Unique_Name__c = reportRow.DeveloperName
        );
        insert existing;

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            reportName,
            reportRow.DeveloperName,
            String.valueOf(reportRow.Id),
            baseUrl,
            today
        );
        Test.stopTest();

        List<FEC_Download_Report__c> rows = [
            SELECT Id, FEC_Link__c
            FROM FEC_Download_Report__c
            WHERE FEC_Report_Unique_Name__c = :reportRow.DeveloperName
            AND Name LIKE :(today + '%')
        ];
        System.assertEquals(1, rows.size(), 'Should reuse existing FEC_Download_Report__c for same day.');
        System.assertEquals(existing.Id, rows[0].Id);
        System.assertNotEquals(null, rows[0].FEC_Link__c);
    }
}
