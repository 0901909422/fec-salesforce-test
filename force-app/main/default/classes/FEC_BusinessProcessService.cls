public with sharing class FEC_BusinessProcessService {
    /**
     * @description Fetches all active Business Processes and their associated Stages.
     * @return List<Map<String, Object>> Hierarchical tree of Business Processes and Stages.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getBusinessProcessTree() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        try {
            // 1. Fetch all active Business Processes
            List<FEC_Business_Process__c> businessProcesses = [
                SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c
                FROM FEC_Business_Process__c
                WHERE FEC_Active__c = true
                ORDER BY FEC_Order__c ASC NULLS LAST, Name ASC
            ];

            if (businessProcesses.isEmpty()) {
                return result;
            }

            // 2. Fetch all active Stages grouped by Business Process
            Map<Id, List<FEC_Case_Stage__c>> stagesByBP = new Map<Id, List<FEC_Case_Stage__c>>();
            List<FEC_Case_Stage__c> allStages = [
                SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c, FEC_Order__c
                FROM FEC_Case_Stage__c
                WHERE FEC_Active__c = true
                  AND FEC_Business_Process__c IN (SELECT Id FROM FEC_Business_Process__c WHERE FEC_Active__c = true)
                ORDER BY FEC_Business_Process__c ASC, FEC_Order__c ASC NULLS LAST, Name ASC
            ];

            for (FEC_Case_Stage__c stage : allStages) {
                if (!stagesByBP.containsKey(stage.FEC_Business_Process__c)) {
                    stagesByBP.put(stage.FEC_Business_Process__c, new List<FEC_Case_Stage__c>());
                }
                stagesByBP.get(stage.FEC_Business_Process__c).add(stage);
            }

            // 3. Build tree structure
            for (FEC_Business_Process__c bp : businessProcesses) {
                Map<String, Object> bpNode = new Map<String, Object>();
                bpNode.put('id', bp.Id);
                bpNode.put('label', bp.Name);
                bpNode.put('code', bp.FEC_Code__c);
                bpNode.put('nameVN', bp.FEC_Name_VN__c);
                bpNode.put('type', 'BUSINESS_PROCESS');
                bpNode.put('icon', 'utility:process');

                // Add Stages to Business Process
                List<Map<String, Object>> stageNodes = new List<Map<String, Object>>();
                if (stagesByBP.containsKey(bp.Id)) {
                    for (FEC_Case_Stage__c stage : stagesByBP.get(bp.Id)) {
                        Map<String, Object> stageNode = new Map<String, Object>();
                        stageNode.put('id', stage.Id);
                        stageNode.put('label', stage.Name);
                        stageNode.put('code', stage.FEC_Code__c);
                        stageNode.put('type', 'STAGE');
                        stageNode.put('parentId', bp.Id);
                        stageNode.put('icon', 'utility:steps');
                        stageNodes.add(stageNode);
                    }
                }

                bpNode.put('children', stageNodes);
                bpNode.put('childCount', stageNodes.size());
                result.add(bpNode);
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Business Process tree: ' + e.getMessage());
        }
    }

    /**
     * @description Lấy Decision Table (bảng quyết định) theo Business Process ID.
     * Decision Table: Current Stage + Conditions + Action → Next Stage
     * 
     * Dữ liệu từ 2 objects:
     * - FEC_Stage_Change__c: Previous Stage + Action → Next Stage (routing logic)
     * - FEC_Case_Stage__c: Stages thuộc Business Process
     * 
     * @param businessProcessId ID của FEC_Business_Process__c
     * @return List<Map<String, String>> Danh sách các decision rules
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDecisionTableByBP(String businessProcessId) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        if (String.isBlank(businessProcessId)) {
            return result;
        }

        try {
            // 1. Lấy tất cả Stage thuộc Business Process
            List<FEC_Case_Stage__c> stages = [
                SELECT Id, Name, FEC_Code__c
                FROM FEC_Case_Stage__c
                WHERE FEC_Business_Process__c = :businessProcessId
                  AND FEC_Active__c = true
                ORDER BY Name ASC
            ];

            if (stages.isEmpty()) {
                return result;
            }

            Set<Id> stageIds = new Set<Id>();
            Map<Id, String> stageNameMap = new Map<Id, String>();
            for (FEC_Case_Stage__c s : stages) {
                stageIds.add(s.Id);
                stageNameMap.put(s.Id, s.Name);
            }

            // 2. Lấy tất cả Stage Change rules (Previous Stage + Action → Next Stage)
            List<FEC_Stage_Change__c> changes = [
                SELECT Id, 
                       FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name,
                       FEC_Action_Button__c, FEC_Action_Button__r.Name, FEC_Action_Button__r.FEC_Code__c,
                       FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                       FEC_Active__c,
                       FEC_Next_Queue__c,
                       FEC_Team_User_Group__c
                FROM FEC_Stage_Change__c
                WHERE FEC_Previous_Stage__c IN :stageIds
                  AND FEC_Active__c = true
                ORDER BY FEC_Previous_Stage__r.Name ASC, FEC_Action_Button__r.Name ASC
            ];

            // Đảm bảo map chứa actionButtonId và nextStageId
            for (FEC_Stage_Change__c sc : changes) {
                Map<String, String> row = new Map<String, String>();
                row.put('rowId',         sc.Id);
                row.put('currentStage',  sc.FEC_Previous_Stage__r?.Name);
                row.put('currentStageId',sc.FEC_Previous_Stage__c);
                row.put('action',        sc.FEC_Action_Button__r?.Name);
                row.put('actionCode',    sc.FEC_Action_Button__r?.FEC_Code__c);
                row.put('actionButtonId',sc.FEC_Action_Button__c);          // ← ID của Action Button
                row.put('nextStage',     sc.FEC_Next_Stage__r?.Name);
                row.put('nextStageId',   sc.FEC_Next_Stage__c);             // ← ID của Next Stage
                row.put('nextQueue',     sc.FEC_Next_Queue__c);
                row.put('teamUserGroup', sc.FEC_Team_User_Group__c);
                result.add(row);
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading Decision Table: ' + e.getMessage());
        }
    }

    /**
     * Get Decision Table for MDM objects
     * businessProcessId có thể là Live BP ID hoặc MDM BP ID
     * → tự động resolve qua FEC_Code__c
     */
    @AuraEnabled
    public static List<Map<String, Object>> getDecisionTableByBPMDM(Id businessProcessId) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        try {
            // Resolve MDM BP ID: nếu truyền vào là Live BP ID, tìm MDM BP có cùng FEC_Code__c
            Id mdmBPId = businessProcessId;
            List<FEC_Business_Process__c> liveBPList = [
                SELECT Id, FEC_Code__c FROM FEC_Business_Process__c WHERE Id = :businessProcessId LIMIT 1
            ];
            if (!liveBPList.isEmpty() && String.isNotBlank(liveBPList[0].FEC_Code__c)) {
                List<FEC_MDM_Business_Process__c> mdmBPList = [
                    SELECT Id FROM FEC_MDM_Business_Process__c
                    WHERE FEC_Code__c = :liveBPList[0].FEC_Code__c LIMIT 1
                ];
                if (!mdmBPList.isEmpty()) {
                    mdmBPId = mdmBPList[0].Id;
                }
            }

            List<FEC_MDM_Stage_Change__c> stageChanges = [
                SELECT Id, Name, FEC_Code__c,
                       FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name, FEC_Previous_Stage__r.FEC_Code__c,
                       FEC_Previous_Stage__r.FEC_Business_Process__c,
                       FEC_Action_Button__c, FEC_Action_Button__r.Name, FEC_Action_Button__r.FEC_Code__c,
                       FEC_Next_Stage__c, FEC_Next_Stage__r.Name, FEC_Next_Stage__r.FEC_Code__c,
                       FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c,
                       Process_Change_Status__c
                FROM FEC_MDM_Stage_Change__c
                WHERE FEC_Previous_Stage__r.FEC_Business_Process__c = :mdmBPId
                ORDER BY FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name
            ];

            for (FEC_MDM_Stage_Change__c sc : stageChanges) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('rowId',            sc.Id);
                row.put('code',             sc.FEC_Code__c);
                row.put('currentStage',     sc.FEC_Previous_Stage__r != null ? sc.FEC_Previous_Stage__r.Name : '--');
                row.put('currentStageId',   sc.FEC_Previous_Stage__c);
                row.put('currentStageCode', sc.FEC_Previous_Stage__r != null ? sc.FEC_Previous_Stage__r.FEC_Code__c : null);
                row.put('action',           sc.FEC_Action_Button__r  != null ? sc.FEC_Action_Button__r.Name  : '--');
                row.put('actionId',         sc.FEC_Action_Button__c);
                row.put('actionCode',       sc.FEC_Action_Button__r  != null ? sc.FEC_Action_Button__r.FEC_Code__c  : null);
                row.put('nextStage',        sc.FEC_Next_Stage__r     != null ? sc.FEC_Next_Stage__r.Name     : '--');
                row.put('nextStageId',      sc.FEC_Next_Stage__c);
                row.put('nextStageCode',    sc.FEC_Next_Stage__r     != null ? sc.FEC_Next_Stage__r.FEC_Code__c     : null);
                row.put('nextQueue',        sc.FEC_Next_Queue__c);
                row.put('teamUserGroup',    sc.FEC_Team_User_Group__c);
                row.put('active',           sc.FEC_Active__c);
                row.put('processChangeStatus', sc.Process_Change_Status__c);
                rows.add(row);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error loading MDM Decision Table: ' + e.getMessage());
        }
        return rows;
    }

    /**
     * @description Save or update FEC_Stage_Change__c rule
     * @param stagChangeData Map containing: previousStageId, actionButtonId, nextStageId, nextQueue, teamUserGroup, [recordId]
     * @return String ID của record vừa save
     */
    @AuraEnabled
    public static String saveStagChangeRule(Map<String, Object> stagChangeData) {
        try {
            String recordId = (String) stagChangeData.get('recordId');
            String previousStageId = (String) stagChangeData.get('previousStageId');
            String actionButtonId = (String) stagChangeData.get('actionButtonId');
            String nextStageId = (String) stagChangeData.get('nextStageId');
            String nextQueue = (String) stagChangeData.get('nextQueue');
            String teamUserGroup = (String) stagChangeData.get('teamUserGroup');

            // Validate required fields
            if (String.isBlank(previousStageId) || String.isBlank(actionButtonId) || String.isBlank(nextStageId)) {
                throw new IllegalArgumentException(System.Label.FEC_Error_Required_Stage_Fields);
            }

            FEC_Stage_Change__c rule;
            if (String.isNotBlank(recordId)) {
                // Update existing
                rule = new FEC_Stage_Change__c(Id = recordId);
            } else {
                // Insert new
                rule = new FEC_Stage_Change__c();
                rule.FEC_Active__c = true; // Default active for new rules
            }

            rule.FEC_Previous_Stage__c = previousStageId;
            rule.FEC_Action_Button__c = actionButtonId;
            rule.FEC_Next_Stage__c = nextStageId;
            rule.FEC_Next_Queue__c = nextQueue;
            rule.FEC_Team_User_Group__c = teamUserGroup;

            upsert rule;

            return rule.Id;

        } catch (DmlException dml) {
            throw new AuraHandledException(System.Label.FEC_Error_DML_Prefix + ' ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Save_Rule + ' ' + e.getMessage());
        }
    }

    /**
     * @description Delete FEC_Stage_Change__c rule
     * @param recordId ID của rule cần xóa
     */
    @AuraEnabled
    public static void deleteStagChangeRule(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                throw new IllegalArgumentException(System.Label.FEC_Error_Record_ID_Required);
            }

            FEC_Stage_Change__c rule = new FEC_Stage_Change__c(Id = recordId);
            delete rule;

        } catch (DmlException dml) {
            throw new AuraHandledException(System.Label.FEC_Error_DML_Prefix + ' ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Delete_Rule + ' ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getStagesByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_Case_Stage__c> stages = [
            SELECT Id, Name
            FROM FEC_Case_Stage__c
            WHERE FEC_Business_Process__c = :businessProcessId
            AND FEC_Active__c = true
            ORDER BY FEC_Order__c ASC
        ];
        for (FEC_Case_Stage__c s : stages) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', s.Name);
            opt.put('value', s.Id);
            options.add(opt);
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActionButtonsByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_Action_Button__c> buttons = [
            SELECT Id, Name
            FROM FEC_Action_Button__c
            WHERE FEC_Active__c = true
            ORDER BY Name ASC
        ];
        for (FEC_Action_Button__c b : buttons) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', b.Name);
            opt.put('value', b.Id);
            options.add(opt);
        }
        return options;
    }

    /**
     * Get MDM Stage options for a given Business Process (used in modal combobox).
     * IMPORTANT: value = FEC_Code__c (immutable, validation rule locked) instead of Id/Name.
     *           This makes Decision Rules survive Stage rename and cross-environment deployment.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMDMStageOptions(Id businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (FEC_MDM_Case_Stage__c stage : [
            SELECT Id, Name, FEC_Code__c FROM FEC_MDM_Case_Stage__c
            WHERE FEC_Business_Process__c = :businessProcessId
              AND FEC_Code__c != null
            ORDER BY Name
        ]) {
            options.add(new Map<String, String>{
                'label' => stage.Name,
                'value' => stage.FEC_Code__c
            });
        }
        return options;
    }

    /** Get all MDM Action Button options (used in modal combobox) */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getMDMActionButtonOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (FEC_MDM_Action_Button__c ab : [
            SELECT Id, Name FROM FEC_MDM_Action_Button__c
            WHERE FEC_Active__c = true
            ORDER BY Name
        ]) {
            options.add(new Map<String, String>{ 'label' => ab.Name, 'value' => ab.Id });
        }
        return options;
    }

    /**
     * @description Lấy danh sách Queue (Group WHERE Type = 'Queue') để dùng làm dropdown
     *              cho cột "Next Queue" trong Decision Table.
     *              Trả về DeveloperName làm value để bền vững khi rename queue label.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getQueueOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Group q : [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            ORDER BY Name
        ]) {
            options.add(new Map<String, String>{
                'label' => q.Name,
                'value' => q.DeveloperName
            });
        }
        return options;
    }

    /** Save (insert or update) a MDM Stage Change Rule */
    @AuraEnabled
    public static void saveMDMStageChangeRule(String ruleData) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(ruleData);
            String  recordId        = (String) data.get('recordId');
            Id      previousStageId = (Id) data.get('previousStageId');
            Id      actionButtonId  = (Id) data.get('actionButtonId');
            Id      nextStageId     = (Id) data.get('nextStageId');
            String  nextQueue       = (String) data.get('nextQueue');
            String  teamUserGroup   = (String) data.get('teamUserGroup');

            FEC_MDM_Stage_Change__c rule = String.isNotBlank(recordId)
                ? new FEC_MDM_Stage_Change__c(Id = recordId)
                : new FEC_MDM_Stage_Change__c();

            rule.FEC_Previous_Stage__c  = previousStageId;
            rule.FEC_Action_Button__c   = actionButtonId;
            rule.FEC_Next_Stage__c      = nextStageId;
            rule.FEC_Next_Queue__c      = nextQueue;
            rule.FEC_Team_User_Group__c = teamUserGroup;

            upsert rule;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving MDM Stage Change Rule: ' + e.getMessage());
        }
    }

    /** Delete a MDM Stage Change Rule by Id */
    @AuraEnabled
    public static void deleteMDMStageChangeRule(Id recordId) {
        try {
            delete [SELECT Id FROM FEC_MDM_Stage_Change__c WHERE Id = :recordId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting MDM Stage Change Rule: ' + e.getMessage());
        }
    }
}