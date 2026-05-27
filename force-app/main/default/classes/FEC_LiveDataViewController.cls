/**
 * @description Read-only controller for Live Data View.
 * Queries Live objects (FEC_*) with FLS enforcement.
 * NO DML operations — all methods are cacheable read-only.
 * @date 2025
 */
public with sharing class FEC_LiveDataViewController {

    /**
     * @description Query Live NOC records and build tree structure.
     * Delegates to FEC_NatureOfCaseTreeBuilder.buildTree(List<FEC_Nature_Of_Case__c>).
     * @return List<FEC_NatureOfCaseTreeItem> Tree items for NOC hierarchy
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_NatureOfCaseTreeItem> getLiveNocTreeData() {
        try {
            List<FEC_Nature_Of_Case__c> listNOC = [
                SELECT
                    Id, Name, FEC_Customer_Type__c,
                    FEC_Product_Type__c,
                    FEC_Product_Type__r.Name, FEC_Product_Type__r.FEC_Alias__c,
                    FEC_Product_Type__r.FEC_Code__c, FEC_Product_Type__r.FEC_Name_VN__c,
                    FEC_Product_Type__r.FEC_Active__c,
                    FEC_Business_Process__c,
                    FEC_Business_Process__r.Name, FEC_Business_Process__r.FEC_Alias__c,
                    FEC_Business_Process__r.FEC_Code__c, FEC_Business_Process__r.FEC_Name_VN__c,
                    FEC_Business_Process__r.FEC_Active__c,
                    FEC_Category__c,
                    FEC_Category__r.Name, FEC_Category__r.FEC_Alias__c,
                    FEC_Category__r.FEC_Code__c, FEC_Category__r.FEC_Name_VN__c,
                    FEC_Category__r.FEC_Active__c,
                    FEC_Sub_Category__c,
                    FEC_Sub_Category__r.Name, FEC_Sub_Category__r.FEC_Alias__c,
                    FEC_Sub_Category__r.FEC_Code__c, FEC_Sub_Category__r.FEC_Name_VN__c,
                    FEC_Sub_Category__r.FEC_Active__c,
                    FEC_Sub_Code__c,
                    FEC_Sub_Code__r.Name, FEC_Sub_Code__r.FEC_Alias__c,
                    FEC_Sub_Code__r.FEC_Code__c, FEC_Sub_Code__r.FEC_Name_VN__c,
                    FEC_Sub_Code__r.FEC_Active__c
                FROM FEC_Nature_Of_Case__c
                
                ORDER BY
                    FEC_Product_Type__r.Name ASC,
                    FEC_Business_Process__r.Name ASC,
                    FEC_Category__r.Name ASC,
                    FEC_Sub_Category__r.Name ASC,
                    FEC_Sub_Code__r.Name ASC
            ];

            List<FEC_Nature_Of_Case__c> safeNOC = (List<FEC_Nature_Of_Case__c>)
                Security.stripInaccessible(AccessType.READABLE, listNOC).getRecords();
            return FEC_NatureOfCaseTreeBuilder.buildTree(safeNOC);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get case stages filtered by Business Process ID.
     * @param businessProcessId The Business Process record ID
     * @return List<Map<String, String>> Stage options with Name, Code, Id
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveCaseStagesByBP(String businessProcessId) {
        if (String.isBlank(businessProcessId)) return new List<Map<String, String>>();
        try {
            List<FEC_Case_Stage__c> stages = [
                SELECT Id, Name, FEC_Code__c
                FROM FEC_Case_Stage__c
                WHERE FEC_Business_Process__c = :businessProcessId
                
                ORDER BY Name ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, stages).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Case_Stage__c stage : (List<FEC_Case_Stage__c>) safe) {
                result.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => stage.Name,
                    FEC_UIConstants.MAP_VALUE => stage.Id,
                    'code' => stage.FEC_Code__c
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get all Live channels.
     * @return List<FEC_Channel__c> Channel records
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Channel__c> getLiveChannels() {
        try {
            List<FEC_Channel__c> channels = [
                SELECT Id, Name, FEC_Channel_ID__c, FEC_Channel_Vietnamese_name__c, FEC_Channel_Status__c
                FROM FEC_Channel__c
                
                ORDER BY Name ASC
            ];
            return (List<FEC_Channel__c>)
                Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get all Live case channels.
     * @return List<FEC_Case_Channel__c> Case channel records
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Case_Channel__c> getLiveCaseChannels() {
        try {
            List<FEC_Case_Channel__c> caseChannels = [
                SELECT Id, Name, FEC_Code__c, FEC_Channel_Status__c,
                       FEC_Self_Service_Flag__c
                FROM FEC_Case_Channel__c
                
                ORDER BY Name ASC
            ];
            return (List<FEC_Case_Channel__c>)
                Security.stripInaccessible(AccessType.READABLE, caseChannels).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get all Live additional fields.
     * @return List<FEC_Additional_Field__c> Additional field records
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field__c> getLiveAdditionalFields() {
        try {
            List<FEC_Additional_Field__c> fields = [
                SELECT Id, FEC_Unique_ID__c, Name, FEC_Type__c,
                       FEC_Field_Status__c, FEC_Field_Mandatory__c
                FROM FEC_Additional_Field__c
                
                ORDER BY Name ASC
            ];
            return (List<FEC_Additional_Field__c>)
                Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get list values for a specific additional field.
     * @param fieldId The Additional Field record ID
     * @return List<FEC_Additional_Field_List_Value__c> List value records
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Additional_Field_List_Value__c> getLiveFieldListValues(String fieldId) {
        if (String.isBlank(fieldId)) return new List<FEC_Additional_Field_List_Value__c>();
        try {
            List<FEC_Additional_Field_List_Value__c> listValues = [
                SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Order__c
                FROM FEC_Additional_Field_List_Value__c
                WHERE FEC_Additional_Field__c = :fieldId
                
                ORDER BY FEC_Order__c ASC
            ];
            return (List<FEC_Additional_Field_List_Value__c>)
                Security.stripInaccessible(AccessType.READABLE, listValues).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get Business Process options for selectors (label/value maps).
     * @return List<Map<String, String>> BP options
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveBusinessProcessOptions() {
        try {
            List<FEC_Business_Process__c> bps = [
                SELECT Id, Name, FEC_Code__c
                FROM FEC_Business_Process__c
                
                ORDER BY Name ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, bps).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Business_Process__c bp : (List<FEC_Business_Process__c>) safe) {
                result.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => bp.Name,
                    FEC_UIConstants.MAP_VALUE => bp.Id
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get Live Master Data Settings for a NOC + Stage combination.
     * Partitions by integration flag: isIntegration=false returns Property Config
     * (FEC_Data_Integration_Mapping__c IS NULL), isIntegration=true returns
     * Fraud Mapping (FEC_Data_Integration_Mapping__c IS NOT NULL).
     * @param nocId Nature of Case record ID (or Business Process ID — will find all NOC records for this BP)
     * @param stageId Case Stage record ID
     * @param isIntegration true for Fraud Mapping, false for Property Config
     * @return List<FEC_Master_Data_Setting__c> Filtered settings records
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Master_Data_Setting__c> getLiveMasterDataSettings(String nocId, String stageId, Boolean isIntegration) {
        if (String.isBlank(nocId) || String.isBlank(stageId)) {
            return new List<FEC_Master_Data_Setting__c>();
        }
        try {
            // Collect all NOC Ids: try direct match first, then try as BP Id
            Set<Id> nocIds = new Set<Id>();
            nocIds.add(nocId);
            // Also find all NOC records belonging to the same Business Process
            List<FEC_Nature_Of_Case__c> relatedNocs = [
                SELECT Id FROM FEC_Nature_Of_Case__c
                WHERE FEC_Business_Process__c = :nocId
                
            ];
            for (FEC_Nature_Of_Case__c n : relatedNocs) {
                nocIds.add(n.Id);
            }

            List<FEC_Master_Data_Setting__c> settings;
            if (isIntegration != null && isIntegration) {
                settings = [
                    SELECT Id, Name, FEC_Field_API_Name__c, FEC_Field_Label_Name__c,
                           FEC_Field_Object_Name__c, FEC_Field_Status__c,
                           FEC_Field_ReadOnly__c, FEC_Field_Mandatory__c,
                           FEC_Field_Order_Display__c,
                           FEC_Section__c, FEC_Sub_Section__c, FEC_Sub_Section_Order__c,
                           FEC_Sub_Section_Layout__c, FEC_Sub_Section_Field_Layout__c,
                           FEC_Channel__c, FEC_Applicable_Role__c,
                           FEC_Field_Editable__c, FEC_Field_Masking__c,
                           FEC_Masking_Type__c, FEC_Field_Reverted__c,
                           FEC_Editable_Role__c,
                           FEC_Data_Integration_Mapping__r.Name
                    FROM FEC_Master_Data_Setting__c
                    WHERE FEC_Nature_Of_Case__c IN :nocIds
                      AND FEC_Stage_Name__c = :stageId
                      AND FEC_Data_Integration_Mapping__c != NULL
                    ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC
                ];
            } else {
                settings = [
                    SELECT Id, Name, FEC_Field_API_Name__c, FEC_Field_Label_Name__c,
                           FEC_Field_Object_Name__c, FEC_Field_Status__c,
                           FEC_Field_ReadOnly__c, FEC_Field_Mandatory__c,
                           FEC_Field_Order_Display__c,
                           FEC_Section__c, FEC_Sub_Section__c, FEC_Sub_Section_Order__c,
                           FEC_Sub_Section_Layout__c, FEC_Sub_Section_Field_Layout__c,
                           FEC_Channel__c, FEC_Applicable_Role__c,
                           FEC_Field_Editable__c, FEC_Field_Masking__c,
                           FEC_Masking_Type__c, FEC_Field_Reverted__c,
                           FEC_Editable_Role__c
                    FROM FEC_Master_Data_Setting__c
                    WHERE FEC_Nature_Of_Case__c IN :nocIds
                      AND FEC_Stage_Name__c = :stageId
                      AND FEC_Data_Integration_Mapping__c = NULL
                    ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC
                ];
            }
            return (List<FEC_Master_Data_Setting__c>)
                Security.stripInaccessible(AccessType.READABLE, settings).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get Live Stage Change rules for a Business Process.
     * Returns stage transition rules with relationship fields for display.
     * @param businessProcessId The Business Process record ID
     * @return List<Map<String, String>> Stage change rules with Previous Stage, Action, Next Stage, etc.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveStageChangeRules(String businessProcessId) {
        if (String.isBlank(businessProcessId)) {
            return new List<Map<String, String>>();
        }
        try {
            // Get all stages belonging to this Business Process
            List<FEC_Case_Stage__c> stages = [
                SELECT Id
                FROM FEC_Case_Stage__c
                WHERE FEC_Business_Process__c = :businessProcessId
                
            ];
            if (stages.isEmpty()) {
                return new List<Map<String, String>>();
            }

            Set<Id> stageIds = new Set<Id>();
            for (FEC_Case_Stage__c s : stages) {
                stageIds.add(s.Id);
            }

            // Query stage change rules where Previous Stage belongs to this BP
            List<FEC_Stage_Change__c> changes = [
                SELECT Id,
                       FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name,
                       FEC_Action_Button__c, FEC_Action_Button__r.Name,
                       FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                       FEC_Next_Queue__c,
                       FEC_Team_User_Group__c
                FROM FEC_Stage_Change__c
                WHERE FEC_Previous_Stage__c IN :stageIds
                
                ORDER BY FEC_Previous_Stage__r.Name ASC, FEC_Action_Button__r.Name ASC
            ];

            List<SObject> safeChanges = Security.stripInaccessible(AccessType.READABLE, changes).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Stage_Change__c sc : (List<FEC_Stage_Change__c>) safeChanges) {
                Map<String, String> row = new Map<String, String>();
                row.put('rowId', sc.Id);
                row.put('previousStage', sc.FEC_Previous_Stage__r?.Name);
                row.put('actionButton', sc.FEC_Action_Button__r?.Name);
                row.put('nextStage', sc.FEC_Next_Stage__r?.Name);
                row.put('nextQueue', sc.FEC_Next_Queue__c);
                row.put('teamUserGroup', sc.FEC_Team_User_Group__c);
                result.add(row);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    // ── Review Tab Methods ────────────────────────────────────────────────

    /**
     * @description Get distinct customer types from Live NOC records for Review cascading filter.
     * @return List<Map<String, String>> Customer type options with label/value
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewCustomerTypes() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Customer_Type__c ct
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Customer_Type__c != NULL
                
                GROUP BY FEC_Customer_Type__c
            ]) {
                String val = (String) ar.get(FEC_Constants.ALIAS_CT);
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => val,
                    FEC_UIConstants.MAP_VALUE => val
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get product type options filtered by customer type from Live NOC records.
     * @param customerType The customer type filter value
     * @return List<Map<String, String>> Product type options with label (Code) / value (Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewProductOptions(String customerType) {
        if (String.isBlank(customerType)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Product_Type__r.Id pId, FEC_Product_Type__r.FEC_Code__c pCode
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Customer_Type__c = :customerType
                
                GROUP BY FEC_Product_Type__r.Id, FEC_Product_Type__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_P_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_P_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get business process options filtered by product type from Live NOC records.
     * @param productId The Product Type record ID
     * @return List<Map<String, String>> Business process options with label (Code) / value (Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewBizOptions(String productId) {
        if (String.isBlank(productId)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Business_Process__r.Id bId, FEC_Business_Process__r.FEC_Code__c bCode
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Product_Type__c = :productId
                
                GROUP BY FEC_Business_Process__r.Id, FEC_Business_Process__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_B_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_B_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get category options filtered by product type and business process from Live NOC records.
     * @param productId The Product Type record ID
     * @param bizId The Business Process record ID
     * @return List<Map<String, String>> Category options with label (Code) / value (Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewCategoryOptions(String productId, String bizId) {
        if (String.isBlank(productId) || String.isBlank(bizId)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Category__r.Id cId, FEC_Category__r.FEC_Code__c cCode
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Product_Type__c = :productId
                  AND FEC_Business_Process__c = :bizId
                
                GROUP BY FEC_Category__r.Id, FEC_Category__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_C_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_C_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get sub-category options filtered by product type, business process, and category from Live NOC records.
     * @param productId The Product Type record ID
     * @param bizId The Business Process record ID
     * @param catId The Category record ID
     * @return List<Map<String, String>> Sub-category options with label (Code) / value (Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewSubCatOptions(String productId, String bizId, String catId) {
        if (String.isBlank(productId) || String.isBlank(bizId) || String.isBlank(catId)) {
            return new List<Map<String, String>>();
        }
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Sub_Category__r.Id scId, FEC_Sub_Category__r.FEC_Code__c scCode
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Product_Type__c = :productId
                  AND FEC_Business_Process__c = :bizId
                  AND FEC_Category__c = :catId
                
                GROUP BY FEC_Sub_Category__r.Id, FEC_Sub_Category__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SC_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SC_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Get sub-code options filtered by product type, business process, category, and sub-category from Live NOC records.
     * @param productId The Product Type record ID
     * @param bizId The Business Process record ID
     * @param catId The Category record ID
     * @param subCatId The Sub Category record ID
     * @return List<Map<String, String>> Sub-code options with label (Code) / value (Id)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLiveReviewSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        if (String.isBlank(productId) || String.isBlank(bizId) || String.isBlank(catId) || String.isBlank(subCatId)) {
            return new List<Map<String, String>>();
        }
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Sub_Code__r.Id sccId, FEC_Sub_Code__r.FEC_Code__c sccCode
                FROM FEC_Nature_Of_Case__c
                WHERE FEC_Product_Type__c = :productId
                  AND FEC_Business_Process__c = :bizId
                  AND FEC_Category__c = :catId
                  AND FEC_Sub_Category__c = :subCatId
                
                GROUP BY FEC_Sub_Code__r.Id, FEC_Sub_Code__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SCC_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SCC_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    // ── Data Tabs & Decision Table Methods ──────────────────────────────

    /**
     * @description Return all Live master data for Data Gốc tab.
     * Adapted from FEC_CleanUpMasterDataController.getAllMasterData() with FLS enforcement.
     * @return Map<String, List<Object>> with 13 object types
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllLiveMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        try {
            masterDataMap.put(FEC_ObjectConstants.KEY_PRODUCT_TYPE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                     FROM FEC_Product_Type__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_BUSINESS_PROCESS,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                     FROM FEC_Business_Process__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CATEGORY,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                     FROM FEC_Category__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CATEGORY,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                     FROM FEC_Sub_Category__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CODE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                     FROM FEC_Sub_Code__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_MASTER_SETTING,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Stage_Name__c, FEC_Nature_Of_Case__c, FEC_Channel__c
                     FROM FEC_Master_Data_Setting__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CHANNEL,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c
                     FROM FEC_Channel__c  ORDER BY Name]
                ).getRecords());

            // Nature Of Case — use wrapper for relationship field display
            List<FEC_Nature_Of_Case__c> nocList = [
                SELECT Id, Name, FEC_Code__c, FEC_Product_Type__r.Name, FEC_Business_Process__r.Name,
                       FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name
                FROM FEC_Nature_Of_Case__c
                
            ];
            List<SObject> safeNocList = Security.stripInaccessible(AccessType.READABLE, nocList).getRecords();
            List<FEC_CleanUpMasterDataController.NatureOfCaseWrapper> nocWrapperList =
                new List<FEC_CleanUpMasterDataController.NatureOfCaseWrapper>();
            for (FEC_Nature_Of_Case__c noc : (List<FEC_Nature_Of_Case__c>) safeNocList) {
                nocWrapperList.add(new FEC_CleanUpMasterDataController.NatureOfCaseWrapper(noc));
            }
            masterDataMap.put(FEC_ObjectConstants.KEY_NATURE_OF_CASE, nocWrapperList);

            masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c
                     FROM FEC_Additional_Field__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD_LIST,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c
                     FROM FEC_Additional_Field_List_Value__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CASE_STAGE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c
                     FROM FEC_Case_Stage__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put('ActionButton',
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c
                     FROM FEC_Action_Button__c  ORDER BY Name]
                ).getRecords());

            // Stage Change — use wrapper for relationship field display
            List<FEC_Stage_Change__c> scList = [
                SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name,
                       FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c
                FROM FEC_Stage_Change__c
                
            ];
            List<SObject> safeScList = Security.stripInaccessible(AccessType.READABLE, scList).getRecords();
            List<FEC_CleanUpMasterDataController.StageChangeWrapper> scWrapperList =
                new List<FEC_CleanUpMasterDataController.StageChangeWrapper>();
            for (FEC_Stage_Change__c sc : (List<FEC_Stage_Change__c>) safeScList) {
                scWrapperList.add(new FEC_CleanUpMasterDataController.StageChangeWrapper(sc));
            }
            masterDataMap.put('StageChange', scWrapperList);

        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }

    /**
     * @description Return all MDM master data for Data Clone tab.
     * Adapted from FEC_CleanUpMasterDataController.getAllMasterDataMDM() with FLS enforcement.
     * @return Map<String, List<Object>> with MDM object types
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMdmMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        try {
            masterDataMap.put(FEC_ObjectConstants.KEY_PRODUCT_TYPE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                     FROM FEC_MDM_Product_Type__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_BUSINESS_PROCESS,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c
                     FROM FEC_MDM_Business_Process__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CATEGORY,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                     FROM FEC_MDM_Category__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CATEGORY,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                     FROM FEC_MDM_Sub_Category__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CODE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                     FROM FEC_MDM_Sub_Code__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_MASTER_SETTING,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Additional_Field__c, FEC_Nature_Of_Case__c,
                            FEC_Stage_Name__c, FEC_Channel__c, FEC_Applicable_Role__c,
                            FEC_Data_Integration_Mapping__c, Process_Change_Status__c
                     FROM FEC_MDM_Master_Data_Setting__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CHANNEL,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, Process_Change_Status__c
                     FROM FEC_MDM_Channel__c  ORDER BY Name]
                ).getRecords());

            // MDM Nature Of Case — use wrapper for relationship field display
            List<FEC_MDM_Nature_Of_Case__c> nocList = [
                SELECT Id, Name, FEC_Code__c, FEC_Customer_Type__c, FEC_Product_Type__r.Name,
                       FEC_Business_Process__r.Name, FEC_Category__r.Name, FEC_Sub_Category__r.Name,
                       FEC_Sub_Code__r.Name, Process_Change_Status__c
                FROM FEC_MDM_Nature_Of_Case__c
                
            ];
            List<SObject> safeNocList = Security.stripInaccessible(AccessType.READABLE, nocList).getRecords();
            List<FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper> nocWrapperList =
                new List<FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper>();
            for (FEC_MDM_Nature_Of_Case__c noc : (List<FEC_MDM_Nature_Of_Case__c>) safeNocList) {
                nocWrapperList.add(new FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper(noc));
            }
            masterDataMap.put(FEC_ObjectConstants.KEY_NATURE_OF_CASE, nocWrapperList);

            masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c, Process_Change_Status__c
                     FROM FEC_MDM_Additional_Field__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD_LIST,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c, Process_Change_Status__c
                     FROM FEC_MDM_Additional_Field_List_Value__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put(FEC_ObjectConstants.KEY_CASE_STAGE,
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c, Process_Change_Status__c
                     FROM FEC_MDM_Case_Stage__c  ORDER BY Name]
                ).getRecords());

            masterDataMap.put('ActionButton',
                Security.stripInaccessible(AccessType.READABLE,
                    [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c, Process_Change_Status__c
                     FROM FEC_MDM_Action_Button__c  ORDER BY Name]
                ).getRecords());

            // MDM Stage Change — use wrapper for relationship field display
            List<FEC_MDM_Stage_Change__c> scListMdm = [
                SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name,
                       FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c, Process_Change_Status__c
                FROM FEC_MDM_Stage_Change__c
                
            ];
            List<SObject> safeScList = Security.stripInaccessible(AccessType.READABLE, scListMdm).getRecords();
            List<FEC_CleanUpMasterDataController.StageChangeMDMWrapper> scWrapperListMdm =
                new List<FEC_CleanUpMasterDataController.StageChangeMDMWrapper>();
            for (FEC_MDM_Stage_Change__c sc : (List<FEC_MDM_Stage_Change__c>) safeScList) {
                scWrapperListMdm.add(new FEC_CleanUpMasterDataController.StageChangeMDMWrapper(sc));
            }
            masterDataMap.put('StageChange', scWrapperListMdm);

        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }

    /**
     * @description Return BP → Property mapping tree for ServiceType tab.
     * Adapted from FEC_FecServiceTypeMappingController.getServiceTypeTree() but queries Live objects.
     * @return List<Map<String, Object>> Tree structure with BP parents and property children
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLiveServiceTypeTree() {
        try {
            Map<Id, FEC_Business_Process__c> bpMap = new Map<Id, FEC_Business_Process__c>(
                [SELECT Id, Name FROM FEC_Business_Process__c  ORDER BY Name]
            );

            List<FEC_Master_Data_Setting__c> allSettings = [
                SELECT Id, Name, FEC_Additional_Field__r.Name, Property_Reference__c,
                       FEC_Nature_Of_Case__r.FEC_Business_Process__c
                FROM FEC_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__r.FEC_Business_Process__c IN :bpMap.keySet()
                  AND FEC_Additional_Field__c != NULL
                
                ORDER BY Name
            ];
            List<SObject> safeSettings = Security.stripInaccessible(AccessType.READABLE, allSettings).getRecords();

            Map<Id, List<Map<String, Object>>> bpToProperties = new Map<Id, List<Map<String, Object>>>();
            for (FEC_Master_Data_Setting__c setting : (List<FEC_Master_Data_Setting__c>) safeSettings) {
                Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process__c;
                if (!bpToProperties.containsKey(bpId)) {
                    bpToProperties.put(bpId, new List<Map<String, Object>>());
                }
                String displayLabel = setting.FEC_Additional_Field__r != null
                    ? setting.FEC_Additional_Field__r.Name : setting.Name;
                bpToProperties.get(bpId).add(new Map<String, Object>{
                    FEC_UIConstants.MAP_LABEL => displayLabel,
                    FEC_UIConstants.MAP_NAME => setting.Id,
                    FEC_UIConstants.MAP_PROPERTY_REF => setting.Property_Reference__c,
                    FEC_UIConstants.MAP_PARENT_NAME => bpMap.get(bpId).Name
                });
            }

            List<Map<String, Object>> treeData = new List<Map<String, Object>>();
            for (FEC_Business_Process__c bp : bpMap.values()) {
                List<Map<String, Object>> children = bpToProperties.containsKey(bp.Id)
                    ? bpToProperties.get(bp.Id)
                    : new List<Map<String, Object>>();
                treeData.add(new Map<String, Object>{
                    FEC_UIConstants.MAP_LABEL => bp.Name,
                    FEC_UIConstants.MAP_NAME => bp.Id,
                    FEC_UIConstants.MAP_EXPANDED => false,
                    FEC_UIConstants.MAP_ITEMS => children
                });
            }
            return treeData;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Return dynamic decision table for a Business Process from Live objects.
     * Adapted from FEC_DecisionTableController.getDynamicDecisionTable() with FLS enforcement.
     * Reuses FEC_DecisionTableController.TableWrapper pattern.
     * @param businessProcessId The Business Process record ID
     * @return FEC_DecisionTableController.TableWrapper Decision table structure
     */
    @AuraEnabled(cacheable=true)
    public static FEC_DecisionTableController.TableWrapper getLiveDynamicDecisionTable(String businessProcessId) {
        FEC_DecisionTableController.TableWrapper result = new FEC_DecisionTableController.TableWrapper();
        result.conditionCols = new List<FEC_DecisionTableController.ColumnWrapper>();
        result.actionCols = new List<FEC_DecisionTableController.ColumnWrapper>();
        result.rows = new List<FEC_DecisionTableController.RowWrapper>();

        if (String.isBlank(businessProcessId)) return result;

        try {
            List<FEC_Decision_Table__c> tables = [
                SELECT Id
                FROM FEC_Decision_Table__c
                WHERE FEC_Business_Process__c = :businessProcessId
                  AND FEC_Active__c = true
                
                LIMIT 1
            ];
            if (tables.isEmpty()) return result;

            result.tableId = tables[0].Id;

            List<FEC_Decision_Column__c> listCols = [
                SELECT Id, Name, FEC_Column_Type__c
                FROM FEC_Decision_Column__c
                WHERE FEC_Decision_Table__c = :result.tableId
                
                ORDER BY FEC_Column_Type__c DESC, FEC_Order__c ASC
            ];
            List<SObject> safeCols = Security.stripInaccessible(AccessType.READABLE, listCols).getRecords();

            for (FEC_Decision_Column__c col : (List<FEC_Decision_Column__c>) safeCols) {
                FEC_DecisionTableController.ColumnWrapper cw = new FEC_DecisionTableController.ColumnWrapper();
                cw.id = col.Id;
                cw.label = col.Name;
                cw.type = col.FEC_Column_Type__c;
                if (col.FEC_Column_Type__c == 'Condition') {
                    result.conditionCols.add(cw);
                } else {
                    result.actionCols.add(cw);
                }
            }

            Map<Id, FEC_DecisionTableController.RowWrapper> rowMap = new Map<Id, FEC_DecisionTableController.RowWrapper>();
            List<FEC_Decision_Row__c> rowRecords = [
                SELECT Id
                FROM FEC_Decision_Row__c
                WHERE FEC_Decision_Table__c = :result.tableId
                
                ORDER BY FEC_Priority__c ASC
            ];
            for (FEC_Decision_Row__c r : rowRecords) {
                FEC_DecisionTableController.RowWrapper rw = new FEC_DecisionTableController.RowWrapper();
                rw.rowId = r.Id;
                rw.conditionCells = new List<FEC_DecisionTableController.CellWrapper>();
                rw.actionCells = new List<FEC_DecisionTableController.CellWrapper>();
                rw.allSearchableCells = new List<FEC_DecisionTableController.CellWrapper>();
                rowMap.put(r.Id, rw);
                result.rows.add(rw);
            }

            Map<String, String> cellValueMap = new Map<String, String>();
            for (FEC_Decision_Cell__c cell : [
                SELECT FEC_Decision_Row__c, FEC_Decision_Column__c, FEC_Value__c
                FROM FEC_Decision_Cell__c
                WHERE FEC_Decision_Row__c IN :rowMap.keySet()
                
            ]) {
                cellValueMap.put(cell.FEC_Decision_Row__c + '-' + cell.FEC_Decision_Column__c, cell.FEC_Value__c);
            }

            for (FEC_DecisionTableController.RowWrapper rw : result.rows) {
                for (FEC_DecisionTableController.ColumnWrapper cw : result.conditionCols) {
                    FEC_DecisionTableController.CellWrapper cell = new FEC_DecisionTableController.CellWrapper();
                    cell.colId = cw.id;
                    cell.value = cellValueMap.containsKey(rw.rowId + '-' + cw.id)
                        ? cellValueMap.get(rw.rowId + '-' + cw.id) : FEC_UIConstants.PLACEHOLDER_EMPTY;
                    rw.conditionCells.add(cell);
                    rw.allSearchableCells.add(cell);
                }
                for (FEC_DecisionTableController.ColumnWrapper cw : result.actionCols) {
                    FEC_DecisionTableController.CellWrapper cell = new FEC_DecisionTableController.CellWrapper();
                    cell.colId = cw.id;
                    cell.value = cellValueMap.containsKey(rw.rowId + '-' + cw.id)
                        ? cellValueMap.get(rw.rowId + '-' + cw.id) : FEC_UIConstants.PLACEHOLDER_EMPTY;
                    rw.actionCells.add(cell);
                    rw.allSearchableCells.add(cell);
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    // ── Review Tab Methods ────────────────────────────────────────────────

    /**
     * @description Compare MDM vs Live Master Data Settings for a specific NOC combination.
     * Finds the Live NOC record matching the filter criteria, queries its MDM settings,
     * then matches against Live settings by FEC_Code__c. Categorizes each record as
     * New (MDM only), Updated (both but fields differ), or Synced (identical).
     * Reuses FEC_MasterDataReviewController.ComparisonResult wrapper.
     * @param productId The Product Type record ID
     * @param bizId The Business Process record ID
     * @param catId The Category record ID
     * @param subCatId The Sub Category record ID
     * @param subCodeId The Sub Code record ID
     * @return FEC_MasterDataReviewController.ComparisonResult Comparison results with newList, updateList, syncedList
     */
    @AuraEnabled(cacheable=true)
    public static FEC_MasterDataReviewController.ComparisonResult getLiveReviewComparison(
        String productId, String bizId, String catId, String subCatId, String subCodeId
    ) {
        FEC_MasterDataReviewController.ComparisonResult finalResult =
            new FEC_MasterDataReviewController.ComparisonResult();

        if (String.isBlank(productId) || String.isBlank(bizId) ||
            String.isBlank(catId) || String.isBlank(subCatId) || String.isBlank(subCodeId)) {
            return finalResult;
        }

        try {
            // Find the MDM NOC record matching the filter criteria
            List<FEC_MDM_Nature_Of_Case__c> mdmNocs = [
                SELECT Id, FEC_Code__c
                FROM FEC_MDM_Nature_Of_Case__c
                WHERE FEC_Product_Type__c = :productId
                  AND FEC_Business_Process__c = :bizId
                  AND FEC_Category__c = :catId
                  AND FEC_Sub_Category__c = :subCatId
                  AND FEC_Sub_Code__c = :subCodeId
                
            ];
            List<SObject> safeNocs = Security.stripInaccessible(AccessType.READABLE, mdmNocs).getRecords();
            if (safeNocs.isEmpty()) return finalResult;

            Id mdmNocId = ((FEC_MDM_Nature_Of_Case__c) safeNocs[0]).Id;

            // Query MDM Master Data Settings for this NOC
            List<FEC_MDM_Master_Data_Setting__c> mdmSettings = [
                SELECT Name, FEC_Code__c, FEC_MDM_Channel__c, FEC_MDM_Channel__r.Name,
                       FEC_Stage_Name__c, FEC_Section__c, FEC_Field_Mandatory__c,
                       FEC_Additional_Field__r.Name, Process_Change_Status__c
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__c = :mdmNocId
                
            ];
            List<SObject> safeSettings = Security.stripInaccessible(AccessType.READABLE, mdmSettings).getRecords();
            if (safeSettings.isEmpty()) return finalResult;

            // Collect MDM codes for matching against Live records
            Set<String> mdmCodes = new Set<String>();
            for (SObject s : safeSettings) {
                FEC_MDM_Master_Data_Setting__c m = (FEC_MDM_Master_Data_Setting__c) s;
                if (String.isNotBlank(m.FEC_Code__c)) {
                    mdmCodes.add(m.FEC_Code__c);
                }
            }

            // Query Live Master Data Settings matching by FEC_Code__c
            Map<String, FEC_Master_Data_Setting__c> liveMap = new Map<String, FEC_Master_Data_Setting__c>();
            if (!mdmCodes.isEmpty()) {
                List<FEC_Master_Data_Setting__c> liveQuery = [
                    SELECT Name, FEC_Code__c, FEC_Channel__c, FEC_Channel__r.Name,
                           FEC_Stage_Name__c, FEC_Section__c, FEC_Field_Mandatory__c
                    FROM FEC_Master_Data_Setting__c
                    WHERE FEC_Code__c IN :mdmCodes
                    
                ];
                List<SObject> safeLive = Security.stripInaccessible(AccessType.READABLE, liveQuery).getRecords();
                for (SObject s : safeLive) {
                    FEC_Master_Data_Setting__c live = (FEC_Master_Data_Setting__c) s;
                    liveMap.put(live.FEC_Code__c, live);
                }
            }

            // Categorize each MDM setting as New, Updated, or Synced
            for (SObject s : safeSettings) {
                FEC_MDM_Master_Data_Setting__c mdm = (FEC_MDM_Master_Data_Setting__c) s;
                FEC_MasterDataReviewController.ComparisonWrapper wrapped =
                    new FEC_MasterDataReviewController.ComparisonWrapper(mdm, liveMap.get(mdm.FEC_Code__c));
                if (wrapped.isNew) {
                    finalResult.newList.add(wrapped);
                } else if (wrapped.hasChanged) {
                    finalResult.updateList.add(wrapped);
                } else {
                    finalResult.syncedList.add(wrapped);
                }
            }
            return finalResult;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}