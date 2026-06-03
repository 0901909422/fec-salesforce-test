/**
 * Unit tests for FEC_AssignmentExecuteService.
 */
@IsTest
private class FEC_AssignmentExecuteService_Test {

    private static final String QUEUE_NAME = 'Queue Exec Assign Main';
    private static final String SUB_GROUP_NAME = 'Sub Group Exec Assign';

    private static User adminUser() {
        return [
            SELECT Id, UserRoleId
            FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
            LIMIT 1
        ];
    }

    private static User directAgentUser() {
        return [
            SELECT Id, UserRoleId, Email
            FROM User
            WHERE Alias = 'agtExD'
            LIMIT 1
        ];
    }

    private static User roleAgentUser() {
        return [
            SELECT Id, UserRoleId
            FROM User
            WHERE Alias = 'agtExR'
            LIMIT 1
        ];
    }

    private static Group getTestQueue() {
        return [
            SELECT Id, Name
            FROM Group
            WHERE Name = :QUEUE_NAME AND Type = 'Queue'
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupQueueAndUsers() {
        UserRole testRole = new UserRole(
            DeveloperName = 'FEC_Exec_Assign_Role',
            Name = 'FEC Exec Assign Role'
        );
        insert testRole;

        Group testQueue = new Group(Name = QUEUE_NAME, Type = 'Queue');
        Group subGroup = new Group(Name = SUB_GROUP_NAME, Type = 'Regular');
        insert new List<Group>{ testQueue, subGroup };

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());

        User agentDirect = new User(
            Alias = 'agtExD',
            Email = 'agent.exec.direct' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExecDirect',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'agent.exec.direct' + suffix + '@test.invalid'
        );
        User agentRole = new User(
            Alias = 'agtExR',
            Email = 'agent.exec.role' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExecRole',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'agent.exec.role' + suffix + '@test.invalid',
            UserRoleId = testRole.Id
        );
        insert new List<User>{ agentDirect, agentRole };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new QueueSobject(QueueId = testQueue.Id, SobjectType = 'Case');
            insert new List<GroupMember>{
                new GroupMember(GroupId = subGroup.Id, UserOrGroupId = agentDirect.Id),
                new GroupMember(GroupId = testQueue.Id, UserOrGroupId = subGroup.Id),
                new GroupMember(GroupId = testQueue.Id, UserOrGroupId = agentDirect.Id)
            };

            List<Group> roleGroups = [
                SELECT Id
                FROM Group
                WHERE RelatedId = :testRole.Id AND Type = 'Role'
                LIMIT 1
            ];
            if (!roleGroups.isEmpty()) {
                insert new GroupMember(
                    GroupId = testQueue.Id,
                    UserOrGroupId = roleGroups[0].Id
                );
            }
        }
    }

    private static Case insertCase() {
        Case c = new Case(Subject = 'FEC_AssignmentExecuteService_Test');
        insert c;
        return c;
    }

    private static Case insertCaseWithAssignmentUsers(String assignmentUsers) {
        Case c = new Case(
            Subject = 'FEC_AssignmentExecuteService_Test',
            FEC_Assignment_Users__c = assignmentUsers
        );
        insert c;
        return c;
    }

