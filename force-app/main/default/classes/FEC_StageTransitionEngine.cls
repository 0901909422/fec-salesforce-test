/**
 * @description Stage Transition Engine — runtime evaluation on Live layer.
 *              Queries FEC_Decision_Rule__c / FEC_Decision_Condition__c (Live objects).
 *              Replaces evaluateStageTransition / evaluateLiveStageTransition in FEC_MDM_WorkflowEngine.
 *
 *              Supports two modes:
 *              - evaluateAllTransitions: evaluate ALL action buttons at once → Map<ActionName, Result>
 *              - evaluateSingleTransition: evaluate ONE action button → Map<String, Object>
 *
 *              Integrates FEC_Stage_History__c for Revert logic.
 */
public with sharing class FEC_StageTransitionEngine {

    // ════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════

    public static final String TABLE_KEY_STAGE_TRANSITION = 'STAGE_TRANSITION';

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPER: QUERY RULES
    // ════════════════════════════════════════════════════════

    /**
     * Query active Decision Rules for a given table key, ordered by priority.
     * Filtering by Previous Stage / Action Button is now done via Condition rows.
     */
    private static List<FEC_Decision_Rule__c> queryRulesByTableKey(String tableKey) {
        return [
            SELECT  Id,
                    Name,
                    FEC_Priority__c
            FROM    FEC_Decision_Rule__c
            WHERE   FEC_Table_Key__c = :tableKey
            AND     FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPER: QUERY & GROUP CONDITIONS
    // ════════════════════════════════════════════════════════

    /**
     * Query all Decision Conditions for a set of rule IDs, grouped by Rule Id.
     */
    private static Map<Id, List<FEC_Decision_Condition__c>> queryConditionsForRules(Set<Id> ruleIds) {
        List<FEC_Decision_Condition__c> allConditions = [
            SELECT  Id,
                    FEC_Decision_Rule__c,
                    FEC_Type__c,
                    FEC_Label__c,
                    FEC_Operator__c,
                    FEC_Value__c,
                    FEC_Expression__c,
                    FEC_Order__c
            FROM    FEC_Decision_Condition__c
            WHERE   FEC_Decision_Rule__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];

        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule = new Map<Id, List<FEC_Decision_Condition__c>>();
        for (FEC_Decision_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Decision_Rule__c;
            if (!conditionsByRule.containsKey(ruleId)) {
                conditionsByRule.put(ruleId, new List<FEC_Decision_Condition__c>());
            }
            conditionsByRule.get(ruleId).add(cond);
        }
        return conditionsByRule;
    }

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPER: COLLECT FIELD API NAMES
    // ════════════════════════════════════════════════════════

    /**
     * Extract unique field API names from Condition-type rows via FEC_Label__c.
     * Skips Action rows and fixed labels (Previous Stage, Action Button) which are structural, not Case fields.
     */
    private static Set<String> collectFieldApiNames(List<FEC_Decision_Condition__c> conditions) {
        Set<String> FIXED_LABELS = new Set<String>{ 'Previous Stage', 'Current Stage', 'Action Button' };
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isNotBlank(label) && !FIXED_LABELS.contains(label)) {
                fieldApiNames.add(label);
            }
        }
        return fieldApiNames;
    }

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPER: QUERY CASE FIELDS
    // ════════════════════════════════════════════════════════

    private static Map<String, Object> queryCaseFields(Id caseId, Set<String> fieldApiNames) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        List<String> validFields = new List<String>();
        for (String fieldName : fieldApiNames) {
            if (caseFields.containsKey(fieldName.toLowerCase())) {
                validFields.add(fieldName);
            }
        }
        if (validFields.isEmpty()) {
            return new Map<String, Object>();
        }
        String fieldList = String.join(validFields, ', ');
        String soql = 'SELECT ' + fieldList + ' FROM Case WHERE Id = :caseId LIMIT 1';
        List<SObject> results = Database.query(soql);
        Map<String, Object> caseData = new Map<String, Object>();
        if (!results.isEmpty()) {
            SObject caseRecord = results[0];
            for (String fieldName : validFields) {
                Object val = caseRecord.get(fieldName);
                caseData.put(fieldName.toLowerCase(), val != null ? String.valueOf(val) : '');
            }
        }
        return caseData;
    }

    // ════════════════════════════════════════════════════════
    // EXPRESSION & CONDITION EVALUATION
    // ════════════════════════════════════════════════════════

    @TestVisible
    private static String applyExpression(String expression, String value) {
        if (value == null) value = '';
        if (String.isBlank(expression)) return value;
        String expr = expression.toUpperCase().trim();
        if (expr.startsWith('TRIM')) return value.trim();
        if (expr.startsWith('UPPER')) return value.toUpperCase();
        if (expr.startsWith('LOWER')) return value.toLowerCase();
        if (expr.startsWith('LENGTH')) return String.valueOf(value.length());
        if (expr.startsWith('LEFT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.left(n) : value;
        }
        if (expr.startsWith('RIGHT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.right(n) : value;
        }
        return value;
    }

    private static Integer extractNumber(String expression) {
        if (String.isBlank(expression)) return null;
        Pattern p = Pattern.compile('\\,\\s*(\\d+)\\s*\\)');
        Matcher m = p.matcher(expression);
        if (m.find()) {
            try { return Integer.valueOf(m.group(1)); } catch (Exception e) { return null; }
        }
        return null;
    }

    @TestVisible
    private static Boolean evaluateCondition(String actualValue, String operator, String conditionValue, String expression) {
        String processedValue = actualValue != null ? actualValue : '';
        if (String.isNotBlank(expression) && expression != 'RANGE_START' && expression != 'RANGE_END') {
            processedValue = applyExpression(expression, processedValue);
        }
        if (String.isBlank(operator)) return processedValue == conditionValue;
        switch on operator {
            when '=' { return processedValue == conditionValue; }
            when '!=' { return processedValue != conditionValue; }
            when '>' { return compareNumeric(processedValue, conditionValue) > 0; }
            when '<' { return compareNumeric(processedValue, conditionValue) < 0; }
            when '>=' { return compareNumeric(processedValue, conditionValue) >= 0; }
            when '<=' { return compareNumeric(processedValue, conditionValue) <= 0; }
            when 'IN' { return isInList(processedValue, conditionValue); }
            when 'NOT IN' { return !isInList(processedValue, conditionValue); }
            when 'Contains' { return processedValue != null && conditionValue != null && processedValue.containsIgnoreCase(conditionValue); }
            when 'Starts With' { return processedValue != null && conditionValue != null && processedValue.startsWithIgnoreCase(conditionValue); }
            when 'Ends With' { return processedValue != null && conditionValue != null && processedValue.endsWithIgnoreCase(conditionValue); }
            when 'BETWEEN' { return evaluateBetween(processedValue, conditionValue); }
            when else { return processedValue == conditionValue; }
        }
    }

    private static Integer compareNumeric(String val1, String val2) {
        try {
            Decimal d1 = Decimal.valueOf(val1.trim());
            Decimal d2 = Decimal.valueOf(val2.trim());
            if (d1 > d2) return 1;
            if (d1 < d2) return -1;
            return 0;
        } catch (Exception e) {
            String s1 = val1 != null ? val1 : '';
            String s2 = val2 != null ? val2 : '';
            if (s1 > s2) return 1;
            if (s1 < s2) return -1;
            return 0;
        }
    }

    private static Boolean isInList(String value, String commaSeparatedList) {
        if (String.isBlank(commaSeparatedList)) return false;
        String lowerValue = (value != null ? value.trim().toLowerCase() : '');
        for (String item : commaSeparatedList.split(',')) {
            if (item.trim().toLowerCase() == lowerValue) return true;
        }
        return false;
    }

    private static Boolean evaluateBetween(String actualValue, String rangeValue) {
        if (String.isBlank(rangeValue) || String.isBlank(actualValue)) return false;
        try {
            List<String> parts = rangeValue.split(',');
            if (parts.size() != 2) return false;
            String startPart = parts[0].trim();
            String endPart = parts[1].trim();
            String startOp; Decimal startVal;
            if (startPart.startsWith('>=')) { startOp = '>='; startVal = Decimal.valueOf(startPart.substring(2).trim()); }
            else if (startPart.startsWith('>')) { startOp = '>'; startVal = Decimal.valueOf(startPart.substring(1).trim()); }
            else { startOp = '>='; startVal = Decimal.valueOf(startPart); }
            String endOp; Decimal endVal;
            if (endPart.startsWith('<=')) { endOp = '<='; endVal = Decimal.valueOf(endPart.substring(2).trim()); }
            else if (endPart.startsWith('<')) { endOp = '<'; endVal = Decimal.valueOf(endPart.substring(1).trim()); }
            else { endOp = '<='; endVal = Decimal.valueOf(endPart); }
            Decimal actual = Decimal.valueOf(actualValue.trim());
            Boolean startOk = (startOp == '>=') ? actual >= startVal : actual > startVal;
            Boolean endOk = (endOp == '<=') ? actual <= endVal : actual < endVal;
            return startOk && endOk;
        } catch (Exception e) { return false; }
    }

    private static Boolean evaluateRuleConditions(List<FEC_Decision_Condition__c> conditions, Map<String, Object> caseData) {
        Set<String> FIXED_LABELS = new Set<String>{ 'Previous Stage', 'Current Stage', 'Action Button' };
        // Group Condition-type rows by Label (skip Action rows and fixed labels)
        Map<String, List<FEC_Decision_Condition__c>> conditionsByLabel = new Map<String, List<FEC_Decision_Condition__c>>();
        for (FEC_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isBlank(label) || FIXED_LABELS.contains(label)) continue;
            if (!conditionsByLabel.containsKey(label)) {
                conditionsByLabel.put(label, new List<FEC_Decision_Condition__c>());
            }
            conditionsByLabel.get(label).add(cond);
        }
        // Evaluate: AND across labels, OR within same label
        for (String label : conditionsByLabel.keySet()) {
            List<FEC_Decision_Condition__c> labelConds = conditionsByLabel.get(label);
            Boolean groupMatched = false;
            for (FEC_Decision_Condition__c cond : labelConds) {
                String actualValue = '';
                Object val = caseData.get(label.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
                if (evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c)) {
                    groupMatched = true;
                    break;
                }
            }
            if (!groupMatched) return false;
        }
        return true;
    }

    // ════════════════════════════════════════════════════════
    // BUILD MATCH RESULT
    // ════════════════════════════════════════════════════════

    /**
     * Build match result from Action-type Condition rows.
     * Reads Action rows by Label to populate Next Stage, Next Queue, Available Decisions, etc.
     */
    private static Map<String, Object> buildMatchResult(Id ruleId, String ruleName, List<FEC_Decision_Condition__c> ruleConditions) {
        Map<String, Object> result = new Map<String, Object>{
            'ruleId'   => ruleId
        };
        // Extract values from Action-type rows by Label
        if (ruleConditions != null) {
            for (FEC_Decision_Condition__c cond : ruleConditions) {
                if (cond.FEC_Type__c != 'Action') continue;
                String label = cond.FEC_Label__c;
                String value = cond.FEC_Value__c;
                if (label == 'Next Stage') {
                    result.put('nextStageName', value);
                } else if (label == 'Next Queue') {
                    result.put('nextQueue', value);
                } else if (label == 'Available Decisions') {
                    result.put('availableDecisions', value);
                } else if (label == 'Team User Group') {
                    result.put('teamUserGroup', value);
                } else if (label == 'Action Button') {
                    result.put('actionButtonName', value);
                }
            }
        }
        return result;
    }

    // ════════════════════════════════════════════════════════
    // STAGE HISTORY & REVERT
    // ════════════════════════════════════════════════════════

    public static void insertStageHistory(Id caseId, Id fromStageId, Id toStageId, Id actionButtonId, String queue) {
        FEC_Stage_History__c history = new FEC_Stage_History__c(
            FEC_Case__c = caseId,
            FEC_From_Stage__c = fromStageId,
            FEC_To_Stage__c = toStageId,
            FEC_Action_Button__c = actionButtonId,
            FEC_Performed_By__c = UserInfo.getUserId(),
            FEC_Queue__c = queue,
            FEC_Timestamp__c = DateTime.now()
        );
        insert history;
    }

    private static Map<String, Object> getRevertInfo(Id caseId, Id currentStageId) {
        List<FEC_Stage_History__c> historyList = [
            SELECT FEC_From_Stage__c, FEC_From_Stage__r.Name, FEC_Queue__c
            FROM FEC_Stage_History__c
            WHERE FEC_Case__c = :caseId
              AND FEC_To_Stage__c = :currentStageId
            ORDER BY FEC_Timestamp__c DESC
            LIMIT 1
        ];
        if (historyList.isEmpty()) return null;
        FEC_Stage_History__c h = historyList[0];
        return new Map<String, Object>{
            'nextStageId'   => h.FEC_From_Stage__c,
            'nextStageName' => h.FEC_From_Stage__r?.Name,
            'queueId'       => h.FEC_Queue__c
        };
    }

    // ════════════════════════════════════════════════════════
    // PUBLIC: EVALUATE ALL TRANSITIONS
    // ════════════════════════════════════════════════════════

    /**
     * @description Evaluate stage transitions.
     *              actionLabel = null → lấy tất cả action khả dụng
     *              actionLabel = "Submit" → chỉ lấy 1 action cụ thể
     *              isEvaluateAll = true → trả TẤT CẢ rules mỗi group (cả matched lẫn unmatched)
     *              isEvaluateAll = false → First Match Wins, chỉ trả rule đầu tiên match
     */
    @AuraEnabled
    public static Map<String, Map<String, Object>> getDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        return doGetDecisionTableResults(caseId, currentStageId, TABLE_KEY_STAGE_TRANSITION, actionLabel, isEvaluateAll == true);
    }

    /**
     * Helper: get the "Available Decisions" value from a rule's Action rows.
     */
    private static String getActionValueByLabel(List<FEC_Decision_Condition__c> ruleConditions, String targetLabel) {
        if (ruleConditions == null) return null;
        for (FEC_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Action' && cond.FEC_Label__c == targetLabel) {
                return cond.FEC_Value__c;
            }
        }
        return null;
    }

    /**
     * Helper: check if a rule has a Condition row with a given Label matching a given value.
     */
    private static Boolean hasConditionRowMatching(List<FEC_Decision_Condition__c> ruleConditions, String targetLabel, String expectedValue) {
        if (ruleConditions == null || ruleConditions.isEmpty()) return false;
        for (FEC_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Condition' && cond.FEC_Label__c == targetLabel && cond.FEC_Value__c == expectedValue) {
                return true;
            }
        }
        return false;
    }

    private static Map<String, Map<String, Object>> doGetDecisionTableResults(Id caseId, Id currentStageId, String tableKey, String actionLabel, Boolean isEvaluateAll) {
        try {
            if (caseId == null || currentStageId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (String.isBlank(tableKey)) tableKey = TABLE_KEY_STAGE_TRANSITION;

            // Query current stage name for Previous Stage filtering
            String currentStageName = '';
            List<FEC_Case_Stage__c> stages = [SELECT Name FROM FEC_Case_Stage__c WHERE Id = :currentStageId LIMIT 1];
            if (!stages.isEmpty()) currentStageName = stages[0].Name;

            List<FEC_Decision_Rule__c> allRules = queryRulesByTableKey(tableKey);
            if (allRules.isEmpty()) {
                Map<String, Map<String, Object>> emptyResult = new Map<String, Map<String, Object>>();
                Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
                if (revertInfo != null) emptyResult.put('Revert', revertInfo);
                return emptyResult;
            }

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Decision_Rule__c r : allRules) ruleIds.add(r.Id);

            Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule = queryConditionsForRules(ruleIds);

            // Filter rules by "Previous Stage" or "Current Stage" Condition row matching current stage name
            List<FEC_Decision_Rule__c> rules = new List<FEC_Decision_Rule__c>();
            for (FEC_Decision_Rule__c rule : allRules) {
                List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                if (hasConditionRowMatching(ruleConds, 'Previous Stage', currentStageName)
                    || hasConditionRowMatching(ruleConds, 'Current Stage', currentStageName)) {
                    rules.add(rule);
                }
            }
            if (rules.isEmpty()) {
                Map<String, Map<String, Object>> emptyResult = new Map<String, Map<String, Object>>();
                Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
                if (revertInfo != null) emptyResult.put('Revert', revertInfo);
                return emptyResult;
            }

            // Collect all field API names and query Case data once
            List<FEC_Decision_Condition__c> allConds = new List<FEC_Decision_Condition__c>();
            for (FEC_Decision_Rule__c rule : rules) {
                List<FEC_Decision_Condition__c> conds = conditionsByRule.get(rule.Id);
                if (conds != null) allConds.addAll(conds);
            }
            Set<String> fieldApiNames = collectFieldApiNames(allConds);
            Map<String, Object> caseData = new Map<String, Object>();
            if (!fieldApiNames.isEmpty()) caseData = queryCaseFields(caseId, fieldApiNames);

            // Group rules by "Available Decisions" from Action rows
            Map<String, List<FEC_Decision_Rule__c>> rulesByDecisionLabel = new Map<String, List<FEC_Decision_Rule__c>>();
            for (FEC_Decision_Rule__c rule : rules) {
                List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                String decisionLabel = getActionValueByLabel(ruleConds, 'Available Decisions');
                if (String.isBlank(decisionLabel)) continue;
                // Filter by actionLabel if provided
                if (String.isNotBlank(actionLabel) && !decisionLabel.equals(actionLabel)) continue;
                if (!rulesByDecisionLabel.containsKey(decisionLabel)) {
                    rulesByDecisionLabel.put(decisionLabel, new List<FEC_Decision_Rule__c>());
                }
                rulesByDecisionLabel.get(decisionLabel).add(rule);
            }

            // Evaluate per group
            Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();
            for (String label : rulesByDecisionLabel.keySet()) {
                Boolean foundMatch = false;
                List<Map<String, Object>> allRuleResults = new List<Map<String, Object>>();
                for (FEC_Decision_Rule__c rule : rulesByDecisionLabel.get(label)) {
                    List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                    Boolean isMatch = (ruleConds == null || ruleConds.isEmpty()) || evaluateRuleConditions(ruleConds, caseData);

                    if (isEvaluateAll) {
                        // All mode: collect every rule
                        Map<String, Object> ruleResult = buildMatchResult(rule.Id, rule.Name, ruleConds);
                        allRuleResults.add(ruleResult);
                    } else {
                        // Normal mode: First Match Wins
                        if (isMatch) {
                            result.put(label, buildMatchResult(rule.Id, rule.Name, ruleConds));
                            foundMatch = true;
                            break;
                        }
                    }
                }
                if (isEvaluateAll && !allRuleResults.isEmpty()) {
                    Map<String, Object> entry = (Map<String, Object>) allRuleResults[0].clone();
                    if (allRuleResults.size() > 1) {
                        entry.put('rules', allRuleResults);
                    }
                    result.put(label, entry);
                }
            }

            // Add Revert info
            Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
            if (revertInfo != null) result.put('Revert', revertInfo);

            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // PUBLIC: EVALUATE SINGLE TRANSITION
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Object> evaluateSingleTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        return evaluateSingleTransitionWithKey(caseId, currentStageId, actionButtonId, TABLE_KEY_STAGE_TRANSITION);
    }

    @AuraEnabled
    public static Map<String, Object> evaluateSingleTransitionWithKey(Id caseId, Id currentStageId, Id actionButtonId, String tableKey) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (String.isBlank(tableKey)) tableKey = TABLE_KEY_STAGE_TRANSITION;

            // Query current stage name for Previous Stage filtering
            String currentStageName = '';
            List<FEC_Case_Stage__c> stages = [SELECT Name FROM FEC_Case_Stage__c WHERE Id = :currentStageId LIMIT 1];
            if (!stages.isEmpty()) currentStageName = stages[0].Name;

            // Query action button name for Action Button filtering
            String actionButtonName = '';
            List<FEC_Action_Button__c> buttons = [SELECT Name FROM FEC_Action_Button__c WHERE Id = :actionButtonId LIMIT 1];
            if (!buttons.isEmpty()) actionButtonName = buttons[0].Name;

            List<FEC_Decision_Rule__c> allRules = queryRulesByTableKey(tableKey);
            if (allRules.isEmpty()) {
                return new Map<String, Object>{ 'matched' => false, 'message' => System.Label.FEC_Error_NoRuleMatched };
            }

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Decision_Rule__c r : allRules) ruleIds.add(r.Id);

            Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule = queryConditionsForRules(ruleIds);

            // Filter rules by "Previous Stage"/"Current Stage" and "Action Button" Condition rows
            List<FEC_Decision_Rule__c> rules = new List<FEC_Decision_Rule__c>();
            for (FEC_Decision_Rule__c rule : allRules) {
                List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                if ((hasConditionRowMatching(ruleConds, 'Previous Stage', currentStageName)
                    || hasConditionRowMatching(ruleConds, 'Current Stage', currentStageName))
                    && hasConditionRowMatching(ruleConds, 'Action Button', actionButtonName)) {
                    rules.add(rule);
                }
            }
            if (rules.isEmpty()) {
                return new Map<String, Object>{ 'matched' => false, 'message' => System.Label.FEC_Error_NoRuleMatched };
            }

            List<FEC_Decision_Condition__c> allConds = new List<FEC_Decision_Condition__c>();
            for (FEC_Decision_Rule__c rule : rules) {
                List<FEC_Decision_Condition__c> conds = conditionsByRule.get(rule.Id);
                if (conds != null) allConds.addAll(conds);
            }
            Set<String> fieldApiNames = collectFieldApiNames(allConds);
            Map<String, Object> caseData = new Map<String, Object>();
            if (!fieldApiNames.isEmpty()) caseData = queryCaseFields(caseId, fieldApiNames);

            for (FEC_Decision_Rule__c rule : rules) {
                List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                if (ruleConds == null || ruleConds.isEmpty()) return buildMatchResult(rule.Id, rule.Name, ruleConds);
                if (evaluateRuleConditions(ruleConds, caseData)) return buildMatchResult(rule.Id, rule.Name, ruleConds);
            }

            return new Map<String, Object>{ 'matched' => false, 'message' => System.Label.FEC_Error_NoRuleMatched };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // MDM PRIVATE HELPERS (consolidated from FEC_DecisionEngineController)
    // ════════════════════════════════════════════════════════

    private static Map<String, Object> buildMatchResultFromConditions(Id ruleId, String ruleName, List<FEC_MDM_Decision_Condition__c> ruleConds) {
        String nextStageName = null;
        String nextQueue = null;
        String teamUserGroup = null;
        String availableDecisions = null;

        if (ruleConds != null) {
            for (FEC_MDM_Decision_Condition__c cond : ruleConds) {
                String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
                if (condType != 'Action') continue;
                String condLabel = cond.FEC_Label__c;
                if (condLabel == 'Next Stage') {
                    nextStageName = cond.FEC_Value__c;
                } else if (condLabel == 'Next Queue') {
                    nextQueue = cond.FEC_Value__c;
                } else if (condLabel == 'Team User Group') {
                    teamUserGroup = cond.FEC_Value__c;
                } else if (condLabel == 'Available Decisions') {
                    availableDecisions = cond.FEC_Value__c;
                }
            }
        }

        return new Map<String, Object>{
            'ruleId'             => ruleId,
            'nextStageName'      => nextStageName,
            'nextQueue'          => nextQueue,
            'teamUserGroup'      => teamUserGroup,
            'availableDecisions' => availableDecisions
        };
    }

    private static Boolean evaluateConditionsWithTrace(
        List<FEC_MDM_Decision_Condition__c> conditions,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        // Group by Label instead of MDS Id — only Condition-type rows should be passed in
        Map<String, List<FEC_MDM_Decision_Condition__c>> byLabel = new Map<String, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c c : conditions) {
            String condType = c.FEC_Type__c != null ? c.FEC_Type__c : 'Condition';
            if (condType != 'Condition') continue;
            String label = c.FEC_Label__c;
            if (String.isBlank(label)) continue;
            if (!byLabel.containsKey(label)) {
                byLabel.put(label, new List<FEC_MDM_Decision_Condition__c>());
            }
            byLabel.get(label).add(c);
        }

        Boolean allGroupsMatch = true;

        for (String label : byLabel.keySet()) {
            List<FEC_MDM_Decision_Condition__c> labelConds = byLabel.get(label);
            Boolean groupMatched = false;

            for (FEC_MDM_Decision_Condition__c cond : labelConds) {
                // Use Label as the field API name for lookup in fieldValues
                String apiName = cond.FEC_Label__c;
                String actualValue = '';
                if (String.isNotBlank(apiName)) {
                    Object val = fieldValues.get(apiName.toLowerCase());
                    actualValue = val != null ? String.valueOf(val) : '';
                }

                Boolean condResult = evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c);

                condTrace.add(new Map<String, Object>{
                    'fieldLabel'    => cond.FEC_Label__c,
                    'fieldApiName'  => apiName,
                    'operator'      => cond.FEC_Operator__c,
                    'expectedValue' => cond.FEC_Value__c,
                    'actualValue'   => actualValue,
                    'expression'    => cond.FEC_Expression__c,
                    'result'        => condResult
                });

                if (condResult) {
                    groupMatched = true;
                }
            }

            if (!groupMatched) {
                allGroupsMatch = false;
            }
        }

        return allGroupsMatch;
    }

    private static String resolveFieldDataType(String objectName, String fieldApiName) {
        if (String.isBlank(objectName) || String.isBlank(fieldApiName)) return 'Text';
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) return 'Text';
            Schema.SObjectField field = objType.getDescribe().fields.getMap().get(fieldApiName.toLowerCase());
            if (field == null) return 'Text';
            Schema.DisplayType dt = field.getDescribe().getType();
            switch on dt {
                when STRING, TEXTAREA, URL, EMAIL, PHONE, ID, ENCRYPTEDSTRING {
                    return 'Text';
                }
                when INTEGER, DOUBLE, CURRENCY, PERCENT, LONG {
                    return 'Number';
                }
                when BOOLEAN {
                    return 'Boolean';
                }
                when PICKLIST, MULTIPICKLIST {
                    return 'Picklist';
                }
                when DATE {
                    return 'Date';
                }
                when DATETIME {
                    return 'DateTime';
                }
                when TIME {
                    return 'Time';
                }
                when REFERENCE {
                    return 'Reference';
                }
                when else {
                    return 'Text';
                }
            }
        } catch (Exception e) {
            return 'Text';
        }
    }


    // ════════════════════════════════════════════════════════
    // MDM EVALUATION (queries FEC_MDM_Decision_Rule__c / FEC_MDM_Decision_Condition__c)
    // ════════════════════════════════════════════════════════

    /**
     * Query active MDM Decision Rules for a given table key, ordered by priority.
     */
    private static List<FEC_MDM_Decision_Rule__c> queryMDMRulesByTableKey(String tableKey) {
        return [
            SELECT  Id,
                    Name,
                    FEC_Priority__c
            FROM    FEC_MDM_Decision_Rule__c
            WHERE   FEC_Table_Key__c = :tableKey
            AND     FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    /**
     * Query all MDM Decision Conditions for a set of rule IDs, grouped by Rule Id.
     */
    private static Map<Id, List<FEC_MDM_Decision_Condition__c>> queryMDMConditionsForRules(Set<Id> ruleIds) {
        List<FEC_MDM_Decision_Condition__c> allConditions = [
            SELECT  Id,
                    FEC_Decision_Rule__c,
                    FEC_Type__c,
                    FEC_Label__c,
                    FEC_Operator__c,
                    FEC_Value__c,
                    FEC_Expression__c,
                    FEC_Order__c
            FROM    FEC_MDM_Decision_Condition__c
            WHERE   FEC_Decision_Rule__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];

        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Decision_Rule__c;
            if (!conditionsByRule.containsKey(ruleId)) {
                conditionsByRule.put(ruleId, new List<FEC_MDM_Decision_Condition__c>());
            }
            conditionsByRule.get(ruleId).add(cond);
        }
        return conditionsByRule;
    }

    /**
     * Evaluate MDM conditions using the same AND-across-labels, OR-within-label logic as evaluateRuleConditions.
     */
    private static Boolean evaluateMDMRuleConditions(List<FEC_MDM_Decision_Condition__c> conditions, Map<String, Object> caseData) {
        Set<String> FIXED_LABELS = new Set<String>{ 'Previous Stage', 'Current Stage', 'Action Button' };
        Map<String, List<FEC_MDM_Decision_Condition__c>> conditionsByLabel = new Map<String, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isBlank(label) || FIXED_LABELS.contains(label)) continue;
            if (!conditionsByLabel.containsKey(label)) {
                conditionsByLabel.put(label, new List<FEC_MDM_Decision_Condition__c>());
            }
            conditionsByLabel.get(label).add(cond);
        }
        for (String label : conditionsByLabel.keySet()) {
            List<FEC_MDM_Decision_Condition__c> labelConds = conditionsByLabel.get(label);
            Boolean groupMatched = false;
            for (FEC_MDM_Decision_Condition__c cond : labelConds) {
                String actualValue = '';
                Object val = caseData.get(label.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
                if (evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c)) {
                    groupMatched = true;
                    break;
                }
            }
            if (!groupMatched) return false;
        }
        return true;
    }

    /**
     * Extract unique field API names from MDM Condition-type rows via FEC_Label__c.
     */
    private static Set<String> collectMDMFieldApiNames(List<FEC_MDM_Decision_Condition__c> conditions) {
        Set<String> FIXED_LABELS = new Set<String>{ 'Previous Stage', 'Current Stage', 'Action Button' };
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_MDM_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isNotBlank(label) && !FIXED_LABELS.contains(label)) {
                fieldApiNames.add(label);
            }
        }
        return fieldApiNames;
    }

    /**
     * Check if an MDM rule has a Condition row with a given Label matching a given value.
     */
    private static Boolean hasMDMConditionRowMatching(List<FEC_MDM_Decision_Condition__c> ruleConditions, String targetLabel, String expectedValue) {
        if (ruleConditions == null || ruleConditions.isEmpty()) return false;
        for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Condition' && cond.FEC_Label__c == targetLabel && cond.FEC_Value__c == expectedValue) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get the value of an Action row by label from MDM conditions.
     */
    private static String getMDMActionValueByLabel(List<FEC_MDM_Decision_Condition__c> ruleConditions, String targetLabel) {
        if (ruleConditions == null) return null;
        for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Action' && cond.FEC_Label__c == targetLabel) {
                return cond.FEC_Value__c;
            }
        }
        return null;
    }

    /**
     * Orchestrate MDM evaluation — mirrors doGetDecisionTableResults but uses MDM query helpers and MDM wrappers.
     */
    private static Map<String, Map<String, Object>> doGetMDMDecisionTableResults(Id caseId, Id currentStageId, String tableKey, String actionLabel, Boolean isEvaluateAll) {
        try {
            if (caseId == null || currentStageId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (String.isBlank(tableKey)) tableKey = TABLE_KEY_STAGE_TRANSITION;

            // Query current stage name for Previous Stage filtering
            String currentStageName = '';
            List<FEC_Case_Stage__c> stages = [SELECT Name FROM FEC_Case_Stage__c WHERE Id = :currentStageId LIMIT 1];
            if (!stages.isEmpty()) currentStageName = stages[0].Name;

            List<FEC_MDM_Decision_Rule__c> allRules = queryMDMRulesByTableKey(tableKey);
            if (allRules.isEmpty()) {
                Map<String, Map<String, Object>> emptyResult = new Map<String, Map<String, Object>>();
                Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
                if (revertInfo != null) emptyResult.put('Revert', revertInfo);
                return emptyResult;
            }

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Decision_Rule__c r : allRules) ruleIds.add(r.Id);

            Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = queryMDMConditionsForRules(ruleIds);

            // Filter rules by "Previous Stage" or "Current Stage" Condition row matching current stage name
            List<FEC_MDM_Decision_Rule__c> rules = new List<FEC_MDM_Decision_Rule__c>();
            for (FEC_MDM_Decision_Rule__c rule : allRules) {
                List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                if (hasMDMConditionRowMatching(ruleConds, 'Previous Stage', currentStageName)
                    || hasMDMConditionRowMatching(ruleConds, 'Current Stage', currentStageName)) {
                    rules.add(rule);
                }
            }
            if (rules.isEmpty()) {
                Map<String, Map<String, Object>> emptyResult = new Map<String, Map<String, Object>>();
                Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
                if (revertInfo != null) emptyResult.put('Revert', revertInfo);
                return emptyResult;
            }

            // Collect all field API names and query Case data once
            List<FEC_MDM_Decision_Condition__c> allConds = new List<FEC_MDM_Decision_Condition__c>();
            for (FEC_MDM_Decision_Rule__c rule : rules) {
                List<FEC_MDM_Decision_Condition__c> conds = conditionsByRule.get(rule.Id);
                if (conds != null) allConds.addAll(conds);
            }
            Set<String> fieldApiNames = collectMDMFieldApiNames(allConds);
            Map<String, Object> caseData = new Map<String, Object>();
            if (!fieldApiNames.isEmpty()) caseData = queryCaseFields(caseId, fieldApiNames);

            // Group rules by "Available Decisions" from Action rows
            Map<String, List<FEC_MDM_Decision_Rule__c>> rulesByDecisionLabel = new Map<String, List<FEC_MDM_Decision_Rule__c>>();
            for (FEC_MDM_Decision_Rule__c rule : rules) {
                List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                String decisionLabel = getMDMActionValueByLabel(ruleConds, 'Available Decisions');
                if (String.isBlank(decisionLabel)) continue;
                // Filter by actionLabel if provided
                if (String.isNotBlank(actionLabel) && !decisionLabel.equals(actionLabel)) continue;
                if (!rulesByDecisionLabel.containsKey(decisionLabel)) {
                    rulesByDecisionLabel.put(decisionLabel, new List<FEC_MDM_Decision_Rule__c>());
                }
                rulesByDecisionLabel.get(decisionLabel).add(rule);
            }

            // Evaluate per group
            Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();
            for (String label : rulesByDecisionLabel.keySet()) {
                List<Map<String, Object>> allRuleResults = new List<Map<String, Object>>();
                for (FEC_MDM_Decision_Rule__c rule : rulesByDecisionLabel.get(label)) {
                    List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                    Boolean isMatch = (ruleConds == null || ruleConds.isEmpty()) || evaluateMDMRuleConditions(ruleConds, caseData);

                    if (isEvaluateAll) {
                        Map<String, Object> ruleResult = buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
                        allRuleResults.add(ruleResult);
                    } else {
                        // Normal mode: First Match Wins
                        if (isMatch) {
                            result.put(label, buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds));
                            break;
                        }
                    }
                }
                if (isEvaluateAll && !allRuleResults.isEmpty()) {
                    Map<String, Object> entry = (Map<String, Object>) allRuleResults[0].clone();
                    if (allRuleResults.size() > 1) {
                        entry.put('rules', allRuleResults);
                    }
                    result.put(label, entry);
                }
            }

            // Add Revert info
            Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
            if (revertInfo != null) result.put('Revert', revertInfo);

            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Map<String, Object>> getMDMDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        return doGetMDMDecisionTableResults(caseId, currentStageId, TABLE_KEY_STAGE_TRANSITION, actionLabel, isEvaluateAll == true);
    }

    // ════════════════════════════════════════════════════════
    // MDM CRUD METHODS (consolidated from FEC_DecisionEngineController)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId, String tableKey) {
        String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
        List<FEC_MDM_Decision_Rule__c> rules;
        if (String.isNotBlank(keyId)) {
            rules = [
                SELECT  Id, Name, FEC_Priority__c, FEC_Active__c, FEC_Table_Key__c, FEC_Code__c, FEC_Key_ID__c
                FROM    FEC_MDM_Decision_Rule__c
                WHERE   FEC_Table_Key__c = :tableKey
                AND     FEC_Active__c = true
                AND     FEC_Key_ID__c = :keyId
                ORDER BY FEC_Priority__c ASC NULLS LAST
            ];
        } else {
            rules = [
                SELECT  Id, Name, FEC_Priority__c, FEC_Active__c, FEC_Table_Key__c, FEC_Code__c, FEC_Key_ID__c
                FROM    FEC_MDM_Decision_Rule__c
                WHERE   FEC_Table_Key__c = :tableKey
                AND     FEC_Active__c = true
                ORDER BY FEC_Priority__c ASC NULLS LAST
            ];
        }

        Set<Id> ruleIds = new Set<Id>();
        for (FEC_MDM_Decision_Rule__c rule : rules) {
            ruleIds.add(rule.Id);
        }

        List<FEC_MDM_Decision_Condition__c> allConditions = [
            SELECT  Id,
                    Name,
                    FEC_Decision_Rule__c,
                    FEC_Operator__c,
                    FEC_Value__c,
                    FEC_Expression__c,
                    FEC_Order__c,
                    FEC_Type__c,
                    FEC_Label__c
            FROM    FEC_MDM_Decision_Condition__c
            WHERE   FEC_Decision_Rule__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];

        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Decision_Rule__c;
            if (!conditionsByRule.containsKey(ruleId)) {
                conditionsByRule.put(ruleId, new List<FEC_MDM_Decision_Condition__c>());
            }
            conditionsByRule.get(ruleId).add(cond);
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (FEC_MDM_Decision_Rule__c rule : rules) {
            List<Map<String, Object>> condList = new List<Map<String, Object>>();
            List<FEC_MDM_Decision_Condition__c> ruleConditions = conditionsByRule.get(rule.Id);

            // Build lookup maps from Condition rows by Type + Label
            String currentStageVal = null;
            String actionVal = null;
            String nextStageVal = null;
            String nextQueueVal = null;
            String teamUserGroupVal = null;
            String availableDecisionsVal = null;
            String processChangeStatusVal = null;
            String customActionsVal = null;

            if (ruleConditions != null) {
                for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
                    String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
                    String condLabel = cond.FEC_Label__c;

                    // Extract known labels into rule-level fields
                    if (condType == 'Condition' && condLabel == 'Previous Stage') {
                        currentStageVal = cond.FEC_Value__c;
                    } else if (condType == 'Condition' && condLabel == 'Action Button') {
                        actionVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Next Stage') {
                        nextStageVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Next Queue') {
                        nextQueueVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Team User Group') {
                        teamUserGroupVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Available Decisions') {
                        availableDecisionsVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Process Change Status') {
                        processChangeStatusVal = cond.FEC_Value__c;
                    } else if (condType == 'Action' && condLabel == 'Custom Actions') {
                        customActionsVal = cond.FEC_Value__c;
                    }

                    condList.add(new Map<String, Object>{
                        'id'            => cond.Id,
                        'conditionName' => cond.Name,
                        'fieldName'     => cond.FEC_Label__c,
                        'fieldApiName'  => cond.FEC_Label__c,
                        'fieldType'     => 'Text',
                        'operator'      => cond.FEC_Operator__c,
                        'value'         => cond.FEC_Value__c,
                        'expression'    => cond.FEC_Expression__c,
                        'order'         => cond.FEC_Order__c,
                        'type'          => condType,
                        'label'         => cond.FEC_Label__c
                    });
                }
            }

            result.add(new Map<String, Object>{
                'rowId'               => rule.Id,
                'currentStage'        => currentStageVal,
                'action'              => actionVal,
                'nextStage'           => nextStageVal,
                'nextQueue'           => nextQueueVal,
                'teamUserGroup'       => teamUserGroupVal,
                'priority'            => rule.FEC_Priority__c,
                'active'              => rule.FEC_Active__c,
                'tableKey'            => rule.FEC_Table_Key__c,
                'availableDecisions'  => availableDecisionsVal,
                'customActions'       => customActionsVal,
                'processChangeStatus' => processChangeStatusVal,
                'conditions'          => condList
            });
        }

        return result;
    }


    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDecisionTableData(Id businessProcessId, String tableKey) {
        List<Map<String, Object>> rules = getRulesWithConditions(businessProcessId, tableKey);

        // ALL condition labels are returned as columns (no fixed labels exclusion)
        Map<String, Map<String, Object>> columnMap = new Map<String, Map<String, Object>>();
        for (Map<String, Object> rule : rules) {
            List<Object> conditions = (List<Object>) rule.get('conditions');
            if (conditions != null) {
                for (Object condObj : conditions) {
                    Map<String, Object> cond = (Map<String, Object>) condObj;
                    String condType = (String) cond.get('type');
                    String label = (String) cond.get('label');
                    if (condType == 'Condition'
                        && String.isNotBlank(label)
                        && !columnMap.containsKey(label)) {
                        columnMap.put(label, new Map<String, Object>{
                            'fieldName'    => label,
                            'fieldApiName' => label,
                            'dataType'     => 'Text'
                        });
                    }
                }
            }
        }

        return new Map<String, Object>{
            'conditionColumns' => columnMap.values(),
            'rules'            => rules
        };
    }


    @AuraEnabled
    public static String saveRuleWithConditions(String ruleData) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ruleData);

            FEC_MDM_Decision_Rule__c rule = new FEC_MDM_Decision_Rule__c();
            if (payload.get('recordId') != null && String.valueOf(payload.get('recordId')) != 'null') {
                rule.Id = (Id) payload.get('recordId');
            }
            rule.FEC_Priority__c        = payload.get('priority') != null
                                          ? Decimal.valueOf(String.valueOf(payload.get('priority'))) : 1;
            rule.FEC_Active__c          = true;

            // Set Table Key from payload
            String tableKeyVal = (String) payload.get('tableKey');
            if (String.isNotBlank(tableKeyVal)) {
                rule.FEC_Table_Key__c = tableKeyVal;
            }

            // Set Code from payload
            if (payload.containsKey('code')) {
                rule.FEC_Code__c = (String) payload.get('code');
            }

            // Set Key ID from payload (e.g., Business Process ID for context filtering)
            if (payload.containsKey('keyId')) {
                rule.FEC_Key_ID__c = (String) payload.get('keyId');
            }

            upsert rule;

            // ── Handle conditions ──
            List<Object> conditionsRaw = (List<Object>) payload.get('conditions');
            if (conditionsRaw == null) conditionsRaw = new List<Object>();

            Set<Id> keepIds = new Set<Id>();
            List<FEC_MDM_Decision_Condition__c> conditionsToUpsert = new List<FEC_MDM_Decision_Condition__c>();

            for (Object condObj : conditionsRaw) {
                Map<String, Object> cond = (Map<String, Object>) condObj;
                String condId = cond.get('id') != null ? String.valueOf(cond.get('id')) : null;

                FEC_MDM_Decision_Condition__c rec = new FEC_MDM_Decision_Condition__c();
                if (String.isNotBlank(condId) && condId != 'null' && !condId.startsWith('new-')) {
                    rec.Id = (Id) condId;
                    keepIds.add(rec.Id);
                } else {
                    rec.FEC_Decision_Rule__c = rule.Id;
                }
                String operatorVal = (String) cond.get('operator');
                if (operatorVal == 'BETWEEN') {
                    operatorVal = '>=';
                }
                rec.FEC_Operator__c   = operatorVal;
                rec.FEC_Value__c      = (String) cond.get('value');
                rec.FEC_Expression__c = (String) cond.get('expression');
                rec.FEC_Order__c      = cond.get('order') != null
                                        ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null;
                rec.FEC_Type__c       = cond.get('type') != null ? (String) cond.get('type') : 'Condition';
                rec.FEC_Label__c      = (String) cond.get('label');

                conditionsToUpsert.add(rec);
            }

            // Delete removed conditions
            List<FEC_MDM_Decision_Condition__c> toDelete = [
                SELECT Id FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Decision_Rule__c = :rule.Id
                AND    Id NOT IN :keepIds
            ];
            if (!toDelete.isEmpty()) delete toDelete;

            // Upsert remaining/new
            if (!conditionsToUpsert.isEmpty()) upsert conditionsToUpsert;

            return rule.Id;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Save_Rule + ' ' + e.getMessage());
        }
    }


    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        if (!FEC_MDM_Decision_Rule__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        delete [SELECT Id FROM FEC_MDM_Decision_Rule__c WHERE Id = :ruleId];
    }

    @AuraEnabled
    public static void deleteConditionColumn(Id businessProcessId, String labelText, String tableKey) {
        if (!FEC_MDM_Decision_Condition__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
        List<FEC_MDM_Decision_Condition__c> toDelete;
        if (String.isNotBlank(keyId)) {
            toDelete = [
                SELECT Id FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Label__c = :labelText
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
            ];
        } else {
            toDelete = [
                SELECT Id FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Label__c = :labelText
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
            ];
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }


    @AuraEnabled
    public static Map<String, Object> testRuleEvaluation(
        Id businessProcessId,
        Map<String, String> fieldValues,
        String tableKey
    ) {
        try {
            if (fieldValues == null) {
                fieldValues = new Map<String, String>();
            }

            Map<String, Object> normalizedValues = new Map<String, Object>();
            for (String key : fieldValues.keySet()) {
                normalizedValues.put(key.toLowerCase(), fieldValues.get(key));
            }

            // Simple static query by Table_Key + Active
            List<FEC_MDM_Decision_Rule__c> rules = [
                SELECT  Id, Name, FEC_Priority__c
                FROM    FEC_MDM_Decision_Rule__c
                WHERE   FEC_Table_Key__c = :tableKey
                AND     FEC_Active__c = true
                ORDER BY FEC_Priority__c ASC NULLS LAST
            ];

            if (rules.isEmpty()) {
                return new Map<String, Object>{
                    'matched'         => false,
                    'message'         => System.Label.FEC_Error_NoRuleMatched,
                    'evaluationTrace' => new List<Map<String, Object>>()
                };
            }

            // Query conditions with Type and Label (no MDS fields)
            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Decision_Rule__c r : rules) { ruleIds.add(r.Id); }

            List<FEC_MDM_Decision_Condition__c> allConditions = [
                SELECT  Id, FEC_Decision_Rule__c,
                        FEC_Operator__c, FEC_Value__c, FEC_Expression__c, FEC_Order__c,
                        FEC_Type__c, FEC_Label__c
                FROM    FEC_MDM_Decision_Condition__c
                WHERE   FEC_Decision_Rule__c IN :ruleIds
                ORDER BY FEC_Order__c ASC NULLS LAST
            ];

            Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Decision_Condition__c>>();
            for (FEC_MDM_Decision_Condition__c c : allConditions) {
                if (!conditionsByRule.containsKey(c.FEC_Decision_Rule__c)) {
                    conditionsByRule.put(c.FEC_Decision_Rule__c, new List<FEC_MDM_Decision_Condition__c>());
                }
                conditionsByRule.get(c.FEC_Decision_Rule__c).add(c);
            }

            // Evaluate each rule + build trace
            List<Map<String, Object>> trace = new List<Map<String, Object>>();
            Boolean alreadyMatched = false;
            Map<String, Object> matchResult = null;

            for (FEC_MDM_Decision_Rule__c rule : rules) {
                List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);

                // Extract trace values from Condition/Action rows by Label
                String previousStageVal = null;
                String actionVal = null;
                String nextStageVal = null;
                String nextQueueVal = null;
                String teamVal = null;
                String availableDecisionsVal = null;

                // Separate Condition-type rows for evaluation
                List<FEC_MDM_Decision_Condition__c> conditionRows = new List<FEC_MDM_Decision_Condition__c>();

                if (ruleConds != null) {
                    for (FEC_MDM_Decision_Condition__c cond : ruleConds) {
                        String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
                        String condLabel = cond.FEC_Label__c;

                        // Extract known labels for trace/result
                        if (condType == 'Condition' && condLabel == 'Previous Stage') {
                            previousStageVal = cond.FEC_Value__c;
                        } else if (condType == 'Condition' && condLabel == 'Action Button') {
                            actionVal = cond.FEC_Value__c;
                        } else if (condType == 'Action' && condLabel == 'Next Stage') {
                            nextStageVal = cond.FEC_Value__c;
                        } else if (condType == 'Action' && condLabel == 'Next Queue') {
                            nextQueueVal = cond.FEC_Value__c;
                        } else if (condType == 'Action' && condLabel == 'Team User Group') {
                            teamVal = cond.FEC_Value__c;
                        } else if (condType == 'Action' && condLabel == 'Available Decisions') {
                            availableDecisionsVal = cond.FEC_Value__c;
                        }

                        // Collect only Condition-type rows for evaluation
                        if (condType == 'Condition') {
                            conditionRows.add(cond);
                        }
                    }
                }

                Map<String, Object> ruleTrace = new Map<String, Object>{
                    'ruleId'             => rule.Id,
                    'ruleName'           => rule.Name,
                    'priority'           => rule.FEC_Priority__c,
                    'previousStage'      => previousStageVal,
                    'action'             => actionVal,
                    'availableDecisions' => availableDecisionsVal,
                    'nextStage'          => nextStageVal,
                    'nextQueue'          => nextQueueVal,
                    'team'               => teamVal
                };

                if (alreadyMatched) {
                    ruleTrace.put('result', 'NOT_EVALUATED');
                    ruleTrace.put('conditions', new List<Map<String, Object>>());
                    trace.add(ruleTrace);
                    continue;
                }

                // No condition rows → default rule (match)
                if (conditionRows.isEmpty()) {
                    ruleTrace.put('result', 'MATCH');
                    ruleTrace.put('conditions', new List<Map<String, Object>>());
                    trace.add(ruleTrace);
                    alreadyMatched = true;
                    matchResult = buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
                    matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                    continue;
                }

                // Evaluate only Condition-type rows with trace
                List<Map<String, Object>> condTrace = new List<Map<String, Object>>();
                Boolean ruleMatched = evaluateConditionsWithTrace(conditionRows, normalizedValues, condTrace);

                ruleTrace.put('result', ruleMatched ? 'MATCH' : 'NOT_MATCH');
                ruleTrace.put('conditions', condTrace);
                trace.add(ruleTrace);

                if (ruleMatched) {
                    alreadyMatched = true;
                    matchResult = buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
                    matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                }
            }

            Map<String, Object> response = new Map<String, Object>{
                'evaluationTrace' => trace
            };
            if (matchResult != null) {
                response.putAll(matchResult);
            } else {
                response.put('matched', false);
                response.put('message', System.Label.FEC_Error_NoRuleMatched);
            }
            return response;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }


    @AuraEnabled
    public static void updateColumnProperties(Id businessProcessId, String labelText, String newOperator, String newExpression, String tableKey) {
        try {
            if (String.isBlank(labelText)) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (!FEC_MDM_Decision_Condition__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
            }

            String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
            List<FEC_MDM_Decision_Condition__c> conditions;
            if (String.isNotBlank(keyId)) {
                conditions = [
                    SELECT Id, FEC_Operator__c, FEC_Expression__c
                    FROM   FEC_MDM_Decision_Condition__c
                    WHERE  FEC_Label__c = :labelText
                    AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                    AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
                ];
            } else {
                conditions = [
                    SELECT Id, FEC_Operator__c, FEC_Expression__c
                    FROM   FEC_MDM_Decision_Condition__c
                    WHERE  FEC_Label__c = :labelText
                    AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                ];
            }

            if (conditions.isEmpty()) return;

            Map<String, String> operatorMap = new Map<String, String>{
                'EQUALS' => '=', 'NOT_EQUALS' => '!=', 'GREATER_THAN' => '>',
                'LESS_THAN' => '<', 'GREATER_THAN_OR_EQUAL' => '>=', 'LESS_THAN_OR_EQUAL' => '<=',
                'IN' => 'IN', 'NOT_IN' => 'NOT IN', 'CONTAINS' => 'Contains',
                'STARTS_WITH' => 'Starts With', 'ENDS_WITH' => 'Ends With'
            };
            String mappedOperator = operatorMap.containsKey(newOperator) ? operatorMap.get(newOperator) : newOperator;

            if (mappedOperator == 'BETWEEN') {
                for (FEC_MDM_Decision_Condition__c cond : conditions) {
                    cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
                }
                update Security.stripInaccessible(AccessType.UPDATABLE, conditions).getRecords();
                return;
            }

            for (FEC_MDM_Decision_Condition__c cond : conditions) {
                cond.FEC_Operator__c   = mappedOperator;
                cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
            }

            update Security.stripInaccessible(AccessType.UPDATABLE, conditions).getRecords();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission + ' ' + e.getMessage());
        }
    }


    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId, String tableKey) {
        List<Map<String, String>> options = new List<Map<String, String>>();

        try {
            // No fixed labels exclusion — all labels are selectable
            Set<String> seen = new Set<String>();

            // 1. Derive field options from distinct Condition labels already in the table
            String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
            List<FEC_MDM_Decision_Condition__c> conditionLabels;
            if (String.isNotBlank(keyId)) {
                conditionLabels = [
                    SELECT FEC_Label__c
                    FROM   FEC_MDM_Decision_Condition__c
                    WHERE  FEC_Type__c = 'Condition'
                    AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                    AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
                    AND    FEC_Label__c != null
                    ORDER BY FEC_Label__c ASC
                ];
            } else {
                conditionLabels = [
                    SELECT FEC_Label__c
                    FROM   FEC_MDM_Decision_Condition__c
                    WHERE  FEC_Type__c = 'Condition'
                    AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                    AND    FEC_Label__c != null
                    ORDER BY FEC_Label__c ASC
                ];
            }

            for (FEC_MDM_Decision_Condition__c cond : conditionLabels) {
                String labelText = cond.FEC_Label__c;
                if (String.isBlank(labelText) || seen.contains(labelText)) {
                    continue;
                }
                seen.add(labelText);
                options.add(new Map<String, String>{
                    'label'        => labelText,
                    'value'        => labelText,
                    'fieldApiName' => labelText,
                    'dataType'     => 'Text'
                });
            }

            // 2. Also include Case custom fields as available options for new columns
            Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
            for (String fieldName : caseFields.keySet()) {
                Schema.DescribeFieldResult dfr = caseFields.get(fieldName).getDescribe();
                // Only include custom fields and common standard fields that are useful
                if (!dfr.isCustom() && !dfr.getName().equals('Priority') && !dfr.getName().equals('Status')
                    && !dfr.getName().equals('Origin') && !dfr.getName().equals('Type') && !dfr.getName().equals('Reason')) {
                    continue;
                }
                String apiName = dfr.getName();
                String label = dfr.getLabel();
                if (seen.contains(apiName)) continue;
                seen.add(apiName);

                String dataType = 'Text';
                Schema.DisplayType dt = dfr.getType();
                if (dt == Schema.DisplayType.INTEGER || dt == Schema.DisplayType.DOUBLE
                    || dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.PERCENT) {
                    dataType = 'Number';
                } else if (dt == Schema.DisplayType.BOOLEAN) {
                    dataType = 'Boolean';
                } else if (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.MULTIPICKLIST) {
                    dataType = 'Picklist';
                } else if (dt == Schema.DisplayType.DATE) {
                    dataType = 'Date';
                }

                options.add(new Map<String, String>{
                    'label'        => label + ' (' + apiName + ')',
                    'value'        => apiName,
                    'fieldApiName' => apiName,
                    'dataType'     => dataType
                });
            }

            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }
}