@IsTest
private class FEC_ClearSessionController_Test {

    @TestSetup
    static void setupData() {
        // Tạo User mồi để test chức năng tìm kiếm
        User u = new User(
            Alias = 'tuser', Email = 'test.user@fecredit.com.vn', 
            LastName = 'Tester', ProfileId = UserInfo.getProfileId(),
            UserName = 'test.user.clear@fecredit.com.vn', 
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', 
            LocaleSidKey = 'en_US', TimeZoneSidKey = 'America/Los_Angeles'
        );
        insert u;
    }

    /**
     * Kịch bản 1: Kiểm tra hàm searchUsers
     */
    @IsTest
    static void testSearchUsers_Success() {
        Test.startTest();
        // Tìm kiếm theo tên hoặc email (Keyword phải >= 2 ký tự)
        List<FEC_ClearSessionController.UserResult> results = FEC_ClearSessionController.searchUsers('Tester');
        Test.stopTest();

        System.assert(results.size() > 0, 'Phải tìm thấy ít nhất 1 user.');
        System.assertEquals('Tester', results[0].name);
    }

    @IsTest
    static void testSearchUsers_InvalidKeyword() {
        Test.startTest();
        // Keyword ngắn hơn 2 ký tự
        List<FEC_ClearSessionController.UserResult> results = FEC_ClearSessionController.searchUsers('a');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Kết quả phải rỗng nếu từ khóa quá ngắn.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm clearSessions và @future method
     */
    @IsTest
    static void testClearSessions_Success() {
        User u = [SELECT Id FROM User WHERE Alias = 'tuser' LIMIT 1];
        List<Id> userIds = new List<Id>{ u.Id };

        Test.startTest();
        // Lưu ý: FEC_SessionUtil.forceClearSessions cần tồn tại trong hệ thống
        FEC_ClearSessionController.clearSessions(userIds);
        Test.stopTest();

        // Kiểm tra record lịch sử (FEC_Clear_Session__c) đã được tạo qua @future
        List<FEC_Clear_Session__c> logs = [SELECT FEC_Status__c FROM FEC_Clear_Session__c];
        System.assertEquals(1, logs.size(), 'Lịch sử log phải được tạo.');
        System.assertEquals('Success', logs[0].FEC_Status__c);
    }

    /**
     * Kịch bản 3: Kiểm tra hàm getAllClearSessions
     */
    @IsTest
    static void testGetAllClearSessions() {
        // Tạo log mồi
        insert new FEC_Clear_Session__c(FEC_User__c = 'test@email.com', FEC_Status__c = 'Success');

        Test.startTest();
        List<FEC_Clear_Session__c> logs = FEC_ClearSessionController.getAllClearSessions();
        Test.stopTest();

        System.assert(logs.size() > 0);
    }

    /**
     * Kịch bản 4: Kiểm tra bẫy lỗi (Exception)
     */
    @IsTest
    static void testClearSessions_NullInput() {
        Boolean thrown = false;
        try {
            FEC_ClearSessionController.clearSessions(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assertEquals(true, thrown, 'Phải ném AuraHandledException khi userIds null.');
    }
}