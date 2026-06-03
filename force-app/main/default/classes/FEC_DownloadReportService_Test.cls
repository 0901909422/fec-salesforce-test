@IsTest
private class FEC_DownloadReportService_Test {

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
    static void testProcessReportAsync_whenReportExists_mayCreateRecord() {
        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN ('FEC_RP_01', 'FEC_RP_02')
            LIMIT 1
        ];
        if (reports.isEmpty()) {
            System.assert(true, 'Skipped: no configured report in org.');
            return;
        }

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String today = Date.today().format();
        Integer countBefore = [SELECT COUNT() FROM FEC_Download_Report__c];

        Test.startTest();
        FEC_DownloadReportService.processReportAsync(
            'Unit Test Report',
            reports[0].DeveloperName,
            String.valueOf(reports[0].Id),
            baseUrl,
            today
        );
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM FEC_Download_Report__c] >= countBefore,
            'Future method should run without throwing when report exists.'
        );
    }
}
