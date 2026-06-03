/**
 * @description Facade for Stage Transition Engine — delegates to specialized services.
 *              Refactored in Phase 2.3 from God Class (1,605 LOC) to thin Facade (~120 LOC).
 *              LWC import paths preserved (no breaking change).
 *
 *              Service map:
 *              - Runtime evaluation (Live + MDM)  → FEC_StageTransitionResolver
 *              - CRUD + Test panel (MDM)          → FEC_StageTransitionExecutor
 *              - Condition utilities              → FEC_MDMConditionUtils (shared with Phase 2.2)
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.3
 */
public with sharing class FEC_StageTransitionEngine {

    public static final String TABLE_KEY_STAGE_TRANSITION = FEC_StageTransitionResolver.TABLE_KEY_STAGE_TRANSITION;

    // ════════════════════════════════════════════════════════
    // STAGE HISTORY (delegate to FEC_StageTransitionResolver)
    // ════════════════════════════════════════════════════════

    public static void insertStageHistory(Id caseId, Id fromStageId, Id toStageId, Id actionButtonId, String queue) {
        FEC_StageTransitionResolver.insertStageHistory(caseId, fromStageId, toStageId, actionButtonId, queue);
    }

    // ════════════════════════════════════════════════════════
    // LIVE LAYER — Decision Table evaluation
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Map<String, Object>> getDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        return FEC_StageTransitionResolver.getDecisionTableResults(caseId, currentStageId, actionLabel, isEvaluateAll == true);
    }

    @AuraEnabled
    public static Map<String, Object> evaluateSingleTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        return FEC_StageTransitionResolver.evaluateSingleTransitionWithKey(caseId, currentStageId, actionButtonId, TABLE_KEY_STAGE_TRANSITION);
    }

    @AuraEnabled
    public static Map<String, Object> evaluateSingleTransitionWithKey(Id caseId, Id currentStageId, Id actionButtonId, String tableKey) {
        return FEC_StageTransitionResolver.evaluateSingleTransitionWithKey(caseId, currentStageId, actionButtonId, tableKey);
    }

    // ════════════════════════════════════════════════════════
    // MDM LAYER — Decision Table evaluation
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Map<String, Object>> getMDMDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        return FEC_StageTransitionResolver.getMDMDecisionTableResults(caseId, currentStageId, actionLabel, isEvaluateAll == true);
    }

    // ════════════════════════════════════════════════════════
    // MDM CRUD (delegate to FEC_StageTransitionExecutor)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId, String tableKey) {
        return FEC_StageTransitionExecutor.getRulesWithConditions(businessProcessId, tableKey);
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDecisionTableData(Id businessProcessId, String tableKey) {
        return FEC_StageTransitionExecutor.getDecisionTableData(businessProcessId, tableKey);
    }

    @AuraEnabled
    public static String saveRuleWithConditions(String ruleData) {
        return FEC_StageTransitionExecutor.saveRuleWithConditions(ruleData);
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        FEC_StageTransitionExecutor.deleteRule(ruleId);
    }

    @AuraEnabled
    public static Integer deleteAllRulesByBP(Id businessProcessId, String tableKey) {
        return FEC_StageTransitionExecutor.deleteAllRulesByBP(businessProcessId, tableKey);
    }

    @AuraEnabled
    public static void deleteConditionColumn(Id businessProcessId, String labelText, String tableKey) {
        FEC_StageTransitionExecutor.deleteConditionColumn(businessProcessId, labelText, tableKey);
    }

    @AuraEnabled
    public static Map<String, Object> testRuleEvaluation(Id businessProcessId, Map<String, String> fieldValues, String tableKey) {
        return FEC_StageTransitionExecutor.testRuleEvaluation(businessProcessId, fieldValues, tableKey);
    }

    @AuraEnabled
    public static void updateColumnProperties(Id businessProcessId, String labelText, String newOperator, String newExpression, String tableKey) {
        FEC_StageTransitionExecutor.updateColumnProperties(businessProcessId, labelText, newOperator, newExpression, tableKey);
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId, String tableKey) {
        return FEC_StageTransitionExecutor.getFieldsForBusinessProcess(businessProcessId, tableKey);
    }

    // ════════════════════════════════════════════════════════
    // BACKWARD-COMPAT @TestVisible (FEC_StageTransitionEngineTest)
    // ════════════════════════════════════════════════════════

    @TestVisible
    private static Boolean evaluateCondition(String actualValue, String operator, String conditionValue, String expression) {
        return FEC_MDMConditionUtils.evaluateCondition(actualValue, operator, conditionValue, expression);
    }

    @TestVisible
    private static String applyExpression(String expression, String value) {
        return FEC_MDMConditionUtils.applyExpression(expression, value);
    }
}