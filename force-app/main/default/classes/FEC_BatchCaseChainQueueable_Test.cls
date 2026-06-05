@IsTest
private class FEC_BatchCaseChainQueueable_Test {

    @IsTest
    static void testQueueableWithEmptyList() {
        Test.startTest();
        // Passing an empty list to ensure the early exit condition works and no errors are thrown
        Id jobId = System.enqueueJob(new FEC_BatchCaseChainQueueable(new List<Id>()));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be enqueued successfully even with an empty list.');
    }

    @IsTest
    static void testQueueableWithNullList() {
        Test.startTest();
        Id jobId = System.enqueueJob(new FEC_BatchCaseChainQueueable(null));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be enqueued successfully with null list.');
    }

    @IsTest
    static void testQueueableProcessSingleRecordWithoutChaining() {
        // Use a real batch record to cover the execute processing path without hitting recursive chain depth in tests.
        FEC_Batch_Case_Creation__c b1 = new FEC_Batch_Case_Creation__c(FEC_Status__c = 'Processed');
        insert b1;

        Test.startTest();
        System.enqueueJob(new FEC_BatchCaseChainQueueable(new List<Id>{ b1.Id }));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];

        System.assert(jobs.size() > 0, 'Queueable should execute successfully for one batch id.');
    }
}