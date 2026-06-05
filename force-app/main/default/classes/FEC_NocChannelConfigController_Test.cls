@IsTest
private class FEC_NocChannelConfigController_Test {

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Channel__c ch1 = new FEC_Channel__c(
            Name = 'CH01',
            FEC_Code__c = 'CHZ' + suffix,
            FEC_Channel_ID__c = 'CH-ZALO-' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Zalo',
            FEC_Channel_Status__c = true
        );
        FEC_Channel__c ch2 = new FEC_Channel__c(
            Name = 'CH02',
            FEC_Code__c = 'CHF' + suffix,
            FEC_Channel_ID__c = 'CH-FB-' + suffix,
            FEC_Channel_Vietnamese_name__c = 'Facebook',
            FEC_Channel_Status__c = true
        );
        insert new List<FEC_Channel__c>{ ch1, ch2 };

        // FEC_Nature_of_Case__c.FEC_Channel__c is Text — stores Channel record Id(s)
        insert new FEC_Nature_of_Case__c(
            FEC_Channel__c = String.valueOf(ch1.Id),
            FEC_Active__c = true
        );
    }

    @IsTest
    static void testCanEditChannelConfig() {
        // Lấy Profile của User đang chạy Test để tạo assertion động
        // Tránh lỗi khi chạy test ở các môi trường khác nhau (Sys Admin hoặc Profile khác)
        User currentUser = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Boolean expectedResult = (currentUser.Profile.Name == 'RD - IT User' || currentUser.Profile.Name == 'System Administrator');

        Test.startTest();
        Boolean result = FEC_NocChannelConfigController.canEditChannelConfig();
        Test.stopTest();

        System.assertEquals(expectedResult, result, 'Quyền edit channel config không khớp với Profile mong đợi.');
    }

    @IsTest
    static void testSearchChannels() {
        Test.startTest();
        // Nhánh 1: Tìm kiếm với chuỗi rỗng -> Mong đợi trả về tất cả bản ghi active (2 bản ghi)
        List<FEC_Channel__c> allChannels = FEC_NocChannelConfigController.searchChannels('');
        System.assertEquals(2, allChannels.size(), 'Truyền chuỗi rỗng phải tìm thấy tất cả Channel (Zalo, Facebook).');

        // Nhánh 2: Tìm kiếm với từ khóa cụ thể (starts-with)
        List<FEC_Channel__c> searchZalo = FEC_NocChannelConfigController.searchChannels('Zalo');
        System.assertEquals(1, searchZalo.size(), 'Phải tìm thấy 1 channel Zalo.');
        System.assertEquals('Zalo', searchZalo[0].FEC_Channel_Vietnamese_name__c);
        
        // Nhánh 3: Tìm kiếm với từ khóa không tồn tại
        List<FEC_Channel__c> searchEmpty = FEC_NocChannelConfigController.searchChannels('Tiktok');
        System.assertEquals(0, searchEmpty.size(), 'Không được trả về kết quả nào.');
        Test.stopTest();
    }

    @IsTest
    static void testGetChannelIds() {
        FEC_Nature_of_Case__c noc = [SELECT Id, FEC_Channel__c FROM FEC_Nature_of_Case__c LIMIT 1];

        Test.startTest();
        // Nhánh 1: Truyền ID hợp lệ
        String channelId = FEC_NocChannelConfigController.getChannelIds(noc.Id);
        
        // Nhánh 2: Truyền ID rỗng/null
        String emptyChannelId = FEC_NocChannelConfigController.getChannelIds('');
        Test.stopTest();

        System.assertEquals(noc.FEC_Channel__c, channelId, 'Phải lấy đúng Channel ID được gán vào NOC.');
        System.assertEquals(null, emptyChannelId, 'Truyền ID rỗng phải trả về null.');
    }

    @IsTest
    static void testSaveChannelIds() {
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Channel__c fbChannel = [SELECT Id FROM FEC_Channel__c WHERE FEC_Channel_Vietnamese_name__c = 'Facebook' LIMIT 1];

        Test.startTest();
        // Nhánh 1: Lưu dữ liệu hợp lệ
        FEC_NocChannelConfigController.saveChannelIds(noc.Id, fbChannel.Id);
        
        // Nhánh 2: Lưu dữ liệu khi ID NOC bị rỗng (Bypass)
        FEC_NocChannelConfigController.saveChannelIds('', fbChannel.Id);
        Test.stopTest();

        // Query kiểm tra lại database
        FEC_Nature_of_Case__c updatedNoc = [SELECT FEC_Channel__c FROM FEC_Nature_of_Case__c WHERE Id = :noc.Id];
        System.assertEquals(fbChannel.Id, updatedNoc.FEC_Channel__c, 'Trường FEC_Channel__c phải được cập nhật thành ID mới.');
    }
}