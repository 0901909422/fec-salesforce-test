/**
 * @description Service layer for Live NOC tree + Master Data Setting queries.
 *              Extracted from FEC_LiveDataViewController in Phase 2.4 refactor.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.4
 */
public with sharing class FEC_LiveNOCQueryService {

    public static List<FEC_NatureOfCaseTreeItem> getLiveNocTreeData() {
        try {
            List<FEC_Nature_Of_Case__c> listNOC = [
                SELECT
                    Id, Name, FEC_Customer_Type__c, FEC_User_Group__c,
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

    public static List<Map<String, String>> getLiveCaseStagesByBP(String businessProcessId) {
        if (String.isBlank(businessProcessId)) return new List<Map<String, String>>();
        try {
            List<FEC_Case_Stage__c> stages = [
                SELECT Id, Name, FEC_Code__c
                FROM   FEC_Case_Stage__c
                WHERE  FEC_Business_Process__c = :businessProcessId
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

    public static List<FEC_Master_Data_Setting__c> getLiveMasterDataSettings(String nocId, String stageId, Boolean isIntegration) {
        if (String.isBlank(nocId) || String.isBlank(stageId)) {
            return new List<FEC_Master_Data_Setting__c>();
        }
        try {
            Set<Id> nocIds = collectRelatedNocIds(nocId);
            List<FEC_Master_Data_Setting__c> settings = (isIntegration != null && isIntegration)
                ? queryIntegrationSettings(nocIds, stageId)
                : queryPropertySettings(nocIds, stageId);
            return (List<FEC_Master_Data_Setting__c>)
                Security.stripInaccessible(AccessType.READABLE, settings).getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static Set<Id> collectRelatedNocIds(String nocId) {
        Set<Id> nocIds = new Set<Id>();
        nocIds.add(nocId);
        List<FEC_Nature_Of_Case__c> relatedNocs = [
            SELECT Id FROM FEC_Nature_Of_Case__c WHERE FEC_Business_Process__c = :nocId
        ];
        for (FEC_Nature_Of_Case__c n : relatedNocs) nocIds.add(n.Id);
        return nocIds;
    }

    private static List<FEC_Master_Data_Setting__c> queryIntegrationSettings(Set<Id> nocIds, String stageId) {
        return [
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
            FROM   FEC_Master_Data_Setting__c
            WHERE  FEC_Nature_Of_Case__c IN :nocIds
            AND    FEC_Stage_Name__c = :stageId
            AND    FEC_Data_Integration_Mapping__c != NULL
            ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC
        ];
    }

    private static List<FEC_Master_Data_Setting__c> queryPropertySettings(Set<Id> nocIds, String stageId) {
        return [
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
            FROM   FEC_Master_Data_Setting__c
            WHERE  FEC_Nature_Of_Case__c IN :nocIds
            AND    FEC_Stage_Name__c = :stageId
            AND    FEC_Data_Integration_Mapping__c = NULL
            ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC
        ];
    }

    public static List<Map<String, String>> getLiveStageChangeRules(String businessProcessId) {
        if (String.isBlank(businessProcessId)) return new List<Map<String, String>>();
        try {
            Set<Id> stageIds = collectStageIdsForBP(businessProcessId);
            if (stageIds.isEmpty()) return new List<Map<String, String>>();
            return mapStageChangesToRows(queryStageChanges(stageIds));
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static Set<Id> collectStageIdsForBP(String businessProcessId) {
        List<FEC_Case_Stage__c> stages = [
            SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Business_Process__c = :businessProcessId
        ];
        Set<Id> stageIds = new Set<Id>();
        for (FEC_Case_Stage__c s : stages) stageIds.add(s.Id);
        return stageIds;
    }

    private static List<FEC_Stage_Change__c> queryStageChanges(Set<Id> stageIds) {
        return [
            SELECT Id,
                   FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name,
                   FEC_Action_Button__c, FEC_Action_Button__r.Name,
                   FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                   FEC_Next_Queue__c, FEC_Team_User_Group__c
            FROM   FEC_Stage_Change__c
            WHERE  FEC_Previous_Stage__c IN :stageIds
            ORDER BY FEC_Previous_Stage__r.Name ASC, FEC_Action_Button__r.Name ASC
        ];
    }

    private static List<Map<String, String>> mapStageChangesToRows(List<FEC_Stage_Change__c> changes) {
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
    }
}