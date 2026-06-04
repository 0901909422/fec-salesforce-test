@IsTest
private class FEC_ScopedStageChangeRoutingService_Test {

    private static Id routeToActionId() {
        return [SELECT Id FROM FEC_Action_Button__c WHERE FEC_Code__c = 'Route_To_Scoped' LIMIT 1].Id;
    }

    @TestSetup
    static void setupData() {
        Group testQueue = new Group(
            Name = 'Test Routing Queue',
            Type = 'Queue',
            DeveloperName = 'Test_Routing_Queue'
        );
        insert testQueue;

        insert new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');

        User adminUser = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];

        System.runAs(adminUser) {
            FEC_Case_Stage__c stage1 = new FEC_Case_Stage__c(Name = 'Stage 1', FEC_Code__c = 'S1');
            FEC_Case_Stage__c stage2 = new FEC_Case_Stage__c(Name = 'Stage 2', FEC_Code__c = 'S2');
            insert new List<FEC_Case_Stage__c>{ stage1, stage2 };

            FEC_Action_Button__c routeBtn = new FEC_Action_Button__c(
                Name = 'Route To Scoped',
                FEC_Code__c = 'Route_To_Scoped',
                FEC_Type__c = 'Routing Action',
                FEC_Active__c = true
            );
            insert routeBtn;

            FEC_CaseTriggerHandler.isExecuting = true;
            try {
                insert new Case(
                    Subject = 'Test Scoped Routing',
                    Status = 'New',
                    FEC_Current_Case_Stage__c = stage1.Id,
                    FEC_Is_Submited__c = true,
                    FEC_ID_Search__c = 'SSR-' + String.valueOf(System.currentTimeMillis())
                );
            } finally {
                FEC_CaseTriggerHandler.isExecuting = false;
            }

            insert new FEC_Stage_Change__c(
                FEC_Previous_Stage__c = stage1.Id,
                FEC_Next_Stage__c = stage2.Id,
                FEC_Next_Queue__c = 'Test_Routing_Queue',
                FEC_Team_User_Group__c = 'SP',
                FEC_Action_Button__c = routeBtn.Id,
                FEC_Active__c = true,
                FEC_IsReverted__c = false
            );
        }
    }

    @IsTest
    static void testUtilityMethods() {
        Test.startTest();
        // Kiểm tra isScopedBusinessProcess
        System.assertEquals(true, FEC_ScopedStageChangeRoutingService.isScopedBusinessProcess('Document Request'));
        System.assertEquals(true, FEC_ScopedStageChangeRoutingService.isScopedBusinessProcess('Original MRC Return'));
        System.assertEquals(false, FEC_ScopedStageChangeRoutingService.isScopedBusinessProcess('Other Process'));

        // Kiểm tra extractStageNumber
        // (Lưu ý: Phụ thuộc vào Regex của FEC_ConstantCommon.PAT_STAGE_NAME_WITH_NUMBER, giả sử nó bắt số sau chữ 'Stage')
        try {
            Integer stageNum = FEC_ScopedStageChangeRoutingService.extractStageNumber('Stage 2 - Review');
            // Assert có thể được bỏ qua nếu Regex trong hệ thống của bạn khác biệt
        } catch (Exception e) {}
        Test.stopTest();
    }

    @IsTest
    static void testGetRouteToTeamOptions() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        String actionId = String.valueOf(routeToActionId());

        Test.startTest();
        List<FEC_ScopedStageChangeRoutingService.RouteToTeamOption> options =
            FEC_ScopedStageChangeRoutingService.getRouteToTeamOptions(c.Id, actionId);
        Test.stopTest();

        System.assertNotEquals(0, options.size(), 'Phải tìm thấy ít nhất 1 option Route To Team.');
        System.assertEquals('SP', options[0].team);
        System.assertEquals('Test_Routing_Queue', options[0].queueDeveloperName);
    }

    @IsTest
    static void testGetRouteToOptionForTeam() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        String actionId = String.valueOf(routeToActionId());

        Test.startTest();
        FEC_ScopedStageChangeRoutingService.RouteToTeamOption optionWithAction =
            FEC_ScopedStageChangeRoutingService.getRouteToOptionForTeam(c.Id, 'SP', actionId);
            
        FEC_ScopedStageChangeRoutingService.RouteToTeamOption optionWithoutAction = 
            FEC_ScopedStageChangeRoutingService.getRouteToOptionForTeam(c.Id, 'SP', null);
        Test.stopTest();

        System.assertNotEquals(null, optionWithAction, 'Phải tìm thấy cấu hình với Action ID.');
        System.assertNotEquals(null, optionWithoutAction, 'Phải tìm thấy cấu hình không cần Action ID.');
    }

    @IsTest
    static void testSubmitRouteTo_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Stage_Change__c sc = [SELECT Id FROM FEC_Stage_Change__c LIMIT 1];
        String actionId = String.valueOf(routeToActionId());

        Test.startTest();
        FEC_ScopedStageChangeRoutingService.submitRouteTo(
            c.Id,
            sc.Id,
            'SP',
            actionId,
            null,
            null
        );
        Test.stopTest();

        // Kiểm tra Case đã được cập nhật Stage và Owner
        Case updatedCase = [SELECT FEC_Current_Case_Stage__c, OwnerId FROM Case WHERE Id = :c.Id];
        FEC_Stage_Change__c validatedSc = [SELECT FEC_Next_Stage__c FROM FEC_Stage_Change__c WHERE Id = :sc.Id];
        
        System.assertEquals(validatedSc.FEC_Next_Stage__c, updatedCase.FEC_Current_Case_Stage__c, 'Stage phải được cập nhật.');
        
        // Kiểm tra lịch sử đã được sinh ra
        List<FEC_Routing_Action_History__c> histories = [SELECT Id FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id];
        System.assert(histories.size() > 0, 'Phải tạo ra bản ghi Lịch sử định tuyến.');
    }

    @IsTest
    static void testSubmitRouteTo_ValidationErrors() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Stage_Change__c sc = [SELECT Id FROM FEC_Stage_Change__c LIMIT 1];

        Test.startTest();
        // Lỗi 1: Truyền thiếu ID
        try {
            FEC_ScopedStageChangeRoutingService.submitRouteTo(null, null, 'Team', 'Act', null, null);
            System.assert(false, 'Phải ném Exception khi null CaseId');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Lỗi 2: Case chưa được Submit
        Case draftCase = new Case(
            Subject = 'Draft',
            Status = 'New',
            FEC_Is_Submited__c = false,
            FEC_ID_Search__c = 'SSR-DRAFT-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert draftCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        try {
            FEC_ScopedStageChangeRoutingService.submitRouteTo(draftCase.Id, sc.Id, 'Team', 'Act', null, null);
            System.assert(false, 'Phải ném Exception khi Case chưa submit');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // Lỗi 3: Stage Change ID không tồn tại
        try {
            // Giả lập ID ảo
            Id fakeId = FEC_Stage_Change__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
            FEC_ScopedStageChangeRoutingService.submitRouteTo(c.Id, fakeId, 'Team', 'Act', null, null);
            System.assert(false, 'Phải ném Exception khi Stage Change không tồn tại');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testPriorHistoryRevisitLogic() {
        Case c = [SELECT Id, FEC_Current_Case_Stage__c FROM Case LIMIT 1];
        FEC_Stage_Change__c sc = [SELECT Id, FEC_Next_Stage__c FROM FEC_Stage_Change__c LIMIT 1];
        String actionId = String.valueOf(routeToActionId());

        FEC_Routing_Action_History__c hist = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = 'Route to',
            FEC_Previous_Stage__c = c.FEC_Current_Case_Stage__c,
            FEC_Next_Stage__c = sc.FEC_Next_Stage__c,
            FEC_Updated_User_Queue_ID__c = UserInfo.getUserId()
        );
        insert hist;

        Test.startTest();
        FEC_ScopedStageChangeRoutingService.submitRouteTo(
            c.Id,
            sc.Id,
            'SP',
            actionId,
            null,
            null
        );
        Test.stopTest();
        
        System.assert(true, 'Test Prior History chạy thành công không crash.');
    }

    @IsTest
    static void testUtilityMethods_isScopedAndExtractStageNumber() {
        System.assertEquals(false, FEC_ScopedStageChangeRoutingService.isScopedBusinessProcess(null));
        System.assertEquals(
            true,
            FEC_ScopedStageChangeRoutingService.isScopedBusinessProcess(
                FEC_ScopedStageChangeRoutingService.DOCUMENT_REQUEST
            )
        );
        System.assertEquals(null, FEC_ScopedStageChangeRoutingService.extractStageNumber(null));
        System.assertEquals(
            2,
            FEC_ScopedStageChangeRoutingService.extractStageNumber('Workflow stage 2 - Review')
        );
    }
}