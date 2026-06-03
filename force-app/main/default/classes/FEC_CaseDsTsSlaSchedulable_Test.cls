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

        System.assertEquals(4, jobIds.size(), 'Should schedule 4 jobs for :00/:15/:30/:45.');

        List<CronTrigger> activeJobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :('FEC Case DS/TS SLA Every 15m%')
        ];
        System.assertEquals(4, activeJobs.size(), 'All 4 DS/TS SLA jobs should exist.');

        FEC_CaseDsTsSlaSchedulable.abortAllJobs();

        Integer remaining = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :('FEC Case DS/TS SLA Every 15m%')
        ];
        System.assertEquals(0, remaining, 'abortAllJobs should remove all scheduled DS/TS SLA jobs.');
    }

    @IsTest
    static void testAbortExistingByName_andEnsureScheduledInTest() {
        List<String> jobIds = FEC_CaseDsTsSlaSchedulable.scheduleEvery15Minutes();
        System.assertEquals(4, jobIds.size());

        // In test context this method should short-circuit and not schedule extra jobs.
        FEC_CaseDsTsSlaSchedulable.ensureScheduled();

        Integer beforeAbort = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :('FEC Case DS/TS SLA Every 15m%')
        ];
        System.assertEquals(4, beforeAbort);

        FEC_CaseDsTsSlaSchedulable.abortExistingByName(FEC_CaseDsTsSlaSchedulable.JOB_NAME);

        Integer afterAbort = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :('FEC Case DS/TS SLA Every 15m%')
        ];
        System.assertEquals(0, afterAbort);
    }
}
