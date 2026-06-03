@IsTest
private class FEC_CaseAssignmentQueueRoleResolver_Test {

    @TestSetup
    static void setupData() {
        // 1. Dựng cấu trúc cây phân cấp vai trò UserRole (Cha -> Con) để test hàm đệ quy addDescendantUserRoleIds
        UserRole parentRole = new UserRole(DeveloperName = 'CS_Manager_Role', Name = 'CS Manager');
        insert parentRole;

        UserRole childRole = new UserRole(DeveloperName = 'CS_Agent_Role', Name = 'CS Agent', ParentRoleId = parentRole.Id);
        insert childRole;

        // 2. Tạo hàng đợi hệ thống (Group) đóng vai trò điều phối bản ghi Case
        Group testQueue = new Group(Name = 'Queue CS Resolver Support', Type = 'Queue');
        insert testQueue;

        // Thiết lập liên kết đối tượng Case cho Queue thông qua QueueSobject
        QueueSobject mappingObject = new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
        
        // Thực thi việc chèn bản ghi hệ thống dưới context User hiện tại để tránh lỗi Mixed DML
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert mappingObject;
        }

        // 3. Tạo một Group phụ thông thường để giả lập cấu trúc nhóm lồng nhau (Sub-Groups lặp qua vòng while)
        Group subGroup = new Group(Name = 'Sub Group Operational Members', Type = 'Regular');
        insert subGroup;

        // 4. Lấy Profile chuẩn để tạo User mồi liên kết với vai trò con
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User agentUser = new User(
            Alias = 'resAgnt', Email = 'agent.resolver@fecredit.com.vn', EmailEncodingKey = 'UTF-8',
            LastName = 'ResolverAgent', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'agent.resolver.test@fecredit.com.vn',
            UserRoleId = childRole.Id
        );
        insert agentUser;

