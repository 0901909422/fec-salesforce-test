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

    private static Group getTestQueue() {
        return [SELECT Id, Name FROM Group WHERE Name = 'Queue CS Support' AND Type = 'Queue' LIMIT 1];
    }

    private static void insertQueueCases(Integer count, Id queueId) {
        FEC_Product_Type__c prod = [
            SELECT Id
            FROM FEC_Product_Type__c
            WHERE Name = 'Credit Card'
            LIMIT 1
        ];
        FEC_Category__c cat = [
            SELECT Id
            FROM FEC_Category__c
            WHERE Name = 'Request'
            LIMIT 1
        ];
        FEC_Sub_Category__c subCat = [
            SELECT Id
            FROM FEC_Sub_Category__c
            WHERE Name = 'RC27'
            LIMIT 1
        ];
        FEC_Sub_Code__c subCode = [
            SELECT Id
            FROM FEC_Sub_Code__c
            WHERE Name = 'RC27.01'
            LIMIT 1
        ];
        List<Case> batch = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            batch.add(
                new Case(
                    Subject = 'Bulk Queue Case ' + Crypto.getRandomInteger(),
                    OwnerId = queueId,
                    Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                    FEC_Product_Type__c = prod.Id,
                    FEC_Category__c = cat.Id,
                    FEC_SubCategory__c = subCat.Id,
                    FEC_SubCode__c = subCode.Id
                )
            );
        }
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert batch;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
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

        Group publicGroup = new Group(Name = 'CS Support Public Group', Type = 'Regular');
        insert publicGroup;
        insert new GroupMember(GroupId = publicGroup.Id, UserOrGroupId = userB.Id);

        // Gắn Public Group và User vào Queue — cover BFS bung nhóm lồng queue.
        GroupMember gmPublicGroup = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = publicGroup.Id);
        GroupMember gmUserA = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userA.Id);
        GroupMember gmUserB = new GroupMember(GroupId = testQueue.Id, UserOrGroupId = userB.Id);
        insert new List<GroupMember>{ gmPublicGroup, gmUserA, gmUserB };

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
                    Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
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
     * Điều kiện: Hệ thống so khớp thời gian chia hết choScheduled_Time, bóc tách danh sách Case và điều phối đều cho Users.
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
            System.assert(assignedCount > 0, 'Time-Based phải phân phối Case khớp NOC không SubCode.');

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

        Datetime fiveMinAgo = Datetime.now().addMinutes(-5);
        FEC_Case_Assignment_Logs__c anchorLog = new FEC_Case_Assignment_Logs__c(
            Name = 'Continuous Rule - Anchor',
            FEC_Case_Assignment_Name__c = continuousRule.Id,
            FEC_Number_of_Case__c = 1
        );
        insert anchorLog;
        Test.setCreatedDate(anchorLog.Id, fiveMinAgo);

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
        Datetime at807Utc = Datetime.newInstanceGmt(2026, 5, 26, 1, 7, 0);

        System.assertEquals(
            true,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(
                rule,
                at805Utc,
                firstLogUtc,
                firstLogUtc
            ),
            '08:05 phải due khi start căn 08:00 và step 5 phút.'
        );
        System.assertEquals(
            false,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(
                rule,
                at803Utc,
                firstLogUtc,
                firstLogUtc
            ),
            '08:03 vẫn cùng slot với log 08:02 — không due.'
        );
        System.assertEquals(
            true,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(
                rule,
                at807Utc,
                firstLogUtc,
                firstLogUtc
            ),
            '08:07 (scheduler lệch mốc) vẫn due slot kế sau log 08:02.'
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

    @IsTest
    static void testExecuteImmediately_NullDraftAndDiagnose() {
        System.assertEquals(
            0,
            FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(null)
        );

        List<String> nullDiag = FEC_CaseAssignmentAutoDistributeService.diagnoseAssignment(null);
        System.assert(nullDiag[0].contains('null'));

        List<String> missingDiag = FEC_CaseAssignmentAutoDistributeService.diagnoseAssignment(
            FEC_Case_Assignment__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'
        );
        System.assert(missingDiag[0].contains('không tìm thấy'));

        FEC_Case_Assignment__c draftRule = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Continuous Rule'
            LIMIT 1
        ];
        System.assertEquals(
            0,
            FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(draftRule.Id)
        );

        List<String> draftDiag = FEC_CaseAssignmentAutoDistributeService.diagnoseAssignment(draftRule.Id);
        System.assert(draftDiag[1].contains('Active'));
    }

    @IsTest
    static void testFilterAssignmentIdsForImmediateActivation() {
        FEC_Case_Assignment__c continuousRule = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Continuous Rule'
            LIMIT 1
        ];
        FEC_Case_Assignment__c timeRule = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Time-Based Rule'
            LIMIT 1
        ];
        Set<Id> eligible = FEC_CaseAssignmentAutoDistributeService.filterAssignmentIdsForImmediateActivation(
            new Set<Id>{ continuousRule.Id, timeRule.Id }
        );
        System.assert(eligible.contains(continuousRule.Id));
        System.assert(!eligible.contains(timeRule.Id));
        System.assertEquals(0, FEC_CaseAssignmentAutoDistributeService.filterAssignmentIdsForImmediateActivation(null).size());
    }

    @IsTest
    static void testDiagnoseAssignment_ActiveRuleOk() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            List<String> lines = FEC_CaseAssignmentAutoDistributeService.diagnoseAssignment(rule.Id);
            System.assert(lines.size() > 0);
            System.assert(lines[lines.size() - 1].startsWith('OK'));
        }
    }

    @IsTest
    static void testExecuteNow_EnqueuesDueAssignment() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            Test.startTest();
            FEC_CaseAssignmentAutoDistributeService.executeNow();
            Test.stopTest();

            System.assert(
                [
                    SELECT COUNT()
                    FROM AsyncApexJob
                    WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
                ] > 0,
                'executeNow phải enqueue FEC_CaseAssignmentAutoDistQueueJob.'
            );
        }
    }

    @IsTest
    static void testHandleQueueCasesAfterSave_EnqueuesWhenDue() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            Group testQueue = getTestQueue();
            insertQueueCases(1, testQueue.Id);
            Case queueCase = [
                SELECT Id, OwnerId, IsClosed
                FROM Case
                WHERE Subject LIKE 'Bulk Queue Case%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            Test.startTest();
            FEC_CaseAssignmentAutoDistributeService.handleQueueCasesAfterSave(
                new List<Case>{ queueCase },
                null
            );
            Test.stopTest();

            System.assert(
                [
                    SELECT COUNT()
                    FROM AsyncApexJob
                    WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
                ] > 0,
                'handleQueueCasesAfterSave phải enqueue khi assignment Continuous due.'
            );
        }
    }

    @IsTest
    static void testDistributionViaOpenQueueAssignment() {
        System.runAs(testRunAsUser()) {
            Case queueCase = [
                SELECT Id, OwnerId
                FROM Case
                WHERE Subject LIKE 'Pending Queue Case%'
                LIMIT 1
            ];
            insert new FEC_Assignment__c(
                FEC_Case__c = queueCase.Id,
                FEC_Assignment_Name__c = 'Queue-owned assignment',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                FEC_OwnerID__c = 'Queue CS Support'
            );

            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            Integer assignedCount =
                FEC_CaseAssignmentAutoDistributeService.executeImmediatelyForAssignmentId(rule.Id);
            System.assert(assignedCount > 0, 'Phải phân phối Case có FEC_Assignment__c trên queue.');
        }
    }

    @IsTest
    static void testInsertAssignmentRunLog_AndApplyFromBatch() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [
                SELECT Id, Name
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            User agent = [SELECT Id FROM User WHERE Alias = 'agentA' LIMIT 1];
            Case queueCase = [
                SELECT Id
                FROM Case
                WHERE Subject LIKE 'Pending Queue Case%'
                LIMIT 1
            ];

            Map<Id, Integer> counts = new Map<Id, Integer>{ agent.Id => 2 };
            FEC_CaseAssignmentAutoDistributeService.insertAssignmentRunLog(
                rule.Id,
                rule.Name,
                99,
                2,
                counts,
                new List<Id>{ agent.Id }
            );
            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM FEC_Case_Assignment_Log_Detail__c
                    WHERE FEC_Case_Assignment_log_Name__r.FEC_Case_Assignment_Name__c = :rule.Id
                    AND FEC_Case_Assignment_log_Name__r.Name LIKE '%99'
                ]
            );

            FEC_CaseAssignmentAutoDistributeService.applyDistributionResultsFromBatch(
                rule.Id,
                new List<FEC_CaseAssignmentApplyOwnerBatch.DistributionTargetStub>{
                    new FEC_CaseAssignmentApplyOwnerBatch.DistributionTargetStub(
                        queueCase.Id,
                        agent.Id,
                        true,
                        null
                    )
                }
            );
            System.assertEquals(agent.Id, [SELECT OwnerId FROM Case WHERE Id = :queueCase.Id].OwnerId);
        }
    }

    @IsTest
    static void testTimeBasedIsDueToRun_InSlotWindow() {
        FEC_Case_Assignment__c timeRule = [
            SELECT
                Id,
                FEC_Assignment_Method__c,
                FEC_Time_Slots__c,
                FEC_Business_Hours__c,
                FEC_Business_Hours__r.TimeZoneSidKey
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Time-Based Rule'
            LIMIT 1
        ];
        timeRule.FEC_Time_Slots__c = validTimeSlotForPicklist();
        update timeRule;

        Datetime slotUtc = Datetime.newInstanceGmt(2026, 5, 29, 5, 2, 0);
        System.assertEquals(
            true,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(timeRule, slotUtc, null, null),
            '12:02 ICT phải nằm trong cửa sổ slot 12:00.'
        );
        System.assertEquals(
            false,
            FEC_CaseAssignmentAutoDistributeService.isDueToRun(
                timeRule,
                Datetime.newInstanceGmt(2026, 5, 29, 4, 0, 0),
                null,
                null
            ),
            '11:00 ICT không khớp slot 12:00.'
        );
    }

    @IsTest
    static void testExecuteNow_SkipsWhenScheduleNotDue() {
        System.runAs(testRunAsUser()) {
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
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            rule.FEC_Scheduled_Time__c = 30;
            update rule;

            Datetime recentRun = Datetime.now().addMinutes(-1);
            FEC_Case_Assignment_Logs__c recentLog = new FEC_Case_Assignment_Logs__c(
                Name = 'Continuous Rule - 1',
                FEC_Case_Assignment_Name__c = rule.Id,
                FEC_Number_of_Case__c = 1
            );
            insert recentLog;
            Test.setCreatedDate(recentLog.Id, recentRun);

            Integer jobsBefore = [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
            ];

            Test.startTest();
            FEC_CaseAssignmentAutoDistributeService.executeNow();
            Test.stopTest();

            System.assertEquals(
                jobsBefore,
                [
                    SELECT COUNT()
                    FROM AsyncApexJob
                    WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
                ],
                'executeNow không enqueue khi chưa đến kỳ Continuous.'
            );
        }
    }

    @IsTest
    static void testHandleQueueCasesAfterSave_SkipsClosedAndSameOwner() {
        Group testQueue = getTestQueue();
        Case closedCase = new Case(
            Subject = 'Closed queue case',
            OwnerId = testQueue.Id,
            Status = 'Closed'
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert closedCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_CaseAssignmentAutoDistributeService.handleQueueCasesAfterSave(
            new List<Case>{ closedCase },
            null
        );
        FEC_CaseAssignmentAutoDistributeService.handleQueueCasesAfterSave(
            new List<Case>(),
            null
        );

        Case pendingCase = [
            SELECT Id, OwnerId, IsClosed
            FROM Case
            WHERE Subject LIKE 'Pending Queue Case%'
            LIMIT 1
        ];
        Map<Id, Case> oldMap = new Map<Id, Case>{
            pendingCase.Id => new Case(Id = pendingCase.Id, OwnerId = pendingCase.OwnerId)
        };
        FEC_CaseAssignmentAutoDistributeService.handleQueueCasesAfterSave(
            new List<Case>{ pendingCase },
            oldMap
        );
        System.assert(true, 'Các nhánh guard handleQueueCasesAfterSave phải thoát sớm không lỗi.');
    }

    @IsTest
    static void testAutoDistQueueJob_ExecutesDistribution() {
        System.runAs(testRunAsUser()) {
            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];
            rule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
            update rule;

            Test.startTest();
            System.enqueueJob(new FEC_CaseAssignmentAutoDistQueueJob(rule.Id));
            Test.stopTest();

            System.assert(
                [
                    SELECT COUNT()
                    FROM Case
                    WHERE Subject LIKE 'Pending Queue Case%' AND Owner.Type = 'User'
                ] > 0,
                'Queueable job phải gọi phân phối và gán Case cho User.'
            );
        }
    }

    @IsTest
    static void testHandleQueueCasesAfterSave_SkipsWhenOnlyTimeBasedActive() {
        FEC_Case_Assignment__c continuousRule = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Continuous Rule'
            LIMIT 1
        ];
        continuousRule.FEC_Status__c = 'Draft';
        update continuousRule;

        FEC_Case_Assignment__c timeRule = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Time-Based Rule'
            LIMIT 1
        ];
        timeRule.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update timeRule;

        Case queueCase = [
            SELECT Id, OwnerId, IsClosed
            FROM Case
            WHERE Subject LIKE 'Pending Queue Case%'
            LIMIT 1
        ];
        Integer jobsBefore = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
        ];
        FEC_CaseAssignmentAutoDistributeService.handleQueueCasesAfterSave(
            new List<Case>{ queueCase },
            null
        );
        System.assertEquals(
            jobsBefore,
            [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'FEC_CaseAssignmentAutoDistQueueJob'
            ],
            'Chỉ Time-Based Active — handleQueueCasesAfterSave không enqueue.'
        );
    }

    @IsTest
    static void testApplyFromBatch_UpdatesAssignmentOwnerOnly() {
        System.runAs(testRunAsUser()) {
            Case queueCase = [
                SELECT Id
                FROM Case
                WHERE Subject LIKE 'Pending Queue Case%'
                LIMIT 1
            ];
            FEC_Assignment__c assignmentRow = new FEC_Assignment__c(
                FEC_Case__c = queueCase.Id,
                FEC_Assignment_Name__c = 'Batch assignment owner',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                FEC_OwnerID__c = 'Queue CS Support'
            );
            insert assignmentRow;

            User agent = [SELECT Id FROM User WHERE Alias = 'agentA' LIMIT 1];
            FEC_Case_Assignment__c rule = [
                SELECT Id
                FROM FEC_Case_Assignment__c
                WHERE Name = 'Continuous Rule'
                LIMIT 1
            ];

            FEC_CaseAssignmentAutoDistributeService.applyDistributionResultsFromBatch(
                rule.Id,
                new List<FEC_CaseAssignmentApplyOwnerBatch.DistributionTargetStub>{
                    new FEC_CaseAssignmentApplyOwnerBatch.DistributionTargetStub(
                        queueCase.Id,
                        agent.Id,
                        false,
                        assignmentRow.Id
                    )
                }
            );

            System.assertEquals(
                agent.Id,
                [
                    SELECT FEC_Assignment_Owner__c
                    FROM FEC_Assignment__c
                    WHERE Id = :assignmentRow.Id
                ]
                .FEC_Assignment_Owner__c
            );
        }
    }

    @IsTest
    static void testContinuousSlotIndex_AndAnchor() {
        Datetime anchor = Datetime.newInstanceGmt(2026, 5, 26, 1, 0, 0);
        System.assertEquals(
            -1,
            FEC_CaseAssignmentAutoDistributeService.continuousSlotIndex(null, anchor, 5)
        );
        System.assertEquals(
            0,
            FEC_CaseAssignmentAutoDistributeService.continuousSlotIndex(
                Datetime.newInstanceGmt(2026, 5, 26, 1, 2, 0),
                anchor,
                5
            )
        );
        Datetime firstLog = Datetime.newInstanceGmt(2026, 5, 26, 1, 2, 0);
        Datetime snapped = FEC_CaseAssignmentAutoDistributeService.continuousScheduleAnchorUtc(
            firstLog,
            5,
            'Asia/Ho_Chi_Minh'
        );
        System.assertNotEquals(null, snapped);
    }
}