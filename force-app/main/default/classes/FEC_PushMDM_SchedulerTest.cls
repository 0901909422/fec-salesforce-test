/**
 * @description Test class cho FEC_PushMDM_Scheduler
 * Đảm bảo coverage cho việc lập lịch chạy Batch đẩy dữ liệu MDM.
 */
@isTest
private class FEC_PushMDM_SchedulerTest {

    @isTest
    static void testSchedulerExecution() {
        // Biểu thức Cron: Chạy vào lúc 0h ngày 31 tháng 12 năm 2040 (một ngày xa trong tương lai)
        String cronExp = '0 0 0 31 12 ? 2040';
        
        Test.startTest();
        
        // 1. Lập lịch cho class
        String jobId = System.schedule(
            'Test FEC_PushMDM_Scheduler', 
            cronExp, 
            new FEC_PushMDM_Scheduler()
        );
        
        // 2. Kiểm tra xem Job đã được đưa vào hàng đợi chưa
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime 
                          FROM CronTrigger WHERE id = :jobId];
        
        Assert.areEqual(cronExp, ct.CronExpression, 'Cron Expression không khớp');
        Assert.areEqual(0, ct.TimesTriggered, 'Job không được phép chạy trước khi Test.stopTest()');
        
        // Test.stopTest() sẽ ép buộc các asynchronous jobs (như Schedulable và Batchable) thực thi logic
        Test.stopTest();
        
        // Sau khi stopTest, Job đã được thực thi. 
    }
}
