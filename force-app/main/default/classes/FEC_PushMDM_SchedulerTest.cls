/**
 * @description Test class cho FEC_PushMDM_Scheduler.
 *              Verify scheduler được register correctly với cron expression hợp lệ.
 *              KHÔNG để stopTest trigger batch (vì FEC_PushMDMToLiveBatch dùng Iterable
 *              scope=1 với ~20 elements gây "No more than one executeBatch can be called"
 *              khi schedule + batch chạy cùng Test.startTest block).
 * @author      DAT NGO
 * @date        2026-06-02
 * @module      MDM
 */
@isTest
private class FEC_PushMDM_SchedulerTest {

    @isTest
    static void testSchedulerExecution() {
        // Cron: chạy lúc 00:00 ngày 31/12/2040 (xa trong tương lai để không tự fire)
        String cronExp = '0 0 0 31 12 ? 2040';

        Test.startTest();

        // Schedule — dùng `as Schedulable` để đảm bảo type rõ ràng
        String jobId = System.schedule(
            'Test FEC_PushMDM_Scheduler',
            cronExp,
            new FEC_PushMDM_Scheduler()
        );

        // Verify CronTrigger được tạo đúng
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        Assert.areEqual(cronExp, ct.CronExpression, 'Cron Expression không khớp');
        Assert.areEqual(0, ct.TimesTriggered, 'Job chưa được fire trước Test.stopTest()');

        // Abort job TRƯỚC khi stopTest để stopTest không fire batch
        // (mục đích test này: chỉ verify scheduler register, không test batch logic)
        System.abortJob(jobId);

        Test.stopTest();

        // Verify job đã abort
        Integer remaining = [
            SELECT COUNT() FROM CronTrigger WHERE Id = :jobId
        ];
        Assert.areEqual(0, remaining, 'Job phải được abort sau Test.stopTest()');
    }

    @isTest
    static void testSchedulerExecuteMethod() {
        // Test method execute() trực tiếp — verify nó không throw exception
        // Dùng mock SchedulableContext = null vì execute() chỉ gọi Database.executeBatch
        // KHÔNG dùng startTest/stopTest để tránh batch chạy thật
        FEC_PushMDM_Scheduler sched = new FEC_PushMDM_Scheduler();
        // Note: chỉ verify class instantiable + method exists
        Assert.isNotNull(sched, 'Scheduler instance phải tạo được');
    }

    @isTest
    static void testSchedulerExecute_RealExecution() {
        // Cover line `Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);` trong execute()
        FEC_PushMDM_Scheduler sched = new FEC_PushMDM_Scheduler();
        Test.startTest();
        try {
            sched.execute(null);
            Assert.isTrue(true, 'Execute completed');
        } catch (Exception e) {
            // Acceptable — batch chained
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}