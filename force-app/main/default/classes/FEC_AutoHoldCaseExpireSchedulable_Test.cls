/**
 * Unit tests for FEC_AutoHoldCaseExpireSchedulable.
 */
@IsTest
private class FEC_AutoHoldCaseExpireSchedulable_Test {

    private static Integer countExpireBatchJobs() {
        return [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
              AND ApexClass.Name = 'FEC_AutoHoldCaseExpireBatch'
        ];
    }

    @IsTest
    static void testExecute_startsExpireBatch() {
        Integer before = countExpireBatchJobs();

        Test.startTest();
        new FEC_AutoHoldCaseExpireSchedulable().execute(null);
        Test.stopTest();

        System.assert(
            countExpireBatchJobs() > before,
            'execute() should enqueue FEC_AutoHoldCaseExpireBatch.'
        );
    }

    @IsTest
    static void testSchedule_invokesExecuteAndBatch() {
        String cron = '0 0 0 1 1 ? 2099';
        Integer before = countExpireBatchJobs();

        Test.startTest();
        System.schedule('FEC Auto Hold Expire UT', cron, new FEC_AutoHoldCaseExpireSchedulable());
        Test.stopTest();

        System.assert(
            countExpireBatchJobs() > before,
            'Scheduled job should run execute() and start the expire batch.'
        );

        List<CronTrigger> triggers = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'FEC Auto Hold Expire UT'
        ];
        System.assertEquals(1, triggers.size(), 'Cron job should be registered.');
    }
}
