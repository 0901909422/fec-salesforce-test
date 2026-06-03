/**
 * @description Service layer for MDM Decision Table CRUD operations.
 *              Extracted from FEC_MDM_WorkflowEngine in Phase 2.2 refactor.
 *              Handles: get rules, save rule, get table data, delete rule,
 *              delete condition column, update column properties.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.2
 */
public with sharing class FEC_MDMDecisionTableService {

    /**
     * Get all active stage change rules with their conditions for a Business Process.
     * Issue #4: Apply stripInaccessible to enforce FLS/CRUD on rule + condition records.
     */
    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId) {
        List<FEC_MDM_Stage_Change__c> rules = queryActiveRules(businessProcessId);

        Set<Id> ruleIds = new Set<Id>();
        for (FEC_MDM_Stage_Change__c rule : rules) {
            ruleIds.add(rule.Id);
        }

        List<FEC_MDM_Stage_Change_Condition__c> allConditions = queryConditionsByRules(ruleIds);
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = groupConditionsByRule(allConditions);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (FEC_MDM_Stage_Change__c rule : rules) {
            result.add(buildRuleResult(rule, conditionsByRule.get(rule.Id)));
        }
        return result;
    }

    private static List<FEC_MDM_Stage_Change__c> queryActiveRules(Id businessProcessId) {
        return (List<FEC_MDM_Stage_Change__c>) Security.stripInaccessible(
            AccessType.READABLE,
            [
                SELECT  Id, Name,
                        FEC_Previous_Stage__c,
                        FEC_Previous_Stage__r.Name,
                        FEC_Previous_Stage__r.FEC_Code__c,
                        FEC_Action_Button__c,
                        FEC_Action_Button__r.Name,
                        FEC_Action_Button__r.FEC_Code__c,
                        FEC_Next_Stage__c,
                        FEC_Next_Stage__r.Name,
                        FEC_Next_Stage__r.FEC_Code__c,
                        FEC_Next_Queue__c,
                        FEC_Team_User_Group__c,
                        FEC_Priority__c,
                        FEC_Active__c,
                        FEC_Condition_Logic__c,
                        FEC_Condition_Requirement__c,
                        Process_Change_Status__c
                FROM    FEC_MDM_Stage_Change__c
                WHERE   FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
                AND     FEC_Active__c = true
                ORDER BY FEC_Previous_Stage__r.Name ASC,
                         FEC_Priority__c ASC NULLS LAST
            ]
        ).getRecords();
    }

    private static List<FEC_MDM_Stage_Change_Condition__c> queryConditionsByRules(Set<Id> ruleIds) {
        return (List<FEC_MDM_Stage_Change_Condition__c>) Security.stripInaccessible(
            AccessType.READABLE,
            [
                SELECT  Id, Name,
                        FEC_Stage_Change__c,
                        FEC_Master_Data_Setting__c,
                        FEC_Master_Data_Setting__r.FEC_Field_Label_Name__c,
                        FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                        FEC_Master_Data_Setting__r.FEC_Field_Object_Name__c,
                        FEC_Operator__c, FEC_Value__c,
                        FEC_Expression__c, FEC_Order__c
                FROM    FEC_MDM_Stage_Change_Condition__c
                WHERE   FEC_Stage_Change__c IN :ruleIds
                ORDER BY FEC_Order__c ASC NULLS LAST
            ]
        ).getRecords();
    }

    private static Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> groupConditionsByRule(
        List<FEC_MDM_Stage_Change_Condition__c> conditions
    ) {
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> grouped = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
            Id ruleId = cond.FEC_Stage_Change__c;
            if (!grouped.containsKey(ruleId)) {
                grouped.put(ruleId, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            grouped.get(ruleId).add(cond);
        }
        return grouped;
    }

    private static Map<String, Object> buildRuleResult(
        FEC_MDM_Stage_Change__c rule,
        List<FEC_MDM_Stage_Change_Condition__c> ruleConditions
    ) {
        List<Map<String, Object>> condList = new List<Map<String, Object>>();
        if (ruleConditions != null) {
            for (FEC_MDM_Stage_Change_Condition__c cond : ruleConditions) {
                condList.add(buildConditionMap(cond));
            }
        }
        return new Map<String, Object>{
            'rowId'                => rule.Id,
            'currentStage'         => rule.FEC_Previous_Stage__r?.Name,
            'currentStageId'       => rule.FEC_Previous_Stage__c,
            'currentStageCode'     => rule.FEC_Previous_Stage__r?.FEC_Code__c,
            'action'               => rule.FEC_Action_Button__r?.Name,
            'actionId'             => rule.FEC_Action_Button__c,
            'actionCode'           => rule.FEC_Action_Button__r?.FEC_Code__c,
            'nextStage'            => rule.FEC_Next_Stage__r?.Name,
            'nextStageId'          => rule.FEC_Next_Stage__c,
            'nextStageCode'        => rule.FEC_Next_Stage__r?.FEC_Code__c,
            'nextQueue'            => rule.FEC_Next_Queue__c,
            'teamUserGroup'        => rule.FEC_Team_User_Group__c,
            'priority'             => rule.FEC_Priority__c,
            'active'               => rule.FEC_Active__c,
            'conditionLogic'       => rule.FEC_Condition_Logic__c,
            'conditionRequirement' => rule.FEC_Condition_Requirement__c,
            'processChangeStatus'  => rule.Process_Change_Status__c,
            'conditions'           => condList
        };
    }

    private static Map<String, Object> buildConditionMap(FEC_MDM_Stage_Change_Condition__c cond) {
        return new Map<String, Object>{
            'id'           => cond.Id,
            'conditionName'=> cond.Name,
            'fieldId'      => cond.FEC_Master_Data_Setting__c,
            'fieldName'    => cond.FEC_Master_Data_Setting__r?.FEC_Field_Label_Name__c,
            'fieldApiName' => cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c,
            'fieldType'    => FEC_MDMConditionUtils.resolveFieldDataType(
                cond.FEC_Master_Data_Setting__r?.FEC_Field_Object_Name__c,
                cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c
            ),
            'operator'     => cond.FEC_Operator__c,
            'value'        => cond.FEC_Value__c,
            'expression'   => cond.FEC_Expression__c,
            'order'        => cond.FEC_Order__c
        };
    }

    // ════════════════════════════════════════════════════════
    // SAVE RULE WITH CONDITIONS — Issue #5: CRUD enforcement
    // ════════════════════════════════════════════════════════

    public static String saveRuleWithConditions(String ruleData) {
        try {
            verifyCRUDPermissions();

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ruleData);
            FEC_MDM_Stage_Change__c rule = upsertRuleFromPayload(payload);

            List<Object> conditionsRaw = (List<Object>) payload.get('conditions');
            if (conditionsRaw == null) conditionsRaw = new List<Object>();

            ConditionUpsertResult parsedConds = parseConditions(conditionsRaw, rule.Id);
            deleteRemovedConditions(rule.Id, parsedConds.keepIds);
            if (!parsedConds.toUpsert.isEmpty()) upsert parsedConds.toUpsert;

            return rule.Id;
        } catch (Exception e) {
            System.debug('Error in saveRuleWithConditions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Save_Rule + ' ' + e.getMessage());
        }
    }

    private static void verifyCRUDPermissions() {
        Schema.DescribeSObjectResult ruleDescribe = FEC_MDM_Stage_Change__c.SObjectType.getDescribe();
        Schema.DescribeSObjectResult condDescribe = FEC_MDM_Stage_Change_Condition__c.SObjectType.getDescribe();
        if (!ruleDescribe.isCreateable() || !ruleDescribe.isUpdateable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
        }
        if (!condDescribe.isCreateable() || !condDescribe.isUpdateable() || !condDescribe.isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
        }
    }

    private static FEC_MDM_Stage_Change__c upsertRuleFromPayload(Map<String, Object> payload) {
        FEC_MDM_Stage_Change__c rule = new FEC_MDM_Stage_Change__c();
        if (payload.get('recordId') != null && String.valueOf(payload.get('recordId')) != 'null') {
            rule.Id = (Id) payload.get('recordId');
        }
        rule.FEC_Previous_Stage__c  = (Id)     payload.get('previousStageId');
        rule.FEC_Action_Button__c   = (Id)     payload.get('actionButtonId');
        rule.FEC_Next_Stage__c      = (Id)     payload.get('nextStageId');
        rule.FEC_Next_Queue__c      = (String) payload.get('nextQueue');
        rule.FEC_Team_User_Group__c = (String) payload.get('teamUserGroup');
        rule.FEC_Priority__c        = payload.get('priority') != null
                                      ? Decimal.valueOf(String.valueOf(payload.get('priority'))) : 1;
        rule.FEC_Condition_Requirement__c = (String) payload.get('conditionRequirement');
        rule.FEC_Condition_Logic__c       = (String) payload.get('conditionLogic');
        rule.FEC_Active__c                = true;
        upsert rule;
        return rule;
    }

    private static ConditionUpsertResult parseConditions(List<Object> conditionsRaw, Id ruleId) {
        ConditionUpsertResult result = new ConditionUpsertResult();
        for (Object condObj : conditionsRaw) {
            Map<String, Object> cond = (Map<String, Object>) condObj;
            FEC_MDM_Stage_Change_Condition__c rec = buildConditionRecord(cond, ruleId, result.keepIds);
            result.toUpsert.add(rec);
        }
        return result;
    }

    private static FEC_MDM_Stage_Change_Condition__c buildConditionRecord(
        Map<String, Object> cond, Id ruleId, Set<Id> keepIds
    ) {
        String condId = cond.get('id') != null ? String.valueOf(cond.get('id')) : null;
        String rawFieldId = cond.get('fieldId') != null ? String.valueOf(cond.get('fieldId')) : null;
        Id parsedFieldId = String.isNotBlank(rawFieldId) && rawFieldId != 'null' ? (Id) rawFieldId : null;

        FEC_MDM_Stage_Change_Condition__c rec = new FEC_MDM_Stage_Change_Condition__c();
        if (String.isNotBlank(condId) && condId != 'null' && !condId.startsWith('new-')) {
            rec.Id = (Id) condId;
            keepIds.add(rec.Id);
        } else {
            rec.FEC_Stage_Change__c = ruleId;
        }
        rec.FEC_Master_Data_Setting__c = parsedFieldId;
        String operatorVal = (String) cond.get('operator');
        if (operatorVal == 'BETWEEN') operatorVal = '>=';
        rec.FEC_Operator__c   = operatorVal;
        rec.FEC_Value__c      = (String) cond.get('value');
        rec.FEC_Expression__c = (String) cond.get('expression');
        rec.FEC_Order__c      = cond.get('order') != null ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null;
        return rec;
    }

    private static void deleteRemovedConditions(Id ruleId, Set<Id> keepIds) {
        List<FEC_MDM_Stage_Change_Condition__c> toDelete = [
            SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
            WHERE  FEC_Stage_Change__c = :ruleId
            AND    Id NOT IN :keepIds
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private class ConditionUpsertResult {
        Set<Id> keepIds = new Set<Id>();
        List<FEC_MDM_Stage_Change_Condition__c> toUpsert = new List<FEC_MDM_Stage_Change_Condition__c>();
    }

    // ════════════════════════════════════════════════════════
    // GET DECISION TABLE DATA (rules + columns)
    // ════════════════════════════════════════════════════════

    public static Map<String, Object> getDecisionTableData(Id businessProcessId) {
        List<Map<String, Object>> rules = getRulesWithConditions(businessProcessId);
        Map<Id, Map<String, Object>> columnMap = new Map<Id, Map<String, Object>>();

        for (Map<String, Object> rule : rules) {
            List<Object> conditions = (List<Object>) rule.get('conditions');
            if (conditions == null) continue;
            for (Object condObj : conditions) {
                Map<String, Object> cond = (Map<String, Object>) condObj;
                Id fieldId = (Id) cond.get('fieldId');
                if (fieldId != null && !columnMap.containsKey(fieldId)) {
                    columnMap.put(fieldId, new Map<String, Object>{
                        'fieldId'      => fieldId,
                        'fieldName'    => cond.get('fieldName'),
                        'fieldApiName' => cond.get('fieldApiName'),
                        'dataType'     => cond.get('fieldType')
                    });
                }
            }
        }

        return new Map<String, Object>{
            'conditionColumns' => columnMap.values(),
            'rules'            => rules
        };
    }

    // ════════════════════════════════════════════════════════
    // DELETE OPERATIONS
    // ════════════════════════════════════════════════════════

    public static void deleteRule(Id ruleId) {
        if (!FEC_MDM_Stage_Change__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        if (!FEC_MDM_Stage_Change_Condition__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        List<FEC_MDM_Stage_Change_Condition__c> conditions = [
            SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
            WHERE FEC_Stage_Change__c = :ruleId
        ];
        if (!conditions.isEmpty()) delete conditions;
        delete [SELECT Id FROM FEC_MDM_Stage_Change__c WHERE Id = :ruleId];
    }

    public static void deleteConditionColumn(Id businessProcessId, Id masterDataSettingId) {
        if (!FEC_MDM_Stage_Change_Condition__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        List<FEC_MDM_Stage_Change_Condition__c> toDelete = [
            SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
            WHERE FEC_Master_Data_Setting__c = :masterDataSettingId
            AND   FEC_Stage_Change__r.FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
        ];
        if (!toDelete.isEmpty()) delete toDelete;
    }

    // ════════════════════════════════════════════════════════
    // UPDATE COLUMN PROPERTIES
    // ════════════════════════════════════════════════════════

    public static void updateColumnProperties(
        Id businessProcessId, Id masterDataSettingId, String newOperator, String newExpression
    ) {
        try {
            if (businessProcessId == null || masterDataSettingId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }
            if (!FEC_MDM_Stage_Change_Condition__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Update_Permission);
            }

            List<FEC_MDM_Stage_Change_Condition__c> conditions = [
                SELECT Id, FEC_Operator__c, FEC_Expression__c
                FROM FEC_MDM_Stage_Change_Condition__c
                WHERE FEC_Master_Data_Setting__c = :masterDataSettingId
                AND   FEC_Stage_Change__r.FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
            ];

            if (conditions.isEmpty()) return;

            String mappedOperator = mapOperatorValue(newOperator);
            applyColumnUpdates(conditions, mappedOperator, newExpression);
            update conditions;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Không thể cập nhật cột: ' + e.getMessage());
        }
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

    private static void applyColumnUpdates(
        List<FEC_MDM_Stage_Change_Condition__c> conditions, String mappedOperator, String newExpression
    ) {
        Boolean isBetween = (mappedOperator == 'BETWEEN');
        for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
            if (!isBetween) cond.FEC_Operator__c = mappedOperator;
            cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
        }
    }
}