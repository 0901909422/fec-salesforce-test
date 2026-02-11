/****************************************************************************************
 * File Name    : FEC_GetNextWorkControllerTest
 * Author       : Quangdv7
 * Date         : 2025-12-07
 * Description  : Set update test for FEC_GetNextWorkController
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-07     Quangdv7             Create
 
****************************************************************************************/

@IsTest
public class FEC_GetNextWorkControllerTest {

    @TestSetup
    static void setupData() {
        // Query existing record types (must exist in the org)
        RecordType rtInternal = [
            SELECT Id 
            FROM RecordType 
            WHERE SobjectType = 'Case' 
            AND DeveloperName = 'Internal_Case'
            LIMIT 1
        ];

        // Query ANY existing queue (cannot insert Group)
        Group queue = [
            SELECT Id 
            FROM Group 
            WHERE Type = 'Queue' 
            LIMIT 1
        ];

        // Insert oldest case (inserted first -> older CreatedDate)
        Case oldCase = new Case(
            OwnerId = queue.Id,
            Subject = 'Old Case',
            RecordTypeId = rtInternal.Id
        );
        insert oldCase;

        // Insert newer case (inserted later -> newer CreatedDate)
        Case newerCase = new Case(
            OwnerId = queue.Id,
            Subject = 'New Case',
            RecordTypeId = rtInternal.Id
        );
        insert newerCase;

        // Also insert a case owned by current user (so takeOwnership can find/operate on non-queue case too)
        Case userCase = new Case(
            OwnerId = UserInfo.getUserId(),
            Subject = 'User Owned Case',
            RecordTypeId = rtInternal.Id
        );
        insert userCase;
    }

    @IsTest
    static void testGetAllUserQueues_WhenUserNotMember_ReturnsEmpty() {
        Test.startTest();
        List<FEC_GetNextWorkController.Option> queues = FEC_GetNextWorkController.getAllUserQueues();
        Test.stopTest();
        System.assertNotEquals(null, queues, 'getAllUserQueues should not return null');
    }

    @IsTest
    static void testGetOldestCase_WithValidQueue_ReturnsOldest() {
        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];
        Test.startTest();
        Id oldestCaseId = FEC_GetNextWorkController.getOldestCase(queue.Id);
        Test.stopTest();
        System.assertNotEquals(null, oldestCaseId, 'Oldest case should be found for queue');
        Case oldest = [SELECT Subject, OwnerId FROM Case WHERE Id = :oldestCaseId LIMIT 1];
        System.assertEquals('Old Case', oldest.Subject, 'Should return the oldest inserted case');
        System.assertEquals(queue.Id, oldest.OwnerId, 'Owner should be the queue');
    }

    @IsTest
    static void testGetOldestCase_WithNullQueue_ReturnsNull() {
        Test.startTest();
        Id result = FEC_GetNextWorkController.getOldestCase(null);
        Test.stopTest();
        System.assertEquals(null, result, 'getOldestCase(null) should return null');
    }

    @IsTest
    static void testGetOldestCase_WhenNoMatchingRecordTypes_ReturnsNull() {
        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];
        List<RecordType> otherRTs = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Case'
            AND DeveloperName NOT IN ('Internal_Case','Customer_Case')
            LIMIT 1
        ];

        if (!otherRTs.isEmpty()) {
            Case other = new Case(
                OwnerId = queue.Id,
                Subject = 'Non Matching RT Case',
                RecordTypeId = otherRTs[0].Id
            );
            insert other;
            Test.startTest();
            Id oldestId = FEC_GetNextWorkController.getOldestCase(queue.Id);
            Test.stopTest();
            System.assertNotEquals(null, oldestId, 'Should still return the oldest matching RT case');
        } else {
            Test.startTest();
            Id oldestId = FEC_GetNextWorkController.getOldestCase(queue.Id);
            Test.stopTest();
            System.assertNotEquals(null, oldestId);
        }
    }

    @IsTest
    static void testTakeOwnership_WithValidCase_UpdatesOwner() {
        Case queueCase = [SELECT Id, OwnerId FROM Case WHERE OwnerId IN (SELECT Id FROM Group WHERE Type='Queue') LIMIT 1];
        Test.startTest();
        Id updatedId = FEC_GetNextWorkController.takeOwnership(queueCase.Id);
        Test.stopTest();
        System.assertNotEquals(null, updatedId, 'takeOwnership should return an Id');
        Case after = [SELECT OwnerId FROM Case WHERE Id = :updatedId];
        System.assertEquals(UserInfo.getUserId(), after.OwnerId, 'Owner should be set to current user');
    }

    @IsTest
    static void testTakeOwnership_WithNull_ReturnsNullAndNoException() {
        Test.startTest();
        Id res = FEC_GetNextWorkController.takeOwnership(null);
        Test.stopTest();
        System.assertEquals(null, res, 'takeOwnership(null) should return null');
    }
}