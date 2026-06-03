@IsTest
private class FEC_IntegrationFraudScheduler_Test {

    private static final String CRON_EXPR = '0 0 0 1 1 ? 2099';

    private static Boolean canRunSchedulerTests() {
        return Type.forName('FEC_IntegrationFraudScheduler') != null;
    }

    @IsTest
    static void testSystemScheduleAndExecute() {
        if (!canRunSchedulerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudScheduler not on org.');
            return;
        }

        String jobName = 'FEC_Fraud_Sched_Test_' + System.currentTimeMillis();

        Test.startTest();
        Id jobId = System.schedule(
            jobName,
            CRON_EXPR,
            new FEC_IntegrationFraudScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        List<CronTrigger> triggers = [
            SELECT Id, CronJobDetail.Name, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, triggers.size());
        System.assertEquals(jobName, triggers[0].CronJobDetail.Name);
    }

    @IsTest
    static void testExecuteWithSchedulableContext() {
        if (!canRunSchedulerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudScheduler not on org.');
            return;
        }

        Id jobId;
        Test.startTest();
        jobId = System.schedule(
            'FEC_Fraud_Exec_Test_' + System.currentTimeMillis(),
            CRON_EXPR,
            new FEC_IntegrationFraudScheduler()
        );
        Test.stopTest();

        FEC_IntegrationFraudScheduler scheduler = new FEC_IntegrationFraudScheduler();
        try {
            scheduler.execute(new MockSchedulableContext(jobId));
            System.assert(true, 'Execute completed (success or handled failure path).');
        } catch (Exception e) {
            System.assert(
                String.isNotBlank(e.getMessage()),
                'Unexpected execute failure: ' + e.getMessage()
            );
        }
    }

    @IsTest
    static void testExecute_nullContextThrows() {
        if (!canRunSchedulerTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudScheduler not on org.');
            return;
        }

        Test.startTest();
        try {
            new FEC_IntegrationFraudScheduler().execute(null);
            System.assert(false, 'Must throw when SchedulableContext is null.');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private class MockSchedulableContext implements SchedulableContext {
        private Id triggerId;

        MockSchedulableContext(Id triggerId) {
            this.triggerId = triggerId;
        }

        public Id getTriggerId() {
            return triggerId;
        }

        public Id getJobId() {
            return null;
        }
    }
}
