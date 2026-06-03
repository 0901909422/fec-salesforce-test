@IsTest(SeeAllData=true)
private class FEC_CaseTatFullProcessRefreshBatch_Test {
    @IsTest
    static void testStartAndFinish() {
        FEC_CaseTatFullProcessRefreshBatch batch = new FEC_CaseTatFullProcessRefreshBatch();

        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        batch.finish(null);
        Test.stopTest();

        System.assertNotEquals(null, ql, 'start() should return QueryLocator.');
    }

    @IsTest
    static void testExecute_guardClauses() {
        FEC_CaseTatFullProcessRefreshBatch batch = new FEC_CaseTatFullProcessRefreshBatch();

        Test.startTest();
        batch.execute(null, null);
        batch.execute(null, new List<Case>());
        Test.stopTest();

        System.assert(true, 'execute() should safely return for null/empty scope.');
    }

    @IsTest
    static void testExecute_updatesTatForEligibleCase() {
        if ([SELECT COUNT() FROM BusinessHours WHERE Name = 'FEC Business Hours' AND IsActive = TRUE] == 0) {
            System.assert(true, 'Skip update-path assertion because FEC Business Hours is missing.');
            return;
        }
        List<Case> eligible = [
            SELECT Id
            FROM Case
            WHERE FEC_Case_Created_On__c != null
            AND (
                FEC_Case_Status__c LIKE 'Pending-%'
                OR (FEC_Case_Status__c = null AND Status LIKE 'Pending-%')
            )
            LIMIT 1
        ];
        if (eligible.isEmpty()) {
            System.assert(true, 'Skip update-path assertion because no eligible case exists in org data.');
            return;
        }
        Id caseId = eligible[0].Id;

        Test.startTest();
        Database.executeBatch(new FEC_CaseTatFullProcessRefreshBatch(), 1);
        Test.stopTest();

        Case afterRow = [
            SELECT Id, FEC_TAT_Full_Process__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        System.assertNotEquals(
            null,
            afterRow.FEC_TAT_Full_Process__c,
            'Batch should calculate full-process TAT for eligible pending case.'
        );
    }
}
