/**
 * Unit tests for FEC_AssignmentController (routing history → Case / Assignment teams).
 */
@IsTest
private class FEC_AssignmentController_Test {

    private static final String QUEUE_DEV_NAME = 'FEC_AsgCtrl_Queue';
    private static final String QUEUE_LABEL = 'FEC AsgCtrl Test Queue';
    private static final String TARGET_TEAM = 'AsgCtrlTeam';

    private static User adminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupQueueAndTeamMapping() {
        Group testQueue = new Group(
            Name = QUEUE_LABEL,
            DeveloperName = QUEUE_DEV_NAME,
            Type = 'Queue'
        );
        insert testQueue;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
        }

        FEC_Team__c team = new FEC_Team__c(Name = TARGET_TEAM);
        insert team;

        insert new FEC_Team_Queue__c(
            FEC_Queue_Name__c = QUEUE_DEV_NAME,
            FEC_Select_Team__c = team.Id,
            FEC_Team__c = TARGET_TEAM
        );
    }

    private static Group getTestQueue() {
        return [
            SELECT Id, Name
            FROM Group
            WHERE DeveloperName = :QUEUE_DEV_NAME AND Type = 'Queue'
            LIMIT 1
        ];
    }

    private static Case insertCase(String team) {
        Case c = new Case(Subject = 'FEC_AssignmentController_Test');
        if (String.isNotBlank(team)) {
            c.FEC_Team__c = team;
        }
        insert c;
        return c;
    }

    private static FEC_Assignment__c insertAssignment(Id caseId, String status, String team) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'Unit Test Assignment ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            FEC_Assignment_Status__c = status,
            FEC_Team__c = team
        );
        insert a;
        return a;
    }

    private static FEC_Routing_Action_History__c buildCaseRoutingHistory(
        Id caseId,
        Id assignmentId,
        String queueDisplayName
    ) {
        return new FEC_Routing_Action_History__c(
            FEC_Assignment__c = assignmentId,
            FEC_Case__c = caseId,
            FEC_Routing_Action_Type__c = 'Case',
            FEC_Routing_Action__c = FEC_ConstantCommon.CASE_ROUTING_ACTION,
            FEC_Updated_User_Queue__c = queueDisplayName
        );
    }

    private static FEC_Routing_Action_History__c buildAssignmentHistory(
        Id caseId,
        Id assignmentId,
        String action,
        String decision
    ) {
        return new FEC_Routing_Action_History__c(
            FEC_Assignment__c = assignmentId,
            FEC_Case__c = caseId,
            FEC_Routing_Action_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            FEC_Routing_Action__c = action,
            FEC_Decision__c = decision
        );
    }

    @IsTest
    static void handle_nullOrEmpty_noOp() {
        // Verify no exceptions thrown when handling null or empty list
        Boolean exceptionThrown = false;
        try {
            FEC_AssignmentController.handle(null);
            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assertEquals(false, exceptionThrown, 'handle() should not throw exception for null or empty input');
    }

    @IsTest
    static void handle_skipsHistoryWithoutAssignment() {
        System.runAs(adminUser()) {
            Case c = insertCase(null);
            FEC_Routing_Action_History__c skipped = new FEC_Routing_Action_History__c(
                FEC_Case__c = c.Id,
                FEC_Routing_Action_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Routing_Action__c = FEC_ConstantCommon.CASE_REJECT_ACTION
            );
            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{ skipped });
            System.assertEquals(null, [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c);
        }
    }

    @IsTest
    static void handleCaseRouting_singleAssignment_setsTeamOnCaseAndAssignment() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase(null);
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                null
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildCaseRoutingHistory(c.Id, a.Id, q.Name)
            });

            Case loadedCase = [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id];
            FEC_Assignment__c loadedAssignment = [
                SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(TARGET_TEAM, loadedAssignment.FEC_Team__c);
            System.assert(loadedCase.FEC_Team__c.contains(TARGET_TEAM));
        }
    }

    @IsTest
    static void handleCaseRouting_multipleAssignments_usesElseBranch() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase(FEC_ConstantCommon.TEAM_VALUE_CSSUPPORT);
            FEC_Assignment__c a1 = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'OldTeam'
            );
            insertAssignment(c.Id, FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN, 'OtherTeam');

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildCaseRoutingHistory(c.Id, a1.Id, q.Name)
            });

            Case loadedCase = [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id];
            System.assert(!loadedCase.FEC_Team__c.contains(FEC_ConstantCommon.TEAM_VALUE_CSSUPPORT));
            System.assert(loadedCase.FEC_Team__c.contains(TARGET_TEAM));
        }
    }

    @IsTest
    static void handleCaseRouting_caseWithMultipleTeams_skipsSingleAssignmentBranch() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase('TeamA_TeamB');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildCaseRoutingHistory(c.Id, a.Id, q.Name)
            });

            Case loadedCase = [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id];
            System.assert(loadedCase.FEC_Team__c.contains('TeamA'));
            System.assert(loadedCase.FEC_Team__c.contains('TeamB'));
            System.assert(loadedCase.FEC_Team__c.contains(TARGET_TEAM));
        }
    }

    @IsTest
    static void handleCaseRouting_invalidHistory_noUpdate() {
        System.runAs(adminUser()) {
            Case c = insertCase('KeepMe');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                null
            );

            FEC_Routing_Action_History__c invalid = new FEC_Routing_Action_History__c(
                FEC_Assignment__c = a.Id,
                FEC_Case__c = c.Id,
                FEC_Routing_Action_Type__c = 'Case',
                FEC_Routing_Action__c = FEC_ConstantCommon.CASE_REJECT_ACTION
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{ invalid });

            System.assertEquals(
                'KeepMe',
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_routeViaOwnerId_setsTargetTeam() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase('OldTeam');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'OldTeam'
            );

            FEC_Routing_Action_History__c history = buildAssignmentHistory(
                c.Id,
                a.Id,
                FEC_ConstantCommon.CASE_TRANSFER_ACTION,
                null
            );
            history.FEC_Updated_User_Queue_ID__c = String.valueOf(q.Id);

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{ history });

            FEC_Assignment__c loadedAssignment = [
                SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(TARGET_TEAM, loadedAssignment.FEC_Team__c);
            System.assert(
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c.contains(TARGET_TEAM)
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_escalate_viaQueueDisplayName() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase(null);
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                null
            );

            FEC_Routing_Action_History__c history = buildAssignmentHistory(
                c.Id,
                a.Id,
                FEC_ConstantCommon.CASE_ESCALATE_ACTION,
                null
            );
            history.FEC_Updated_User_Queue__c = q.Name;

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{ history });

            System.assertEquals(
                TARGET_TEAM,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_routeTo_sameTeamOnOtherAssignment_keepsSharedTeam() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase('SharedTeam');
            FEC_Assignment__c a1 = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'SharedTeam'
            );
            insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'SharedTeam'
            );

            FEC_Routing_Action_History__c history = buildAssignmentHistory(
                c.Id,
                a1.Id,
                FEC_ConstantCommon.ACTION_ROUTE_TO,
                null
            );
            history.FEC_Updated_User_Queue__c = q.Name;

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{ history });

            System.assert(
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c.contains('SharedTeam')
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_reject_clearsTeamsWhenLastActive() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a.Id,
                    FEC_ConstantCommon.CASE_REJECT_ACTION,
                    null
                )
            });

            Case loadedCase = [
                SELECT FEC_Team__c, Status
                FROM Case
                WHERE Id = :c.Id
            ];
            FEC_Assignment__c loadedAssignment = [
                SELECT FEC_Team__c
                FROM FEC_Assignment__c
                WHERE Id = :a.Id
            ];
            System.assertEquals(null, loadedCase.FEC_Team__c);
            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
                loadedCase.Status
            );
            System.assertEquals(null, loadedAssignment.FEC_Team__c);
            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM FEC_Routing_Action_History__c
                    WHERE FEC_Case__c = :c.Id
                      AND FEC_Routing_Action__c = :FEC_ConstantCommon.CASE_RESOLVE_ACTION
                ]
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_resolve_otherActive_clearsOnlyAssignmentTeam() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a1 = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );
            insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a1.Id,
                    FEC_ConstantCommon.CASE_RESOLVE_ACTION,
                    null
                )
            });

            System.assertEquals(
                'TeamA',
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c
            );
            System.assertEquals(
                null,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a1.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_updateDecision_mapsTeamOnCase() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            String decision = 'Pending CS';
            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a.Id,
                    FEC_ConstantCommon.CASE_UPDATE_VALUE,
                    decision
                )
            });

            String expectedTeam = FEC_ConstantCommon.decisionToTeamMap.get(decision);
            FEC_Assignment__c loadedAssignment = [
                SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(expectedTeam, loadedAssignment.FEC_Team__c);
            System.assert(
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id].FEC_Team__c.contains(expectedTeam)
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_cannotContact_lastActive_resolvesCase() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a.Id,
                    FEC_ConstantCommon.CASE_UPDATE_VALUE,
                    FEC_ConstantCommon.CASE_DECISION_VALUE
                )
            });

            Case loadedCase = [
                SELECT FEC_Team__c, Status
                FROM Case
                WHERE Id = :c.Id
            ];
            System.assertEquals(null, loadedCase.FEC_Team__c);
            System.assertEquals(
                FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER,
                loadedCase.Status
            );
            System.assertEquals(
                null,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_cannotContact_otherActive_setsCannotContactTeam() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a1 = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );
            insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamB'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a1.Id,
                    FEC_ConstantCommon.CASE_UPDATE_VALUE,
                    FEC_ConstantCommon.CASE_DECISION_VALUE
                )
            });

            System.assert(
                [SELECT FEC_Team__c FROM Case WHERE Id = :c.Id]
                    .FEC_Team__c.contains(FEC_ConstantCommon.TEAM_VALUE)
            );
            System.assertEquals(
                FEC_ConstantCommon.TEAM_VALUE,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a1.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handleAssignmentRouting_revert_setsRevertingCreatorTeam() {
        System.runAs(adminUser()) {
            Case c = insertCase('TeamA');
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'TeamA'
            );

            FEC_AssignmentController.handle(new List<FEC_Routing_Action_History__c>{
                buildAssignmentHistory(
                    c.Id,
                    a.Id,
                    FEC_ConstantCommon.CASE_REVERT_ACTION,
                    null
                )
            });

            System.assertEquals(
                FEC_ConstantCommon.CASE_REVERTING_CREATOR,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id].FEC_Team__c
            );
        }
    }

    @IsTest
    static void handle_mixedHistories_processesValidOnes() {
        System.runAs(adminUser()) {
            Group q = getTestQueue();
            Case c = insertCase(null);
            FEC_Assignment__c a = insertAssignment(
                c.Id,
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                null
            );

            List<FEC_Routing_Action_History__c> batch = new List<FEC_Routing_Action_History__c>{
                new FEC_Routing_Action_History__c(
                    FEC_Case__c = c.Id,
                    FEC_Routing_Action_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                    FEC_Routing_Action__c = FEC_ConstantCommon.CASE_REJECT_ACTION
                ),
                buildCaseRoutingHistory(c.Id, a.Id, q.Name)
            };

            FEC_AssignmentController.handle(batch);

            System.assertEquals(
                TARGET_TEAM,
                [SELECT FEC_Team__c FROM FEC_Assignment__c WHERE Id = :a.Id].FEC_Team__c
            );
        }
    }
}
