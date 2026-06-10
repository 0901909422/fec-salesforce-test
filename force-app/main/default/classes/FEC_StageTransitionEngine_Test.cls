/**
 * @description Unit tests for FEC_StageTransitionEngine.
 *              Tests Live layer evaluation using FEC_Decision_Rule__c / FEC_Decision_Condition__c
 *              with the generic Decision Table wrapper (Condition rows with Type/Label/Value).
 *
 * Validates: Requirements 5.1–5.5, 8.1, 3.2
 */
@IsTest(SeeAllData=false)
private class FEC_StageTransitionEngine_Test {

    private static final String TABLE_KEY = 'STAGE_TRANSITION';

    // ════════════════════════════════════════════════════════
    // HELPERS
    // ════════════════════════════════════════════════════════

    /**
     * Create a Live Decision Rule with conditions.
     */
    private static FEC_Decision_Rule__c createRule(Integer priority, List<FEC_Decision_Condition__c> conditionTemplates) {
        FEC_Decision_Rule__c rule = new FEC_Decision_Rule__c(
            FEC_Table_Key__c = TABLE_KEY,
            FEC_Active__c = true,
            FEC_Priority__c = priority,
            FEC_Code__c = 'TEST_' + priority
        );
        insert rule;

        if (conditionTemplates != null && !conditionTemplates.isEmpty()) {
            List<FEC_Decision_Condition__c> toInsert = new List<FEC_Decision_Condition__c>();
            for (FEC_Decision_Condition__c tpl : conditionTemplates) {
                toInsert.add(new FEC_Decision_Condition__c(
                    FEC_Decision_Rule__c = rule.Id,
                    FEC_Type__c = tpl.FEC_Type__c,
                    FEC_Label__c = tpl.FEC_Label__c,
                    FEC_Value__c = tpl.FEC_Value__c,
                    FEC_Operator__c = tpl.FEC_Operator__c,
                    FEC_Order__c = tpl.FEC_Order__c
                ));
            }
            insert toInsert;
        }
        return rule;
    }

    /**
     * Build a condition template (not yet inserted — no Rule Id).
     */
    private static FEC_Decision_Condition__c cond(String type, String label, String value, String operator, Integer ord) {
        return new FEC_Decision_Condition__c(
            FEC_Type__c = type,
            FEC_Label__c = label,
            FEC_Value__c = value,
            FEC_Operator__c = operator,
            FEC_Order__c = ord
        );
    }

    // ════════════════════════════════════════════════════════
    // TEST 1: getDecisionTableResults with Condition rows
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetDecisionTableResults_withConditionRows() {
        // Create stage record
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = 'Draft', FEC_Code__c = 'DRAFT_T1');
        insert stage;

        // Create action button record
        FEC_Action_Button__c btn = new FEC_Action_Button__c(Name = 'Submit', FEC_Code__c = 'SUBMIT_T1');
        insert btn;

        // Create rule with Condition rows (Previous Stage, Action Button) and Action rows
        List<FEC_Decision_Condition__c> conditions = new List<FEC_Decision_Condition__c>{
            cond('Condition', 'Previous Stage', 'Draft', '=', 1),
            cond('Condition', 'Action Button', 'Submit', '=', 2),
            cond('Action', 'Next Stage', 'Review', null, 3),
            cond('Action', 'Next Queue', 'Q_Review', null, 4),
            cond('Action', 'Available Decisions', 'Approve,Reject', null, 5)
        };
        createRule(1, conditions);

        // Create a Case
        Case testCase = new Case(Subject = 'Test Case');
        insert testCase;

        Test.startTest();
        Map<String, Map<String, Object>> result = FEC_StageTransitionEngine.getDecisionTableResults(
            testCase.Id, stage.Id, null, false
        );
        Test.stopTest();