        // 5. Thiết lập sơ đồ thành viên đa tầng (GroupMember Mapping)
        // Thành viên 1: Gắn User trực tiếp vào Sub-Group
        GroupMember gmUserToSubGroup = new GroupMember(GroupId = subGroup.Id, UserOrGroupId = agentUser.Id);
        // Thành viên 2: Gắn Sub-Group lồng vào làm thành viên của Queue chính
        GroupMember gmSubGroupToQueue = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = subGroup.Id);
        insert new List<GroupMember>{gmUserToSubGroup, gmSubGroupToQueue};
    }

    /**
     * Kịch bản 1: Kiểm tra hàm ensureQueueIds với các nhánh rẽ tham số thô khác nhau.
     * Bao phủ: Trích xuất mảng sơ bộ có sẵn (preliminaryIds) và luồng chạy câu lệnh SOQL quét tên Queue khi mảng sơ bộ trống.
     */
    @IsTest
    static void testEnsureQueueIds_AllBranches() {
        Group mainQueue = [SELECT Id FROM Group WHERE Name = 'Queue CS Resolver Support' LIMIT 1];
        Set<String> queueNames = new Set<String>{ 'Queue CS Resolver Support' };
        Set<Id> preliminaryIds = new Set<Id>{ mainQueue.Id };

        Test.startTest();
        Set<Id> resWithPreliminary =
            FEC_CaseAssignmentQueueRoleResolver.ensureQueueIds(queueNames, preliminaryIds);
        Set<Id> resWithSoql = FEC_CaseAssignmentQueueRoleResolver.ensureQueueIds(queueNames, null);
        Test.stopTest();

        System.assertEquals(1, resWithPreliminary.size());
        System.assert(resWithPreliminary.contains(mainQueue.Id));
        System.assertEquals(1, resWithSoql.size());
        System.assert(resWithSoql.contains(mainQueue.Id));
    }

    /**
     * Kịch bản 2: Kiểm tra toàn bộ chuỗi phân tích thành viên và dựng danh sách Picklist hoàn chỉnh (buildPicklist).
     * Bao phủ: Vòng lặp while xử lý nhóm lồng nhau (Sub-Groups), trích xuất ID người dùng (`User.SObjectType`), trích xuất mã vai trò, sắp xếp bảng chữ cái tên vai trò.
     */
    @IsTest
    static void testBuildPicklist_WithSubGroupsAndUsers() {
        Group mainQueue = [SELECT Id FROM Group WHERE Name = 'Queue CS Resolver Support' LIMIT 1];
        Set<Id> queueIds = new Set<Id>{ mainQueue.Id };

        Test.startTest();
        List<FEC_CaseAssignmentConfigController.OptionItem> options = FEC_CaseAssignmentQueueRoleResolver.buildPicklist(queueIds);
        Test.stopTest();

        // Khẳng định kết quả bóc tách thành viên đệ quy đa tầng
        System.assertNotEquals(null, options);
        System.assert(options.size() > 0, 'Hệ thống phải quét xuyên qua cấu trúc nhóm lồng để tìm ra vai trò CS Agent của User mồi.');
        System.assertEquals('CS Agent', options[0].label, 'Tên nhãn vai trò trích xuất được phải trùng khớp.');
    }

    /**
     * Kịch bản 3: Kiểm tra luồng giải quyết hàng đợi chứa các nhóm đại diện cho Phân cấp vai trò hệ thống (Role-backed Groups).
     * Bao phủ: Nhánh rẽ quét qua các Group mang thuộc tính `Type = 'Role'` hoặc `Type = 'RoleAndSubordinates'` (Bao phủ hàm đệ quy addDescendantUserRoleIds).
     */
    @IsTest
    static void testBuildPicklist_WithRoleBackedGroups() {
        UserRole managerRole = [SELECT Id FROM UserRole WHERE Name = 'CS Manager' LIMIT 1];
        
        // Trong kiến trúc hạ tầng Salesforce, khi một UserRole được tạo, hệ thống tự động sinh ra các nhóm Group Setup ngầm 
        // đại diện cho vai trò đó (Mang Type = 'Role' hoặc 'RoleAndSubordinates') liên kết qua trường RelatedId.
        // Chúng ta thực hiện SOQL bốc nhóm Setup ngầm này lên để nạp trực tiếp đầu vào hàm walk.
        List<Group> roleSetupGroups = [
            SELECT Id
            FROM Group
            WHERE RelatedId = :managerRole.Id AND (Type = 'Role' OR Type LIKE 'RoleAnd%')
        ];

        if (!roleSetupGroups.isEmpty()) {
            Set<Id> setupGroupIds = new Set<Id>();
            for (Group g : roleSetupGroups) {
                setupGroupIds.add(g.Id);
            }

            Test.startTest();
            // Gọi hàm buildPicklist truyền trực tiếp danh sách ID nhóm Setup của Role
            List<FEC_CaseAssignmentConfigController.OptionItem> options = FEC_CaseAssignmentQueueRoleResolver.buildPicklist(setupGroupIds);
            Test.stopTest();

            System.assertNotEquals(null, options);
        }
    }

    /**
     * Kịch bản 4: Kiểm tra các tầng bảo vệ biên chặn lỗi tham số trống đầu vào (Guard Clauses).
     * Bao phủ: Truyền tham số cấu trúc null hoặc mảng tập hợp rỗng `isEmpty()`.
     */
    @IsTest
    static void testBuildPicklist_GuardClausesAndEmptyChecks() {
        Test.startTest();
        // Nhánh biên 1: Tham số Id truyền vào nhận giá trị null hoàn toàn
        List<FEC_CaseAssignmentConfigController.OptionItem> resNull = FEC_CaseAssignmentQueueRoleResolver.buildPicklist(null);
        
        // Nhánh biên 2: Tham số mảng tập hợp rỗng []
        List<FEC_CaseAssignmentConfigController.OptionItem> resEmpty = FEC_CaseAssignmentQueueRoleResolver.buildPicklist(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, resNull.size());
        System.assertEquals(0, resEmpty.size(), 'Tham số trống phải lập tức thoát sớm và trả về mảng kết quả trống.');
    }
}