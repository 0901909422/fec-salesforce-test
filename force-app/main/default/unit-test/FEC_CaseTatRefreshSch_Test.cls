@IsTest
private class FEC_CaseTatRefreshSch_Test {
    @IsTest
    static void testScheduleHourly_andScheduleEvery15Minutes() {
        Test.startTest();
        String hourlyJobId = FEC_CaseTatFullProcessRefreshScheduler.scheduleHourly();
        String every15JobId = FEC_CaseTatFullProcessRefreshScheduler.scheduleEvery15Minutes();
        Test.stopTest();

        System.assertNotEquals(null, hourlyJobId, 'scheduleHourly should return a job id.');
        System.assertNotEquals(null, every15JobId, 'scheduleEvery15Minutes should return a job id.');
    }

    @IsTest
    static void testExecute_runsSchedulable() {
        String cron = '0 0 0 1 1 ? 2099';

        Test.startTest();
        String jobId = System.schedule(
            'UT_FEC_CaseTatRefreshSch_' + System.now().getTime(),
            cron,
            new FEC_CaseTatFullProcessRefreshScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'System.schedule should return a job id.');
    }
}
