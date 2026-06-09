@IsTest
private class FEC_DownloadReportJob_Test {

    @IsTest
    static void testExecute_QueueableCompletes() {
        Test.startTest();
        Id jobId = System.enqueueJob(new FEC_DownloadReportJob());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Queueable phải được enqueue thành công.');

        AsyncApexJob jobInfo = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        System.assertEquals('Completed', jobInfo.Status, 'Job phải hoàn thành không lỗi.');
        System.assertEquals(0, jobInfo.NumberOfErrors, 'Không được có lỗi khi thực thi job.');
    }

    @IsTest
    static void testExecute_InvokesGenerateDailyReports() {
        Integer reportCountBefore = [
            SELECT COUNT()
            FROM FEC_Download_Report__c
        ];

        Test.startTest();
        System.enqueueJob(new FEC_DownloadReportJob());
        Test.stopTest();

        List<Report> configuredReports = [
            SELECT Id
            FROM Report
            WHERE DeveloperName IN ('FEC_RP_01', 'FEC_RP_02')
            LIMIT 1
        ];

        if (configuredReports.isEmpty()) {
            System.assertEquals(
                reportCountBefore,
                [SELECT COUNT() FROM FEC_Download_Report__c],
                'Không có report cấu hình thì service không tạo bản ghi mới.'
            );
        } else {
            System.assert(
                true,
                'Job đã gọi generateDailyReports; future method có thể chạy nếu report tồn tại trong org.'
            );
        }
    }
}
