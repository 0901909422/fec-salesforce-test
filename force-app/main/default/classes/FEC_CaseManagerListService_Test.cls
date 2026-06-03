@IsTest
private class FEC_CaseManagerListService_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo Cấu trúc cây phân cấp Role Hierarchy (Grandparent -> Parent -> Child)
        UserRole grandParentRole = new UserRole(DeveloperName = 'Grand_Parent_Role', Name = 'Director Level');
        insert grandParentRole;

        UserRole parentRole = new UserRole(DeveloperName = 'Parent_Role', Name = 'Manager Level', ParentRoleId = grandParentRole.Id);
        insert parentRole;

        UserRole childRole = new UserRole(DeveloperName = 'Child_Role', Name = 'Agent Level', ParentRoleId = parentRole.Id);
        insert childRole;

        UserRole isolatedRole = new UserRole(DeveloperName = 'Isolated_Role', Name = 'Isolated Level'); // Vai trò không có Parent
        insert isolatedRole;

        // 2. Tạo User tương ứng với các Role
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());

        User grandParentUser = new User(
            Alias = 'grandP', Email = 'grand.parent' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'GrandParent', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'grand.parent.exec' + suffix + '@test.invalid',
            UserRoleId = grandParentRole.Id, IsActive = true
        );
        User parentUser1 = new User(
            Alias = 'parent1', Email = 'parent1' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Parent1', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'parent1.exec' + suffix + '@test.invalid',
            UserRoleId = parentRole.Id, IsActive = true
        );
        User parentUser2 = new User(
            Alias = 'parent2', Email = 'parent2' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Parent2', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'parent2.exec' + suffix + '@test.invalid',
            UserRoleId = parentRole.Id, IsActive = true
        );
        User childUser = new User(
            Alias = 'child', Email = 'child' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'ChildAgent', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'child.exec' + suffix + '@test.invalid',
            UserRoleId = childRole.Id, IsActive = true
        );
        User isolatedUser = new User(
            Alias = 'isolate', Email = 'isolated' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'Isolated', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'isolated.exec' + suffix + '@test.invalid',
            UserRoleId = isolatedRole.Id, IsActive = true
        );
        insert new List<User>{grandParentUser, parentUser1, parentUser2, childUser, isolatedUser};

        // 3. Tạo Queue Hệ thống để kiểm tra luồng xóa Manager CSV
        Group testQueue = new Group(Name = 'Queue CS Test', Type = 'Queue');
        insert testQueue;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            QueueSobject qs = new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
            insert qs;
        }

        // 4. Case mồi — tránh MIXED_DML sau UserRole; tắt trigger insert để gán FEC_ID_Search__c unique
        System.runAs(childUser) {
            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert new List<Case>{
                    new Case(
                        Subject = 'Case Owned by Child', OwnerId = childUser.Id, Status = 'New',
                        FEC_ID_Search__c = 'MGR-CHILD-' + suffix
                    ),
                    new Case(
                        Subject = 'Case Owned by Isolated', OwnerId = isolatedUser.Id, Status = 'New',
                        FEC_ID_Search__c = 'MGR-ISO-' + suffix
                    ),
                    new Case(
                        Subject = 'Case Owned by Queue', OwnerId = testQueue.Id, Status = 'New',
                        FEC_ID_Search__c = 'MGR-QUEUE-' + suffix
                    )
                };
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }
        }
    }

    /**
     * Kịch bản 1: Kiểm tra luồng đồng bộ từ Owner trên Case (syncFromOwnerCases) - Khi Owner là User có Role.
     * Mong đợi: Tính toán cây Role cấp trên thành CSV và cập nhật xuống trường FEC_Manager_ID_List__c.
     */
    @IsTest
    static void testSyncFromOwnerCases_UserWithHierarchy() {
        Case c = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Case Owned by Child' LIMIT 1];
        
        // Mô phỏng Trigger context truyền biến oldMap
        Map<Id, Case> oldMap = new Map<Id, Case>{ c.Id => new Case(Id = c.Id, OwnerId = UserInfo.getUserId()) }; // Giả lập OwnerId cũ khác biệt để pass khối lệnh `continue;`
        List<Case> newCases = new List<Case>{ c };

        Test.startTest();
        FEC_CaseManagerListService.syncFromOwnerCases(newCases, oldMap);
        Test.stopTest();

        // Xác minh giá trị CSV Managers
        Case updatedCase = [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, updatedCase.FEC_Manager_ID_List__c, 'Danh sách Manager CSV không được rỗng.');
        
        // Xác minh CSV chứa ID của cả 2 User thuộc cấp Parent (parent1, parent2) và 1 User cấp Grandparent
        List<String> managerIds = updatedCase.FEC_Manager_ID_List__c.split(',');
        System.assertEquals(3, managerIds.size(), 'Cây phân cấp phía trên có tổng cộng 3 Users hợp lệ.');
    }

    /**
     * Kịch bản 2: Đồng bộ từ Owner trên Case - Khi Owner là Queue hoặc User KHÔNG CÓ Parent Role.
     * Mong đợi: Cập nhật xóa sạch dữ liệu trường FEC_Manager_ID_List__c về `null`.
     */
    @IsTest
    static void testSyncFromOwnerCases_QueueAndIsolatedUser() {
        Case caseQueue = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Case Owned by Queue' LIMIT 1];
        Case caseIsolated = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Case Owned by Isolated' LIMIT 1];
        
        List<Case> newCases = new List<Case>{ caseQueue, caseIsolated };
        // Không truyền oldMap để ép luồng chạy như Insert
        
        Test.startTest();
        FEC_CaseManagerListService.syncFromOwnerCases(newCases, null);
        Test.stopTest();

        // Xác minh cả 2 Case đều nhận giá trị null vì không truy xuất được ParentRole
        Case updatedQueueCase = [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :caseQueue.Id];
        Case updatedIsolatedCase = [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :caseIsolated.Id];
        
        System.assertEquals(null, updatedQueueCase.FEC_Manager_ID_List__c, 'Owner là Queue phải dọn sạch chuỗi CSV thành null.');
        System.assertEquals(null, updatedIsolatedCase.FEC_Manager_ID_List__c, 'Owner là User không có Parent Role phải dọn sạch chuỗi CSV thành null.');
    }

    /**
     * Kịch bản 3: Đồng bộ lại sau khi tạo Lịch sử định tuyến (applyAfterRoutingHistoryInsert).
     * Mong đợi: SOQL lấy lại danh sách Case từ ID của History và gọi hàm `syncFromOwnerCases`.
     */
    @IsTest
    static void testApplyAfterRoutingHistoryInsert_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case Owned by Child' LIMIT 1];
        
        // Khởi tạo một mảng giả lập FEC_Routing_Action_History__c mới
        List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c(FEC_Case__c = c.Id, FEC_Routing_Action__c = 'Route to')
        };
        
        Test.startTest();
        FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(histories);
        
        // Truyền mảng rỗng và mảng chứa caseId null để test Guard Clause đầu vào
        FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(new List<FEC_Routing_Action_History__c>{ new FEC_Routing_Action_History__c(FEC_Case__c = null) });
        FEC_CaseManagerListService.applyAfterRoutingHistoryInsert(null);
        Test.stopTest();

        // Hành động thành công sẽ tự động Update CSV xuống Database, ta tái khẳng định trường đó
        Case updatedCase = [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, updatedCase.FEC_Manager_ID_List__c);
    }

    /**
     * Kịch bản 4: Kích hoạt đồng bộ lại hàng loạt (recalculateForCaseIds) - Tính năng Backfill.
     * Mong đợi: Cập nhật an toàn dựa trên mảng Set ID Case.
     */
    @IsTest
    static void testRecalculateForCaseIds_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Case Owned by Child' LIMIT 1];
        Set<Id> targetIds = new Set<Id>{ c.Id };

        Test.startTest();
        FEC_CaseManagerListService.recalculateForCaseIds(targetIds);
        
        // Gọi kèm nhánh Set null và Set rỗng để test bẫy Guard Clause
        FEC_CaseManagerListService.recalculateForCaseIds(null);
        FEC_CaseManagerListService.recalculateForCaseIds(new Set<Id>());
        Test.stopTest();

        System.assertNotEquals(null, [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :c.Id].FEC_Manager_ID_List__c);
    }

    /**
     * Kịch bản 5: Hàm bẫy vòng lặp đệ quy cây Role (collectAncestorRoleIdsOrdered - Break loop mechanism).
     * Mặc dù ta không thể tạo một vòng lặp vĩnh cửu thực tế ở tầng DML trên Role, ta có thể kiểm tra biên giới bẫy vòng lặp và lỗi đầu vào rỗng.
     */
    @IsTest
    static void testBuildManagerIdListCsv_EdgeCasesAndExceptions() {
        Test.startTest();
        // 1. Gửi giá trị null hoặc ID ma
        String resNull = FEC_CaseManagerListService.buildManagerIdListCsv(null);
        String resFakeId = FEC_CaseManagerListService.buildManagerIdListCsv('005000000000001AAA'); // ID User ảo
        String resGroupId = FEC_CaseManagerListService.buildManagerIdListCsv('00G000000000001AAA'); // Truyền ID Group

        // 2. Gửi giá trị cho User không tồn tại Role nào (System Admin mặc định hoặc tương tự)
        String suffix = String.valueOf(System.currentTimeMillis());
        User systemAdminUser = new User(
            Alias = 'adminX', Email = 'admin' + suffix + '@test.invalid', EmailEncodingKey = 'UTF-8',
            LastName = 'AdminX', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'admin.test.exec' + suffix + '@test.invalid'
        );
        insert systemAdminUser;
        String resNoRoleUser = FEC_CaseManagerListService.buildManagerIdListCsv(systemAdminUser.Id);

        Test.stopTest();

        System.assertEquals(null, resNull);
        System.assertEquals(null, resFakeId);
        System.assertEquals(null, resGroupId);
        System.assertEquals(null, resNoRoleUser, 'User không gắn UserRoleId phải trả về mảng CSV null.');
    }

    /**
     * Kịch bản 6: Khẳng định tính không trùng lặp và bỏ qua trường hợp Same Owner Update.
     */
    @IsTest
    static void testSyncFromOwnerCases_SkipSameOwnerLogic() {
        Case c = [SELECT Id, OwnerId FROM Case WHERE Subject = 'Case Owned by Child' LIMIT 1];
        
        // Mô phỏng Trigger context truyền biến oldMap chứa CHÍNH XÁC cùng OwnerId
        Map<Id, Case> oldMap = new Map<Id, Case>{ c.Id => new Case(Id = c.Id, OwnerId = c.OwnerId) };
        List<Case> newCases = new List<Case>{ c };

        Test.startTest();
        FEC_CaseManagerListService.syncFromOwnerCases(newCases, oldMap);
        Test.stopTest();

        // Do dính nhánh chặn `c.OwnerId == oldC.OwnerId`, danh sách toUpdate sẽ trống và KHÔNG thực thi DML xuống Database
        // Trường CSV vẫn giữ nguyên định dạng rỗng (null) tạo từ khâu Setup
        System.assertEquals(null, [SELECT FEC_Manager_ID_List__c FROM Case WHERE Id = :c.Id].FEC_Manager_ID_List__c);
    }
}