@IsTest
private class FEC_SendNotificationEmailsQueueable_Test {

    @IsTest
    static void testExecuteQueueable() {
        // 1. Chuẩn bị dữ liệu đầu vào (Mock Data)
        // Chúng ta tạo một bản ghi rỗng. Dựa vào logic của FEC_RoutingActionHistoryTriggerHandler,
        // nếu FEC_Case__c là null, hàm processNotificationEmails sẽ tự động return sớm (early exit),
        // giúp test chạy cực nhanh và cô lập hoàn toàn với dữ liệu của Handler.
        List<FEC_Routing_Action_History__c> dummyRecords = new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c()
        };

        // 2. Khởi tạo lớp Queueable
        FEC_SendNotificationEmailsQueueable queueableJob = new FEC_SendNotificationEmailsQueueable(dummyRecords);

        Test.startTest();
        // 3. Đưa Job vào hàng đợi
        Id jobId = System.enqueueJob(queueableJob);
        // Test.stopTest() sẽ ép tất cả các tiến trình bất đồng bộ (Queueable, Future, Batch)
        // chạy đồng bộ ngay lập tức để ta có thể kiểm tra kết quả.
        Test.stopTest();

        // 4. Kiểm tra kết quả
        System.assertNotEquals(null, jobId, 'Job ID không được null, Queueable phải được enqueue thành công.');
        
        // Truy vấn trạng thái của Job trong hệ thống
        AsyncApexJob jobInfo = [
            SELECT Status, NumberOfErrors 
            FROM AsyncApexJob 
            WHERE Id = :jobId
        ];
        
        System.assertEquals('Completed', jobInfo.Status, 'Trạng thái của Job phải là Completed.');
        System.assertEquals(0, jobInfo.NumberOfErrors, 'Không được có lỗi nào xảy ra trong quá trình thực thi Queueable.');
    }
}