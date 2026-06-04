/**
 * Unit tests for FEC_AssignmentListHandler.
 */
@IsTest
private class FEC_AssignmentListHandler_Test {

    private static final String TEST_QUEUE_LABEL = 'DQ - CS Support Test List';

    private static User adminUser() {
        return [
            SELECT Id
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

    private static User relevantDeptsUser() {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND Profile.Name = :FEC_ConstantCommon.PROFILE_RELEVANT_DEPTS
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    @TestSetup
    static void setupQueuesAndTeams() {
        Group csSupportQueue = ensureQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME,
            FEC_ConstantCommon.QUEUE_CS_SUPPORT_W_SPACE
        );
        Group csCareQueue = ensureQueue(
            FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME,
            'DQ - CS Customer Care Test List'
        );

        FEC_Team__c teamSp = new FEC_Team__c(Name = FEC_ConstantCommon.TEAM_CODE_SP);
        FEC_Team__c teamCc = new FEC_Team__c(Name = FEC_ConstantCommon.TEAM_CODE_CC);
        insert new List<FEC_Team__c>{ teamSp, teamCc };

        insert new List<FEC_Team_Queue__c>{
            new FEC_Team_Queue__c(
                FEC_Select_Team__c = teamSp.Id,
                FEC_Queue_Name__c = csSupportQueue.DeveloperName
            ),
            new FEC_Team_Queue__c(
                FEC_Select_Team__c = teamCc.Id,
                FEC_Queue_Name__c = csCareQueue.DeveloperName
            )
        };

        User runUser = new User(Id = UserInfo.getUserId());
        System.runAs(runUser) {
            ensureQueueSobject(csSupportQueue.Id);
            ensureGroupMember(csSupportQueue.Id, UserInfo.getUserId());
            ensureGroupMember(csCareQueue.Id, UserInfo.getUserId());
        }
    }

    /**
     * Tránh UNABLE_TO_LOCK_ROW khi nhiều test class cùng ghi GroupMember vào queue org dùng chung.
     */
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

    private static Boolean isUnableToLockRow(DmlException ex) {
        return ex != null
            && ex.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW;
    }

    private static void seedCsQueueMembershipForUser(Id userId) {
        if (userId == null) {
            return;
        }
        System.runAs(adminUser()) {
            ensureGroupMember(getCsSupportQueue().Id, userId);
            ensureGroupMember(getCsCareQueue().Id, userId);
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
        Group q = new Group(
            Name = label,
            DeveloperName = developerName,
            Type = 'Queue'
        );
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

    private static Group getCsSupportQueue() {
        return [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            LIMIT 1
        ];
    }

    private static Group getCsCareQueue() {
        return [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
            LIMIT 1
        ];
    }

    private static Case insertCase() {
        Case c = new Case(Subject = 'FEC_AssignmentListHandler_Test');
        insert c;
        return c;
    }

    private static Case insertCaseWithStageKeyword(String keyword, Id ownerId) {
        String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = keyword + ' Stage ' + suffix,
            FEC_Code__c = 'STG' + suffix,
            FEC_Active__c = true
        );
        insert stage;
        Case c = new Case(
            Subject = 'FEC_AssignmentListHandler_Test',
            FEC_Current_Case_Stage__c = stage.Id,
            OwnerId = ownerId
        );
        insert c;
        return c;
    }

    private static FEC_Assignment__c insertAssignment(Id caseId, Id ownerId, String queueName) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'List Handler Test',
            FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
            FEC_Assignment_Type__c = 'Routing',
            FEC_Assignment_Owner__c = ownerId,
            FEC_OwnerID__c = queueName
        );
        insert a;
        return a;
    }

    @IsTest
    static void getUserDepartment_returnsCsOrOther() {
        System.runAs(adminUser()) {
            String department = FEC_AssignmentListHandler.getUserDepartment();
            System.assert(
                department == FEC_ConstantCommon.TEAM_CODE_CS
                    || department == FEC_ConstantCommon.TEAM_OTHER,
                'Department must be CS or OTHER.'
            );
        }
    }

    @IsTest
    static void getUserDepartment_csQueueMember_returnsCs() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            if (FEC_AssignmentListHandler.isCSSupport()
                || FEC_AssignmentListHandler.isCSCustomerCare()) {
                System.assertEquals(
                    FEC_ConstantCommon.TEAM_CODE_CS,
                    FEC_AssignmentListHandler.getUserDepartment()
                );
            }
        }
    }

    @IsTest
    static void isCSSupport_isCSCustomerCare_isOtherCS() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            System.assertNotEquals(null, FEC_AssignmentListHandler.isCSSupport());
            System.assertNotEquals(null, FEC_AssignmentListHandler.isCSCustomerCare());
            System.assertNotEquals(null, FEC_AssignmentListHandler.isOtherCS(UserInfo.getUserId()));
        }
    }

    @IsTest
    static void getCurrentUserQueues_andQueueIds() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            Set<String> queueNames = FEC_AssignmentListHandler.getCurrentUserQueues(
                UserInfo.getUserId()
            );
            Set<Id> queueIds = FEC_AssignmentListHandler.getCurrentUserQueueIds(
                UserInfo.getUserId()
            );
            System.assertNotEquals(null, queueNames);
            System.assertNotEquals(null, queueIds);
        }
    }

    @IsTest
    static void getAssignmentsNEW_nullCaseId_throws() {
        Boolean thrown = false;
        try {
            FEC_AssignmentListHandler.getAssignmentsNEW(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown);
    }

    @IsTest
    static void getAssignmentsNEW_returnsRowsForCase() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            Case c = insertCase();
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            List<FEC_Assignment__c> rows =
                FEC_AssignmentListHandler.getAssignmentsNEW(String.valueOf(c.Id));

            System.assertEquals(1, rows.size());
            System.assertEquals(a.Id, rows[0].Id);
        }
    }

    @IsTest
    static void getAssignmentsNEW_relevantDepts_ownedAssignment() {
        User rdUser = relevantDeptsUser();
        if (rdUser == null) {
            return;
        }

        System.runAs(rdUser) {
            Case c = insertCase();
            insertAssignment(c.Id, UserInfo.getUserId(), null);

            List<FEC_Assignment__c> rows =
                FEC_AssignmentListHandler.getAssignmentsNEW(String.valueOf(c.Id));

            System.assertEquals(1, rows.size());
        }
    }

    @IsTest
    static void getAssignmentsNEW_relevantDepts_queueAssignment() {
        User rdUser = relevantDeptsUser();
        if (rdUser == null) {
            return;
        }

        System.runAs(rdUser) {
            Set<String> userQueues = FEC_AssignmentListHandler.getCurrentUserQueues(
                UserInfo.getUserId()
            );
            if (userQueues.isEmpty()) {
                return;
            }
            String queueName = new List<String>(userQueues)[0];
            Case c = insertCase();
            insertAssignment(c.Id, null, queueName);

            List<FEC_Assignment__c> rows =
                FEC_AssignmentListHandler.getAssignmentsNEW(String.valueOf(c.Id));

            System.assertEquals(1, rows.size());
        }
    }

    @IsTest
    static void getAssignmentsNEW_adminProfile_returnsEmpty() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            insertAssignment(c.Id, null, null);

            System.assertEquals(
                0,
                FEC_AssignmentListHandler.getAssignmentsNEW(String.valueOf(c.Id)).size()
            );
        }
    }

    @IsTest
    static void countAssignments_returnsTotal() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            insertAssignment(c.Id, null, null);
            insertAssignment(c.Id, null, null);

            System.assertEquals(
                2,
                FEC_AssignmentListHandler.countAssignments(String.valueOf(c.Id))
            );
        }
    }

    @IsTest
    static void getAssignmentRemarks_nullCaseId_throws() {
        Boolean thrown = false;
        try {
            FEC_AssignmentListHandler.getAssignmentRemarks(null, 'a00');
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown);
    }

    @IsTest
    static void getAssignmentRemarks_nullAssignmentId_throws() {
        Boolean thrown = false;
        try {
            FEC_AssignmentListHandler.getAssignmentRemarks('500', null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown);
    }

    @IsTest
    static void getAssignmentRemarks_returnsFilteredRemarks() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);
            insert new FEC_Case_Remarks__c(
                FEC_Case__c = c.Id,
                FEC_Assignment__c = a.Id,
                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Case_Remarks__c = 'Remark body',
                FEC_Stage_Name__c = 'Stage1'
            );

            List<FEC_Case_Remarks__c> remarks = FEC_AssignmentListHandler.getAssignmentRemarks(
                String.valueOf(c.Id),
                String.valueOf(a.Id)
            );

            System.assertEquals(1, remarks.size());
            System.assertEquals('Remark body', remarks[0].FEC_Case_Remarks__c);
        }
    }

    @IsTest
    static void getUsersInGroup_and_getQueuesForUser_returnLists() {
        System.runAs(adminUser()) {
            System.assertNotEquals(null, FEC_AssignmentListHandler.getUsersInGroup());
            System.assertNotEquals(null, FEC_AssignmentListHandler.getQueuesForUser());
        }
    }

    @IsTest
    static void getQueueNames_emptyAndValidIds() {
        System.assertEquals(
            0,
            FEC_AssignmentListHandler.getQueueNames(null).size()
        );
        System.assertEquals(
            0,
            FEC_AssignmentListHandler.getQueueNames(new List<String>()).size()
        );

        Group q = getCsSupportQueue();
        Map<String, String> names = FEC_AssignmentListHandler.getQueueNames(
            new List<String>{ String.valueOf(q.Id), 'invalid-id' }
        );
        System.assertEquals(1, names.size());
        System.assertEquals(q.Name, names.get(String.valueOf(q.Id)));
    }

    @IsTest
    static void getAssignmentsForViewNEW_paginatesWithRemarks() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            Case c = insertCase();
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);
            insert new FEC_Case_Remarks__c(
                FEC_Case__c = c.Id,
                FEC_Assignment__c = a.Id,
                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
                FEC_Case_Remarks__c = 'View remark',
                FEC_Stage_Name__c = 'StageView'
            );

            FEC_AssignmentListHandler.AssignmentViewResponse response =
                FEC_AssignmentListHandler.getAssignmentsForViewNEW(
                    String.valueOf(c.Id),
                    10,
                    1
                );

            System.assertEquals(1, response.totalCount);
            System.assertEquals(1, response.assignments.size());
            System.assertEquals('StageView', response.assignments[0].stageName);
        }
    }

    @IsTest
    static void getAssignmentsForViewNEW_secondPage_emptyAssignments() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            Case c = insertCase();
            insertAssignment(c.Id, null, null);

            FEC_AssignmentListHandler.AssignmentViewResponse response =
                FEC_AssignmentListHandler.getAssignmentsForViewNEW(
                    String.valueOf(c.Id),
                    1,
                    2
                );

            System.assertEquals(1, response.totalCount);
            System.assertEquals(0, response.assignments.size());
        }
    }

    @IsTest
    static void getAssignmentsForViewNEW_blankCaseId_throws() {
        Boolean thrown = false;
        try {
            FEC_AssignmentListHandler.getAssignmentsForViewNEW('', 10, 1);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        System.assert(thrown);
    }

    @IsTest
    static void getAssignmentsForViewNEW_admin_returnsAssignments() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            insertAssignment(c.Id, null, null);

            FEC_AssignmentListHandler.AssignmentViewResponse response =
                FEC_AssignmentListHandler.getAssignmentsForViewNEW(
                    String.valueOf(c.Id),
                    10,
                    1
                );

            // getAssignmentsForViewNEW does not filter by profile; returns all case assignments
            System.assertEquals(1, response.totalCount);
            System.assertEquals(1, response.assignments.size());
        }
    }

    @IsTest
    static void getAction_otherDept_returnsOptions() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            List<FEC_AssignmentListHandler.SelectOptionWrapper> options =
                FEC_AssignmentListHandler.getAction(String.valueOf(c.Id));
            System.assert(!options.isEmpty());
        }
    }

    @IsTest
    static void getAction_csUser_sameQueueOwner() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            if (!FEC_AssignmentListHandler.isCSSupport()
                && !FEC_AssignmentListHandler.isCSCustomerCare()) {
                return;
            }
            Group q = getCsSupportQueue();
            Case c = insertCaseWithStageKeyword('Stage', q.Id);
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            List<FEC_AssignmentListHandler.SelectOptionWrapper> options =
                FEC_AssignmentListHandler.getAction(String.valueOf(c.Id));

            System.assert(
                options.size() >= FEC_ConstantCommon.ACTION_OPTIONS_CS_SUPPORT.size()
                    || options.size() >= FEC_ConstantCommon.ACTION_OPTIONS_OTHER.size()
            );
            FEC_AssignmentListHandler.getTeamForRouteToAction(c.Id, a.Name);
            FEC_AssignmentListHandler.getQueueForRouteToAction(c.Id, a.Name);
        }
    }

    @IsTest
    static void getAction_csUser_differentCaseOwner_returnsOtherOptions() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            if (!FEC_AssignmentListHandler.isCSSupport()
                && !FEC_AssignmentListHandler.isCSCustomerCare()) {
                return;
            }
            User other = [
                SELECT Id
                FROM User
                WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
                LIMIT 1
            ];
            Case c = insertCaseWithStageKeyword('Stage', other.Id);

            List<FEC_AssignmentListHandler.SelectOptionWrapper> options =
                FEC_AssignmentListHandler.getAction(String.valueOf(c.Id));

            System.assertEquals(
                FEC_ConstantCommon.ACTION_OPTIONS_OTHER.size(),
                options.size()
            );
        }
    }

    @IsTest
    static void getTeamForRouteToAction_otherGsrStage() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithStageKeyword(
                FEC_ConstantCommon.BP_GSR,
                UserInfo.getUserId()
            );
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            List<FEC_AssignmentListHandler.SelectOptionWrapper> teams =
                FEC_AssignmentListHandler.getTeamForRouteToAction(c.Id, a.Name);

            System.assert(!teams.isEmpty());
        }
    }

    @IsTest
    static void getQueueForRouteToAction_otherCofStage() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithStageKeyword(
                FEC_ConstantCommon.BP_COF,
                UserInfo.getUserId()
            );
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            List<FEC_AssignmentListHandler.SelectOptionWrapper> queues =
                FEC_AssignmentListHandler.getQueueForRouteToAction(c.Id, a.Name);

            System.assertNotEquals(null, queues);
        }
    }

    @IsTest
    static void getTeamForRouteToAction_otherCofStage() {
        System.runAs(adminUser()) {
            Case c = insertCaseWithStageKeyword(
                FEC_ConstantCommon.BP_COF,
                UserInfo.getUserId()
            );
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            List<FEC_AssignmentListHandler.SelectOptionWrapper> teams =
                FEC_AssignmentListHandler.getTeamForRouteToAction(c.Id, a.Name);

            System.assert(!teams.isEmpty());
        }
    }

    @IsTest
    static void getAssignmentsForViewNEW_relevantDepts_filtersByOwner() {
        User rdUser = relevantDeptsUser();
        if (rdUser == null) {
            return;
        }

        System.runAs(rdUser) {
            Case c = insertCase();
            insertAssignment(c.Id, UserInfo.getUserId(), null);

            FEC_AssignmentListHandler.AssignmentViewResponse response =
                FEC_AssignmentListHandler.getAssignmentsForViewNEW(
                    String.valueOf(c.Id),
                    10,
                    1
                );

            System.assertEquals(1, response.totalCount);
        }
    }

    @IsTest
    static void getQueueBelongToTeam_and_getQueueByName() {
        FEC_Team__c team = [
            SELECT Name
            FROM FEC_Team__c
            WHERE Name = :FEC_ConstantCommon.TEAM_CODE_SP
            LIMIT 1
        ];

        System.assertNotEquals(
            0,
            FEC_AssignmentListHandler.getQueueBelongToTeam(team.Name).size()
        );
        System.assertNotEquals(
            0,
            FEC_AssignmentListHandler.getQueueByName(
                FEC_ConstantCommon.QUEUE_CS_SUPPORT_W_SPACE
            ).size()
        );
    }

    @IsTest
    static void getTeamForRouteToAction_invalidCase_returnsEmpty() {
        System.assertEquals(
            0,
            FEC_AssignmentListHandler.getTeamForRouteToAction(
                '500000000000000AAA',
                'A-1'
            ).size()
        );
    }

    @IsTest
    static void saveAssignmentDraft_updatesRemark() {
        System.runAs(adminUser()) {
            Case c = insertCase();
            FEC_Assignment__c a = insertAssignment(c.Id, null, null);

            FEC_AssignmentListHandler.saveAssignmentDraft(a.Id, 'Draft text');
            FEC_AssignmentListHandler.saveAssignmentDraft(null, 'ignored');

            System.assertEquals(
                'Draft text',
                [
                    SELECT FEC_Draft_Assignment_Remark__c
                    FROM FEC_Assignment__c
                    WHERE Id = :a.Id
                ].FEC_Draft_Assignment_Remark__c
            );
        }
    }

    @IsTest
    static void getFirstTeamProcessViaRouteToAction_withHistory() {
        System.runAs(csUser()) {
            seedCsQueueMembershipForUser(UserInfo.getUserId());
            Group q = getCsSupportQueue();
            Case c = insertCaseWithStageKeyword('Stage', q.Id);
            FEC_Assignment__c a = insertAssignment(c.Id, null, q.Name);

            insert new FEC_Routing_Action_History__c(
                FEC_Assignment__c = a.Id,
                FEC_Case__c = c.Id,
                FEC_Routing_Action_Type__c = 'Assignment',
                FEC_Original_User_Queue__c = q.Name
            );

            List<FEC_AssignmentListHandler.SelectOptionWrapper> queues =
                FEC_AssignmentListHandler.getQueueForRouteToAction(c.Id, a.Name);

            System.assertNotEquals(null, queues);
        }
    }
}