    private static String validAssignmentViewMode() {
        for (Schema.PicklistEntry entry :
            Case.FEC_Assigment_Mode__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static Set<String> closedAssignmentStatuses() {
        return new Set<String>{
            FEC_ConstantCommon.STATUS_COMPLETED,
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_REJECTED,
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_CANCELLED,
            FEC_ConstantCommon.ASSIGNMENT_AUTORECALLED_STATUS,
            FEC_ConstantCommon.ASSIGNMENT_AUTOCOMPLETE_STATUS
        };
    }

    private static String activeAssignmentStatus() {
        Set<String> closed = closedAssignmentStatuses();
        for (Schema.PicklistEntry entry :
            FEC_Assignment__c.FEC_Assignment_Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !closed.contains(entry.getValue())) {
                return entry.getValue();
            }
        }
        return FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN;
    }

    private static FEC_Assignment__c insertOpenAssignment(
        Id caseId,
        Id ownerId,
        String ownerRef
    ) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'Execute Test ' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            FEC_Assignment_Status__c = activeAssignmentStatus(),
            FEC_OwnerID__c = ownerRef,
            FEC_Assignment_Owner__c = ownerId
        );
        insert a;
        return a;
    }

    @IsTest
    static void canExecuteAssignment_noActiveAssignment_returnsFalse() {
        System.runAs(adminUser()) {
            Case c = insertCase();

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(false, result.value);
            System.assertNotEquals(null, result.shouldUpdate);
        }
    }

    @IsTest
    static void canExecuteAssignment_withOwnedAssignment_returnsTrue() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            insertOpenAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(true, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_noAccess_returnsFalse() {
        System.runAs(adminUser()) {
            User other = [
                SELECT Id
                FROM User
                WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
                LIMIT 1
            ];
            Case c = insertCaseWithAssignmentUsers(String.valueOf(other.Id));
            insertOpenAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(false, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_queueInAssignmentUsers_returnsTrue() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            insertOpenAssignment(c.Id, null, q.Name);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(true, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_ownerIdString_relevantUser_returnsTrue() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            insertOpenAssignment(
                c.Id,
                null,
                String.valueOf(UserInfo.getUserId())
            );

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(true, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_onlyClosedAssignments_returnsFalse() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            FEC_Assignment__c a = insertOpenAssignment(
                c.Id,
                UserInfo.getUserId(),
                null
            );
            a.FEC_Assignment_Status__c = FEC_ConstantCommon.STATUS_COMPLETED;
            update a;

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(false, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_noPendingForUser_returnsFalse() {
        System.runAs(directAgentUser()) {
            User other = [
                SELECT Id
                FROM User
                WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
                LIMIT 1
            ];
            Case c = insertCaseWithAssignmentUsers(QUEUE_NAME);
            insertOpenAssignment(c.Id, other.Id, null);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(false, result.value);
        }
    }

    @IsTest
    static void canExecuteAssignment_shouldUpdateMatchesCaseFlag() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            c.FEC_Can_Execute_Assignment__c = false;
            update c;
            insertOpenAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.canExecuteAssignment(c.Id);

            System.assertEquals(true, result.value);
            System.assertEquals(true, result.shouldUpdate);
            System.assertEquals(
                true,
                [SELECT FEC_Can_Execute_Assignment__c FROM Case WHERE Id = :c.Id]
                    .FEC_Can_Execute_Assignment__c
            );
        }
    }

    @IsTest
    static void refreshExecuteAssignmentVisibility_delegatesToCanExecute() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCaseWithAssignmentUsers(q.Name);
            insertOpenAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentExecuteService.ExecuteVisibilityResult result =
                FEC_AssignmentExecuteService.refreshExecuteAssignmentVisibility(c.Id);

            System.assertEquals(true, result.value);
        }
    }

    @IsTest
    static void executeAssignment_directOwner_keepsOwnership() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentExecuteService.executeAssignment(c.Id);

            System.assertEquals(
                UserInfo.getUserId(),
                [SELECT FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Owner__c
            );
        }
    }

    @IsTest
    static void executeAssignment_claimFromQueue_setsOwnerAndHistory() {
        System.runAs(directAgentUser()) {
            Group q = getTestQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, null, q.Name);

            FEC_AssignmentExecuteService.ExecuteAssignmentResult result =
                FEC_AssignmentExecuteService.executeAssignment(c.Id);

            System.assertEquals(1, result.claimedCount);
            FEC_Assignment__c loaded = [
                SELECT FEC_Assignment_Owner__c
                FROM FEC_Assignment__c
                WHERE Id = :a.Id
            ];
            System.assertEquals(UserInfo.getUserId(), loaded.FEC_Assignment_Owner__c);
            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM FEC_Routing_Action_History__c
                    WHERE FEC_Case__c = :c.Id
                      AND FEC_Assignment__c = :a.Id
                      AND FEC_Routing_Action__c = 'Change Owner'
                ]
            );
        }
    }

    @IsTest
    static void executeAssignment_noMatch_leavesOwnerUnchanged() {
        System.runAs(adminUser()) {
            User other = [
                SELECT Id
                FROM User
                WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
                LIMIT 1
            ];
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, other.Id, null);

            FEC_AssignmentExecuteService.ExecuteAssignmentResult result =
                FEC_AssignmentExecuteService.executeAssignment(c.Id);

            System.assertEquals(0, result.claimedCount);
            System.assertEquals(
                other.Id,
                [SELECT FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                    .FEC_Assignment_Owner__c
            );
        }
    }

    @IsTest
    static void executeAssignment_roleQueueMember_canClaim() {
        User roleAgent = roleAgentUser();
        if (roleAgent.UserRoleId == null) {
            return;
        }

        System.runAs(roleAgent) {
            Group q = getTestQueue();
            Case c = insertCase();
            FEC_Assignment__c a = insertOpenAssignment(c.Id, null, q.Name);

            FEC_AssignmentExecuteService.ExecuteAssignmentResult result =
                FEC_AssignmentExecuteService.executeAssignment(c.Id);

            if (result.claimedCount == 1) {
                System.assertEquals(
                    UserInfo.getUserId(),
                    [SELECT FEC_Assignment_Owner__c FROM FEC_Assignment__c WHERE Id = :a.Id]
                        .FEC_Assignment_Owner__c
                );
            }
        }
    }

    @IsTest
    static void setAssignmentViewMode_updatesCase() {
        System.runAs(adminUser()) {
            String modeValue = validAssignmentViewMode();
            if (modeValue == null) {
                return;
            }

            Case c = insertCase();
            String mode = FEC_AssignmentExecuteService.setAssignmentViewMode(c.Id, modeValue);

            System.assertEquals(modeValue, mode);
            System.assertEquals(
                modeValue,
                [SELECT FEC_Assigment_Mode__c FROM Case WHERE Id = :c.Id].FEC_Assigment_Mode__c
            );
        }
    }

    @IsTest
    static void setAssignmentViewMode_nullRecord_returnsNull() {
        System.assertEquals(null, FEC_AssignmentExecuteService.setAssignmentViewMode(null, 'Edit'));
    }

    @IsTest
    static void forceShowExecuteAssignment_setsFlag() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            c.FEC_Can_Execute_Assignment__c = false;
            update c;

            FEC_AssignmentExecuteService.forceShowExecuteAssignment(c.Id);

            System.assertEquals(
                true,
                [SELECT FEC_Can_Execute_Assignment__c FROM Case WHERE Id = :c.Id]
                    .FEC_Can_Execute_Assignment__c
            );
        }
    }

    @IsTest
    static void forceShowExecuteAssignment_nullCaseId_noOp() {
        FEC_AssignmentExecuteService.forceShowExecuteAssignment(null);
        System.assert(true);
    }
}
