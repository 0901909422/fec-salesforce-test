@isTest(seeAllData=true)
private class FEC_CaseAssignmentConflictServiceTest {
    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    private static FEC_Case_Assignment__c createAssignment(String queueValue, String statusValue) {
        FEC_Case_Assignment__c assignmentRecord = new FEC_Case_Assignment__c(
            Name = 'CA-' + String.valueOf(Crypto.getRandomLong()),
            FEC_Status__c = statusValue,
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = getBusinessHoursId(),
            FEC_Select_Queues__c = queueValue,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = 'FEC Conflict Test Role|1',
            FEC_Scale__c = 1
        );
        insert assignmentRecord;
        return assignmentRecord;
    }

    /**
     * Seeds from org data — tests skip if sandbox has no NOC rows yet.
     */
    private static FEC_Case_Assignment_NOC__c getSeedNocOrNull() {
        List<FEC_Case_Assignment_NOC__c> seeds = [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE
                FEC_Product_Type__c != NULL
                AND FEC_Category__c != NULL
                AND FEC_Sub_Category__c != NULL
            LIMIT 1
        ];
        return seeds.isEmpty() ? null : seeds[0];
    }

    private static FEC_Case_Assignment_NOC__c buildNoc(
        Id assignmentId,
        FEC_Case_Assignment_NOC__c seed
    ) {
        return new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = assignmentId,
            FEC_Product_Type__c = seed.FEC_Product_Type__c,
            FEC_Category__c = seed.FEC_Category__c,
            FEC_Sub_Category__c = seed.FEC_Sub_Category__c,
            FEC_Sub_Code__c = seed.FEC_Sub_Code__c
        );
    }

    @isTest
    static void shouldBlockDuplicateNocWhenQueueOverlapsActiveAssignment() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }

        FEC_Case_Assignment__c activeBasis = createAssignment('Shared Task;Queue A', 'Draft');
        insert buildNoc(activeBasis.Id, seed);

        activeBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update activeBasis;

        FEC_Case_Assignment__c draftAssignment = createAssignment('Queue A;Queue B', 'Draft');
        FEC_Case_Assignment_NOC__c candidate = buildNoc(draftAssignment.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(false, saveResult.isSuccess(), 'Expected duplicate NOC to be blocked.');
        System.assert(
            saveResult.getErrors()[0].getMessage().contains('Queue đang chọn đã có 1 quy tắc phân bổ'),
            'Expected Noti-02 style error message.'
        );
    }

    @isTest
    static void shouldAllowNocWhenQueueDoesNotOverlap() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }

        FEC_Case_Assignment__c blocker = createAssignment('Shared Task;Queue A', 'Draft');
        insert buildNoc(blocker.Id, seed);

        blocker.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update blocker;

        FEC_Case_Assignment__c anotherAssignment = createAssignment('Queue C;Queue D', 'Draft');
        FEC_Case_Assignment_NOC__c candidate = buildNoc(anotherAssignment.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Expected non-overlap queue to be allowed.'
        );
    }

    /** NOC under Draft/Archived parents must not participate in duplicate/block logic vs other Draft rules. */
    @isTest
    static void shouldAllowNocWhenOverlappingQueuesButOtherRuleIsDraft() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }

        FEC_Case_Assignment__c draftA = createAssignment('Shared Task;Queue A', 'Draft');
        insert buildNoc(draftA.Id, seed);

        FEC_Case_Assignment__c draftB = createAssignment('Shared Task;Queue A', 'Draft');
        FEC_Case_Assignment_NOC__c candidate = buildNoc(draftB.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Overlapping Draft assignment must not block.'
        );
    }

    @isTest
    static void shouldAllowNocWhenOverlappingQueuesButOtherRuleIsArchived() {
        FEC_Case_Assignment_NOC__c seed = getSeedNocOrNull();
        if (seed == null) {
            return;
        }

        FEC_Case_Assignment__c archivedBasis = createAssignment(
            'Shared Task;Queue A',
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert buildNoc(archivedBasis.Id, seed);
        archivedBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update archivedBasis;
        archivedBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ARCHIVED;
        update archivedBasis;

        FEC_Case_Assignment__c draftAssignment = createAssignment(
            'Shared Task;Queue A',
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment_NOC__c candidate = buildNoc(draftAssignment.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Archived assignment NOC must not block new Draft NOC with same queues.'
        );
    }
}