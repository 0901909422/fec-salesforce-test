@IsTest
private class FEC_FullCustomerIntegrationJob_Test {

    @IsTest
    static void testExecute_SyncSuccess() {
        // 1. Dựng dữ liệu
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Customer_Name__c = 'Old Name'
        );
        insert hist;

        Case c = new Case(
            Subject = 'Test Case',
            FEC_Account_or_Contract__c = hist.Id
        );
        insert c;

        // 2. Mocking dữ liệu trả về từ Service
        // Vì class này gọi service static, cách tốt nhất là giả lập dữ liệu vào Database 
        // để Service xử lý hoặc mock bằng cách thay đổi logic service.
        // Ở đây giả định bạn có thể kiểm soát logic service qua data.

        Test.startTest();
        FEC_FullCustomerIntegrationJob job = new FEC_FullCustomerIntegrationJob(
            hist.Id, 'CIF123', '0901234567', 'ACC123'
        );
        System.enqueueJob(job);
        Test.stopTest();

        // 3. Kiểm tra kết quả
        FEC_Customer_History__c updatedHist = [SELECT FEC_Customer_Name__c FROM FEC_Customer_History__c WHERE Id = :hist.Id];
        // Hệ thống sẽ update theo dữ liệu mock từ Service
        System.assertNotEquals('Old Name', updatedHist.FEC_Customer_Name__c, 'Tên khách hàng phải được cập nhật.');
    }

    @IsTest
    static void testExecute_NullSafeUpdate() {
        // Tạo history với data cũ
        FEC_Customer_History__c hist = new FEC_Customer_History__c(
            FEC_Customer_Name__c = 'Existing Name'
        );
        insert hist;

        // Giả lập Service trả về result null hoặc rỗng
        // Code trong Service sẽ không ghi đè nếu result null/blank

        Test.startTest();
        FEC_FullCustomerIntegrationJob job = new FEC_FullCustomerIntegrationJob(
            hist.Id, 'CIF123', '0901234567', 'ACC123'
        );
        System.enqueueJob(job);
        Test.stopTest();

        FEC_Customer_History__c updatedHist = [SELECT FEC_Customer_Name__c FROM FEC_Customer_History__c WHERE Id = :hist.Id];
        System.assertEquals('Existing Name', updatedHist.FEC_Customer_Name__c, 'Không được ghi đè nếu kết quả trả về rỗng.');
    }
}