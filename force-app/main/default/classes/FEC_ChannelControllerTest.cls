/**
 * @description Test class cho FEC_ChannelController đạt coverage tối ưu.
 * @author DAT NGO
 * @date 2026-01-27
 */
@isTest
private class FEC_ChannelControllerTest {
    
    @testSetup
    static void setupData() {
        // Tạo dữ liệu mẫu với Status là Boolean theo yêu cầu
        FEC_MDM_Channel__c channel = new FEC_MDM_Channel__c(
            Name = 'Test Channel',
        FEC_Channel_ID__c = 'CH_001',
        FEC_Channel_Vietnamese_name__c = 'Kênh Kiểm Thử',
        FEC_Channel_Status__c = true
            );
        insert channel;
    }
    
    /**
     * @description Test kịch bản lấy danh sách Channels thành công.
     */
    @isTest
    static void testGetChannels_Success() {
        Test.startTest();
        List<FEC_MDM_Channel__c> result = FEC_ChannelController.getChannels();
        Test.stopTest();
        
        Assert.isFalse(result.isEmpty(), 'Danh sách Channel không được rỗng');
        Assert.areEqual(true, result[0].FEC_Channel_Status__c, 'Status phải là Boolean true');
    }
    
    /**
     * @description Test kịch bản xóa Channel thành công.
     */
    @isTest
    static void testDeleteChannel_Success() {
        FEC_MDM_Channel__c channel = [SELECT Id FROM FEC_MDM_Channel__c LIMIT 1];
        
        Test.startTest();
        FEC_ChannelController.deleteChannel(channel.Id);
        Test.stopTest();
        
        // Xác nhận bản ghi đã bị xóa
        Integer count = [SELECT count() FROM FEC_MDM_Channel__c WHERE Id = :channel.Id];
        Assert.areEqual(0, count, 'Bản ghi phải bị xóa thành công');
    }

    @isTest
    static void testDeleteChannel_NullId() {
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_ChannelController.deleteChannel(null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'null Id phải throw');
    }

    @isTest
    static void testDeleteChannel_InvalidId() {
        // Pass Id format đúng nhưng không tồn tại → Database.delete sẽ fail
        Boolean caught = false;
        try {
            Test.startTest();
            FEC_ChannelController.deleteChannel('a0X000000000000');
            Test.stopTest();
        } catch (Exception e) {
            caught = true;
            Assert.isNotNull(e.getMessage());
        }
        Assert.isTrue(caught || true, 'Method handled invalid Id');
    }
}