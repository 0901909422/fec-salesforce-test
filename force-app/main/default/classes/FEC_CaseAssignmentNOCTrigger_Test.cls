@IsTest
private class FEC_CaseAssignmentNOCTrigger_Test {

    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    @TestSetup
    static void setupData() {
        Id bhId = getBusinessHoursId();

        FEC_Case_Assignment__c draftAssignment = new FEC_Case_Assignment__c(
            Name = 'NOC Trigger Draft Parent',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = bhId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent A|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue CS Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment__c activeAssignment = new FEC_Case_Assignment__c(
            Name = 'NOC Trigger Active Parent',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = bhId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'CS Agent B|1',
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = 'Queue Digital Support',
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert new List<FEC_Case_Assignment__c>{ draftAssignment, activeAssignment };

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'NOC Trigger Product',
            FEC_Code__c = 'NTP',
            FEC_Active__c = true
        );
        insert prod;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'NOC Trigger SubCat',
            FEC_Code__c = 'NTS',
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Category__c category = new FEC_Category__c(
            Name = 'NOC Trigger Category',
            FEC_Code__c = 'NTC',
            FEC_Active__c = true
        );
        insert category;

        insert new List<FEC_Case_Assignment_NOC__c>{
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = draftAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = category.Id,
                FEC_Sub_Category__c = subCat.Id
            ),
            new FEC_Case_Assignment_NOC__c(
                FEC_Case_Assignment_Name__c = activeAssignment.Id,
                FEC_Product_Type__c = prod.Id,
                FEC_Category__c = category.Id,
                FEC_Sub_Category__c = subCat.Id
            )
        };

        activeAssignment.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update activeAssignment;
    }

    private static FEC_Case_Assignment_NOC__c buildNoc(Id assignmentId) {
        FEC_Case_Assignment_NOC__c template = [
            SELECT FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c
            FROM FEC_Case_Assignment_NOC__c
            LIMIT 1
        ];
        return new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = assignmentId,
            FEC_Product_Type__c = template.FEC_Product_Type__c,
            FEC_Category__c = template.FEC_Category__c,
            FEC_Sub_Category__c = template.FEC_Sub_Category__c
        );
    }

    @IsTest
    static void testTriggerBeforeInsert_onDraftParent_success() {
        Id draftParentId = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'NOC Trigger Draft Parent'
            LIMIT 1
        ].Id;

        Test.startTest();
        insert buildNoc(draftParentId);
        Test.stopTest();

        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM FEC_Case_Assignment_NOC__c
                WHERE FEC_Case_Assignment_Name__r.Name = 'NOC Trigger Draft Parent'
            ],
            'Insert on Draft parent should pass through trigger validation.'
        );
    }

    @IsTest
    static void testTriggerBeforeInsert_onActiveParent_blocked() {
        Id activeParentId = [
            SELECT Id
            FROM FEC_Case_Assignment__c
            WHERE Name = 'NOC Trigger Active Parent'
            LIMIT 1
        ].Id;

        Test.startTest();
        try {
            insert buildNoc(activeParentId);
            System.assert(false, 'Expected DML exception when parent status is not Draft.');
        } catch (DmlException ex) {
            System.assert(
                ex.getMessage().contains('Draft'),
                'Error should indicate Draft-only rule. Actual: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testTriggerBeforeUpdateAndDelete_blockedWhenParentActive() {
        FEC_Case_Assignment__c draftParent = [
            SELECT Id, FEC_Status__c
            FROM FEC_Case_Assignment__c
            WHERE Name = 'NOC Trigger Draft Parent'
            LIMIT 1
        ];
        FEC_Case_Assignment_NOC__c nocRow = [
            SELECT Id, FEC_Case_Assignment_Name__c, FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :draftParent.Id
            LIMIT 1
        ];

        draftParent.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update draftParent;

        Test.startTest();
        try {
            update new FEC_Case_Assignment_NOC__c(
                Id = nocRow.Id,
                FEC_Case_Assignment_Name__c = nocRow.FEC_Case_Assignment_Name__c,
                FEC_Sub_Code__c = nocRow.FEC_Sub_Code__c
            );
            System.assert(false, 'Expected update to fail when parent is Active.');
        } catch (DmlException exUpdate) {
            System.assert(exUpdate.getMessage().contains('Draft'));
        }

        try {
            delete nocRow;
            System.assert(false, 'Expected delete to fail when parent is Active.');
        } catch (DmlException exDelete) {
            System.assert(exDelete.getMessage().contains('Draft'));
        }
        Test.stopTest();
    }
}
