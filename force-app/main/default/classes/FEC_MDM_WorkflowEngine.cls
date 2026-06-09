/**
 * @description Facade for MDM Decision Table Engine — delegates to specialized services.
 *              Refactored in Phase 2.2 from God Class (1,316 LOC) to thin Facade (~80 LOC).
 *              LWC import paths preserved (no breaking change).
 *
 *              Service map:
 *              - Decision Table CRUD       → FEC_MDMDecisionTableService
 *              - Field Options             → FEC_MDMFieldOptionService
 *              - Runtime Rule Evaluation   → FEC_RuleEngineService
 *              - Test Panel Evaluation     → FEC_RuleTestService
 *              - Condition Utilities       → FEC_MDMConditionUtils
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_MDM_WorkflowEngine {

    // ════════════════════════════════════════════════════════
    // DECISION TABLE CRUD (delegate to FEC_MDMDecisionTableService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId) {
        return FEC_MDMDecisionTableService.getRulesWithConditions(businessProcessId);
    }

    @AuraEnabled
    public static String saveRuleWithConditions(String ruleData) {
        return FEC_MDMDecisionTableService.saveRuleWithConditions(ruleData);
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDecisionTableData(Id businessProcessId) {
        return FEC_MDMDecisionTableService.getDecisionTableData(businessProcessId);
    }

    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        FEC_MDMDecisionTableService.deleteRule(ruleId);
    }

    @AuraEnabled
    public static void deleteConditionColumn(Id businessProcessId, Id masterDataSettingId) {
        FEC_MDMDecisionTableService.deleteConditionColumn(businessProcessId, masterDataSettingId);
    }

    @AuraEnabled
    public static void updateColumnProperties(Id businessProcessId, Id masterDataSettingId, String newOperator, String newExpression) {
        FEC_MDMDecisionTableService.updateColumnProperties(businessProcessId, masterDataSettingId, newOperator, newExpression);
    }

    // ════════════════════════════════════════════════════════
    // FIELD OPTIONS (delegate to FEC_MDMFieldOptionService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAdditionalFieldOptions() {
        return FEC_MDMFieldOptionService.getAdditionalFieldOptions();
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId) {
        return FEC_MDMFieldOptionService.getFieldsForBusinessProcess(businessProcessId);
    }

    @AuraEnabled
    public static List<Map<String, String>> getFieldsForStage(String stageId) {
        return FEC_MDMFieldOptionService.getFieldsForStage(stageId);
    }

    // ════════════════════════════════════════════════════════
    // RUNTIME RULE EVALUATION (delegate to FEC_RuleEngineService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Object> evaluateStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        return FEC_RuleEngineService.evaluateStageTransition(caseId, currentStageId, actionButtonId);
    }

    @AuraEnabled
    public static Map<String, Object> evaluateLiveStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        return FEC_RuleEngineService.evaluateLiveStageTransition(caseId, currentStageId, actionButtonId);
    }

    // ════════════════════════════════════════════════════════
    // TEST PANEL (delegate to FEC_RuleTestService)
    // ════════════════════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Object> testRuleEvaluation(
        Id businessProcessId,
        Id previousStageId,
        Id actionButtonId,
        Map<String, String> fieldValues
    ) {
        return FEC_RuleTestService.testRuleEvaluation(businessProcessId, previousStageId, actionButtonId, fieldValues);
    }

    // ════════════════════════════════════════════════════════
    // BACKWARD-COMPAT @TestVisible methods (for FEC_MDM_WorkflowEngineTest)
    // Existing test class calls these on the Facade — preserved as delegates.
    // ════════════════════════════════════════════════════════

    @TestVisible
    private static Boolean evaluateCondition(String actualValue, String operator, String conditionValue, String expression) {
        return FEC_MDMConditionUtils.evaluateCondition(actualValue, operator, conditionValue, expression);
    }

    @TestVisible
    private static String applyExpression(String expression, String value) {
        return FEC_MDMConditionUtils.applyExpression(expression, value);
    }

    @TestVisible
    private static String resolveFieldDataType(String objectName, String fieldApiName) {
        return FEC_MDMConditionUtils.resolveFieldDataType(objectName, fieldApiName);
    }
}