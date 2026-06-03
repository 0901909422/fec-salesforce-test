@IsTest
private class FEC_DownloadReportController_Test {

    private static FEC_Download_Report__c insertReport(
        String name,
        String uniqueName,
        String link
    ) {
        FEC_Download_Report__c report = new FEC_Download_Report__c(
            Name = name,
            FEC_Report_Unique_Name__c = uniqueName,
            FEC_Link__c = link
        );
        insert report;
        return report;
    }

    @IsTest
    static void testGetDownloadReports_ReturnsMappedRecords() {
        FEC_Download_Report__c older = insertReport(
            'Older Report',
            'REPORT_OLDER',
            'https://example.com/older.xls'
        );
        FEC_Download_Report__c newer = insertReport(
            'Newer Report',
            'REPORT_NEWER',
            'https://example.com/newer.xls'
        );

        Test.startTest();
        List<FEC_DownloadReportController.ReportWrapper> result =
            FEC_DownloadReportController.getDownloadReports();
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Phải trả về đủ 2 bản ghi report.');

        Map<Id, FEC_DownloadReportController.ReportWrapper> byId =
            new Map<Id, FEC_DownloadReportController.ReportWrapper>();
        for (FEC_DownloadReportController.ReportWrapper wrapper : result) {
            byId.put((Id) wrapper.id, wrapper);
        }

        FEC_DownloadReportController.ReportWrapper newerWrapper = byId.get(newer.Id);
        System.assertNotEquals(null, newerWrapper, 'Phải có report mới hơn.');
        System.assertEquals('Newer Report', newerWrapper.name);
        System.assertEquals('REPORT_NEWER', newerWrapper.uniqueName);
        System.assertEquals('https://example.com/newer.xls', newerWrapper.link);

        FEC_DownloadReportController.ReportWrapper olderWrapper = byId.get(older.Id);
        System.assertNotEquals(null, olderWrapper, 'Phải có report cũ hơn.');
        System.assertEquals('Older Report', olderWrapper.name);
        System.assertEquals('REPORT_OLDER', olderWrapper.uniqueName);
        System.assertEquals('https://example.com/older.xls', olderWrapper.link);
    }

    @IsTest
    static void testGetDownloadReports_EmptyList() {
        Test.startTest();
        List<FEC_DownloadReportController.ReportWrapper> result =
            FEC_DownloadReportController.getDownloadReports();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Kết quả không được null.');
        System.assertEquals(0, result.size(), 'Không có dữ liệu thì trả về list rỗng.');
    }

    @IsTest
    static void testDownloadReport_ReturnsLinksForValidIds() {
        FEC_Download_Report__c report1 = insertReport(
            'Report A',
            'REPORT_A',
            'https://example.com/a.xls'
        );
        FEC_Download_Report__c report2 = insertReport(
            'Report B',
            'REPORT_B',
            'https://example.com/b.xls'
        );

        Test.startTest();
        List<String> links = FEC_DownloadReportController.downloadReport(
            new List<Id>{ report1.Id, report2.Id }
        );
        Test.stopTest();

        System.assertEquals(2, links.size(), 'Phải trả về link cho cả 2 report.');
        System.assert(links.contains('https://example.com/a.xls'));
        System.assert(links.contains('https://example.com/b.xls'));
    }

    @IsTest
    static void testDownloadReport_SkipsBlankLinks() {
        FEC_Download_Report__c withLink = insertReport(
            'Report With Link',
            'REPORT_WITH_LINK',
            'https://example.com/with-link.xls'
        );
        FEC_Download_Report__c withoutLink = insertReport(
            'Report Without Link',
            'REPORT_WITHOUT_LINK',
            null
        );

        Test.startTest();
        List<String> links = FEC_DownloadReportController.downloadReport(
            new List<Id>{ withLink.Id, withoutLink.Id }
        );
        Test.stopTest();

        System.assertEquals(1, links.size(), 'Chỉ trả về report có FEC_Link__c.');
        System.assertEquals('https://example.com/with-link.xls', links[0]);
    }

    @IsTest
    static void testDownloadReport_ThrowsWhenNoLinksFound() {
        FEC_Download_Report__c blankLinkReport = insertReport(
            'Blank Link Report',
            'REPORT_BLANK_LINK',
            ''
        );

        Test.startTest();
        try {
            FEC_DownloadReportController.downloadReport(
                new List<Id>{ blankLinkReport.Id }
            );
            System.assert(false, 'Phải throw AuraHandledException khi không có link hợp lệ.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDownloadReport_ThrowsWhenIdsEmpty() {
        Test.startTest();
        try {
            FEC_DownloadReportController.downloadReport(new List<Id>());
            System.assert(false, 'Phải throw AuraHandledException khi danh sách Id rỗng.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
}
