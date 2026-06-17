@IsTest
private class FEC_UserManagerSync_Test {

    private static final String USER_GROUP_CC = 'CC';
    private static final String USER_GROUP_OB = 'OB';

    @TestSetup
    static void setupData() {
        UserRole parentRole = new UserRole(DeveloperName = 'UMS_Parent_Role', Name = 'UMS Manager Level');
        insert parentRole;

        UserRole childRole = new UserRole(
            DeveloperName = 'UMS_Child_Role',
            Name = 'UMS Agent Level',
            ParentRoleId = parentRole.Id
        );
        insert childRole;

        UserRole isolatedRole = new UserRole(DeveloperName = 'UMS_Isolated_Role', Name = 'UMS Isolated Level');
        insert isolatedRole;

        UserRole emptyParentRole = new UserRole(DeveloperName = 'UMS_Empty_Parent', Name = 'UMS Empty Parent');
        insert emptyParentRole;

        UserRole orphanChildRole = new UserRole(
            DeveloperName = 'UMS_Orphan_Child',
            Name = 'UMS Orphan Child',
            ParentRoleId = emptyParentRole.Id
        );
        insert orphanChildRole;

        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String suffix = String.valueOf(System.currentTimeMillis());

        User managerCc = new User(
            Alias = 'mgrcc',
            Email = 'ums.manager.cc' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AlphaManager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ums.manager.cc' + suffix + '@test.invalid',
            UserRoleId = parentRole.Id,
            FEC_User_Group__c = USER_GROUP_CC,
            IsActive = true
        );
        User managerOb = new User(
            Alias = 'mgrob',
            Email = 'ums.manager.ob' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'BetaManager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ums.manager.ob' + suffix + '@test.invalid',
            UserRoleId = parentRole.Id,
            FEC_User_Group__c = USER_GROUP_OB,
            IsActive = true
        );
        User childUser = new User(
            Alias = 'child',
            Email = 'ums.child' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ChildAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ums.child' + suffix + '@test.invalid',
            UserRoleId = childRole.Id,
            FEC_User_Group__c = USER_GROUP_CC,
            IsActive = true
        );
        User isolatedUser = new User(
            Alias = 'isolat',
            Email = 'ums.isolated' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'IsolatedAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ums.isolated' + suffix + '@test.invalid',
            UserRoleId = isolatedRole.Id,
            IsActive = true
        );
        User orphanChildUser = new User(
            Alias = 'orphan',
            Email = 'ums.orphan' + suffix + '@test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'OrphanAgent',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'ums.orphan' + suffix + '@test.invalid',
            UserRoleId = orphanChildRole.Id,
            IsActive = true
        );
        insert new List<User>{ managerCc, managerOb, childUser, isolatedUser, orphanChildUser };

        childUser.ManagerId = managerOb.Id;
        isolatedUser.ManagerId = managerCc.Id;
        update new List<User>{ childUser, isolatedUser };
    }

    @IsTest
    static void testResolveManagers_emptyInput() {
        System.assertEquals(0, FEC_UserManagerSyncService.resolveManagersForUsers(null).size());
        System.assertEquals(0, FEC_UserManagerSyncService.resolveManagersForUsers(new List<User>()).size());
    }

    @IsTest
    static void testResolveManagers_prefersMatchingUserGroup() {
        User childUser = [
            SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
            FROM User
            WHERE LastName = 'ChildAgent'
            LIMIT 1
        ];
        User managerCc = [SELECT Id FROM User WHERE LastName = 'AlphaManager' LIMIT 1];

        Map<Id, Id> resolved = FEC_UserManagerSyncService.resolveManagersForUsers(new List<User>{ childUser });

        System.assertEquals(1, resolved.size());
        System.assertEquals(managerCc.Id, resolved.get(childUser.Id));
    }

    @IsTest
    static void testResolveManagers_noParentRole_returnsNullManager() {
        User isolatedUser = [
            SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
            FROM User
            WHERE LastName = 'IsolatedAgent'
            LIMIT 1
        ];

        Map<Id, Id> resolved = FEC_UserManagerSyncService.resolveManagersForUsers(new List<User>{ isolatedUser });

        System.assertEquals(1, resolved.size());
        System.assertEquals(null, resolved.get(isolatedUser.Id));
    }

