@IsTest
private class FEC_CaseRemarksTrigger_Test {

    private static Case createCaseRow(String subjectValue) {
        Case c = new Case(
            Subject = subjectValue,
            Status = FEC_ConstantCommon.CASE_STATUS_PENDING
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testAfterInsertAndDeleteAndUndelete() {
        Case c = createCaseRow('Case Remarks Trigger A');

        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c(
            FEC_Case__c = c.Id,
            FEC_Case_Remarks__c = 'Initial remark',
            FEC_Stage_Name__c = 'Stage 1',
            FEC_User_Role__c = 'Maker'
        );

        Test.startTest();
        insert remark;      // after insert
        delete remark;      // after delete
        undelete remark;    // after undelete
        Test.stopTest();

        Integer countRemarks = [
            SELECT COUNT()
            FROM FEC_Case_Remarks__c
            WHERE Id = :remark.Id
        ];
        System.assertEquals(1, countRemarks, 'Remark should be restored after undelete.');
    }

    @IsTest
    static void testAfterUpdate_changedFieldsAndNoChange() {
        Case c1 = createCaseRow('Case Remarks Trigger B1');

        FEC_Case_Remarks__c remark = new FEC_Case_Remarks__c(
            FEC_Case__c = c1.Id,
            FEC_Case_Remarks__c = 'Before update',
            FEC_Stage_Name__c = 'Stage 1',
            FEC_User_Role__c = 'Maker'
        );
        insert remark;

        Test.startTest();
        // changed branch (remark text + user role changed)
        remark.FEC_Case_Remarks__c = 'After update';
        remark.FEC_User_Role__c = 'Checker';
        update remark;

        // no-change branch (none of compared fields changed)
        remark.FEC_Stage_Name__c = 'Stage 2';
        update remark;
        Test.stopTest();

        FEC_Case_Remarks__c reloaded = [
            SELECT Id, FEC_Case__c, FEC_Case_Remarks__c, FEC_Stage_Name__c, FEC_User_Role__c
            FROM FEC_Case_Remarks__c
            WHERE Id = :remark.Id
        ];
        System.assertEquals(c1.Id, reloaded.FEC_Case__c);
        System.assertEquals('After update', reloaded.FEC_Case_Remarks__c);
        System.assertEquals('Stage 2', reloaded.FEC_Stage_Name__c);
        System.assertEquals('Checker', reloaded.FEC_User_Role__c);
    }
}
