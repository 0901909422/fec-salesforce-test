/**
 * @description Property-based tests for the generic Decision Table wrapper.
 *              Uses parameterized test methods with generated data (100+ iterations)
 *              to verify correctness properties across the input space.
 *
 *              Operates on MDM layer: FEC_MDM_Decision_Rule__c / FEC_MDM_Decision_Condition__c.
 */
@IsTest(SeeAllData=false)
private class FEC_DecisionEngine_Property_Test {

    private static final String TABLE_KEY = 'PROP_TEST';
    private static final List<String> VALID_TYPES = new List<String>{ 'Condition', 'Action' };
    private static final List<String> CONDITION_LABELS = new List<String>{
        'Previous Stage', 'Amount', 'Region', 'Status', 'Category', 'Priority Level'
    };
    private static final List<String> ACTION_LABELS = new List<String>{
        'Next Stage', 'Next Queue', 'Available Decisions', 'Team User Group',
        'Process Change Status', 'Custom Actions'
    };
    private static final List<String> OPERATORS = new List<String>{ '=', '!=', '>', '<', '>=', '<=' };

    // ════════════════════════════════════════════════════════
    // RANDOM DATA GENERATORS
    // ════════════════════════════════════════════════════════

    private static String randomString(Integer len) {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String result = '';
        for (Integer i = 0; i < len; i++) {
            result += chars.substring(
                Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length()),
                Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length()) + 1
            );
        }
        return result.length() > len ? result.substring(0, len) : result;
    }

    private static Integer randomInt(Integer minVal, Integer maxVal) {
        return minVal + Math.mod(Math.abs(Crypto.getRandomInteger()), (maxVal - minVal + 1));
    }

    private static String randomFrom(List<String> items) {
        return items[Math.mod(Math.abs(Crypto.getRandomInteger()), items.size())];
    }

    /**
     * Generate a random save payload JSON with N condition rows and M action rows.
     */
    private static String generateRulePayload(Integer numConditions, Integer numActions, String tKey) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('priority', randomInt(1, 100));
        payload.put('tableKey', tKey);
        payload.put('code', 'PROP_' + randomString(6));

        List<Map<String, Object>> conditions = new List<Map<String, Object>>();
        Integer order = 1;
        for (Integer i = 0; i < numConditions; i++) {
            conditions.add(new Map<String, Object>{
                'type'     => 'Condition',
                'label'    => CONDITION_LABELS[Math.mod(i, CONDITION_LABELS.size())],
                'value'    => 'Val_' + randomString(5),
                'operator' => randomFrom(OPERATORS),
                'order'    => order++
            });
        }
        for (Integer i = 0; i < numActions; i++) {
            conditions.add(new Map<String, Object>{
                'type'     => 'Action',
                'label'    => ACTION_LABELS[Math.mod(i, ACTION_LABELS.size())],
                'value'    => 'Act_' + randomString(5),
                'operator' => null,
                'order'    => order++
            });
        }
        payload.put('conditions', conditions);
        return JSON.serialize(payload);
    }

    // ════════════════════════════════════════════════════════
    // Property 1: Condition Row Data Model Invariant
    // ════════════════════════════════════════════════════════

    /**
     * Feature: generic-decision-table-wrapper, Property 1: Condition Row Data Model Invariant
     *
     * For any rule saved through saveRuleWithConditions, every column value SHALL be stored
     * as a Decision_Condition row where FEC_Type__c ∈ {Condition, Action}, FEC_Label__c is
     * non-blank, and FEC_Value__c matches the input value.
     *
     * Validates: Requirements 2.1, 2.2, 2.3, 2.4
     */
    @IsTest
    static void property1_conditionRowDataModelInvariant() {
        // We batch 100 iterations into groups to stay within DML limits
        Integer iterations = 100;
        for (Integer iter = 0; iter < iterations; iter++) {
            Integer numConds = randomInt(1, 4);
            Integer numActions = randomInt(1, 4);
            String tableKeyIter = TABLE_KEY + '_P1_' + iter;
            String payload = generateRulePayload(numConds, numActions, tableKeyIter);

            // Parse payload to capture expected values
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
            List<Object> expectedConds = (List<Object>) parsed.get('conditions');

            Test.startTest();
            String ruleId = FEC_StageTransitionEngine.saveRuleWithConditions(payload);
            Test.stopTest();

            // Query persisted condition rows
            List<FEC_MDM_Decision_Condition__c> rows = [
                SELECT FEC_Type__c, FEC_Label__c, FEC_Value__c, FEC_Order__c
                FROM   FEC_MDM_Decision_Condition__c
                WHERE  FEC_Decision_Rule__c = :ruleId
                ORDER BY FEC_Order__c ASC
            ];

            System.assertEquals(expectedConds.size(), rows.size(),
                'Iteration ' + iter + ': row count mismatch');

            for (Integer i = 0; i < rows.size(); i++) {
                FEC_MDM_Decision_Condition__c row = rows[i];
                Map<String, Object> expected = (Map<String, Object>) expectedConds[i];

                // Type must be Condition or Action
                System.assert(
                    VALID_TYPES.contains(row.FEC_Type__c),
                    'Iteration ' + iter + ': invalid Type "' + row.FEC_Type__c + '"'
                );
                // Label must be non-blank
                System.assert(
                    String.isNotBlank(row.FEC_Label__c),
                    'Iteration ' + iter + ': blank Label on row ' + i
                );
                // Value must match input
                System.assertEquals(
                    (String) expected.get('value'), row.FEC_Value__c,
                    'Iteration ' + iter + ': value mismatch on row ' + i
                );
                // Type must match input
                System.assertEquals(
                    (String) expected.get('type'), row.FEC_Type__c,
                    'Iteration ' + iter + ': type mismatch on row ' + i
                );
            }
        }
    }


    // ════════════════════════════════════════════════════════
    // Property 2: Save/Load Round Trip
    // ════════════════════════════════════════════════════════

    /**
     * Feature: generic-decision-table-wrapper, Property 2: Save/Load Round Trip
     *
     * For any valid rule payload, saving via saveRuleWithConditions and then loading via
     * getRulesWithConditions SHALL produce a response where every original column value
     * is recoverable from the Condition rows' Type, Label, and Value fields.
     *
     * Validates: Requirements 4.3
     */
    @IsTest
    static void property2_saveLoadRoundTrip() {
        Integer iterations = 100;
        for (Integer iter = 0; iter < iterations; iter++) {
            Integer numConds = randomInt(1, 3);
            Integer numActions = randomInt(1, 3);
            String tableKeyIter = TABLE_KEY + '_P2_' + iter;
            String payload = generateRulePayload(numConds, numActions, tableKeyIter);

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
            List<Object> expectedConds = (List<Object>) parsed.get('conditions');

            Test.startTest();
            String ruleId = FEC_StageTransitionEngine.saveRuleWithConditions(payload);

            // Load back via getRulesWithConditions
            List<Map<String, Object>> loaded = FEC_StageTransitionEngine.getRulesWithConditions(null, tableKeyIter);
            Test.stopTest();

            System.assertEquals(1, loaded.size(),
                'Iteration ' + iter + ': expected 1 rule loaded');

            Map<String, Object> loadedRule = loaded[0];
            List<Object> loadedConds = (List<Object>) loadedRule.get('conditions');

            System.assertEquals(expectedConds.size(), loadedConds.size(),
                'Iteration ' + iter + ': condition count mismatch after round trip');

            // Build a map of label+type → value from expected
            Map<String, String> expectedMap = new Map<String, String>();
            for (Object obj : expectedConds) {
                Map<String, Object> ec = (Map<String, Object>) obj;
                String key = (String) ec.get('type') + '|' + (String) ec.get('label');
                expectedMap.put(key, (String) ec.get('value'));
            }

            // Verify each loaded condition matches
            for (Object obj : loadedConds) {
                Map<String, Object> lc = (Map<String, Object>) obj;
                String lcType = (String) lc.get('type');
                String lcLabel = (String) lc.get('label');
                String lcValue = (String) lc.get('value');
                String key = lcType + '|' + lcLabel;

                System.assert(expectedMap.containsKey(key),
                    'Iteration ' + iter + ': unexpected condition ' + key);
                System.assertEquals(expectedMap.get(key), lcValue,
                    'Iteration ' + iter + ': value mismatch for ' + key);
            }
        }
    }

    // ════════════════════════════════════════════════════════
    // Property 5: Evaluation Uses Condition-Type Rows
    // ════════════════════════════════════════════════════════

    /**
     * Feature: generic-decision-table-wrapper, Property 5: Evaluation Uses Condition-Type Rows
     *
     * For any rule evaluation via testRuleEvaluation, the engine SHALL evaluate only
     * Decision_Condition rows with Type="Condition" against the provided field values.
     * Action rows SHALL NOT influence matching.
     *
     * Validates: Requirements 5.1, 5.3, 5.5, 10.1, 10.2
     */
    @IsTest
    static void property5_evaluationUsesConditionTypeRows() {
        Integer iterations = 100;
        for (Integer iter = 0; iter < iterations; iter++) {
            String tableKeyIter = TABLE_KEY + '_P5_' + iter;
            // Create a rule with 1 Condition row and 1-3 Action rows
            String condLabel = 'Amount';
            String condValue = String.valueOf(randomInt(1, 1000));

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('priority', 1);
            payload.put('tableKey', tableKeyIter);
            payload.put('code', 'P5_' + iter);

            List<Map<String, Object>> conditions = new List<Map<String, Object>>();
            // Condition row
            conditions.add(new Map<String, Object>{
                'type' => 'Condition', 'label' => condLabel,
                'value' => condValue, 'operator' => '=', 'order' => 1
            });
            // Action rows — these should NOT affect matching
            Integer numActions = randomInt(1, 3);
            for (Integer a = 0; a < numActions; a++) {
                conditions.add(new Map<String, Object>{
                    'type' => 'Action', 'label' => ACTION_LABELS[a],
                    'value' => 'ActionVal_' + randomString(4), 'operator' => null, 'order' => 2 + a
                });
            }
            payload.put('conditions', conditions);

            Test.startTest();
            FEC_StageTransitionEngine.saveRuleWithConditions(JSON.serialize(payload));

            // Test with matching field value — should match
            Map<String, String> matchingFields = new Map<String, String>{ condLabel => condValue };
            Map<String, Object> matchResult = FEC_StageTransitionEngine.testRuleEvaluation(null, matchingFields, tableKeyIter);

            // Test with non-matching field value — should NOT match
            Map<String, String> nonMatchingFields = new Map<String, String>{ condLabel => condValue + '_WRONG' };
            Map<String, Object> noMatchResult = FEC_StageTransitionEngine.testRuleEvaluation(null, nonMatchingFields, tableKeyIter);
            Test.stopTest();

            System.assertEquals(true, matchResult.get('matched'),
                'Iteration ' + iter + ': should match when Condition row value matches');
            System.assertEquals(false, noMatchResult.get('matched'),
                'Iteration ' + iter + ': should NOT match when Condition row value differs');
        }
    }


    // ════════════════════════════════════════════════════════
    // Property 6: Match Result from Action Rows
    // ════════════════════════════════════════════════════════

    /**
     * Feature: generic-decision-table-wrapper, Property 6: Match Result from Action Rows
     *
     * For any rule that matches during evaluation, the result map (Next Stage, Next Queue,
     * Available Decisions, Team User Group) SHALL be constructed exclusively from
     * Decision_Condition rows with Type="Action".
     *
     * Validates: Requirements 5.2, 5.4, 10.3
     */
    @IsTest
    static void property6_matchResultFromActionRows() {
        Integer iterations = 100;
        for (Integer iter = 0; iter < iterations; iter++) {
            String tableKeyIter = TABLE_KEY + '_P6_' + iter;
            String condLabel = 'Region';
            String condValue = 'Region_' + randomString(3);

            // Random action values
            String nextStageVal = 'Stage_' + randomString(4);
            String nextQueueVal = 'Queue_' + randomString(4);
            String availDecVal = 'Dec_' + randomString(4);
            String teamVal = 'Team_' + randomString(4);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('priority', 1);
            payload.put('tableKey', tableKeyIter);
            payload.put('code', 'P6_' + iter);

            List<Map<String, Object>> conditions = new List<Map<String, Object>>();
            // Condition row
            conditions.add(new Map<String, Object>{
                'type' => 'Condition', 'label' => condLabel,
                'value' => condValue, 'operator' => '=', 'order' => 1
            });
            // Action rows
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Next Stage',
                'value' => nextStageVal, 'operator' => null, 'order' => 2
            });
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Next Queue',
                'value' => nextQueueVal, 'operator' => null, 'order' => 3
            });
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Available Decisions',
                'value' => availDecVal, 'operator' => null, 'order' => 4
            });
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Team User Group',
                'value' => teamVal, 'operator' => null, 'order' => 5
            });
            payload.put('conditions', conditions);

            Test.startTest();
            FEC_StageTransitionEngine.saveRuleWithConditions(JSON.serialize(payload));

            // Evaluate with matching condition
            Map<String, String> fields = new Map<String, String>{ condLabel => condValue };
            Map<String, Object> result = FEC_StageTransitionEngine.testRuleEvaluation(null, fields, tableKeyIter);
            Test.stopTest();

            System.assertEquals(true, result.get('matched'),
                'Iteration ' + iter + ': rule should match');
            System.assertEquals(nextStageVal, result.get('nextStageName'),
                'Iteration ' + iter + ': nextStageName should come from Action row');
            System.assertEquals(nextQueueVal, result.get('nextQueue'),
                'Iteration ' + iter + ': nextQueue should come from Action row');
            System.assertEquals(availDecVal, result.get('availableDecisions'),
                'Iteration ' + iter + ': availableDecisions should come from Action row');
            System.assertEquals(teamVal, result.get('teamUserGroup'),
                'Iteration ' + iter + ': teamUserGroup should come from Action row');
        }
    }

    // ════════════════════════════════════════════════════════
    // Property 8: Backward Compatibility Fallback
    // ════════════════════════════════════════════════════════

    /**
     * Feature: generic-decision-table-wrapper, Property 8: Backward Compatibility Fallback
     *
     * For any rule during the transition period, if Decision_Condition rows exist for a
     * given label, the system SHALL use the Condition row values. Since old lookup fields
     * are not populated in test context, this verifies the Condition row path works correctly.
     *
     * Validates: Requirements 8.1, 8.2, 8.3
     */
    @IsTest
    static void property8_backwardCompatibilityFallback() {
        Integer iterations = 100;
        for (Integer iter = 0; iter < iterations; iter++) {
            String tableKeyIter = TABLE_KEY + '_P8_' + iter;
            String prevStageVal = 'PrevStage_' + randomString(4);
            String nextStageVal = 'NextStage_' + randomString(4);
            String nextQueueVal = 'Queue_' + randomString(4);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('priority', 1);
            payload.put('tableKey', tableKeyIter);
            payload.put('code', 'P8_' + iter);

            List<Map<String, Object>> conditions = new List<Map<String, Object>>();
            // Condition rows (these replace old lookup fields)
            conditions.add(new Map<String, Object>{
                'type' => 'Condition', 'label' => 'Previous Stage',
                'value' => prevStageVal, 'operator' => '=', 'order' => 1
            });
            // Action rows (these replace old lookup fields)
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Next Stage',
                'value' => nextStageVal, 'operator' => null, 'order' => 2
            });
            conditions.add(new Map<String, Object>{
                'type' => 'Action', 'label' => 'Next Queue',
                'value' => nextQueueVal, 'operator' => null, 'order' => 3
            });
            payload.put('conditions', conditions);

            Test.startTest();
            FEC_StageTransitionEngine.saveRuleWithConditions(JSON.serialize(payload));

            // Load and verify Condition row values are used (not lookup fallback)
            List<Map<String, Object>> loaded = FEC_StageTransitionEngine.getRulesWithConditions(null, tableKeyIter);
            Test.stopTest();

            System.assertEquals(1, loaded.size(),
                'Iteration ' + iter + ': expected 1 rule');

            Map<String, Object> rule = loaded[0];
            // Verify values come from Condition rows
            System.assertEquals(prevStageVal, rule.get('currentStage'),
                'Iteration ' + iter + ': currentStage should come from Condition row');
            System.assertEquals(nextStageVal, rule.get('nextStage'),
                'Iteration ' + iter + ': nextStage should come from Action row');
            System.assertEquals(nextQueueVal, rule.get('nextQueue'),
                'Iteration ' + iter + ': nextQueue should come from Action row');
        }
    }
}