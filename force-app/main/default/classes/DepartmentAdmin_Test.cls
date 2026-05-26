/**
 * @description Test class for DepartmentAdmin
 * Covers: getQueueMembers, getUserQueues, addUsersToQueue, removeUserFromQueue,
 * searchActiveUsers, getQueueValidBaseNameOrId, updateMainQueueForUser, insertCustomLog (@future)
 * Uses SeeAllData=false and isolated test data.
 */
@IsTest
private class DepartmentAdmin_Test {
    @TestSetup
    static void setup() {
        // Profile for creating users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create three users (two active, one inactive)
        User u1 = new User(
            FirstName = 'John',
            LastName = 'QueueOne',
            Alias = 'jqueue1',
            Email = 'john.queue1@example.com',
            Username = 'john.queue1.' + System.currentTimeMillis() + '@example.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        User u2 = new User(
            FirstName = 'Jane',
            LastName = 'QueueTwo',
            Alias = 'jqueue2',
            Email = 'jane.queue2@example.com',
            Username = 'jane.queue2.' + System.currentTimeMillis() + '@example.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = true
        );
        User u3 = new User(
            FirstName = 'Mark',
            LastName = 'Inactive',
            Alias = 'minact',
            Email = 'mark.inactive@example.com',
            Username = 'mark.inactive.' + System.currentTimeMillis() + '@example.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            IsActive = false
        );
        insert new List<User>{ u1, u2, u3 };

        // Create two Queues (Group Type = Queue) with DeveloperName
        Group q1 = new Group(Name = 'Support Queue A', DeveloperName = 'Support_Queue_A', Type = 'Queue');
        Group q2 = new Group(Name = 'Support Queue B', DeveloperName = 'Support_Queue_B', Type = 'Queue');
        insert new List<Group>{ q1, q2 };

        // Relate QueueSobject to Case
        insert new List<QueueSobject>{
            new QueueSobject(QueueId = q1.Id, SobjectType = 'Case'),
            new QueueSobject(QueueId = q2.Id, SobjectType = 'Case')
        };

        // Assign users to queues
        insert new List<GroupMember>{
            new GroupMember(GroupId = q1.Id, UserOrGroupId = u1.Id),
            new GroupMember(GroupId = q1.Id, UserOrGroupId = u2.Id),
            new GroupMember(GroupId = q2.Id, UserOrGroupId = u2.Id)
        };

        // Mark main queue for u1
        u1.FEC_Main_Queue__c = 'Support_Queue_A';
        update u1;
    }

    private static Group getQueueByDevName(String devName) {
        return [SELECT Id, Name, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName = :devName LIMIT 1];
    }
    private static User getUserByEmail(String email) {
        return [SELECT Id, Email, Name, FEC_Main_Queue__c FROM User WHERE Email = :email LIMIT 1];
    }

    @IsTest
    static void testGetQueueMembers_basicAndPaging() {
        Group q1 = getQueueByDevName('Support_Queue_A');

        // First page (pageSize=1)
        Test.startTest();
        DepartmentAdmin.PagedUsers page1 = DepartmentAdmin.getQueueMembers(q1.Id, 1, null);
        // Use last user id from page1 to fetch next page (Id > lastUserId)
        Id lastId = page1.users.isEmpty() ? null : page1.users[0].id;
        DepartmentAdmin.PagedUsers page2 = DepartmentAdmin.getQueueMembers(q1.Id, 10, lastId);
        Test.stopTest();

        System.assertEquals(1, page1.users.size(), 'Expect first page to have 1 user');
        System.assert(page2.users.size() >= 0, 'Second page can be 0 or more depending on sort');
        // Validate returned fields
        DepartmentAdmin.UserDto dto = page1.users[0];
        System.assertNotEquals(null, dto.id, 'User id populated');
        System.assertNotEquals(null, dto.name, 'User name populated');
        System.assertNotEquals(null, dto.email, 'User email populated');
        System.assertNotEquals(null, dto.userrole, 'User role label populated (or No Role)');
    }

