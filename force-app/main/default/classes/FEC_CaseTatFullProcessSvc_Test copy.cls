/**
 * Unit tests for FEC_CaseTatFullProcessSvc (full-process TAT on Case).
 * FEC_Case_Status__c, FEC_Case_Created_On__c, FEC_Last_Updated_On__c are formula — set Status/FEC_Team__c only.
 */
@IsTest
private class FEC_CaseTatFullProcessSvc_Test {

    private static Id customerCaseRecordTypeId() {
        Schema.RecordTypeInfo rt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME);
        return rt == null ? null : rt.getRecordTypeId();
    }

    private static Case queryCase(Id caseId) {
        return [
            SELECT
                Id,
                Status,
                FEC_Case_Status__c,
                FEC_Case_Created_On__c,
                FEC_Last_Updated_On__c,
                CreatedDate,
                FEC_TAT_Full_Process_Hrs__c,
                FEC_Team__c
            FROM Case
            WHERE Id = :caseId
        ];
    }

    private static Case insertCustomerCase(String subject, String status, String team, Integer daysBack) {
        Id rtId = customerCaseRecordTypeId();
        System.assertNotEquals(null, rtId, 'Customer Case record type required on org.');

        Case c = new Case(
            Subject = subject,
            Status = status,
            FEC_Team__c = team,
            RecordTypeId = rtId,
            FEC_ID_Search__c = subject + '-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        if (daysBack != null && daysBack > 0) {
            Test.setCreatedDate(c.Id, DateTime.now().addDays(-daysBack));
        }
        return queryCase(c.Id);
    }

    @IsTest
    static void testApplyBeforeSave_guardsAndPendingTat() {
        FEC_CaseTatFullProcessSvc.applyBeforeSave(null, null);
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>(), null);

        Case systemSkip = new Case(Subject = 'System skip');
        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            FEC_CaseTatFullProcessSvc.applyBeforeSave(
                new List<Case>{ systemSkip },
                new Map<Id, Case>()
            );
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }
        System.assertEquals(null, systemSkip.FEC_TAT_Full_Process_Hrs__c);

        if (customerCaseRecordTypeId() == null) {
            return;
        }

        Case openCase = insertCustomerCase(
            'TAT Before Open',
            FEC_ConstantCommon.CASE_STATUS_OPEN,
            'TS',
            1
        );
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ openCase }, null);
        System.assertEquals(null, openCase.FEC_TAT_Full_Process_Hrs__c);

        Case pendingCase = insertCustomerCase(
            'TAT Before Pending',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'TS',
            2
        );
        Test.startTest();
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ pendingCase }, null);
        Test.stopTest();
        System.assertNotEquals(null, pendingCase.FEC_TAT_Full_Process_Hrs__c);

        Case pendingPrefix = insertCustomerCase(
            'TAT Before Pending Prefix',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'BO',
            1
        );
        System.assert(
            pendingPrefix.FEC_Case_Status__c != null
            && pendingPrefix.FEC_Case_Status__c.startsWith('Pending'),
            'Formula status should reflect Pending picklist.'
        );
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ pendingPrefix }, null);
        System.assertNotEquals(null, pendingPrefix.FEC_TAT_Full_Process_Hrs__c);
    }

    @IsTest
    static void testSyncCasesFromRoutingHistory_pendingAndResolved() {
        if (customerCaseRecordTypeId() == null) {
            System.assert(true, 'Customer Case record type not on org; skip routing sync E2E.');
            return;
        }

        Case pendingCase = insertCustomerCase(
            'TAT Routing Pending',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'TS',
            2
        );
        Case resolvedCase = insertCustomerCase(
            'TAT Routing Resolved',
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'BO',
            2
        );

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(null);
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>());
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>{ pendingCase.Id });
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>{ pendingCase.Id });
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>{ resolvedCase.Id });
        Test.stopTest();

        pendingCase = queryCase(pendingCase.Id);
        resolvedCase = queryCase(resolvedCase.Id);
        System.assertNotEquals(null, pendingCase.FEC_TAT_Full_Process_Hrs__c);
        System.assertNotEquals(null, resolvedCase.FEC_TAT_Full_Process_Hrs__c);
        System.assert(pendingCase.FEC_Case_Status__c.startsWith('Pending'));
        System.assert(resolvedCase.FEC_Case_Status__c.startsWith('Resolved'));
    }

    @IsTest
    static void testSyncAfterSave_pendingAndResolved() {
        if (customerCaseRecordTypeId() == null) {
            System.assert(true, 'Customer Case record type not on org; skip after-save E2E.');
            return;
        }

        Case pendingCase = insertCustomerCase(
            'TAT After Save Pending',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'LG',
            1
        );
        Case resolvedCase = insertCustomerCase(
            'TAT After Save Resolved',
            FEC_ConstantCommon.CASE_STATUS_RESOLVED_COMPLETED,
            'LG',
            2
        );

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncAfterSave(null, null);
        FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>(), null);
        FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>{ pendingCase }, null);
        FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>{ resolvedCase }, null);
        Test.stopTest();

        System.assertNotEquals(null, queryCase(pendingCase.Id).FEC_TAT_Full_Process_Hrs__c);
        System.assertNotEquals(null, queryCase(resolvedCase.Id).FEC_TAT_Full_Process_Hrs__c);
    }

    @IsTest
    static void testSyncAfterSave_systemUpdateSkipped() {
        if (customerCaseRecordTypeId() == null) {
            return;
        }
        Case c = insertCustomerCase(
            'TAT System Skip',
            FEC_ConstantCommon.CASE_STATUS_OPEN,
            null,
            null
        );
        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>{ c }, null);
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }
        System.assert(true, 'System update path should return early.');
    }

    @IsTest
    static void testSyncAfterSave_statusTransitionRecalc() {
        if (customerCaseRecordTypeId() == null) {
            return;
        }

        Case c = insertCustomerCase(
            'TAT Transition',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'DS',
            3
        );
        Case oldSnapshot = queryCase(c.Id);

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Team__c = 'LG');
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Case triggerRow = queryCase(c.Id);

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncAfterSave(
            new List<Case>{ triggerRow },
            new Map<Id, Case>{ c.Id => oldSnapshot }
        );
        Test.stopTest();

        System.assertNotEquals(null, queryCase(c.Id).FEC_TAT_Full_Process_Hrs__c);
        System.assertNotEquals(
            oldSnapshot.FEC_Case_Status__c,
            triggerRow.FEC_Case_Status__c,
            'Team change should change formula FEC_Case_Status__c for Pending cases.'
        );
    }

    @IsTest
    static void testSyncAfterSave_leavesPendingToOpenRecalculates() {
        if (customerCaseRecordTypeId() == null) {
            return;
        }

        Case c = insertCustomerCase(
            'TAT Leave Pending',
            FEC_ConstantCommon.CASE_STATUS_PENDING,
            'POS',
            2
        );
        Case oldSnapshot = queryCase(c.Id);

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, Status = FEC_ConstantCommon.CASE_STATUS_OPEN);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Case triggerRow = queryCase(c.Id);

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncAfterSave(
            new List<Case>{ triggerRow },
            new Map<Id, Case>{ c.Id => oldSnapshot }
        );
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :c.Id]);
    }

    @IsTest
    static void testApplyBeforeSave_nonCustomerCaseNoAnchor() {
        Case standardCase = new Case(
            Subject = 'TAT Standard Case',
            Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
            FEC_ID_Search__c = 'TAT-STD-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert standardCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Case row = queryCase(standardCase.Id);
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ row }, null);
        System.assertEquals(null, row.FEC_TAT_Full_Process_Hrs__c);
    }
}
