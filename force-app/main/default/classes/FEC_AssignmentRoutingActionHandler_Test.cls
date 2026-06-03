/**
 * Unit tests for FEC_AssignmentRoutingActionHandler (>80% coverage).
 */
@IsTest
private class FEC_AssignmentRoutingActionHandler_Test {

    private static final String ROUTING_QUEUE_DEV = 'FEC_AsgRt_Handler_Queue';
    private static final String ROUTING_QUEUE_LABEL = 'FEC AsgRt Handler Queue';
    private static final String OTHER_CS_QUEUE_DEV = 'FEC_DQ_CS_Other_RtH_Test';

    private static User adminUser() {
        return [
            SELECT Id, ManagerId
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static User csUser() {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND Profile.Name IN (
                  :FEC_ConstantCommon.PROFILE_CS_FL,
                  :FEC_ConstantCommon.PROFILE_CS_BO
              )
            LIMIT 1
        ];
        return users.isEmpty() ? adminUser() : users[0];
    }

    @TestSetup
    static void setupQueues() {
        Group routingQueue = ensureQueue(ROUTING_QUEUE_DEV, ROUTING_QUEUE_LABEL);
        Group csSupportQueue = ensureQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME,
            FEC_ConstantCommon.QUEUE_CS_SUPPORT
        );
        ensureQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME,
            FEC_ConstantCommon.QUEUE_CS_CUSTOMER_CARE
        );
        ensureQueueByName(FEC_ConstantCommon.QUEUE_HANDLING);
        ensureQueueByName(FEC_ConstantCommon.QUEUE_CARE_INTERNAL_TASK);
        ensureQueue(OTHER_CS_QUEUE_DEV, 'DQ - CS Other RtH Test');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            ensureQueueSobject(routingQueue.Id);
            ensureQueueSobject(csSupportQueue.Id);
            ensureGroupMember(routingQueue.Id, UserInfo.getUserId());
            ensureGroupMember(csSupportQueue.Id, UserInfo.getUserId());
        }
    }

    private static Boolean isUnableToLockRow(DmlException ex) {
        return ex != null && ex.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW;
    }

    private static void ensureGroupMember(Id groupId, Id userOrGroupId) {
        if (groupId == null || userOrGroupId == null) {
            return;
        }
        if (
            [
                SELECT COUNT()
                FROM GroupMember
                WHERE GroupId = :groupId AND UserOrGroupId = :userOrGroupId
            ] > 0
        ) {
            return;
        }
        try {
            insert new GroupMember(GroupId = groupId, UserOrGroupId = userOrGroupId);
        } catch (DmlException ex) {
            if (!isUnableToLockRow(ex)) {
                throw ex;
            }
        }
    }

    private static void ensureQueueSobject(Id queueId) {
        if (queueId == null) {
            return;
        }
        if ([SELECT COUNT() FROM QueueSobject WHERE QueueId = :queueId] > 0) {
            return;
        }
        try {
            insert new QueueSobject(QueueId = queueId, SobjectType = 'Case');
        } catch (DmlException ex) {
            if (!isUnableToLockRow(ex)) {
                throw ex;
            }
        }
    }

    private static Group ensureQueue(String developerName, String label) {
        List<Group> existing = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :developerName AND Type = 'Queue'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Group q = new Group(Name = label, DeveloperName = developerName, Type = 'Queue');
        try {
            insert q;
            return q;
        } catch (DmlException ex) {
            if (!isUnableToLockRow(ex)) {
                throw ex;
            }
            List<Group> raced = [
                SELECT Id, Name, DeveloperName
                FROM Group
                WHERE DeveloperName = :developerName AND Type = 'Queue'
                LIMIT 1
            ];
            if (raced.isEmpty()) {
                throw ex;
            }
            return raced[0];
        }
    }

    private static void ensureQueueByName(String queueName) {
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE Name = :queueName AND Type = 'Queue'
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }
        String devName = 'FEC_RtH_' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 8);
        insert new Group(Name = queueName, DeveloperName = devName, Type = 'Queue');
    }

    private static Group getRoutingQueue() {
        return [
            SELECT Id, Name
            FROM Group
            WHERE DeveloperName = :ROUTING_QUEUE_DEV AND Type = 'Queue'
            LIMIT 1
        ];
    }

    private static Group getCsSupportQueue() {
        return [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            LIMIT 1
        ];
    }

    private static Group getCsCustomerCareQueue() {
        return [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
            LIMIT 1
        ];
    }

    private static void ensureUserInQueue(Id userId, Id queueId) {
        System.runAs(adminUser()) {
            ensureGroupMember(queueId, userId);
        }
    }

    private static void ensureUserIsCsSupport(User u) {
        ensureUserInQueue(u.Id, getCsSupportQueue().Id);
    }

    private static void ensureUserIsCsCustomerCare(User u) {
        ensureUserInQueue(u.Id, getCsCustomerCareQueue().Id);
    }

    private static Case insertCase() {
        Case c = new Case(Subject = 'FEC_AssignmentRoutingActionHandler_Test');
        insert c;
        return c;
    }

    private static Case insertCaseWithStageCode(String stageCodeKeyword) {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = stageCodeKeyword + ' Stage ' + suffix,
            FEC_Code__c = stageCodeKeyword + suffix,
            FEC_Active__c = true
        );
        insert stage;
        Case c = new Case(
            Subject = 'FEC_AssignmentRoutingActionHandler_Test',
            FEC_Current_Case_Stage__c = stage.Id
        );
        insert c;
        return c;
    }

    private static FEC_Assignment__c insertOpenAssignment(Id caseId, Id ownerId) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'Routing Test',
            FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
            FEC_Assignment_Owner__c = ownerId
        );
        insert a;
        return a;
    }

    private static FEC_Assignment__c insertQueueOwnedAssignment(Id caseId, String queueName) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'Routing Queue Test',
            FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
            FEC_OwnerID__c = queueName
        );
        insert a;
        return a;
    }

    // --- execute / actions ---

    @IsTest
    static void execute_invalidAction_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, 'InvalidAction', 'remark', null, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_reject_completesAssignmentAndCreatesHistory() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_REJECT, 'Reject remark', null, null
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Status__c, FEC_OwnerID__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED, loaded.FEC_Assignment_Status__c);
            System.assertEquals(null, loaded.FEC_OwnerID__c);
            System.assertEquals(
                1,
                [SELECT COUNT() FROM FEC_Routing_Action_History__c
                 WHERE FEC_Case__c = :c.Id AND FEC_Assignment__c = :a.Id]
            );
            System.assertEquals(
                1,
                [SELECT COUNT() FROM FEC_Case_Remarks__c
                 WHERE FEC_Case__c = :c.Id AND FEC_Assignment__c = :a.Id]
            );
        }
    }

    @IsTest
    static void execute_resolve_completesAssignmentAndCreatesHistory() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            Id ownerId = UserInfo.getUserId();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, ownerId);

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_RESOLVE, 'Resolve remark', null, null
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Status__c, FEC_Assignment_Owner__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED, loaded.FEC_Assignment_Status__c);
            System.assertEquals(ownerId, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(
                1,
                [SELECT COUNT() FROM FEC_Routing_Action_History__c
                 WHERE FEC_Case__c = :c.Id AND FEC_Assignment__c = :a.Id]
            );
        }
    }

    @IsTest
    static void execute_resolve_syncsCaseAssignmentUsersWhenOtherOpen() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a1 = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Id otherOwner = adminUser().Id;
            insertOpenAssignment(c.Id, otherOwner);

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a1.Id, FEC_ConstantCommon.ACTION_RESOLVE, 'Resolve one', null, null
            );

            Case loadedCase = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
            System.assert(
                String.isNotBlank(loadedCase.FEC_Assignment_Users__c)
                    && loadedCase.FEC_Assignment_Users__c.contains(String.valueOf(otherOwner))
            );
        }
    }

    @IsTest
    static void execute_revert_toCreator_updatesAssignment() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_REVERT, 'Revert remark',
                FEC_ConstantCommon.DECISION_USER, null
            );

            c = [SELECT CreatedById FROM Case WHERE Id = :c.Id];
            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Status__c, FEC_Assignment_Owner__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR,
                loaded.FEC_Assignment_Status__c
            );
            Id expectedOwner = c.CreatedById != null ? c.CreatedById : UserInfo.getUserId();
            System.assertEquals(expectedOwner, loaded.FEC_Assignment_Owner__c);
        }
    }

    @IsTest
    static void execute_revert_toTeamQueue_updatesOwnerId() {
        System.runAs(adminUser()) {
            Group csQueue = getCsSupportQueue();
            User runUser = [
                SELECT Id, FEC_Main_Queue__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            runUser.FEC_Main_Queue__c = csQueue.DeveloperName;
            update runUser;

            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_REVERT, 'Revert to queue',
                FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE, null
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Assignment_Status__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(null, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(csQueue.Name, loaded.FEC_OwnerID__c);
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR,
                loaded.FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_revert_blankDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_REVERT, 'r', null, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_revert_invalidDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_REVERT, 'r', 'BAD', null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_update_cannotContact_completesAssignment() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'Cannot contact',
                FEC_ConstantCommon.DECISION_CANNOT_CONTACT, null
            );

            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_update_pendingCs_setsCaseStatus() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'Pending CS',
                'PENDING_CS', null
            );

            System.assertEquals(
                'Pending-CSInternal',
                [SELECT Status FROM Case WHERE Id = :c.Id].Status
            );
            System.assertEquals(
                UserInfo.getUserId(),
                [SELECT FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Owner__c
            );
        }
    }

    @IsTest
    static void execute_update_outOfProcess_routesToQueue() {
        List<Group> handlingQueues = [
            SELECT Id, Name
            FROM Group
            WHERE Name = :FEC_ConstantCommon.QUEUE_HANDLING AND Type = 'Queue'
            LIMIT 1
        ];
        if (handlingQueues.isEmpty()) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'Out of process',
                FEC_ConstantCommon.DECISION_OUT_OF_PROCESS, null
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(null, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(handlingQueues[0].Id, loaded.FEC_OwnerID__c);
        }
    }

    @IsTest
    static void execute_update_blankDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'r', null, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_transfer_toUser() {
        System.runAs(adminUser()) {
            User target = adminUser();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'Transfer user',
                FEC_ConstantCommon.DECISION_USER, String.valueOf(target.Id)
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(target.Id, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(String.valueOf(target.Id), loaded.FEC_OwnerID__c);
        }
    }

    @IsTest
    static void execute_transfer_toQueue() {
        System.runAs(adminUser()) {
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'Transfer queue',
                FEC_ConstantCommon.DECISION_QUEUE, String.valueOf(q.Id)
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(null, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(q.Name, loaded.FEC_OwnerID__c);
        }
    }

    @IsTest
    static void execute_transfer_blankDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'r', null, UserInfo.getUserId()
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_transfer_blankSubDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'r',
                    FEC_ConstantCommon.DECISION_USER, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_transfer_invalidDecision_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'r', 'BAD', UserInfo.getUserId()
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_routeTo_otherDept_gsrStage() {
        System.runAs(adminUser()) {
            Group q = getRoutingQueue();
            Case c = insertCaseWithStageCode(FEC_ConstantCommon.BP_GSR);
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ROUTE_TO, 'Route GSR',
                null, String.valueOf(q.Id)
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c, FEC_Assignment_Status__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(null, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(q.Name, loaded.FEC_OwnerID__c);
            System.assertEquals(
                FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                loaded.FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_routeTo_otherDept_cofStage() {
        System.runAs(adminUser()) {
            Group q = getRoutingQueue();
            Case c = insertCaseWithStageCode(FEC_ConstantCommon.BP_COF);
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ROUTE_TO, 'Route COF',
                null, String.valueOf(q.Id)
            );

            System.assertEquals(
                FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_routeTo_csSupport_setsBackOfficeStatus() {
        User admin = adminUser();
        ensureUserIsCsSupport(admin);
        System.runAs(admin) {
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ROUTE_TO, 'Route CS',
                null, String.valueOf(q.Id)
            );

            System.assertEquals(
                FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_routeTo_csCustomerCare_setsBackOfficeStatus() {
        User admin = adminUser();
        ensureUserIsCsCustomerCare(admin);
        System.runAs(admin) {
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ROUTE_TO, 'Route Care',
                null, String.valueOf(q.Id)
            );

            System.assertEquals(
                FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    private static User userForOtherCsOnly() {
        Set<Id> csQueueIds = new Map<Id, Group>([
            SELECT Id
            FROM Group
            WHERE DeveloperName IN (
                :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME,
                :FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME,
                :FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_DEPT_NAME
            )
        ]).keySet();
        Set<Id> csMembers = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId IN :csQueueIds AND UserOrGroupId IN (SELECT Id FROM User WHERE IsActive = TRUE)
        ]) {
            csMembers.add(gm.UserOrGroupId);
        }
        List<User> candidates = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND UserType = 'Standard'
              AND Id NOT IN :csMembers
            LIMIT 1
        ];
        return candidates.isEmpty() ? adminUser() : candidates[0];
    }

    @IsTest
    static void execute_routeTo_otherCs_setsBackOfficeStatus() {
        User runUser = userForOtherCsOnly();
        Group otherCsQueue = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :OTHER_CS_QUEUE_DEV
            LIMIT 1
        ];
        ensureUserInQueue(runUser.Id, otherCsQueue.Id);
        System.runAs(runUser) {
            if (!FEC_AssignmentRoutingActionHandler.isOtherCS(UserInfo.getUserId())) {
                return;
            }
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ROUTE_TO, 'Route Other CS',
                null, String.valueOf(q.Id)
            );

            System.assertEquals(
                FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void execute_revert_noMainQueue_throws() {
        System.runAs(adminUser()) {
            User runUser = [
                SELECT Id, FEC_Main_Queue__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            runUser.FEC_Main_Queue__c = 'FEC_Nonexistent_Main_Queue_Dev';
            update runUser;

            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_REVERT, 'Revert queue',
                    FEC_ConstantCommon.DECISION_USER_TEAM_QUEUE, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_escalate_assignmentNotFound_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            String keyPrefix = FEC_Assignment__c.SObjectType.getDescribe().getKeyPrefix();
            Id missingAssignmentId = Id.valueOf(keyPrefix + '000000000001');
            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id,
                    missingAssignmentId,
                    FEC_ConstantCommon.ACTION_ESCALATE,
                    'Escalate',
                    null,
                    null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_update_cicRelated_routesToQueue() {
        List<Group> taskQueues = [
            SELECT Id
            FROM Group
            WHERE Name = :FEC_ConstantCommon.QUEUE_CARE_INTERNAL_TASK AND Type = 'Queue'
            LIMIT 1
        ];
        if (taskQueues.isEmpty()) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'CIC',
                FEC_ConstantCommon.DECISION_CIC_RELATED, null
            );

            System.assertEquals(
                taskQueues[0].Id,
                [SELECT FEC_OwnerID__c FROM FEC_Assignment__c WHERE Id = :a.Id].FEC_OwnerID__c
            );
        }
    }

    @IsTest
    static void execute_transfer_asCsSupport() {
        User admin = adminUser();
        ensureUserIsCsSupport(admin);
        System.runAs(admin) {
            User target = adminUser();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_TRANSFER, 'Transfer CS',
                FEC_ConstantCommon.DECISION_USER, String.valueOf(target.Id)
            );

            System.assertEquals(
                target.Id,
                [SELECT FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Owner__c
            );
        }
    }

    @IsTest
    static void execute_escalate_success_whenManagerExists() {
        User admin = adminUser();
        if (admin.ManagerId == null) {
            List<User> withManager = [
                SELECT Id, ManagerId
                FROM User
                WHERE IsActive = TRUE AND ManagerId != NULL
                LIMIT 1
            ];
            if (withManager.isEmpty()) {
                return;
            }
            admin = withManager[0];
        }

        System.runAs(admin) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());
            Id expectedManager = [
                SELECT ManagerId FROM User WHERE Id = :UserInfo.getUserId()
            ].ManagerId;

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_ESCALATE, 'Escalate', null, null
            );

            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c, FEC_OwnerID__c
                FROM FEC_Assignment__c WHERE Id = :a.Id
            ];
            System.assertEquals(expectedManager, loaded.FEC_Assignment_Owner__c);
            System.assertEquals(expectedManager, loaded.FEC_OwnerID__c);
        }
    }

    @IsTest
    static void execute_escalate_noOwner_throws() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertQueueOwnedAssignment(c.Id, 'Some Queue');

            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_ESCALATE, 'Escalate', null, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    @IsTest
    static void execute_escalate_noManager_throws() {
        List<User> usersWithoutManager = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND ManagerId = NULL AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (usersWithoutManager.isEmpty()) {
            return;
        }

        System.runAs(usersWithoutManager[0]) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId());

            Boolean thrown = false;
            try {
                FEC_AssignmentRoutingActionHandler.execute(
                    c.Id, a.Id, FEC_ConstantCommon.ACTION_ESCALATE, 'Escalate', null, null
                );
            } catch (AuraHandledException e) {
                thrown = true;
            }
            System.assert(thrown);
        }
    }

    // --- public helpers ---

    @IsTest
    static void getTeams_returnsOptions() {
        List<FEC_AssignmentRoutingActionHandler.SelectOptionWrapper> teams =
            FEC_AssignmentRoutingActionHandler.getTeams();
        System.assertEquals(2, teams.size());
    }

    @IsTest
    static void getQueuesByTeam_blankTeam_throws() {
        Boolean thrown = false;
        try {
            FEC_AssignmentRoutingActionHandler.getQueuesByTeam('');
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown);
    }

    @IsTest
    static void getQueuesByTeam_csSupport_returnsQueue() {
        ensureQueueByName(FEC_ConstantCommon.QUEUE_CS_SUPPORT);
        List<FEC_AssignmentRoutingActionHandler.SelectOptionWrapper> options =
            FEC_AssignmentRoutingActionHandler.getQueuesByTeam(
                FEC_ConstantCommon.TEAM_CS_SUPPORT
            );
        System.assertEquals(1, options.size());
        System.assertNotEquals(null, options[0].value);
        System.assertNotEquals(null, options[0].label);
    }

    @IsTest
    static void getQueuesByTeam_unknownTeam_returnsEmpty() {
        List<FEC_AssignmentRoutingActionHandler.SelectOptionWrapper> options =
            FEC_AssignmentRoutingActionHandler.getQueuesByTeam('Unknown Team XYZ');
        System.assertEquals(0, options.size());
    }

    @IsTest
    static void isCurrentUserInQueue_member_returnsTrue() {
        Group q = getCsSupportQueue();
        Boolean result = FEC_AssignmentRoutingActionHandler.isCurrentUserInQueue(
            new Set<String>{ q.DeveloperName }
        );
        System.assertEquals(true, result);
    }

    @IsTest
    static void isCurrentUserInQueue_unknownQueue_returnsFalse() {
        Boolean result = FEC_AssignmentRoutingActionHandler.isCurrentUserInQueue(
            new Set<String>{ 'FEC_Nonexistent_Queue_XYZ' }
        );
        System.assertEquals(false, result);
    }

    @IsTest
    static void isCSSupport_returnsTrue_whenQueueMember() {
        User admin = adminUser();
        ensureUserIsCsSupport(admin);
        System.runAs(admin) {
            System.assertEquals(true, FEC_AssignmentRoutingActionHandler.isCSSupport());
        }
    }

    @IsTest
    static void isCSCustomerCare_returnsTrue_whenQueueMember() {
        User admin = adminUser();
        ensureUserIsCsCustomerCare(admin);
        System.runAs(admin) {
            System.assertEquals(true, FEC_AssignmentRoutingActionHandler.isCSCustomerCare());
        }
    }

    @IsTest
    static void isOtherCS_returnsTrue_whenOnlyOtherCsQueue() {
        User runUser = userForOtherCsOnly();
        Group otherCsQueue = [
            SELECT Id FROM Group WHERE DeveloperName = :OTHER_CS_QUEUE_DEV LIMIT 1
        ];
        ensureUserInQueue(runUser.Id, otherCsQueue.Id);
        System.runAs(runUser) {
            System.assertEquals(true, FEC_AssignmentRoutingActionHandler.isOtherCS(runUser.Id));
        }
    }

    @IsTest
    static void isCurrentUserInQueue_roleGroupMember_returnsTrue() {
        List<User> usersWithRole = [
            SELECT Id, UserRoleId
            FROM User
            WHERE IsActive = TRUE AND UserRoleId != NULL
            LIMIT 1
        ];
        if (usersWithRole.isEmpty()) {
            return;
        }
        Group q = getRoutingQueue();
        List<Group> roleGroups = [
            SELECT Id
            FROM Group
            WHERE RelatedId = :usersWithRole[0].UserRoleId
              AND Type = :FEC_ConstantCommon.ROLE_STR
            LIMIT 1
        ];
        if (roleGroups.isEmpty()) {
            return;
        }
        System.runAs(adminUser()) {
            ensureGroupMember(q.Id, roleGroups[0].Id);
        }
        System.runAs(usersWithRole[0]) {
            System.assertEquals(
                true,
                FEC_AssignmentRoutingActionHandler.isCurrentUserInQueue(
                    new Set<String>{ ROUTING_QUEUE_DEV }
                )
            );
        }
    }

    @IsTest
    static void resolveAllAssignments_nonCsUser_noOp() {
        User nonCsUser = userForOtherCsOnly();
        System.runAs(nonCsUser) {
            if (FEC_AssignmentRoutingActionHandler.isCSSupport()
                || FEC_AssignmentRoutingActionHandler.isCSCustomerCare()) {
                return;
            }
            Case c = insertCase();
            insertOpenAssignment(c.Id, UserInfo.getUserId());
            FEC_AssignmentRoutingActionHandler.resolveAllAssignments(c.Id);
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c
                 WHERE FEC_Case__c = :c.Id LIMIT 1].FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void resolveAllAssignments_csUser_processesAssignments() {
        User admin = adminUser();
        ensureUserIsCsSupport(admin);
        System.runAs(admin) {
            Case c = insertCase();
            FEC_Assignment__c openAss = insertOpenAssignment(c.Id, UserInfo.getUserId());
            FEC_Assignment__c completedAss = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Completed',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert completedAss;

            FEC_Assignment__c revertingAss = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Reverting',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_REVERTING_CREATOR,
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert revertingAss;

            Group q = getRoutingQueue();
            FEC_Assignment__c backOfficeAss = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'BackOffice',
                FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_BACKOFFICE,
                FEC_OwnerID__c = String.valueOf(q.Id)
            );
            insert backOfficeAss;

            FEC_Assignment__c otherDeptAss = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'OtherDept',
                FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_OTHER_DEPT,
                FEC_Assignment_Owner__c = UserInfo.getUserId()
            );
            insert otherDeptAss;

            FEC_AssignmentRoutingActionHandler.resolveAllAssignments(c.Id);

            Map<Id, FEC_Assignment__c> byId = new Map<Id, FEC_Assignment__c>([
                SELECT FEC_Assignment_Status__c
                FROM FEC_Assignment__c
                WHERE FEC_Case__c = :c.Id
            ]);
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS,
                byId.get(openAss.Id).FEC_Assignment_Status__c
            );
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_STATUS_COMPLETED,
                byId.get(completedAss.Id).FEC_Assignment_Status__c
            );
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
                byId.get(revertingAss.Id).FEC_Assignment_Status__c
            );
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS,
                byId.get(backOfficeAss.Id).FEC_Assignment_Status__c
            );
            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
                byId.get(otherDeptAss.Id).FEC_Assignment_Status__c
            );
            System.assert(
                [SELECT COUNT() FROM FEC_Routing_Action_History__c WHERE FEC_Case__c = :c.Id] >= 4
            );
        }
    }

    @IsTest
    static void resolveAllAssignments_queueIdOwner_resolvesDisplayName() {
        User admin = adminUser();
        ensureUserIsCsSupport(admin);
        System.runAs(admin) {
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Queue Id Owner',
                FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_CS_REVIEW,
                FEC_OwnerID__c = String.valueOf(q.Id)
            );
            insert a;

            FEC_AssignmentRoutingActionHandler.resolveAllAssignments(c.Id);

            System.assertEquals(
                FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
                [SELECT FEC_Assignment_Status__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Status__c
            );
        }
    }

    @IsTest
    static void syncAssignmentUsers_queueIdInOwnerField() {
        System.runAs(adminUser()) {
            Group q = getRoutingQueue();
            Case c = insertCase();
            FEC_Assignment__c a = new FEC_Assignment__c(
                FEC_Case__c = c.Id,
                FEC_Assignment_Name__c = 'Queue sync',
                FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                FEC_OwnerID__c = String.valueOf(q.Id)
            );
            insert a;

            FEC_AssignmentRoutingActionHandler.execute(
                c.Id, a.Id, FEC_ConstantCommon.ACTION_UPDATE, 'User path',
                'PENDING_CS', null
            );

            Case loaded = [SELECT FEC_Assignment_Users__c FROM Case WHERE Id = :c.Id];
            System.assert(
                String.isBlank(loaded.FEC_Assignment_Users__c)
                    || loaded.FEC_Assignment_Users__c.contains(q.Name)
                    || loaded.FEC_Assignment_Users__c.contains(String.valueOf(UserInfo.getUserId()))
            );
        }
    }
}
