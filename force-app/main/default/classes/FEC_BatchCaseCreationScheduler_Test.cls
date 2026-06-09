@IsTest
private class FEC_BatchCaseCreationScheduler_Test {

    private static Integer countScheduledJobsByPrefix() {
        return [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC Batch Case Creation Daily%'
        ];
    }

    @IsTest
    static void testExecute_runsWithoutException() {
        Test.startTest();
        new FEC_BatchCaseCreationScheduler().execute(null);
        Test.stopTest();

        System.assert(true, 'execute() should complete without exceptions.');
    }

    @IsTest
    static void testRunProcessBatchNow_returnsBatchJobId() {
        Test.startTest();
        Id jobId = FEC_BatchCaseCreationScheduler.runProcessBatchNow();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned.');
        AsyncApexJob job = [
            SELECT Id, JobType
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        System.assertEquals('BatchApex', job.JobType);
    }

    @IsTest
    static void testScheduleDailyJob_replacesExistingJob() {
        Test.startTest();
        String firstJobId = FEC_BatchCaseCreationScheduler.scheduleDailyJob();
        String secondJobId = FEC_BatchCaseCreationScheduler.scheduleDailyJob();
        Test.stopTest();

        System.assertNotEquals(null, firstJobId, 'First schedule id is required.');
        System.assertNotEquals(null, secondJobId, 'Second schedule id is required.');
        System.assertNotEquals(firstJobId, secondJobId, 'Second schedule should recreate the job.');
        System.assertEquals(1, countScheduledJobsByPrefix(), 'Only one scheduled job should remain after reschedule.');

        CronTrigger latest = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :secondJobId
            LIMIT 1
        ];
        System.assertEquals(FEC_BatchCaseCreationScheduler.DAILY_SCHEDULE_CRON, latest.CronExpression);
        System.assert(latest.State == 'WAITING' || latest.State == 'ACQUIRED');
    }
}
