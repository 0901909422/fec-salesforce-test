@IsTest
private class FEC_CaseIdCounterService_Test {

    private static final String COUNTER_KEY = 'TestRecordType|TestChannel';
    private static final String PREFIX = 'T';

    private static Map<String, Integer> singleCount() {
        return new Map<String, Integer>{ PREFIX => 1 };
    }

    private static Map<String, String> counterNameMap() {
        return new Map<String, String>{ PREFIX => COUNTER_KEY };
    }

    @IsTest
    static void testAllocateNextNumbers_emptyInput() {
        Test.startTest();
        Map<String, List<Long>> result = FEC_CaseIdCounterService.allocateNextNumbers(
            new Map<String, Integer>(),
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testAllocateNextNumbers_createsCounterAndIncrements() {
        Test.startTest();
        Map<String, List<Long>> first = FEC_CaseIdCounterService.allocateNextNumbers(
            singleCount(),
            null,
            counterNameMap()
        );
        Map<String, List<Long>> second = FEC_CaseIdCounterService.allocateNextNumbers(
            singleCount(),
            null,
            counterNameMap()
        );
        Test.stopTest();

        System.assertEquals(1, first.get(PREFIX).size());
        System.assertEquals(1, second.get(PREFIX).size());
        System.assertEquals(1L, first.get(PREFIX)[0]);
        System.assertEquals(2L, second.get(PREFIX)[0]);

        FEC_Case_ID_Counter__c counter = [
            SELECT FEC_Current_Number__c, FEC_Prefix__c
            FROM FEC_Case_ID_Counter__c
            WHERE Name = :COUNTER_KEY
            LIMIT 1
        ];
        System.assertEquals(PREFIX, counter.FEC_Prefix__c);
        System.assertEquals(2, counter.FEC_Current_Number__c);
    }

    @IsTest
    static void testAllocateNextNumbers_bulkAllocatesSequentialNumbers() {
        Map<String, Integer> countByPrefix = new Map<String, Integer>{ PREFIX => 5 };

        Test.startTest();
        Map<String, List<Long>> allocated = FEC_CaseIdCounterService.allocateNextNumbers(
            countByPrefix,
            null,
            counterNameMap()
        );
        Test.stopTest();

        List<Long> numbers = allocated.get(PREFIX);
        System.assertEquals(5, numbers.size());
        System.assertEquals(1L, numbers[0]);
        System.assertEquals(5L, numbers[4]);
    }

    @IsTest
    static void testAllocateNextNumbers_appliesInitNumberFloor() {
        Map<String, Long> initByPrefix = new Map<String, Long>{ PREFIX => 100L };

        Test.startTest();
        Map<String, List<Long>> allocated = FEC_CaseIdCounterService.allocateNextNumbers(
            singleCount(),
            initByPrefix,
            counterNameMap()
        );
        Test.stopTest();

        System.assertEquals(101L, allocated.get(PREFIX)[0]);
        System.assertEquals(
            101,
            [SELECT FEC_Current_Number__c FROM FEC_Case_ID_Counter__c WHERE Name = :COUNTER_KEY LIMIT 1]
                .FEC_Current_Number__c
        );
    }

    @IsTest
    static void testAllocateNextNumbers_existingCounterBelowInitIsRaised() {
        insert new FEC_Case_ID_Counter__c(
            Name = COUNTER_KEY,
            FEC_Prefix__c = PREFIX,
            FEC_Current_Number__c = 10
        );

        Map<String, Long> initByPrefix = new Map<String, Long>{ PREFIX => 100L };

        Test.startTest();
        Map<String, List<Long>> allocated = FEC_CaseIdCounterService.allocateNextNumbers(
            singleCount(),
            initByPrefix,
            counterNameMap()
        );
        Test.stopTest();

        System.assertEquals(101L, allocated.get(PREFIX)[0]);
    }

    @IsTest
    static void testAllocateNextNumbers_sequentialCallsDoNotReuseNumbers() {
        Test.startTest();
        for (Integer i = 0; i < 3; i++) {
            Map<String, List<Long>> batch = FEC_CaseIdCounterService.allocateNextNumbers(
                new Map<String, Integer>{ PREFIX => 2 },
                null,
                counterNameMap()
            );
            List<Long> numbers = batch.get(PREFIX);
            System.assertEquals(2, numbers.size());
            System.assert(numbers[1] > numbers[0], 'Numbers in a batch must be sequential.');
            if (i > 0) {
                System.assert(numbers[0] > 2 * i, 'Later batches must not reuse earlier numbers.');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testAllocateNextNumbersOnce_skipsBlankCounterKey() {
        Test.startTest();
        Map<String, List<Long>> allocated = FEC_CaseIdCounterService.allocateNextNumbersOnce(
            new Map<String, Integer>{ PREFIX => 1 },
            null,
            new Map<String, String>()
        );
        Test.stopTest();

        System.assertEquals(0, allocated.size());
        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Case_ID_Counter__c WHERE Name = :COUNTER_KEY]
        );
    }
}
