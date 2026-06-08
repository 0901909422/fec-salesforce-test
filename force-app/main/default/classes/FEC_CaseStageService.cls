/**
 * @description Service layer for Case Stage + Stage Screen CRUD.
 *              Extracted from FEC_MasterDataSettingController in Phase 2.1 refactor.
 *              Note: keeps original signatures for backward compatibility (LWC unchanged).
 *              13-param createCaseStage / 12-param updateCaseStage preserved as-is.
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.1
 */
public with sharing class FEC_CaseStageService {

    // ════════════════════════════════════════════════════════
    // CASE STAGE CRUD
    // ════════════════════════════════════════════════════════

    public static void updateCaseStageName(Id stageId, String newName) {
        try {
            FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
                Id = stageId,
                Name = newName,
                FEC_Name_VN__c = newName,
                FEC_Alias__c = newName
            );
            update stage;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static void updateCaseStage(
        Id stageId, String name, String nameVN, String alias,
        Boolean status, Boolean active, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Integer posOrder,
        String statusName, Boolean endStage
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException(System.Label.FEC_Error_Stage_Name_Empty);
        }
        try {
            FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
                Id = stageId,
                Name = name,
                FEC_Name_VN__c = nameVN,
                FEC_Alias__c = alias,
                FEC_Active__c = active,
                FEC_Default_Stage__c = defaultStage != null ? defaultStage : false,
                FEC_End_Stage__c = endStage != null ? endStage : false,
                FEC_Nature_of_Cases__c = String.isNotBlank(natureOfCasesId) ? natureOfCasesId : null,
                FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
                FEC_Order__c = posOrder,
                FEC_Status_Name__c = String.isNotBlank(statusName) ? statusName : null
            );
            update stage;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static void deleteCaseStage(Id stageId) {
        try {
            delete new FEC_MDM_Case_Stage__c(Id = stageId);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static Id createCaseStage(
        String name, String code, String businessProcessId, String nameVN,
        Boolean status, String alias, Integer posOrder, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Boolean active,
        String statusName, Boolean endStage
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException(System.Label.FEC_Error_Stage_Name_Empty);
        }
        try {
            FEC_MDM_Case_Stage__c stage = buildNewStage(name, code, businessProcessId, nameVN,
                alias, posOrder, defaultStage, natureOfCasesId, userGroup, active, statusName, endStage);
            insert stage;
            return stage.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            throw buildDmlException(dml, name);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static FEC_MDM_Case_Stage__c buildNewStage(
        String name, String code, String businessProcessId, String nameVN,
        String alias, Integer posOrder, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Boolean active,
        String statusName, Boolean endStage
    ) {
        return new FEC_MDM_Case_Stage__c(
            Name = name,
            FEC_Code__c = code,
            FEC_Business_Process__c = businessProcessId,
            FEC_Name_VN__c = nameVN,
            FEC_Active__c = active != null ? active : false,
            FEC_Alias__c = alias,
            FEC_Order__c = posOrder,
            FEC_Default_Stage__c = defaultStage != null ? defaultStage : false,
            FEC_End_Stage__c = endStage != null ? endStage : false,
            FEC_Nature_of_Cases__c = String.isNotBlank(natureOfCasesId) ? natureOfCasesId : null,
            FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
            FEC_Status_Name__c = String.isNotBlank(statusName) ? statusName : null
        );
    }

    private static AuraHandledException buildDmlException(DmlException dml, String name) {
        String msg = dml.getDmlMessage(0);
        if (dml.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
            msg = 'Stage "' + name + '" already exists (duplicate code). Please use a different name.';
        }
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        return ex;
    }

    public static List<Map<String, String>> getCaseStageOptionsByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Case_Stage__c> stages = [
            SELECT Id, Name, FEC_Default_Stage__c, FEC_End_Stage__c, FEC_Order__c
            FROM   FEC_MDM_Case_Stage__c
            WHERE  FEC_Business_Process__c = :businessProcessId
            ORDER BY FEC_Order__c ASC NULLS FIRST, Name ASC
        ];
        for (FEC_MDM_Case_Stage__c stage : stages) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => stage.Name,
                FEC_UIConstants.MAP_VALUE => stage.Id,
                'defaultStage' => String.valueOf(stage.FEC_Default_Stage__c),
                'endStage' => String.valueOf(stage.FEC_End_Stage__c),
                'posOrder' => stage.FEC_Order__c != null ? String.valueOf(stage.FEC_Order__c.intValue()) : '0'
            });
        }
        return options;
    }

    public static Map<String, String> getCaseStageDetail(Id stageId) {
        List<FEC_MDM_Case_Stage__c> stages = [
            SELECT Id, Name, FEC_Name_VN__c, FEC_Alias__c, FEC_Active__c,
                   FEC_Default_Stage__c, FEC_End_Stage__c, FEC_Nature_of_Cases__c, FEC_User_Group__c,
                   FEC_Order__c, FEC_Status_Name__c
            FROM   FEC_MDM_Case_Stage__c
            WHERE  Id = :stageId
            LIMIT 1
        ];
        if (stages.isEmpty()) {
            throw new AuraHandledException(System.Label.FEC_Error_Stage_Not_Found);
        }
        return buildStageDetail(stages[0]);
    }

    private static Map<String, String> buildStageDetail(FEC_MDM_Case_Stage__c stage) {
        Map<String, Object> populated = stage.getPopulatedFieldsAsMap();
        Map<String, String> result = new Map<String, String>();
        result.put('id', stage.Id);
        result.put('name', stage.Name);
        result.put('nameVN', stage.FEC_Name_VN__c != null ? stage.FEC_Name_VN__c : '');
        result.put('alias', stage.FEC_Alias__c != null ? stage.FEC_Alias__c : '');
        result.put('status', String.valueOf(stage.FEC_Active__c));
        result.put('active', String.valueOf(stage.FEC_Active__c));
        result.put('defaultStage', String.valueOf(stage.FEC_Default_Stage__c));
        result.put('endStage', populated.containsKey(FEC_FieldConstants.FIELD_END_STAGE) ? String.valueOf(stage.FEC_End_Stage__c) : 'false');
        result.put('natureOfCasesId', stage.FEC_Nature_of_Cases__c != null ? String.valueOf(stage.FEC_Nature_of_Cases__c) : '');
        result.put('userGroup', stage.FEC_User_Group__c != null ? stage.FEC_User_Group__c : '');
        result.put('posOrder', stage.FEC_Order__c != null ? String.valueOf(stage.FEC_Order__c.intValue()) : '0');
        result.put('statusName', stage.FEC_Status_Name__c != null ? stage.FEC_Status_Name__c : '');
        return result;
    }

    // ════════════════════════════════════════════════════════
    // STAGE SCREEN CRUD
    // ════════════════════════════════════════════════════════

    public static List<Map<String, String>> getStageScreensByStage(Id stageId) {
        if (stageId == null) {
            throw new AuraHandledException(System.Label.FEC_Error_Stage_Id_Null);
        }
        try {
            List<FEC_Stage_Screen__c> screens = [
                SELECT Id, FEC_Action_Button__r.Name, FEC_User_Group__c,
                       FEC_Active__c, FEC_Code__c
                FROM   FEC_Stage_Screen__c
                WHERE  FEC_Case_Stage__c = :stageId
                ORDER BY CreatedDate ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, screens).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Stage_Screen__c screen : (List<FEC_Stage_Screen__c>) safe) {
                result.add(buildStageScreenMap(screen));
            }
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static Map<String, String> buildStageScreenMap(FEC_Stage_Screen__c screen) {
        return new Map<String, String>{
            'id' => screen.Id,
            'actionButtonName' => screen.FEC_Action_Button__r != null ? screen.FEC_Action_Button__r.Name : '',
            'userGroup' => screen.FEC_User_Group__c != null ? screen.FEC_User_Group__c : '',
            'active' => String.valueOf(screen.FEC_Active__c),
            'code' => screen.FEC_Code__c != null ? screen.FEC_Code__c : ''
        };
    }

    public static Id createStageScreen(Id stageId, Id actionButtonId, String userGroup, Boolean active) {
        if (stageId == null || actionButtonId == null) {
            throw new AuraHandledException(System.Label.FEC_Error_Stage_ActionButton_Null);
        }
        try {
            checkDuplicateStageScreen(stageId, actionButtonId);
            FEC_Stage_Screen__c screen = new FEC_Stage_Screen__c(
                FEC_Case_Stage__c = stageId,
                FEC_Action_Button__c = actionButtonId,
                FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
                FEC_Active__c = active != null ? active : true
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<FEC_Stage_Screen__c>{ screen }
            );
            FEC_Stage_Screen__c sanitized = (FEC_Stage_Screen__c) decision.getRecords()[0];
            insert sanitized;
            return sanitized.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            String msg = dml.getDmlMessage(0);
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static void checkDuplicateStageScreen(Id stageId, Id actionButtonId) {
        List<FEC_Stage_Screen__c> existing = [
            SELECT Id FROM FEC_Stage_Screen__c
            WHERE  FEC_Case_Stage__c = :stageId
            AND    FEC_Action_Button__c = :actionButtonId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            String msg = System.Label.FEC_Error_ActionButton_Duplicate;
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    public static void deleteStageScreen(Id stageScreenId) {
        if (stageScreenId == null) {
            throw new AuraHandledException(System.Label.FEC_Error_StageScreen_Id_Null);
        }
        try {
            delete new FEC_Stage_Screen__c(Id = stageScreenId);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static void toggleStageScreenActive(Id stageScreenId, Boolean active) {
        if (stageScreenId == null) {
            throw new AuraHandledException(System.Label.FEC_Error_StageScreen_Id_Null);
        }
        try {
            FEC_Stage_Screen__c screen = new FEC_Stage_Screen__c(Id = stageScreenId, FEC_Active__c = active);
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<FEC_Stage_Screen__c>{ screen }
            );
            update decision.getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}