        // The rule should match — "Available Decisions" is the group key
        System.assert(result.containsKey('Approve,Reject'), 'Result should contain Approve,Reject key');
        Map<String, Object> matchEntry = result.get('Approve,Reject');
        System.assertEquals(true, matchEntry.get('matched'));
        System.assertEquals('Review', matchEntry.get('nextStageName'));
        System.assertEquals('Q_Review', matchEntry.get('nextQueue'));
        System.assertEquals('Approve,Reject', matchEntry.get('availableDecisions'));
    }

    // ════════════════════════════════════════════════════════
    // TEST 2: evaluateSingleTransition with Condition rows
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testEvaluateSingleTransition_withConditionRows() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = 'Draft', FEC_Code__c = 'DRAFT_T2');
        insert stage;

        FEC_Action_Button__c btn = new FEC_Action_Button__c(Name = 'Submit', FEC_Code__c = 'SUBMIT_T2');
        insert btn;

        List<FEC_Decision_Condition__c> conditions = new List<FEC_Decision_Condition__c>{
            cond('Condition', 'Previous Stage', 'Draft', '=', 1),
            cond('Condition', 'Action Button', 'Submit', '=', 2),
            cond('Action', 'Next Stage', 'Approved', null, 3),
            cond('Action', 'Next Queue', 'Q_Approved', null, 4),
            cond('Action', 'Available Decisions', 'Close', null, 5)
        };
        createRule(1, conditions);

        Case testCase = new Case(Subject = 'Test Single Transition');
        insert testCase;

        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionEngine.evaluateSingleTransition(
            testCase.Id, stage.Id, btn.Id
        );
        Test.stopTest();

        System.assertEquals(true, result.get('matched'));
        System.assertEquals('Approved', result.get('nextStageName'));
        System.assertEquals('Q_Approved', result.get('nextQueue'));
        System.assertEquals('Close', result.get('availableDecisions'));
    }

    // ════════════════════════════════════════════════════════
    // TEST 3: getDecisionTableResults — no matching Previous Stage
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetDecisionTableResults_noMatchingPreviousStage() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = 'Review', FEC_Code__c = 'REVIEW_T3');
        insert stage;

        List<FEC_Decision_Condition__c> conditions = new List<FEC_Decision_Condition__c>{
            cond('Condition', 'Previous Stage', 'Draft', '=', 1),
            cond('Action', 'Next Stage', 'Approved', null, 2),
            cond('Action', 'Available Decisions', 'Submit', null, 3)
        };
        createRule(1, conditions);

        Case testCase = new Case(Subject = 'No Match Case');
        insert testCase;

        Test.startTest();
        Map<String, Map<String, Object>> result = FEC_StageTransitionEngine.getDecisionTableResults(
            testCase.Id, stage.Id, null, false
        );
        Test.stopTest();

        // Should not contain any matched transition (Revert may be present but no rule match)
        result.remove('Revert');
        System.assertEquals(0, result.size(), 'No rules should match when Previous Stage does not match');
    }

    // ════════════════════════════════════════════════════════
    // TEST 4: Cascade delete — deleting rule deletes conditions
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testCascadeDelete() {
        List<FEC_Decision_Condition__c> conditions = new List<FEC_Decision_Condition__c>{
            cond('Condition', 'Previous Stage', 'Draft', '=', 1),
            cond('Action', 'Next Stage', 'Review', null, 2),
            cond('Action', 'Next Queue', 'Q1', null, 3)
        };
        FEC_Decision_Rule__c rule = createRule(1, conditions);

        // Verify conditions exist
        Integer condsBefore = [SELECT COUNT() FROM FEC_Decision_Condition__c WHERE FEC_Decision_Rule__c = :rule.Id];
        System.assertEquals(3, condsBefore, 'Should have 3 conditions before delete');

        Test.startTest();
        delete rule;
        Test.stopTest();

        // Rule should be gone
        Integer rulesAfter = [SELECT COUNT() FROM FEC_Decision_Rule__c WHERE Id = :rule.Id];
        System.assertEquals(0, rulesAfter, 'Rule should be deleted');

        // Conditions should be cascade-deleted via master-detail
        Integer condsAfter = [SELECT COUNT() FROM FEC_Decision_Condition__c WHERE FEC_Decision_Rule__c = :rule.Id];
        System.assertEquals(0, condsAfter, 'Conditions should be cascade-deleted');
    }

    // ════════════════════════════════════════════════════════
    // TEST 5: getDecisionTableResults with dynamic conditions
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetDecisionTableResults_withDynamicConditions() {
        FEC_Case_Stage__c stage = new FEC_Case_Stage__c(Name = 'Draft', FEC_Code__c = 'DRAFT_T5');
        insert stage;

        // Rule with Previous Stage + a dynamic Condition on Priority = 'High'
        // Priority is a standard Case picklist field
        List<FEC_Decision_Condition__c> conditions = new List<FEC_Decision_Condition__c>{
            cond('Condition', 'Previous Stage', 'Draft', '=', 1),
            cond('Condition', 'Priority', 'High', '=', 2),
            cond('Action', 'Next Stage', 'High Value Review', null, 3),
            cond('Action', 'Available Decisions', 'Escalate', null, 4)
        };
        createRule(1, conditions);

        // Create Case with Priority = 'High' (should match the dynamic condition)
        Case testCase = new Case(Subject = 'Dynamic Condition Case', Priority = 'High');
        insert testCase;

        Test.startTest();
        Map<String, Map<String, Object>> result = FEC_StageTransitionEngine.getDecisionTableResults(
            testCase.Id, stage.Id, null, false
        );
        Test.stopTest();

        System.assert(result.containsKey('Escalate'), 'Result should contain Escalate key');
        Map<String, Object> matchEntry = result.get('Escalate');
        System.assertEquals(true, matchEntry.get('matched'));
        System.assertEquals('High Value Review', matchEntry.get('nextStageName'));
    }
}