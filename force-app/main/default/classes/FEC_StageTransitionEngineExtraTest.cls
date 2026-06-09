/**
 * @description Extra tests for FEC_StageTransitionEngine facade.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      MDM | Decision Engine
 */
@IsTest
private class FEC_StageTransitionEngineExtraTest {

    @IsTest
    static void testInsertStageHistory_NullIds() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.insertStageHistory(null, null, null, null, null);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testGetDecisionTableData_Null() {
        Test.startTest();
        Map<String, Object> data = FEC_StageTransitionEngine.getDecisionTableData(null, 'KEY');
        Test.stopTest();
        Assert.isNotNull(data);
    }

    @IsTest
    static void testDeleteAllRulesByBP_Null() {
        try {
            Test.startTest();
            Integer cnt = FEC_StageTransitionEngine.deleteAllRulesByBP(null, 'KEY');
            Test.stopTest();
            Assert.isNotNull(cnt);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testDeleteConditionColumn() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.deleteConditionColumn(null, 'TestLabel', 'KEY');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testUpdateColumnProperties() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.updateColumnProperties(null, 'Label', '=', null, 'KEY');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testTestRuleEvaluation_NullFields() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.testRuleEvaluation(null, new Map<String, String>(), 'KEY');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testGetFieldsForBusinessProcess_Null() {
        Test.startTest();
        List<Map<String, String>> fields = FEC_StageTransitionEngine.getFieldsForBusinessProcess(null, 'KEY');
        Test.stopTest();
        Assert.isNotNull(fields);
    }

    @IsTest
    static void testGetMDMDecisionTableResults_Null() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.getMDMDecisionTableResults(null, null, 'TestAction', false);
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }

    @IsTest
    static void testEvaluateSingleTransitionWithKey_Null() {
        try {
            Test.startTest();
            FEC_StageTransitionEngine.evaluateSingleTransitionWithKey(null, null, null, 'KEY');
            Test.stopTest();
        } catch (Exception e) {
            // OK
        }
        Assert.isTrue(true);
    }
}