@IsTest
private class FEC_DownloadReportScheduler_Test {

    private static final String CRON_EXPR = '0 0 0 1 1 ? 2099';

    @IsTest
    static void testSystemSchedule_RegistersCronJob() {
        String jobName = 'FEC_DownloadReport_Sched_Test_' + System.currentTimeMillis();

        Test.startTest();
        Id cronId = System.schedule(
            jobName,
            CRON_EXPR,
            new FEC_DownloadReportScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, cronId, 'Cron job phải được schedule thành công.');

        List<CronTrigger> triggers = [
            SELECT Id, CronJobDetail.Name, State
            FROM CronTrigger
            WHERE Id = :cronId
        ];
        System.assertEquals(1, triggers.size(), 'Phải tìm thấy CronTrigger vừa tạo.');
        System.assertEquals(jobName, triggers[0].CronJobDetail.Name);
    }

    @IsTest
    static void testExecute_EnqueuesDownloadReportJob() {
        Test.startTest();
        new FEC_DownloadReportScheduler().execute(new MockSchedulableContext());
        Test.stopTest();

        List<AsyncApexJob> queueableJobs = [
            SELECT Status, NumberOfErrors, ApexClass.Name
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'FEC_DownloadReportJob'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(1, queueableJobs.size(), 'Scheduler phải enqueue FEC_DownloadReportJob.');
        System.assertEquals('Completed', queueableJobs[0].Status, 'Queueable phải hoàn thành.');
        System.assertEquals(0, queueableJobs[0].NumberOfErrors, 'Queueable không được có lỗi.');
    }

    private class MockSchedulableContext implements SchedulableContext {
        public Id getTriggerId() {
            return null;
        }

        public Id getJobId() {
            return null;
        }
    }
}
