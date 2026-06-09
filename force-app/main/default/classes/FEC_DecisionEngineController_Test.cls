/**
 * @description Unit tests for FEC_StageTransitionEngine.
 *              Tests CRUD operations on MDM layer using the generic Decision Table wrapper
 *              (Condition rows with Type/Label/Value instead of external lookups).
 *
 * Validates: Requirements 4.1–4.6, 9.1, 9.2
 */
@IsTest(SeeAllData=false)
private class FEC_DecisionEngineController_Test {

    private static final String TABLE_KEY = 'UNIT_TEST_TABLE';

    // ════════════════════════════════════════════════════════
    // HELPER: Build a save payload JSON
    // ════════════════════════════════════════════════════════

    private static String buildPayload(String tableKey, Integer priority, String code, List<Map<String, Object>> conditions) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('priority', priority);
        payload.put('tableKey', tableKey);
        payload.put('code', code);
        payload.put('conditions', conditions);
        return JSON.serialize(payload);
    }

    private static String buildPayloadWithId(String recordId, String tableKey, Integer priority, String code, List<Map<String, Object>> conditions) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('recordId', recordId);
        payload.put('priority', priority);
        payload.put('tableKey', tableKey);
        payload.put('code', code);
        payload.put('conditions', conditions);
        return JSON.serialize(payload);
    }

    // ════════════════════════════════════════════════════════
    // TEST: saveRuleWithConditions — verify Condition rows
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testSaveRuleWithConditions_createsConditionRows() {
        List<Map<String, Object>> conditions = new List<Map<String, Object>>();
        conditions.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Previous Stage',
            'value' => 'Draft', 'operator' => '=', 'order' => 1
        });
        conditions.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '5000', 'operator' => '>', 'order' => 2
        });
        conditions.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Review', 'operator' => null, 'order' => 3
        });
        conditions.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Queue',
            'value' => 'Q_Review', 'operator' => null, 'order' => 4
        });
        conditions.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Available Decisions',
            'value' => 'Approve', 'operator' => null, 'order' => 5
        });

        String payload = buildPayload(TABLE_KEY, 1, 'RULE_001', conditions);

        Test.startTest();
        String ruleId = FEC_StageTransitionEngine.saveRuleWithConditions(payload);
        Test.stopTest();

        System.assertNotEquals(null, ruleId, 'Rule ID should be returned');

        // Verify rule fields
        FEC_MDM_Decision_Rule__c rule = [
            SELECT FEC_Priority__c, FEC_Table_Key__c, FEC_Active__c, FEC_Code__c
            FROM   FEC_MDM_Decision_Rule__c WHERE Id = :ruleId
        ];
        System.assertEquals(1, rule.FEC_Priority__c);
        System.assertEquals(TABLE_KEY, rule.FEC_Table_Key__c);
        System.assertEquals(true, rule.FEC_Active__c);
        System.assertEquals('RULE_001', rule.FEC_Code__c);

        // Verify condition rows
        List<FEC_MDM_Decision_Condition__c> rows = [
            SELECT FEC_Type__c, FEC_Label__c, FEC_Value__c, FEC_Operator__c, FEC_Order__c
            FROM   FEC_MDM_Decision_Condition__c
            WHERE  FEC_Decision_Rule__c = :ruleId
            ORDER BY FEC_Order__c ASC
        ];
        System.assertEquals(5, rows.size(), 'Should have 5 condition rows');

        // Row 0: Condition / Previous Stage
        System.assertEquals('Condition', rows[0].FEC_Type__c);
        System.assertEquals('Previous Stage', rows[0].FEC_Label__c);
        System.assertEquals('Draft', rows[0].FEC_Value__c);
        System.assertEquals('=', rows[0].FEC_Operator__c);

        // Row 1: Condition / Amount
        System.assertEquals('Condition', rows[1].FEC_Type__c);
        System.assertEquals('Amount', rows[1].FEC_Label__c);
        System.assertEquals('5000', rows[1].FEC_Value__c);

        // Row 2: Action / Next Stage
        System.assertEquals('Action', rows[2].FEC_Type__c);
        System.assertEquals('Next Stage', rows[2].FEC_Label__c);
        System.assertEquals('Review', rows[2].FEC_Value__c);

        // Row 3: Action / Next Queue
        System.assertEquals('Action', rows[3].FEC_Type__c);
        System.assertEquals('Next Queue', rows[3].FEC_Label__c);
        System.assertEquals('Q_Review', rows[3].FEC_Value__c);

        // Row 4: Action / Available Decisions
        System.assertEquals('Action', rows[4].FEC_Type__c);
        System.assertEquals('Available Decisions', rows[4].FEC_Label__c);
        System.assertEquals('Approve', rows[4].FEC_Value__c);
    }


    // ════════════════════════════════════════════════════════
    // TEST: saveRuleWithConditions — update existing rule
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testSaveRuleWithConditions_updateExistingRule() {
        // Create initial rule
        List<Map<String, Object>> conditions = new List<Map<String, Object>>();
        conditions.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Previous Stage',
            'value' => 'Draft', 'operator' => '=', 'order' => 1
        });
        String payload = buildPayload(TABLE_KEY, 1, 'UPD_001', conditions);
        String ruleId = FEC_StageTransitionEngine.saveRuleWithConditions(payload);

        // Update with new conditions
        List<Map<String, Object>> newConditions = new List<Map<String, Object>>();
        newConditions.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Status',
            'value' => 'Active', 'operator' => '=', 'order' => 1
        });
        newConditions.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Closed', 'operator' => null, 'order' => 2
        });
        String updatePayload = buildPayloadWithId(ruleId, TABLE_KEY, 2, 'UPD_001', newConditions);

        Test.startTest();
        String updatedId = FEC_StageTransitionEngine.saveRuleWithConditions(updatePayload);
        Test.stopTest();

        System.assertEquals(ruleId, updatedId, 'Should update same rule');

        List<FEC_MDM_Decision_Condition__c> rows = [
            SELECT FEC_Type__c, FEC_Label__c, FEC_Value__c
            FROM   FEC_MDM_Decision_Condition__c
            WHERE  FEC_Decision_Rule__c = :ruleId
            ORDER BY FEC_Order__c ASC
        ];
        // Old condition (Previous Stage) should be deleted, new ones created
        System.assertEquals(2, rows.size(), 'Should have 2 new condition rows');
        System.assertEquals('Status', rows[0].FEC_Label__c);
        System.assertEquals('Next Stage', rows[1].FEC_Label__c);
    }

    // ════════════════════════════════════════════════════════
    // TEST: deleteConditionColumn by Label
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testDeleteConditionColumn_byLabel() {
        // Create two rules with "Amount" condition
        List<Map<String, Object>> conds1 = new List<Map<String, Object>>();
        conds1.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '>', 'order' => 1
        });
        conds1.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Review', 'operator' => null, 'order' => 2
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'DEL_001', conds1));

        List<Map<String, Object>> conds2 = new List<Map<String, Object>>();
        conds2.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '200', 'operator' => '>', 'order' => 1
        });
        conds2.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Approve', 'operator' => null, 'order' => 2
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 2, 'DEL_002', conds2));

        // Verify Amount conditions exist
        Integer amountBefore = [
            SELECT COUNT() FROM FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = 'Amount'
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :TABLE_KEY
        ];
        System.assertEquals(2, amountBefore, 'Should have 2 Amount conditions');

        Test.startTest();
        FEC_StageTransitionEngine.deleteConditionColumn(null, 'Amount', TABLE_KEY);
        Test.stopTest();

        // Amount conditions should be deleted
        Integer amountAfter = [
            SELECT COUNT() FROM FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = 'Amount'
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :TABLE_KEY
        ];
        System.assertEquals(0, amountAfter, 'Amount conditions should be deleted');

        // Next Stage actions should remain
        Integer nextStageCount = [
            SELECT COUNT() FROM FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = 'Next Stage'
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :TABLE_KEY
        ];
        System.assertEquals(2, nextStageCount, 'Next Stage actions should remain');
    }

    // ════════════════════════════════════════════════════════
    // TEST: deleteConditionColumn — non-existent label (idempotent)
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testDeleteConditionColumn_nonExistentLabel() {
        Test.startTest();
        // Should not throw
        FEC_StageTransitionEngine.deleteConditionColumn(null, 'NonExistent', TABLE_KEY);
        Test.stopTest();
        // No assertion needed — just verifying no exception
    }

    // ════════════════════════════════════════════════════════
    // TEST: updateColumnProperties by Label
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateColumnProperties_byLabel() {
        // Create rule with Amount condition
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '>', 'order' => 1
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '200', 'operator' => '>', 'order' => 2
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'UCP_001', conds));

        Test.startTest();
        // Should not throw — verifies label-based matching works
        FEC_StageTransitionEngine.updateColumnProperties(null, 'Amount', 'GREATER_THAN', 'TRIM', TABLE_KEY);
        Test.stopTest();

        // Verify conditions still exist (not deleted)
        List<FEC_MDM_Decision_Condition__c> updated = [
            SELECT FEC_Operator__c, FEC_Expression__c
            FROM   FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = 'Amount'
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :TABLE_KEY
        ];
        System.assertEquals(2, updated.size(), 'Should have 2 Amount conditions');
    }


    // ════════════════════════════════════════════════════════
    // TEST: updateColumnProperties — blank label throws
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateColumnProperties_blankLabelThrows() {
        Boolean caught = false;
        Test.startTest();
        try {
            FEC_StageTransitionEngine.updateColumnProperties(null, '', '=', null, TABLE_KEY);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        System.assert(caught, 'Should throw AuraHandledException for blank label');
    }

    // ════════════════════════════════════════════════════════
    // TEST: getDecisionTableData — column structure from Labels
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetDecisionTableData_columnStructure() {
        // Create rule with dynamic Condition columns
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Previous Stage',
            'value' => 'Draft', 'operator' => '=', 'order' => 1
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '>', 'order' => 2
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Region',
            'value' => 'APAC', 'operator' => '=', 'order' => 3
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Review', 'operator' => null, 'order' => 4
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'GDT_001', conds));

        Test.startTest();
        Map<String, Object> tableData = FEC_StageTransitionEngine.getDecisionTableData(null, TABLE_KEY);
        Test.stopTest();

        System.assertNotEquals(null, tableData, 'Table data should not be null');

        // conditionColumns should contain Amount and Region (not Previous Stage — it's a fixed label)
        List<Object> columns = (List<Object>) tableData.get('conditionColumns');
        System.assertNotEquals(null, columns, 'conditionColumns should not be null');

        Set<String> columnNames = new Set<String>();
        for (Object col : columns) {
            Map<String, Object> colMap = (Map<String, Object>) col;
            columnNames.add((String) colMap.get('fieldName'));
        }
        System.assert(columnNames.contains('Amount'), 'Should contain Amount column');
        System.assert(columnNames.contains('Region'), 'Should contain Region column');
        System.assert(!columnNames.contains('Previous Stage'), 'Should NOT contain Previous Stage (fixed label)');
        System.assert(!columnNames.contains('Next Stage'), 'Should NOT contain Action columns');

        // rules should be present
        List<Object> rules = (List<Object>) tableData.get('rules');
        System.assertEquals(1, rules.size(), 'Should have 1 rule');
    }

    // ════════════════════════════════════════════════════════
    // TEST: getRulesWithConditions — data from Condition rows
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetRulesWithConditions_dataFromConditionRows() {
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Previous Stage',
            'value' => 'Draft', 'operator' => '=', 'order' => 1
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Action Button',
            'value' => 'Submit', 'operator' => '=', 'order' => 2
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Review', 'operator' => null, 'order' => 3
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Queue',
            'value' => 'Q_Review', 'operator' => null, 'order' => 4
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Available Decisions',
            'value' => 'Approve,Reject', 'operator' => null, 'order' => 5
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Team User Group',
            'value' => 'TeamA', 'operator' => null, 'order' => 6
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Process Change Status',
            'value' => 'In Progress', 'operator' => null, 'order' => 7
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Custom Actions',
            'value' => 'SendEmail', 'operator' => null, 'order' => 8
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'GRC_001', conds));

        Test.startTest();
        List<Map<String, Object>> rules = FEC_StageTransitionEngine.getRulesWithConditions(null, TABLE_KEY);
        Test.stopTest();

        System.assertEquals(1, rules.size(), 'Should return 1 rule');
        Map<String, Object> rule = rules[0];

        // Verify rule-level fields derived from Condition rows
        System.assertEquals('Draft', rule.get('currentStage'));
        System.assertEquals('Submit', rule.get('action'));
        System.assertEquals('Review', rule.get('nextStage'));
        System.assertEquals('Q_Review', rule.get('nextQueue'));
        System.assertEquals('Approve,Reject', rule.get('availableDecisions'));
        System.assertEquals('TeamA', rule.get('teamUserGroup'));
        System.assertEquals('In Progress', rule.get('processChangeStatus'));
        System.assertEquals('SendEmail', rule.get('customActions'));
        System.assertEquals(true, rule.get('active'));
        System.assertEquals(TABLE_KEY, rule.get('tableKey'));

        // Verify conditions list
        List<Object> condList = (List<Object>) rule.get('conditions');
        System.assertEquals(8, condList.size(), 'Should have 8 condition entries');
    }

    // ════════════════════════════════════════════════════════
    // TEST: getFieldsForBusinessProcess — returns labels
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testGetFieldsForBusinessProcess_returnsLabels() {
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Previous Stage',
            'value' => 'Draft', 'operator' => '=', 'order' => 1
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '>', 'order' => 2
        });
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Region',
            'value' => 'APAC', 'operator' => '=', 'order' => 3
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Review', 'operator' => null, 'order' => 4
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'GFP_001', conds));

        Test.startTest();
        List<Map<String, String>> fields = FEC_StageTransitionEngine.getFieldsForBusinessProcess(null, TABLE_KEY);
        Test.stopTest();

        // Should return Amount and Region (not Previous Stage — fixed label, not Action rows)
        Set<String> fieldLabels = new Set<String>();
        for (Map<String, String> f : fields) {
            fieldLabels.add(f.get('label'));
        }
        System.assert(fieldLabels.contains('Amount'), 'Should contain Amount');
        System.assert(fieldLabels.contains('Region'), 'Should contain Region');
        System.assert(!fieldLabels.contains('Previous Stage'), 'Should NOT contain Previous Stage');
        System.assert(!fieldLabels.contains('Next Stage'), 'Should NOT contain Action labels');
    }

    // ════════════════════════════════════════════════════════
    // TEST: testRuleEvaluation — basic match
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testTestRuleEvaluation_basicMatch() {
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '=', 'order' => 1
        });
        conds.add(new Map<String, Object>{
            'type' => 'Action', 'label' => 'Next Stage',
            'value' => 'Approved', 'operator' => null, 'order' => 2
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'TRE_001', conds));

        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionEngine.testRuleEvaluation(
            null, new Map<String, String>{ 'Amount' => '100' }, TABLE_KEY
        );
        Test.stopTest();

        System.assertEquals(true, result.get('matched'));
        System.assertEquals('Approved', result.get('nextStageName'));
    }

    // ════════════════════════════════════════════════════════
    // TEST: testRuleEvaluation — no match
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testTestRuleEvaluation_noMatch() {
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '=', 'order' => 1
        });
        FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'TRE_002', conds));

        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionEngine.testRuleEvaluation(
            null, new Map<String, String>{ 'Amount' => '999' }, TABLE_KEY
        );
        Test.stopTest();

        System.assertEquals(false, result.get('matched'));
    }

    // ════════════════════════════════════════════════════════
    // TEST: testRuleEvaluation — no rules exist
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testTestRuleEvaluation_noRules() {
        Test.startTest();
        Map<String, Object> result = FEC_StageTransitionEngine.testRuleEvaluation(
            null, new Map<String, String>{ 'Amount' => '100' }, 'NONEXISTENT_KEY'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('matched'));
    }

    // ════════════════════════════════════════════════════════
    // TEST: deleteRule — cascade deletes conditions
    // ════════════════════════════════════════════════════════

    @IsTest
    static void testDeleteRule_cascadeDeletesConditions() {
        List<Map<String, Object>> conds = new List<Map<String, Object>>();
        conds.add(new Map<String, Object>{
            'type' => 'Condition', 'label' => 'Amount',
            'value' => '100', 'operator' => '=', 'order' => 1
        });
        String ruleId = FEC_StageTransitionEngine.saveRuleWithConditions(buildPayload(TABLE_KEY, 1, 'CDEL_001', conds));

        Integer condsBefore = [SELECT COUNT() FROM FEC_MDM_Decision_Condition__c WHERE FEC_Decision_Rule__c = :ruleId];
        System.assertEquals(1, condsBefore, 'Should have 1 condition before delete');

        Test.startTest();
        FEC_StageTransitionEngine.deleteRule(ruleId);
        Test.stopTest();

        Integer rulesAfter = [SELECT COUNT() FROM FEC_MDM_Decision_Rule__c WHERE Id = :ruleId];
        System.assertEquals(0, rulesAfter, 'Rule should be deleted');

        Integer condsAfter = [SELECT COUNT() FROM FEC_MDM_Decision_Condition__c WHERE FEC_Decision_Rule__c = :ruleId];
        System.assertEquals(0, condsAfter, 'Conditions should be cascade-deleted');
    }
}