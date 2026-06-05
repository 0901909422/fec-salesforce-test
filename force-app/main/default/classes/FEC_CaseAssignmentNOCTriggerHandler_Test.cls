@IsTest
private class FEC_CaseAssignmentNOCTriggerHandler_Test {

    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    private static FEC_Case_Assignment_NOC__c getNocFieldTemplate() {
        return [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c
            FROM FEC_Case_Assignment_NOC__c
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        Id businessHoursId = getBusinessHoursId();
        FEC_Case_Assignment__c draftAssignment = new FEC_Case_Assignment__c(
            Name = 'Draft Assignment Parent',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue CS Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment__c activeAssignment = new FEC_Case_Assignment__c(
            Name = 'Active Assignment Parent',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent B|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Digital Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert new List<FEC_Case_Assignment__c>{ draftAssignment, activeAssignment };

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'RC27',
            FEC_Code__c = 'RC27',
            FEC_Active__c = true
        );
        insert subCat;

        insert new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = draftAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id
            ),
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = activeAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = cat.Id,
                FEC_Sub_Category__c = subCat.Id
            )
        };

        activeAssignment.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update activeAssignment;
    }

    @IsTest
    static void testHandleBeforeInsert_SuccessOnDraftParent() {
        FEC_Case_Assignment__c draftAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Draft Assignment Parent'
            LIMIT 1
        ];
        FEC_Case_Assignment_NOC__c template = getNocFieldTemplate();

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = draftAssign.Id,
                FEC_Product_Type__c = template.FEC_Product_Type__c,
                FEC_Category__c = template.FEC_Category__c,
                FEC_Sub_Category__c = template.FEC_Sub_Category__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(newList);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors());
    }

    @IsTest
    static void testHandleBeforeInsert_ValidationErrorOnActiveParent() {
        FEC_Case_Assignment__c activeAssign = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'Active Assignment Parent'
            LIMIT 1
        ];
        FEC_Case_Assignment_NOC__c template = getNocFieldTemplate();

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = activeAssign.Id,
                FEC_Product_Type__c = template.FEC_Product_Type__c,
                FEC_Category__c = template.FEC_Category__c,
                FEC_Sub_Category__c = template.FEC_Sub_Category__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(newList);
        Test.stopTest();

        System.assertEquals(true, newList[0].hasErrors());
    }

    @IsTest
    static void testHandleBeforeInsert_ParentNotFoundAndNullChecks() {
        FEC_Case_Assignment_NOC__c template = getNocFieldTemplate();

        List<FEC_Case_Assignment_NOC__c> newList1 = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = Id.valueOf('a03000000000001AAA'),
                FEC_Product_Type__c = template.FEC_Product_Type__c
            )
        };
        List<FEC_Case_Assignment_NOC__c> newList2 = new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = null,
                FEC_Product_Type__c = template.FEC_Product_Type__c
            )
        };

        Test.startTest();
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(newList1);
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(newList2);
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeInsert(new List<FEC_Case_Assignment_NOC__c>());
        Test.stopTest();

        System.assertEquals(true, newList1[0].hasErrors());
        System.assertEquals(false, newList2[0].hasErrors());
    }

    @IsTest
    static void testHandleBeforeUpdate_Success() {
        FEC_Case_Assignment_NOC__c oldNoc = [
            SELECT
                Id,
                FEC_Case_Assignment_Name__c,
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__r.Name = 'Draft Assignment Parent'
            LIMIT 1
        ];

        FEC_Case_Assignment_NOC__c updatedNoc = new FEC_Case_Assignment_NOC__c(
            Id = oldNoc.Id,
            FEC_Case_Assignment_Name__c = oldNoc.FEC_Case_Assignment_Name__c,
            FEC_Product_Type__c = oldNoc.FEC_Product_Type__c,
            FEC_Category__c = oldNoc.FEC_Category__c,
            FEC_Sub_Category__c = oldNoc.FEC_Sub_Category__c,
            FEC_Sub_Code__c = oldNoc.FEC_Sub_Code__c
        );

        List<FEC_Case_Assignment_NOC__c> newList = new List<FEC_Case_Assignment_NOC__c>{ updatedNoc };
        Map<Id, FEC_Case_Assignment_NOC__c> oldMap = new Map<Id, FEC_Case_Assignment_NOC__c>{
            oldNoc.Id => oldNoc
        };

        Test.startTest();
        FEC_CaseAssignmentNOCTriggerHandler.handleBeforeUpdate(newList, oldMap);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors());
    }
}
