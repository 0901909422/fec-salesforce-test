/**
 * @description Service layer for Rule Test Panel evaluation (LWC).
 *              Extracted from FEC_MDM_WorkflowEngine in Phase 2.2 refactor.
 *              Provides mock-data evaluation with detailed trace for the
 *              Decision Table Stage View test panel.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_RuleTestService {

    /**
     * Evaluate Decision Table rules using mock field values (no real Case needed).
     * Returns matched rule info plus detailed evaluationTrace for UI display.
     */
    public static Map<String, Object> testRuleEvaluation(
        Id businessProcessId,
        Id previousStageId,
        Id actionButtonId,
        Map<String, String> fieldValues
    ) {
        try {
            if (businessProcessId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            Map<String, Object> normalizedValues = normalizeFieldValues(fieldValues);
            List<FEC_MDM_Stage_Change__c> rules = queryRulesForTest(businessProcessId, previousStageId, actionButtonId);

            if (rules.isEmpty()) return buildNoMatchTraceResponse();

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Stage_Change__c r : rules) ruleIds.add(r.Id);

            List<FEC_MDM_Stage_Change_Condition__c> allConditions = queryConditionsForTest(ruleIds);
            Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = groupConditionsByRule(allConditions);

            return evaluateRulesWithTrace(rules, conditionsByRule, normalizedValues);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static Map<String, Object> normalizeFieldValues(Map<String, String> fieldValues) {
        Map<String, Object> normalized = new Map<String, Object>();
        if (fieldValues == null) return normalized;
        for (String key : fieldValues.keySet()) {
            normalized.put(key.toLowerCase(), fieldValues.get(key));
        }
        return normalized;
    }

    private static List<FEC_MDM_Stage_Change__c> queryRulesForTest(
        Id businessProcessId, Id previousStageId, Id actionButtonId
    ) {
        String soql = 'SELECT Id, Name, FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name, '
            + 'FEC_Action_Button__c, FEC_Action_Button__r.Name, '
            + 'FEC_Next_Stage__c, FEC_Next_Stage__r.Name, '
            + 'FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Priority__c '
            + 'FROM FEC_MDM_Stage_Change__c '
            + 'WHERE FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId '
            + 'AND FEC_Active__c = true ';
        if (previousStageId != null) soql += 'AND FEC_Previous_Stage__c = :previousStageId ';
        if (actionButtonId != null)  soql += 'AND FEC_Action_Button__c = :actionButtonId ';
        soql += 'ORDER BY FEC_Priority__c ASC NULLS LAST';
        return Database.query(soql);
    }

    private static List<FEC_MDM_Stage_Change_Condition__c> queryConditionsForTest(Set<Id> ruleIds) {
        return [
            SELECT  Id, FEC_Stage_Change__c,
                    FEC_Master_Data_Setting__c,
                    FEC_Master_Data_Setting__r.FEC_Field_Label_Name__c,
                    FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                    FEC_Operator__c, FEC_Value__c, FEC_Expression__c, FEC_Order__c
            FROM    FEC_MDM_Stage_Change_Condition__c
            WHERE   FEC_Stage_Change__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
    }

    private static Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> groupConditionsByRule(
        List<FEC_MDM_Stage_Change_Condition__c> allConditions
    ) {
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> grouped = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c c : allConditions) {
            if (!grouped.containsKey(c.FEC_Stage_Change__c)) {
                grouped.put(c.FEC_Stage_Change__c, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            grouped.get(c.FEC_Stage_Change__c).add(c);
        }
        return grouped;
    }

    private static Map<String, Object> evaluateRulesWithTrace(
        List<FEC_MDM_Stage_Change__c> rules,
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule,
        Map<String, Object> normalizedValues
    ) {
        List<Map<String, Object>> trace = new List<Map<String, Object>>();
        Boolean alreadyMatched = false;
        Map<String, Object> matchResult = null;

        for (FEC_MDM_Stage_Change__c rule : rules) {
            List<FEC_MDM_Stage_Change_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            Map<String, Object> ruleTrace = buildRuleTraceShell(rule);

            if (alreadyMatched) {
                ruleTrace.put('result', 'NOT_EVALUATED');
                ruleTrace.put('conditions', new List<Map<String, Object>>());
                trace.add(ruleTrace);
                continue;
            }

            if (ruleConds == null || ruleConds.isEmpty()) {
                ruleTrace.put('result', 'MATCH');
                ruleTrace.put('conditions', new List<Map<String, Object>>());
                trace.add(ruleTrace);
                alreadyMatched = true;
                matchResult = FEC_RuleEngineService.buildMatchResult(rule);
                matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                continue;
            }

            List<Map<String, Object>> condTrace = new List<Map<String, Object>>();
            Boolean ruleMatched = evaluateConditionsWithTrace(ruleConds, normalizedValues, condTrace);

            ruleTrace.put('result', ruleMatched ? 'MATCH' : 'NOT_MATCH');
            ruleTrace.put('conditions', condTrace);
            trace.add(ruleTrace);

            if (ruleMatched) {
                alreadyMatched = true;
                matchResult = FEC_RuleEngineService.buildMatchResult(rule);
                matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
            }
        }

        return buildTraceResponse(trace, matchResult);
    }

    private static Map<String, Object> buildRuleTraceShell(FEC_MDM_Stage_Change__c rule) {
        return new Map<String, Object>{
            'ruleId'        => rule.Id,
            'ruleName'      => rule.Name,
            'priority'      => rule.FEC_Priority__c,
            'previousStage' => rule.FEC_Previous_Stage__r?.Name,
            'action'        => rule.FEC_Action_Button__r?.Name,
            'nextStage'     => rule.FEC_Next_Stage__r?.Name,
            'nextQueue'     => rule.FEC_Next_Queue__c,
            'team'          => rule.FEC_Team_User_Group__c
        };
    }

    private static Map<String, Object> buildTraceResponse(
        List<Map<String, Object>> trace, Map<String, Object> matchResult
    ) {
        Map<String, Object> response = new Map<String, Object>{ 'evaluationTrace' => trace };
        if (matchResult != null) {
            response.putAll(matchResult);
        } else {
            response.put('matched', false);
            response.put('message', System.Label.FEC_Error_NoRuleMatched);
        }
        return response;
    }

    private static Map<String, Object> buildNoMatchTraceResponse() {
        return new Map<String, Object>{
            'matched'         => false,
            'message'         => System.Label.FEC_Error_NoRuleMatched,
            'evaluationTrace' => new List<Map<String, Object>>()
        };
    }

    /**
     * Evaluate conditions building a detailed trace for UI display.
     * Logic: OR within same field, AND between fields.
     */
    @TestVisible
    private static Boolean evaluateConditionsWithTrace(
        List<FEC_MDM_Stage_Change_Condition__c> conditions,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> byField = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c c : conditions) {
            if (c.FEC_Master_Data_Setting__c == null) continue;
            if (!byField.containsKey(c.FEC_Master_Data_Setting__c)) {
                byField.put(c.FEC_Master_Data_Setting__c, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            byField.get(c.FEC_Master_Data_Setting__c).add(c);
        }

        Boolean allGroupsMatch = true;
        for (Id fieldId : byField.keySet()) {
            if (!evaluateFieldGroupWithTrace(byField.get(fieldId), fieldValues, condTrace)) {
                allGroupsMatch = false;
            }
        }
        return allGroupsMatch;
    }

    private static Boolean evaluateFieldGroupWithTrace(
        List<FEC_MDM_Stage_Change_Condition__c> fieldConds,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        Boolean groupMatched = false;
        for (FEC_MDM_Stage_Change_Condition__c cond : fieldConds) {
            String apiName = cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
            String actualValue = '';
            if (String.isNotBlank(apiName)) {
                Object val = fieldValues.get(apiName.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
            }
            Boolean condResult = FEC_MDMConditionUtils.evaluateCondition(
                actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c
            );
            condTrace.add(buildConditionTrace(cond, apiName, actualValue, condResult));
            if (condResult) groupMatched = true;
        }
        return groupMatched;
    }

    private static Map<String, Object> buildConditionTrace(
        FEC_MDM_Stage_Change_Condition__c cond, String apiName, String actualValue, Boolean condResult
    ) {
        return new Map<String, Object>{
            'fieldLabel'    => cond.FEC_Master_Data_Setting__r?.FEC_Field_Label_Name__c,
            'fieldApiName'  => apiName,
            'operator'      => cond.FEC_Operator__c,
            'expectedValue' => cond.FEC_Value__c,
            'actualValue'   => actualValue,
            'expression'    => cond.FEC_Expression__c,
            'result'        => condResult
        };
    }
}