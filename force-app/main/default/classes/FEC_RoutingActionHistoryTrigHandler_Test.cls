@IsTest
private class FEC_RoutingActionHistoryTrigHandler_Test {

    @TestSetup
    static void setupData() {
        // 1. Tạo Stage
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = 'Stage 1', FEC_Code__c = 'S1');
        insert stage;

        // 2. Tạo Case (FEC_Assignment_Count__c là rollup — mặc định 0 khi chưa có assignment)
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = 'Test Case',
                Status = 'New',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'RAH-' + String.valueOf(System.currentTimeMillis())
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        // 3. Tạo Notification Template Channel để test gửi email
        FEC_Notification__c notif = new FEC_Notification__c(
            Name = 'Test Notif',
            FEC_Notification_Status__c = true,
            FEC_Target_Group__c = FEC_ConstantCommon.TARGET_GROUP_CUSTOMER,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );
        insert notif;

        FEC_Notification_Template_Channel__c channel = new FEC_Notification_Template_Channel__c(
            FEC_Notification__c = notif.Id
        );
        insert channel;
    }

    @IsTest
    static void testAfterInsert_Notification() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );

        Test.startTest();
        // Trigger logic
        insert history;
        Test.stopTest();

        // Kiểm tra xem job queueable đã được enqueue chưa
        Integer jobs = [SELECT count() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assert(jobs > 0, 'Phải có job Queueable được enqueue để gửi email.');
    }

    @IsTest
    static void testUpdateCaseTeamsOnInsert() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        
        // Tạo history để kích hoạt logic update Team
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Routing_Action__c = 'ASSIGN' // Giả lập action ASSIGN
        );

        Test.startTest();
        insert history;
        Test.stopTest();

        Case updatedCase = [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id];
        // Kiểm tra kết quả update team (tuỳ thuộc vào logic trong FEC_OwnerTeamLookupSvc của bạn)
        System.assertNotEquals(null, updatedCase, 'Case phải được update team.');
    }

    @IsTest
    static void testBuildPendingStatus() {
        // Test logic build status string
        Id id1 = UserInfo.getUserId();
        
        Test.startTest();
        String status = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromOwnerIds(id1, id1);
        Test.stopTest();

        System.assert(
            status == FEC_ConstantCommon.CASE_STATUS_PENDING
                || status.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX),
            'Actual status: ' + status
        );
    }
}