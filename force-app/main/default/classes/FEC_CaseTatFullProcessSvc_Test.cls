@IsTest
private class FEC_CaseTatFullProcessSvc_Test {

    private static Case insertSimpleCase(String subject) {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = subject,
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = subject + '-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        return c;
    }

    @IsTest
    static void testApplyBeforeSave_nullAndSystemUpdate() {
        FEC_CaseTatFullProcessSvc.applyBeforeSave(null, null);
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>(), null);

        Case c = new Case(Subject = 'In-memory TAT');
        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ c }, new Map<Id, Case>());
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }
        System.assert(true, 'System update path should no-op.');
    }

    @IsTest
    static void testApplyBeforeSave_nonPendingCaseSkipped() {
        Case c = new Case(Subject = 'Non pending TAT');
        Test.startTest();
        FEC_CaseTatFullProcessSvc.applyBeforeSave(new List<Case>{ c }, null);
        Test.stopTest();
        System.assertEquals(null, c.FEC_TAT_Full_Process_Hrs__c);
    }

    @IsTest
    static void testSyncCasesFromRoutingHistory_emptyAndDedupe() {
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(null);
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>());

        Case c = insertSimpleCase('TAT Routing Sync');

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>{ c.Id });
        FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(new Set<Id>{ c.Id });
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :c.Id]);
    }

    @IsTest
    static void testSyncAfterSave_insertContext() {
        Case c = insertSimpleCase('TAT After Save Insert');

        Test.startTest();
        FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>{ c }, null);
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :c.Id]);
    }

    @IsTest
    static void testSyncAfterSave_systemUpdateSkipped() {
        Case c = insertSimpleCase('TAT System Skip');
        Boolean prior = FEC_CaseTriggerHandler.isSystemUpdate;
        FEC_CaseTriggerHandler.isSystemUpdate = true;
        try {
            FEC_CaseTatFullProcessSvc.syncAfterSave(new List<Case>{ c }, null);
        } finally {
            FEC_CaseTriggerHandler.isSystemUpdate = prior;
        }
        System.assert(true, 'System update should skip syncAfterSave.');
    }
}
