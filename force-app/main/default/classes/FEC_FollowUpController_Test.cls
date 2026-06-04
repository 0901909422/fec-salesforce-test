@IsTest
private class FEC_FollowUpController_Test {

    @TestSetup
    static void setupData() {
        // Tạo Case mẫu
        Case c = new Case(Subject = 'Test Case', Status = 'Open');
        insert c;
    }

    @IsTest
    static void testFollowAndUnfollow() {
        Case c = [SELECT Id, OwnerId FROM Case LIMIT 1];
        String userId = UserInfo.getUserId();

        Test.startTest();
        // 1. Follow
        FEC_FollowUpController.followCase(c.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
        
        Map<String, Object> status = FEC_FollowUpController.checkFollowStatus(c.Id);
        System.assertEquals(true, status.get('isFollowing'));

        // 2. Unfollow
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
        // Case owner follow cho người khác
        String msg = FEC_FollowUpController.followCaseForUser(c.Id, targetUser.Id, FEC_ConstantCommon.FOLLOW_UP_FRONTEND_RESOLVED);
        Test.stopTest();

        System.assertNotEquals(null, msg);
        System.assert(msg.length() > 0, 'Follow-up should return a success message.');

        List<FEC_Watcher__c> watchers = [SELECT Id FROM FEC_Watcher__c WHERE FEC_Case__c = :c.Id AND FEC_Watcher_User__c = :targetUser.Id];
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
        FEC_FollowUpController.removeWatchersOnCaseResolved(new Set<Id>{c.Id});
        Test.stopTest();

        List<FEC_Watcher__c> watchers = [SELECT Id FROM FEC_Watcher__c WHERE Id = :w.Id];
        System.assertEquals(0, watchers.size(), 'Watcher Until Resolved phải bị xóa khi resolve case.');
    }

    @IsTest
    static void testSearchUsers() {
        Test.startTest();
        List<Map<String, String>> users = FEC_FollowUpController.searchUsers('Admin');
        Test.stopTest();
        
        System.assertNotEquals(null, users);
    }
}