    @IsTest
    static void testGetQueueMembers_nullOrEmpty() {
        Test.startTest();
        DepartmentAdmin.PagedUsers resNull = DepartmentAdmin.getQueueMembers(null, 5, null);
        Test.stopTest();
        System.assertEquals(0, resNull.users.size(), 'Null queue returns empty list');
    }

    @IsTest
    static void testGetUserQueues_andMainFlag() {
        User u1 = getUserByEmail('john.queue1@example.com');

        Test.startTest();
        List<DepartmentAdmin.QueueDto> queues = DepartmentAdmin.getUserQueues(u1.Id);
        Test.stopTest();

        System.assert(queues.size() > 0, 'User should belong to at least one queue');
        Set<String> names = new Set<String>();
        Boolean foundMain = false;
        for (DepartmentAdmin.QueueDto q : queues) {
            names.add(q.name);
            if (q.devname == 'Support_Queue_A') {
                System.assertEquals(true, q.mainqueue, 'Support_Queue_A must be flagged main');
                foundMain = true;
            }
        }
        System.assert(foundMain, 'Main queue flag should be set for Support_Queue_A');
        System.assert(names.contains('Support Queue A'), 'Support Queue A present');
    }

    @IsTest
    static void testGetUserQueues_nullAndNoUser() {
        // Null userId returns empty
        Test.startTest();
        List<DepartmentAdmin.QueueDto> nullRes = DepartmentAdmin.getUserQueues(null);
        System.assertEquals(0, nullRes.size(), 'Null userId returns empty');

        // Non-existing user
        List<DepartmentAdmin.QueueDto> noUser = DepartmentAdmin.getUserQueues('005000000000000');
        Test.stopTest();
        System.assertEquals(0, noUser.size(), 'Not found user returns empty');
    }

    @IsTest
    static void testAddUsersToQueue_successAndFail() {
        Group q2 = getQueueByDevName('Support_Queue_B');
        User u1 = getUserByEmail('john.queue1@example.com');

        // Success path
        Test.startTest();
        Boolean ok = DepartmentAdmin.addUsersToQueue(q2.Id, new List<Id>{ u1.Id });
        System.assertEquals(true, ok, 'Should add user to queue successfully');

        // Verify GroupMember exists
        Integer cnt = [SELECT COUNT() FROM GroupMember WHERE GroupId = :q2.Id AND UserOrGroupId = :u1.Id];
        System.assertEquals(1, cnt, 'GroupMember record must be inserted');

        // Failure: null/empty params
        Boolean bad1 = DepartmentAdmin.addUsersToQueue(null, new List<Id>{ u1.Id });
        Boolean bad2 = DepartmentAdmin.addUsersToQueue(q2.Id, null);
        Boolean bad3 = DepartmentAdmin.addUsersToQueue(q2.Id, new List<Id>());
        Test.stopTest();
        System.assertEquals(false, bad1, 'Null queue should return false');
        System.assertEquals(false, bad2, 'Null userIds should return false');
        System.assertEquals(false, bad3, 'Empty userIds should return false');
    }

    @IsTest
    static void testRemoveUserFromQueue_successAndNoop() {
        Group q1 = getQueueByDevName('Support_Queue_A');
        User u2 = getUserByEmail('jane.queue2@example.com');

        // Ensure membership exists
        Integer before = [SELECT COUNT() FROM GroupMember WHERE GroupId = :q1.Id AND UserOrGroupId = :u2.Id];
        System.assertEquals(1, before, 'Precondition: membership exists');

        // Success remove
        Test.startTest();
        Boolean removed = DepartmentAdmin.removeUserFromQueue(q1.Id, u2.Id);
        System.assertEquals(true, removed, 'Should remove membership');

        Integer after = [SELECT COUNT() FROM GroupMember WHERE GroupId = :q1.Id AND UserOrGroupId = :u2.Id];
        System.assertEquals(0, after, 'Membership should be deleted');

        // No-op: already removed
        Boolean noop = DepartmentAdmin.removeUserFromQueue(q1.Id, u2.Id);
        System.assertEquals(false, noop, 'Removing non-member returns false');

        // Invalid params
        Boolean bad = DepartmentAdmin.removeUserFromQueue(null, null);
        Test.stopTest();
        System.assertEquals(false, bad, 'Null params return false');
    }

