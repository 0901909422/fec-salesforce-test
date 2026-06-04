/**
 * @description Live mirror of FEC_MasterDataSettingController.
 *              Provides full CRUD operations on FEC_Master_Data_Setting__c (Live)
 *              along with related read methods for FEC_Case_Stage__c, FEC_Stage_Change__c.
 *              Live objects do NOT have Process_Change_Status__c.
 * @date   2026
 */
public with sharing class FEC_LiveMasterDataSettingController {

    /** Allowlist of sObject API names permitted for getLookupOptions queries. */
    @TestVisible
    private static final Set<String> ALLOWED_LOOKUP_OBJECTS = new Set<String>{
        'FEC_Case_Stage__c',
        'FEC_Additional_Field__c',
        'UserRole'
    };

    // ─────────────────────────────────────────────────────────────────────
    //  READ — Master Data Settings (Property Config / Fraud Mapping partition)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @description Get Live Master Data Settings for a NOC + Stage combo.
     *              Partitions by integration flag:
     *              - isIntegration=false → FEC_Data_Integration_Mapping__c IS NULL (Property Config)
     *              - isIntegration=true  → FEC_Data_Integration_Mapping__c IS NOT NULL (Fraud Mapping)
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_Master_Data_Setting__c> getMasterDataSettings(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        if (String.isBlank(selectedNodeId)) return new List<FEC_Master_Data_Setting__c>();

        // Collect NOC Ids: direct match + all NOC records under same BP
        Set<Id> nocIds = new Set<Id>();
        try {
            Id directId = (Id) selectedNodeId;
            nocIds.add(directId);
        } catch (Exception ignored) {}
        try {
            List<FEC_Nature_Of_Case__c> relatedNocs = [
                SELECT Id FROM FEC_Nature_Of_Case__c WHERE FEC_Business_Process__c = :selectedNodeId
            ];
            for (FEC_Nature_Of_Case__c n : relatedNocs) nocIds.add(n.Id);
        } catch (Exception ignored) {}

        if (nocIds.isEmpty()) return new List<FEC_Master_Data_Setting__c>();

        List<String> fields = new List<String>{
            'Id', 'Name', 'FEC_Section__c', 'FEC_Field_Status__c', 'FEC_Field_ReadOnly__c',
            'FEC_Field_Order_Display__c', 'FEC_Field_Object_Name__c', 'FEC_Field_Mandatory__c',
            'FEC_Applicable_Role__c', 'FEC_Data_Integration_Mapping__c',
            'FEC_Field_API_Name__c', 'FEC_Field_Label_Name__c',
            'FEC_Additional_Field__c', 'FEC_Additional_Field__r.Name',
            'FEC_Stage_Name__r.Name', 'FEC_Nature_Of_Case__r.Name',
            'FEC_Channel__c', 'FEC_Channel__r.Name',
            'FEC_Field_Masking__c', 'FEC_Masking_Type__c', 'FEC_Field_Reverted__c',
            'FEC_Sub_Section__c', 'FEC_Sub_Section_Field_Layout__c', 'FEC_Sub_Section_Layout__c',
            'FEC_Sub_Section_Order__c', 'FEC_Editable_User_Group__c',
            'FEC_Field_Editable__c', 'FEC_Editable_Role__c',
            'Property_Reference__c'
        };

        String baseQuery = 'SELECT ' + String.join(fields, ', ')
            + ' FROM FEC_Master_Data_Setting__c WHERE FEC_Nature_Of_Case__c IN :nocIds ';

        if (String.isNotBlank(selectedStageId)) {
            baseQuery += ' AND FEC_Stage_Name__c = :selectedStageId ';
        } else if (isIntegration != null && isIntegration) {
            baseQuery += ' AND FEC_Stage_Name__c = NULL ';
        } else {
            return new List<FEC_Master_Data_Setting__c>();
        }

        if (isIntegration != null) {
            baseQuery += isIntegration
                ? ' AND FEC_Data_Integration_Mapping__c != NULL '
                : ' AND FEC_Data_Integration_Mapping__c = NULL ';
        }

        String finalQuery = baseQuery + ' ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC';

        try {
            List<FEC_Master_Data_Setting__c> settings = Database.query(finalQuery);
            List<FEC_Master_Data_Setting__c> safe =
                (List<FEC_Master_Data_Setting__c>) Security.stripInaccessible(AccessType.READABLE, settings).getRecords();

            // Restore lookup IDs that may be stripped by FLS but still referenced by UI
            Map<Id, FEC_Master_Data_Setting__c> originalMap = new Map<Id, FEC_Master_Data_Setting__c>(settings);
            for (FEC_Master_Data_Setting__c s : safe) {
                FEC_Master_Data_Setting__c orig = originalMap.get(s.Id);
                if (orig == null) continue;
                if (orig.FEC_Channel__c != null) s.FEC_Channel__c = orig.FEC_Channel__c;
                if (orig.FEC_Sub_Section__c != null) s.FEC_Sub_Section__c = orig.FEC_Sub_Section__c;
                if (orig.FEC_Sub_Section_Order__c != null) s.FEC_Sub_Section_Order__c = orig.FEC_Sub_Section_Order__c;
                if (orig.FEC_Sub_Section_Layout__c != null) s.FEC_Sub_Section_Layout__c = orig.FEC_Sub_Section_Layout__c;
                if (orig.FEC_Sub_Section_Field_Layout__c != null) s.FEC_Sub_Section_Field_Layout__c = orig.FEC_Sub_Section_Field_Layout__c;
                if (orig.FEC_Field_Editable__c != null) s.FEC_Field_Editable__c = orig.FEC_Field_Editable__c;
                if (orig.FEC_Editable_Role__c != null) s.FEC_Editable_Role__c = orig.FEC_Editable_Role__c;
                if (isIntegration != null && isIntegration && orig.FEC_Data_Integration_Mapping__c != null) {
                    s.FEC_Data_Integration_Mapping__c = orig.FEC_Data_Integration_Mapping__c;
                }
            }
            return safe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /** Non-cacheable version for imperative refresh after DML. */
    @AuraEnabled
    public static List<FEC_Master_Data_Setting__c> getMasterDataSettingsFresh(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        return getMasterDataSettings(selectedNodeId, selectedStageId, isIntegration);
    }

    // ─────────────────────────────────────────────────────────────────────
    //  READ — Stages, Channels, User Roles, Lookup Options
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStagesByBP(String businessProcessId) {
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannels() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_Channel__c> channels = [SELECT Id, Name FROM FEC_Channel__c ORDER BY CreatedDate DESC];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        for (FEC_Channel__c c : (List<FEC_Channel__c>) safe) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => c.Name,
                FEC_UIConstants.MAP_VALUE => c.Id
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUserRoles() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<UserRole> roles = [SELECT Name FROM UserRole ORDER BY Name];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, roles).getRecords();
        for (UserRole r : (List<UserRole>) safe) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => r.Name,
                FEC_UIConstants.MAP_VALUE => r.Name
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getStageOptions() {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{
            FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE,
            FEC_UIConstants.MAP_VALUE => ''
        });
        List<FEC_Case_Stage__c> stages = [SELECT Id, Name FROM FEC_Case_Stage__c ORDER BY Name ASC];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, stages).getRecords();
        for (FEC_Case_Stage__c stage : (List<FEC_Case_Stage__c>) safe) {
            options.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => stage.Name,
                FEC_UIConstants.MAP_VALUE => stage.Id
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLookupOptions(String sObjectName) {
        if (!ALLOWED_LOOKUP_OBJECTS.contains(sObjectName)) {
            throw new AuraHandledException('Invalid sObject: ' + sObjectName);
        }
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{
            FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE,
            FEC_UIConstants.MAP_VALUE => ''
        });
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectName);
        if (targetType == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_SOBJECT_PREFIX + sObjectName);
        }
        String query = 'SELECT Id, Name FROM ' + sObjectName + ' ORDER BY Name ASC';
        List<SObject> records = Database.query(query);
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, records).getRecords();
        for (SObject rec : safe) {
            options.add(new Map<String, Object>{
                FEC_UIConstants.MAP_LABEL => (String) rec.get('Name'),
                FEC_UIConstants.MAP_VALUE => (String) rec.get('Id')
            });
        }
        return options;
    }

    // ─────────────────────────────────────────────────────────────────────
    //  READ — Stage Change rules
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getStageChangeRules(String businessProcessId) {
        if (String.isBlank(businessProcessId)) return new List<Map<String, String>>();
        try {
            List<FEC_Case_Stage__c> stages = [
                SELECT Id FROM FEC_Case_Stage__c WHERE FEC_Business_Process__c = :businessProcessId
            ];
            if (stages.isEmpty()) return new List<Map<String, String>>();
            Set<Id> stageIds = new Set<Id>();
            for (FEC_Case_Stage__c s : stages) stageIds.add(s.Id);

            List<FEC_Stage_Change__c> changes = [
                SELECT Id,
                       FEC_Previous_Stage__c, FEC_Previous_Stage__r.Name,
                       FEC_Action_Button__c, FEC_Action_Button__r.Name,
                       FEC_Next_Stage__c, FEC_Next_Stage__r.Name,
                       FEC_Next_Queue__c, FEC_Team_User_Group__c
                FROM FEC_Stage_Change__c
                WHERE FEC_Previous_Stage__c IN :stageIds
                ORDER BY FEC_Previous_Stage__r.Name ASC, FEC_Action_Button__r.Name ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, changes).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Stage_Change__c sc : (List<FEC_Stage_Change__c>) safe) {
                result.add(new Map<String, String>{
                    'rowId' => sc.Id,
                    'previousStage' => sc.FEC_Previous_Stage__r?.Name,
                    'actionButton'  => sc.FEC_Action_Button__r?.Name,
                    'nextStage'     => sc.FEC_Next_Stage__r?.Name,
                    'nextQueue'     => sc.FEC_Next_Queue__c,
                    'teamUserGroup' => sc.FEC_Team_User_Group__c
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  WRITE — Master Data Setting CRUD
    // ─────────────────────────────────────────────────────────────────────

    private static String getOptionalId(Map<String, Object> req, String fieldName) {
        String value = (String) req.get(fieldName);
        return String.isNotBlank(value) ? value : null;
    }

    @TestVisible
    private static void validateSchemaFields(String objectName, String fieldApiName) {
        if (String.isBlank(objectName)) return;
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectName)) {
            throw new AuraHandledException(System.Label.FEC_Error_Invalid_Object_Name + ': ' + objectName);
        }
        if (String.isNotBlank(fieldApiName)) {
            Map<String, Schema.SObjectField> fieldMap =
                globalDescribe.get(objectName).getDescribe().fields.getMap();
            if (!fieldMap.containsKey(fieldApiName)) {
                throw new AuraHandledException(System.Label.FEC_Error_Invalid_Field_Name + ': ' + fieldApiName + ' on ' + objectName);
            }
        }
    }

    @AuraEnabled
    public static Id saveMasterDataSetting(Map<String, Object> req) {
        String recordId = (String) req.get(FEC_FieldConstants.FIELD_ID);
        Boolean isCreateMode = String.isBlank(recordId);

        if (isCreateMode) {
            if (!FEC_Master_Data_Setting__c.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission);
            }
        } else {
            if (!FEC_Master_Data_Setting__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }
        }

        FEC_Master_Data_Setting__c rec = isCreateMode
            ? new FEC_Master_Data_Setting__c()
            : new FEC_Master_Data_Setting__c(Id = recordId);

        try {
            if (req.containsKey(FEC_FieldConstants.FIELD_NATURE_OF_CASE)) rec.FEC_Nature_Of_Case__c = getOptionalId(req, FEC_FieldConstants.FIELD_NATURE_OF_CASE);
            if (req.containsKey(FEC_FieldConstants.FIELD_STAGE_NAME))     rec.FEC_Stage_Name__c     = getOptionalId(req, FEC_FieldConstants.FIELD_STAGE_NAME);
            if (req.containsKey(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD)) rec.FEC_Additional_Field__c = (String) req.get(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD);
            if (req.containsKey(FEC_FieldConstants.FIELD_SECTION))        rec.FEC_Section__c        = (String) req.get(FEC_FieldConstants.FIELD_SECTION);
            if (req.containsKey('FEC_Channel__c'))                         rec.FEC_Channel__c        = getOptionalId(req, 'FEC_Channel__c');
            if (req.containsKey(FEC_FieldConstants.FIELD_APPLICABLE_ROLE)) rec.FEC_Applicable_Role__c = getOptionalId(req, FEC_FieldConstants.FIELD_APPLICABLE_ROLE);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY)) {
                Object v = req.get(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY);
                rec.FEC_Field_Order_Display__c = (v != null) ? Integer.valueOf(String.valueOf(v)) : null;
            }
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_STATUS))    rec.FEC_Field_Status__c    = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_STATUS);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_READONLY))  rec.FEC_Field_ReadOnly__c  = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_READONLY);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_MANDATORY)) rec.FEC_Field_Mandatory__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_MANDATORY);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME)) rec.FEC_Field_Object_Name__c = (String) req.get(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_API_NAME))  rec.FEC_Field_API_Name__c  = (String) req.get(FEC_FieldConstants.FIELD_FIELD_API_NAME);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME)) rec.FEC_Field_Label_Name__c = (String) req.get(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME);
            if (req.containsKey(FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING)) rec.FEC_Data_Integration_Mapping__c = getOptionalId(req, FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_MASKING))   rec.FEC_Field_Masking__c   = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_MASKING);
            if (req.containsKey(FEC_FieldConstants.FIELD_MASKING_TYPE))    rec.FEC_Masking_Type__c    = (String) req.get(FEC_FieldConstants.FIELD_MASKING_TYPE);
            if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_REVERTED))  rec.FEC_Field_Reverted__c  = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_REVERTED);
            if (req.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION))     rec.FEC_Sub_Section__c     = (String) req.get(FEC_FieldConstants.FIELD_SUB_SECTION);
            if (req.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT)) {
                Object v = req.get(FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT);
                rec.FEC_Sub_Section_Field_Layout__c = (v != null) ? Integer.valueOf(String.valueOf(v)) : null;
            }
            if (req.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT)) {
                Object v = req.get(FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT);
                rec.FEC_Sub_Section_Layout__c = (v != null) ? Integer.valueOf(String.valueOf(v)) : null;
            }
            if (req.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_ORDER)) {
                Object v = req.get(FEC_FieldConstants.FIELD_SUB_SECTION_ORDER);
                rec.FEC_Sub_Section_Order__c = (v != null) ? Integer.valueOf(String.valueOf(v)) : null;
            }
            if (req.containsKey(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP)) rec.FEC_Editable_User_Group__c = (String) req.get(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP);
            if (req.containsKey('FEC_Field_Editable__c')) rec.FEC_Field_Editable__c = (Boolean) req.get('FEC_Field_Editable__c');
            if (req.containsKey('FEC_Editable_Role__c'))  rec.FEC_Editable_Role__c  = (String) req.get('FEC_Editable_Role__c');
            if (req.containsKey('Property_Reference__c')) rec.Property_Reference__c = (String) req.get('Property_Reference__c');

            validateSchemaFields(rec.FEC_Field_Object_Name__c, rec.FEC_Field_API_Name__c);

            // Preserve lookups before FLS strip
            Id preservedChannelId = rec.FEC_Channel__c;
            Id preservedIntegrationMappingId = rec.FEC_Data_Integration_Mapping__c;
            Id preservedNocId = rec.FEC_Nature_Of_Case__c;
            Id preservedStageId = rec.FEC_Stage_Name__c;
            String preservedSubSection = rec.FEC_Sub_Section__c;
            Decimal preservedSubSectionOrder = rec.FEC_Sub_Section_Order__c;
            Decimal preservedSubSectionLayout = rec.FEC_Sub_Section_Layout__c;
            Decimal preservedSubSectionFieldLayout = rec.FEC_Sub_Section_Field_Layout__c;
            Boolean preservedFieldEditable = rec.FEC_Field_Editable__c;
            String preservedEditableRole = rec.FEC_Editable_Role__c;

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPSERTABLE,
                new List<FEC_Master_Data_Setting__c>{ rec }
            );
            FEC_Master_Data_Setting__c sanitized = (FEC_Master_Data_Setting__c) decision.getRecords()[0];

            Map<String, Set<String>> removedFields = decision.getRemovedFields();
            String objKey = 'FEC_Master_Data_Setting__c';
            if (removedFields.containsKey(objKey)) {
                Set<String> removed = removedFields.get(objKey);
                if (removed.contains('FEC_Channel__c') && preservedChannelId != null) sanitized.FEC_Channel__c = preservedChannelId;
                if (removed.contains('FEC_Data_Integration_Mapping__c') && preservedIntegrationMappingId != null) sanitized.FEC_Data_Integration_Mapping__c = preservedIntegrationMappingId;
                if (removed.contains('FEC_Nature_Of_Case__c') && preservedNocId != null) sanitized.FEC_Nature_Of_Case__c = preservedNocId;
                if (removed.contains('FEC_Stage_Name__c') && preservedStageId != null) sanitized.FEC_Stage_Name__c = preservedStageId;
                if (removed.contains('FEC_Sub_Section__c') && preservedSubSection != null) sanitized.FEC_Sub_Section__c = preservedSubSection;
                if (removed.contains('FEC_Sub_Section_Order__c') && preservedSubSectionOrder != null) sanitized.FEC_Sub_Section_Order__c = preservedSubSectionOrder;
                if (removed.contains('FEC_Sub_Section_Layout__c') && preservedSubSectionLayout != null) sanitized.FEC_Sub_Section_Layout__c = preservedSubSectionLayout;
                if (removed.contains('FEC_Sub_Section_Field_Layout__c') && preservedSubSectionFieldLayout != null) sanitized.FEC_Sub_Section_Field_Layout__c = preservedSubSectionFieldLayout;
                if (removed.contains('FEC_Field_Editable__c') && preservedFieldEditable != null) sanitized.FEC_Field_Editable__c = preservedFieldEditable;
                if (removed.contains('FEC_Editable_Role__c') && preservedEditableRole != null) sanitized.FEC_Editable_Role__c = preservedEditableRole;
            }

            upsert sanitized;
            rec.Id = sanitized.Id;

            // Auto-assign FEC_Code__c = Id on CREATE (external ID for EOD sync matching)
            if (isCreateMode) {
                try {
                    update new FEC_Master_Data_Setting__c(Id = sanitized.Id, FEC_Code__c = sanitized.Id);
                } catch (Exception ignored) {
                    System.debug('Failed to assign FEC_Code__c for ' + sanitized.Id);
                }
            }

            return sanitized.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            throw new AuraHandledException(dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + FEC_UIConstants.ERROR_INVALID_ID);
        }
        try {
            if (!FEC_Master_Data_Setting__c.SObjectType.getDescribe().isDeletable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
            }
            delete new FEC_Master_Data_Setting__c(Id = recordId);
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_SYSTEM + ' ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    //  WRITE — Case Stage updates
    // ─────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void updateCaseStageName(Id stageId, String newName) {
        try {
            FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
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

    @AuraEnabled
    public static void updateCaseStage(
        Id stageId, String name, String nameVN, String alias,
        Boolean status, Boolean active, Boolean defaultStage,
        String natureOfCasesId, String userGroup, Integer posOrder,
        String statusName, Boolean endStage
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException('Stage name cannot be empty.');
        }
        try {
            FEC_Case_Stage__c stage = new FEC_Case_Stage__c(
                Id = stageId,
                Name = name,
                FEC_Name_VN__c = nameVN,
                FEC_Alias__c = alias,
                FEC_Active__c = active,
                FEC_Default_Stage__c = defaultStage != null ? defaultStage : false,
                FEC_Nature_of_Cases__c = String.isNotBlank(natureOfCasesId) ? natureOfCasesId : null,
                FEC_User_Group__c = String.isNotBlank(userGroup) ? userGroup : null,
                FEC_Order__c = posOrder,
                FEC_Status_Name__c = String.isNotBlank(statusName) ? statusName : null
            );
            // Live FEC_Case_Stage__c does not have FEC_End_Stage__c — skip
            update stage;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
}