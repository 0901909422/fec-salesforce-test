@IsTest
private class FEC_CaseAssignmentTriggerHandler_Test {

    private static FEC_Case_Assignment__c buildAssignment(String statusValue) {
        Id businessHoursId = [SELECT Id FROM BusinessHours LIMIT 1].Id;
        return new FEC_Case_Assignment__c(
            Name = 'Trigger Handler ' + statusValue,
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue CS Support',
            FEC_Status__c = statusValue
        );
    }

    @IsTest
    static void testHandleAfterInsert_draftAndGuardClauses() {
        FEC_Case_Assignment__c assignment = buildAssignment(
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert assignment;

        Test.startTest();
        FEC_CaseAssignmentTriggerHandler.handleAfterInsert(
            new List<FEC_Case_Assignment__c>{ assignment }
        );
        FEC_CaseAssignmentTriggerHandler.handleAfterInsert(null);
        FEC_CaseAssignmentTriggerHandler.handleAfterInsert(new List<FEC_Case_Assignment__c>());
        Test.stopTest();

        System.assertNotEquals(null, assignment.Id);
    }

    @IsTest
    static void testHandleAfterUpdate_statusBecomesActiveInMemory() {
        FEC_Case_Assignment__c assignment = buildAssignment(
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert assignment;
        FEC_Case_Assignment__c oldRow = assignment.clone(true, true, true, true);
        assignment.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;

        Test.startTest();
        FEC_CaseAssignmentTriggerHandler.handleAfterUpdate(
            new List<FEC_Case_Assignment__c>{ assignment },
            new Map<Id, FEC_Case_Assignment__c>{ assignment.Id => oldRow }
        );
        FEC_CaseAssignmentTriggerHandler.handleAfterUpdate(null, null);
        FEC_CaseAssignmentTriggerHandler.handleAfterUpdate(
            new List<FEC_Case_Assignment__c>(),
            new Map<Id, FEC_Case_Assignment__c>()
        );
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT,
            [SELECT FEC_Status__c FROM FEC_Case_Assignment__c WHERE Id = :assignment.Id].FEC_Status__c
        );
    }
}
