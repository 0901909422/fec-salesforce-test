@IsTest
private class FEC_LocationSyncScheduler_Test {

    @IsTest
    static void test_Schedule() {
        FEC_IntegrationLocationService.useMock = true;

        Test.startTest();
        String jobId = System.schedule(
            'TestLocationScheduler_' + Datetime.now().getTime(),
            '0 0 0 1 1 ? 2099',
            new FEC_LocationSyncScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled');
    }
}