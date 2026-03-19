@isTest
private class FEC_CustAddHistHandlerTest {
    
    @testSetup
    static void setup() {
        // Tạo dữ liệu nền nếu cần
    }

    @isTest
    static void testTriggerLogic() {
        Test.startTest();
        
        // 1. Test INSERT: Phải tạo 1 bản ghi History trạng thái 'Draft'
        FEC_CustomerAdditionalInfoConfig__c config = new FEC_CustomerAdditionalInfoConfig__c(
            FEC_KeyIdentifier__c = 'CIF',
            FEC_FieldID__c = 'ZaloID',
            FEC_Status__c = 'Draft',
            FEC_IsActive__c = true
        );
        insert config;
        
        // Assert Insert
        List<FEC_CustomerDataConfigHistory__c> h1 = [SELECT FEC_Status__c FROM FEC_CustomerDataConfigHistory__c WHERE FEC_Customers_Data_Config__c = :config.Id];
        System.assertEquals(1, h1.size(), 'Sau khi insert Config phải có 1 History');
        System.assertEquals('Draft', h1[0].FEC_Status__c);

        // 2. Test UPDATE thường: Status giữ nguyên
        config.FEC_IsActive__c = false;
        update config;
        
        // 3. Test UPDATE đặc biệt: Status = Uploaded -> History phải là 'Reuploaded'
        config.FEC_Status__c = FEC_ConstantCommon.UPLOADED_STATUS; 
        update config;
        
        Test.stopTest();
        
        // Assert Update
        List<FEC_CustomerDataConfigHistory__c> allHistories = [
            SELECT FEC_Status__c FROM FEC_CustomerDataConfigHistory__c 
            WHERE FEC_Customers_Data_Config__c = :config.Id 
            ORDER BY CreatedDate ASC
        ];
        
        System.assert(allHistories.size() >= 3, 'Phải có ít nhất 3 dòng lịch sử (1 insert + 2 update)');
        // Lấy dòng cuối cùng để kiểm tra logic Reuploaded
        System.assertEquals('Reuploaded', allHistories[allHistories.size()-1].FEC_Status__c);
    }
}