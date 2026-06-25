@IsTest
private class FEC_FollowUpController_Test {

    @TestSetup
    static void setupData() {
        Case c = new Case(Subject = 'Test Case', Status = 'Open');
        insert c;
    }

    private static User createStandardUser(String suffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'fut' + suffix.left(4),
            Email = 'followup.test.' + suffix + '@fecredit.test.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FollowUpTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'followup.test.' + suffix + '@test.invalid'
        );
        insert u;
        return u;
    }

    @IsTest
    static void testFollowAndUnfollow() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        String userId = UserInfo.getUserId();

        Test.startTest();
        FEC_FollowUpController.followCase(c.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);

        Map<String, Object> status = FEC_FollowUpController.checkFollowStatus(c.Id);
        System.assertEquals(true, status.get('isFollowing'));

        FEC_FollowUpController.unfollowCase(c.Id);

        Map<String, Object> statusUnfollow = FEC_FollowUpController.checkFollowStatus(c.Id);
        System.assertEquals(false, statusUnfollow.get('isFollowing'));
        Test.stopTest();
    }

    @IsTest
    static void testFollowCaseForUser() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        User targetUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        String msg = FEC_FollowUpController.followCaseForUser(
            c.Id, targetUser.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
        Test.stopTest();

        System.assertNotEquals(null, msg);
        System.assert(msg.length() > 0, 'Follow-up should return a success message.');

        List<FEC_Watcher__c> watchers = [
            SELECT Id FROM FEC_Watcher__c
            WHERE FEC_Case__c = :c.Id AND FEC_Watcher_User__c = :targetUser.Id
        ];
        System.assertEquals(1, watchers.size());
    }

    @IsTest
    static void testRemoveWatchersOnCaseResolved() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Watcher__c w = new FEC_Watcher__c(
            FEC_Case__c = c.Id,
            FEC_Watcher_User__c = UserInfo.getUserId(),
            FEC_Active__c = true,
            FEC_Follow_up_Type__c = FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_RESOLVED
        );
        insert w;

        Test.startTest();
        FEC_FollowUpController.removeWatchersOnCaseResolved(new Set<Id>{ c.Id });
        Test.stopTest();

        List<FEC_Watcher__c> watchers = [SELECT Id FROM FEC_Watcher__c WHERE Id = :w.Id];
        System.assertEquals(0, watchers.size(), 'Watcher Until Resolved phải bị xóa khi resolve case.');
    }

    @IsTest
    static void testSearchUsers() {
        Test.startTest();
        List<Map<String, String>> users = FEC_FollowUpController.searchUsers('Admin');
        List<Map<String, String>> blankUsers = FEC_FollowUpController.searchUsers(null);
        List<Map<String, String>> shortTerm = FEC_FollowUpController.searchUsers('a');
        Test.stopTest();

        System.assertNotEquals(null, users);
        System.assertNotEquals(null, blankUsers);
        System.assertEquals(0, shortTerm.size(), 'Search term < 2 ký tự phải trả list rỗng.');
    }

    @IsTest
    static void testGetWatchersList() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        System.assertEquals(0, FEC_FollowUpController.getWatchersList(null).size());
        System.assertEquals(0, FEC_FollowUpController.getWatchersList('').size());

        FEC_FollowUpController.followCase(c.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_UNFOLLOW);

        List<FEC_FollowUpController.WatcherDetail> watchers =
            FEC_FollowUpController.getWatchersList(c.Id);
        System.assertEquals(1, watchers.size(), 'Phải trả 1 watcher đang active.');
        System.assertEquals(true, watchers[0].odtActive);
        System.assertNotEquals(null, watchers[0].odtId);
    }

    @IsTest
    static void testCheckFollowStatus_InactiveWatcher() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        delete [SELECT Id FROM FEC_Watcher__c WHERE FEC_Case__c = :c.Id];

        insert new FEC_Watcher__c(
            FEC_Case__c = c.Id,
            FEC_Watcher_User__c = UserInfo.getUserId(),
            FEC_Active__c = false,
            FEC_Follow_up_Type__c = FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_UNFOLLOW
        );

        Map<String, Object> status = FEC_FollowUpController.checkFollowStatus(c.Id);
        System.assertEquals(false, status.get('isFollowing'));
        System.assertEquals(
            FEC_ConstantCommon.FOLLOW_UP_FRONTEND_UNFOLLOW,
            status.get('followType'),
            'Phải pre-select follow type từ watcher inactive.'
        );
        System.assertNotEquals(null, status.get('canAddUserFollow'));
    }

    @IsTest
    static void testCanAddUserFollowHelpers() {
        System.assertEquals(false, FEC_FollowUpController.canCurrentUserAddFollowUpUser('CO'));
        System.assertEquals(true, FEC_FollowUpController.canCurrentUserAddFollowUpUser('CC'));
        System.assertEquals(false, FEC_FollowUpController.evaluateCanAddUserFollow(true, false, 'IT'));
        System.assertEquals(true, FEC_FollowUpController.evaluateCanAddUserFollow(true, false, 'CC'));
        System.assertEquals(true, FEC_FollowUpController.evaluateCanAddUserFollow(false, true, 'CO'));
        System.assertEquals(false, FEC_FollowUpController.evaluateCanAddUserFollow(false, false, 'CC'));
        System.assertEquals(false, FEC_FollowUpController.isRdItAdminUser(null));
    }

    @IsTest
    static void testFollowCaseForUser_ValidationErrors() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        User targetUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        try {
            FEC_FollowUpController.followCaseForUser(null, null, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
            System.assert(false, 'Phải throw khi caseId/targetUserId blank.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        User otherUser = createStandardUser(String.valueOf(System.currentTimeMillis()));
        Case ownedCase = [SELECT Id FROM Case LIMIT 1];

        System.runAs(otherUser) {
            try {
                FEC_FollowUpController.followCaseForUser(
                    ownedCase.Id, targetUser.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
                System.assert(false, 'Non-owner không được add follow-up user.');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }

        FEC_FollowUpController.followCaseForUser(
            c.Id, targetUser.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
        try {
            FEC_FollowUpController.followCaseForUser(
                c.Id, targetUser.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
            System.assert(false, 'Phải throw khi user đã là watcher active.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testUnfollowCase_AlreadyUnfollowed() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_FollowUpController.followCase(c.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);

        FEC_Watcher__c watcher = [
            SELECT Id FROM FEC_Watcher__c
            WHERE FEC_Case__c = :c.Id AND FEC_Watcher_User__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        update new FEC_Watcher__c(Id = watcher.Id, FEC_Active__c = false);

        String msg = FEC_FollowUpController.unfollowCase(c.Id);
        System.assertEquals(System.Label.FEC_MSG_FollowUp_Already_Unfollowed, msg);
    }

    @IsTest
    static void testAddUsersToFollowUpBulk() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        User targetUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        FEC_FollowUpController.addUsersToFollowUpBulk(
            new Map<Id, Set<Id>>{ c.Id => new Set<Id>{ targetUser.Id } },
            FEC_ConstantCommon.FOLLOW_UP_TYPE_UNTIL_UNFOLLOW
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM FEC_Watcher__c WHERE FEC_Case__c = :c.Id AND FEC_Watcher_User__c = :targetUser.Id],
            'Bulk follow phải tạo watcher cho target user.'
        );
    }
}
