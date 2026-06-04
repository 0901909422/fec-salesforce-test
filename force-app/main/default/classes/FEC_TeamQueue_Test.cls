/**
 * Test class for FEC_TeamQueue
 * Ensures coverage for:
 * - getListTeam
 * - getQueuesForTeam
 * - createQueue
 * - createTeamQueueRecord
 * - CreateNewTeam
 * - getQueueEditInfo
 * - updateQueueEdit
 *
 * Notes:
 * - SeeAllData=false. All data is created within tests.
 * - DepartmentAdmin.getQueueValidBaseNameOrId and DepartmentAdmin.insertCustomLog are invoked; if these have logic,
 *   this test only relies on their public contract and will create minimal data to satisfy usage.
 */
@isTest
public class FEC_TeamQueue_Test {

    // Utility method để tạo dữ liệu mẫu
    private static FEC_Team__c createSampleTeam() {
        FEC_Team__c team = new FEC_Team__c(
            Name = 'TestTeam',
            FEC_Team_Label__c = 'Test Label',
            FEC_Team_Description__c = 'Test Description'
        );
        insert team;
        return team;
    }

    @isTest
    static void testCreateNewTeam() {
        Test.startTest();
        Id teamId = FEC_TeamQueue.CreateNewTeam('Label1', 'TeamAPIName', 'Description');
        System.assertNotEquals(null, teamId, 'Team should be created successfully');
        Test.stopTest();
    }

    @isTest
    static void testGetListTeam() {
        FEC_Team__c team = createSampleTeam();
        Test.startTest();
        List<FEC_TeamQueue.TeamQueueWrapper> teams = FEC_TeamQueue.getListTeam();
        System.assert(teams.size() > 0, 'Should return at least one team');
        Test.stopTest();
    }

    @isTest
    static void testCreateQueue() {
        Test.startTest();
        String queueId = FEC_TeamQueue.createQueue('Test Queue Label', 'TestQueueDevName');
        System.assertNotEquals(null, queueId, 'Queue should be created successfully');
        Test.stopTest();
    }

    @isTest
    static void testCreateTeamQueueRecord() {
        FEC_Team__c team = createSampleTeam();
        Test.startTest();
        Boolean result = FEC_TeamQueue.createTeamQueueRecord(team.Id, 'TestQueueDevName');
        System.assertEquals(true, result, 'Team Queue record should be created successfully');
        Test.stopTest();
    }

    @isTest
    static void testGetQueuesForTeam() {
        FEC_Team__c team = createSampleTeam();
        // Tạo record FEC_Team_Queue__c giả lập
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'TestQueueDevName'
        );
        insert tq;

        Test.startTest();
        List<FEC_TeamQueue.ListQueueDto> queues = FEC_TeamQueue.getQueuesForTeam(team.Id);
        System.assertNotEquals(null, queues, 'Queues list should not be null');
        Test.stopTest();
    }

    @isTest
    static void testGetQueueEditInfo() {
        // Tạo team và queue (tạo Group trực tiếp để đảm bảo tồn tại)
        FEC_Team__c team = createSampleTeam();
        Group g = new Group(Name = 'EditQueueLabel', DeveloperName = 'EditQueueDevName', Type = 'Queue');
        insert g;
        Id queueId = g.Id;
        
        // Tạo mapping record FEC_Team_Queue__c
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'EditQueueDevName'
        );
        insert tq;

        Test.startTest();
        FEC_TeamQueue.EditQueueDto dto = FEC_TeamQueue.getQueueEditInfo(queueId, tq.Id);
        System.assertEquals(queueId, dto.queueId, 'Queue Id should match');
        System.assertEquals(team.Id, dto.teamId, 'Team Id should match');
        Test.stopTest();
    }

    @isTest
    static void testUpdateQueueEdit() {
        // Tạo Group (Queue) first to avoid mixed DML issues and ensure it exists
        Group g = new Group(Name = 'EditQueueLabel', DeveloperName = 'EditQueueDevName', Type = 'Queue');
        insert g;
        Id queueId = g.Id;

        // Then create team and mapping record
        FEC_Team__c team = createSampleTeam();
        FEC_Team_Queue__c tq = new FEC_Team_Queue__c(
            FEC_Select_Team__c = team.Id,
            FEC_Queue_Name__c = 'EditQueueDevName'
        );
        insert tq;

        // Sanity checks
        System.assertNotEquals(null, queueId, 'Queue Id must not be null');
        System.assertNotEquals(null, tq.Id, 'Team-Queue mapping Id must not be null');

        Test.startTest();
        Boolean updateResult = FEC_TeamQueue.updateQueueEdit(queueId, 'UpdatedLabel', tq.Id, team.Id);
        System.assertEquals(true, updateResult, 'Update should succeed');
        // Verify that Group name was updated
        Group updated = [SELECT Id, Name FROM Group WHERE Id = :queueId LIMIT 1];
        System.assertEquals('UpdatedLabel', updated.Name, 'Group name should be updated');
        // Verify that mapping was updated to point to the same team (no change expected)
        FEC_Team_Queue__c updatedTq = [SELECT Id, Team__c FROM FEC_Team_Queue__c WHERE Id = :tq.Id LIMIT 1];
        System.assertEquals(team.Id, updatedTq.Team__c, 'Team mapping should match the provided team Id');
        Test.stopTest();
    }
}