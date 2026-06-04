/**
 * Unit tests for FEC_BCH_ExportAssignmentRemarkLoader.
 * Class name shortened to meet Apex 40-character identifier limit.
 */
@IsTest
private class FEC_BCH_ExpAsgRemarkLoader_Test {

    private static Case insertCase(String subject) {
        Case c = new Case(
            Subject = subject,
            FEC_ID_Search__c = subject + '-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    private static FEC_Assignment__c insertAssignment(Id caseId) {
        FEC_Assignment__c a = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Name__c = 'Export Remark Loader',
            FEC_Assignment_Status__c = FEC_ConstantCommon.ASSIGNMENT_STATUS_OPEN,
            FEC_Assignment_Owner__c = UserInfo.getUserId()
        );
        insert a;
        return [
            SELECT Id, Name, FEC_Assignment_Owner_Text__c
            FROM FEC_Assignment__c
            WHERE Id = :a.Id
        ];
    }

    private static FEC_Case_Remarks__c insertRemark(
        Id caseId,
        Id assignmentId,
        String remarkType,
        String body,
        String userName,
        String userRole
    ) {
        FEC_Case_Remarks__c r = new FEC_Case_Remarks__c(
            FEC_Case__c = caseId,
            FEC_Assignment__c = assignmentId,
            FEC_Remark_Type__c = remarkType,
            FEC_Case_Remarks__c = body,
            FEC_User__c = userName,
            FEC_User_Role__c = userRole
        );
        insert r;
        return r;
    }

    @IsTest
    static void testLoadByCaseId_nullAndEmpty() {
        System.assertEquals(
            0,
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(null).size()
        );
        System.assertEquals(
            0,
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(new Set<Id>()).size()
        );
    }

    @IsTest
    static void testLoadByCaseId_mapsAssignmentRemarksPerCase() {
        Case caseA = insertCase('BCH Export Remark A');
        Case caseB = insertCase('BCH Export Remark B');
        FEC_Assignment__c asnA = insertAssignment(caseA.Id);
        FEC_Assignment__c asnB = insertAssignment(caseB.Id);

        FEC_Case_Remarks__c first = insertRemark(
            caseA.Id,
            asnA.Id,
            FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            'First remark',
            'User A',
            'Role A'
        );
        FEC_Case_Remarks__c second = insertRemark(
            caseA.Id,
            asnA.Id,
            FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            'Second remark',
            'User B',
            'Role B'
        );
        insertRemark(
            caseA.Id,
            asnA.Id,
            'Case',
            'Case-level only',
            'Ignored',
            'Ignored'
        );
        insertRemark(
            caseB.Id,
            asnB.Id,
            FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            'Case B remark',
            'User C',
            'Role C'
        );

        Test.setCreatedDate(first.Id, DateTime.now().addHours(-2));
        Test.setCreatedDate(second.Id, DateTime.now().addHours(-1));

        Map<Id, FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle> loaded =
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(
                new Set<Id>{ caseA.Id, caseB.Id }
            );

        System.assertEquals(2, loaded.size());
        FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle bundleA =
            loaded.get(caseA.Id);
        System.assert(bundleA.hasData());
        System.assert(bundleA.assignmentRemarks.contains('First remark'));
        System.assert(bundleA.assignmentRemarks.contains('Second remark'));
        System.assert(bundleA.assignmentRemarks.contains('#1:'));
        System.assert(bundleA.assignmentRemarks.contains('#2:'));
        System.assert(
            String.isNotBlank(bundleA.assignmentOwner),
            'Assignment owner text should come from formula FEC_Assignment_Owner_Text__c.'
        );
        System.assert(bundleA.assignmentRemarksEnteredBy.contains('User A'));
        System.assert(bundleA.assignmentRemarksEnteredByRole.contains('Role B'));
        System.assertNotEquals(
            FEC_ConstantCommon.STR_EMPTY,
            bundleA.assignmentRemarksEnteredOn
        );

        System.assert(loaded.get(caseB.Id).assignmentRemarks.contains('Case B remark'));
    }

    @IsTest
    static void testAssignmentRemarkExportBundle_applyToAndAddLine() {
        FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle bundle =
            new FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle();
        System.assertEquals(false, bundle.hasData());

        bundle.applyTo(null);

        bundle.addLine(null, null, null, null, null, null);
        System.assertEquals(true, bundle.hasData());
        System.assert(bundle.assignmentId.startsWith('#1:'));

        bundle.addLine(
            'ASN-2',
            'Owner 2',
            'Body 2',
            'User 2',
            'Role 2',
            DateTime.newInstance(2026, 6, 1, 9, 0, 0)
        );
        FEC_BatchCaseHandlingExportRow row = new FEC_BatchCaseHandlingExportRow();
        bundle.applyTo(row);

        System.assert(row.assignmentRemarks.contains('Body 2'));
        System.assert(row.assignmentId.contains('#2:'));
        System.assert(row.assignmentOwner.contains('Owner 2'));
        System.assert(row.assignmentRemarksEnteredBy.contains('User 2'));
        System.assert(row.assignmentRemarksEnteredOn.contains('01/06/2026'));
    }

    @IsTest
    static void testLoadByCaseId_assignmentRemarkWithoutAssignmentLink() {
        Case c = insertCase('BCH Export Remark No Assignment Link');
        insertRemark(
            c.Id,
            null,
            FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT,
            'Assignment remark without lookup',
            'User X',
            'Role X'
        );

        Map<Id, FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle> loaded =
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(new Set<Id>{ c.Id });

        System.assertEquals(1, loaded.size());
        System.assert(loaded.get(c.Id).assignmentRemarks.contains('Assignment remark without lookup'));
    }

    @IsTest
    static void testLoadByCaseId_noMatchingRemarks_returnsEmptyMap() {
        Case c = insertCase('BCH Export Remark Empty');
        insertRemark(c.Id, null, 'Case', 'Only case remark', 'U', 'R');

        Map<Id, FEC_BCH_ExportAssignmentRemarkLoader.AssignmentRemarkExportBundle> loaded =
            FEC_BCH_ExportAssignmentRemarkLoader.loadByCaseId(new Set<Id>{ c.Id });

        System.assertEquals(0, loaded.size());
    }
}
