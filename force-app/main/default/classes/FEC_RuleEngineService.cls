/**
 * @description Service layer for runtime rule evaluation.
 *              Extracted from FEC_MDM_WorkflowEngine in Phase 2.2 refactor.
 *              Handles First-Match-Wins evaluation of stage transition rules
 *              against actual Case data on both MDM and Live layers.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_RuleEngineService {

    // ════════════════════════════════════════════════════════
    // MDM LAYER: Evaluate Stage Transition (First Match Wins)
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> evaluateStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }

            List<FEC_MDM_Stage_Change__c> rules = queryActiveRulesForTransition(currentStageId, actionButtonId);
            if (rules.isEmpty()) return buildNoMatchResponse();

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Stage_Change__c rule : rules) ruleIds.add(rule.Id);

            List<FEC_MDM_Stage_Change_Condition__c> allConditions = queryConditionsForRules(ruleIds);
            Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = groupConditionsByRule(allConditions);

            Map<String, Object> caseData = fetchCaseDataForConditions(caseId, allConditions);
            return findFirstMatchingRule(rules, conditionsByRule, caseData);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static List<FEC_MDM_Stage_Change__c> queryActiveRulesForTransition(Id currentStageId, Id actionButtonId) {
        return [
            SELECT  Id, Name,
                    FEC_Previous_Stage__c,
                    FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                    FEC_Next_Queue__c, FEC_Team_User_Group__c,
                    FEC_Priority__c
            FROM    FEC_MDM_Stage_Change__c
            WHERE   FEC_Previous_Stage__c = :currentStageId
            AND     FEC_Action_Button__c = :actionButtonId
            AND     FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    private static List<FEC_MDM_Stage_Change_Condition__c> queryConditionsForRules(Set<Id> ruleIds) {
        return [
            SELECT  Id, FEC_Stage_Change__c,
                    FEC_Master_Data_Setting__c,
                    FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                    FEC_Master_Data_Setting__r.FEC_Field_Object_Name__c,
                    FEC_Operator__c, FEC_Value__c,
                    FEC_Expression__c, FEC_Order__c
            FROM    FEC_MDM_Stage_Change_Condition__c
            WHERE   FEC_Stage_Change__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
    }

    private static Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> groupConditionsByRule(
        List<FEC_MDM_Stage_Change_Condition__c> allConditions
    ) {
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> grouped = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Stage_Change__c;
            if (!grouped.containsKey(ruleId)) {
                grouped.put(ruleId, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            grouped.get(ruleId).add(cond);
        }
        return grouped;
    }

    private static Map<String, Object> fetchCaseDataForConditions(
        Id caseId, List<FEC_MDM_Stage_Change_Condition__c> conditions
    ) {
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
            String apiName = cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
            if (String.isNotBlank(apiName)) fieldApiNames.add(apiName);
        }
        return fieldApiNames.isEmpty() ? new Map<String, Object>() : queryCaseFields(caseId, fieldApiNames);
    }

    private static Map<String, Object> findFirstMatchingRule(
        List<FEC_MDM_Stage_Change__c> rules,
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule,
        Map<String, Object> caseData
    ) {
        for (FEC_MDM_Stage_Change__c rule : rules) {
            List<FEC_MDM_Stage_Change_Condition__c> ruleConditions = conditionsByRule.get(rule.Id);
            if (ruleConditions == null || ruleConditions.isEmpty()) {
                return buildMatchResult(rule);
            }
            if (evaluateRuleConditions(ruleConditions, caseData)) {
                return buildMatchResult(rule);
            }
        }
        return buildNoMatchResponse();
    }

    /**
     * Evaluate all conditions for an MDM rule. Logic: OR within same field, AND between fields.
     */
    public static Boolean evaluateRuleConditions(
        List<FEC_MDM_Stage_Change_Condition__c> conditions,
        Map<String, Object> caseData
    ) {
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByField = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
            Id fieldId = cond.FEC_Master_Data_Setting__c;
            if (fieldId == null) continue;
            if (!conditionsByField.containsKey(fieldId)) {
                conditionsByField.put(fieldId, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            conditionsByField.get(fieldId).add(cond);
        }

        for (Id fieldId : conditionsByField.keySet()) {
            if (!isFieldGroupMatched(conditionsByField.get(fieldId), caseData)) return false;
        }
        return true;
    }

    private static Boolean isFieldGroupMatched(
        List<FEC_MDM_Stage_Change_Condition__c> fieldConditions,
        Map<String, Object> caseData
    ) {
        for (FEC_MDM_Stage_Change_Condition__c cond : fieldConditions) {
            String apiName = cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
            String actualValue = '';
            if (String.isNotBlank(apiName)) {
                Object val = caseData.get(apiName.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
            }
            if (FEC_MDMConditionUtils.evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Query Case fields dynamically, validating each field against the Case schema.
     */
    public static Map<String, Object> queryCaseFields(Id caseId, Set<String> fieldApiNames) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        List<String> validFields = new List<String>();
        for (String fieldName : fieldApiNames) {
            if (caseFields.containsKey(fieldName.toLowerCase())) validFields.add(fieldName);
        }
        if (validFields.isEmpty()) return new Map<String, Object>();

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
    // LIVE LAYER: Evaluate Stage Transition (First Match Wins)
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> evaluateLiveStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }

            List<FEC_Stage_Change__c> rules = queryActiveLiveRules(currentStageId, actionButtonId);
            if (rules.isEmpty()) return buildNoMatchResponse();

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Stage_Change__c rule : rules) ruleIds.add(rule.Id);

            List<FEC_Stage_Change_Condition__c> allConditions = queryLiveConditions(ruleIds);
            Map<Id, List<FEC_Stage_Change_Condition__c>> conditionsByRule = groupLiveConditionsByRule(allConditions);

            Map<String, Object> caseData = fetchCaseDataForLiveConditions(caseId, allConditions);
            return findFirstMatchingLiveRule(rules, conditionsByRule, caseData);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static List<FEC_Stage_Change__c> queryActiveLiveRules(Id currentStageId, Id actionButtonId) {
        return [
            SELECT  Id, Name,
                    FEC_Previous_Stage__c,
                    FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                    FEC_Next_Queue__c, FEC_Team_User_Group__c
            FROM    FEC_Stage_Change__c
            WHERE   FEC_Previous_Stage__c = :currentStageId
            AND     FEC_Action_Button__c = :actionButtonId
            AND     FEC_Active__c = true
            ORDER BY Name ASC
        ];
    }

    private static List<FEC_Stage_Change_Condition__c> queryLiveConditions(Set<Id> ruleIds) {
        return [
            SELECT  Id, FEC_Stage_Change__c,
                    FEC_Master_Data_Setting__c,
                    FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                    FEC_Operator__c, FEC_Value__c, FEC_Order__c
            FROM    FEC_Stage_Change_Condition__c
            WHERE   FEC_Stage_Change__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
    }

    private static Map<Id, List<FEC_Stage_Change_Condition__c>> groupLiveConditionsByRule(
        List<FEC_Stage_Change_Condition__c> allConditions
    ) {
        Map<Id, List<FEC_Stage_Change_Condition__c>> grouped = new Map<Id, List<FEC_Stage_Change_Condition__c>>();
        for (FEC_Stage_Change_Condition__c c : allConditions) {
            if (!grouped.containsKey(c.FEC_Stage_Change__c)) {
                grouped.put(c.FEC_Stage_Change__c, new List<FEC_Stage_Change_Condition__c>());
            }
            grouped.get(c.FEC_Stage_Change__c).add(c);
        }
        return grouped;
    }

    private static Map<String, Object> fetchCaseDataForLiveConditions(
        Id caseId, List<FEC_Stage_Change_Condition__c> conditions
    ) {
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_Stage_Change_Condition__c c : conditions) {
            String apiName = c.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
            if (String.isNotBlank(apiName)) fieldApiNames.add(apiName);
        }
        return fieldApiNames.isEmpty() ? new Map<String, Object>() : queryCaseFields(caseId, fieldApiNames);
    }

    private static Map<String, Object> findFirstMatchingLiveRule(
        List<FEC_Stage_Change__c> rules,
        Map<Id, List<FEC_Stage_Change_Condition__c>> conditionsByRule,
        Map<String, Object> caseData
    ) {
        for (FEC_Stage_Change__c rule : rules) {
            List<FEC_Stage_Change_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            if (ruleConds == null || ruleConds.isEmpty()) return buildLiveMatchResult(rule);
            if (evaluateLiveRuleConditions(ruleConds, caseData)) return buildLiveMatchResult(rule);
        }
        return buildNoMatchResponse();
    }

    private static Boolean evaluateLiveRuleConditions(
        List<FEC_Stage_Change_Condition__c> conditions,
        Map<String, Object> caseData
    ) {
        Map<Id, List<FEC_Stage_Change_Condition__c>> conditionsByField = new Map<Id, List<FEC_Stage_Change_Condition__c>>();
        for (FEC_Stage_Change_Condition__c cond : conditions) {
            Id fieldId = cond.FEC_Master_Data_Setting__c;
            if (fieldId == null) continue;
            if (!conditionsByField.containsKey(fieldId)) {
                conditionsByField.put(fieldId, new List<FEC_Stage_Change_Condition__c>());
            }
            conditionsByField.get(fieldId).add(cond);
        }

        for (Id fieldId : conditionsByField.keySet()) {
            if (!isLiveFieldGroupMatched(conditionsByField.get(fieldId), caseData)) return false;
        }
        return true;
    }

    private static Boolean isLiveFieldGroupMatched(
        List<FEC_Stage_Change_Condition__c> fieldConds,
        Map<String, Object> caseData
    ) {
        for (FEC_Stage_Change_Condition__c cond : fieldConds) {
            String apiName = cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
            String actualValue = '';
            if (String.isNotBlank(apiName)) {
                Object val = caseData.get(apiName.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
            }
            if (FEC_MDMConditionUtils.evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, null)) {
                return true;
            }
        }
        return false;
    }

    // ════════════════════════════════════════════════════════
    // RESULT BUILDERS
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> buildMatchResult(FEC_MDM_Stage_Change__c rule) {
        return new Map<String, Object>{
            'matched'       => true,
            'ruleId'        => rule.Id,
            'ruleName'      => rule.Name,
            'nextStageId'   => rule.FEC_Next_Stage__c,
            'nextStageName' => rule.FEC_Next_Stage__r?.Name,
            'nextQueue'     => rule.FEC_Next_Queue__c,
            'teamUserGroup' => rule.FEC_Team_User_Group__c
        };
    }

    public static Map<String, Object> buildLiveMatchResult(FEC_Stage_Change__c rule) {
        return new Map<String, Object>{
            'matched'       => true,
            'ruleId'        => rule.Id,
            'ruleName'      => rule.Name,
            'nextStageId'   => rule.FEC_Next_Stage__c,
            'nextStageName' => rule.FEC_Next_Stage__r?.Name,
            'nextQueue'     => rule.FEC_Next_Queue__c,
            'teamUserGroup' => rule.FEC_Team_User_Group__c
        };
    }

    private static Map<String, Object> buildNoMatchResponse() {
        return new Map<String, Object>{
            'matched' => false,
            'message' => System.Label.FEC_Error_NoRuleMatched
        };
    }
}