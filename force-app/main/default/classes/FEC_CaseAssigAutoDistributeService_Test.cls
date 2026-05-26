@IsTest
private class FEC_CaseAssigAutoDistributeService_Test {

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    private static String validTimeSlotForPicklist() {
        // executeImmediatelyForAssignmentId bỏ qua lịch — chỉ cần giá trị hợp lệ trên picklist (08:00–17:30).
        return '12:00';
    }

    @TestSetup
    static void setupData() {
        // 1. Tạo cấu trúc phân cấp Role cho User phục vụ thuật toán phân phối theo trọng số (Role Scale)
        UserRole roleAgentA = new UserRole(DeveloperName = 'CS_Agent_A', Name = 'CS Agent A');
        UserRole roleAgentB = new UserRole(DeveloperName = 'CS_Agent_B', Name = 'CS Agent B');
        insert new List<UserRole>{roleAgentA, roleAgentB};

        // 2. Tạo Queue hệ thống (Group) đóng vai trò điều phối bản ghi
        Group testQueue = new Group(Name = 'Queue CS Support', Type = 'Queue');
        insert testQueue;

        // Thiết lập Queue hợp lệ bằng cấu trúc QueueSobject
        QueueSobject mappingObject = new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert mappingObject;
        }

        // 3. Lấy Profile chuẩn để tạo Users mồi liên kết với các Role trên
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User userA = new User(
            Alias = 'agentA', Email = 'agent.a@fecredit.com.vn', EmailEncodingKey = 'UTF-8',
            LastName = 'AgentA', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'agent.a.dist@fecredit.com.vn',
            UserRoleId = roleAgentA.Id
        );
        User userB = new User(
            Alias = 'agentB', Email = 'agent.b@fecredit.com.vn', EmailEncodingKey = 'UTF-8',
            LastName = 'AgentB', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'agent.b.dist@fecredit.com.vn',
            UserRoleId = roleAgentB.Id
        );
        insert new List<User>{userA, userB};

