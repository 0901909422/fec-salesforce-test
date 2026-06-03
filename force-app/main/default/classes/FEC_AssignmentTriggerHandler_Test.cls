@IsTest
private class FEC_AssignmentTriggerHandler_Test {

    @TestSetup
    static void setupData() {
        // 1. Khởi tạo dữ liệu Case mẫu
        Case testCase1 = new Case(
            Subject = 'Test Case 1',
            Status = 'Open'
        );
        Case testCase2 = new Case(
            Subject = 'Test Case 2',
            Status = 'Open'
        );
        insert new List<Case>{testCase1, testCase2};

        // 2. Tạo bản ghi User giả lập để gán Owner
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User testUser1 = new User(
            Alias = 'usr1', Email='testuser1@fecredit.com.vn',
            EmailEncodingKey='UTF-8', LastName='Testing1', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='testuser1_fec@fecredit.com.vn'
        );
        User testUser2 = new User(
            Alias = 'usr2', Email='testuser2@fecredit.com.vn',
            EmailEncodingKey='UTF-8', LastName='Testing2', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='testuser2_fec@fecredit.com.vn'
        );
        insert new List<User>{testUser1, testUser2};

        // 3. Khởi tạo các bản ghi FEC_Assignment__c ban đầu
        
        // Bản ghi 1: Loại ROUTING thuộc Case 1
        FEC_Assignment__c assignRouting = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'Routing Assignment Test', // Thêm dòng này
            FEC_Case__c = testCase1.Id,
            FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
            FEC_Assignment_Owner__c = testUser1.Id
        );

        // Bản ghi 2: Loại GENERAL (Thủ công) thuộc Case 2
        FEC_Assignment__c assignGeneral = new FEC_Assignment__c(
            FEC_Assignment_Name__c = 'General Assignment Test', // Thêm dòng này
            FEC_Case__c = testCase2.Id,
            FEC_Assignment_Type__c = 'General', 
            FEC_Assignment_Owner__c = testUser1.Id
        );

        insert new List<FEC_Assignment__c>{assignRouting, assignGeneral};
    }

    /**
     * Kịch bản 1: Cập nhật Owner của bản ghi có loại 'ROUTING'.
     * Mong đợi: Trường FEC_Assignment_Users__c trên Case được cập nhật chuỗi User ID.
     */
    @IsTest
    static void testUpdateOwner_RoutingAssignment_Success() {
        Case c1 = [SELECT Id FROM Case WHERE Subject = 'Test Case 1' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Alias = 'usr2' LIMIT 1];
        FEC_Assignment__c assign = [SELECT Id, FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE FEC_Case__c = :c1.Id LIMIT 1];

        Test.startTest();
        assign.FEC_Assignment_Owner__c = u2.Id;
        update assign;
        Test.stopTest();

        Case updatedCase = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c1.Id];
        System.assertNotEquals(null, updatedCase.FEC_Assignment_Users__c, 'Trường này không được null đối với loại Routing');
        System.assertEquals(String.valueOf(u2.Id), updatedCase.FEC_Assignment_Users__c, 'Mã User ID mới phải được đồng bộ chính xác');
    }

    /**
     * Kịch bản 2: Cập nhật Owner nhưng bản ghi thuộc loại khác (không phải 'ROUTING').
     * Mong đợi: Trường FEC_Assignment_Users__c trên Case bị set về null.
     */
    @IsTest
    static void testUpdateOwner_GeneralAssignment_SetsNull() {
        Case c2 = [SELECT Id FROM Case WHERE Subject = 'Test Case 2' LIMIT 1];
        User u2 = [SELECT Id FROM User WHERE Alias = 'usr2' LIMIT 1];
        FEC_Assignment__c assign = [SELECT Id, FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE FEC_Case__c = :c2.Id LIMIT 1];

        Test.startTest();
        assign.FEC_Assignment_Owner__c = u2.Id;
        update assign;
        Test.stopTest();

        Case updatedCase = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c2.Id];
        System.assertEquals(null, updatedCase.FEC_Assignment_Users__c, 'Trường này phải set bằng null khi không có Routing assignment nào');
    }

    /**
     * Kịch bản 3: Cập nhật một trường bất kỳ trên Assignment nhưng KHÔNG thay đổi Owner.
     * Mong đợi: Trigger nhận biết được và dừng sớm (Bypass), không thực hiện câu lệnh cập nhật Case nào.
     */
    @IsTest
    static void testUpdateOtherField_NoOwnerChange_Bypassed() {
        Case c1 = [SELECT Id FROM Case WHERE Subject = 'Test Case 1' LIMIT 1];
        FEC_Assignment__c assign = [SELECT Id, FEC_Manual__c FROM FEC_Assignment__c WHERE FEC_Case__c = :c1.Id LIMIT 1];

        c1.FEC_Assignment_Users__c = null;
        update c1;

        Test.startTest();
        assign.FEC_Manual__c = true;
        update assign;
        Test.stopTest();

        Case updatedCase = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c1.Id];
        System.assertEquals(null, updatedCase.FEC_Assignment_Users__c, 'Trường này phải giữ nguyên vì trigger đã bypass do không đổi Owner');
    }

    /**
     * Kịch bản 4: Trường hợp đặc biệt khi gán Routing Assignment cho một Queue (Owner = null nhưng có tên Queue ở FEC_OwnerID__c).
     * Mong đợi: Đồng bộ tên của Queue (FEC_OwnerID__c) vào trường text của Case.
     */
    @IsTest
    static void testUpdateOwner_RoutingToQueue_Success() {
        Case c1 = [SELECT Id FROM Case WHERE Subject = 'Test Case 1' LIMIT 1];
        FEC_Assignment__c assign = [SELECT Id, FEC_Assignment_Owner__c, FEC_OwnerID__c FROM FEC_Assignment__c WHERE FEC_Case__c = :c1.Id LIMIT 1];

        Test.startTest();
        assign.FEC_Assignment_Owner__c = null;
        assign.FEC_OwnerID__c = 'FEC_Test_Queue_Name';
        update assign;
        Test.stopTest();

        Case updatedCase = [SELECT Id, FEC_Assignment_Users__c FROM Case WHERE Id = :c1.Id];
        System.assertEquals('FEC_Test_Queue_Name', updatedCase.FEC_Assignment_Users__c, 'Phải lưu tên Queue khi OwnerId bằng null');
    }
}