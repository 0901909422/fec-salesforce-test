@IsTest
private class FEC_SyncCaseStatusBatch_Test {

    @IsTest
    static void testBatchSyncStatus() {
        // 1. Dữ liệu đầu vào: Cần tạo FEC_Routing_Action_History__c
        // Lưu ý: Trong Unit Test, CreatedDate là trường chỉ đọc (Read-only).
        // Nếu Org không cho phép set CreatedDate, batch này sẽ trả về 0 record.
        // Để kiểm thử logic bên trong 'execute', chúng ta sẽ giả lập list scope.
        
        List<FEC_Routing_Action_History__c> scope = new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c(FEC_Changed_Status__c = 'Pending'),
            new FEC_Routing_Action_History__c(FEC_Changed_Status__c = 'Resolved')
        };

        // 2. Chạy execute trực tiếp (cách này giúp test logic quan trọng nhất: Map & Insert)
        Test.startTest();
        FEC_SyncCaseStatusBatch batch = new FEC_SyncCaseStatusBatch();
        batch.execute(null, scope);
        Test.stopTest();

        // 3. Kiểm tra kết quả trong FEC_Case_Status__c
        List<FEC_Case_Status__c> insertedStatuses = [SELECT Name FROM FEC_Case_Status__c WHERE Name IN ('Pending', 'Resolved')];
        System.assertEquals(2, insertedStatuses.size(), 'Batch phải insert 2 status mới.');
    }

    @IsTest
    static void testBatchSyncStatus_Duplicates() {
        // Tạo trước 1 status đã tồn tại để test việc deduplication
        insert new FEC_Case_Status__c(Name = 'Pending');
        
        List<FEC_Routing_Action_History__c> scope = new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c(FEC_Changed_Status__c = 'Pending'),
            new FEC_Routing_Action_History__c(FEC_Changed_Status__c = 'NewStatus')
        };

        Test.startTest();
        new FEC_SyncCaseStatusBatch().execute(null, scope);
        Test.stopTest();

        // Pending đã có sẵn, nên chỉ insert thêm NewStatus
        List<FEC_Case_Status__c> insertedStatuses = [SELECT Name FROM FEC_Case_Status__c WHERE Name IN ('Pending', 'NewStatus')];
        System.assertEquals(2, insertedStatuses.size(), 'Chỉ nên có 2 record duy nhất.');
    }
}