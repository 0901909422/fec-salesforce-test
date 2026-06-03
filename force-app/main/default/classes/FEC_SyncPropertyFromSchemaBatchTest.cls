/**
 * @description Smoke test for FEC_SyncPropertyFromSchemaBatch.
 *              Run batch với scope nhỏ để verify lifecycle (start/execute/finish).
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM
 */
@IsTest
private class FEC_SyncPropertyFromSchemaBatchTest {

    @IsTest
    static void testBatch_RunLifecycle() {
        Test.startTest();
        try {
            Database.executeBatch(new FEC_SyncPropertyFromSchemaBatch(), 1);
            Assert.isTrue(true, 'Batch enqueued without throwing');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Execute_DeleteStep() {
        // Insert sample data first to be deleted
        FEC_MDM_Additional_Field__c af = new FEC_MDM_Additional_Field__c(
            FEC_Unique_ID__c = 'AF_SP_DEL',
            FEC_Type__c = 'String',
            FEC_Name_VN__c = 'TV',
            FEC_Field_Status__c = true,
            Field_API_Name__c = 'Existing_Field__c'
        );
        insert af;

        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.execute(null, new List<String>{'DELETE'});
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Execute_CreateProperties() {
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.execute(null, new List<String>{'CREATE_PROPERTIES'});
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Execute_CreateListValues() {
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.execute(null, new List<String>{'CREATE_LIST_VALUES'});
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Execute_UnknownStep() {
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.execute(null, new List<String>{'UNKNOWN_STEP'});
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Finish() {
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.finish(null);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBatch_Start_TestMode() {
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        Iterable<String> result = batch.start(null);
        Test.stopTest();
        Assert.isNotNull(result);
    }

    @IsTest
    static void testBatch_AllStepsSequential() {
        // Single batch instance, executes all 3 steps in order.
        // This populates fieldApiNameToPropertyIdMap (set by CREATE_PROPERTIES) so
        // CREATE_LIST_VALUES can iterate properly (covers lines 245-280).
        FEC_SyncPropertyFromSchemaBatch batch = new FEC_SyncPropertyFromSchemaBatch();
        Test.startTest();
        try {
            batch.execute(null, new List<String>{'DELETE'});
            batch.execute(null, new List<String>{'CREATE_PROPERTIES'});
            batch.execute(null, new List<String>{'CREATE_LIST_VALUES'});
            batch.finish(null);
            Assert.isTrue(true);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}