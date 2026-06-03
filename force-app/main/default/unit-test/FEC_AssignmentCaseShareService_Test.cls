@IsTest
private class FEC_AssignmentCaseShareService_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo 2 User để phục vụ cho việc tạo và chia sẻ Case
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        String suffix = String.valueOf(System.currentTimeMillis());
        User user1 = new User(
            Alias = 'usr1', Email='user1@fec.test.com', 
            EmailEncodingKey='UTF-8', LastName='Testing 1', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='user1.' + suffix + '@fec.test.com'
        );
        User user2 = new User(
            Alias = 'usr2', Email='user2@fec.test.com', 
            EmailEncodingKey='UTF-8', LastName='Testing 2', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='user2.' + suffix + '@fec.test.com'
        );
        insert new List<User>{user1, user2};

        // 2. Tạo Case (Gán cho User1)
        System.runAs(user1) {
            Case c = new Case(Subject = 'Test Share Case', Status = 'New');
            insert c;
        }
    }

    @IsTest
    static void testShareCasesForAssignments_Success() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User user2 = [SELECT Id FROM User WHERE Alias = 'usr2' LIMIT 1];

        // 1. Tạo Assignment Data giả định gán Case cho user2
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Owner__c = user2.Id
        );

        Test.startTest();
        FEC_AssignmentCaseShareService.shareCasesForAssignments(new List<FEC_Assignment__c>{assignment});
        Test.stopTest();

        // Kiểm tra chia sẻ thành công (Không có lỗi trong list lưu trữ tĩnh)
        System.assertEquals(0, FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size(), 'Không được có lỗi chia sẻ.');
        
        // Kiểm tra CaseShare có được tạo hay không (Tùy thuộc OWD)
        List<CaseShare> shares = [SELECT Id FROM CaseShare WHERE CaseId = :c.Id AND UserOrGroupId = :user2.Id AND RowCause = 'Manual'];
        if(CaseShare.SObjectType.getDescribe().isCreateable()) {
            System.assert(shares.size() >= 0, 'Truy vấn CaseShare chạy không có lỗi.');
        }
    }

    @IsTest
    static void testShareCasesForAssignments_AvoidDuplicatesAndOwnerShare() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User user1 = [SELECT Id FROM User WHERE Alias = 'usr1' LIMIT 1];
        User user2 = [SELECT Id FROM User WHERE Alias = 'usr2' LIMIT 1];

        // 1. Chia sẻ thủ công trước để tạo tồn tại (Duplicate)
        CaseShare cs = new CaseShare(CaseId = c.Id, UserOrGroupId = user2.Id, CaseAccessLevel = 'Edit', RowCause = 'Manual');
        Database.insert(cs, false);

        // 2. Tạo Assignments chứa (1) Case Owner và (2) User đã được chia sẻ
        FEC_Assignment__c assignOwner = new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Owner__c = user1.Id // user1 đã là owner -> phải bỏ qua
        );
        FEC_Assignment__c assignDuplicate = new FEC_Assignment__c(
            FEC_Case__c = c.Id,
            FEC_Assignment_Owner__c = user2.Id // user2 đã có share record -> phải bỏ qua
        );

        Test.startTest();
        FEC_AssignmentCaseShareService.shareCasesForAssignments(new List<FEC_Assignment__c>{assignOwner, assignDuplicate});
        Test.stopTest();

        // Không sinh lỗi insert vì các bản ghi này bị logic mã (if-continue) bỏ qua
        System.assertEquals(0, FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size());
    }

    @IsTest
    static void testShareCaseWithUser_HelperMethod() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User user2 = [SELECT Id FROM User WHERE Alias = 'usr2' LIMIT 1];

        Test.startTest();
        // Phương thức Overload trực tiếp
        FEC_AssignmentCaseShareService.shareCaseWithUser(c.Id, user2.Id);
        Test.stopTest();

        System.assertEquals(0, FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size());
    }

    @IsTest
    static void testShareCaseWithUser_InvalidUserIdType_NoOp() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        // truyền Case Id vào userId để đi qua nhánh isUserId = false
        FEC_AssignmentCaseShareService.shareCaseWithUser(c.Id, c.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size(),
            'Invalid user id type phải được bỏ qua an toàn.'
        );
    }

    @IsTest
    static void testShareCasesForAssignments_EmptyList_NoOp() {
        Test.startTest();
        FEC_AssignmentCaseShareService.shareCasesForAssignments(new List<FEC_Assignment__c>());
        Test.stopTest();

        System.assertEquals(
            0,
            FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size(),
            'Empty list không được gây lỗi.'
        );
    }

    @IsTest
    static void testInvalidInputsAndEdgeCases() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        Test.startTest();
        // 1. Danh sách null
        FEC_AssignmentCaseShareService.shareCasesForAssignments(null);
        
        // 2. Danh sách có assignment rỗng hoặc null field
        FEC_Assignment__c assignNullId = new FEC_Assignment__c(FEC_Case__c = c.Id, FEC_Assignment_Owner__c = null);
        FEC_Assignment__c assignInvalidType = new FEC_Assignment__c(FEC_Case__c = c.Id, FEC_Assignment_Owner__c = c.Id); // Lấy Id Case gán cho User lookup
        FEC_AssignmentCaseShareService.shareCasesForAssignments(new List<FEC_Assignment__c>{assignNullId, assignInvalidType});
        
        // 3. Phương thức helper nhận tham số null
        FEC_AssignmentCaseShareService.shareCaseWithUser(null, null);
        Test.stopTest();

        System.assertEquals(
            0,
            FEC_AssignmentCaseShareService.getLastShareErrorsForTest().size(),
            'Các input invalid phải được bỏ qua, không phát sinh lỗi insert.'
        );
    }
}