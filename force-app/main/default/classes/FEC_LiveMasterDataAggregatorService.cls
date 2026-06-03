/**
 * @description Service layer for Live + MDM master data aggregation queries.
 *              Extracted from FEC_LiveDataViewController in Phase 2.4 refactor.
 *              Handles getAllLiveMasterData, getAllMdmMasterData,
 *              getLiveServiceTypeTree, getLiveDynamicDecisionTable.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.4
 */
public with sharing class FEC_LiveMasterDataAggregatorService {

    public static Map<String, List<Object>> getAllLiveMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        try {
            populateBasicLiveMasterData(masterDataMap);
            populateLiveNatureOfCase(masterDataMap);
            populateLiveAdditionalFields(masterDataMap);
            populateLiveStageData(masterDataMap);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }

    private static void populateBasicLiveMasterData(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_PRODUCT_TYPE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                 FROM FEC_Product_Type__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_BUSINESS_PROCESS,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                 FROM FEC_Business_Process__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_CATEGORY,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                 FROM FEC_Category__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CATEGORY,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                 FROM FEC_Sub_Category__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CODE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c
                 FROM FEC_Sub_Code__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_MASTER_SETTING,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Stage_Name__c, FEC_Nature_Of_Case__c, FEC_Channel__c
                 FROM FEC_Master_Data_Setting__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_CHANNEL,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c FROM FEC_Channel__c ORDER BY Name]
            ).getRecords());
    }

    private static void populateLiveNatureOfCase(Map<String, List<Object>> masterDataMap) {
        List<FEC_Nature_Of_Case__c> nocList = [
            SELECT Id, Name, FEC_Code__c, FEC_Product_Type__r.Name, FEC_Business_Process__r.Name,
                   FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name
            FROM   FEC_Nature_Of_Case__c
        ];
        List<SObject> safeNocList = Security.stripInaccessible(AccessType.READABLE, nocList).getRecords();
        List<FEC_CleanUpMasterDataController.NatureOfCaseWrapper> nocWrapperList = new List<FEC_CleanUpMasterDataController.NatureOfCaseWrapper>();
        for (FEC_Nature_Of_Case__c noc : (List<FEC_Nature_Of_Case__c>) safeNocList) {
            nocWrapperList.add(new FEC_CleanUpMasterDataController.NatureOfCaseWrapper(noc));
        }
        masterDataMap.put(FEC_ObjectConstants.KEY_NATURE_OF_CASE, nocWrapperList);
    }

    private static void populateLiveAdditionalFields(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c
                 FROM FEC_Additional_Field__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD_LIST,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c
                 FROM FEC_Additional_Field_List_Value__c ORDER BY Name]
            ).getRecords());
    }

    private static void populateLiveStageData(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_CASE_STAGE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c
                 FROM FEC_Case_Stage__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put('ActionButton',
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c
                 FROM FEC_Action_Button__c ORDER BY Name]
            ).getRecords());

        List<FEC_Stage_Change__c> scList = [
            SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name,
                   FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c
            FROM   FEC_Stage_Change__c
        ];
        List<SObject> safeScList = Security.stripInaccessible(AccessType.READABLE, scList).getRecords();
        List<FEC_CleanUpMasterDataController.StageChangeWrapper> scWrapperList = new List<FEC_CleanUpMasterDataController.StageChangeWrapper>();
        for (FEC_Stage_Change__c sc : (List<FEC_Stage_Change__c>) safeScList) {
            scWrapperList.add(new FEC_CleanUpMasterDataController.StageChangeWrapper(sc));
        }
        masterDataMap.put('StageChange', scWrapperList);
    }

    // ════════════════════════════════════════════════════════
    // MDM AGGREGATION
    // ════════════════════════════════════════════════════════

    public static Map<String, List<Object>> getAllMdmMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        try {
            populateBasicMDMMasterData(masterDataMap);
            populateMDMNatureOfCase(masterDataMap);
            populateMDMAdditionalFields(masterDataMap);
            populateMDMStageData(masterDataMap);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }

    private static void populateBasicMDMMasterData(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_PRODUCT_TYPE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                 FROM FEC_MDM_Product_Type__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_BUSINESS_PROCESS,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c
                 FROM FEC_MDM_Business_Process__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_CATEGORY,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                 FROM FEC_MDM_Category__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CATEGORY,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                 FROM FEC_MDM_Sub_Category__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_SUB_CODE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, Process_Change_Status__c, FEC_Active__c
                 FROM FEC_MDM_Sub_Code__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_MASTER_SETTING,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Additional_Field__c, FEC_Nature_Of_Case__c,
                        FEC_Stage_Name__c, FEC_Channel__c, FEC_Applicable_Role__c,
                        FEC_Data_Integration_Mapping__c, Process_Change_Status__c
                 FROM FEC_MDM_Master_Data_Setting__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_CHANNEL,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, Process_Change_Status__c
                 FROM FEC_MDM_Channel__c ORDER BY Name]
            ).getRecords());
    }

    private static void populateMDMNatureOfCase(Map<String, List<Object>> masterDataMap) {
        List<FEC_MDM_Nature_Of_Case__c> nocList = [
            SELECT Id, Name, FEC_Code__c, FEC_Customer_Type__c, FEC_Product_Type__r.Name,
                   FEC_Business_Process__r.Name, FEC_Category__r.Name, FEC_Sub_Category__r.Name,
                   FEC_Sub_Code__r.Name, Process_Change_Status__c
            FROM   FEC_MDM_Nature_Of_Case__c
        ];
        List<SObject> safeNocList = Security.stripInaccessible(AccessType.READABLE, nocList).getRecords();
        List<FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper> nocWrapperList = new List<FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper>();
        for (FEC_MDM_Nature_Of_Case__c noc : (List<FEC_MDM_Nature_Of_Case__c>) safeNocList) {
            nocWrapperList.add(new FEC_CleanUpMasterDataController.NatureOfCaseMDMWrapper(noc));
        }
        masterDataMap.put(FEC_ObjectConstants.KEY_NATURE_OF_CASE, nocWrapperList);
    }

    private static void populateMDMAdditionalFields(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c, Process_Change_Status__c
                 FROM FEC_MDM_Additional_Field__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put(FEC_ObjectConstants.KEY_ADDITIONAL_FIELD_LIST,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c, Process_Change_Status__c
                 FROM FEC_MDM_Additional_Field_List_Value__c ORDER BY Name]
            ).getRecords());
    }

    private static void populateMDMStageData(Map<String, List<Object>> masterDataMap) {
        masterDataMap.put(FEC_ObjectConstants.KEY_CASE_STAGE,
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c, Process_Change_Status__c
                 FROM FEC_MDM_Case_Stage__c ORDER BY Name]
            ).getRecords());

        masterDataMap.put('ActionButton',
            Security.stripInaccessible(AccessType.READABLE,
                [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c, Process_Change_Status__c
                 FROM FEC_MDM_Action_Button__c ORDER BY Name]
            ).getRecords());

        List<FEC_MDM_Stage_Change__c> scListMdm = [
            SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name,
                   FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c, Process_Change_Status__c
            FROM   FEC_MDM_Stage_Change__c
        ];
        List<SObject> safeScList = Security.stripInaccessible(AccessType.READABLE, scListMdm).getRecords();
        List<FEC_CleanUpMasterDataController.StageChangeMDMWrapper> scWrapperListMdm = new List<FEC_CleanUpMasterDataController.StageChangeMDMWrapper>();
        for (FEC_MDM_Stage_Change__c sc : (List<FEC_MDM_Stage_Change__c>) safeScList) {
            scWrapperListMdm.add(new FEC_CleanUpMasterDataController.StageChangeMDMWrapper(sc));
        }
        masterDataMap.put('StageChange', scWrapperListMdm);
    }

    // ════════════════════════════════════════════════════════
    // SERVICE TYPE TREE
    // ════════════════════════════════════════════════════════

    public static List<Map<String, Object>> getLiveServiceTypeTree() {
        try {
            Map<Id, FEC_Business_Process__c> bpMap = new Map<Id, FEC_Business_Process__c>(
                [SELECT Id, Name FROM FEC_Business_Process__c ORDER BY Name]
            );
            List<SObject> safeSettings = querySettingsForServiceTypeTree(bpMap.keySet());
            Map<Id, List<Map<String, Object>>> bpToProperties = buildBpToPropertiesMap(safeSettings, bpMap);
            return buildTreeData(bpMap, bpToProperties);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static List<SObject> querySettingsForServiceTypeTree(Set<Id> bpIds) {
        List<FEC_Master_Data_Setting__c> allSettings = [
            SELECT Id, Name, FEC_Additional_Field__r.Name, Property_Reference__c,
                   FEC_Nature_Of_Case__r.FEC_Business_Process__c
            FROM   FEC_Master_Data_Setting__c
            WHERE  FEC_Nature_Of_Case__r.FEC_Business_Process__c IN :bpIds
            AND    FEC_Additional_Field__c != NULL
            ORDER BY Name
        ];
        return Security.stripInaccessible(AccessType.READABLE, allSettings).getRecords();
    }

    private static Map<Id, List<Map<String, Object>>> buildBpToPropertiesMap(List<SObject> safeSettings, Map<Id, FEC_Business_Process__c> bpMap) {
        Map<Id, List<Map<String, Object>>> bpToProperties = new Map<Id, List<Map<String, Object>>>();
        for (FEC_Master_Data_Setting__c setting : (List<FEC_Master_Data_Setting__c>) safeSettings) {
            Id bpId = setting.FEC_Nature_Of_Case__r.FEC_Business_Process__c;
            if (!bpToProperties.containsKey(bpId)) {
                bpToProperties.put(bpId, new List<Map<String, Object>>());
            }
            String displayLabel = setting.FEC_Additional_Field__r != null ? setting.FEC_Additional_Field__r.Name : setting.Name;
            bpToProperties.get(bpId).add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => displayLabel,
                FEC_UIConstants.MAP_NAME => setting.Id,
                FEC_UIConstants.MAP_PROPERTY_REF => setting.Property_Reference__c,
                FEC_UIConstants.MAP_PARENT_NAME => bpMap.get(bpId).Name
            });
        }
        return bpToProperties;
    }

    private static List<Map<String, Object>> buildTreeData(
        Map<Id, FEC_Business_Process__c> bpMap,
        Map<Id, List<Map<String, Object>>> bpToProperties
    ) {
        List<Map<String, Object>> treeData = new List<Map<String, Object>>();
        for (FEC_Business_Process__c bp : bpMap.values()) {
            List<Map<String, Object>> children = bpToProperties.containsKey(bp.Id)
                ? bpToProperties.get(bp.Id) : new List<Map<String, Object>>();
            treeData.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => bp.Name,
                FEC_UIConstants.MAP_NAME => bp.Id,
                FEC_UIConstants.MAP_EXPANDED => false,
                FEC_UIConstants.MAP_ITEMS => children
            });
        }
        return treeData;
    }

    // ════════════════════════════════════════════════════════
    // DYNAMIC DECISION TABLE
    // ════════════════════════════════════════════════════════

    public static FEC_DecisionTableController.TableWrapper getLiveDynamicDecisionTable(String businessProcessId) {
        FEC_DecisionTableController.TableWrapper result = initEmptyTableWrapper();
        if (String.isBlank(businessProcessId)) return result;

        try {
            List<FEC_Decision_Table__c> tables = [
                SELECT Id FROM FEC_Decision_Table__c
                WHERE  FEC_Business_Process__c = :businessProcessId AND FEC_Active__c = true
                LIMIT 1
            ];
            if (tables.isEmpty()) return result;
            result.tableId = tables[0].Id;

            populateColumns(result);
            Map<Id, FEC_DecisionTableController.RowWrapper> rowMap = populateRows(result);
            populateCells(result, rowMap);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static FEC_DecisionTableController.TableWrapper initEmptyTableWrapper() {
        FEC_DecisionTableController.TableWrapper result = new FEC_DecisionTableController.TableWrapper();
        result.conditionCols = new List<FEC_DecisionTableController.ColumnWrapper>();
        result.actionCols = new List<FEC_DecisionTableController.ColumnWrapper>();
        result.rows = new List<FEC_DecisionTableController.RowWrapper>();
        return result;
    }

    private static void populateColumns(FEC_DecisionTableController.TableWrapper result) {
        List<FEC_Decision_Column__c> listCols = [
            SELECT Id, Name, FEC_Column_Type__c
            FROM   FEC_Decision_Column__c
            WHERE  FEC_Decision_Table__c = :result.tableId
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
    }

    private static Map<Id, FEC_DecisionTableController.RowWrapper> populateRows(FEC_DecisionTableController.TableWrapper result) {
        Map<Id, FEC_DecisionTableController.RowWrapper> rowMap = new Map<Id, FEC_DecisionTableController.RowWrapper>();
        List<FEC_Decision_Row__c> rowRecords = [
            SELECT Id FROM FEC_Decision_Row__c
            WHERE  FEC_Decision_Table__c = :result.tableId
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
        return rowMap;
    }

    private static void populateCells(
        FEC_DecisionTableController.TableWrapper result,
        Map<Id, FEC_DecisionTableController.RowWrapper> rowMap
    ) {
        Map<String, String> cellValueMap = new Map<String, String>();
        for (FEC_Decision_Cell__c cell : [
            SELECT FEC_Decision_Row__c, FEC_Decision_Column__c, FEC_Value__c
            FROM   FEC_Decision_Cell__c
            WHERE  FEC_Decision_Row__c IN :rowMap.keySet()
        ]) {
            cellValueMap.put(cell.FEC_Decision_Row__c + '-' + cell.FEC_Decision_Column__c, cell.FEC_Value__c);
        }

        for (FEC_DecisionTableController.RowWrapper rw : result.rows) {
            populateRowCells(rw, result.conditionCols, true, cellValueMap);
            populateRowCells(rw, result.actionCols, false, cellValueMap);
        }
    }

    private static void populateRowCells(
        FEC_DecisionTableController.RowWrapper rw,
        List<FEC_DecisionTableController.ColumnWrapper> cols,
        Boolean isCondition,
        Map<String, String> cellValueMap
    ) {
        for (FEC_DecisionTableController.ColumnWrapper cw : cols) {
            FEC_DecisionTableController.CellWrapper cell = new FEC_DecisionTableController.CellWrapper();
            cell.colId = cw.id;
            String key = rw.rowId + '-' + cw.id;
            cell.value = cellValueMap.containsKey(key) ? cellValueMap.get(key) : FEC_UIConstants.PLACEHOLDER_EMPTY;
            if (isCondition) rw.conditionCells.add(cell);
            else rw.actionCells.add(cell);
            rw.allSearchableCells.add(cell);
        }
    }
}