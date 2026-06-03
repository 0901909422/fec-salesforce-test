@IsTest
private class FEC_LocationSyncScheduler_Test {

    @IsTest
    static void test_execute() {
        // Use mock to avoid external object queries
        FEC_IntegrationLocationService.useMock = true;

        Test.startTest();
        String jobId = System.schedule(
            'Test Location Sync',
            '0 0 2 * * ?',
            new FEC_LocationSyncScheduler()
        );
        Test.stopTest();

        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Job should be scheduled');
    }
}
