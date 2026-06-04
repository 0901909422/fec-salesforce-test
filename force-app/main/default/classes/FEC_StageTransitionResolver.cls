/**
 * @description Service layer for runtime stage transition evaluation.
 *              Extracted from FEC_StageTransitionEngine in Phase 2.3 refactor.
 *              Handles Live + MDM Decision Table evaluation, single transition match,
 *              and revert info via Stage History.
 *
 *              Reuses FEC_MDMConditionUtils for condition evaluation (DRY).
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.3
 */
public with sharing class FEC_StageTransitionResolver {

    public static final String TABLE_KEY_STAGE_TRANSITION = 'STAGE_TRANSITION';
    private static final Set<String> FIXED_LABELS = new Set<String>{ 'Previous Stage', 'Current Stage', 'Action Button' };

    // ════════════════════════════════════════════════════════
    // STAGE NAME CACHE (per transaction)
    // ════════════════════════════════════════════════════════

    private static Map<String, String> stageNameCache = new Map<String, String>();
    private static Boolean stageCacheLoaded = false;

    public static String resolveStageNameFromCode(String stageCodeOrName) {
        if (String.isBlank(stageCodeOrName)) return stageCodeOrName;
        if (!stageCacheLoaded) {
            for (FEC_Case_Stage__c s : [SELECT Name, FEC_Code__c FROM FEC_Case_Stage__c WHERE FEC_Code__c != null]) {
                stageNameCache.put(s.FEC_Code__c, s.Name);
            }
            stageCacheLoaded = true;
        }
        String resolved = stageNameCache.get(stageCodeOrName);
        return resolved != null ? resolved : stageCodeOrName;
    }

    // ════════════════════════════════════════════════════════
    // PRIVATE HELPERS — LIVE QUERIES
    // ════════════════════════════════════════════════════════

    private static List<FEC_Decision_Rule__c> queryRulesByTableKey(String tableKey) {
        return [
            SELECT  Id, Name, FEC_Priority__c
            FROM    FEC_Decision_Rule__c
            WHERE   FEC_Table_Key__c = :tableKey
            AND     FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    private static Map<Id, List<FEC_Decision_Condition__c>> queryConditionsForRules(Set<Id> ruleIds) {
        List<FEC_Decision_Condition__c> allConditions = [
            SELECT Id, FEC_Decision_Rule__c, FEC_Type__c, FEC_Label__c,
                   FEC_Operator__c, FEC_Value__c, FEC_Expression__c, FEC_Order__c
            FROM   FEC_Decision_Condition__c
            WHERE  FEC_Decision_Rule__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
        Map<Id, List<FEC_Decision_Condition__c>> grouped = new Map<Id, List<FEC_Decision_Condition__c>>();
        for (FEC_Decision_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Decision_Rule__c;
            if (!grouped.containsKey(ruleId)) grouped.put(ruleId, new List<FEC_Decision_Condition__c>());
            grouped.get(ruleId).add(cond);
        }
        return grouped;
    }

    private static Set<String> collectFieldApiNames(List<FEC_Decision_Condition__c> conditions) {
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isNotBlank(label) && !FIXED_LABELS.contains(label)) {
                fieldApiNames.add(label);
            }
            // FIELD(...) trong Value → cần load thêm field được tham chiếu để so field-to-field
            String refLabel = FEC_MDMConditionUtils.extractFieldRefLabel(cond.FEC_Value__c);
            if (String.isNotBlank(refLabel)) {
                fieldApiNames.add(refLabel);
            }
        }
        return fieldApiNames;
    }

    private static Map<String, Object> queryCaseFields(Id caseId, Set<String> fieldApiNames) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        List<String> validFields = new List<String>();
        for (String fieldName : fieldApiNames) {
            if (caseFields.containsKey(fieldName.toLowerCase())) validFields.add(fieldName);
        }
        if (validFields.isEmpty()) return new Map<String, Object>();

        String soql = 'SELECT ' + String.join(validFields, ', ') + ' FROM Case WHERE Id = :caseId LIMIT 1';
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
    // PRIVATE HELPERS — LIVE EVALUATION
    // ════════════════════════════════════════════════════════

    private static Boolean evaluateRuleConditions(List<FEC_Decision_Condition__c> conditions, Map<String, Object> caseData) {
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
        for (String label : conditionsByLabel.keySet()) {
            if (!isLiveLabelGroupMatched(conditionsByLabel.get(label), label, caseData)) return false;
        }
        return true;
    }

    private static Boolean isLiveLabelGroupMatched(List<FEC_Decision_Condition__c> labelConds, String label, Map<String, Object> caseData) {
        for (FEC_Decision_Condition__c cond : labelConds) {
            Object val = caseData.get(label.toLowerCase());
            String actualValue = val != null ? String.valueOf(val) : '';
            // Resolve FIELD(...) → giá trị field khác trên Case (so field-to-field); literal giữ nguyên.
            String compareValue = FEC_MDMConditionUtils.resolveConditionValue(cond.FEC_Value__c, caseData);
            if (FEC_MDMConditionUtils.evaluateCondition(actualValue, cond.FEC_Operator__c, compareValue, cond.FEC_Expression__c)) {
                return true;
            }
        }
        return false;
    }

    private static Map<String, Object> buildMatchResult(Id ruleId, String ruleName, List<FEC_Decision_Condition__c> ruleConditions) {
        Map<String, Object> result = new Map<String, Object>{
            'ruleId' => ruleId,
            'matched' => true
        };
        if (ruleConditions == null) return result;
        for (FEC_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c != 'Action') continue;
            populateActionField(result, cond.FEC_Label__c, cond.FEC_Value__c);
        }
        return result;
    }

    private static void populateActionField(Map<String, Object> result, String label, String value) {
        if (label == 'Next Stage') {
            result.put('nextStageName', resolveStageNameFromCode(value));
            result.put('nextStageCode', value);
        } else if (label == 'Next Queue') {
            result.put('nextQueue', value);
        } else if (label == 'Available Decisions') {
            result.put('availableDecisions', value);
        } else if (label == 'Team User Group') {
            result.put('teamUserGroup', value);
        } else if (label == 'Action Button') {
            result.put('actionButtonName', value);
        } else if (String.isNotBlank(label)) {
            // Generic fallback: cột tuỳ biến do admin thêm trên UI Decision Engine (vd: Auto, Custom Flag).
            // Convert label thành camelCase key, đặt vào output map để caller đọc được.
            result.put(toCamelCaseKey(label), value);
        }
    }

    private static String toCamelCaseKey(String label) {
        if (String.isBlank(label)) return label;
        List<String> parts = label.trim().split('\\s+');
        if (parts.isEmpty()) return label;
        String key = parts[0].toLowerCase();
        for (Integer i = 1; i < parts.size(); i++) {
            String p = parts[i];
            if (String.isBlank(p)) continue;
            key += p.substring(0, 1).toUpperCase() + (p.length() > 1 ? p.substring(1).toLowerCase() : '');
        }
        return key;
    }

    private static String getActionValueByLabel(List<FEC_Decision_Condition__c> ruleConditions, String targetLabel) {
        if (ruleConditions == null) return null;
        for (FEC_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Action' && cond.FEC_Label__c == targetLabel) {
                return cond.FEC_Value__c;
            }
        }
        return null;
    }

    private static Boolean hasConditionRowMatching(List<FEC_Decision_Condition__c> ruleConditions, String targetLabel, String expectedCode, String expectedName) {
        if (ruleConditions == null || ruleConditions.isEmpty()) return false;
        for (FEC_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c != 'Condition' || cond.FEC_Label__c != targetLabel) continue;
            String storedValue = cond.FEC_Value__c;
            if (String.isNotBlank(expectedCode) && expectedCode == storedValue) return true;
            if (String.isNotBlank(expectedName) && expectedName == storedValue) return true;
        }
        return false;
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

    public static Map<String, Object> getRevertInfo(Id caseId, Id currentStageId) {
        List<FEC_Stage_History__c> historyList = [
            SELECT FEC_From_Stage__c, FEC_From_Stage__r.Name, FEC_Queue__c
            FROM FEC_Stage_History__c
            WHERE FEC_Case__c = :caseId AND FEC_To_Stage__c = :currentStageId
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
    // PUBLIC: LIVE — getDecisionTableResults
    // ════════════════════════════════════════════════════════

    public static Map<String, Map<String, Object>> getDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        try {
            if (caseId == null || currentStageId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            String tableKey = TABLE_KEY_STAGE_TRANSITION;

            StageInfo stageInfo = queryStageInfo(currentStageId);
            List<FEC_Decision_Rule__c> allRules = queryRulesByTableKey(tableKey);
            if (allRules.isEmpty()) return buildEmptyResultWithRevert(caseId, currentStageId);

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Decision_Rule__c r : allRules) ruleIds.add(r.Id);

            Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule = queryConditionsForRules(ruleIds);
            List<FEC_Decision_Rule__c> rules = filterRulesByStage(allRules, conditionsByRule, stageInfo);
            if (rules.isEmpty()) return buildEmptyResultWithRevert(caseId, currentStageId);

            Map<String, Object> caseData = collectAllCaseData(caseId, rules, conditionsByRule);
            Map<String, List<FEC_Decision_Rule__c>> rulesByDecisionLabel = groupRulesByDecisionLabel(rules, conditionsByRule, actionLabel);
            Map<String, Map<String, Object>> result = evaluateRuleGroups(rulesByDecisionLabel, conditionsByRule, caseData, isEvaluateAll);

            Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
            if (revertInfo != null) result.put('Revert', revertInfo);
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static StageInfo queryStageInfo(Id stageId) {
        StageInfo info = new StageInfo();
        List<FEC_Case_Stage__c> stages = [SELECT Name, FEC_Code__c FROM FEC_Case_Stage__c WHERE Id = :stageId LIMIT 1];
        if (!stages.isEmpty()) {
            info.name = stages[0].Name;
            info.code = stages[0].FEC_Code__c;
        }
        return info;
    }

    private static Map<String, Map<String, Object>> buildEmptyResultWithRevert(Id caseId, Id currentStageId) {
        Map<String, Map<String, Object>> emptyResult = new Map<String, Map<String, Object>>();
        Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
        if (revertInfo != null) emptyResult.put('Revert', revertInfo);
        return emptyResult;
    }

    private static List<FEC_Decision_Rule__c> filterRulesByStage(
        List<FEC_Decision_Rule__c> allRules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        StageInfo stageInfo
    ) {
        List<FEC_Decision_Rule__c> filtered = new List<FEC_Decision_Rule__c>();
        for (FEC_Decision_Rule__c rule : allRules) {
            List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            if (hasConditionRowMatching(ruleConds, 'Previous Stage', stageInfo.code, stageInfo.name)
                || hasConditionRowMatching(ruleConds, 'Current Stage', stageInfo.code, stageInfo.name)) {
                filtered.add(rule);
            }
        }
        return filtered;
    }

    private static Map<String, Object> collectAllCaseData(
        Id caseId,
        List<FEC_Decision_Rule__c> rules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule
    ) {
        List<FEC_Decision_Condition__c> allConds = new List<FEC_Decision_Condition__c>();
        for (FEC_Decision_Rule__c rule : rules) {
            List<FEC_Decision_Condition__c> conds = conditionsByRule.get(rule.Id);
            if (conds != null) allConds.addAll(conds);
        }
        Set<String> fieldApiNames = collectFieldApiNames(allConds);
        return fieldApiNames.isEmpty() ? new Map<String, Object>() : queryCaseFields(caseId, fieldApiNames);
    }

    private static Map<String, List<FEC_Decision_Rule__c>> groupRulesByDecisionLabel(
        List<FEC_Decision_Rule__c> rules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        String actionLabelFilter
    ) {
        Map<String, List<FEC_Decision_Rule__c>> grouped = new Map<String, List<FEC_Decision_Rule__c>>();
        for (FEC_Decision_Rule__c rule : rules) {
            List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            String decisionLabel = getActionValueByLabel(ruleConds, 'Available Decisions');
            if (String.isBlank(decisionLabel)) continue;
            if (String.isNotBlank(actionLabelFilter) && !decisionLabel.equals(actionLabelFilter)) continue;
            if (!grouped.containsKey(decisionLabel)) grouped.put(decisionLabel, new List<FEC_Decision_Rule__c>());
            grouped.get(decisionLabel).add(rule);
        }
        return grouped;
    }

    private static Map<String, Map<String, Object>> evaluateRuleGroups(
        Map<String, List<FEC_Decision_Rule__c>> rulesByDecisionLabel,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> caseData,
        Boolean isEvaluateAll
    ) {
        Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();
        for (String label : rulesByDecisionLabel.keySet()) {
            Map<String, Object> entry = evaluateOneGroup(rulesByDecisionLabel.get(label), conditionsByRule, caseData, isEvaluateAll);
            if (entry != null) result.put(label, entry);
        }
        return result;
    }

    private static Map<String, Object> evaluateOneGroup(
        List<FEC_Decision_Rule__c> groupRules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> caseData,
        Boolean isEvaluateAll
    ) {
        List<Map<String, Object>> allRuleResults = new List<Map<String, Object>>();
        for (FEC_Decision_Rule__c rule : groupRules) {
            List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            Boolean isMatch = (ruleConds == null || ruleConds.isEmpty()) || evaluateRuleConditions(ruleConds, caseData);
            if (isEvaluateAll) {
                allRuleResults.add(buildMatchResult(rule.Id, rule.Name, ruleConds));
            } else if (isMatch) {
                return buildMatchResult(rule.Id, rule.Name, ruleConds);
            }
        }
        if (isEvaluateAll && !allRuleResults.isEmpty()) {
            Map<String, Object> entry = (Map<String, Object>) allRuleResults[0].clone();
            if (allRuleResults.size() > 1) entry.put('rules', allRuleResults);
            return entry;
        }
        return null;
    }

    // ════════════════════════════════════════════════════════
    // PUBLIC: LIVE — evaluateSingleTransition
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> evaluateSingleTransitionWithKey(Id caseId, Id currentStageId, Id actionButtonId, String tableKey) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (String.isBlank(tableKey)) tableKey = TABLE_KEY_STAGE_TRANSITION;

            StageInfo stageInfo = queryStageInfo(currentStageId);
            String actionButtonName = queryActionButtonName(actionButtonId);

            List<FEC_Decision_Rule__c> allRules = queryRulesByTableKey(tableKey);
            if (allRules.isEmpty()) return buildNoMatchResponse();

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Decision_Rule__c r : allRules) ruleIds.add(r.Id);
            Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule = queryConditionsForRules(ruleIds);

            List<FEC_Decision_Rule__c> rules = filterRulesByStageAndAction(allRules, conditionsByRule, stageInfo, actionButtonName);
            if (rules.isEmpty()) return buildNoMatchResponse();

            Map<String, Object> caseData = collectAllCaseData(caseId, rules, conditionsByRule);
            return findFirstMatchingRule(rules, conditionsByRule, caseData);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static String queryActionButtonName(Id actionButtonId) {
        List<FEC_Action_Button__c> buttons = [SELECT Name FROM FEC_Action_Button__c WHERE Id = :actionButtonId LIMIT 1];
        return buttons.isEmpty() ? '' : buttons[0].Name;
    }

    private static List<FEC_Decision_Rule__c> filterRulesByStageAndAction(
        List<FEC_Decision_Rule__c> allRules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        StageInfo stageInfo,
        String actionButtonName
    ) {
        List<FEC_Decision_Rule__c> filtered = new List<FEC_Decision_Rule__c>();
        for (FEC_Decision_Rule__c rule : allRules) {
            List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            Boolean stageMatch = hasConditionRowMatching(ruleConds, 'Previous Stage', stageInfo.code, stageInfo.name)
                || hasConditionRowMatching(ruleConds, 'Current Stage', stageInfo.code, stageInfo.name);
            Boolean actionMatch = hasConditionRowMatching(ruleConds, 'Action Button', actionButtonName, null);
            if (stageMatch && actionMatch) filtered.add(rule);
        }
        return filtered;
    }

    private static Map<String, Object> findFirstMatchingRule(
        List<FEC_Decision_Rule__c> rules,
        Map<Id, List<FEC_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> caseData
    ) {
        for (FEC_Decision_Rule__c rule : rules) {
            List<FEC_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            if (ruleConds == null || ruleConds.isEmpty() || evaluateRuleConditions(ruleConds, caseData)) {
                return buildMatchResult(rule.Id, rule.Name, ruleConds);
            }
        }
        return buildNoMatchResponse();
    }

    private static Map<String, Object> buildNoMatchResponse() {
        return new Map<String, Object>{
            'matched' => false,
            'message' => System.Label.FEC_Error_NoRuleMatched
        };
    }

    // ════════════════════════════════════════════════════════
    // PUBLIC: MDM — getMDMDecisionTableResults
    // ════════════════════════════════════════════════════════

    public static Map<String, Map<String, Object>> getMDMDecisionTableResults(Id caseId, Id currentStageId, String actionLabel, Boolean isEvaluateAll) {
        try {
            if (caseId == null || currentStageId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            String tableKey = TABLE_KEY_STAGE_TRANSITION;

            StageInfo stageInfo = queryStageInfo(currentStageId);
            List<FEC_MDM_Decision_Rule__c> allRules = queryMDMRulesByTableKey(tableKey);
            if (allRules.isEmpty()) return buildEmptyResultWithRevert(caseId, currentStageId);

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Decision_Rule__c r : allRules) ruleIds.add(r.Id);

            Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = queryMDMConditionsForRules(ruleIds);
            List<FEC_MDM_Decision_Rule__c> rules = filterMDMRulesByStage(allRules, conditionsByRule, stageInfo);
            if (rules.isEmpty()) return buildEmptyResultWithRevert(caseId, currentStageId);

            Map<String, Object> caseData = collectAllMDMCaseData(caseId, rules, conditionsByRule);
            Map<String, List<FEC_MDM_Decision_Rule__c>> rulesByDecisionLabel = groupMDMRulesByDecisionLabel(rules, conditionsByRule, actionLabel);
            Map<String, Map<String, Object>> result = evaluateMDMRuleGroups(rulesByDecisionLabel, conditionsByRule, caseData, isEvaluateAll);

            Map<String, Object> revertInfo = getRevertInfo(caseId, currentStageId);
            if (revertInfo != null) result.put('Revert', revertInfo);
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    public static List<FEC_MDM_Decision_Rule__c> queryMDMRulesByTableKey(String tableKey) {
        return [
            SELECT Id, Name, FEC_Priority__c
            FROM   FEC_MDM_Decision_Rule__c
            WHERE  FEC_Table_Key__c = :tableKey
            AND    FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    public static Map<Id, List<FEC_MDM_Decision_Condition__c>> queryMDMConditionsForRules(Set<Id> ruleIds) {
        List<FEC_MDM_Decision_Condition__c> allConditions = [
            SELECT Id, FEC_Decision_Rule__c, FEC_Type__c, FEC_Label__c,
                   FEC_Operator__c, FEC_Value__c, FEC_Expression__c, FEC_Order__c
            FROM   FEC_MDM_Decision_Condition__c
            WHERE  FEC_Decision_Rule__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];
        Map<Id, List<FEC_MDM_Decision_Condition__c>> grouped = new Map<Id, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Decision_Rule__c;
            if (!grouped.containsKey(ruleId)) grouped.put(ruleId, new List<FEC_MDM_Decision_Condition__c>());
            grouped.get(ruleId).add(cond);
        }
        return grouped;
    }

    private static Set<String> collectMDMFieldApiNames(List<FEC_MDM_Decision_Condition__c> conditions) {
        Set<String> fieldApiNames = new Set<String>();
        for (FEC_MDM_Decision_Condition__c cond : conditions) {
            if (cond.FEC_Type__c != 'Condition') continue;
            String label = cond.FEC_Label__c;
            if (String.isNotBlank(label) && !FIXED_LABELS.contains(label)) fieldApiNames.add(label);
            // FIELD(...) trong Value → load thêm field tham chiếu (so field-to-field)
            String refLabel = FEC_MDMConditionUtils.extractFieldRefLabel(cond.FEC_Value__c);
            if (String.isNotBlank(refLabel)) fieldApiNames.add(refLabel);
        }
        return fieldApiNames;
    }

    private static Boolean hasMDMConditionRowMatching(List<FEC_MDM_Decision_Condition__c> ruleConditions, String targetLabel, String expectedCode, String expectedName) {
        if (ruleConditions == null || ruleConditions.isEmpty()) return false;
        for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
            String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
            if (condType != 'Condition' || cond.FEC_Label__c != targetLabel) continue;
            String storedValue = cond.FEC_Value__c;
            if (String.isNotBlank(expectedCode) && expectedCode == storedValue) return true;
            if (String.isNotBlank(expectedName) && expectedName == storedValue) return true;
        }
        return false;
    }

    private static String getMDMActionValueByLabel(List<FEC_MDM_Decision_Condition__c> ruleConditions, String targetLabel) {
        if (ruleConditions == null) return null;
        for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
            if (cond.FEC_Type__c == 'Action' && cond.FEC_Label__c == targetLabel) return cond.FEC_Value__c;
        }
        return null;
    }

    public static Boolean evaluateMDMRuleConditions(List<FEC_MDM_Decision_Condition__c> conditions, Map<String, Object> caseData) {
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
            if (!isMDMLabelGroupMatched(conditionsByLabel.get(label), label, caseData)) return false;
        }
        return true;
    }

    private static Boolean isMDMLabelGroupMatched(List<FEC_MDM_Decision_Condition__c> labelConds, String label, Map<String, Object> caseData) {
        for (FEC_MDM_Decision_Condition__c cond : labelConds) {
            Object val = caseData.get(label.toLowerCase());
            String actualValue = val != null ? String.valueOf(val) : '';
            // Resolve FIELD(...) → giá trị field khác trên Case (so field-to-field); literal giữ nguyên.
            String compareValue = FEC_MDMConditionUtils.resolveConditionValue(cond.FEC_Value__c, caseData);
            if (FEC_MDMConditionUtils.evaluateCondition(actualValue, cond.FEC_Operator__c, compareValue, cond.FEC_Expression__c)) {
                return true;
            }
        }
        return false;
    }

    public static Map<String, Object> buildMatchResultFromConditions(Id ruleId, String ruleName, List<FEC_MDM_Decision_Condition__c> ruleConds) {
        Map<String, Object> result = new Map<String, Object>{
            'ruleId' => ruleId,
            'matched' => true
        };
        if (ruleConds == null) {
            return result;
        }
        for (FEC_MDM_Decision_Condition__c cond : ruleConds) {
            String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
            if (condType != 'Action') continue;
            String condLabel = cond.FEC_Label__c;
            String condValue = cond.FEC_Value__c;
            if (condLabel == 'Next Stage') {
                result.put('nextStageName', resolveStageNameFromCode(condValue));
                result.put('nextStageCode', condValue);
            } else if (condLabel == 'Next Queue') {
                result.put('nextQueue', condValue);
            } else if (condLabel == 'Team User Group') {
                result.put('teamUserGroup', condValue);
            } else if (condLabel == 'Available Decisions') {
                result.put('availableDecisions', condValue);
            } else if (condLabel == 'Action Button') {
                result.put('actionButtonName', condValue);
            } else if (String.isNotBlank(condLabel)) {
                // Generic fallback: cột tuỳ biến (vd: Auto, Custom Flag) — output theo camelCase key.
                result.put(toCamelCaseKey(condLabel), condValue);
            }
        }
        return result;
    }

    private static List<FEC_MDM_Decision_Rule__c> filterMDMRulesByStage(
        List<FEC_MDM_Decision_Rule__c> allRules,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule,
        StageInfo stageInfo
    ) {
        List<FEC_MDM_Decision_Rule__c> filtered = new List<FEC_MDM_Decision_Rule__c>();
        for (FEC_MDM_Decision_Rule__c rule : allRules) {
            List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            if (hasMDMConditionRowMatching(ruleConds, 'Previous Stage', stageInfo.code, stageInfo.name)
                || hasMDMConditionRowMatching(ruleConds, 'Current Stage', stageInfo.code, stageInfo.name)) {
                filtered.add(rule);
            }
        }
        return filtered;
    }

    private static Map<String, Object> collectAllMDMCaseData(
        Id caseId,
        List<FEC_MDM_Decision_Rule__c> rules,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule
    ) {
        List<FEC_MDM_Decision_Condition__c> allConds = new List<FEC_MDM_Decision_Condition__c>();
        for (FEC_MDM_Decision_Rule__c rule : rules) {
            List<FEC_MDM_Decision_Condition__c> conds = conditionsByRule.get(rule.Id);
            if (conds != null) allConds.addAll(conds);
        }
        Set<String> fieldApiNames = collectMDMFieldApiNames(allConds);
        return fieldApiNames.isEmpty() ? new Map<String, Object>() : queryCaseFields(caseId, fieldApiNames);
    }

    private static Map<String, List<FEC_MDM_Decision_Rule__c>> groupMDMRulesByDecisionLabel(
        List<FEC_MDM_Decision_Rule__c> rules,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule,
        String actionLabelFilter
    ) {
        Map<String, List<FEC_MDM_Decision_Rule__c>> grouped = new Map<String, List<FEC_MDM_Decision_Rule__c>>();
        for (FEC_MDM_Decision_Rule__c rule : rules) {
            List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            String decisionLabel = getMDMActionValueByLabel(ruleConds, 'Available Decisions');
            if (String.isBlank(decisionLabel)) continue;
            if (String.isNotBlank(actionLabelFilter) && !decisionLabel.equals(actionLabelFilter)) continue;
            if (!grouped.containsKey(decisionLabel)) grouped.put(decisionLabel, new List<FEC_MDM_Decision_Rule__c>());
            grouped.get(decisionLabel).add(rule);
        }
        return grouped;
    }

    private static Map<String, Map<String, Object>> evaluateMDMRuleGroups(
        Map<String, List<FEC_MDM_Decision_Rule__c>> rulesByDecisionLabel,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> caseData,
        Boolean isEvaluateAll
    ) {
        Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();
        for (String label : rulesByDecisionLabel.keySet()) {
            Map<String, Object> entry = evaluateOneMDMGroup(rulesByDecisionLabel.get(label), conditionsByRule, caseData, isEvaluateAll);
            if (entry != null) result.put(label, entry);
        }
        return result;
    }

    private static Map<String, Object> evaluateOneMDMGroup(
        List<FEC_MDM_Decision_Rule__c> groupRules,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> caseData,
        Boolean isEvaluateAll
    ) {
        List<Map<String, Object>> allRuleResults = new List<Map<String, Object>>();
        for (FEC_MDM_Decision_Rule__c rule : groupRules) {
            List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            Boolean isMatch = (ruleConds == null || ruleConds.isEmpty()) || evaluateMDMRuleConditions(ruleConds, caseData);
            if (isEvaluateAll) {
                allRuleResults.add(buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds));
            } else if (isMatch) {
                return buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
            }
        }
        if (isEvaluateAll && !allRuleResults.isEmpty()) {
            Map<String, Object> entry = (Map<String, Object>) allRuleResults[0].clone();
            if (allRuleResults.size() > 1) entry.put('rules', allRuleResults);
            return entry;
        }
        return null;
    }

    // ════════════════════════════════════════════════════════
    // INNER CLASSES
    // ════════════════════════════════════════════════════════

    private class StageInfo {
        public String name = '';
        public String code = '';
    }
}