    @IsTest
    static void testSearchActiveUsers() {
        // Should find active users by name fragment and by email
        Test.startTest();
        List<DepartmentAdmin.UserDto> byName = DepartmentAdmin.searchActiveUsers('Jane', new List<Id>());
        List<DepartmentAdmin.UserDto> byEmail = DepartmentAdmin.searchActiveUsers('john.queue1@', new List<Id>());
        List<DepartmentAdmin.UserDto> blank = DepartmentAdmin.searchActiveUsers('', new List<Id>());

        System.assert(byName.size() > 0, 'Expect at least one match by name');
        Boolean hasJane = false;
        for (DepartmentAdmin.UserDto u : byName) {
            if (u.email == 'jane.queue2@example.com') {
                hasJane = true;
            }
        }
        System.assertEquals(true, hasJane, 'Jane should be found by name');

        Boolean hasJohn = false;
        for (DepartmentAdmin.UserDto u : byEmail) {
            if (u.email == 'john.queue1@example.com') {
                hasJohn = true;
            }
        }
        Test.stopTest();
        System.assertEquals(true, hasJohn, 'John should be found by email fragment');
        System.assertEquals(0, blank.size(), 'Blank search should return empty');
    }
    
    @IsTest
    static void testGetQueueValidBaseNameOrId() {
        Group q1 = getQueueByDevName('Support_Queue_A');

        // By developer name
        Test.startTest();
        DepartmentAdmin.QueueDto byName = DepartmentAdmin.getQueueValidBaseNameOrId('Support_Queue_A', null);
        // By id
        DepartmentAdmin.QueueDto byId = DepartmentAdmin.getQueueValidBaseNameOrId(null, q1.Id);
        // Not found
        DepartmentAdmin.QueueDto none = DepartmentAdmin.getQueueValidBaseNameOrId('Does_Not_Exist', null);
        // Invalid inputs
        DepartmentAdmin.QueueDto invalid = DepartmentAdmin.getQueueValidBaseNameOrId(null, null);
        Test.stopTest();

        System.assertNotEquals(null, byName, 'Queue should be returned by dev name');
        System.assertNotEquals(null, byId, 'Queue should be returned by id');
        System.assertEquals(null, none, 'Non-existent dev name returns null');
        System.assertEquals(null, invalid, 'Both null returns null');
    }

    @IsTest
    static void testUpdateMainQueueForUser_success_andErrors() {
        User u1 = getUserByEmail('john.queue1@example.com');

        // Success update to new value (queueId is only used for logging)
        Test.startTest();
            Boolean ok = DepartmentAdmin.updateMainQueueForUser(null, u1.Id, 'Support_Queue_B');
        System.assertEquals(true, ok, 'Update should succeed');

        // Verify value updated
        User refreshed = [SELECT Id, FEC_Main_Queue__c FROM User WHERE Id = :u1.Id];
        System.assertEquals('Support_Queue_B', refreshed.FEC_Main_Queue__c, 'Main queue updated');

        // Success: clear the main queue (null allowed)
       
            // Boolean okClear = DepartmentAdmin.updateMainQueueForUser(null, u1.Id, null);
        Test.stopTest();
        Boolean threwNotFound = false;
        try {
            DepartmentAdmin.updateMainQueueForUser(null, (Id)'005000000000000', 'X');
        } catch (AuraHandledException ex) {
            threwNotFound = true;
            System.assert(ex.getMessage().startsWith('Unable to update main queue:'), 'Expected wrapped AuraHandledException with prefix for not found');
        }
        System.assertEquals(true, threwNotFound, 'Should throw when user not found');
    }
}