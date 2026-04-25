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
                        FEC_Condition_Requirement__c,
                        Process_Change_Status__c
                FROM    FEC_MDM_Stage_Change__c
                WHERE   FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
                AND     FEC_Active__c = true
                ORDER BY FEC_Previous_Stage__r.Name ASC,
                         FEC_Priority__c ASC NULLS LAST
        ];

        // Collect rule IDs for separate condition query
        Set<Id> ruleIds = new Set<Id>();
        for (FEC_MDM_Stage_Change__c rule : rules) {
            ruleIds.add(rule.Id);
        }

        // Query conditions separately — no stripInaccessible needed since these are
        // internal condition records accessed through the already-secured parent rules
        List<FEC_MDM_Stage_Change_Condition__c> allConditions = [
            SELECT  Id,
                    Name,
                    FEC_Stage_Change__c,
                    FEC_Master_Data_Setting__c,
                    FEC_Master_Data_Setting__r.FEC_Field_Label_Name__c,
                    FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                    FEC_Master_Data_Setting__r.FEC_Field_Object_Name__c,
                    FEC_Operator__c,
                    FEC_Value__c,
                    FEC_Expression__c,
                    FEC_Order__c
            FROM    FEC_MDM_Stage_Change_Condition__c
            WHERE   FEC_Stage_Change__c IN :ruleIds
            ORDER BY FEC_Order__c ASC NULLS LAST
        ];

        // Group conditions by rule ID
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c cond : allConditions) {
            Id ruleId = cond.FEC_Stage_Change__c;
            if (!conditionsByRule.containsKey(ruleId)) {
                conditionsByRule.put(ruleId, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            conditionsByRule.get(ruleId).add(cond);
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();

        for (FEC_MDM_Stage_Change__c rule : rules) {
            // ── Build condition list from separately queried conditions ──
            List<Map<String, Object>> condList = new List<Map<String, Object>>();
            List<FEC_MDM_Stage_Change_Condition__c> ruleConditions = conditionsByRule.get(rule.Id);
            if (ruleConditions != null) {
                for (FEC_MDM_Stage_Change_Condition__c cond : ruleConditions) {
                    condList.add(new Map<String, Object>{
                        'id'            => cond.Id,
                        'conditionName' => cond.Name,
                        'fieldId'       => cond.FEC_Master_Data_Setting__c,
                        'fieldName'     => cond.FEC_Master_Data_Setting__r?.FEC_Field_Label_Name__c,
                        'fieldApiName'  => cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c,
                        'fieldType'     => resolveFieldDataType(
                            cond.FEC_Master_Data_Setting__r?.FEC_Field_Object_Name__c,
                            cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c
                        ),
                        'operator'      => cond.FEC_Operator__c,
                        'value'         => cond.FEC_Value__c,
                        'expression'    => cond.FEC_Expression__c,
                        'order'         => cond.FEC_Order__c
                    });
                }
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
                'conditionRequirement'=> rule.FEC_Condition_Requirement__c,
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
        List<FEC_MDM_Additional_Field__c> fields = (List<FEC_MDM_Additional_Field__c>) Security.stripInaccessible(
            AccessType.READABLE,
            [
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
            ]
        ).getRecords();

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
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ruleData);

            // ── Upsert Stage Change rule ──
            FEC_MDM_Stage_Change__c rule = new FEC_MDM_Stage_Change__c();
            if (payload.get('recordId') != null && String.valueOf(payload.get('recordId')) != 'null') {
                rule.Id = (Id) payload.get('recordId');
            }
            rule.FEC_Previous_Stage__c  = (Id)      payload.get('previousStageId');
            rule.FEC_Action_Button__c   = (Id)      payload.get('actionButtonId');
            rule.FEC_Next_Stage__c      = (Id)      payload.get('nextStageId');
            rule.FEC_Next_Queue__c      = (String)  payload.get('nextQueue');
            rule.FEC_Team_User_Group__c = (String)  payload.get('teamUserGroup');
            rule.FEC_Priority__c        = payload.get('priority') != null
                                          ? Decimal.valueOf(String.valueOf(payload.get('priority'))) : 1;
            
            rule.FEC_Condition_Requirement__c = (String) payload.get('conditionRequirement');
            rule.FEC_Condition_Logic__c = (String)  payload.get('conditionLogic');
            rule.FEC_Active__c          = true;

            upsert rule;

            // ── Handle conditions ──
            List<Object> conditionsRaw = (List<Object>) payload.get('conditions');
            if (conditionsRaw == null) conditionsRaw = new List<Object>();

            Set<Id> keepIds = new Set<Id>();
            List<FEC_MDM_Stage_Change_Condition__c> conditionsToUpsert = new List<FEC_MDM_Stage_Change_Condition__c>();

            for (Object condObj : conditionsRaw) {
                Map<String, Object> cond = (Map<String, Object>) condObj;
                String condId = cond.get('id') != null ? String.valueOf(cond.get('id')) : null;
                
                String rawFieldId = cond.get('fieldId') != null ? String.valueOf(cond.get('fieldId')) : null;
                Id parsedFieldId = String.isNotBlank(rawFieldId) && rawFieldId != 'null' ? (Id) rawFieldId : null;

                FEC_MDM_Stage_Change_Condition__c rec = new FEC_MDM_Stage_Change_Condition__c();
                if (String.isNotBlank(condId) && condId != 'null' && !condId.startsWith('new-')) {
                    rec.Id = (Id) condId;
                    keepIds.add(rec.Id);
                } else {
                    rec.FEC_Stage_Change__c = rule.Id;
                }
                
                rec.FEC_Master_Data_Setting__c = parsedFieldId;
                // Convert BETWEEN to >= (BETWEEN is not a valid picklist value)
                String operatorVal = (String) cond.get('operator');
                if (operatorVal == 'BETWEEN') {
                    operatorVal = '>=';
                }
                rec.FEC_Operator__c            = operatorVal;
                rec.FEC_Value__c               = (String) cond.get('value');
                rec.FEC_Expression__c          = (String) cond.get('expression');
                rec.FEC_Order__c               = cond.get('order') != null ? Decimal.valueOf(String.valueOf(cond.get('order'))) : null;
                
                conditionsToUpsert.add(rec);
            }

            // 1. Delete removed
            List<FEC_MDM_Stage_Change_Condition__c> toDelete = [
                SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
                WHERE  FEC_Stage_Change__c = :rule.Id
                AND    Id NOT IN :keepIds
            ];
            if (!toDelete.isEmpty()) delete toDelete;

            // 2. Upsert remaining/new
            if (!conditionsToUpsert.isEmpty()) upsert conditionsToUpsert;

            return rule.Id;
        } catch (Exception e) {
            System.debug('Error in saveRuleWithConditions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(System.Label.FEC_Error_Cannot_Save_Rule + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // GET DECISION TABLE DATA (for LWC Decision Table Stage)
    // ════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getDecisionTableData(Id businessProcessId) {
        List<Map<String, Object>> rules = getRulesWithConditions(businessProcessId);

        Map<Id, Map<String, Object>> columnMap = new Map<Id, Map<String, Object>>();
        for (Map<String, Object> rule : rules) {
            List<Object> conditions = (List<Object>) rule.get('conditions');
            if (conditions != null) {
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
        }

        return new Map<String, Object>{
            'conditionColumns' => columnMap.values(),
            'rules'            => rules
        };
    }

    // ════════════════════════════════════════════════════════
    // DELETE RULE (Stage Change + cascade Conditions)
    // ════════════════════════════════════════════════════════
    @AuraEnabled
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
        if (!conditions.isEmpty()) {
            delete conditions;
        }
        delete [SELECT Id FROM FEC_MDM_Stage_Change__c WHERE Id = :ruleId];
    }

    // ════════════════════════════════════════════════════════
    // DELETE CONDITION COLUMN (all conditions of a field in BP)
    // ════════════════════════════════════════════════════════
    @AuraEnabled
    public static void deleteConditionColumn(Id businessProcessId, Id masterDataSettingId) {
        if (!FEC_MDM_Stage_Change_Condition__c.SObjectType.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        List<FEC_MDM_Stage_Change_Condition__c> toDelete = [
            SELECT Id FROM FEC_MDM_Stage_Change_Condition__c
            WHERE FEC_Master_Data_Setting__c = :masterDataSettingId
            AND   FEC_Stage_Change__r.FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId
        ];
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    // ════════════════════════════════════════════════════════
    // GET FIELDS FOR BUSINESS PROCESS (all MDS fields across all Stages in BP)
    // ════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getFieldsForBusinessProcess(Id businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (businessProcessId == null) return options;

        try {
            List<FEC_MDM_Master_Data_Setting__c> mdsList = (List<FEC_MDM_Master_Data_Setting__c>) Security.stripInaccessible(
                AccessType.READABLE,
                [
                    SELECT Id,
                           FEC_Field_Label_Name__c,
                           FEC_Field_API_Name__c,
                           FEC_Field_Object_Name__c,
                           Name
                    FROM FEC_MDM_Master_Data_Setting__c
                    WHERE FEC_Stage_Name__r.FEC_Business_Process__c = :businessProcessId
                      AND FEC_Field_Status__c = true
                    ORDER BY FEC_Field_Order_Display__c ASC
                ]
            ).getRecords();

            // Deduplicate by MDS Id (same field may appear in multiple stages)
            Set<Id> seen = new Set<Id>();
            for (FEC_MDM_Master_Data_Setting__c mds : mdsList) {
                if (seen.contains(mds.Id)) continue;
                seen.add(mds.Id);

                String labelName = mds.FEC_Field_Label_Name__c;
                if (String.isBlank(labelName)) {
                    labelName = mds.Name;
                }

                String apiName = mds.FEC_Field_API_Name__c;
                if (String.isBlank(apiName)) {
                    apiName = mds.Name;
                }

                options.add(new Map<String, String>{
                    'label'        => labelName + ' (' + apiName + ')',
                    'value'        => (String) mds.Id,
                    'fieldApiName' => apiName,
                    'dataType'     => resolveFieldDataType(mds.FEC_Field_Object_Name__c, apiName)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // RUNTIME ENGINE: EVALUATE STAGE TRANSITION
    // ════════════════════════════════════════════════════════

    /**
     * @description Runtime engine: evaluates Decision Table rules against Case data.
     *              Finds the first matching rule (First Match Wins by priority)
     *              for the given Case, current Stage, and Action Button.
     *
     *              To integrate with fec_CaseBussiness:
     *              1. Import this method in the LWC
     *              2. Call before run() in handleSubmit
     *              3. Use returned nextStageId/nextQueue/teamUserGroup
     *
     * @param caseId The Case record Id
     * @param currentStageId The current Stage Id (FEC_MDM_Case_Stage__c)
     * @param actionButtonId The Action Button Id pressed by the agent
     * @return Map with matched rule info or {matched: false, message: '...'}
     */
    @AuraEnabled
    public static Map<String, Object> evaluateStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }

            // 1. Query active rules matching Previous Stage + Action Button, ordered by Priority ASC
            List<FEC_MDM_Stage_Change__c> rules = [
                SELECT  Id,
                        Name,
                        FEC_Previous_Stage__c,
                        FEC_Next_Stage__c,
                        FEC_Next_Stage__r.Name,
                        FEC_Next_Queue__c,
                        FEC_Team_User_Group__c,
                        FEC_Priority__c
                FROM    FEC_MDM_Stage_Change__c
                WHERE   FEC_Previous_Stage__c = :currentStageId
                AND     FEC_Action_Button__c = :actionButtonId
                AND     FEC_Active__c = true
                ORDER BY FEC_Priority__c ASC NULLS LAST
            ];

            if (rules.isEmpty()) {
                return new Map<String, Object>{
                    'matched' => false,
                    'message' => System.Label.FEC_Error_NoRuleMatched
                };
            }

            // Collect rule IDs
            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Stage_Change__c rule : rules) {
                ruleIds.add(rule.Id);
            }

            // 2. Query all conditions for these rules (including expression)
            List<FEC_MDM_Stage_Change_Condition__c> allConditions = [
                SELECT  Id,
                        FEC_Stage_Change__c,
                        FEC_Master_Data_Setting__c,
                        FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                        FEC_Master_Data_Setting__r.FEC_Field_Object_Name__c,
                        FEC_Operator__c,
                        FEC_Value__c,
                        FEC_Expression__c,
                        FEC_Order__c
                FROM    FEC_MDM_Stage_Change_Condition__c
                WHERE   FEC_Stage_Change__c IN :ruleIds
                ORDER BY FEC_Order__c ASC NULLS LAST
            ];

            // Group conditions by rule ID
            Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
            for (FEC_MDM_Stage_Change_Condition__c cond : allConditions) {
                Id ruleId = cond.FEC_Stage_Change__c;
                if (!conditionsByRule.containsKey(ruleId)) {
                    conditionsByRule.put(ruleId, new List<FEC_MDM_Stage_Change_Condition__c>());
                }
                conditionsByRule.get(ruleId).add(cond);
            }

            // 3. Collect all unique field API names referenced by conditions
            Set<String> fieldApiNames = new Set<String>();
            for (FEC_MDM_Stage_Change_Condition__c cond : allConditions) {
                String apiName = resolveFieldApiName(cond);
                if (String.isNotBlank(apiName)) {
                    fieldApiNames.add(apiName);
                }
            }

            // 4. Query Case data for referenced fields (dynamic SOQL with schema validation)
            Map<String, Object> caseData = new Map<String, Object>();
            if (!fieldApiNames.isEmpty()) {
                caseData = queryCaseFields(caseId, fieldApiNames);
            }

            // 5. Evaluate each rule by priority — First Match Wins
            for (FEC_MDM_Stage_Change__c rule : rules) {
                List<FEC_MDM_Stage_Change_Condition__c> ruleConditions = conditionsByRule.get(rule.Id);

                // No conditions → default/otherwise rule → matches immediately
                if (ruleConditions == null || ruleConditions.isEmpty()) {
                    return buildMatchResult(rule);
                }

                // Evaluate conditions: group by fieldId → OR within same field, AND between fields
                if (evaluateRuleConditions(ruleConditions, caseData)) {
                    return buildMatchResult(rule);
                }
            }

            // No rule matched
            return new Map<String, Object>{
                'matched' => false,
                'message' => System.Label.FEC_Error_NoRuleMatched
            };

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    /**
     * Resolve the Case field API name from a condition's Master Data Setting.
     */
    private static String resolveFieldApiName(FEC_MDM_Stage_Change_Condition__c cond) {
        return cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
    }

    /**
     * Resolve field data type from Salesforce schema using object name + field API name.
     * Returns a simplified type string: Text, Number, Boolean, Picklist, Date, DateTime, etc.
     */
    @TestVisible
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

    /**
     * Query Case fields dynamically, validating each field against the Case schema.
     */
    private static Map<String, Object> queryCaseFields(Id caseId, Set<String> fieldApiNames) {
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();

        // Validate and filter to only real Case fields
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

    /**
     * Evaluate all conditions for a rule.
     * Logic: OR within same field (Master Data Setting), AND between different fields.
     */
    private static Boolean evaluateRuleConditions(
        List<FEC_MDM_Stage_Change_Condition__c> conditions,
        Map<String, Object> caseData
    ) {
        // Group conditions by Master Data Setting Id (field)
        Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByField = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
        for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
            Id fieldId = cond.FEC_Master_Data_Setting__c;
            if (fieldId == null) continue;
            if (!conditionsByField.containsKey(fieldId)) {
                conditionsByField.put(fieldId, new List<FEC_MDM_Stage_Change_Condition__c>());
            }
            conditionsByField.get(fieldId).add(cond);
        }

        // AND between field groups: all groups must match
        for (Id fieldId : conditionsByField.keySet()) {
            List<FEC_MDM_Stage_Change_Condition__c> fieldConditions = conditionsByField.get(fieldId);
            Boolean groupMatched = false;

            // OR within same field: at least one condition must match
            for (FEC_MDM_Stage_Change_Condition__c cond : fieldConditions) {
                String apiName = resolveFieldApiName(cond);
                String actualValue = '';
                if (String.isNotBlank(apiName)) {
                    Object val = caseData.get(apiName.toLowerCase());
                    actualValue = val != null ? String.valueOf(val) : '';
                }

                if (evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c)) {
                    groupMatched = true;
                    break; // OR: one match is enough
                }
            }

            if (!groupMatched) {
                return false; // AND: all groups must match
            }
        }

        return true;
    }

    /**
     * Evaluate a single condition: apply expression first, then compare.
     */
    @TestVisible
    private static Boolean evaluateCondition(String actualValue, String operator, String conditionValue, String expression) {
        // Apply expression transformation if set (skip range markers)
        String processedValue = actualValue != null ? actualValue : '';
        if (String.isNotBlank(expression) && expression != 'RANGE_START' && expression != 'RANGE_END') {
            processedValue = applyExpression(expression, processedValue);
        }

        if (String.isBlank(operator)) {
            return processedValue == conditionValue;
        }

        switch on operator {
            when '=' {
                return processedValue == conditionValue;
            }
            when '!=' {
                return processedValue != conditionValue;
            }
            when '>' {
                return compareNumeric(processedValue, conditionValue) > 0;
            }
            when '<' {
                return compareNumeric(processedValue, conditionValue) < 0;
            }
            when '>=' {
                return compareNumeric(processedValue, conditionValue) >= 0;
            }
            when '<=' {
                return compareNumeric(processedValue, conditionValue) <= 0;
            }
            when 'IN' {
                return isInList(processedValue, conditionValue);
            }
            when 'NOT IN' {
                return !isInList(processedValue, conditionValue);
            }
            when 'Contains' {
                return processedValue != null && conditionValue != null && processedValue.containsIgnoreCase(conditionValue);
            }
            when 'Starts With' {
                return processedValue != null && conditionValue != null && processedValue.startsWithIgnoreCase(conditionValue);
            }
            when 'Ends With' {
                return processedValue != null && conditionValue != null && processedValue.endsWithIgnoreCase(conditionValue);
            }
            when 'BETWEEN' {
                return evaluateBetween(processedValue, conditionValue);
            }
            when else {
                return processedValue == conditionValue;
            }
        }
    }

    /**
     * Apply expression function to transform a field value before comparison.
     * Supported: TRIM, UPPER, LOWER, LENGTH, LEFT(field, n), RIGHT(field, n)
     */
    @TestVisible
    private static String applyExpression(String expression, String value) {
        if (value == null) value = '';
        if (String.isBlank(expression)) return value;

        String expr = expression.toUpperCase().trim();

        if (expr.startsWith('TRIM')) {
            return value.trim();
        }
        if (expr.startsWith('UPPER')) {
            return value.toUpperCase();
        }
        if (expr.startsWith('LOWER')) {
            return value.toLowerCase();
        }
        if (expr.startsWith('LENGTH')) {
            return String.valueOf(value.length());
        }
        if (expr.startsWith('LEFT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.left(n) : value;
        }
        if (expr.startsWith('RIGHT')) {
            Integer n = extractNumber(expression);
            return (n != null && value.length() >= n) ? value.right(n) : value;
        }

        return value; // No recognized expression, return as-is
    }

    /**
     * Extract a numeric parameter from an expression like LEFT(field, 3) or RIGHT(field, 5).
     */
    private static Integer extractNumber(String expression) {
        if (String.isBlank(expression)) return null;
        // Match pattern: FUNC(..., N) — extract the last number before closing paren
        Pattern p = Pattern.compile('\\,\\s*(\\d+)\\s*\\)');
        Matcher m = p.matcher(expression);
        if (m.find()) {
            try {
                return Integer.valueOf(m.group(1));
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    /**
     * Compare two values as Decimals. Returns negative, zero, or positive.
     */
    private static Integer compareNumeric(String val1, String val2) {
        try {
            Decimal d1 = Decimal.valueOf(val1.trim());
            Decimal d2 = Decimal.valueOf(val2.trim());
            if (d1 > d2) return 1;
            if (d1 < d2) return -1;
            return 0;
        } catch (Exception e) {
            // Fallback to string comparison if not numeric
            String s1 = val1 != null ? val1 : '';
            String s2 = val2 != null ? val2 : '';
            if (s1 > s2) return 1;
            if (s1 < s2) return -1;
            return 0;
        }
    }

    /**
     * Check if a value is in a comma-separated list (case-insensitive).
     */
    private static Boolean isInList(String value, String commaSeparatedList) {
        if (String.isBlank(commaSeparatedList)) return false;
        String lowerValue = (value != null ? value.trim().toLowerCase() : '');
        for (String item : commaSeparatedList.split(',')) {
            if (item.trim().toLowerCase() == lowerValue) {
                return true;
            }
        }
        return false;
    }

    /**
     * Evaluate BETWEEN operator. Value format: ">=5,<=10" or ">5,<10"
     * Each part has operator prefix (>=, >, <=, <) followed by numeric value.
     */
    private static Boolean evaluateBetween(String actualValue, String rangeValue) {
        if (String.isBlank(rangeValue) || String.isBlank(actualValue)) return false;
        try {
            List<String> parts = rangeValue.split(',');
            if (parts.size() != 2) return false;

            String startPart = parts[0].trim(); // e.g. ">=5"
            String endPart = parts[1].trim();   // e.g. "<=10"

            // Parse start: extract operator and value
            String startOp;
            Decimal startVal;
            if (startPart.startsWith('>=')) {
                startOp = '>=';
                startVal = Decimal.valueOf(startPart.substring(2).trim());
            } else if (startPart.startsWith('>')) {
                startOp = '>';
                startVal = Decimal.valueOf(startPart.substring(1).trim());
            } else {
                startOp = '>=';
                startVal = Decimal.valueOf(startPart);
            }

            // Parse end: extract operator and value
            String endOp;
            Decimal endVal;
            if (endPart.startsWith('<=')) {
                endOp = '<=';
                endVal = Decimal.valueOf(endPart.substring(2).trim());
            } else if (endPart.startsWith('<')) {
                endOp = '<';
                endVal = Decimal.valueOf(endPart.substring(1).trim());
            } else {
                endOp = '<=';
                endVal = Decimal.valueOf(endPart);
            }

            Decimal actual = Decimal.valueOf(actualValue.trim());

            Boolean startOk = (startOp == '>=') ? actual >= startVal : actual > startVal;
            Boolean endOk = (endOp == '<=') ? actual <= endVal : actual < endVal;

            return startOk && endOk;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Build the match result map from a matched rule.
     */
    private static Map<String, Object> buildMatchResult(FEC_MDM_Stage_Change__c rule) {
        return new Map<String, Object>{
            'matched'        => true,
            'ruleId'         => rule.Id,
            'ruleName'       => rule.Name,
            'nextStageId'    => rule.FEC_Next_Stage__c,
            'nextStageName'  => rule.FEC_Next_Stage__r?.Name,
            'nextQueue'      => rule.FEC_Next_Queue__c,
            'teamUserGroup'  => rule.FEC_Team_User_Group__c
        };
    }

    @AuraEnabled
    public static List<Map<String, String>> getFieldsForStage(String stageId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (String.isBlank(stageId)) return options;

        try {
            // Lấy danh sách từ Master Data Setting của Stage hiện tại
            List<FEC_MDM_Master_Data_Setting__c> mdsList = (List<FEC_MDM_Master_Data_Setting__c>) Security.stripInaccessible(
                AccessType.READABLE,
                [
                    SELECT Id, 
                           FEC_Field_Label_Name__c, 
                           FEC_Field_API_Name__c,
                           FEC_Field_Object_Name__c,
                           Name
                    FROM FEC_MDM_Master_Data_Setting__c
                    WHERE FEC_Stage_Name__c = :stageId
                      AND FEC_Field_Status__c = true
                    ORDER BY FEC_Field_Order_Display__c ASC
                ]
            ).getRecords();

            for (FEC_MDM_Master_Data_Setting__c mds : mdsList) {
                Map<String, String> opt = new Map<String, String>();
                
                String labelName = mds.FEC_Field_Label_Name__c;
                if (String.isBlank(labelName)) {
                    labelName = mds.Name;
                }
                
                String apiName = mds.FEC_Field_API_Name__c;
                if (String.isBlank(apiName)) {
                     apiName = mds.Name;
                }

                opt.put('label', labelName + ' (' + apiName + ')');
                opt.put('value', (String)mds.Id);
                opt.put('fieldApiName', apiName);
                opt.put('dataType', resolveFieldDataType(mds.FEC_Field_Object_Name__c, apiName));
                options.add(opt);
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Load_Field_List + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // UPDATE COLUMN PROPERTIES (operator, expression) for all conditions of a field in BP
    // ════════════════════════════════════════════════════════

    /**
     * @description Update operator and expression for all conditions of a specific MDS field
     *              across all rules in a Business Process.
     * @param businessProcessId The Business Process ID
     * @param masterDataSettingId The MDS field ID (column)
     * @param newOperator New operator value (e.g. '=', '>', 'IN')
     * @param newExpression New expression value (e.g. 'TRIM', 'UPPER', or empty)
     */
    @AuraEnabled
    public static void updateColumnProperties(Id businessProcessId, Id masterDataSettingId, String newOperator, String newExpression) {
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

            // Map operator display values
            Map<String, String> operatorMap = new Map<String, String>{
                'EQUALS' => '=', 'NOT_EQUALS' => '!=', 'GREATER_THAN' => '>',
                'LESS_THAN' => '<', 'GREATER_THAN_OR_EQUAL' => '>=', 'LESS_THAN_OR_EQUAL' => '<=',
                'IN' => 'IN', 'NOT_IN' => 'NOT IN', 'CONTAINS' => 'Contains',
                'STARTS_WITH' => 'Starts With', 'ENDS_WITH' => 'Ends With'
            };
            String mappedOperator = operatorMap.containsKey(newOperator) ? operatorMap.get(newOperator) : newOperator;
            // BETWEEN is not a valid picklist value — skip bulk operator update for range columns
            if (mappedOperator == 'BETWEEN') {
                // Only update expression, don't change operator on existing records
                for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
                    cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
                }
                update conditions;
                return;
            }

            for (FEC_MDM_Stage_Change_Condition__c cond : conditions) {
                cond.FEC_Operator__c = mappedOperator;
                cond.FEC_Expression__c = String.isNotBlank(newExpression) ? newExpression : null;
            }

            update conditions;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Không thể cập nhật cột: ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // TEST RULE EVALUATION (for Rule Test Panel in LWC)
    // ════════════════════════════════════════════════════════

    /**
     * @description Evaluate Decision Table rules using mock field values (no real Case needed).
     *              Used by the Test Panel in Decision Table Stage View.
     *              All filter params are optional — omit to see all rules.
     *
     * @param businessProcessId Business Process ID (required)
     * @param previousStageId Previous Stage ID (optional — null = all stages)
     * @param actionButtonId Action Button ID (optional — null = all actions)
     * @param fieldValues Map<String, String> — key = MDS field API name, value = test value (optional)
     * @return Map with matched rule info and evaluationTrace
     */
    @AuraEnabled
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
            if (fieldValues == null) {
                fieldValues = new Map<String, String>();
            }

            // Normalize keys to lowercase
            Map<String, Object> normalizedValues = new Map<String, Object>();
            for (String key : fieldValues.keySet()) {
                normalizedValues.put(key.toLowerCase(), fieldValues.get(key));
            }

            // 1. Build dynamic query with optional filters
            String soql = 'SELECT Id, Name, FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name, '
                + 'FEC_Action_Button__c, FEC_Action_Button__r.Name, '
                + 'FEC_Next_Stage__c, FEC_Next_Stage__r.Name, '
                + 'FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Priority__c '
                + 'FROM FEC_MDM_Stage_Change__c '
                + 'WHERE FEC_Previous_Stage__r.FEC_Business_Process__c = :businessProcessId '
                + 'AND FEC_Active__c = true ';
            if (previousStageId != null) {
                soql += 'AND FEC_Previous_Stage__c = :previousStageId ';
            }
            if (actionButtonId != null) {
                soql += 'AND FEC_Action_Button__c = :actionButtonId ';
            }
            soql += 'ORDER BY FEC_Priority__c ASC NULLS LAST';

            List<FEC_MDM_Stage_Change__c> rules = Database.query(soql);

            if (rules.isEmpty()) {
                return new Map<String, Object>{
                    'matched'         => false,
                    'message'         => System.Label.FEC_Error_NoRuleMatched,
                    'evaluationTrace' => new List<Map<String, Object>>()
                };
            }

            // 2. Query conditions
            Set<Id> ruleIds = new Set<Id>();
            for (FEC_MDM_Stage_Change__c r : rules) { ruleIds.add(r.Id); }

            List<FEC_MDM_Stage_Change_Condition__c> allConditions = [
                SELECT  Id, FEC_Stage_Change__c,
                        FEC_Master_Data_Setting__c,
                        FEC_Master_Data_Setting__r.FEC_Field_Label_Name__c,
                        FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                        FEC_Operator__c, FEC_Value__c, FEC_Expression__c, FEC_Order__c
                FROM    FEC_MDM_Stage_Change_Condition__c
                WHERE   FEC_Stage_Change__c IN :ruleIds
                ORDER BY FEC_Order__c ASC NULLS LAST
            ];

            Map<Id, List<FEC_MDM_Stage_Change_Condition__c>> conditionsByRule = new Map<Id, List<FEC_MDM_Stage_Change_Condition__c>>();
            for (FEC_MDM_Stage_Change_Condition__c c : allConditions) {
                if (!conditionsByRule.containsKey(c.FEC_Stage_Change__c)) {
                    conditionsByRule.put(c.FEC_Stage_Change__c, new List<FEC_MDM_Stage_Change_Condition__c>());
                }
                conditionsByRule.get(c.FEC_Stage_Change__c).add(c);
            }

            // 3. Evaluate each rule + build trace
            List<Map<String, Object>> trace = new List<Map<String, Object>>();
            Boolean alreadyMatched = false;
            Map<String, Object> matchResult = null;

            for (FEC_MDM_Stage_Change__c rule : rules) {
                List<FEC_MDM_Stage_Change_Condition__c> ruleConds = conditionsByRule.get(rule.Id);
                Map<String, Object> ruleTrace = new Map<String, Object>{
                    'ruleId'        => rule.Id,
                    'ruleName'      => rule.Name,
                    'priority'      => rule.FEC_Priority__c,
                    'previousStage' => rule.FEC_Previous_Stage__r?.Name,
                    'action'        => rule.FEC_Action_Button__r?.Name,
                    'nextStage'     => rule.FEC_Next_Stage__r?.Name,
                    'nextQueue'     => rule.FEC_Next_Queue__c,
                    'team'          => rule.FEC_Team_User_Group__c
                };

                if (alreadyMatched) {
                    ruleTrace.put('result', 'NOT_EVALUATED');
                    ruleTrace.put('conditions', new List<Map<String, Object>>());
                    trace.add(ruleTrace);
                    continue;
                }

                // No conditions → default rule
                if (ruleConds == null || ruleConds.isEmpty()) {
                    ruleTrace.put('result', 'MATCH');
                    ruleTrace.put('conditions', new List<Map<String, Object>>());
                    trace.add(ruleTrace);
                    alreadyMatched = true;
                    matchResult = buildMatchResult(rule);
                    matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                    continue;
                }

                // Evaluate with trace
                List<Map<String, Object>> condTrace = new List<Map<String, Object>>();
                Boolean ruleMatched = evaluateConditionsWithTrace(ruleConds, normalizedValues, condTrace);

                ruleTrace.put('result', ruleMatched ? 'MATCH' : 'NOT_MATCH');
                ruleTrace.put('conditions', condTrace);
                trace.add(ruleTrace);

                if (ruleMatched) {
                    alreadyMatched = true;
                    matchResult = buildMatchResult(rule);
                    matchResult.put('matchedRulePriority', rule.FEC_Priority__c);
                }
            }

            // 4. Build response
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

    /**
     * Evaluate conditions for a rule using provided field values, building a detailed trace.
     * Logic: OR within same field, AND between different fields.
     */
    private static Boolean evaluateConditionsWithTrace(
        List<FEC_MDM_Stage_Change_Condition__c> conditions,
        Map<String, Object> fieldValues,
        List<Map<String, Object>> condTrace
    ) {
        // Group by field
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
            List<FEC_MDM_Stage_Change_Condition__c> fieldConds = byField.get(fieldId);
            Boolean groupMatched = false;

            for (FEC_MDM_Stage_Change_Condition__c cond : fieldConds) {
                String apiName = resolveFieldApiName(cond);
                String actualValue = '';
                if (String.isNotBlank(apiName)) {
                    Object val = fieldValues.get(apiName.toLowerCase());
                    actualValue = val != null ? String.valueOf(val) : '';
                }

                Boolean condResult = evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, cond.FEC_Expression__c);

                condTrace.add(new Map<String, Object>{
                    'fieldLabel'    => cond.FEC_Master_Data_Setting__r?.FEC_Field_Label_Name__c,
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

    // ════════════════════════════════════════════════════════
    // LIVE LAYER: evaluateLiveStageTransition
    // Same logic as evaluateStageTransition but queries Live objects
    // (FEC_Stage_Change__c, FEC_Stage_Change_Condition__c, FEC_Master_Data_Setting__c)
    // ════════════════════════════════════════════════════════

    /**
     * @description Evaluate stage transition rules on LIVE layer.
     *              Same logic as evaluateStageTransition (First Match Wins, OR/AND, expressions)
     *              but queries Live objects instead of MDM objects.
     *
     * @param caseId Case ID
     * @param currentStageId Current Live Stage ID (FEC_Case_Stage__c)
     * @param actionButtonId Action Button ID (FEC_Action_Button__c)
     * @return Map with matched rule info or null
     */
    @AuraEnabled
    public static Map<String, Object> evaluateLiveStageTransition(Id caseId, Id currentStageId, Id actionButtonId) {
        try {
            if (caseId == null || currentStageId == null || actionButtonId == null) {
                throw new AuraHandledException(System.Label.FEC_Error_Required_Fields);
            }

            // 1. Query active Live rules
            List<FEC_Stage_Change__c> rules = [
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

            if (rules.isEmpty()) {
                return new Map<String, Object>{
                    'matched' => false,
                    'message' => System.Label.FEC_Error_NoRuleMatched
                };
            }

            Set<Id> ruleIds = new Set<Id>();
            for (FEC_Stage_Change__c r : rules) { ruleIds.add(r.Id); }

            // 2. Query Live conditions
            List<FEC_Stage_Change_Condition__c> allConditions = [
                SELECT  Id, FEC_Stage_Change__c,
                        FEC_Master_Data_Setting__c,
                        FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                        FEC_Operator__c, FEC_Value__c, FEC_Order__c
                FROM    FEC_Stage_Change_Condition__c
                WHERE   FEC_Stage_Change__c IN :ruleIds
                ORDER BY FEC_Order__c ASC NULLS LAST
            ];

            // Group conditions by rule
            Map<Id, List<FEC_Stage_Change_Condition__c>> conditionsByRule = new Map<Id, List<FEC_Stage_Change_Condition__c>>();
            for (FEC_Stage_Change_Condition__c c : allConditions) {
                if (!conditionsByRule.containsKey(c.FEC_Stage_Change__c)) {
                    conditionsByRule.put(c.FEC_Stage_Change__c, new List<FEC_Stage_Change_Condition__c>());
                }
                conditionsByRule.get(c.FEC_Stage_Change__c).add(c);
            }

            // 3. Collect field API names
            Set<String> fieldApiNames = new Set<String>();
            for (FEC_Stage_Change_Condition__c c : allConditions) {
                String apiName = resolveLiveFieldApiName(c);
                if (String.isNotBlank(apiName)) {
                    fieldApiNames.add(apiName);
                }
            }

            // 4. Query Case data
            Map<String, Object> caseData = new Map<String, Object>();
            if (!fieldApiNames.isEmpty()) {
                caseData = queryCaseFields(caseId, fieldApiNames);
            }

            // 5. Evaluate — First Match Wins
            for (FEC_Stage_Change__c rule : rules) {
                List<FEC_Stage_Change_Condition__c> ruleConds = conditionsByRule.get(rule.Id);

                if (ruleConds == null || ruleConds.isEmpty()) {
                    return buildLiveMatchResult(rule);
                }

                if (evaluateLiveRuleConditions(ruleConds, caseData)) {
                    return buildLiveMatchResult(rule);
                }
            }

            return new Map<String, Object>{
                'matched' => false,
                'message' => System.Label.FEC_Error_NoRuleMatched
            };

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_EngineError + ' ' + e.getMessage());
        }
    }

    private static String resolveLiveFieldApiName(FEC_Stage_Change_Condition__c cond) {
        return cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c;
    }

    private static Map<String, Object> buildLiveMatchResult(FEC_Stage_Change__c rule) {
        return new Map<String, Object>{
            'matched'        => true,
            'ruleId'         => rule.Id,
            'ruleName'       => rule.Name,
            'nextStageId'    => rule.FEC_Next_Stage__c,
            'nextStageName'  => rule.FEC_Next_Stage__r?.Name,
            'nextQueue'      => rule.FEC_Next_Queue__c,
            'teamUserGroup'  => rule.FEC_Team_User_Group__c
        };
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
            List<FEC_Stage_Change_Condition__c> fieldConds = conditionsByField.get(fieldId);
            Boolean groupMatched = false;

            for (FEC_Stage_Change_Condition__c cond : fieldConds) {
                String apiName = resolveLiveFieldApiName(cond);
                String actualValue = '';
                if (String.isNotBlank(apiName)) {
                    Object val = caseData.get(apiName.toLowerCase());
                    actualValue = val != null ? String.valueOf(val) : '';
                }

                if (evaluateCondition(actualValue, cond.FEC_Operator__c, cond.FEC_Value__c, null)) {
                    groupMatched = true;
                    break;
                }
            }

            if (!groupMatched) {
                return false;
            }
        }

        return true;
    }
}