@IsTest
private class FEC_SyncCaseStatusScheduler_Test {

    @IsTest
    static void testSchedulerExecution() {
        for (CronTrigger existing : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'FEC Sync Case Status Daily 00:00'
        ]) {
            System.abortJob(existing.Id);
        }

        Test.startTest();
        String jobId = FEC_SyncCaseStatusScheduler.scheduleDailyMidnightJob();
        Test.stopTest();

        // Kiểm tra xem CronTrigger đã được tạo chưa
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger 
            WHERE Id = :jobId
        ];

        System.assertEquals(FEC_SyncCaseStatusScheduler.DAILY_MIDNIGHT_CRON, ct.CronExpression, 'Cron expression phải khớp.');
        System.assertEquals(0, ct.TimesTriggered, 'Job chưa được chạy ngay sau khi lập lịch.');
    }

    @IsTest
    static void testExecuteBatch() {
        // 2. Kiểm tra việc gọi Batch từ Scheduler
        // Chúng ta có thể trigger thủ công phương thức execute() để đảm bảo batch được khởi tạo
        Test.startTest();
        FEC_SyncCaseStatusScheduler scheduler = new FEC_SyncCaseStatusScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Kiểm tra xem Batch Job đã được thêm vào hàng đợi chưa
        Integer batchJobs = [SELECT count() FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        System.assert(batchJobs > 0, 'Batch FEC_SyncCaseStatusBatch phải được gọi bởi scheduler.');
    }
}