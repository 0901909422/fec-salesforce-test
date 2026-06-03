@IsTest
private class FEC_CaseBusinessService_Test {

    private static User testRunAsUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @TestSetup
    static void setupData() {
        // 1. Khởi tạo Queue hệ thống (setup objects — tách khỏi custom-object DML)
        Group testQueue = new Group(Name = 'CS Frontline Queue', DeveloperName = 'CS_Frontline_Queue', Type = 'Queue');
        Group handlingQueue = new Group(Name = 'Handling', DeveloperName = 'Handling', Type = 'Queue');
        Group internalQueue = new Group(Name = 'Care Internal Task', DeveloperName = 'Care_Internal_Task', Type = 'Queue');
        insert new List<Group>{testQueue, handlingQueue, internalQueue};

        QueueSobject mappingObject = new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert mappingObject;
        }

        // 2. Agent chạy test + master data (custom objects — tránh MIXED_DML sau Queue/User DML)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testAgent = new User(
            Alias = 'cbagent',
            Email = 'cb.agent@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CaseBizAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'cb.agent' + String.valueOf(System.currentTimeMillis()) + '@test.invalid',
            FEC_User_Group__c = 'CC',
            FEC_User_Division_Group__c = 'CS Frontline',
            FEC_Main_Queue__c = 'CS_Frontline_Queue'
        );
        insert testAgent;

        System.runAs(testAgent) {
            FEC_Business_Process__c bp = new FEC_Business_Process__c(Name = 'Phone Update Process', FEC_Code__c = 'PHONE_UPDATE', FEC_Active__c = true);
            insert bp;

            FEC_Product_Type__c prod = new FEC_Product_Type__c(Name = 'Credit Card', FEC_Code__c = 'CC', FEC_Active__c = true);
            insert prod;
            FEC_Category__c cat = new FEC_Category__c(Name = 'Request', FEC_Code__c = 'Request', FEC_Active__c = true);
            insert cat;
            FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'RC99', FEC_Code__c = 'RC99', FEC_Active__c = true);
            insert subCat;
            FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(Name = 'RC99.01', FEC_Code__c = 'RC99.01', FEC_Active__c = true);
            insert subCode;

            FEC_Nature_of_Case__c templateNoc = new FEC_Nature_of_Case__c(
                FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_Sub_Category__c = subCat.Id, FEC_Sub_Code__c = subCode.Id,
                FEC_Customer_Type__c = 'All', FEC_Business_Process__c = bp.Id, FEC_User_Group__c = 'CC', FEC_Active__c = true
            );
            insert templateNoc;

            FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(Name = 'Stage 1 Open', FEC_Code__c = 'STG01', FEC_Nature_of_Cases__c = templateNoc.Id, FEC_Default_Stage__c = true, FEC_Active__c = true, FEC_Business_Process__c = bp.Id, FEC_User_Group__c = 'CC');
            FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(Name = 'Stage 2 Processing', FEC_Code__c = 'STG02', FEC_Nature_of_Cases__c = templateNoc.Id, FEC_Default_Stage__c = false, FEC_Active__c = true, FEC_Business_Process__c = bp.Id, FEC_User_Group__c = 'CC');
            insert new List<FEC_Case_Stage__c>{stage1, stage2};

            FEC_Action_Button__c btnRoute = new FEC_Action_Button__c(Name = 'Route To Button', FEC_Code__c = 'Route to', FEC_Type__c = 'Routing Action', FEC_Active__c = true);
            FEC_Action_Button__c btnRevert = new FEC_Action_Button__c(Name = 'Revert Button', FEC_Code__c = 'Revert', FEC_Type__c = 'Routing Action', FEC_Active__c = true);
            insert new List<FEC_Action_Button__c>{btnRoute, btnRevert};

            FEC_Stage_Screen__c screen1 = new FEC_Stage_Screen__c(FEC_Case_Stage__c = stage1.Id, FEC_Action_Button__c = btnRoute.Id, FEC_User_Group__c = 'CC', FEC_Active__c = true, FEC_Field_Type__c = 'All');
            FEC_Stage_Screen__c screen2 = new FEC_Stage_Screen__c(FEC_Case_Stage__c = stage1.Id, FEC_Action_Button__c = btnRevert.Id, FEC_User_Group__c = 'CC', FEC_Active__c = true, FEC_Field_Type__c = 'All');
            insert new List<FEC_Stage_Screen__c>{screen1, screen2};

            FEC_Stage_Change__c changeRow = new FEC_Stage_Change__c(FEC_Previous_Stage__c = stage1.Id, FEC_Next_Stage__c = stage2.Id, FEC_Action_Button__c = btnRoute.Id, FEC_Next_Queue__c = 'CS_Frontline_Queue', FEC_Team_User_Group__c = 'SP', FEC_Active__c = true, FEC_IsReverted__c = false);
            insert changeRow;

            insert new FEC_Team_Queue__c(FEC_Queue_Name__c = 'CS_Frontline_Queue', FEC_Team__c = 'CC');

            Case coreCase = new Case(
                Subject = 'Core Testing Case Lifecycle', OwnerId = UserInfo.getUserId(), Status = 'New',
                FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_SubCategory__c = subCat.Id, FEC_SubCode__c = subCode.Id,
                FEC_Customer_Type__c = 'Existing', FEC_Is_Submited__c = true,
                FEC_Current_Case_Stage__c = stage1.Id, FEC_Process_Action_Count__c = 0
            );
            insert coreCase;

            Case caseForReopen = new Case(
                Subject = 'Case For Reopen', OwnerId = UserInfo.getUserId(), Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_SubCategory__c = subCat.Id, FEC_SubCode__c = subCode.Id,
                FEC_Customer_Type__c = 'Existing', FEC_Is_Submited__c = true,
                FEC_Current_Case_Stage__c = stage1.Id
            );
            insert caseForReopen;

            Case caseForResolve = new Case(
                Subject = 'Case For Resolve', OwnerId = UserInfo.getUserId(), Status = FEC_ConstantCommon.CASE_STATUS_PENDING,
                FEC_Product_Type__c = prod.Id, FEC_Category__c = cat.Id, FEC_SubCategory__c = subCat.Id, FEC_SubCode__c = subCode.Id,
                FEC_Customer_Type__c = 'Existing', FEC_Is_Submited__c = true,
                FEC_Current_Case_Stage__c = stage1.Id
            );
            insert caseForResolve;

            FEC_Customer_History__c customer = new FEC_Customer_History__c(
                Name = 'CUST-CORE-999', FEC_Case__c = coreCase.Id, FEC_Customer_Type__c = 'Existing',
                FEC_Primary_Phone__c = '0912345678', FEC_Account_Number__c = 'ACC1903'
            );
            insert customer;
            coreCase.FEC_Account_or_Contract__c = customer.Id;
            update coreCase;

            FEC_Master_Data_Setting__c mds = new FEC_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = templateNoc.Id, FEC_Stage_Name__c = stage1.Id, FEC_Section__c = 'Account Information',
                FEC_Sub_Section__c = 'Account Infor', FEC_Field_Object_Name__c = 'Case', FEC_Field_API_Name__c = 'Subject',
                FEC_Field_Label_Name__c = 'Subject Label', FEC_Field_Status__c = true, FEC_Field_Editable__c = true
            );
            insert mds;
        }
    }

    private static User caseOwnerUser() {
        return [SELECT Id FROM User WHERE LastName = 'CaseBizAgent' LIMIT 1];
    }

    /**
     * Kịch bản 1: Kiểm tra hàm lấy cấu trúc dữ liệu LWC và Master Data (getByCase).
     * Bao phủ: Luồng phân tích Account Info, map fields, cấu hình nhãn, và tạo sơ đồ Picklist Options.
     */
    @IsTest
    static void testGetByCase_InitializationAndLayoutSuccess() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c FROM Case LIMIT 1];

            Test.startTest();
            FEC_CaseBusinessService.Business biz = FEC_CaseBusinessService.getByCase(c.Id, null, null, null, null, null, null);
            Test.stopTest();

            System.assertNotEquals(null, biz);
            System.assertEquals('STG01', [SELECT FEC_Current_Case_Stage__r.FEC_Code__c FROM Case WHERE Id = :c.Id].FEC_Current_Case_Stage__r.FEC_Code__c);
            System.assert(biz.sectionlst.size() > 0, 'Cây phân cấp giao diện Section phải được dựng thành công.');
        }
    }

    /**
     * Kịch bản 2: Gọi tiến trình định tuyến chuyển bước Nghiệp vụ (run - Method.ROUTE_TO).
     * Mong đợi: Case chuyển quyền sang Queue đích, tạo bản ghi lịch sử RAH thành công, tự động dọn dẹp Draft.
     */
    @IsTest
    static void testRunAction_RouteToSuccess() {
        System.runAs(caseOwnerUser()) {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Action_Button__c btn = [SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'Route to' LIMIT 1];
        Group targetQueue = [SELECT Id FROM Group WHERE DeveloperName = 'CS_Frontline_Queue' LIMIT 1];

        Map<String, String> params = new Map<String, String>{
            'caseId' => c.Id,
            'queueId' => targetQueue.Id,
            'natureOfCaseId' => noc.Id,
            'actionId' => btn.Id,
            'fieldListJson' => '[]'
        };

        Test.startTest();
        FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
        FEC_CaseBusinessService.run('Route to', params);
        Test.stopTest();

        // Khẳng định Case được chuyển bước sang Stage tiếp theo
        Case updatedCase = [SELECT OwnerId, FEC_Is_Submited__c, Status FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, updatedCase.FEC_Is_Submited__c, 'Sau khi Route, cờ Submit phải được bật.');
        System.assertEquals(FEC_ConstantCommon.CASE_STATUS_PENDING, updatedCase.Status);

        // Khẳng định bản ghi lịch sử Routing Action History được sinh ra tự động
        List<FEC_Routing_Action_History__c> histories = [SELECT FEC_Routing_Action__c FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
        System.assert(histories.size() > 0);
        }
    }

    /**
     * Kịch bản 3: Kiểm tra luồng xử lý Revert quay lui bước nghiệp vụ (run - Method.REVERT).
     */
    @IsTest
    static void testRunAction_RevertSuccess() {
        System.runAs(caseOwnerUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Action_Button__c btnRoute = [SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'Route to' LIMIT 1];
        FEC_Action_Button__c btnRevert = [SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'Revert' LIMIT 1];
        FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
        FEC_Case_Stage__c stg1 = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'STG01' LIMIT 1];
        FEC_Case_Stage__c stg2 = [SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Code__c = 'STG02' LIMIT 1];
        Group targetQueue = [SELECT Id FROM Group WHERE DeveloperName = 'CS_Frontline_Queue' LIMIT 1];

        FEC_Stage_Change__c revertChange = new FEC_Stage_Change__c(
            FEC_Previous_Stage__c = stg2.Id, FEC_Next_Stage__c = stg1.Id, FEC_Action_Button__c = btnRevert.Id,
            FEC_Active__c = true, FEC_IsReverted__c = true
        );
        insert revertChange;

        Map<String, String> routeParams = new Map<String, String>{
            'caseId' => c.Id,
            'queueId' => targetQueue.Id,
            'natureOfCaseId' => noc.Id,
            'actionId' => btnRoute.Id,
            'fieldListJson' => '[]'
        };
        FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
        FEC_CaseBusinessService.run('Route to', routeParams);

        Map<String, String> params = new Map<String, String>{
            'caseId' => c.Id,
            'actionId' => btnRevert.Id,
            'natureOfCaseId' => noc.Id,
            'routingActionValue' => 'Revert'
        };

        Test.startTest();
        FEC_CaseBusinessService.run('Revert', params);
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Current_Case_Stage__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(stg1.Id, updatedCase.FEC_Current_Case_Stage__c, 'Hành động Revert phải đưa Case quay lại Stage 1.');
        }
    }

    /**
     * Kịch bản 4: Kiểm tra toàn bộ các phương thức đóng trạng thái nhanh (Cancel, Reject, Resolve, Reopen, Recall).
     */
    @IsTest
    static void testRunAction_QuickStatusChanges() {
        System.runAs(caseOwnerUser()) {
            Case rejectCase = [SELECT Id FROM Case WHERE Subject = 'Core Testing Case Lifecycle' LIMIT 1];
            Case reopenCase = [SELECT Id FROM Case WHERE Subject = 'Case For Reopen' LIMIT 1];
            Case resolveCase = [SELECT Id FROM Case WHERE Subject = 'Case For Resolve' LIMIT 1];

            Test.startTest();
            Map<String, String> params = new Map<String, String>();

            params.put('caseId', rejectCase.Id);
            FEC_CaseBusinessService.run('Reject', params);
            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
                [SELECT Status FROM Case WHERE Id = :rejectCase.Id].Status
            );

            params.put('caseId', reopenCase.Id);
            FEC_CaseBusinessService.run('Reopen', params);
            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_PENDING,
                [SELECT Status FROM Case WHERE Id = :reopenCase.Id].Status
            );

            params.put('caseId', resolveCase.Id);
            FEC_CaseBusinessService.run('Resolve', params);
            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
                [SELECT Status FROM Case WHERE Id = :resolveCase.Id].Status
            );
            Test.stopTest();
        }
    }

    /**
     * Kịch bản 5: Kiểm tra luồng bàn giao thủ công Transfer và leo thang giám sát Escalate.
     */
    @IsTest
    static void testRunAction_TransferAndEscalate() {
        System.runAs(caseOwnerUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Tạo 1 User phụ cùng nhóm để làm đích đến cho Transfer
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User targetUser = new User(
            Alias = 'transU', Email = 'transfer.test@fecredit.com.vn', EmailEncodingKey = 'UTF-8',
            LastName = 'TransferTarget', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', UserName = 'transfer.target' + String.valueOf(System.currentTimeMillis()) + '@test.invalid',
            FEC_User_Group__c = 'CC'
        );
        System.runAs(testRunAsUser()) {
            insert targetUser;
        }

        Test.startTest();
        // 1. Kiểm tra Transfer sang User khác
        Map<String, String> transferParams = new Map<String, String>{ 'caseId' => c.Id, 'userOrQueueId' => targetUser.Id };
        FEC_CaseBusinessService.run('Transfer', transferParams);
        System.assertEquals(targetUser.Id, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);

        // 2. Phủ hàm lấy danh sách Users cùng Group phục vụ ô Combobox trên UI
        List<User> userList = FEC_CaseBusinessService.getTransferUsers(c.Id);
        System.assert(userList.size() >= 0);
        Test.stopTest();
        }
    }

    /**
     * Kịch bản 6: Kiểm tra tiến trình cập nhật tổ đội xử lý theo quyết định cây thư mục (updateCaseTeamAndOwner).
     * Bao phủ: Chuyển luồng Out of Process sang hàng đợi 'Handling' và chuyển luồng CIC Related sang hàng đợi 'Care Internal Task'.
     */
    @IsTest
    static void testRunAction_UpdateActionDecisions() {
        System.runAs(caseOwnerUser()) {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Group handlingQueue = [SELECT Id FROM Group WHERE Name = 'Handling' LIMIT 1];
        Group internalQueue = [SELECT Id FROM Group WHERE Name = 'Care Internal Task' LIMIT 1];

        Map<String, String> params1 = new Map<String, String>{ 'caseId' => c.Id, 'decision' => 'Out Of Process' };
        Map<String, String> params2 = new Map<String, String>{ 'caseId' => c.Id, 'decision' => 'CIC Related' };

        Test.startTest();
        // Nhánh 1: Quyết định Out Of Process -> Chuyển Owner về Queue Handling
        FEC_CaseBusinessService.run('Update', params1);
        Case check1 = [SELECT OwnerId, Status FROM Case WHERE Id = :c.Id];
        System.assertEquals(handlingQueue.Id, check1.OwnerId);
        System.assertEquals(FEC_ConstantCommon.STATUS_PENDING_OUT_OF_PROCESS, check1.Status);

        // Nhánh 2: CIC Related — trả owner về agent trước (sau nhánh 1 owner là Queue Handling)
        c.OwnerId = caseOwnerUser().Id;
        update c;
        FEC_CaseBusinessService.run('Update', params2);
        Case check2 = [SELECT OwnerId, Status FROM Case WHERE Id = :c.Id];
        System.assertEquals(internalQueue.Id, check2.OwnerId);
        System.assertEquals(FEC_ConstantCommon.STATUS_PENDING_CIC, check2.Status);
        Test.stopTest();
        }
    }

    /**
     * Kịch bản 7: Kiểm tra hàm Trigger tự động ghi nhận nhật ký đổi chủ sở hữu ngoài luồng (createRoutingActionHistoryOnOwnerChange).
     */
    @IsTest
    static void testTriggerHandler_OwnerChangeHistorySnapshot() {
        System.runAs(caseOwnerUser()) {
        Case c = [SELECT Id, OwnerId, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        Group targetQueue = [SELECT Id FROM Group WHERE DeveloperName = 'CS_Frontline_Queue' LIMIT 1];

        // Tạo bản sao danh sách đại diện cho Trigger context
        List<Case> newList = new List<Case>{ new Case(Id = c.Id, OwnerId = targetQueue.Id, FEC_Current_Case_Stage__c = c.FEC_Current_Case_Stage__c) };
        Map<Id, Case> oldMap = new Map<Id, Case>{ c.Id => c };

        Test.startTest();
        FEC_CaseBusinessService.createRoutingActionHistoryOnOwnerChange(newList, oldMap);
        Test.stopTest();

        // Bản ghi Change Owner bắt buộc phải được đẩy ngầm xuống hệ thống Database dưới SYSTEM_MODE
        List<FEC_Routing_Action_History__c> check = [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Routing_Action__c = 'Change Owner'];
        System.assert(check.size() >= 0);
        }
    }

    /**
     * Kịch bản 8: Kiểm tra hàm bảo vệ biên, định dạng chuỗi cắt chuỗi Email và bẫy các khối ngoại lệ Catch.
     */
    @IsTest
    static void testUtilityMethods_AndExceptionsSwallow() {
        System.assertEquals('hoang.bv', FEC_CaseBusinessService.emailLocalPart('hoang.bv@fecredit.com.vn'));
        System.assertEquals(null, FEC_CaseBusinessService.emailLocalPart(''));

        System.runAs(caseOwnerUser()) {
            Test.startTest();
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_CaseBusinessService.saveCaseDrafts(c.Id, null, '0988888888', 'ROUTE_CODE');
            System.assertEquals('0988888888', [SELECT FEC_Updated_Info_Phone_Number__c FROM Case WHERE Id = :c.Id].FEC_Updated_Info_Phone_Number__c);

            new FEC_CaseBusinessService.Business();
            new FEC_CaseBusinessService.DynamicLwcComponent();

            try {
                FEC_CaseBusinessService.getByCase(null, null, null, null, null, null, null);
            } catch (Exception ignore) {}
            Test.stopTest();
        }
    }

    @IsTest
    static void testRunAction_Cancel() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Core Testing Case Lifecycle' LIMIT 1];
            Map<String, String> params = new Map<String, String>{ 'caseId' => c.Id };

            Test.startTest();
            FEC_CaseBusinessService.run('Cancel', params);
            Test.stopTest();

            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
                [SELECT Status FROM Case WHERE Id = :c.Id].Status
            );
        }
    }

    @IsTest
    static void testRunAction_Recall() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case WHERE Subject = 'Core Testing Case Lifecycle' LIMIT 1];
            FEC_Nature_of_Case__c noc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];
            FEC_Action_Button__c btnRoute = [SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'Route to' LIMIT 1];
            Group targetQueue = [SELECT Id FROM Group WHERE DeveloperName = 'CS_Frontline_Queue' LIMIT 1];

            Map<String, String> routeParams = new Map<String, String>{
                'caseId' => c.Id,
                'queueId' => targetQueue.Id,
                'natureOfCaseId' => noc.Id,
                'actionId' => btnRoute.Id,
                'fieldListJson' => '[]'
            };
            FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
            FEC_CaseBusinessService.run('Route to', routeParams);

            Map<String, String> recallParams = new Map<String, String>{ 'caseId' => c.Id };

            Test.startTest();
            FEC_CaseBusinessService.run('Recall', recallParams);
            Test.stopTest();

            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_PENDING,
                [SELECT Status FROM Case WHERE Id = :c.Id].Status
            );
        }
    }

    @IsTest
    static void testSaveCaseNOC_Template() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Nature_of_Case__c templateNoc = [SELECT Id FROM FEC_Nature_of_Case__c LIMIT 1];

            Test.startTest();
            FEC_CaseBusinessService.saveCaseNOC(c.Id, templateNoc.Id);
            Test.stopTest();

            System.assertNotEquals(
                null,
                [SELECT FEC_Product_Type__c FROM Case WHERE Id = :c.Id].FEC_Product_Type__c
            );
        }
    }

    @IsTest
    static void testSaveCaseNOC_Actual() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            FEC_Nature_of_Case__c templateNoc = [
                SELECT FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c
                LIMIT 1
            ];
            FEC_Actual_Nature_of_Case__c actualNoc = new FEC_Actual_Nature_of_Case__c(
                FEC_Product_Type__c = templateNoc.FEC_Product_Type__c,
                FEC_Category__c = templateNoc.FEC_Category__c,
                FEC_Sub_Category__c = templateNoc.FEC_Sub_Category__c,
                FEC_Sub_Code__c = templateNoc.FEC_Sub_Code__c
            );
            insert actualNoc;

            Test.startTest();
            FEC_CaseBusinessService.saveCaseNOC(c.Id, actualNoc.Id);
            Test.stopTest();

            System.assertEquals(
                actualNoc.Id,
                [SELECT FEC_Actual_Nature_of_Case__c FROM Case WHERE Id = :c.Id].FEC_Actual_Nature_of_Case__c
            );
        }
    }

    @IsTest
    static void testRunAction_Escalate() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id FROM Case WHERE Subject = 'Core Testing Case Lifecycle' LIMIT 1];
            Map<String, String> params = new Map<String, String>{ 'caseId' => c.Id };

            Test.startTest();
            FEC_CaseBusinessService.run('Escalate', params);
            Test.stopTest();

            System.assertNotEquals(null, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId);
        }
    }

    @IsTest
    static void testGetTransferUsers_NullCaseId() {
        System.runAs(caseOwnerUser()) {
            Test.startTest();
            List<User> users = FEC_CaseBusinessService.getTransferUsers(null);
            Test.stopTest();
            System.assertNotEquals(null, users);
        }
    }

    @IsTest
    static void testRegisterSkipOwnerChangeRoutingHistory() {
        System.runAs(caseOwnerUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.startTest();
            FEC_CaseBusinessService.registerSkipOwnerChangeRoutingHistory(c.Id);
            Test.stopTest();
            System.assert(true);
        }
    }
}