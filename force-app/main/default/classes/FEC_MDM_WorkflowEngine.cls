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
                    Process_Change_Status__c,
                    (
                        SELECT  Id,
                                Name,
                                FEC_Master_Data_Setting__c,
                                FEC_Master_Data_Setting__r.FEC_Field_Label_Name__c,
                                FEC_Master_Data_Setting__r.FEC_Field_API_Name__c,
                                FEC_Master_Data_Setting__r.FEC_Additional_Field__r.FEC_Type__c,
                                FEC_Operator__c,
                                FEC_Value__c,
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
                    'fieldId'       => cond.FEC_Master_Data_Setting__c, // ID bây giờ trỏ vào Master Data Setting
                    'fieldName'     => cond.FEC_Master_Data_Setting__r?.FEC_Field_Label_Name__c,
                    'fieldApiName'  => cond.FEC_Master_Data_Setting__r?.FEC_Field_API_Name__c,
                    'fieldType'     => cond.FEC_Master_Data_Setting__r?.FEC_Additional_Field__r?.FEC_Type__c,
                    'operator'      => cond.FEC_Operator__c,
                    'value'         => cond.FEC_Value__c,
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
                rec.FEC_Operator__c            = (String) cond.get('operator');
                rec.FEC_Value__c               = (String) cond.get('value');
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
            throw new AuraHandledException('Không thể lưu rule: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> getFieldsForStage(String stageId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (String.isBlank(stageId)) return options;

        try {
            // Lấy danh sách từ Master Data Setting của Stage hiện tại
            List<FEC_MDM_Master_Data_Setting__c> mdsList = [
                SELECT Id, 
                       FEC_Field_Label_Name__c, 
                       FEC_Field_API_Name__c,
                       FEC_Additional_Field__r.FEC_Type__c,
                       FEC_Additional_Field__r.Name,
                       FEC_Additional_Field__r.FEC_Code__c,
                       FEC_Additional_Field__r.FEC_Name_VN__c,
                       FEC_Additional_Field__r.FEC_Unique_ID__c,
                       Name
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Stage_Name__c = :stageId
                  AND FEC_Field_Status__c = true
                ORDER BY FEC_Field_Order_Display__c ASC
            ];

            System.debug('[DEBUG] getFieldsForStage - Total records found: ' + mdsList.size());

            for (FEC_MDM_Master_Data_Setting__c mds : mdsList) {
                Map<String, String> opt = new Map<String, String>();
                
                // Fallback logic to find the best possible label if the explicit fields are empty
                String labelName = mds.FEC_Field_Label_Name__c;
                if (String.isBlank(labelName) && mds.FEC_Additional_Field__r != null) {
                    labelName = mds.FEC_Additional_Field__r.FEC_Name_VN__c != null ? mds.FEC_Additional_Field__r.FEC_Name_VN__c : mds.FEC_Additional_Field__r.Name;
                }
                
                // Use setting Name as final fallback for label
                if (String.isBlank(labelName)) {
                    labelName = mds.Name;
                }
                
                String apiName = mds.FEC_Field_API_Name__c;
                if (String.isBlank(apiName) && mds.FEC_Additional_Field__r != null) {
                    apiName = mds.FEC_Additional_Field__r.FEC_Unique_ID__c != null ? mds.FEC_Additional_Field__r.FEC_Unique_ID__c : mds.FEC_Additional_Field__r.FEC_Code__c;
                }
                
                // Use setting Name as final fallback for API Name (to at least show something unique)
                if (String.isBlank(apiName)) {
                     apiName = mds.Name;
                }

                opt.put('label', labelName + ' (' + apiName + ')');
                opt.put('value', (String)mds.Id); // ID của Master Data Setting
                opt.put('fieldApiName', apiName);
                opt.put('dataType', mds.FEC_Additional_Field__r != null && mds.FEC_Additional_Field__r.FEC_Type__c != null ? mds.FEC_Additional_Field__r.FEC_Type__c : 'Text');
                options.add(opt);
            }
            return options;
        } catch (Exception e) {
            System.debug('[DEBUG] Error in getFieldsForStage: ' + e.getMessage() + ' LINE: ' + e.getLineNumber());
            throw new AuraHandledException('Lỗi tải danh sách trường: ' + e.getMessage());
        }
    }
}
