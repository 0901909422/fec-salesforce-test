/**
 * Test class for FEC_TeamQueue
 * Ensures coverage for:
 * - getListTeam
 * - getQueuesForTeam
 * - createQueue
 * - createTeamQueueRecord
 * - CreateNewTeam (success + validation errors)
 * - getQueueEditInfo
 * - updateQueueEdit
 * - isTeamActiveForQueue
 * - removeQueue (via createTeamQueueRecord failure path)
 *
 * Notes:
 * - SeeAllData=false. All data is created within tests.
 * - System.runAs is used to avoid Mixed DML errors when inserting
 *   setup objects (Group) alongside non-setup objects (FEC_Team__c).
 */
@isTest
public class FEC_TeamQueue_Test {

    private static FEC_Team__c createSampleTeam() {
        FEC_Team__c team = new FEC_Team__c(
            Name = 'TestTeam',
            FEC_Team_Label__c = 'Test Label',
            FEC_Team_Description__c = 'Test Description',
            FEC_Team_Active__c = true
        );
        insert team;
        return team;
    }

    @isTest
    static void testCreateNewTeam() {
        Test.startTest();
        Id teamId = FEC_TeamQueue.CreateNewTeam('Label1', 'TeamAPIName', 'Description');
        Test.stopTest();
        System.assertNotEquals(null, teamId, 'Team should be created successfully');
    }

    @isTest
    static void testCreateNewTeam_BlankLabel() {
        Test.startTest();
        try {
            FEC_TeamQueue.CreateNewTeam('', 'TeamAPIName', 'Description');
            System.assert(false, 'Should have thrown AuraHandledException for blank label');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateNewTeam_BlankName() {
        Test.startTest();
        try {
            FEC_TeamQueue.CreateNewTeam('Label1', '', 'Description');
            System.assert(false, 'Should have thrown AuraHandledException for blank name');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetListTeam() {
        FEC_Team__c team = createSampleTeam();
        // Also create an inactive team that should NOT be returned
        FEC_Team__c inactiveTeam = new FEC_Team__c(
            Name = 'InactiveTeam',
            FEC_Team_Label__c = 'Inactive Label',
            FEC_Team_Description__c = 'Inactive Desc',
            FEC_Team_Active__c = false
        );
        insert inactiveTeam;

        Test.startTest();
        List<FEC_TeamQueue.TeamQueueWrapper> teams = FEC_TeamQueue.getListTeam();
        Test.stopTest();

        // Should return at least the active team
        System.assert(teams.size() >= 1, 'Should return at least one active team');

        // Verify the active team is in the result with correct field mapping
        Boolean foundActive = false;
        Boolean foundInactive = false;
        for (FEC_TeamQueue.TeamQueueWrapper w : teams) {
            if (w.teamId == team.Id) {
                foundActive = true;
                System.assertEquals('TestTeam', w.teamName, 'teamName should map to FEC_Team__c.Name');
                System.assertEquals('Test Label', w.teamLabel, 'teamLabel should map to FEC_Team_Label__c');
                System.assertEquals('Test Description', w.teamDescription, 'teamDescription should map to FEC_Team_Description__c');
            }
            if (w.teamId == inactiveTeam.Id) {
                foundInactive = true;
            }
        }
        System.assertEquals(true, foundActive, 'Active team should be in the result');
        System.assertEquals(false, foundInactive, 'Inactive team should NOT be in the result');
    }

    @isTest
    static void testCreateQueue() {
        Test.startTest();
        String queueId = FEC_TeamQueue.createQueue('Test Queue Label', 'TestQueueDevName');
        Test.stopTest();
        System.assertNotEquals(null, queueId, 'Queue should be created successfully');
    }

    @isTest
    static void testCreateTeamQueueRecord() {
        FEC_Team__c team = createSampleTeam();
        Test.startTest();
        Boolean result = FEC_TeamQueue.createTeamQueueRecord(team.Id, 'TestQueueDevName', 'Test Label Status');
        Test.stopTest();
        System.assertEquals(true, result, 'Team Queue record should be created successfully');
    }

    @isTest
    static void testGetQueuesForTeam() {
        FEC_Team__c team = createSampleTeam();
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'TestQueueDevName'
        );
        insert tq;

        Test.startTest();
        List<FEC_TeamQueue.ListQueueDto> queues = FEC_TeamQueue.getQueuesForTeam(team.Id);
        Test.stopTest();
        System.assertNotEquals(null, queues, 'Queues list should not be null');
    }

    @isTest
    static void testGetQueueEditInfo() {
        // Insert Group (setup object) inside System.runAs to avoid Mixed DML
        Group g;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            g = new Group(Name = 'EditQueueLabel', DeveloperName = 'EditQueueDevName', Type = 'Queue');
            insert g;
        }

        FEC_Team__c team = createSampleTeam();
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'EditQueueDevName'
        );
        insert tq;

        Test.startTest();
        FEC_TeamQueue.EditQueueDto dto = FEC_TeamQueue.getQueueEditInfo(g.Id, tq.Id);
        Test.stopTest();
        System.assertEquals(g.Id, dto.queueId, 'Queue Id should match');
        System.assertEquals(team.Id, dto.teamId, 'Team Id should match');
    }

    @isTest
    static void testGetQueueEditInfo_InvalidQueue() {
        // Create a regular Group (not Queue type) so its Id is valid but won't match Type='Queue'
        Group notAQueue;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            notAQueue = new Group(Name = 'NotAQueue', DeveloperName = 'NotAQueueDev', Type = 'Regular');
            insert notAQueue;
        }

        FEC_Team__c team = createSampleTeam();
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'SomeQueue'
        );
        insert tq;

