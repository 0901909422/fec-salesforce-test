@IsTest
private class FEC_CaseAssignmentConfigController_Test {

    @TestSetup
    static void setupData() {
        UserRole roleAgentA = new UserRole(DeveloperName = 'CS_Agent_A', Name = 'CS Agent A');
        UserRole roleAgentB = new UserRole(DeveloperName = 'CS_Agent_B', Name = 'CS Agent B');
        insert new List<UserRole>{ roleAgentA, roleAgentB };

        Group testQueue = new Group(Name = 'Queue CS Support', Type = 'Queue');
        insert testQueue;
        testQueue = [SELECT Id, DeveloperName FROM Group WHERE Id = :testQueue.Id];

        QueueSobject mappingObject = new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert mappingObject;
        }

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User userA = new User(
            Alias = 'cfgAgtA',
            Email = 'cfg.agent.a@fecredit.com.vn',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CfgAgentA',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'cfg.agent.a@fecredit.com.vn.test',
            UserRoleId = roleAgentA.Id
        );
        User userB = new User(
            Alias = 'cfgAgtB',
            Email = 'cfg.agent.b@fecredit.com.vn',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CfgAgentB',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'cfg.agent.b@fecredit.com.vn.test',
            UserRoleId = roleAgentB.Id
        );
        insert new List<User>{ userA, userB };

        insert new List<GroupMember>{
            new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userA.Id),
            new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userB.Id)
        };

        FEC_Team__c team = new FEC_Team__c(Name = 'CS Support Team');
        insert team;
        insert new FEC_Team_Queue__c(
            FEC_Queue_Name__c = testQueue.DeveloperName,
            FEC_Select_Team__c = team.Id
        );
    }

    /**
     * Kịch bản 1: Kiểm tra hàm lấy danh sách các hàng đợi Case đang hoạt động (getActiveCaseQueues).
     * Mong đợi: Hệ thống bốc chính xác dữ liệu từ bảng QueueSobject, tự động sắp xếp alphabet theo tên hàng đợi và trả về DTO.
     */
    @IsTest
    static void testGetActiveCaseQueues_Success() {
        Test.startTest();
        List<FEC_CaseAssignmentConfigController.OptionItem> queueOptions = FEC_CaseAssignmentConfigController.getActiveCaseQueues();
        Test.stopTest();

        System.assertNotEquals(null, queueOptions, 'Danh sách trả về không được phép null.');
        System.assert(queueOptions.size() > 0, 'Hệ thống phải trích xuất được ít nhất 1 hàng đợi Case.');

        Boolean foundTestQueue = false;
        for (FEC_CaseAssignmentConfigController.OptionItem item : queueOptions) {
            if (item.label == 'Queue CS Support') {
                foundTestQueue = true;
                System.assertEquals('Queue CS Support', item.value);
            }
        }
        System.assert(foundTestQueue, 'Phải có hàng đợi Queue CS Support từ @TestSetup.');
    }

    /**
     * Kịch bản 2: Kiểm tra hàm lấy danh sách tùy chọn vai trò theo tên hàng đợi chỉ định (getRoleOptions).
     * Mong đợi: Gửi danh sách tên Queue hợp lệ, tiến trình phân giải chéo qua lớp Resolver dùng chung diễn ra mượt mà và trả về danh sách picklist.
     */
    @IsTest
    static void testGetRoleOptions_Success() {
        List<String> testQueueNames = new List<String>{ '  Queue CS Support  ', '' };

        Test.startTest();
        List<FEC_CaseAssignmentConfigController.OptionItem> roleOptions =
            FEC_CaseAssignmentConfigController.getRoleOptions(testQueueNames);
        Test.stopTest();

        System.assertNotEquals(null, roleOptions);
        System.assert(roleOptions.size() >= 2, 'Resolver phải trả về role từ User trong Queue.');

        Set<String> roleLabels = new Set<String>();
        for (FEC_CaseAssignmentConfigController.OptionItem item : roleOptions) {
            roleLabels.add(item.label);
            System.assertEquals(item.label, item.value);
        }
        System.assert(roleLabels.contains('CS Agent A'));
        System.assert(roleLabels.contains('CS Agent B'));
    }

    /**
     * Kịch bản 3: Kiểm tra các nhánh rẽ biên chặn lỗi dữ liệu rỗng đầu vào của hàm getRoleOptions (Guard Clauses).
     * Bao phủ: Tham số mảng List nhận giá trị null, mảng rỗng `[]`, hoặc mảng chỉ chứa toàn chuỗi trống.
     */
    @IsTest
    static void testGetRoleOptions_EmptyAndNullInputs() {
        Test.startTest();
        // Nhánh biên 1: Tham số mảng nhận giá trị null hoàn toàn
        List<FEC_CaseAssignmentConfigController.OptionItem> resNull = FEC_CaseAssignmentConfigController.getRoleOptions(null);
        
        // Nhánh biên 2: Tham số mảng rỗng []
        List<FEC_CaseAssignmentConfigController.OptionItem> resEmptyList = FEC_CaseAssignmentConfigController.getRoleOptions(new List<String>());

        // Nhánh biên 3: Mảng có phần tử nhưng nội dung chỉ chứa toàn chuỗi trống/null ký tự
        List<FEC_CaseAssignmentConfigController.OptionItem> resBlankStrings = FEC_CaseAssignmentConfigController.getRoleOptions(new List<String>{ '', '   ' });
        Test.stopTest();

        // Khẳng định hệ thống thoát sớm an toàn và trả về mảng rỗng size == 0
        System.assertEquals(0, resNull.size());
        System.assertEquals(0, resEmptyList.size());
        System.assertEquals(0, resBlankStrings.size());
    }

    /**
     * Kịch bản 4: Kiểm tra hàm lấy danh sách tùy chọn khung giờ làm việc hệ thống (getBusinessHourOptions).
     * Mong đợi: Quét toàn bộ bảng BusinessHours tiêu chuẩn của Salesforce, ưu tiên đưa múi giờ mặc định lên đầu mảng (`ORDER BY IsDefault DESC`).
     */
    @IsTest
    static void testGetBusinessHourOptions_Success() {
        Test.startTest();
        List<FEC_CaseAssignmentConfigController.OptionItem> bhOptions = FEC_CaseAssignmentConfigController.getBusinessHourOptions();
        Test.stopTest();

        // Do đối tượng BusinessHours luôn tồn tại sẵn ít nhất 1 bản ghi mặc định trên mọi Org Salesforce, 
        // mảng kết quả thu về bắt buộc phải có dữ liệu.
        System.assertNotEquals(null, bhOptions);
        System.assert(bhOptions.size() > 0, 'Hệ thống phải bốc lên thành công danh sách giờ làm việc cấu hình của Org.');
        System.assertNotEquals(null, bhOptions[0].label);
        System.assertNotEquals(null, bhOptions[0].value, 'Trường value phải giữ chuỗi ID của bản ghi BusinessHours.');
    }
}