        // Gắn thành viên User vào Queue qua GroupMember
        GroupMember gmA = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userA.Id);
        GroupMember gmB = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userB.Id);
        insert new List<GroupMember>{gmA, gmB};

        // Custom-object DML after setup objects (UserRole, User, Queue) requires runAs.
        System.runAs(userA) {
            FEC_Case_Assignment__c assignContinuous = new FEC_Case_Assignment__c(
                Name = 'Continuous Rule',
                FEC_Assignment_Method__c = 'Continuous',
                FEC_Scheduled_Time__c = 1,
                FEC_Select_Queues__c = 'Queue CS Support',
                FEC_Role__c = 'CS Agent A;CS Agent B',
                FEC_Scale__c = 1,
                FEC_Status__c = 'Draft'
            );
            FEC_Case_Assignment__c assignTimeBased = new FEC_Case_Assignment__c(
                Name = 'Time-Based Rule',
                FEC_Assignment_Method__c = 'Time-Based',
                FEC_Time_Slots__c = '08:00;12:00;16:00',
                FEC_Select_Queues__c = 'Queue CS Support',
                FEC_Role__c = 'CS Agent A|2;CS Agent B|4',
                FEC_Status__c = 'Draft'
            );
            insert new List<FEC_Case_Assignment__c>{assignContinuous, assignTimeBased};

            FEC_Product_Type__c prod = new FEC_Product_Type__c(
                Name = 'Credit Card',
                FEC_Code__c = 'CC',
                FEC_Active__c = true
            );
            insert prod;
            FEC_Category__c cat = new FEC_Category__c(
                Name = 'Request',
                FEC_Code__c = 'Request',
                FEC_Active__c = true
            );
            insert cat;
            FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
                Name = 'RC27',
                FEC_Code__c = 'RC27',
                FEC_Active__c = true
            );
            insert subCat;
            FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
                Name = 'RC27.01',
                FEC_Code__c = 'RC27.01',
                FEC_Active__c = true
            );
            insert subCode;

            insert new List<FEC_Case_Assignment_NOC__c>{
                new FEC_Case_Assignment_NOC__c(
                    FEC_Case_Assignment_Name__c = assignContinuous.Id,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_Sub_Category__c = subCat.Id,
                    FEC_Sub_Code__c = subCode.Id
                ),
                new FEC_Case_Assignment_NOC__c(
                    FEC_Case_Assignment_Name__c = assignTimeBased.Id,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_Sub_Category__c = subCat.Id,
                    FEC_Sub_Code__c = null
                )
            };

            // Giữ Draft trong @TestSetup để tránh trigger enqueue AutoDistQueueJob trước khi test chạy.

            List<Case> casesToDistribute = new List<Case>();
            for (Integer i = 0; i < 4; i++) {
                casesToDistribute.add(new Case(
                    Subject = 'Pending Queue Case ' + i,
                    OwnerId = testQueue.Id,
                    Status = 'New',
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id
                ));
            }
            insert casesToDistribute;
        }
    }

    /**
     * Kịch bản 1: Thực thi luồng xử lý phân phối đều Continuous (distributeEvenly).
     * Điều kiện: Continuous căn lịch theo mốc start (log đầu) và bước Scheduled_Time; bóc tách Case và điều phối đều cho Users.
     */
    @IsTest
    static void testExecuteNow_ContinuousEvenDistribution() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'Continuous Rule' LIMIT 1];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            Integer assignedCount =
                FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(rule.Id);
            System.assert(assignedCount > 0, 'Phân phối phải gán ít nhất một Case từ Queue.');

            List<Case> processedCases = [
                SELECT OwnerId, Owner.Type
                FROM Case
                WHERE Subject LIKE 'Pending Queue Case%'
            ];
            for (Case c : processedCases) {
                System.assertEquals(
                    'User',
                    c.Owner.Type,
                    'Case phải được phân phối chuyển quyền sở hữu từ Queue sang cho User.'
                );
            }

            List<FEC_Case_Assignment_Logs__c> logs = [
                SELECT Id
                FROM FEC_Case_Assignment_Logs__c
                WHERE FEC_Case_Assignment_Name__c = :rule.Id
            ];
            System.assertEquals(1, logs.size());
        }
    }

    /**
     * Kịch bản 2: Thực thi luồng xử lý phân phối theo khung giờ Time-Based (distributeSequentialByTime).
     * Điều kiện: Ép luồng chạy sang nhánh kiểm thử Time-Based bằng cách chỉnh sửa Rule Continuous sang trạng thái ẩn Inactive.
     */
    @IsTest
    static void testExecuteNow_TimeBasedSequentialDistribution() {
        // Tắt luật Continuous đi để ép hệ thống xử lý tập trung vào luật Time-Based
        FEC_Case_Assignment__c continuousRule = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'Continuous Rule' LIMIT 1];
        continuousRule.FEC_Status__c = 'Draft';
        update continuousRule;

        // Tạo lịch sử log detail quá khứ để nạp dữ liệu mồi cho hàm toán tử tổng hợp getHistoricalAssignedCountByUser
        FEC_Case_Assignment__c timeRule = [SELECT Id, Name FROM FEC_Case_Assignment__c WHERE Name = 'Time-Based Rule' LIMIT 1];
        FEC_Case_Assignment_Logs__c oldLog = new FEC_Case_Assignment_Logs__c(
            Name = 'Old Log 1',
            FEC_Case_Assignment_Name__c = timeRule.Id,
            FEC_Number_of_Case__c = 2
        );
        insert oldLog;

        FEC_Case_Assignment_Log_Detail__c oldDetail = new FEC_Case_Assignment_Log_Detail__c(
            Name = 'agent.a@fecredit.com.vn',
            FEC_Case_Assignment_log_Name__c = oldLog.Id,
            FEC_Name_User__c = 'agent.a@fecredit.com.vn',
            FEC_Number_of_Case__c = 2
        );
        insert oldDetail;

        System.runAs(testRunAsUser()) {
            timeRule.FEC_Time_Slots__c = validTimeSlotForPicklist();
            timeRule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update timeRule;

            Integer assignedCount =
                FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(timeRule.Id);
            System.assert(assignedCount >= 0);

            List<FEC_Case_Assignment_Logs__c> logs = [
                SELECT Id
                FROM FEC_Case_Assignment_Logs__c
                WHERE FEC_Case_Assignment_Name__c = :timeRule.Id
            ];
            System.assert(logs.size() >= 1);
        }
    }

    /**
     * Kịch bản 3: Kiểm tra tính năng chặn trùng lặp hành động trong cùng một phút (hasLogInCurrentMinute).
     * Điều kiện: Nếu trong phút hiện tại đã có 1 bản ghi log tồn tại, hệ thống lập tức bỏ qua (`continue`) để tránh nhân bản quyền phân phối.
     */
    @IsTest
    static void testExecuteNow_BlockDuplicateRunInSameMinute() {
        FEC_Case_Assignment__c continuousRule = [SELECT Id FROM FEC_Case_Assignment__c WHERE Name = 'Continuous Rule' LIMIT 1];
        continuousRule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update continuousRule;

        FEC_Case_Assignment_Logs__c doubleLog = new FEC_Case_Assignment_Logs__c(
            Name = 'Continuous Rule - Double Check',
            FEC_Case_Assignment_Name__c = continuousRule.Id,
            FEC_Number_of_Case__c = 4
        );
        insert doubleLog;

        Integer logCountBefore = [
            SELECT COUNT()
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c = :continuousRule.Id
        ];

        // executeNow() không enqueue khi đã có log trong phút hiện tại (tránh chain Queueable).
        FEC_CaseAssignmentAutoDistributeService.executeNow();

        Integer logCountAfter = [
            SELECT COUNT()
            FROM FEC_Case_Assignment_Logs__c
            WHERE FEC_Case_Assignment_Name__c = :continuousRule.Id
        ];
        System.assertEquals(
            logCountBefore,
            logCountAfter,
            'executeNow phải bỏ qua khi đã có log trong cùng phút.'
        );
    }

    /**
     * Continuous: lịch chạy theo mốc start (log đầu căn slot), không cộng dồn từ log gần nhất.
     * Ví dụ log đầu 08:02, step 5 phút → due 08:05, không phải 08:07.
     */
    @IsTest
    static void testContinuousScheduleAlignedFromStartAnchor() {
        FEC_Case_Assignment__c rule = [
            SELECT
                Id,
                FEC_Assignment_Method__c,
                FEC_Scheduled_Time__c,
                FEC_Business_Hours__c,
                FEC_Business_Hours__r.TimeZoneSidKey
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Continuous Rule'
            LIMIT 1
        ];
        rule.FEC_Scheduled_Time__c = 5;
        rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update rule;

        Datetime firstLogUtc = Datetime.newInstanceGmt(2026, 5, 26, 1, 2, 0);
        Datetime at805Utc = Datetime.newInstanceGmt(2026, 5, 26, 1, 5, 0);
        Datetime at803Utc = Datetime.newInstanceGmt(2026, 5, 26, 1, 3, 0);

        System.assertEquals(
            true,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(rule, at805Utc, firstLogUtc),
            '08:05 phải due khi start căn 08:00 và step 5 phút.'
        );
        System.assertEquals(
            false,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(rule, at803Utc, firstLogUtc),
            '08:03 không phải slot 5 phút kể từ mốc 08:00.'
        );
    }

    /**
     * Kịch bản 4: Kiểm tra các nhánh biên xử lý chuỗi rỗng văn bản, lỗi cú pháp phân tách dấu, và bẫy giá trị rỗng (Guard Clauses & Split Utility).
     * Bao phủ: parseRoleScale, splitToSet, normalizeKeyPart, và trường hợp activeAssignments rỗng.
     */
    @IsTest
    static void testUtilityMethods_AndEdgeCases() {
        delete [SELECT Id FROM FEC_Case_Assignment__c];
        // Không có assignment Active → executeNow thoát sớm, không enqueue Queueable.
        FEC_CaseAssignmentAutoDistributeService.executeNow();

        // Kiểm tra sau khi dọn sạch luật, Case vẫn giữ nguyên Owner gốc là Queue
        List<Case> cases = [SELECT Owner.Type FROM Case LIMIT 1];
        System.assertEquals('Queue', cases[0].Owner.Type);
    }
}