        Test.startTest();
        try {
            FEC_TeamQueue.getQueueEditInfo(notAQueue.Id, tq.Id);
            System.assert(false, 'Should have thrown AuraHandledException for invalid queue');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateQueueEdit() {
        // Insert Group inside System.runAs to avoid Mixed DML
        Group g;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            g = new Group(Name = 'EditQueueLabel', DeveloperName = 'EditQueueDevName', Type = 'Queue');
            insert g;
        }

        FEC_Team__c team = createSampleTeam();
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'EditQueueDevName',
            FEC_Team__c = 'Original Label Status'
        );
        insert tq;

        Test.startTest();
        Boolean updateResult = FEC_TeamQueue.updateQueueEdit(g.Id, 'UpdatedLabel', tq.Id, team.Id, 'Updated Label Status');
        Test.stopTest();

        System.assertEquals(true, updateResult, 'Update should succeed');
        Group updated = [SELECT Id, Name FROM Group WHERE Id = :g.Id LIMIT 1];
        System.assertEquals('UpdatedLabel', updated.Name, 'Group name should be updated');
        FEC_Team_Queue__c updatedTq = [SELECT Id, FEC_Select_Team__c, FEC_Team__c FROM FEC_Team_Queue__c WHERE Id = :tq.Id LIMIT 1];
        System.assertEquals(team.Id, updatedTq.FEC_Select_Team__c, 'Team mapping should match');
        System.assertEquals('Updated Label Status', updatedTq.FEC_Team__c, 'Label status should be updated');
    }

    @isTest
    static void testIsTeamActiveForQueue_Active() {
        FEC_Team__c team = createSampleTeam(); // FEC_Team_Active__c = true
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'ActiveQueueDev'
        );
        insert tq;

        Test.startTest();
        Boolean result = FEC_TeamQueue.isTeamActiveForQueue('ActiveQueueDev');
        Test.stopTest();
        System.assertEquals(true, result, 'Should return true for active team');
    }

    @isTest
    static void testIsTeamActiveForQueue_NotFound() {
        Test.startTest();
        Boolean result = FEC_TeamQueue.isTeamActiveForQueue('NonExistentQueue');
        Test.stopTest();
        System.assertEquals(false, result, 'Should return false when queue not found');
    }

    @isTest
    static void testRemoveQueue() {
        // Cover removeQueue directly via @future
        Group g;
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            g = new Group(Name = 'ToDelete', DeveloperName = 'ToDeleteDev', Type = 'Queue');
            insert g;
        }

        Test.startTest();
        FEC_TeamQueue.removeQueue('ToDeleteDev', null);
        Test.stopTest();
        // After @future completes, queue should be deleted
        List<Group> remaining = [SELECT Id FROM Group WHERE DeveloperName = 'ToDeleteDev' AND Type = 'Queue'];
        System.assertEquals(0, remaining.size(), 'Queue should be deleted');
    }

    @isTest
    static void testRemoveQueue_NotFound() {
        Test.startTest();
        FEC_TeamQueue.removeQueue('NonExistentDev', null);
        Test.stopTest();
        // No exception expected, just debug log
    }

    @isTest
    static void testRemoveQueue_BothBlank() {
        Test.startTest();
        FEC_TeamQueue.removeQueue(null, null);
        Test.stopTest();
        // Should return early without error
    }
}
