/**
 * @description Service layer for MDM Master Data Setting CRUD + Schema introspection + Push.
 *              Extracted from FEC_MasterDataSettingController in Phase 2.1 refactor.
 *              Note: saveMasterDataSetting tách thành subroutines.
 *
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.1
 */
public with sharing class FEC_MasterDataSettingService {

    // ════════════════════════════════════════════════════════
    // QUERY MASTER DATA SETTINGS
    // ════════════════════════════════════════════════════════

    public static List<FEC_MDM_Master_Data_Setting__c> getMasterDataSettings(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        if (String.isBlank(selectedNodeId)) return new List<FEC_MDM_Master_Data_Setting__c>();

        List<String> fields = buildFieldList(isIntegration);
        String finalQuery = buildSettingsQuery(fields, selectedNodeId, selectedStageId, isIntegration);
        if (finalQuery == null) return new List<FEC_MDM_Master_Data_Setting__c>();

        List<FEC_MDM_Master_Data_Setting__c> settings = Database.query(finalQuery);
        return restoreStrippedFields(settings, isIntegration);
    }

    private static List<String> buildFieldList(Boolean isIntegration) {
        List<String> fields = new List<String>{
            'Id','Name','FEC_Section__c','FEC_Field_Status__c','FEC_Field_ReadOnly__c',
            'FEC_Field_Order_Display__c','FEC_Field_Object_Name__c','FEC_Field_Mandatory__c',
            'FEC_Applicable_Role__c','Process_Change_Status__c','FEC_Data_Integration_Mapping__c',
            'FEC_Field_API_Name__c', 'FEC_Field_Label_Name__c',
            'FEC_Additional_Field__c','FEC_Additional_Field__r.Name','FEC_Stage_Name__r.Name','FEC_Nature_Of_Case__r.Name','FEC_Channel__c','FEC_Case_Channel__r.Name',
            'FEC_MDM_Channel__c','FEC_MDM_Channel__r.Name',
            'FEC_Field_Masking__c','FEC_Masking_Type__c','FEC_Field_Reverted__c',
            'FEC_Sub_Section__c','FEC_Sub_Section_Field_Layout__c','FEC_Sub_Section_Layout__c',
            'FEC_Sub_Section_Order__c','FEC_Editable_User_Group__c',
            'FEC_Field_Editable__c','FEC_Editable_Role__c'
        };
        if (isIntegration != null && isIntegration) {
            fields.addAll(new List<String>{
                'FEC_Data_Integration_Mapping__r.Id','FEC_Data_Integration_Mapping__r.Name',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Channel__c',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Product_Line_Id__c',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Service_Type_Id__c',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Category_Id__c',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Sub_Category_Id__c',
                'FEC_Data_Integration_Mapping__r.FEC_Int_Sub_Code_Id__c'
            });
        }
        return fields;
    }

    private static String buildSettingsQuery(List<String> fields, String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        String baseQuery = 'SELECT ' + String.join(fields, ', ')
            + ' FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Nature_Of_Case__c = :selectedNodeId ';

        if (String.isNotBlank(selectedStageId)) {
            baseQuery += ' AND FEC_Stage_Name__c = :selectedStageId ';
        } else if (isIntegration != null && isIntegration) {
            baseQuery += ' AND FEC_Stage_Name__c = NULL ';
        } else {
            return null;
        }
        if (isIntegration != null) {
            baseQuery += isIntegration ? ' AND FEC_Data_Integration_Mapping__c != NULL ' : ' AND FEC_Data_Integration_Mapping__c = NULL ';
        }
        baseQuery += ' AND (Process_Change_Status__c = NULL OR Process_Change_Status__c != \'' + FEC_UIConstants.PROCESS_STATUS_DELETED + '\') ';
        return baseQuery + ' ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC';
    }

    private static List<FEC_MDM_Master_Data_Setting__c> restoreStrippedFields(List<FEC_MDM_Master_Data_Setting__c> settings, Boolean isIntegration) {
        List<FEC_MDM_Master_Data_Setting__c> safeSettings = (List<FEC_MDM_Master_Data_Setting__c>)
            Security.stripInaccessible(AccessType.READABLE, settings).getRecords();
        Map<Id, FEC_MDM_Master_Data_Setting__c> originalMap = new Map<Id, FEC_MDM_Master_Data_Setting__c>(settings);
        for (FEC_MDM_Master_Data_Setting__c safe : safeSettings) {
            FEC_MDM_Master_Data_Setting__c orig = originalMap.get(safe.Id);
            if (orig == null) continue;
            restoreLookupFields(safe, orig, isIntegration);
        }
        return safeSettings;
    }

    private static void restoreLookupFields(FEC_MDM_Master_Data_Setting__c safe, FEC_MDM_Master_Data_Setting__c orig, Boolean isIntegration) {
        if (orig.FEC_MDM_Channel__c != null) safe.FEC_MDM_Channel__c = orig.FEC_MDM_Channel__c;
        if (orig.FEC_MDM_Channel__r != null) safe.FEC_MDM_Channel__r = orig.FEC_MDM_Channel__r;
        if (orig.FEC_Sub_Section__c != null) safe.FEC_Sub_Section__c = orig.FEC_Sub_Section__c;
        if (orig.FEC_Sub_Section_Order__c != null) safe.FEC_Sub_Section_Order__c = orig.FEC_Sub_Section_Order__c;
        if (orig.FEC_Sub_Section_Layout__c != null) safe.FEC_Sub_Section_Layout__c = orig.FEC_Sub_Section_Layout__c;
        if (orig.FEC_Sub_Section_Field_Layout__c != null) safe.FEC_Sub_Section_Field_Layout__c = orig.FEC_Sub_Section_Field_Layout__c;
        if (orig.FEC_Field_Editable__c != null) safe.FEC_Field_Editable__c = orig.FEC_Field_Editable__c;
        if (orig.FEC_Editable_Role__c != null) safe.FEC_Editable_Role__c = orig.FEC_Editable_Role__c;
        if (isIntegration != null && isIntegration) {
            if (orig.FEC_Data_Integration_Mapping__r != null) safe.FEC_Data_Integration_Mapping__r = orig.FEC_Data_Integration_Mapping__r;
            safe.FEC_Data_Integration_Mapping__c = orig.FEC_Data_Integration_Mapping__c;
        }
    }

    // ════════════════════════════════════════════════════════
    // SAVE MASTER DATA SETTING (was 213 LOC, now ≤ 30 LOC + subroutines)
    // ════════════════════════════════════════════════════════

    public static Id saveMasterDataSetting(Map<String, Object> mappingReq) {
        String recordId = (String) mappingReq.get(FEC_FieldConstants.FIELD_ID);
        Boolean isCreateMode = String.isBlank(recordId);

        verifyMDSCRUD(isCreateMode);

        FEC_MDM_Master_Data_Setting__c recordToSave = isCreateMode
            ? new FEC_MDM_Master_Data_Setting__c()
            : new FEC_MDM_Master_Data_Setting__c(Id = recordId);
        try {
            populateFieldsFromRequest(recordToSave, mappingReq);
            validateSchemaFields(recordToSave.FEC_Field_Object_Name__c, recordToSave.FEC_Field_API_Name__c);

            PreservedFields preserved = capturePreservedFields(recordToSave);
            FEC_MDM_Master_Data_Setting__c sanitized = applyFLSAndRestore(recordToSave, preserved);
            upsert sanitized;
            recordToSave.Id = sanitized.Id;

            if (isCreateMode) autoAssignCode(sanitized.Id);
            return sanitized.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            AuraHandledException ex = new AuraHandledException(dml.getDmlMessage(0));
            ex.setMessage(dml.getDmlMessage(0));
            throw ex;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    private static void verifyMDSCRUD(Boolean isCreateMode) {
        Schema.DescribeSObjectResult d = FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe();
        if (isCreateMode && !d.isCreateable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission);
        }
        if (!isCreateMode && !d.isUpdateable()) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
        }
    }

    private static void populateFieldsFromRequest(FEC_MDM_Master_Data_Setting__c rec, Map<String, Object> req) {
        if (req.containsKey(FEC_FieldConstants.FIELD_NATURE_OF_CASE)) {
            rec.FEC_Nature_Of_Case__c = getOptionalId(req, FEC_FieldConstants.FIELD_NATURE_OF_CASE);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_STAGE_NAME)) {
            rec.FEC_Stage_Name__c = getOptionalId(req, FEC_FieldConstants.FIELD_STAGE_NAME);
        }
        populateAdditionalAndChannelFields(rec, req);
        populateOrderAndStatusFields(rec, req);
        populateMaskingAndSubSectionFields(rec, req);
        populateEditableFields(rec, req);
    }

    private static void populateAdditionalAndChannelFields(FEC_MDM_Master_Data_Setting__c rec, Map<String, Object> req) {
        if (req.containsKey(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD)) {
            rec.FEC_Additional_Field__c = (String) req.get(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_SECTION)) {
            rec.FEC_Section__c = (String) req.get(FEC_FieldConstants.FIELD_SECTION);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_MDM_CHANNEL)) {
            rec.FEC_MDM_Channel__c = getOptionalId(req, FEC_FieldConstants.FIELD_MDM_CHANNEL);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_APPLICABLE_ROLE)) {
            rec.FEC_Applicable_Role__c = getOptionalId(req, FEC_FieldConstants.FIELD_APPLICABLE_ROLE);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_CASE_CHANNEL)) {
            rec.FEC_Case_Channel__c = getOptionalId(req, FEC_FieldConstants.FIELD_CASE_CHANNEL);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING)) {
            rec.FEC_Data_Integration_Mapping__c = getOptionalId(req, FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING);
        }
    }

    private static void populateOrderAndStatusFields(FEC_MDM_Master_Data_Setting__c rec, Map<String, Object> req) {
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY)) {
            Object v = req.get(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY);
            rec.FEC_Field_Order_Display__c = (v != null) ? Integer.valueOf(String.valueOf(v)) : null;
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_STATUS)) {
            rec.FEC_Field_Status__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_STATUS);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_READONLY)) {
            rec.FEC_Field_ReadOnly__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_READONLY);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_MANDATORY)) {
            rec.FEC_Field_Mandatory__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_MANDATORY);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME)) {
            rec.FEC_Field_Object_Name__c = (String) req.get(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_API_NAME)) {
            rec.FEC_Field_API_Name__c = (String) req.get(FEC_FieldConstants.FIELD_FIELD_API_NAME);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME)) {
            rec.FEC_Field_Label_Name__c = (String) req.get(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME);
        }
    }

    private static void populateMaskingAndSubSectionFields(FEC_MDM_Master_Data_Setting__c rec, Map<String, Object> req) {
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_MASKING)) {
            rec.FEC_Field_Masking__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_MASKING);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_MASKING_TYPE)) {
            rec.FEC_Masking_Type__c = (String) req.get(FEC_FieldConstants.FIELD_MASKING_TYPE);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_REVERTED)) {
            rec.FEC_Field_Reverted__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_REVERTED);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION)) {
            rec.FEC_Sub_Section__c = (String) req.get(FEC_FieldConstants.FIELD_SUB_SECTION);
        }
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
    }

    private static void populateEditableFields(FEC_MDM_Master_Data_Setting__c rec, Map<String, Object> req) {
        if (req.containsKey(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP)) {
            rec.FEC_Editable_User_Group__c = (String) req.get(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_FIELD_EDITABLE)) {
            rec.FEC_Field_Editable__c = (Boolean) req.get(FEC_FieldConstants.FIELD_FIELD_EDITABLE);
        }
        if (req.containsKey(FEC_FieldConstants.FIELD_EDITABLE_ROLE)) {
            rec.FEC_Editable_Role__c = (String) req.get(FEC_FieldConstants.FIELD_EDITABLE_ROLE);
        }
    }

    private static String getOptionalId(Map<String, Object> req, String fieldName) {
        String value = (String) req.get(fieldName);
        return String.isNotBlank(value) ? value : null;
    }

    @TestVisible
    public static void validateSchemaFields(String objectName, String fieldApiName) {
        if (String.isBlank(objectName)) return;
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectName)) {
            String msg = System.Label.FEC_Error_Invalid_Object_Name + ': ' + objectName;
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
        if (String.isNotBlank(fieldApiName)) {
            Map<String, Schema.SObjectField> fieldMap = globalDescribe.get(objectName).getDescribe().fields.getMap();
            if (!fieldMap.containsKey(fieldApiName)) {
                String msg = System.Label.FEC_Error_Invalid_Field_Name + ': ' + fieldApiName + ' on ' + objectName;
                AuraHandledException ex = new AuraHandledException(msg);
                ex.setMessage(msg);
                throw ex;
            }
        }
    }

    private class PreservedFields {
        Id channelId;
        Id integrationMappingId;
        Id nocId;
        Id stageId;
        String subSection;
        Decimal subSectionOrder;
        Decimal subSectionLayout;
        Decimal subSectionFieldLayout;
        Boolean fieldEditable;
        String editableRole;
    }

    private static PreservedFields capturePreservedFields(FEC_MDM_Master_Data_Setting__c rec) {
        PreservedFields p = new PreservedFields();
        p.channelId = rec.FEC_MDM_Channel__c;
        p.integrationMappingId = rec.FEC_Data_Integration_Mapping__c;
        p.nocId = rec.FEC_Nature_Of_Case__c;
        p.stageId = rec.FEC_Stage_Name__c;
        p.subSection = rec.FEC_Sub_Section__c;
        p.subSectionOrder = rec.FEC_Sub_Section_Order__c;
        p.subSectionLayout = rec.FEC_Sub_Section_Layout__c;
        p.subSectionFieldLayout = rec.FEC_Sub_Section_Field_Layout__c;
        p.fieldEditable = rec.FEC_Field_Editable__c;
        p.editableRole = rec.FEC_Editable_Role__c;
        return p;
    }

    private static FEC_MDM_Master_Data_Setting__c applyFLSAndRestore(FEC_MDM_Master_Data_Setting__c rec, PreservedFields p) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPSERTABLE,
            new List<FEC_MDM_Master_Data_Setting__c>{rec}
        );
        FEC_MDM_Master_Data_Setting__c sanitized = (FEC_MDM_Master_Data_Setting__c) decision.getRecords()[0];
        Map<String, Set<String>> removedFields = decision.getRemovedFields();
        String sObjName = FEC_ObjectConstants.OBJ_MDM_MASTER_DATA_SETTING;
        if (!removedFields.containsKey(sObjName)) return sanitized;

        Set<String> removed = removedFields.get(sObjName);
        restoreFromRemoved(sanitized, removed, p);
        return sanitized;
    }

    private static void restoreFromRemoved(FEC_MDM_Master_Data_Setting__c sanitized, Set<String> removed, PreservedFields p) {
        if (removed.contains(FEC_FieldConstants.FIELD_MDM_CHANNEL) && p.channelId != null) {
            sanitized.FEC_MDM_Channel__c = p.channelId;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING) && p.integrationMappingId != null) {
            sanitized.FEC_Data_Integration_Mapping__c = p.integrationMappingId;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_NATURE_OF_CASE) && p.nocId != null) {
            sanitized.FEC_Nature_Of_Case__c = p.nocId;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_STAGE_NAME) && p.stageId != null) {
            sanitized.FEC_Stage_Name__c = p.stageId;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_SUB_SECTION) && p.subSection != null) {
            sanitized.FEC_Sub_Section__c = p.subSection;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_SUB_SECTION_ORDER) && p.subSectionOrder != null) {
            sanitized.FEC_Sub_Section_Order__c = p.subSectionOrder;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT) && p.subSectionLayout != null) {
            sanitized.FEC_Sub_Section_Layout__c = p.subSectionLayout;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT) && p.subSectionFieldLayout != null) {
            sanitized.FEC_Sub_Section_Field_Layout__c = p.subSectionFieldLayout;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_FIELD_EDITABLE) && p.fieldEditable != null) {
            sanitized.FEC_Field_Editable__c = p.fieldEditable;
        }
        if (removed.contains(FEC_FieldConstants.FIELD_EDITABLE_ROLE) && p.editableRole != null) {
            sanitized.FEC_Editable_Role__c = p.editableRole;
        }
    }

    private static void autoAssignCode(Id recordId) {
        try {
            FEC_MDM_Master_Data_Setting__c codeUpdate = new FEC_MDM_Master_Data_Setting__c(
                Id = recordId, FEC_Code__c = recordId
            );
            update codeUpdate;
        } catch (Exception codeEx) {
            System.debug('Failed to assign FEC_Code__c for record ' + recordId + ': ' + codeEx.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // DELETE
    // ════════════════════════════════════════════════════════

    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + FEC_UIConstants.ERROR_INVALID_ID);
        }
        try {
            delete new FEC_MDM_Master_Data_Setting__c(Id = recordId);
            return FEC_UIConstants.OPERATION_SUCCESS;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_SYSTEM + ' ' + e.getMessage());
        }
    }

    public static void deleteFraudIntegrationMapping(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                throw new IllegalArgumentException(System.Label.FEC_Error_Record_Id_Empty);
            }
            List<FEC_MDM_Master_Data_Setting__c> records = [
                SELECT Id, Name, Process_Change_Status__c
                FROM   FEC_MDM_Master_Data_Setting__c
                WHERE  Id = :recordId LIMIT 1
            ];
            if (records.isEmpty()) {
                throw new IllegalArgumentException(System.Label.FEC_Error_Record_Not_Found);
            }
            if (records[0].Process_Change_Status__c == FEC_UIConstants.PROCESS_STATUS_NEW) {
                delete records[0];
            } else {
                records[0].Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_DELETED;
                update records[0];
            }
        } catch (DmlException e) {
            throw new AuraHandledException(System.Label.FEC_Error_Delete_Record_Prefix + ' ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Generic + ' ' + e.getMessage());
        }
    }

    // ════════════════════════════════════════════════════════
    // SCHEMA INTROSPECTION
    // ════════════════════════════════════════════════════════

    public static List<Map<String, String>> getGlobalObjectList() {
        try {
            Set<String> allowedObjects = new Set<String>{
                FEC_ObjectConstants.OBJ_CUSTOMER_HISTORY,
                FEC_ObjectConstants.OBJ_ADDITIONAL_INFO,
                FEC_ObjectConstants.OBJ_CASE
            };
            List<Map<String, String>> result = new List<Map<String, String>>();
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            for (String objName : allowedObjects) {
                Schema.SObjectType sot = globalDescribe.get(objName);
                if (sot == null) continue;
                Schema.DescribeSObjectResult objDescribe = sot.getDescribe();
                if (objDescribe.isAccessible()) {
                    result.add(new Map<String, String>{
                        FEC_UIConstants.MAP_LABEL => objDescribe.getLabel() + ' (' + objDescribe.getName() + ')',
                        FEC_UIConstants.MAP_VALUE => objDescribe.getName()
                    });
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getObjectFields(String objectName) {
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
            if (sot == null) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_SOBJECT_PREFIX + ' ' + objectName);
            }
            List<Map<String, String>> result = new List<Map<String, String>>();
            Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                if (dfr.isAccessible()) {
                    result.add(new Map<String, String>{
                        FEC_UIConstants.MAP_LABEL => dfr.getLabel(),
                        FEC_UIConstants.MAP_VALUE => dfr.getName(),
                        'type' => String.valueOf(dfr.getType())
                    });
                }
            }
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<String> getDistinctSections(String natureOfCaseId, String stageId) {
        try {
            List<String> sections = new List<String>();
            for (AggregateResult ar : [
                SELECT FEC_Section__c section
                FROM   FEC_MDM_Master_Data_Setting__c
                WHERE  FEC_Nature_Of_Case__c = :natureOfCaseId
                AND    FEC_Stage_Name__c = :stageId
                AND    FEC_Section__c != NULL
                GROUP BY FEC_Section__c
                ORDER BY FEC_Section__c ASC
            ]) {
                sections.add((String) ar.get('section'));
            }
            return sections;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, Object>> getDistinctSubSections(String natureOfCaseId, String stageId, String section) {
        try {
            Map<String, Map<String, Object>> subSectionMap = new Map<String, Map<String, Object>>();
            for (FEC_MDM_Master_Data_Setting__c mds : [
                SELECT FEC_Sub_Section__c, FEC_Sub_Section_Order__c,
                       FEC_Sub_Section_Layout__c, FEC_Sub_Section_Field_Layout__c
                FROM   FEC_MDM_Master_Data_Setting__c
                WHERE  FEC_Nature_Of_Case__c = :natureOfCaseId
                AND    FEC_Stage_Name__c = :stageId
                AND    FEC_Section__c = :section
                AND    FEC_Sub_Section__c != NULL
                ORDER BY FEC_Sub_Section_Order__c ASC NULLS LAST
            ]) {
                String subSec = mds.FEC_Sub_Section__c;
                if (!subSectionMap.containsKey(subSec)) {
                    subSectionMap.put(subSec, new Map<String, Object>{
                        'subSection' => subSec,
                        'subSectionOrder' => mds.FEC_Sub_Section_Order__c,
                        'subSectionLayout' => mds.FEC_Sub_Section_Layout__c,
                        'subSectionFieldLayout' => mds.FEC_Sub_Section_Field_Layout__c
                    });
                }
            }
            return subSectionMap.values();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static Id executePushToLive() {
        try {
            return Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static Map<String, Decimal> getSubSectionOrderMap() {
        Map<String, Decimal> result = new Map<String, Decimal>();
        for (AggregateResult ag : [
            SELECT FEC_Sub_Section__c subSec, MAX(FEC_Sub_Section_Order__c) subOrder
            FROM   FEC_Master_Data_Setting__c
            WHERE  FEC_Sub_Section__c != null AND FEC_Field_Status__c = true
            GROUP BY FEC_Sub_Section__c
        ]) {
            String subSec = (String) ag.get('subSec');
            Decimal subOrder = (Decimal) ag.get('subOrder');
            if (String.isNotBlank(subSec)) result.put(subSec, subOrder);
        }
        return result;
    }

    // ════════════════════════════════════════════════════════
    // CHECK PARENT DUPLICATE PROPERTY
    // ════════════════════════════════════════════════════════

    public static String checkParentDuplicateProperty(
        String nocId, String stageId, String additionalFieldId,
        String channelId, String applicableRole
    ) {
        if (String.isBlank(nocId) || String.isBlank(additionalFieldId)) return null;
        try {
            FEC_MDM_Nature_Of_Case__c currentNoc = queryCurrentNoc(nocId);
            if (currentNoc == null) return null;

            Integer currentLevel = determineNocLevel(currentNoc);
            if (currentLevel <= 1) return null;

            Set<Id> parentNocIds = collectParentNocIds(currentNoc, currentLevel);
            if (parentNocIds.isEmpty()) return null;

            return findDuplicateParentName(parentNocIds, additionalFieldId, stageId, channelId);
        } catch (Exception e) {
            throw new AuraHandledException(System.Label.FEC_Error_Parent_Duplicate_Check + ' ' + e.getMessage());
        }
    }

    private static FEC_MDM_Nature_Of_Case__c queryCurrentNoc(String nocId) {
        List<FEC_MDM_Nature_Of_Case__c> nocList = [
            SELECT Id,
                   FEC_Product_Type__c, FEC_Product_Type__r.Name,
                   FEC_Business_Process__c, FEC_Business_Process__r.Name,
                   FEC_Category__c, FEC_Category__r.Name,
                   FEC_Sub_Category__c, FEC_Sub_Category__r.Name,
                   FEC_Sub_Code__c, FEC_Sub_Code__r.Name
            FROM   FEC_MDM_Nature_Of_Case__c
            WHERE  Id = :nocId LIMIT 1
        ];
        return nocList.isEmpty() ? null : nocList[0];
    }

    private static Integer determineNocLevel(FEC_MDM_Nature_Of_Case__c noc) {
        Integer level = 1;
        if (noc.FEC_Business_Process__c != null) level = 2;
        if (noc.FEC_Category__c != null) level = 3;
        if (noc.FEC_Sub_Category__c != null) level = 4;
        if (noc.FEC_Sub_Code__c != null) level = 5;
        return level;
    }

    private static Set<Id> collectParentNocIds(FEC_MDM_Nature_Of_Case__c noc, Integer currentLevel) {
        Id ptId = noc.FEC_Product_Type__c;
        Id bpId = noc.FEC_Business_Process__c;
        Id catId = noc.FEC_Category__c;
        Id scatId = noc.FEC_Sub_Category__c;

        String parentQuery = 'SELECT Id FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :ptId AND (';
        List<String> conditions = new List<String>();
        if (currentLevel > 1) conditions.add('(FEC_Business_Process__c = NULL)');
        if (currentLevel > 2) conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = NULL)');
        if (currentLevel > 3) conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = :catId AND FEC_Sub_Category__c = NULL)');
        if (currentLevel > 4) conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :scatId AND FEC_Sub_Code__c = NULL)');

        parentQuery += String.join(conditions, ' OR ') + ')';

        Set<Id> parentNocIds = new Set<Id>();
        for (FEC_MDM_Nature_Of_Case__c parentNoc : Database.query(parentQuery)) {
            parentNocIds.add(parentNoc.Id);
        }
        return parentNocIds;
    }

    private static String findDuplicateParentName(Set<Id> parentNocIds, String additionalFieldId, String stageId, String channelId) {
        String settingQuery = 'SELECT Id, FEC_Nature_Of_Case__r.FEC_Product_Type__r.Name, '
            + 'FEC_Nature_Of_Case__r.FEC_Business_Process__r.Name, '
            + 'FEC_Nature_Of_Case__r.FEC_Category__r.Name, '
            + 'FEC_Nature_Of_Case__r.FEC_Sub_Category__r.Name '
            + 'FROM FEC_MDM_Master_Data_Setting__c '
            + 'WHERE FEC_Nature_Of_Case__c IN :parentNocIds '
            + 'AND FEC_Additional_Field__c = :additionalFieldId '
            + 'AND FEC_Data_Integration_Mapping__c = NULL ';
        if (String.isNotBlank(stageId)) settingQuery += 'AND FEC_Stage_Name__c = :stageId ';
        if (String.isNotBlank(channelId)) settingQuery += 'AND FEC_MDM_Channel__c = :channelId ';
        settingQuery += 'LIMIT 1';

        List<FEC_MDM_Master_Data_Setting__c> duplicates = Database.query(settingQuery);
        if (duplicates.isEmpty()) return null;

        return resolveParentName(duplicates[0]);
    }

    private static String resolveParentName(FEC_MDM_Master_Data_Setting__c dup) {
        if (dup.FEC_Nature_Of_Case__r.FEC_Sub_Category__r?.Name != null) {
            return dup.FEC_Nature_Of_Case__r.FEC_Sub_Category__r.Name;
        }
        if (dup.FEC_Nature_Of_Case__r.FEC_Category__r?.Name != null) {
            return dup.FEC_Nature_Of_Case__r.FEC_Category__r.Name;
        }
        if (dup.FEC_Nature_Of_Case__r.FEC_Business_Process__r?.Name != null) {
            return dup.FEC_Nature_Of_Case__r.FEC_Business_Process__r.Name;
        }
        if (dup.FEC_Nature_Of_Case__r.FEC_Product_Type__r?.Name != null) {
            return dup.FEC_Nature_Of_Case__r.FEC_Product_Type__r.Name;
        }
        return '';
    }
}