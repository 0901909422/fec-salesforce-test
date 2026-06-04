@IsTest
private class FEC_CaseDsTsSlaSchedulable_Test {

    @IsTest
    static void testExecute_runsBatch() {
        String cron = '0 0 0 1 1 ? 2099';

        Test.startTest();
        System.schedule('FEC DS TS SLA Execute UT', cron, new FEC_CaseDsTsSlaSchedulable());
        Test.stopTest();

        Integer batchJobs = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
              AND ApexClass.Name = 'FEC_CaseDsTsSlaBatch'
        ];
        System.assert(batchJobs > 0, 'Schedulable execute() should start DS/TS SLA batch.');
    }

    @IsTest
    static void testScheduleEvery15Minutes_andAbortAllJobs() {
        Test.startTest();
        List<String> jobIds = FEC_CaseDsTsSlaSchedulable.scheduleEvery15Minutes();
        Test.stopTest();

        System.assertNotEquals(null, jobIds, 'Deprecated scheduler should return a list.');
        FEC_CaseDsTsSlaSchedulable.abortAllJobs();

        Integer remaining = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :(FEC_CaseDsTsSlaSchedulable.JOB_NAME_PREFIX + '%')
        ];
        System.assertEquals(0, remaining, 'abortAllJobs should remove scheduled DS/TS SLA jobs.');
    }

    @IsTest
    static void testAbortExistingByName_andEnsureScheduledInTest() {
        String cron = '0 15 0 1 1 ? 2099';
        String jobName =
            FEC_CaseDsTsSlaSchedulable.JOB_NAME_PREFIX + ':' + String.valueOf(System.now().getTime());
        System.schedule(jobName, cron, new FEC_CaseDsTsSlaSchedulable());

        FEC_CaseDsTsSlaSchedulable.ensureScheduled();

        Integer beforeAbort = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :(FEC_CaseDsTsSlaSchedulable.JOB_NAME_PREFIX + '%')
        ];
        System.assert(beforeAbort > 0, 'Scheduled job should exist before abort.');

        FEC_CaseDsTsSlaSchedulable.abortExistingByName(FEC_CaseDsTsSlaSchedulable.JOB_NAME);

        Integer afterAbort = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :(FEC_CaseDsTsSlaSchedulable.JOB_NAME_PREFIX + '%')
        ];
        System.assertEquals(0, afterAbort);
    }
}