    @IsTest
    static void testResolveManagers_noManagerInParentRole_skipsUser() {
        User orphanChildUser = [
            SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
            FROM User
            WHERE LastName = 'OrphanAgent'
            LIMIT 1
        ];

        Map<Id, Id> resolved = FEC_UserManagerSyncService.resolveManagersForUsers(new List<User>{ orphanChildUser });

        System.assertEquals(false, resolved.containsKey(orphanChildUser.Id));
    }

    @IsTest
    static void testBuildUserUpdates_onlyChangedManagers() {
        User childUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'ChildAgent' LIMIT 1];
        User managerCc = [SELECT Id FROM User WHERE LastName = 'AlphaManager' LIMIT 1];

        List<User> unchanged = FEC_UserManagerSyncService.buildUserUpdates(
            new List<User>{ childUser },
            new Map<Id, Id>{ childUser.Id => childUser.ManagerId }
        );
        System.assertEquals(0, unchanged.size());

        List<User> changed = FEC_UserManagerSyncService.buildUserUpdates(
            new List<User>{ childUser },
            new Map<Id, Id>{ childUser.Id => managerCc.Id }
        );
        System.assertEquals(1, changed.size());
        System.assertEquals(managerCc.Id, changed[0].ManagerId);
    }

    @IsTest
    static void testBuildUserUpdates_emptyInputs() {
        System.assertEquals(0, FEC_UserManagerSyncService.buildUserUpdates(null, new Map<Id, Id>()).size());
        System.assertEquals(0, FEC_UserManagerSyncService.buildUserUpdates(new List<User>(), null).size());
        System.assertEquals(
            0,
            FEC_UserManagerSyncService.buildUserUpdates(new List<User>(), new Map<Id, Id>()).size()
        );
    }

    @IsTest
    static void testSyncManagers_updatesUsers() {
        User childUser = [
            SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
            FROM User
            WHERE LastName = 'ChildAgent'
            LIMIT 1
        ];
        User isolatedUser = [
            SELECT Id, ManagerId, UserRoleId, FEC_User_Group__c, UserRole.ParentRoleId
            FROM User
            WHERE LastName = 'IsolatedAgent'
            LIMIT 1
        ];
        User managerCc = [SELECT Id FROM User WHERE LastName = 'AlphaManager' LIMIT 1];

        System.assertNotEquals(managerCc.Id, childUser.ManagerId);
        System.assertNotEquals(null, isolatedUser.ManagerId);

        Test.startTest();
        FEC_UserManagerSyncService.syncManagers(new List<User>{ childUser, isolatedUser });
        Test.stopTest();

        childUser = [SELECT ManagerId FROM User WHERE Id = :childUser.Id];
        isolatedUser = [SELECT ManagerId FROM User WHERE Id = :isolatedUser.Id];

        System.assertEquals(managerCc.Id, childUser.ManagerId);
        System.assertEquals(null, isolatedUser.ManagerId);
    }

    @IsTest
    static void testBatch_executeUpdatesManagers() {
        User childUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'ChildAgent' LIMIT 1];
        User managerCc = [SELECT Id FROM User WHERE LastName = 'AlphaManager' LIMIT 1];
        System.assertNotEquals(managerCc.Id, childUser.ManagerId);

        Test.startTest();
        Database.executeBatch(new FEC_UserManagerSyncBatch(), 200);
        Test.stopTest();

        childUser = [SELECT ManagerId FROM User WHERE Id = :childUser.Id];
        System.assertEquals(managerCc.Id, childUser.ManagerId);
    }

    @IsTest
    static void testScheduler_executeRunsBatch() {
        User childUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'ChildAgent' LIMIT 1];
        User managerCc = [SELECT Id FROM User WHERE LastName = 'AlphaManager' LIMIT 1];
        System.assertNotEquals(managerCc.Id, childUser.ManagerId);

        Test.startTest();
        new FEC_UserManagerSyncScheduler().execute(null);
        Test.stopTest();

        childUser = [SELECT ManagerId FROM User WHERE Id = :childUser.Id];
        System.assertEquals(managerCc.Id, childUser.ManagerId);
    }

    @IsTest
    static void testScheduler_scheduleDailyJob() {
        Test.startTest();
        String firstJobId = FEC_UserManagerSyncScheduler.scheduleDailyJob();
        String secondJobId = FEC_UserManagerSyncScheduler.scheduleDailyJob();
        Test.stopTest();

        System.assertNotEquals(null, firstJobId);
        System.assertNotEquals(null, secondJobId);

        List<CronTrigger> scheduledJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'FEC User Manager Sync Daily%'
        ];
        System.assertEquals(1, scheduledJobs.size());
    }
}
