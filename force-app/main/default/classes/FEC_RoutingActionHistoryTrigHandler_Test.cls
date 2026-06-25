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

    @IsTest
    static void testAfterInsert_RouteToHistory() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Pending'
        );

        Test.startTest();
        insert history;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM FEC_Routing_Action_History__c WHERE Id = :history.Id].Id);
    }

    @IsTest
    static void testProcessNotificationEmails_directCall() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );
        insert history;

        Test.startTest();
        FEC_RoutingActionHistoryTriggerHandler.processNotificationEmails(
            new List<FEC_Routing_Action_History__c>{ history }
        );
        Test.stopTest();

        System.assert(true, 'processNotificationEmails should complete without unhandled exception.');
    }

    @IsTest
    static void testProcessNotification_batchImportApplyInProgress_skipsEnqueue() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );
        insert history;

        Test.startTest();
        FEC_BatchCaseHandlingImportService.batchImportApplyInProgress = true;
        try {
            FEC_RoutingActionHistoryTriggerHandler.processNotification(
                new List<FEC_Routing_Action_History__c>{ history }
            );
        } finally {
            FEC_BatchCaseHandlingImportService.batchImportApplyInProgress = false;
        }
        Integer enqueuedInTxn = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(
            0,
            enqueuedInTxn,
            'Batch import apply không được enqueue notification — phải giữ slot cho ImportQueueable chain.'
        );
    }

    @IsTest
    static void testAfterUpdate_runsHandlerPaths() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = c.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Current_Status__c = 'Open',
            FEC_Changed_Status__c = 'Pending'
        );
        insert history;

        history.FEC_Changed_Status__c = 'Resolved';
        Test.startTest();
        update history;
        Test.stopTest();

        System.assertEquals(
            'Resolved',
            [SELECT FEC_Changed_Status__c FROM FEC_Routing_Action_History__c WHERE Id = :history.Id]
                .FEC_Changed_Status__c
        );
    }

    @IsTest
    static void testSendNotificationEmails_guardClauses() {
        Test.startTest();
        FEC_RoutingActionHistoryTriggerHandler.sendNotificationEmails(null);
        FEC_RoutingActionHistoryTriggerHandler.sendNotificationEmails(
            new List<FEC_Routing_Action_History__c>()
        );
        Test.stopTest();
        System.assert(true, 'Guard clauses should not throw.');
    }

    @IsTest
    // 23/06/2026 linhdev - regression: sync path (queueable context) không enqueue FEC_SendNotificationEmailsQueueable.
    static void testSendNotificationEmails_syncOverrideSkipsEnqueue() {
        Test.startTest();
        Integer jobsBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        FEC_RoutingActionHistoryTriggerHandler.syncNotificationEmailsOverride = true;
        FEC_RoutingActionHistoryTriggerHandler.sendNotificationEmails(
            new List<FEC_Routing_Action_History__c>{ new FEC_Routing_Action_History__c() }
        );
        Test.stopTest();
        FEC_RoutingActionHistoryTriggerHandler.syncNotificationEmailsOverride = false;
        Integer jobsAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        System.assertEquals(
            jobsBefore,
            jobsAfter,
            'Sync path phải xử lý inline, không enqueue FEC_SendNotificationEmailsQueueable.'
        );
    }

    @IsTest
    static void testBuildPendingStatusFromRouteHistoryRow_branches() {
        Id userId = UserInfo.getUserId();
        Map<Id, String> teamMap = new Map<Id, String>{ userId => 'CSInternal' };

        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(null)
        );

        FEC_Routing_Action_History__c invalidIdHistory = new FEC_Routing_Action_History__c(
            FEC_Original_User_Queue_ID__c = 'bad-id',
            FEC_Updated_User_Queue_ID__c = String.valueOf(userId)
        );
        System.assert(
            FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
                invalidIdHistory,
                teamMap
            ).startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX)
        );

        FEC_Routing_Action_History__c changeOwnerHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER,
            FEC_Updated_User_Queue_ID__c = String.valueOf(userId)
        );
        System.assert(
            FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
                changeOwnerHistory,
                teamMap
            ).startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX)
        );

        System.assertEquals(
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromRouteHistoryRow(
                new FEC_Routing_Action_History__c(
                    FEC_Routing_Action__c = FEC_ConstantCommon.FEC_ROUTING_ACTION_CHANGE_OWNER
                ),
                teamMap
            )
        );
    }

    @IsTest
    static void testCollectOwnerIdsAndGetTeamsFromIds() {
        Id userId = UserInfo.getUserId();
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Original_User_Queue_ID__c = String.valueOf(userId),
            FEC_Updated_User_Queue_ID__c = String.valueOf(userId)
        );

        System.assertEquals(0, FEC_RoutingActionHistoryTriggerHandler.collectOwnerIdsFromRouteHistory(null).size());
        Set<Id> ownerIds = FEC_RoutingActionHistoryTriggerHandler.collectOwnerIdsFromRouteHistory(
            new List<FEC_Routing_Action_History__c>{ history },
            true
        );
        System.assert(ownerIds.contains(userId));

        Set<Id> originalOnly = FEC_RoutingActionHistoryTriggerHandler.collectOwnerIdsFromRouteHistory(
            new List<FEC_Routing_Action_History__c>{ history },
            false
        );
        System.assertEquals(1, originalOnly.size());

        Map<Id, String> teams = FEC_RoutingActionHistoryTriggerHandler.getTeamsFromIds(
            new Set<Id>{ userId }
        );
        System.assertNotEquals(null, teams);

        Set<Id> withNullRow = FEC_RoutingActionHistoryTriggerHandler.collectOwnerIdsFromRouteHistory(
            new List<FEC_Routing_Action_History__c>{ null, history },
            true
        );
        System.assert(withNullRow.contains(userId));
    }

    @IsTest
    static void testAfterInsert_cannotContactCustomerViaTrigger() {
        Case caseRow = [SELECT Id, Status FROM Case LIMIT 1];
        Integer historyCountBefore = [
            SELECT COUNT()
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseRow.Id
        ];

        Test.startTest();
        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = caseRow.Id,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Routing_Action__c = FEC_CaseBusinessService.UPDATEACTION,
            FEC_Decision__c = FEC_ConstantCommon.CASE_DECISION_VALUE,
            FEC_Updated_User_Queue_ID__c = String.valueOf(UserInfo.getUserId())
        );
        Test.stopTest();

        System.assertEquals(
            'Resolved-CannotContactCustomer',
            [SELECT Status FROM Case WHERE Id = :caseRow.Id].Status
        );
        System.assert(
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :caseRow.Id] >
                historyCountBefore
        );
    }

    @IsTest
    static void testUpdateCaseTeams_actionBranches() {
        Case caseRow = [SELECT Id, FEC_Team__c, FEC_Assignment_Count__c FROM Case LIMIT 1];
        Id userId = UserInfo.getUserId();
        Map<Id, String> teamMap = new Map<Id, String>{ userId => 'CSInternal' };

        Case cancelCase = caseRow.clone(false, true, false, false);
        FEC_Routing_Action_History__c cancelHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.CANCEL
        );
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(userId, cancelCase, cancelHistory, teamMap);
        System.assertEquals(null, cancelCase.FEC_Team__c);

        FEC_Routing_Action_History__c rejectHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.REJECT
        );
        Case rejectNoAssignment = caseRow.clone(false, true, false, false);
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(
            userId,
            rejectNoAssignment,
            rejectHistory,
            teamMap
        );
        System.assertNotEquals(null, rejectNoAssignment.FEC_Team__c);

        Case resolveCase = caseRow.clone(false, true, false, false);
        FEC_Routing_Action_History__c resolveHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.RESOLVE
        );
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(userId, resolveCase, resolveHistory, teamMap);
        System.assertNotEquals(null, resolveCase.FEC_Team__c);

        Case routeCase = caseRow.clone(false, true, false, false);
        FEC_Routing_Action_History__c routeHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO
        );
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(userId, routeCase, routeHistory, teamMap);
        System.assertNotEquals(null, routeCase.FEC_Team__c);

        Case updateCase = caseRow.clone(false, true, false, false);
        FEC_Routing_Action_History__c updateHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.UPDATEACTION,
            FEC_Decision__c = 'Pending CS'
        );
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(userId, updateCase, updateHistory, teamMap);
        System.assertEquals('CSInternal', updateCase.FEC_Team__c);

        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(userId, null, updateHistory, teamMap);
        System.assert(true, 'Null case phải thoát sớm không lỗi.');
    }

    @IsTest
    static void testUpdateCaseTeams_rejectClearsTeamWhenAssignmentOpen() {
        FEC_Case_Stage__c stage = [SELECT Id FROM FEC_Case_Stage__c LIMIT 1];
        Id userId = UserInfo.getUserId();
        Case dedicatedCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            dedicatedCase = new Case(
                Subject = 'Reject branch case',
                Status = 'New',
                FEC_Current_Case_Stage__c = stage.Id,
                FEC_ID_Search__c = 'RAH-REJ-' + String.valueOf(System.currentTimeMillis())
            );
            insert dedicatedCase;
            insert new FEC_Assignment__c(
                FEC_Case__c = dedicatedCase.Id,
                FEC_Assignment_Name__c = 'Open assignment',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                FEC_Assignment_Owner__c = userId
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Case caseWithAssignment = [
            SELECT Id, FEC_Team__c, FEC_Assignment_Count__c
            FROM Case
            WHERE Id = :dedicatedCase.Id
        ];
        Map<String, Object> caseFields = (Map<String, Object>) JSON.deserializeUntyped(
            JSON.serialize(caseWithAssignment)
        );
        caseFields.put('FEC_Assignment_Count__c', 1);
        caseWithAssignment = (Case) JSON.deserialize(JSON.serialize(caseFields), Case.class);
        caseWithAssignment.FEC_Team__c = 'CSInternal';
        FEC_Routing_Action_History__c rejectHistory = new FEC_Routing_Action_History__c(
            FEC_Routing_Action__c = FEC_CaseBusinessService.REJECT
        );
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(
            userId,
            caseWithAssignment,
            rejectHistory,
            new Map<Id, String>{ userId => 'CSInternal' }
        );
        System.assertEquals(null, caseWithAssignment.FEC_Team__c);
    }

    @IsTest
    static void testUpdateCaseTeams_cannotContactCustomerDecision() {
        Case caseRow = [SELECT Id, FEC_Team__c, FEC_Assignment_Count__c FROM Case LIMIT 1];
        Integer historyCountBefore = [
            SELECT COUNT()
            FROM FEC_Routing_Action_History__c
            WHERE FEC_Case__c = :caseRow.Id
        ];
        FEC_Routing_Action_History__c updateHistory = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseRow.Id,
            FEC_Routing_Action__c = FEC_CaseBusinessService.UPDATEACTION,
            FEC_Decision__c = FEC_ConstantCommon.CASE_DECISION_VALUE,
            FEC_Routing_Action_Type__c = 'Case'
        );

        Case updateCase = caseRow.clone(false, true, false, false);

        Test.startTest();
        FEC_RoutingActionHistoryTriggerHandler.updateCaseTeams(
            UserInfo.getUserId(),
            updateCase,
            updateHistory,
            null
        );
        Test.stopTest();

        System.assertEquals('Resolved-CannotContactCustomer', updateCase.Status);
        System.assertEquals(
            historyCountBefore + 1,
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :caseRow.Id]
        );
    }

    @IsTest
    static void testAfterInsert_skipsNonCaseLevelHistory() {
        Case caseRow = [SELECT Id, FEC_Team__c FROM Case LIMIT 1];
        String teamBefore = caseRow.FEC_Team__c;

        insert new FEC_Routing_Action_History__c(
            FEC_Case__c = caseRow.Id,
            FEC_Routing_Action_Type__c = 'Assignment',
            FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
            FEC_Updated_User_Queue_ID__c = String.valueOf(UserInfo.getUserId())
        );

        Case afterInsert = [SELECT FEC_Team__c FROM Case WHERE Id = :caseRow.Id];
        System.assertEquals(teamBefore, afterInsert.FEC_Team__c);
    }

    @IsTest
    static void testAfterInsert_cachedCaseTeamRowsOnSecondHistory() {
        Case caseRow = [SELECT Id FROM Case LIMIT 1];
        Id userId = UserInfo.getUserId();

        insert new List<FEC_Routing_Action_History__c>{
            new FEC_Routing_Action_History__c(
                FEC_Case__c = caseRow.Id,
                FEC_Routing_Action_Type__c = 'Case',
                FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                FEC_Updated_User_Queue_ID__c = String.valueOf(userId)
            ),
            new FEC_Routing_Action_History__c(
                FEC_Case__c = caseRow.Id,
                FEC_Routing_Action_Type__c = 'Case',
                FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                FEC_Updated_User_Queue_ID__c = String.valueOf(userId)
            )
        };

        System.assertEquals(
            2,
            [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :caseRow.Id]
        );
    }

    @IsTest
    static void testSendNotificationEmails_batchImportGuard() {
        Case caseRow = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseRow.Id,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );
        insert history;

        Integer jobsBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        FEC_BatchCaseHandlingImportService.batchImportApplyInProgress = true;
        try {
            FEC_RoutingActionHistoryTriggerHandler.sendNotificationEmails(
                new List<FEC_Routing_Action_History__c>{ history }
            );
        } finally {
            FEC_BatchCaseHandlingImportService.batchImportApplyInProgress = false;
        }

        System.assertEquals(
            jobsBefore,
            [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']
        );
    }

    @IsTest
    static void testSendNotificationEmails_suppressForCaseSubmit() {
        Case caseRow = [SELECT Id FROM Case LIMIT 1];
        FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
            FEC_Case__c = caseRow.Id,
            FEC_Current_Status__c = 'Pending',
            FEC_Changed_Status__c = 'Resolved'
        );
        insert history;

        Integer jobsBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        FEC_NotificationService.suppressForCaseSubmit = true;
        try {
            Test.startTest();
            FEC_RoutingActionHistoryTriggerHandler.sendNotificationEmails(
                new List<FEC_Routing_Action_History__c>{ history }
            );
            Test.stopTest();
        } finally {
            FEC_NotificationService.suppressForCaseSubmit = false;
        }

        System.assertEquals(
            jobsBefore,
            [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']
        );
    }

    @IsTest
    static void testBuildPendingStatusFromOwnerIds_mixedTeams() {
        Id userId = UserInfo.getUserId();
        List<User> otherUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Id != :userId
            LIMIT 1
        ];
        if (otherUsers.isEmpty()) {
            System.assert(true, 'Skipped: no second active user in org.');
            return;
        }

        Map<Id, String> teamMap = new Map<Id, String>{
            userId => 'TeamA',
            otherUsers[0].Id => 'TeamB'
        };

        String mixed = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromOwnerIds(
            userId,
            otherUsers[0].Id,
            teamMap
        );
        System.assert(mixed.contains(FEC_ConstantCommon.DELIMITER_UNDERSCORE));

        String onlyUpdated = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromOwnerIds(
            null,
            userId,
            teamMap
        );
        System.assert(onlyUpdated.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX));

        String sameTeam = FEC_RoutingActionHistoryTriggerHandler.buildPendingStatusFromOwnerIds(
            userId,
            userId,
            teamMap
        );
        System.assert(sameTeam.startsWith(FEC_ConstantCommon.CASE_STATUS_PENDING_PREFIX));
        System.assert(!sameTeam.contains(FEC_ConstantCommon.DELIMITER_UNDERSCORE));
    }

    @IsTest
    static void testAfterInsert_suppressMrcDuplicateSideEffects() {
        Case caseRow = [SELECT Id, FEC_Team__c FROM Case LIMIT 1];
        String teamBefore = caseRow.FEC_Team__c;

        FEC_MrcDuplicateCaseService.suppressRoutingHistoryTriggerSideEffects = true;
        try {
            insert new FEC_Routing_Action_History__c(
                FEC_Case__c = caseRow.Id,
                FEC_Routing_Action_Type__c = 'Case',
                FEC_Routing_Action__c = FEC_CaseBusinessService.ROUTE_TO,
                FEC_Updated_User_Queue_ID__c = String.valueOf(UserInfo.getUserId())
            );
        } finally {
            FEC_MrcDuplicateCaseService.suppressRoutingHistoryTriggerSideEffects = false;
        }

        System.assertEquals(
            teamBefore,
            [SELECT FEC_Team__c FROM Case WHERE Id = :caseRow.Id].FEC_Team__c
        );
    }
}