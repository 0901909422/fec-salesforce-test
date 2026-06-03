@IsTest
private class FEC_SessionUtil_Test {

    @IsTest
    static void testForceClearSessions_CurrentTestUser() {
        // Lấy ID của User đang chạy test context
        Id currentUserId = UserInfo.getUserId();
        
        Test.startTest();
        // Gọi phương thức
        Boolean result = FEC_SessionUtil.forceClearSessions(currentUserId);
        Test.stopTest();
        
        // Trong môi trường test, truy vấn AuthSession thường trả về danh sách rỗng 
        // (do không có UI Session thực), hàm sẽ đi qua lệnh if và trả về true.
        System.assertEquals(true, result, 'Hàm phải trả về true khi thực thi an toàn không có lỗi hệ thống.');
    }

    @IsTest
    static void testForceClearSessions_NullUserId() {
        Test.startTest();
        // Truyền tham số null để kiểm tra độ an toàn của SOQL
        Boolean result = FEC_SessionUtil.forceClearSessions(null);
        Test.stopTest();
        
        // Truy vấn với UsersId = null sẽ trả về mảng rỗng, không gây lỗi và trả về true
        System.assertEquals(true, result, 'Hàm phải xử lý an toàn và trả về true khi nhận giá trị null.');
    }
    
    @IsTest
    static void testForceClearSessions_DummyUserId() {
        // UserInfo.getUserId() returns String — use User.SObjectType for key prefix
        Id dummyUserId = User.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        
        Test.startTest();
        Boolean result = FEC_SessionUtil.forceClearSessions(dummyUserId);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Hàm phải trả về true đối với User ID không tồn tại session.');
    }
}