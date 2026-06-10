/**
 * @description Service layer for MDM Decision Table CRUD operations
 *              (Save/Update/Delete + Test panel) on FEC_MDM_Decision_Rule__c.
 *              Extracted from FEC_StageTransitionEngine in Phase 2.3 refactor.
 *
 *              Reuses FEC_MDMConditionUtils for condition evaluation (DRY).
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.3
 */
public with sharing class FEC_StageTransitionExecutor {

    public static final String TABLE_KEY_STAGE_TRANSITION = FEC_StageTransitionResolver.TABLE_KEY_STAGE_TRANSITION;

    // ════════════════════════════════════════════════════════
    // GET RULES WITH CONDITIONS
    // ════════════════════════════════════════════════════════

    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId, String tableKey) {
        String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
        List<FEC_MDM_Decision_Rule__c> rules = queryRulesByKey(keyId, tableKey);

        Set<Id> ruleIds = new Set<Id>();
        for (FEC_MDM_Decision_Rule__c rule : rules) ruleIds.add(rule.Id);

        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = queryAllConditions(ruleIds);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (FEC_MDM_Decision_Rule__c rule : rules) {
            result.add(buildRuleEntry(rule, conditionsByRule.get(rule.Id)));
        }
        return result;
    }

    private static List<FEC_MDM_Decision_Rule__c> queryRulesByKey(String keyId, String tableKey) {
        if (String.isNotBlank(keyId)) {
            return [
                SELECT Id, Name, FEC_Priority__c, FEC_Active__c, FEC_Table_Key__c, FEC_Code__c, FEC_Key_ID__c
                FROM   FEC_MDM_Decision_Rule__c
                WHERE  FEC_Table_Key__c = :tableKey
                AND    FEC_Active__c = true
                AND    FEC_Key_ID__c = :keyId
                ORDER BY FEC_Priority__c ASC NULLS LAST
            ];
        }
        return [
            SELECT Id, Name, FEC_Priority__c, FEC_Active__c, FEC_Table_Key__c, FEC_Code__c, FEC_Key_ID__c
            FROM   FEC_MDM_Decision_Rule__c
            WHERE  FEC_Table_Key__c = :tableKey
            AND    FEC_Active__c = true
            ORDER BY FEC_Priority__c ASC NULLS LAST
        ];
    }

    private static Map<Id, List<FEC_MDM_Decision_Condition__c>> queryAllConditions(Set<Id> ruleIds) {
        List<FEC_MDM_Decision_Condition__c> allConditions = [
            SELECT Id, Name, FEC_Decision_Rule__c, FEC_Operator__c, FEC_Value__c,
                   FEC_Expression__c, FEC_Order__c, FEC_Type__c, FEC_Label__c
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

    private static Map<String, Object> buildRuleEntry(FEC_MDM_Decision_Rule__c rule, List<FEC_MDM_Decision_Condition__c> ruleConditions) {
        RuleLabels labels = new RuleLabels();
        List<Map<String, Object>> condList = buildConditionListAndLabels(ruleConditions, labels);

        return new Map<String, Object>{
            'rowId'               => rule.Id,
            'currentStage'        => labels.currentStage,
            'action'              => labels.action,
            'nextStage'           => labels.nextStage,
            'nextQueue'           => labels.nextQueue,
            'teamUserGroup'       => labels.teamUserGroup,
            'priority'            => rule.FEC_Priority__c,
            'active'              => rule.FEC_Active__c,
            'tableKey'            => rule.FEC_Table_Key__c,
            'availableDecisions'  => labels.availableDecisions,
            'customActions'       => labels.customActions,
            'processChangeStatus' => labels.processChangeStatus,
            'conditions'          => condList
        };
    }

    private static List<Map<String, Object>> buildConditionListAndLabels(
        List<FEC_MDM_Decision_Condition__c> ruleConditions, RuleLabels labels
    ) {
        List<Map<String, Object>> condList = new List<Map<String, Object>>();
        if (ruleConditions == null) return condList;
        for (FEC_MDM_Decision_Condition__c cond : ruleConditions) {
            String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
            String condLabel = cond.FEC_Label__c;
            extractKnownLabel(condType, condLabel, cond.FEC_Value__c, labels);
            condList.add(buildConditionMap(cond, condType));
        }
        return condList;
    }

    private static void extractKnownLabel(String condType, String condLabel, String value, RuleLabels labels) {
        if (condType == 'Condition') {
            if (condLabel == 'Previous Stage') labels.currentStage = value;
            else if (condLabel == 'Action Button') labels.action = value;
        } else if (condType == 'Action') {
            if (condLabel == 'Next Stage') labels.nextStage = value;
            else if (condLabel == 'Next Queue') labels.nextQueue = value;
            else if (condLabel == 'Team User Group') labels.teamUserGroup = value;
            else if (condLabel == 'Available Decisions') labels.availableDecisions = value;
            else if (condLabel == 'Process Change Status') labels.processChangeStatus = value;
            else if (condLabel == 'Custom Actions') labels.customActions = value;
        }
    }

    private static Map<String, Object> buildConditionMap(FEC_MDM_Decision_Condition__c cond, String condType) {
        return new Map<String, Object>{
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
        };
    }

    private class RuleLabels {
        public String currentStage;
        public String action;
        public String nextStage;
        public String nextQueue;
        public String teamUserGroup;
        public String availableDecisions;
        public String processChangeStatus;
        public String customActions;
    }

    // ════════════════════════════════════════════════════════
    // GET DECISION TABLE DATA
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> getDecisionTableData(Id businessProcessId, String tableKey) {
        List<Map<String, Object>> rules = getRulesWithConditions(businessProcessId, tableKey);
        Map<String, Map<String, Object>> columnMap = new Map<String, Map<String, Object>>();
        for (Map<String, Object> rule : rules) {
            collectColumnsFromRule(rule, columnMap);
        }
        return new Map<String, Object>{
            'conditionColumns' => columnMap.values(),
            'rules'            => rules
        };
    }

    private static void collectColumnsFromRule(Map<String, Object> rule, Map<String, Map<String, Object>> columnMap) {
        List<Object> conditions = (List<Object>) rule.get('conditions');
        if (conditions == null) return;
        for (Object condObj : conditions) {
            Map<String, Object> cond = (Map<String, Object>) condObj;
            String condType = (String) cond.get('type');
            String label = (String) cond.get('label');
            // Skip fixed labels (Previous Stage, Action Button) — these are not user-defined columns
            if (condType == 'Condition'
                && String.isNotBlank(label)
                && !FIXED_CONDITION_LABELS.contains(label)
                && !columnMap.containsKey(label)) {
                columnMap.put(label, new Map<String, Object>{
                    'fieldName'    => label,
                    'fieldApiName' => label,
                    'dataType'     => 'Text'
                });
            }
        }
    }

    /** Labels that are fixed/system-managed, NOT user-defined dynamic columns. */
    private static final Set<String> FIXED_CONDITION_LABELS = new Set<String>{
        'Previous Stage', 'Action Button'
    };

    // ════════════════════════════════════════════════════════
    // SAVE RULE WITH CONDITIONS
    // ════════════════════════════════════════════════════════

    public static String saveRuleWithConditions(String ruleData) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ruleData);
            FEC_MDM_Decision_Rule__c rule = upsertRuleFromPayload(payload);

            List<Object> conditionsRaw = (List<Object>) payload.get('conditions');
            if (conditionsRaw == null) conditionsRaw = new List<Object>();

            ConditionsResult parsed = parseConditions(conditionsRaw, rule.Id);
            deleteRemovedConditions(rule.Id, parsed.keepIds);
            if (!parsed.toUpsert.isEmpty()) upsert parsed.toUpsert;

            return rule.Id;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Save_Rule + ' ' + e.getMessage());
        }
    }

    private static FEC_MDM_Decision_Rule__c upsertRuleFromPayload(Map<String, Object> payload) {
        FEC_MDM_Decision_Rule__c rule = new FEC_MDM_Decision_Rule__c();
        if (payload.get('recordId') != null && String.valueOf(payload.get('recordId')) != 'null') {
            rule.Id = (Id) payload.get('recordId');
        }
        rule.FEC_Priority__c = payload.get('priority') != null
            ? Decimal.valueOf(String.valueOf(payload.get('priority'))) : 1;
        rule.FEC_Active__c = true;

        String tableKeyVal = (String) payload.get('tableKey');
        if (String.isNotBlank(tableKeyVal)) rule.FEC_Table_Key__c = tableKeyVal;
        if (payload.containsKey('code'))    rule.FEC_Code__c = (String) payload.get('code');
        if (payload.containsKey('keyId'))   rule.FEC_Key_ID__c = (String) payload.get('keyId');

        upsert rule;
        return rule;
    }

    private static ConditionsResult parseConditions(List<Object> conditionsRaw, Id ruleId) {
        ConditionsResult result = new ConditionsResult();
        for (Object condObj : conditionsRaw) {
            Map<String, Object> cond = (Map<String, Object>) condObj;
            FEC_MDM_Decision_Condition__c rec = buildConditionRecord(cond, ruleId, result.keepIds);
            result.toUpsert.add(rec);
        }
        return result;
    }

    private static FEC_MDM_Decision_Condition__c buildConditionRecord(
        Map<String, Object> cond, Id ruleId, Set<Id> keepIds
    ) {
        String condId = cond.get('id') != null ? String.valueOf(cond.get('id')) : null;
        FEC_MDM_Decision_Condition__c rec = new FEC_MDM_Decision_Condition__c();

        if (String.isNotBlank(condId) && condId != 'null' && !condId.startsWith('new-')) {
            rec.Id = (Id) condId;
            keepIds.add(rec.Id);
        } else {
            rec.FEC_Decision_Rule__c = ruleId;
        }

        String operatorVal = (String) cond.get('operator');
        if (operatorVal == 'BETWEEN') operatorVal = '>=';
        rec.FEC_Operator__c   = operatorVal;
        rec.FEC_Value__c      = (String) cond.get('value');
        rec.FEC_Expression__c = (String) cond.get('expression');
        rec.FEC_Order__c      = cond.get('order') != null ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null;
        rec.FEC_Type__c       = cond.get('type') != null ? (String) cond.get('type') : 'Condition';
        rec.FEC_Label__c      = (String) cond.get('label');
        return rec;
    }

    private static void deleteRemovedConditions(Id ruleId, Set<Id> keepIds) {
        List<FEC_MDM_Decision_Condition__c> toDelete = [
            SELECT Id FROM FEC_MDM_Decision_Condition__c
            WHERE  FEC_Decision_Rule__c = :ruleId
            AND    Id NOT IN :keepIds
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private class ConditionsResult {
        Set<Id> keepIds = new Set<Id>();
        List<FEC_MDM_Decision_Condition__c> toUpsert = new List<FEC_MDM_Decision_Condition__c>();
    }

    // ════════════════════════════════════════════════════════
    // DELETE OPERATIONS
    // ════════════════════════════════════════════════════════

    public static void deleteRule(Id ruleId) {
        if (!FEC_MDM_Decision_Rule__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        delete [SELECT Id FROM FEC_MDM_Decision_Rule__c WHERE Id = :ruleId];
    }

    public static Integer deleteAllRulesByBP(Id businessProcessId, String tableKey) {
        if (!FEC_MDM_Decision_Rule__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        if (businessProcessId == null) {
            throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
        }
        if (String.isBlank(tableKey)) tableKey = TABLE_KEY_STAGE_TRANSITION;

        List<FEC_MDM_Decision_Rule__c> rulesToDelete = [
            SELECT Id FROM FEC_MDM_Decision_Rule__c
            WHERE FEC_Key_ID__c = :String.valueOf(businessProcessId)
            AND   FEC_Table_Key__c = :tableKey
        ];
        Integer count = rulesToDelete.size();
        if (count > 0) delete rulesToDelete;
        return count;
    }

    public static void deleteConditionColumn(Id businessProcessId, String labelText, String tableKey) {
        if (!FEC_MDM_Decision_Condition__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
        List<FEC_MDM_Decision_Condition__c> toDelete = queryConditionsByLabel(keyId, labelText, tableKey);
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private static List<FEC_MDM_Decision_Condition__c> queryConditionsByLabel(String keyId, String labelText, String tableKey) {
        if (String.isNotBlank(keyId)) {
            return [
                SELECT Id FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Label__c = :labelText
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
            ];
        }
        return [
            SELECT Id FROM FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = :labelText
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
        ];
    }

    // ════════════════════════════════════════════════════════
    // UPDATE COLUMN PROPERTIES
    // ════════════════════════════════════════════════════════

    public static void updateColumnProperties(Id businessProcessId, String labelText, String newOperator, String newExpression, String tableKey) {
        try {
            if (String.isBlank(labelText)) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (!FEC_MDM_Decision_Condition__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
            }

            String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;
            List<FEC_MDM_Decision_Condition__c> conditions = queryConditionsByLabelForUpdate(keyId, labelText, tableKey);
            if (conditions.isEmpty()) return;

            String mappedOperator = mapOperatorValue(newOperator);
            applyColumnUpdates(conditions, mappedOperator, newExpression);
            update Security.stripInaccessible(AccessType.UPDATABLE, conditions).getRecords();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission + ' ' + e.getMessage());
        }
    }

    private static List<FEC_MDM_Decision_Condition__c> queryConditionsByLabelForUpdate(String keyId, String labelText, String tableKey) {
        if (String.isNotBlank(keyId)) {
            return [
                SELECT Id, FEC_Operator__c, FEC_Expression__c
                FROM   FEC_MDM_Decision_Condition__c
                WHERE  FEC_Label__c = :labelText
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
            ];
        }
        return [
            SELECT Id, FEC_Operator__c, FEC_Expression__c
            FROM   FEC_MDM_Decision_Condition__c
            WHERE  FEC_Label__c = :labelText
            AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
        ];
    }

    private static String mapOperatorValue(String newOperator) {
        Map<String, String> operatorMap = new Map<String, String>{
            'EQUALS' => '=', 'NOT_EQUALS' => '!=', 'GREATER_THAN' => '>',
            'LESS_THAN' => '<', 'GREATER_THAN_OR_EQUAL' => '>=', 'LESS_THAN_OR_EQUAL' => '<=',
            'IN' => 'IN', 'NOT_IN' => 'NOT IN', 'CONTAINS' => 'Contains',
            'STARTS_WITH' => 'Starts With', 'ENDS_WITH' => 'Ends With'
        };
        return operatorMap.containsKey(newOperator) ? operatorMap.get(newOperator) : newOperator;
    }

    private static void applyColumnUpdates(List<FEC_MDM_Decision_Condition__c> conditions, String mappedOperator, String newExpression) {
        Boolean isBetween = (mappedOperator == 'BETWEEN');
        for (FEC_MDM_Decision_Condition__c cond : conditions) {
            if (!isBetween) cond.FEC_Operator__c = mappedOperator;
            cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
        }
    }

    // ════════════════════════════════════════════════════════
    // GET FIELDS FOR BUSINESS PROCESS (for LWC dropdown)
    // ════════════════════════════════════════════════════════

    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId, String tableKey) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Set<String> seen = new Set<String>();
            String keyId = businessProcessId != null ? String.valueOf(businessProcessId) : null;

            addExistingConditionLabels(keyId, tableKey, options, seen);
            addCaseFields(options, seen);
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }

    private static void addExistingConditionLabels(String keyId, String tableKey, List<Map<String, String>> options, Set<String> seen) {
        List<FEC_MDM_Decision_Condition__c> conditionLabels;
        if (String.isNotBlank(keyId)) {
            conditionLabels = [
                SELECT FEC_Label__c FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Type__c = 'Condition'
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                AND    FEC_Decision_Rule__r.FEC_Key_ID__c = :keyId
                AND    FEC_Label__c != null
                ORDER BY FEC_Label__c ASC
            ];
        } else {
            conditionLabels = [
                SELECT FEC_Label__c FROM FEC_MDM_Decision_Condition__c
                WHERE  FEC_Type__c = 'Condition'
                AND    FEC_Decision_Rule__r.FEC_Table_Key__c = :tableKey
                AND    FEC_Label__c != null
                ORDER BY FEC_Label__c ASC
            ];
        }
        for (FEC_MDM_Decision_Condition__c cond : conditionLabels) {
            String labelText = cond.FEC_Label__c;
            if (String.isBlank(labelText) || seen.contains(labelText)) continue;
            // Skip fixed/system labels — they are not user-defined dynamic fields
            if (FIXED_CONDITION_LABELS.contains(labelText)) continue;
            seen.add(labelText);
            options.add(new Map<String, String>{
                'label'        => labelText,
                'value'        => labelText,
                'fieldApiName' => labelText,
                'dataType'     => 'Text'
            });
        }
    }

    private static void addCaseFields(List<Map<String, String>> options, Set<String> seen) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        Set<String> standardWhitelist = new Set<String>{ 'Priority', 'Status', 'Origin', 'Type', 'Reason' };
        for (String fieldName : caseFields.keySet()) {
            Schema.DescribeFieldResult dfr = caseFields.get(fieldName).getDescribe();
            if (!dfr.isCustom() && !standardWhitelist.contains(dfr.getName())) continue;
            String apiName = dfr.getName();
            if (seen.contains(apiName)) continue;
            seen.add(apiName);
            options.add(buildCaseFieldOption(dfr, apiName));
        }
    }

    private static Map<String, String> buildCaseFieldOption(Schema.DescribeFieldResult dfr, String apiName) {
        return new Map<String, String>{
            'label'        => dfr.getLabel() + ' (' + apiName + ')',
            'value'        => apiName,
            'fieldApiName' => apiName,
            'dataType'     => mapDataType(dfr.getType())
        };
    }

    private static String mapDataType(Schema.DisplayType dt) {
        if (dt == Schema.DisplayType.INTEGER || dt == Schema.DisplayType.DOUBLE
            || dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.PERCENT) return 'Number';
        if (dt == Schema.DisplayType.BOOLEAN) return 'Boolean';
        if (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.MULTIPICKLIST) return 'Picklist';
        if (dt == Schema.DisplayType.DATE) return 'Date';
        return 'Text';
    }

    // ════════════════════════════════════════════════════════
    // TEST RULE EVALUATION
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> testRuleEvaluation(Id businessProcessId, Map<String, String> fieldValues, String tableKey) {
        try {
            Map<String, Object> normalizedValues = normalizeFieldValues(fieldValues);
            List<FEC_MDM_Decision_Rule__c> rules = FEC_StageTransitionResolver.queryMDMRulesByTableKey(tableKey);

            if (rules.isEmpty()) return buildNoMatchTraceResponse();

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Decision_Rule__c r : rules) ruleIds.add(r.Id);
            Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule = FEC_StageTransitionResolver.queryMDMConditionsForRules(ruleIds);

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

    private static Map<String, Object> buildNoMatchTraceResponse() {
        return new Map<String, Object>{
            'matched'         => false,
            'message'         => System.Label.FEC_Error_NoRuleMatched,
            'evaluationTrace' => new List<Map<String, Object>>()
        };
    }

    private static Map<String, Object> evaluateRulesWithTrace(
        List<FEC_MDM_Decision_Rule__c> rules,
        Map<Id, List<FEC_MDM_Decision_Condition__c>> conditionsByRule,
        Map<String, Object> normalizedValues
    ) {
        List<Map<String, Object>> trace = new List<Map<String, Object>>();
        Boolean alreadyMatched = false;
        Map<String, Object> matchResult = null;

        for (FEC_MDM_Decision_Rule__c rule : rules) {
            List<FEC_MDM_Decision_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
            TraceContext ctx = extractTraceContext(ruleConds);
            Map<String, Object> ruleTrace = buildRuleTraceShell(rule, ctx);

            if (alreadyMatched) {
                ruleTrace.put('result', 'NOT_EVALUATED');
                ruleTrace.put('conditions', new List<Map<String, Object>>());
                trace.add(ruleTrace);
                continue;
            }

            if (ctx.conditionRows.isEmpty()) {
                ruleTrace.put('result', 'MATCH');
                ruleTrace.put('conditions', new List<Map<String, Object>>());
                trace.add(ruleTrace);
                alreadyMatched = true;
                matchResult = FEC_StageTransitionResolver.buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
                matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                continue;
            }

            List<Map<String, Object>> condTrace = new List<Map<String, Object>>();
            Boolean ruleMatched = evaluateConditionsWithTrace(ctx.conditionRows, normalizedValues, condTrace);
            ruleTrace.put('result', ruleMatched ? 'MATCH' : 'NOT_MATCH');
            ruleTrace.put('conditions', condTrace);
            trace.add(ruleTrace);

            if (ruleMatched) {
                alreadyMatched = true;
                matchResult = FEC_StageTransitionResolver.buildMatchResultFromConditions(rule.Id, rule.Name, ruleConds);
                matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
            }
        }
        return buildTraceResponse(trace, matchResult);
    }

    private static Map<String, Object> buildTraceResponse(List<Map<String, Object>> trace, Map<String, Object> matchResult) {
        Map<String, Object> response = new Map<String, Object>{ 'evaluationTrace' => trace };
        if (matchResult != null) {
            response.putAll(matchResult);
        } else {
            response.put('matched', false);
            response.put('message', System.Label.FEC_Error_NoRuleMatched);
        }
        return response;
    }

    private static TraceContext extractTraceContext(List<FEC_MDM_Decision_Condition__c> ruleConds) {
        TraceContext ctx = new TraceContext();
        if (ruleConds == null) return ctx;
        for (FEC_MDM_Decision_Condition__c cond : ruleConds) {
            String condType = cond.FEC_Type__c != null ? cond.FEC_Type__c : 'Condition';
            String condLabel = cond.FEC_Label__c;
            extractTraceLabel(ctx, condType, condLabel, cond.FEC_Value__c);
            if (condType == 'Condition') ctx.conditionRows.add(cond);
        }
        return ctx;
    }

    private static void extractTraceLabel(TraceContext ctx, String condType, String condLabel, String value) {
        if (condType == 'Condition') {
            if (condLabel == 'Previous Stage') ctx.previousStage = value;
            else if (condLabel == 'Action Button') ctx.action = value;
        } else if (condType == 'Action') {
            if (condLabel == 'Next Stage') ctx.nextStage = value;
            else if (condLabel == 'Next Queue') ctx.nextQueue = value;
            else if (condLabel == 'Team User Group') ctx.team = value;
            else if (condLabel == 'Available Decisions') ctx.availableDecisions = value;
        }
    }

    private static Map<String, Object> buildRuleTraceShell(FEC_MDM_Decision_Rule__c rule, TraceContext ctx) {
        return new Map<String, Object>{
            'ruleId'             => rule.Id,
            'ruleName'           => rule.Name,
            'priority'           => rule.FEC_Priority__c,
            'previousStage'      => ctx.previousStage,
            'action'             => ctx.action,
            'availableDecisions' => ctx.availableDecisions,
            'nextStage'          => ctx.nextStage,
            'nextQueue'          => ctx.nextQueue,
            'team'               => ctx.team
        };
    }

    private class TraceContext {
        public String previousStage;
        public String action;
        public String nextStage;
        public String nextQueue;
        public String team;
        public String availableDecisions;
        public List<FEC_MDM_Decision_Condition__c> conditionRows = new List<FEC_MDM_Decision_Condition__c>();
    }

    private static Boolean evaluateConditionsWithTrace(
        List<FEC_MDM_Decision_Condition__c> conditions,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        Map<String, List<FEC_MDM_Decision_Condition__c>> byLabel = groupConditionsByLabel(conditions);
        Boolean allGroupsMatch = true;
        for (String label : byLabel.keySet()) {
            if (!evaluateLabelGroupWithTrace(byLabel.get(label), fieldValues, condTrace)) {
                allGroupsMatch = false;
            }
        }
        return allGroupsMatch;
    }

    private static Map<String, List<FEC_MDM_Decision_Condition__c>> groupConditionsByLabel(List<FEC_MDM_Decision_Condition__c> conditions) {
        Map<String, List<FEC_MDM_Decision_Condition__c>> byLabel = new Map<String, List<FEC_MDM_Decision_Condition__c>>();
        for (FEC_MDM_Decision_Condition__c c : conditions) {
            String condType = c.FEC_Type__c != null ? c.FEC_Type__c : 'Condition';
            if (condType != 'Condition') continue;
            String label = c.FEC_Label__c;
            if (String.isBlank(label)) continue;
            if (!byLabel.containsKey(label)) byLabel.put(label, new List<FEC_MDM_Decision_Condition__c>());
            byLabel.get(label).add(c);
        }
        return byLabel;
    }

    private static Boolean evaluateLabelGroupWithTrace(
        List<FEC_MDM_Decision_Condition__c> labelConds,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        Boolean groupMatched = false;
        for (FEC_MDM_Decision_Condition__c cond : labelConds) {
            String apiName = cond.FEC_Label__c;
            String actualValue = '';
            if (String.isNotBlank(apiName)) {
                Object val = fieldValues.get(apiName.toLowerCase());
                actualValue = val != null ? String.valueOf(val) : '';
            }
            Boolean condResult = FEC_MDMConditionUtils.evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c);
            condTrace.add(buildConditionTrace(cond, apiName, actualValue, condResult));
            if (condResult) groupMatched = true;
        }
        return groupMatched;
    }

    private static Map<String, Object> buildConditionTrace(
        FEC_MDM_Decision_Condition__c cond, String apiName, String actualValue, Boolean condResult
    ) {
        return new Map<String, Object>{
            'fieldLabel'    => cond.FEC_Label__c,
            'fieldApiName'  => apiName,
            'operator'      => cond.FEC_Operator__c,
            'expectedValue' => cond.FEC_Value__c,
            'actualValue'   => actualValue,
            'expression'    => cond.FEC_Expression__c,
            'result'        => condResult
        };
    }
}