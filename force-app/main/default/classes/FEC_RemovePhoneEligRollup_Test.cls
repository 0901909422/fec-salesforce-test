@isTest
private class FEC_RemovePhoneEligRollup_Test {

    private static Case insertCaseForTest() {
        Case c = new Case(
            Subject = 'Remove Phone Eligibility Rollup',
            Status = 'New',
            FEC_Is_Submited__c = false,
            FEC_ID_Search__c = 'RPEL-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @isTest
    static void rollup_onCaseSubmit_packsNumberedEligibilityLines() {
        Case c = insertCaseForTest();

        List<FEC_Contract_List_for_Remove_Phone__c> rows = new List<FEC_Contract_List_for_Remove_Phone__c>{
            buildContractRow(c.Id, 'C001', true, 'Active', 'Mobile', 'Yes', 'Reason 1'),
            buildContractRow(c.Id, 'C002', false, 'Closed', 'Home', 'No', 'Reason 2'),
            buildContractRow(c.Id, 'C003', true, 'Active', 'Work', 'Yes', 'Reason 3')
        };
        insert rows;

        Test.startTest();
        c.FEC_Is_Submited__c = true;
        update c;
        Test.stopTest();

        FEC_Contract_List_for_Remove_Phone__c updated = [
            SELECT
                FEC_Eligibility_Details_1__c,
                FEC_Eligibility_Details_2__c,
                FEC_Eligibility_Details_3__c
            FROM FEC_Contract_List_for_Remove_Phone__c
            WHERE FEC_Case__c = :c.Id
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        String combined =
            String.valueOf(updated.FEC_Eligibility_Details_1__c)
            + String.valueOf(updated.FEC_Eligibility_Details_2__c)
            + String.valueOf(updated.FEC_Eligibility_Details_3__c);

        System.assert(
            String.isNotBlank(updated.FEC_Eligibility_Details_1__c),
            'Eligibility Details 1 phải được populate khi Case submit'
        );
        System.assert(combined.contains('#1:'), 'Phải có dòng #1');
        System.assert(combined.contains('#2:'), 'Phải có dòng #2');
        System.assert(combined.contains('#3:'), 'Phải có dòng #3');
        System.assert(combined.contains('Selected: Yes'), 'Selected=true phải map sang Yes');
        System.assert(combined.contains('Selected: No'), 'Selected=false phải map sang No');
        System.assert(combined.contains('Contract Number: C001'), 'Phải có Contract Number');
        System.assert(
            updated.FEC_Eligibility_Details_1__c.length() <= 256,
            'Bucket 1 không vượt 256 ký tự'
        );
    }

    @isTest
    static void rollup_overflowMovesTailToBucket2() {
        Case c = insertCaseForTest();

        List<FEC_Contract_List_for_Remove_Phone__c> rows = new List<FEC_Contract_List_for_Remove_Phone__c>();
        for (Integer i = 1; i <= 4; i++) {
            rows.add(
                buildContractRow(
                    c.Id,
                    'LONGCN' + String.valueOf(i),
                    true,
                    'Active Status ' + String.valueOf(i),
                    'Mobile Phone Type',
                    'Removable Yes',
                    'Reason detail number ' + String.valueOf(i) + ' with extra text'
                )
            );
        }
        insert rows;

        Test.startTest();
        FEC_RemovePhoneEligibilityRollupService.rollup(new Set<Id>{ c.Id });
        Test.stopTest();

        List<FEC_Contract_List_for_Remove_Phone__c> updatedRows = [
            SELECT
                FEC_Eligibility_Details_1__c,
                FEC_Eligibility_Details_2__c,
                FEC_Eligibility_Details_3__c
            FROM FEC_Contract_List_for_Remove_Phone__c
            WHERE FEC_Case__c = :c.Id
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(4, updatedRows.size());
        System.assert(
            String.isNotBlank(updatedRows[0].FEC_Eligibility_Details_1__c),
            'Bucket 1 phải có dữ liệu'
        );
        System.assert(
            updatedRows[0].FEC_Eligibility_Details_1__c.length() <= 256,
            'Bucket 1 không vượt 256 ký tự'
        );
        System.assert(
            String.isNotBlank(updatedRows[0].FEC_Eligibility_Details_2__c)
                || String.isNotBlank(updatedRows[0].FEC_Eligibility_Details_3__c),
            'Phải có overflow sang bucket 2 hoặc 3 khi tổng nội dung > 256 ký tự'
        );
        String combined =
            String.valueOf(updatedRows[0].FEC_Eligibility_Details_1__c)
            + String.valueOf(updatedRows[0].FEC_Eligibility_Details_2__c)
            + String.valueOf(updatedRows[0].FEC_Eligibility_Details_3__c);
        System.assert(combined.contains('#4:'), 'Phải có đủ 4 dòng eligibility');
    }

    private static FEC_Contract_List_for_Remove_Phone__c buildContractRow(
        Id caseId,
        String contractNumber,
        Boolean selected,
        String contractStatus,
        String phoneType,
        String removable,
        String reason
    ) {
        return new FEC_Contract_List_for_Remove_Phone__c(
            FEC_Case__c = caseId,
            Name = contractNumber,
            FEC_Account_Contract_Number__c = contractNumber,
            FEC_Account_Contract_Status__c = contractStatus,
            FEC_Phone_Type__c = phoneType,
            FEC_Removable__c = removable,
            FEC_Reason__c = reason,
            FEC_Check_Remove_Phone__c = selected,
            FEC_Removed_Phone_Number__c = '0901234567'
        );
    }
}
