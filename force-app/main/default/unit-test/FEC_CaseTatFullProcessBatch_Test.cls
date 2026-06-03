@IsTest
private class FEC_CaseTatFullProcessBatch_Test {
    @IsTest
    static void testStartAndFinish() {
        FEC_CaseTatFullProcessBatch batch = new FEC_CaseTatFullProcessBatch();

        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        batch.finish(null);
        Test.stopTest();

        System.assertNotEquals(null, ql, 'start() should always return a QueryLocator.');
    }

    @IsTest
    static void testExecuteWithEmptyScope() {
        FEC_CaseTatFullProcessBatch batch = new FEC_CaseTatFullProcessBatch();

        Test.startTest();
        batch.execute(null, new List<Case>());
        Test.stopTest();

        System.assert(true, 'execute() with empty scope should complete without exception.');
    }
}
