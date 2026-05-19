@IsTest
private class FEC_AutoHoldCaseServiceTest {
    @IsTest
    static void processAutoHoldCase_noHistory_noOp() {
        Test.startTest();
        FEC_AutoHoldCaseService.processAutoHoldCase(null);
        Test.stopTest();
        System.assert(true, 'Should complete without exception');
    }

    @IsTest
    static void statusConfigContains_matchesCleanedValue() {
        System.assertEquals(
            true,
            FEC_AutoHoldCaseService.statusConfigContains(
                'Open-InProgress',
                'Open In Progress'
            )
        );
        System.assertEquals(
            false,
            FEC_AutoHoldCaseService.statusConfigContains('', 'Open')
        );
    }

    @IsTest
    static void parseNfuTillDate_parsesIsoString() {
        DateTime dt = FEC_AutoHoldCaseService.parseNfuTillDate(
            '2025-10-20T00:00:00.000Z'
        );
        System.assertNotEquals(null, dt);
    }

    @IsTest
    static void enqueueAfterRoutingHistory_null_noJob() {
        Test.startTest();
        FEC_AutoHoldCaseService.enqueueAfterRoutingHistory(null);
        Test.stopTest();
        System.assertEquals(0, Limits.getQueueableJobs());
    }
}
