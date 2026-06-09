/**
 * Unit tests for CaseSearchDeletionScheduler.
 * Verifies the scheduling of the deletion batch.
 */
@IsTest
private class FEC_CaseSearchDeletionScheduler_Test {

    @IsTest
    static void execute_schedulesBatchSuccessfully() {
        String cronExp = '0 0 0 1 1 ? 2099';

        Test.startTest();
        String jobId = System.schedule(
            'FEC_CaseSearchDeletionScheduler_Test_Job',
            cronExp,
            new CaseSearchDeletionScheduler()
        );
        System.assertNotEquals(null, jobId, 'Job ID should be returned after scheduling.');

        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match.');
        System.assertEquals(0, ct.TimesTriggered, 'Job should not have fired before stopTest.');

        Test.stopTest();
    }
}
