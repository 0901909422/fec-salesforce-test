public with sharing class FEC_MDM_WorkflowEngine {

    // ════════════════════════════════════════════════════════
    // GET RULES WITH CONDITIONS (for LWC Decision Table)
    // ════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getRulesWithConditions(Id businessProcessId) {
        List<FEC_MDM_Stage_Change__c> rules = [
            SELECT  Id,
                    Name,
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
                    Process_Change_Status__c,
                    (
                        SELECT  Id,
                                Name,
                                FEC_Additional_Field__c,
                                FEC_Additional_Field__r.Name,
                                FEC_Additional_Field__r.FEC_Code__c,
                                FEC_Additional_Field__r.FEC_Name_VN__c,
                                FEC_Additional_Field__r.FEC_Type__c,
                                FEC_Additional_Field__r.FEC_Unique_ID__c,
                                FEC_Operator__c,
                                FEC_Value__c,
                                FEC_Value_Type__c,
                                FEC_Order__c
                        FROM    FEC_MDM_Stage_Change_Conditions__r
                        ORDER BY FEC_Order__c ASC NULLS LAST
                    )
            FROM    FEC_MDM_Stage_Change__c
            WHERE   FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
            AND     FEC_Active__c = true
            ORDER BY FEC_Previous_Stage__r.Name ASC,
                     FEC_Priority__c ASC NULLS LAST
        ];

        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (FEC_MDM_Stage_Change__c rule : rules) {
            // ── Build condition list ──
            List<Map<String, Object>> condList = new List<Map<String, Object>>();
            for (FEC_MDM_Stage_Change_Condition__c cond : rule.FEC_MDM_Stage_Change_Conditions__r) {
                condList.add(new Map<String, Object>{
                    'id'            => cond.Id,
                    'conditionName' => cond.Name,
                    'fieldId'       => cond.FEC_Additional_Field__c,
                    'fieldName'     => cond.FEC_Additional_Field__r?.Name,
                    'fieldNameVN'   => cond.FEC_Additional_Field__r?.FEC_Name_VN__c,
                    'fieldCode'     => cond.FEC_Additional_Field__r?.FEC_Code__c,
                    'fieldApiName'  => cond.FEC_Additional_Field__r?.FEC_Unique_ID__c,
                    'fieldType'     => cond.FEC_Additional_Field__r?.FEC_Type__c,
                    'operator'      => cond.FEC_Operator__c,
                    'value'         => cond.FEC_Value__c,
                    'valueType'     => cond.FEC_Value_Type__c,
                    'order'         => cond.FEC_Order__c
                });
            }

            result.add(new Map<String, Object>{
                'rowId'               => rule.Id,
                'currentStage'        => rule.FEC_Previous_Stage__r?.Name,
                'currentStageId'      => rule.FEC_Previous_Stage__c,
                'currentStageCode'    => rule.FEC_Previous_Stage__r?.FEC_Code__c,
                'action'              => rule.FEC_Action_Button__r?.Name,
                'actionId'            => rule.FEC_Action_Button__c,
                'actionCode'          => rule.FEC_Action_Button__r?.FEC_Code__c,
                'nextStage'           => rule.FEC_Next_Stage__r?.Name,
                'nextStageId'         => rule.FEC_Next_Stage__c,
                'nextStageCode'       => rule.FEC_Next_Stage__r?.FEC_Code__c,
                'nextQueue'           => rule.FEC_Next_Queue__c,
                'teamUserGroup'       => rule.FEC_Team_User_Group__c,
                'priority'            => rule.FEC_Priority__c,
                'active'              => rule.FEC_Active__c,
                'conditionLogic'      => rule.FEC_Condition_Logic__c,
                'processChangeStatus' => rule.Process_Change_Status__c,
                'conditions'          => condList
            });
        }

        return result;
    }

    // ════════════════════════════════════════════════════════
    // GET ADDITIONAL FIELD OPTIONS (for condition form lookup)
    // ════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAdditionalFieldOptions() {
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT  Id,
                    Name,
                    FEC_Code__c,
                    FEC_Name_VN__c,
                    FEC_Unique_ID__c,
                    FEC_Type__c,
                    FEC_Field_Status__c
            FROM    FEC_MDM_Additional_Field__c
            WHERE   FEC_Field_Status__c = true
            ORDER BY Name ASC
        ];

        List<Map<String, Object>> options = new List<Map<String, Object>>();
        for (FEC_MDM_Additional_Field__c f : fields) {
            String displayLabel = (f.FEC_Name_VN__c != null ? f.FEC_Name_VN__c : f.Name)
                                  + ' (' + (f.FEC_Unique_ID__c != null ? f.FEC_Unique_ID__c : f.FEC_Code__c) + ')';
            options.add(new Map<String, Object>{
                'label'       => displayLabel,
                'value'       => f.Id,                 // combobox value = record ID
                'fieldApiName'=> f.FEC_Unique_ID__c,   // actual Field API Name stored in FEC_Unique_ID__c
                'fieldCode'   => f.FEC_Code__c,
                'fieldNameVN' => f.FEC_Name_VN__c,
                'dataType'    => f.FEC_Type__c
            });
        }
        return options;
    }

    // ════════════════════════════════════════════════════════
    // SAVE RULE WITH CONDITIONS
    // ════════════════════════════════════════════════════════
    @AuraEnabled
    public static String saveRuleWithConditions(String ruleData) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ruleData);

        // ── Upsert Stage Change rule ──
        FEC_MDM_Stage_Change__c rule = new FEC_MDM_Stage_Change__c();
        if (payload.get('recordId') != null) {
            rule.Id = (Id) payload.get('recordId');
        }
        rule.FEC_Previous_Stage__c  = (Id)      payload.get('previousStageId');
        rule.FEC_Action_Button__c   = (Id)      payload.get('actionButtonId');
        rule.FEC_Next_Stage__c      = (Id)      payload.get('nextStageId');
        rule.FEC_Next_Queue__c      = (String)  payload.get('nextQueue');
        rule.FEC_Team_User_Group__c = (String)  payload.get('teamUserGroup');
        rule.FEC_Priority__c        = payload.get('priority') != null
                                      ? Decimal.valueOf(String.valueOf(payload.get('priority'))) : 1;
        rule.FEC_Condition_Logic__c = (String)  payload.get('conditionLogic');
        rule.FEC_Active__c          = true;

        upsert rule;

        // ── Handle conditions ──
        List<Object> conditionsRaw = (List<Object>) payload.get('conditions');
        if (conditionsRaw == null) conditionsRaw = new List<Object>();

        // Separate new vs existing conditions
        Set<Id>     keepIds   = new Set<Id>();
        List<FEC_MDM_Stage_Change_Condition__c> toInsert = new List<FEC_MDM_Stage_Change_Condition__c>();
        List<FEC_MDM_Stage_Change_Condition__c> toUpdate = new List<FEC_MDM_Stage_Change_Condition__c>();

        for (Object condObj : conditionsRaw) {
            Map<String, Object> cond = (Map<String, Object>) condObj;
            String condId = cond.get('id') != null ? String.valueOf(cond.get('id')) : null;
            Boolean isExisting = String.isNotBlank(condId) && condId != 'null';

            if (isExisting) {
                // UPDATE: do NOT set FEC_Stage_Change__c (Lookup not reparentable)
                FEC_MDM_Stage_Change_Condition__c rec = new FEC_MDM_Stage_Change_Condition__c(
                    Id                     = (Id) condId,
                    FEC_Additional_Field__c = cond.get('fieldId') != null && String.valueOf(cond.get('fieldId')) != 'null'
                                             ? (Id) cond.get('fieldId') : null,
                    FEC_Operator__c         = (String) cond.get('operator'),
                    FEC_Value__c            = (String) cond.get('value'),
                    FEC_Value_Type__c       = (String) cond.get('valueType'),
                    FEC_Order__c            = cond.get('order') != null
                                             ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null
                );
                keepIds.add(rec.Id);
                toUpdate.add(rec);
            } else {
                // INSERT: set FEC_Stage_Change__c only on new records
                FEC_MDM_Stage_Change_Condition__c rec = new FEC_MDM_Stage_Change_Condition__c(
                    FEC_Stage_Change__c     = rule.Id,
                    FEC_Additional_Field__c = cond.get('fieldId') != null && String.valueOf(cond.get('fieldId')) != 'null'
                                             ? (Id) cond.get('fieldId') : null,
                    FEC_Operator__c         = (String) cond.get('operator'),
                    FEC_Value__c            = (String) cond.get('value'),
                    FEC_Value_Type__c       = (String) cond.get('valueType'),
                    FEC_Order__c            = cond.get('order') != null
                                             ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null
                );
                toInsert.add(rec);
            }
        }

        // Delete conditions that were removed by the user
        List<FEC_MDM_Stage_Change_Condition__c> toDelete = [
            SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
            WHERE  FEC_Stage_Change__c = :rule.Id
            AND    Id NOT IN :keepIds
        ];
        if (!toDelete.isEmpty()) delete toDelete;
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!toInsert.isEmpty()) insert toInsert;

        return rule.Id;
    }
}
