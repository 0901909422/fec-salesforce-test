@IsTest
private class FEC_NewAssignmentController_Test {

    private static final String CASE_SUBJECT_MAPPED = 'New Assignment Mapped Case';
    private static final String CASE_SUBJECT_EMPTY = 'New Assignment Empty Case';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Product Type Test',
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Category Test',
            FEC_Code__c = 'CAT' + suffix,
            FEC_Active__c = true
        );
        insert cat;

        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'Sub Category Test',
            FEC_Code__c = 'SCAT' + suffix,
            FEC_Active__c = true
        );
        insert subCat;

        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'Sub Code Test',
            FEC_Code__c = 'SCODE' + suffix,
            FEC_Active__c = true
        );
        insert subCode;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );
        insert noc;

        insert new FEC_General_Assignment_Config__c(
            FEC_Nature_of_Cases__c = noc.Id,
            FEC_General_Assignment_Name__c = 'Assignment Mẫu',
            FEC_Active__c = true
        );

        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
            Name = 'Stage 1',
            FEC_Code__c = 'STG' + suffix,
            FEC_Default_Stage__c = true,
            FEC_Active__c = true
        );
        insert stage;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                Subject = CASE_SUBJECT_MAPPED,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id,
                FEC_Current_Case_Stage__c = stage.Id,
                Status = 'New'
            );

            insert new Case(
                Subject = CASE_SUBJECT_EMPTY,
                Status = 'New'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getMappedCase() {
        return [
            SELECT Id
            FROM Case
            WHERE Subject = :CASE_SUBJECT_MAPPED
            LIMIT 1
        ];
    }

    private static Case getEmptyCase() {
        return [
            SELECT Id
            FROM Case
            WHERE Subject = :CASE_SUBJECT_EMPTY
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetGeneralAssignmentNames_Success() {
        Case c = getMappedCase();

        Test.startTest();
        List<Map<String, String>> result = FEC_NewAssignmentController.getGeneralAssignmentNames(
            c.Id
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Phải lấy được 1 Assignment Config.');
        System.assertEquals('Assignment Mẫu', result[0].get('label'));
        System.assertEquals('Assignment Mẫu', result[0].get('value'));
    }

    @IsTest
    static void testGetGeneralAssignmentNames_NoNOC_ReturnsEmpty() {
        Case emptyCase = getEmptyCase();

        Test.startTest();
        List<Map<String, String>> result = FEC_NewAssignmentController.getGeneralAssignmentNames(
            emptyCase.Id
        );
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testGetGeneralAssignmentNames_InvalidCaseId_ReturnsEmpty() {
        Id fakeCaseId = Schema.SObjectType.Case.getKeyPrefix() + '000000000001';

        Test.startTest();
        List<Map<String, String>> result = FEC_NewAssignmentController.getGeneralAssignmentNames(
            fakeCaseId
        );
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testCreateAssignment_Success() {
        Case c = getMappedCase();

        Test.startTest();
        Id newAssignmentId = FEC_NewAssignmentController.createAssignment(
            c.Id,
            'General',
            FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
            'Giao việc mới'
        );
        Test.stopTest();

        System.assertNotEquals(null, newAssignmentId);

        FEC_Assignment__c assignment = [
            SELECT FEC_Assignment_Name__c
            FROM FEC_Assignment__c
            WHERE Id = :newAssignmentId
            LIMIT 1
        ];
        System.assertEquals('Giao việc mới', assignment.FEC_Assignment_Name__c);

        List<FEC_Case_Remarks__c> remarks = [
            SELECT FEC_Stage_Name__c, FEC_Case__c
            FROM FEC_Case_Remarks__c
            WHERE FEC_Assignment__c = :newAssignmentId
        ];
        System.assertEquals(1, remarks.size());
        System.assertEquals('Stage 1', remarks[0].FEC_Stage_Name__c);
    }

    @IsTest
    static void testCreateAssignment_InvalidCaseId_ThrowsException() {
        Id fakeCaseId = Schema.SObjectType.Case.getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            FEC_NewAssignmentController.createAssignment(
                fakeCaseId,
                'General',
                FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
                'Giao việc lỗi'
            );
            System.assert(false, 'Expected AuraHandledException for invalid Case Id.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }
}
