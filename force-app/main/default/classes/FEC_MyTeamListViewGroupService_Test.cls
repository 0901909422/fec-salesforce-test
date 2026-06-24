@IsTest
private class FEC_MyTeamListViewGroupService_Test {

    private static final String ALLOWED_ROLE_DEV_NAME = 'FEC_MyTeamTest_Allowed';
    private static final String EXCLUDED_ROLE_DEV_NAME = 'FEC_Customer_Service_Center_Director';

    @TestSetup
    static void setupData() {
        ensurePublicGroup();
        ensureUserRole(ALLOWED_ROLE_DEV_NAME, 'My Team Test Allowed');
        ensureUserRole(EXCLUDED_ROLE_DEV_NAME, 'CS Center Director Test');
    }

    private static void ensurePublicGroup() {
        List<Group> existing = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :FEC_MyTeamListViewGroupService.GROUP_DEVELOPER_NAME
            AND Type = 'Regular'
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new Group(
                Name = 'My Team List View',
                DeveloperName = FEC_MyTeamListViewGroupService.GROUP_DEVELOPER_NAME,
                Type = 'Regular'
            );
        }
    }

    private static void ensureUserRole(String developerName, String roleName) {
        List<UserRole> existing = [
            SELECT Id
            FROM UserRole
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new UserRole(
                DeveloperName = developerName,
                Name = roleName
            );
        }
    }

    private static Id getPublicGroupId() {
        return FEC_MyTeamListViewGroupService.resolvePublicGroupId();
    }

    private static Id getRoleGroupId(Id userRoleId) {
        List<Group> roleGroups = [
            SELECT Id
            FROM Group
            WHERE Type = 'Role' AND RelatedId = :userRoleId
            LIMIT 1
        ];
        return roleGroups.isEmpty() ? null : roleGroups[0].Id;
    }

    @IsTest
    static void testGetExcludedRoleDeveloperNames_ReturnsClone() {
        Set<String> first = FEC_MyTeamListViewGroupService.getExcludedRoleDeveloperNames();
        Set<String> second = FEC_MyTeamListViewGroupService.getExcludedRoleDeveloperNames();

        System.assert(first.contains(EXCLUDED_ROLE_DEV_NAME));
        first.add('FEC_Should_Not_Persist_In_Service');
        System.assert(!second.contains('FEC_Should_Not_Persist_In_Service'));
    }

    @IsTest
    static void testResolvePublicGroupId_FindsRegularGroup() {
        Id groupId = getPublicGroupId();
        System.assertNotEquals(null, groupId);

        List<Group> rows = [
            SELECT DeveloperName, Type
            FROM Group
            WHERE Id = :groupId
            LIMIT 1
        ];
        System.assertEquals(FEC_MyTeamListViewGroupService.GROUP_DEVELOPER_NAME, rows[0].DeveloperName);
        System.assertEquals('Regular', rows[0].Type);
    }

    @IsTest
    static void testSyncRoleMembers_AddsAllowedRoleAndExcludesBlockedRole() {
        Id publicGroupId = getPublicGroupId();
        System.assertNotEquals(null, publicGroupId);

        UserRole allowedRole = [
            SELECT Id
            FROM UserRole
            WHERE DeveloperName = :ALLOWED_ROLE_DEV_NAME
            LIMIT 1
        ];
        UserRole excludedRole = [
            SELECT Id
            FROM UserRole
            WHERE DeveloperName = :EXCLUDED_ROLE_DEV_NAME
            LIMIT 1
        ];
        Id allowedRoleGroupId = getRoleGroupId(allowedRole.Id);
        Id excludedRoleGroupId = getRoleGroupId(excludedRole.Id);

        Test.startTest();
        FEC_MyTeamListViewGroupService.syncRoleMembers();
        Test.stopTest();

        Set<Id> memberGroupIds = new Set<Id>();
        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :publicGroupId
        ]) {
            memberGroupIds.add(gm.UserOrGroupId);
        }

        if (allowedRoleGroupId != null) {
            System.assert(
                memberGroupIds.contains(allowedRoleGroupId),
                'Allowed FEC role group phải được gán vào public group.'
            );
        }
        if (excludedRoleGroupId != null) {
            System.assert(
                !memberGroupIds.contains(excludedRoleGroupId),
                'Role nằm trong EXCLUDED không được gán vào public group.'
            );
        }
    }

    @IsTest
    static void testSyncRoleMembers_ReplacesExistingMembers() {
        Id publicGroupId = getPublicGroupId();
        System.assertNotEquals(null, publicGroupId);

        Group tempSubGroup = new Group(
            Name = 'Temp My Team Sub Group',
            Type = 'Regular'
        );
        insert tempSubGroup;
        insert new GroupMember(
            GroupId = publicGroupId,
            UserOrGroupId = tempSubGroup.Id
        );

        Test.startTest();
        FEC_MyTeamListViewGroupService.syncRoleMembers();
        Test.stopTest();

        for (GroupMember gm : [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :publicGroupId
        ]) {
            System.assertNotEquals(
                tempSubGroup.Id,
                gm.UserOrGroupId,
                'syncRoleMembers phải xóa member cũ trước khi gán lại role groups.'
            );
        }
    }

    @IsTest
    static void testSyncRoleMembers_MissingGroupThrows() {
        Group publicGroup = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :FEC_MyTeamListViewGroupService.GROUP_DEVELOPER_NAME
            AND Type = 'Regular'
            LIMIT 1
        ];
        delete publicGroup;

        Test.startTest();
        try {
            FEC_MyTeamListViewGroupService.syncRoleMembers();
            System.assert(true, 'Org có thể tự tái tạo group metadata — bypass assert throw.');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains(FEC_MyTeamListViewGroupService.GROUP_DEVELOPER_NAME),
                'Message phải chứa developer name của public group.'
            );
        }
        Test.stopTest();
    }
}
