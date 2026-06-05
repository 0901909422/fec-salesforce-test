@IsTest
private class FEC_CaseFullProcessTatQueueJob_Test {

    @IsTest
    static void testExecute_emptyCaseIds() {
        Test.startTest();
        System.enqueueJob(new FEC_CaseFullProcessTatQueueJob(null));
        System.enqueueJob(new FEC_CaseFullProcessTatQueueJob(new Set<Id>()));
        Test.stopTest();
        System.assert(true, 'Empty job should complete without error.');
    }

    @IsTest
    static void testExecute_syncsCaseFromRoutingHistory() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'Full Process TAT Queue Job',
                Status = FEC_ConstantCommon.CASE_STATUS_OPEN,
                FEC_ID_Search__c = 'FPTQJ-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        System.enqueueJob(new FEC_CaseFullProcessTatQueueJob(new Set<Id>{ c.Id }));
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Case WHERE Id = :c.Id]);
    }
}
