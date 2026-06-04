@IsTest
private class FEC_CaseAssignmentConflictServiceTest {
    private static final String QUEUE_A = 'FEC Conflict Test Queue A';
    private static final String QUEUE_B = 'FEC Conflict Test Queue B';
    private static final String QUEUE_C = 'FEC Conflict Test Queue C';
    private static final String ROLE_ONE_QUEUE = 'FEC Conflict Test Role|1';

    private static Id getBusinessHoursId() {
        return [SELECT Id FROM BusinessHours LIMIT 1].Id;
    }

    private static FEC_Case_Assignment_NOC__c getNocTemplate() {
        return [
            SELECT
                FEC_Product_Type__c,
                FEC_Category__c,
                FEC_Sub_Category__c,
                FEC_Sub_Code__c
            FROM FEC_Case_Assignment_NOC__c
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Conflict Test Product',
            FEC_Code__c = 'CTP',
            FEC_Active__c = true
        );
        insert prod;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Conflict Test Category',
            FEC_Code__c = 'CTC',
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Conflict Test SubCat',
            FEC_Code__c = 'CTS',
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Conflict Test SubCode',
            FEC_Code__c = 'CTSC',
            FEC_Active__c = true
        );
        insert subCode;

        Id businessHoursId = getBusinessHoursId();
        FEC_Case_Assignment__c seedAssignment = new FEC_Case_Assignment__c(
            Name = 'Conflict Seed Rule',
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = businessHoursId,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = ROLE_ONE_QUEUE,
            FEC_Scale__c = 1,
            FEC_Select_Queues__c = QUEUE_A,
            FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert seedAssignment;

        insert new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = seedAssignment.Id,
            FEC_Product_Type__c = prod.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id
        );
    }

    private static FEC_Case_Assignment__c createAssignment(
        String queueValue,
        String statusValue
    ) {
        FEC_Case_Assignment__c assignmentRecord = new FEC_Case_Assignment__c(
            Name = 'CA-' + String.valueOf(Crypto.getRandomLong()),
            FEC_Status__c = statusValue,
            FEC_Assignment_Method__c = 'Continuous',
            FEC_Business_Hours__c = getBusinessHoursId(),
            FEC_Select_Queues__c = queueValue,
            FEC_Scheduled_Time__c = 30,
            FEC_Role__c = ROLE_ONE_QUEUE,
            FEC_Scale__c = 1
        );
        insert assignmentRecord;
        return assignmentRecord;
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

    @IsTest
    static void shouldBlockDuplicateNocWhenQueueOverlapsActiveAssignment() {
        FEC_Case_Assignment_NOC__c seed = getNocTemplate();

        FEC_Case_Assignment__c activeBasis = createAssignment(
            QUEUE_A,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert buildNoc(activeBasis.Id, seed);

        activeBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update activeBasis;

        FEC_Case_Assignment__c draftAssignment = createAssignment(
            QUEUE_A + ';' + QUEUE_B,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment_NOC__c candidate = buildNoc(draftAssignment.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(false, saveResult.isSuccess(), 'Expected duplicate NOC to be blocked.');
        System.assert(
            saveResult.getErrors()[0].getMessage().contains('Queue đang chọn đã có 1 quy tắc phân bổ'),
            'Expected Noti-02 style error message.'
        );
    }

    @IsTest
    static void shouldAllowNocWhenQueueDoesNotOverlap() {
        FEC_Case_Assignment_NOC__c seed = getNocTemplate();

        FEC_Case_Assignment__c blocker = createAssignment(
            QUEUE_A,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert buildNoc(blocker.Id, seed);

        blocker.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update blocker;

        FEC_Case_Assignment__c anotherAssignment = createAssignment(
            QUEUE_C,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment_NOC__c candidate = buildNoc(anotherAssignment.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Expected non-overlap queue to be allowed.'
        );
    }

    /** NOC under Draft/Archived parents must not participate in duplicate/block logic vs other Draft rules. */
    @IsTest
    static void shouldAllowNocWhenOverlappingQueuesButOtherRuleIsDraft() {
        FEC_Case_Assignment_NOC__c seed = getNocTemplate();

        FEC_Case_Assignment__c draftA = createAssignment(
            QUEUE_A,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert buildNoc(draftA.Id, seed);

        FEC_Case_Assignment__c draftB = createAssignment(
            QUEUE_A,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        FEC_Case_Assignment_NOC__c candidate = buildNoc(draftB.Id, seed);

        Database.SaveResult saveResult = Database.insert(candidate, false);
        System.assertEquals(
            true,
            saveResult.isSuccess(),
            'Overlapping Draft assignment must not block.'
        );
    }

    @IsTest
    static void shouldAllowNocWhenOverlappingQueuesButOtherRuleIsArchived() {
        FEC_Case_Assignment_NOC__c seed = getNocTemplate();

        FEC_Case_Assignment__c archivedBasis = createAssignment(
            QUEUE_A,
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        );
        insert buildNoc(archivedBasis.Id, seed);
        archivedBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ACTIVE;
        update archivedBasis;
        archivedBasis.FEC_Status__c = FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_ARCHIVED;
        update archivedBasis;

        FEC_Case_Assignment__c draftAssignment = createAssignment(
            QUEUE_A,
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
