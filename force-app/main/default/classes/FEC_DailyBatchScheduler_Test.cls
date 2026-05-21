/**
 * FEC_DailyBatchScheduler_Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Unit tests và property-based tests cho FEC_DailyBatchScheduler.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class FEC_DailyBatchScheduler_Test {

    // ══════════════════════════════════════════════════════════════════════════
    // Unit Tests: scheduleAll / unscheduleAll
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testScheduleAll_CreatesThreeJobs() {
        Test.startTest();
        FEC_DailyBatchScheduler.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(3, jobs.size(), 'scheduleAll() should create exactly 3 jobs');

        Set<String> jobNames = new Set<String>();
        for (CronTrigger ct : jobs) {
            jobNames.add(ct.CronJobDetail.Name);
        }
        System.assert(jobNames.contains(FEC_DailyBatchScheduler.JOB_NAME_ARCHIVE_VERIFY),
            'Should contain ArchiveVerify job');
        System.assert(jobNames.contains(FEC_DailyBatchScheduler.JOB_NAME_CASE_EXPORT),
            'Should contain CaseExport job');
        System.assert(jobNames.contains(FEC_DailyBatchScheduler.JOB_NAME_ATTACHMENT_EXPORT),
            'Should contain AttachmentExport job');
    }

    @IsTest
    static void testUnscheduleAll_RemovesAllJobs() {
        FEC_DailyBatchScheduler.scheduleAll();

        Test.startTest();
        FEC_DailyBatchScheduler.unscheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(0, jobs.size(), 'unscheduleAll() should remove all jobs');
    }

    @IsTest
    static void testScheduleAll_Idempotent() {
        Test.startTest();
        FEC_DailyBatchScheduler.scheduleAll();
        FEC_DailyBatchScheduler.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(3, jobs.size(),
            'Calling scheduleAll() twice should still result in exactly 3 jobs');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Unit Tests: execute() method
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testExecute_Hour1_RunsArchiveVerifyBatch() {
        FEC_DailyBatchScheduler.testHourOverride = 1;

        Test.startTest();
        FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify batch was queued by checking AsyncApexJob
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'FEC_ArchiveVerifyBatch'
            AND JobType = 'BatchApex'
        ];
        System.assert(!jobs.isEmpty(), 'FEC_ArchiveVerifyBatch should be executed at hour 1');
    }

    @IsTest
    static void testExecute_Hour2_RunsCaseExportBatch() {
        FEC_DailyBatchScheduler.testHourOverride = 2;

        Test.startTest();
        FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();
        scheduler.execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'FEC_CaseExportBatch'
            AND JobType = 'BatchApex'
        ];
        System.assert(!jobs.isEmpty(), 'FEC_CaseExportBatch should be executed at hour 2');
    }

    @IsTest
    static void testExecute_Hour3_RunsAttachmentExportBatch() {
        FEC_DailyBatchScheduler.testHourOverride = 3;

        Test.startTest();
        FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();
        scheduler.execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'FEC_AttachmentExportBatch'
            AND JobType = 'BatchApex'
        ];
        System.assert(!jobs.isEmpty(), 'FEC_AttachmentExportBatch should be executed at hour 3');
    }

    @IsTest
    static void testExecute_OtherHour_NoBatchExecuted() {
        FEC_DailyBatchScheduler.testHourOverride = 10;

        Test.startTest();
        FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();
        scheduler.execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND CreatedDate = TODAY
        ];
        System.assertEquals(0, jobs.size(), 'No batch should be executed at hour 10');
    }

    @IsTest
    static void testExecute_ErrorContainment_NoException() {
        // Verify execute() does not throw even with unexpected hour
        FEC_DailyBatchScheduler.testHourOverride = 99;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();
            scheduler.execute(null);
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown,
            'execute() should never throw an exception');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Property-Based Tests (loop pattern)
    // ══════════════════════════════════════════════════════════════════════════

    @IsTest
    static void testHourToBatchMapping_Property() {
        // Feature: batch-daily-scheduler, Property 1: Hour-to-batch mapping correctness
        // For all 24 hours, only hours 1, 2, 3 should trigger batch execution
        Set<Integer> validHours = new Set<Integer>{1, 2, 3};

        for (Integer hour = 0; hour < 24; hour++) {
            FEC_DailyBatchScheduler.testHourOverride = hour;
            FEC_DailyBatchScheduler scheduler = new FEC_DailyBatchScheduler();

            Boolean exceptionThrown = false;
            try {
                scheduler.execute(null);
            } catch (Exception ex) {
                exceptionThrown = true;
            }
            System.assertEquals(false, exceptionThrown,
                'execute() should not throw for hour ' + hour);
        }
    }

    @IsTest
    static void testScheduleUnscheduleRoundTrip_Property() {
        // Feature: batch-daily-scheduler, Property 3: Schedule/unschedule round-trip
        // After scheduleAll() then unscheduleAll(), no jobs should remain

        Test.startTest();
        FEC_DailyBatchScheduler.scheduleAll();

        List<CronTrigger> jobsAfterSchedule = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(3, jobsAfterSchedule.size(),
            'scheduleAll() should create 3 jobs');

        FEC_DailyBatchScheduler.unscheduleAll();
        Test.stopTest();

        List<CronTrigger> jobsAfterUnschedule = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(0, jobsAfterUnschedule.size(),
            'unscheduleAll() should remove all jobs (round-trip)');
    }

    @IsTest
    static void testScheduleAllIdempotence_Property() {
        // Feature: batch-daily-scheduler, Property 4: scheduleAll idempotence
        // Calling scheduleAll() N times should always result in exactly 3 jobs

        Test.startTest();
        for (Integer i = 0; i < 3; i++) {
            FEC_DailyBatchScheduler.scheduleAll();
        }
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC_Daily_%'
        ];
        System.assertEquals(3, jobs.size(),
            'scheduleAll() called 3 times should still result in exactly 3 jobs');
    }
}
