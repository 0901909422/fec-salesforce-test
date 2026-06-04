/**
 * @description Service layer for MDM dropdown options + lookup picklists.
 *              Extracted from FEC_MasterDataSettingController in Phase 2.1 refactor.
 *              All methods are read-only with stripInaccessible.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.1
 */
public with sharing class FEC_MDMOptionService {

    @TestVisible
    private static final Set<String> ALLOWED_LOOKUP_OBJECTS = new Set<String>{
        FEC_ObjectConstants.OBJ_CASE_STAGE,
        FEC_ObjectConstants.OBJ_MDM_ADDITIONAL_FIELD,
        FEC_ObjectConstants.OBJ_USER_ROLE
    };

    public static List<Map<String, String>> getChannels() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Channel__c> channels = [SELECT Id, Name FROM FEC_MDM_Channel__c ORDER BY CreatedDate DESC];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        for (FEC_MDM_Channel__c c : (List<FEC_MDM_Channel__c>) safe) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => c.Name, FEC_UIConstants.MAP_VALUE => c.Id});
        }
        return options;
    }

    public static List<Map<String, String>> getUserRoles() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<UserRole> roles = [SELECT Name FROM UserRole ORDER BY Name];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, roles).getRecords();
        for (UserRole r : (List<UserRole>) safe) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => r.Name, FEC_UIConstants.MAP_VALUE => r.Name});
        }
        return options;
    }

    public static List<Map<String, Object>> getStageOptions() {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE, FEC_UIConstants.MAP_VALUE => ''});
        List<FEC_Case_Stage__c> stages = [
            SELECT Id, Name FROM FEC_Case_Stage__c WITH SECURITY_ENFORCED ORDER BY Name ASC
        ];
        for (FEC_Case_Stage__c stage : stages) {
            options.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => stage.Name,
                FEC_UIConstants.MAP_VALUE => stage.Id
            });
        }
        return options;
    }

    public static List<Map<String, Object>> getLookupOptions(String sObjectName) {
        if (!ALLOWED_LOOKUP_OBJECTS.contains(sObjectName)) {
            throw new AuraHandledException(System.Label.FEC_Error_Invalid_Sobject_Allowlist + ' ' + sObjectName);
        }
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE, FEC_UIConstants.MAP_VALUE => ''});
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectName);
        if (targetType == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_SOBJECT_PREFIX + sObjectName);
        }
        String query = 'SELECT Id, Name FROM ' + sObjectName + ' WITH SECURITY_ENFORCED ORDER BY Name ASC';
        for (SObject rec : Database.query(query)) {
            options.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => (String) rec.get('Name'),
                FEC_UIConstants.MAP_VALUE => (String) rec.get('Id')
            });
        }
        return options;
    }

    public static List<Map<String, String>> getUserGroupOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = FEC_MDM_Case_Stage__c.FEC_User_Group__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => entry.getLabel(),
                    FEC_UIConstants.MAP_VALUE => entry.getValue()
                });
            }
        }
        return options;
    }

    public static List<Map<String, String>> getAdditionalFieldOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT Id, Name, Field_API_Name__c
            FROM   FEC_MDM_Additional_Field__c
            WHERE  FEC_Field_Status__c = true
            ORDER BY CreatedDate DESC
        ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        for (FEC_MDM_Additional_Field__c field : (List<FEC_MDM_Additional_Field__c>) safe) {
            Map<String, Object> populated = field.getPopulatedFieldsAsMap();
            String apiName = populated.containsKey('Field_API_Name__c')
                ? (String) populated.get('Field_API_Name__c') : '';
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => field.Name,
                FEC_UIConstants.MAP_VALUE => field.Id,
                FEC_UIConstants.MAP_FIELD_API_NAME => apiName != null ? apiName : ''
            });
        }
        return options;
    }

    public static List<Map<String, String>> getNatureOfCaseOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Nature_of_Case__c> nocs = [SELECT Id, Name FROM FEC_MDM_Nature_of_Case__c ORDER BY Name ASC];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, nocs).getRecords();
        for (FEC_MDM_Nature_of_Case__c noc : (List<FEC_MDM_Nature_of_Case__c>) safe) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => noc.Name,
                FEC_UIConstants.MAP_VALUE => noc.Id
            });
        }
        return options;
    }

    public static String getUserTypeIdByName(String customerTypeName) {
        if (String.isBlank(customerTypeName)) return null;
        try {
            List<FEC_User_Type__c> userTypes = [
                SELECT Id, Name FROM FEC_User_Type__c
                WHERE FEC_Status__c = true AND Name = :customerTypeName LIMIT 1
            ];
            return userTypes.isEmpty() ? null : userTypes[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    public static List<Map<String, String>> getActionButtonOptions() {
        try {
            List<FEC_MDM_Action_Button__c> buttons = [
                SELECT Id, Name FROM FEC_MDM_Action_Button__c
                WHERE FEC_Active__c = true ORDER BY Name ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, buttons).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_MDM_Action_Button__c btn : (List<FEC_MDM_Action_Button__c>) safe) {
                result.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => btn.Name,
                    FEC_UIConstants.MAP_VALUE => btn.Id
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}