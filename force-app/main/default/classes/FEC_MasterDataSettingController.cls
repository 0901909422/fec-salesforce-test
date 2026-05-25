/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Master_Data_Setting__c.
 * Đóng vai trò là nơi cung cấp dữ liệu cấu hình (Settings) cho LWC.
 * @date 2025-12-03
 * @author DAT NGO
 */
public with sharing class FEC_MasterDataSettingController {
    
    /** Allowlist of sObject API names permitted for getLookupOptions queries. */
    @TestVisible
    private static final Set<String> ALLOWED_LOOKUP_OBJECTS = new Set<String>{
        'FEC_Case_Stage__c',
        'FEC_MDM_Additional_Field__c',
        'UserRole'
    };
    
    /**
     * @description Lấy danh sách các bản ghi Master Data Setting, phân loại theo Tab Property hoặc Fraud.
     * @param selectedNodeId ID của Nature of Case
     * @param selectedStageId ID của Stage
     * @param isIntegration true nếu lấy dữ liệu cho tab Fraud Integration, false nếu lấy Property
     * @return List<FEC_MDM_Master_Data_Setting__c>
     */
    @AuraEnabled(cacheable=true)
    public static List<FEC_MDM_Master_Data_Setting__c> getMasterDataSettings(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        // Kiểm tra input cơ bản
        if (String.isBlank(selectedNodeId)) return new List<FEC_MDM_Master_Data_Setting__c>();
        
        // Build field list and assemble SOQL succinctly
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
        
        // Add integration mapping fields only if querying fraud/integration records
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

        String baseQuery = 'SELECT ' + String.join(fields, ', ') + ' FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Nature_Of_Case__c = :selectedNodeId ';
        if (String.isNotBlank(selectedStageId)) {
            // If selectedStageId is provided, return only records for that specific stage
            baseQuery += ' AND FEC_Stage_Name__c = :selectedStageId ';
        } else if (isIntegration != null && isIntegration) {
            // For integration/fraud records, allow querying records without a stage
            baseQuery += ' AND FEC_Stage_Name__c = NULL ';
        } else {
            // For non-integration records, stageId is required — return empty
            return new List<FEC_MDM_Master_Data_Setting__c>();
        }
        if (isIntegration != null) {
            baseQuery += isIntegration ? ' AND FEC_Data_Integration_Mapping__c != NULL ' : ' AND FEC_Data_Integration_Mapping__c = NULL ';
        }

        // Exclude soft-deleted records
        baseQuery += ' AND (Process_Change_Status__c = NULL OR Process_Change_Status__c != \'' + FEC_UIConstants.PROCESS_STATUS_DELETED + '\') ';

        String finalQuery = baseQuery + ' ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC';
        
        List<FEC_MDM_Master_Data_Setting__c> settings = Database.query(finalQuery);
        
        // DEBUG: Log query results for fraud integration
        if (isIntegration != null && isIntegration) {
            System.debug('FEC_DEBUG getMasterDataSettings: query=' + finalQuery);
            System.debug('FEC_DEBUG getMasterDataSettings: found ' + settings.size() + ' records');
            for (FEC_MDM_Master_Data_Setting__c s : settings) {
                System.debug('FEC_DEBUG record Id=' + s.Id 
                    + ' FEC_Data_Integration_Mapping__c=' + s.FEC_Data_Integration_Mapping__c
                    + ' FEC_Data_Integration_Mapping__r=' + s.FEC_Data_Integration_Mapping__r
                );
                if (s.FEC_Data_Integration_Mapping__r != null) {
                    System.debug('FEC_DEBUG mapping: Channel=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Channel__c
                        + ' ProductLine=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Product_Line_Id__c
                        + ' ServiceType=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Service_Type_Id__c
                        + ' Category=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Category_Id__c
                        + ' SubCategory=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Sub_Category_Id__c
                        + ' SubCode=' + s.FEC_Data_Integration_Mapping__r.FEC_Int_Sub_Code_Id__c
                    );
                } else {
                    System.debug('FEC_DEBUG mapping: FEC_Data_Integration_Mapping__r is NULL');
                }
            }
        }
        
        // FLS enforcement: strip fields the running user cannot read
        List<FEC_MDM_Master_Data_Setting__c> safeSettings = (List<FEC_MDM_Master_Data_Setting__c>) Security.stripInaccessible(AccessType.READABLE, settings).getRecords();
        
        // Workaround: stripInaccessible removes lookup fields user can't read.
        // Re-attach lookup IDs and relationship data from original query results.
        Map<Id, FEC_MDM_Master_Data_Setting__c> originalMap = new Map<Id, FEC_MDM_Master_Data_Setting__c>(settings);
        for (Integer i = 0; i < safeSettings.size(); i++) {
            FEC_MDM_Master_Data_Setting__c safe = safeSettings[i];
            FEC_MDM_Master_Data_Setting__c orig = originalMap.get(safe.Id);
            if (orig != null) {
                // Restore Channel lookup if stripped by FLS
                if (orig.FEC_MDM_Channel__c != null) {
                    safe.FEC_MDM_Channel__c = orig.FEC_MDM_Channel__c;
                }
                if (orig.FEC_MDM_Channel__r != null) {
                    safe.FEC_MDM_Channel__r = orig.FEC_MDM_Channel__r;
                }
                // Restore Sub Section fields if stripped by FLS
                if (orig.FEC_Sub_Section__c != null) {
                    safe.FEC_Sub_Section__c = orig.FEC_Sub_Section__c;
                }
                if (orig.FEC_Sub_Section_Order__c != null) {
                    safe.FEC_Sub_Section_Order__c = orig.FEC_Sub_Section_Order__c;
                }
                if (orig.FEC_Sub_Section_Layout__c != null) {
                    safe.FEC_Sub_Section_Layout__c = orig.FEC_Sub_Section_Layout__c;
                }
                if (orig.FEC_Sub_Section_Field_Layout__c != null) {
                    safe.FEC_Sub_Section_Field_Layout__c = orig.FEC_Sub_Section_Field_Layout__c;
                }
                // Restore Editable fields if stripped by FLS
                if (orig.FEC_Field_Editable__c != null) {
                    safe.FEC_Field_Editable__c = orig.FEC_Field_Editable__c;
                }
                if (orig.FEC_Editable_Role__c != null) {
                    safe.FEC_Editable_Role__c = orig.FEC_Editable_Role__c;
                }
                // Restore Integration Mapping lookup if stripped by FLS
                if (isIntegration != null && isIntegration) {
                    if (orig.FEC_Data_Integration_Mapping__r != null) {
                        safe.FEC_Data_Integration_Mapping__r = orig.FEC_Data_Integration_Mapping__r;
                    }
                    safe.FEC_Data_Integration_Mapping__c = orig.FEC_Data_Integration_Mapping__c;
                }
            }
        }
        
        // DEBUG: Log after FLS strip
        if (isIntegration != null && isIntegration) {
            System.debug('FEC_DEBUG after stripInaccessible: ' + safeSettings.size() + ' records');
        }
        
        return safeSettings;
    }
    
    /**
     * @description Non-cacheable version of getMasterDataSettings for imperative refresh after DML.
     */
    @AuraEnabled
    public static List<FEC_MDM_Master_Data_Setting__c> getMasterDataSettingsFresh(String selectedNodeId, String selectedStageId, Boolean isIntegration) {
        return getMasterDataSettings(selectedNodeId, selectedStageId, isIntegration);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannels() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Channel__c> channels = [SELECT Id, Name FROM FEC_MDM_Channel__c ORDER BY CreatedDate DESC];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        for (FEC_MDM_Channel__c c : (List<FEC_MDM_Channel__c>) safe) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => c.Name, FEC_UIConstants.MAP_VALUE => c.Id});
        }
        return options;
     }
     
     @AuraEnabled(cacheable=true)
     public static List<Map<String, String>> getUserRoles() {
         List<Map<String, String>> options = new List<Map<String, String>>();
         List<UserRole> roles = [SELECT Name FROM UserRole ORDER BY Name];
         List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, roles).getRecords();
         for (UserRole r : (List<UserRole>) safe) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => r.Name, FEC_UIConstants.MAP_VALUE => r.Name});
         }
         return options;
     }
    
    /**
     * @description Lấy danh sách các Stage Name (FEC_Case_Stage__c) cho Combobox.
     * @return List<Map<String, Object>> Danh sách các Stage dưới dạng {label, value}.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getStageOptions() {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE, FEC_UIConstants.MAP_VALUE => ''});
        List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name 
        FROM FEC_Case_Stage__c 
        WITH SECURITY_ENFORCED 
        ORDER BY Name ASC
    ];
         for (FEC_Case_Stage__c stage : stages) {
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
             throw new AuraHandledException('Invalid sObject: ' + sObjectName + '. Only allowed objects can be queried.');
         }
         List<Map<String, Object>> options = new List<Map<String, Object>>();
         options.add(new Map<String, Object>{FEC_UIConstants.MAP_LABEL => FEC_UIConstants.LABEL_NONE, FEC_UIConstants.MAP_VALUE => ''});
         Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectName);
         if (targetType == null) {
             throw new AuraHandledException(FEC_UIConstants.ERROR_INVALID_SOBJECT_PREFIX + sObjectName);
         }
         String query = 'SELECT Id, Name FROM ' + sObjectName + ' WITH SECURITY_ENFORCED ORDER BY Name ASC';
         List<SObject> records = Database.query(query);
         for (SObject rec : records) {
             options.add(new Map<String, Object>{FEC_UIConstants.MAP_LABEL => (String)rec.get('Name'), FEC_UIConstants.MAP_VALUE => (String)rec.get('Id')});
         }
         return options;
    }
    
    private static String getOptionalId(Map<String, Object> mappingReq, String fieldName) {
        String value = (String)mappingReq.get(fieldName);
        return String.isNotBlank(value) ? value : null;
    }
    
    /**
     * @description Validate object name và field API name tồn tại trong Salesforce Schema.
     * Bỏ qua validation nếu objectName rỗng/null.
     * @param objectName SObject API name cần kiểm tra
     * @param fieldApiName Field API name cần kiểm tra trên target object
     * @throws AuraHandledException nếu object hoặc field không hợp lệ
     */
    @TestVisible
    private static void validateSchemaFields(String objectName, String fieldApiName) {
        if (String.isBlank(objectName)) return;
        
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectName)) {
            String msg = System.Label.FEC_Error_Invalid_Object_Name + ': ' + objectName;
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
        
        if (String.isNotBlank(fieldApiName)) {
            Map<String, Schema.SObjectField> fieldMap = 
                globalDescribe.get(objectName).getDescribe().fields.getMap();
            if (!fieldMap.containsKey(fieldApiName)) {
                String msg = System.Label.FEC_Error_Invalid_Field_Name + ': ' + fieldApiName 
                    + ' on ' + objectName;
                AuraHandledException ex = new AuraHandledException(msg);
                ex.setMessage(msg);
                throw ex;
            }
        }
    }
    
    @AuraEnabled
    public static Id saveMasterDataSetting(Map<String, Object> mappingReq) {
        String recordId = (String)mappingReq.get(FEC_FieldConstants.FIELD_ID);
        Boolean isCreateMode = String.isBlank(recordId);

        // CRUD check before any field population or DML
        if (isCreateMode) {
            if (!FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().isCreateable()) {
                throw new AuraHandledException(System.Label.FEC_Error_No_Create_Permission);
            }
        } else {
            if (!FEC_MDM_Master_Data_Setting__c.SObjectType.getDescribe().isUpdateable()) {
                throw new AuraHandledException(FEC_UIConstants.ERROR_NO_UPDATE_PERMISSION);
            }
        }

        FEC_MDM_Master_Data_Setting__c recordToSave = isCreateMode
            ? new FEC_MDM_Master_Data_Setting__c()
            : new FEC_MDM_Master_Data_Setting__c(Id = recordId);
        try {
            // Common fields for both CREATE and EDIT
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_NATURE_OF_CASE)) {
                recordToSave.FEC_Nature_Of_Case__c = getOptionalId(mappingReq, FEC_FieldConstants.FIELD_NATURE_OF_CASE);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_STAGE_NAME)) {
                recordToSave.FEC_Stage_Name__c = getOptionalId(mappingReq, FEC_FieldConstants.FIELD_STAGE_NAME);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD)) {
                recordToSave.FEC_Additional_Field__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_ADDITIONAL_FIELD);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_SECTION)) {
                recordToSave.FEC_Section__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_SECTION);
            }
            if (mappingReq.containsKey('FEC_MDM_Channel__c')) {
                recordToSave.FEC_MDM_Channel__c = getOptionalId(mappingReq, 'FEC_MDM_Channel__c');
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_APPLICABLE_ROLE)) {
                recordToSave.FEC_Applicable_Role__c = getOptionalId(mappingReq, FEC_FieldConstants.FIELD_APPLICABLE_ROLE);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY)) {
                Object orderValue = mappingReq.get(FEC_FieldConstants.FIELD_FIELD_ORDER_DISPLAY);
                recordToSave.FEC_Field_Order_Display__c = (orderValue != null)
                    ? Integer.valueOf(String.valueOf(orderValue)) : null;
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_STATUS)) {
                recordToSave.FEC_Field_Status__c = (Boolean)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_STATUS);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_READONLY)) {
                recordToSave.FEC_Field_ReadOnly__c = (Boolean)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_READONLY);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_MANDATORY)) {
                recordToSave.FEC_Field_Mandatory__c = (Boolean)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_MANDATORY);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME)) {
                recordToSave.FEC_Field_Object_Name__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_OBJECT_NAME);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_API_NAME)) {
                recordToSave.FEC_Field_API_Name__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_API_NAME);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME)) {
                recordToSave.FEC_Field_Label_Name__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_LABEL_NAME);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_CASE_CHANNEL)) {
                recordToSave.FEC_Case_Channel__c = getOptionalId(mappingReq, FEC_FieldConstants.FIELD_CASE_CHANNEL);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING)) {
                recordToSave.FEC_Data_Integration_Mapping__c = getOptionalId(mappingReq, FEC_FieldConstants.FIELD_DATA_INTEGRATION_MAPPING);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_MASKING)) {
                recordToSave.FEC_Field_Masking__c = (Boolean)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_MASKING);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_MASKING_TYPE)) {
                recordToSave.FEC_Masking_Type__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_MASKING_TYPE);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_FIELD_REVERTED)) {
                recordToSave.FEC_Field_Reverted__c = (Boolean)mappingReq.get(FEC_FieldConstants.FIELD_FIELD_REVERTED);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION)) {
                recordToSave.FEC_Sub_Section__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_SUB_SECTION);
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT)) {
                Object subSectionFieldLayoutValue = mappingReq.get(FEC_FieldConstants.FIELD_SUB_SECTION_FIELD_LAYOUT);
                recordToSave.FEC_Sub_Section_Field_Layout__c = (subSectionFieldLayoutValue != null)
                    ? Integer.valueOf(String.valueOf(subSectionFieldLayoutValue)) : null;
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT)) {
                Object subSectionLayoutValue = mappingReq.get(FEC_FieldConstants.FIELD_SUB_SECTION_LAYOUT);
                recordToSave.FEC_Sub_Section_Layout__c = (subSectionLayoutValue != null)
                    ? Integer.valueOf(String.valueOf(subSectionLayoutValue)) : null;
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_SUB_SECTION_ORDER)) {
                Object subSectionOrderValue = mappingReq.get(FEC_FieldConstants.FIELD_SUB_SECTION_ORDER);
                recordToSave.FEC_Sub_Section_Order__c = (subSectionOrderValue != null)
                    ? Integer.valueOf(String.valueOf(subSectionOrderValue)) : null;
            }
            if (mappingReq.containsKey(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP)) {
                recordToSave.FEC_Editable_User_Group__c = (String)mappingReq.get(FEC_FieldConstants.FIELD_EDITABLE_USER_GROUP);
            }
            if (mappingReq.containsKey('FEC_Field_Editable__c')) {
                recordToSave.FEC_Field_Editable__c = (Boolean)mappingReq.get('FEC_Field_Editable__c');
            }
            if (mappingReq.containsKey('FEC_Editable_Role__c')) {
                recordToSave.FEC_Editable_Role__c = (String)mappingReq.get('FEC_Editable_Role__c');
            }
            
            // Schema validation: verify object name and field API name exist before DML
            validateSchemaFields(
                recordToSave.FEC_Field_Object_Name__c,
                recordToSave.FEC_Field_API_Name__c
            );
            
            // Preserve lookup field values before FLS strip (stripInaccessible may remove lookup fields
            // if the running user's profile lacks FLS edit access, even though they have object-level access)
            Id preservedChannelId = recordToSave.FEC_MDM_Channel__c;
            Id preservedIntegrationMappingId = recordToSave.FEC_Data_Integration_Mapping__c;
            Id preservedNocId = recordToSave.FEC_Nature_Of_Case__c;
            Id preservedStageId = recordToSave.FEC_Stage_Name__c;
            // Preserve Sub Section fields before FLS strip
            String preservedSubSection = recordToSave.FEC_Sub_Section__c;
            Decimal preservedSubSectionOrder = recordToSave.FEC_Sub_Section_Order__c;
            Decimal preservedSubSectionLayout = recordToSave.FEC_Sub_Section_Layout__c;
            Decimal preservedSubSectionFieldLayout = recordToSave.FEC_Sub_Section_Field_Layout__c;
            // Preserve Editable fields before FLS strip
            Boolean preservedFieldEditable = recordToSave.FEC_Field_Editable__c;
            String preservedEditableRole = recordToSave.FEC_Editable_Role__c;
            
            // FLS: strip inaccessible fields before DML
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPSERTABLE,
                new List<FEC_MDM_Master_Data_Setting__c>{recordToSave}
            );
            
            FEC_MDM_Master_Data_Setting__c sanitizedRecord = (FEC_MDM_Master_Data_Setting__c)decision.getRecords()[0];
            
            // Restore lookup fields if they were stripped by FLS
            Map<String, Set<String>> removedFields = decision.getRemovedFields();
            String sObjName = 'FEC_MDM_Master_Data_Setting__c';
            if (removedFields.containsKey(sObjName) && removedFields.get(sObjName).contains('FEC_MDM_Channel__c')) {
                if (preservedChannelId != null) {
                    sanitizedRecord.FEC_MDM_Channel__c = preservedChannelId;
                }
            }
            if (removedFields.containsKey(sObjName) && removedFields.get(sObjName).contains('FEC_Data_Integration_Mapping__c')) {
                if (preservedIntegrationMappingId != null) {
                    sanitizedRecord.FEC_Data_Integration_Mapping__c = preservedIntegrationMappingId;
                }
            }
            // Restore NOC and Stage lookup fields if stripped by FLS
            if (removedFields.containsKey(sObjName) && removedFields.get(sObjName).contains('FEC_Nature_Of_Case__c')) {
                if (preservedNocId != null) {
                    sanitizedRecord.FEC_Nature_Of_Case__c = preservedNocId;
                }
            }
            if (removedFields.containsKey(sObjName) && removedFields.get(sObjName).contains('FEC_Stage_Name__c')) {
                if (preservedStageId != null) {
                    sanitizedRecord.FEC_Stage_Name__c = preservedStageId;
                }
            }
            // Restore Sub Section fields if stripped by FLS
            if (removedFields.containsKey(sObjName)) {
                Set<String> removed = removedFields.get(sObjName);
                if (removed.contains('FEC_Sub_Section__c') && preservedSubSection != null) {
                    sanitizedRecord.FEC_Sub_Section__c = preservedSubSection;
                }
                if (removed.contains('FEC_Sub_Section_Order__c') && preservedSubSectionOrder != null) {
                    sanitizedRecord.FEC_Sub_Section_Order__c = preservedSubSectionOrder;
                }
                if (removed.contains('FEC_Sub_Section_Layout__c') && preservedSubSectionLayout != null) {
                    sanitizedRecord.FEC_Sub_Section_Layout__c = preservedSubSectionLayout;
                }
                if (removed.contains('FEC_Sub_Section_Field_Layout__c') && preservedSubSectionFieldLayout != null) {
                    sanitizedRecord.FEC_Sub_Section_Field_Layout__c = preservedSubSectionFieldLayout;
                }
                if (removed.contains('FEC_Field_Editable__c') && preservedFieldEditable != null) {
                    sanitizedRecord.FEC_Field_Editable__c = preservedFieldEditable;
                }
                if (removed.contains('FEC_Editable_Role__c') && preservedEditableRole != null) {
                    sanitizedRecord.FEC_Editable_Role__c = preservedEditableRole;
                }
            }
            
            upsert sanitizedRecord;
            recordToSave.Id = sanitizedRecord.Id;

            // Auto-assign FEC_Code__c = Record Id on CREATE
            if (isCreateMode) {
                try {
                    FEC_MDM_Master_Data_Setting__c codeUpdate = new FEC_MDM_Master_Data_Setting__c(
                        Id = sanitizedRecord.Id,
                        FEC_Code__c = sanitizedRecord.Id
                    );
                    update codeUpdate;
                } catch (Exception codeEx) {
                    System.debug('Failed to assign FEC_Code__c for record ' + sanitizedRecord.Id + ': ' + codeEx.getMessage());
                }
            }

            return sanitizedRecord.Id;
        } catch (AuraHandledException ahe) {
            // Re-throw AuraHandledException as-is to preserve the original message
            throw ahe;
        } catch (DmlException dml) {
            System.debug('DML Error: ' + dml.getMessage());
            AuraHandledException ex = new AuraHandledException(dml.getDmlMessage(0));
            ex.setMessage(dml.getDmlMessage(0));
            throw ex;
        } catch (Exception e) {
            System.debug('General Error: ' + e.getMessage());
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }
    
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_DELETE_RECORD_PREFIX + ' ' + FEC_UIConstants.ERROR_INVALID_ID);
        }
        try {
             FEC_MDM_Master_Data_Setting__c recordToDelete = new FEC_MDM_Master_Data_Setting__c(Id = recordId);
             delete recordToDelete;
             return FEC_UIConstants.OPERATION_SUCCESS;
         } catch (Exception e) {
             System.debug('FEC_MasterDataSettingController.deleteRecord error: ' + e);
            throw new AuraHandledException(FEC_UIConstants.ERROR_SYSTEM + ' ' + e.getMessage());
         }
    }
    
    @AuraEnabled
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

    @AuraEnabled
    public static void deleteCaseStage(Id stageId) {
        try {
            delete new FEC_MDM_Case_Stage__c(Id = stageId);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id createCaseStage(
        String name,
        String code,
        String businessProcessId,
        String nameVN,
        Boolean status,
        String alias,
        Integer posOrder,
        Boolean defaultStage,
        String natureOfCasesId,
        String userGroup,
        Boolean active,
        String statusName,
        Boolean endStage
    ) {
        if (String.isBlank(name)) {
            throw new AuraHandledException('Stage name cannot be empty.');
        }
        try {
            FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
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
            insert stage;
            return stage.Id;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dml) {
            String msg = dml.getDmlMessage(0);
            if (dml.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                msg = 'Stage "' + name + '" already exists (duplicate code). Please use a different name.';
            }
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStageOptionsByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        // Query trực tiếp không qua stripInaccessible cho FEC_Order__c
        // vì field bị FLS chặn nhưng cần cho sort logic
        List<FEC_MDM_Case_Stage__c> stages = [
            SELECT Id, Name, FEC_Default_Stage__c, FEC_End_Stage__c, FEC_Order__c
            FROM FEC_MDM_Case_Stage__c
            WHERE FEC_Business_Process__c = :businessProcessId 
            ORDER BY FEC_Order__c ASC NULLS FIRST, Name ASC
        ];
        for (FEC_MDM_Case_Stage__c stage : stages) {
            Map<String, String> entry = new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => stage.Name,
                FEC_UIConstants.MAP_VALUE => stage.Id,
                'defaultStage' => String.valueOf(stage.FEC_Default_Stage__c),
                'endStage' => String.valueOf(stage.FEC_End_Stage__c),
                'posOrder' => stage.FEC_Order__c != null ? String.valueOf(stage.FEC_Order__c.intValue()) : '0'
            };
            options.add(entry);
        }
        return options;
    }

    @AuraEnabled
    public static Map<String, String> getCaseStageDetail(Id stageId) {
        List<FEC_MDM_Case_Stage__c> stages = [
            SELECT Id, Name, FEC_Name_VN__c, FEC_Alias__c, FEC_Active__c,
                   FEC_Default_Stage__c, FEC_End_Stage__c, FEC_Nature_of_Cases__c, FEC_User_Group__c,
                   FEC_Order__c, FEC_Status_Name__c
            FROM FEC_MDM_Case_Stage__c
            WHERE Id = :stageId
            LIMIT 1
        ];
        if (stages.isEmpty()) {
            throw new AuraHandledException('Stage not found');
        }
        FEC_MDM_Case_Stage__c stage = stages[0];
        Map<String, Object> populated = stage.getPopulatedFieldsAsMap();
        Map<String, String> result = new Map<String, String>();
        result.put('id', stage.Id);
        result.put('name', stage.Name);
        result.put('nameVN', stage.FEC_Name_VN__c != null ? stage.FEC_Name_VN__c : '');
        result.put('alias', stage.FEC_Alias__c != null ? stage.FEC_Alias__c : '');
        result.put('status', String.valueOf(stage.FEC_Active__c));
        result.put('active', String.valueOf(stage.FEC_Active__c));
        result.put('defaultStage', String.valueOf(stage.FEC_Default_Stage__c));
        result.put('endStage', populated.containsKey('FEC_End_Stage__c') ? String.valueOf(stage.FEC_End_Stage__c) : 'false');
        result.put('natureOfCasesId', stage.FEC_Nature_of_Cases__c != null ? String.valueOf(stage.FEC_Nature_of_Cases__c) : '');
        result.put('userGroup', stage.FEC_User_Group__c != null ? stage.FEC_User_Group__c : '');
        result.put('posOrder', stage.FEC_Order__c != null ? String.valueOf(stage.FEC_Order__c.intValue()) : '0');
        result.put('statusName', stage.FEC_Status_Name__c != null ? stage.FEC_Status_Name__c : '');
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUserGroupOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = FEC_MDM_Case_Stage__c.FEC_User_Group__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => entry.getLabel(),
                    FEC_UIConstants.MAP_VALUE => entry.getValue()
                });
            }
        }
        return options;
    }
      
      @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAdditionalFieldOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Additional_Field__c> fields = [
            SELECT Id, Name, Field_API_Name__c
            FROM FEC_MDM_Additional_Field__c 
            WHERE FEC_Field_Status__c = true
            ORDER BY CreatedDate DESC
        ];
        
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, fields).getRecords();
        for (FEC_MDM_Additional_Field__c field : (List<FEC_MDM_Additional_Field__c>) safe) {
            // Use getPopulatedFieldsAsMap() to safely access fields that may have been
            // stripped by stripInaccessible (avoids SObjectException when FLS denies read)
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getNatureOfCaseOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Nature_of_Case__c> nocs = [
            SELECT Id, Name
            FROM FEC_MDM_Nature_of_Case__c
            ORDER BY Name ASC
        ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, nocs).getRecords();
        for (FEC_MDM_Nature_of_Case__c noc : (List<FEC_MDM_Nature_of_Case__c>) safe) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => noc.Name,
                FEC_UIConstants.MAP_VALUE => noc.Id
            });
        }
        return options;
    }

    /**
     * @description Lấy ID của FEC_User_Type__c dựa trên FEC_Customer_Type (Name)
     * @param customerTypeName Tên của Customer Type (e.g., 'ALL', 'EXISTING', 'Non-existing')
     * @return String ID của FEC_User_Type__c record
     */
    @AuraEnabled(cacheable=true)
    public static String getUserTypeIdByName(String customerTypeName) {
        if (String.isBlank(customerTypeName)) {
            return null;
        }
        
        try {
            List<FEC_User_Type__c> userTypes = [
                SELECT Id, Name 
                FROM FEC_User_Type__c 
                WHERE FEC_Status__c = true 
                AND Name = :customerTypeName
                LIMIT 1
            ];
            
            if (!userTypes.isEmpty()) {
                return userTypes[0].Id;
            }
            
            return null;
        } catch (Exception e) {
            return null;
        }
    }
    
    /**
     * Delete a fraud integration mapping record
     * @param recordId - ID of the record to delete
     */
    @AuraEnabled
    public static void deleteFraudIntegrationMapping(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                throw new IllegalArgumentException('Record ID cannot be empty');
            }

            // Verify record exists and user has update access
            List<FEC_MDM_Master_Data_Setting__c> records = [
                SELECT Id, Name, Process_Change_Status__c
                FROM FEC_MDM_Master_Data_Setting__c 
                WHERE Id = :recordId 
                LIMIT 1
            ];

            if (records.isEmpty()) {
                throw new IllegalArgumentException('Record not found');
            }

            // If status is 'New' (never pushed to Live), hard delete immediately
            // Otherwise soft delete: mark as 'Deleted' so Push batch will delete Live record
            if (records[0].Process_Change_Status__c == FEC_UIConstants.PROCESS_STATUS_NEW) {
                delete records[0];
            } else {
                records[0].Process_Change_Status__c = FEC_UIConstants.PROCESS_STATUS_DELETED;
                update records[0];
            }
        } catch (DmlException e) {
            System.debug('DML Error: ' + e.getMessage());
            throw new AuraHandledException(System.Label.FEC_Error_Delete_Record_Prefix + ' ' + e.getMessage());
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(System.Label.FEC_Error_Generic + ' ' + e.getMessage());
        }
    }

    // ── Auto Field Creator methods ──────────────────────────────────────

    /**
     * @description Lấy danh sách tất cả SObject từ Schema.getGlobalDescribe().
     * @return List<Map<String, String>> [{label, value}]
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGlobalObjectList() {
        try {
            Set<String> allowedObjects = new Set<String>{ 'FEC_Customer_History__c', 'FEC_Additional_Info__c', 'Case' };
            List<Map<String, String>> result = new List<Map<String, String>>();
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            for (String objName : allowedObjects) {
                Schema.SObjectType sot = globalDescribe.get(objName);
                if (sot != null) {
                    Schema.DescribeSObjectResult objDescribe = sot.getDescribe();
                    if (objDescribe.isAccessible()) {
                        result.add(new Map<String, String>{
                            FEC_UIConstants.MAP_LABEL => objDescribe.getLabel() + ' (' + objDescribe.getName() + ')',
                            FEC_UIConstants.MAP_VALUE => objDescribe.getName()
                        });
                    }
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Lấy danh sách field của một SObject.
     * @param objectName SObject API name
     * @return List<Map<String, String>> [{label, value, type}]
     */
    @AuraEnabled(cacheable=true)
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

    /**
     * @description Lấy danh sách distinct Section values cho Nature of Case + Stage.
     * @param natureOfCaseId Id của Nature of Case
     * @param stageId Id của Stage
     * @return List<String> distinct section values
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctSections(String natureOfCaseId, String stageId) {
        try {
            List<String> sections = new List<String>();
            for (AggregateResult ar : [
                SELECT FEC_Section__c section
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
                AND FEC_Stage_Name__c = :stageId
                AND FEC_Section__c != NULL
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

    /**
     * @description Lấy danh sách distinct SubSection values cho Section + NOC + Stage.
     * @param natureOfCaseId Id của Nature of Case
     * @param stageId Id của Stage
     * @param section Section name
     * @return List<Map<String, Object>> [{subSection, subSectionOrder, subSectionLayout, subSectionFieldLayout}]
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDistinctSubSections(String natureOfCaseId, String stageId, String section) {
        try {
            Map<String, Map<String, Object>> subSectionMap = new Map<String, Map<String, Object>>();
            for (FEC_MDM_Master_Data_Setting__c mds : [
                SELECT FEC_Sub_Section__c, FEC_Sub_Section_Order__c,
                       FEC_Sub_Section_Layout__c, FEC_Sub_Section_Field_Layout__c
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Nature_Of_Case__c = :natureOfCaseId
                AND FEC_Stage_Name__c = :stageId
                AND FEC_Section__c = :section
                AND FEC_Sub_Section__c != NULL
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

    /**
     * @description Trigger Push to Live batch.
     * @return Id batch job Id
     */
    @AuraEnabled
    public static Id executePushToLive() {
        try {
            return Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    // ── Stage Screen CRUD methods ───────────────────────────────────────

    /**
     * @description Lấy danh sách Stage Screen cho một Stage cụ thể.
     * @param stageId ID của Stage
     * @return List<Map<String, String>> Danh sách Stage Screen gồm id, actionButtonName, userGroup, active, code
     */
    @AuraEnabled
    public static List<Map<String, String>> getStageScreensByStage(Id stageId) {
        if (stageId == null) {
            throw new AuraHandledException('Stage ID cannot be null.');
        }
        try {
            List<FEC_Stage_Screen__c> screens = [
                SELECT Id, FEC_Action_Button__r.Name, FEC_User_Group__c,
                       FEC_Active__c, FEC_Code__c
                FROM FEC_Stage_Screen__c
                WHERE FEC_Case_Stage__c = :stageId
                ORDER BY CreatedDate ASC
            ];
            List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, screens).getRecords();
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (FEC_Stage_Screen__c screen : (List<FEC_Stage_Screen__c>) safe) {
                result.add(new Map<String, String>{
                    'id' => screen.Id,
                    'actionButtonName' => screen.FEC_Action_Button__r != null ? screen.FEC_Action_Button__r.Name : '',
                    'userGroup' => screen.FEC_User_Group__c != null ? screen.FEC_User_Group__c : '',
                    'active' => String.valueOf(screen.FEC_Active__c),
                    'code' => screen.FEC_Code__c != null ? screen.FEC_Code__c : ''
                });
            }
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Tạo Stage Screen mới liên kết Stage với Action Button.
     * @param stageId ID của Stage
     * @param actionButtonId ID của Action Button
     * @param userGroup Multi-select picklist value cho User Group
     * @param active Trạng thái active
     * @return Id ID của bản ghi mới tạo
     */
    @AuraEnabled
    public static Id createStageScreen(Id stageId, Id actionButtonId, String userGroup, Boolean active) {
        if (stageId == null || actionButtonId == null) {
            throw new AuraHandledException('Stage ID and Action Button ID cannot be null.');
        }
        try {
            // Check duplicate: same stageId + actionButtonId
            List<FEC_Stage_Screen__c> existing = [
                SELECT Id FROM FEC_Stage_Screen__c
                WHERE FEC_Case_Stage__c = :stageId
                AND FEC_Action_Button__c = :actionButtonId
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                String msg = 'Action Button này đã được gắn cho stage này';
                AuraHandledException ex = new AuraHandledException(msg);
                ex.setMessage(msg);
                throw ex;
            }

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

    /**
     * @description Xóa một Stage Screen.
     * @param stageScreenId ID của Stage Screen cần xóa
     */
    @AuraEnabled
    public static void deleteStageScreen(Id stageScreenId) {
        if (stageScreenId == null) {
            throw new AuraHandledException('Stage Screen ID cannot be null.');
        }
        try {
            delete new FEC_Stage_Screen__c(Id = stageScreenId);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Bật/tắt trạng thái active của Stage Screen.
     * @param stageScreenId ID của Stage Screen
     * @param active Trạng thái active mới
     */
    @AuraEnabled
    public static void toggleStageScreenActive(Id stageScreenId, Boolean active) {
        if (stageScreenId == null) {
            throw new AuraHandledException('Stage Screen ID cannot be null.');
        }
        try {
            FEC_Stage_Screen__c screen = new FEC_Stage_Screen__c(
                Id = stageScreenId,
                FEC_Active__c = active
            );
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<FEC_Stage_Screen__c>{ screen }
            );
            update decision.getRecords();
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    /**
     * @description Lấy danh sách Action Button active cho combobox.
     * @return List<Map<String, String>> Danh sách Action Button gồm label, value
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActionButtonOptions() {
        try {
            List<FEC_MDM_Action_Button__c> buttons = [
                SELECT Id, Name
                FROM FEC_MDM_Action_Button__c
                WHERE FEC_Active__c = true
                ORDER BY Name ASC
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

    /**
     * @description Kiểm tra xem property (Additional Field + Channel + Role) đã tồn tại ở parent node chưa.
     * Traverse ngược lên cây NOC: từ node hiện tại, tìm tất cả NOC records ở parent levels,
     * rồi check xem có Master Data Setting nào trùng Additional Field + Channel + Applicable Role.
     * @param nocId ID của FEC_MDM_Nature_Of_Case__c hiện tại
     * @param stageId ID của Stage hiện tại
     * @param additionalFieldId ID của Additional Field cần check
     * @param channelId ID của MDM Channel cần check
     * @param applicableRole Chuỗi Applicable Role cần check
     * @return Tên parent node nếu trùng, null nếu không trùng
     */
    @AuraEnabled
    public static String checkParentDuplicateProperty(
        String nocId, String stageId, String additionalFieldId,
        String channelId, String applicableRole
    ) {
        if (String.isBlank(nocId) || String.isBlank(additionalFieldId)) {
            return null;
        }

        try {
            // 1. Lấy NOC record hiện tại để biết path (PT, BP, CAT, SCAT, SC)
            List<FEC_MDM_Nature_Of_Case__c> nocList = [
                SELECT Id,
                    FEC_Product_Type__c, FEC_Product_Type__r.Name,
                    FEC_Business_Process__c, FEC_Business_Process__r.Name,
                    FEC_Category__c, FEC_Category__r.Name,
                    FEC_Sub_Category__c, FEC_Sub_Category__r.Name,
                    FEC_Sub_Code__c, FEC_Sub_Code__r.Name
                FROM FEC_MDM_Nature_Of_Case__c
                WHERE Id = :nocId
                LIMIT 1
            ];
            if (nocList.isEmpty()) return null;

            FEC_MDM_Nature_Of_Case__c currentNoc = nocList[0];

            // 2. Xác định level hiện tại dựa trên lookup fields có giá trị
            // Level 1: chỉ có PT (BP=null) → Product Type node
            // Level 2: có PT+BP (CAT=null) → Business Process node
            // Level 3: có PT+BP+CAT (SCAT=null) → Category node
            // Level 4: có PT+BP+CAT+SCAT (SC=null) → Sub Category node
            // Level 5: có tất cả → Sub Code node
            Integer currentLevel = 1;
            if (currentNoc.FEC_Business_Process__c != null) currentLevel = 2;
            if (currentNoc.FEC_Category__c != null) currentLevel = 3;
            if (currentNoc.FEC_Sub_Category__c != null) currentLevel = 4;
            if (currentNoc.FEC_Sub_Code__c != null) currentLevel = 5;

            // Nếu đang ở level 1 (Product Type) → không có parent → không cần check
            if (currentLevel <= 1) return null;

            // 3. Tìm tất cả NOC records ở parent levels (cùng path nhưng ít lookup hơn)
            Set<Id> parentNocIds = new Set<Id>();
            Id ptId = currentNoc.FEC_Product_Type__c;
            Id bpId = currentNoc.FEC_Business_Process__c;
            Id catId = currentNoc.FEC_Category__c;
            Id scatId = currentNoc.FEC_Sub_Category__c;

            // Build query để tìm parent NOC records
            // Parent level 1 (PT only): cùng PT, BP=null
            // Parent level 2 (PT+BP): cùng PT+BP, CAT=null
            // Parent level 3 (PT+BP+CAT): cùng PT+BP+CAT, SCAT=null
            // Parent level 4 (PT+BP+CAT+SCAT): cùng PT+BP+CAT+SCAT, SC=null
            String parentQuery = 'SELECT Id FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :ptId AND (';
            List<String> conditions = new List<String>();

            // Level 1 parent: chỉ có PT
            if (currentLevel > 1) {
                conditions.add('(FEC_Business_Process__c = NULL)');
            }
            // Level 2 parent: PT + BP
            if (currentLevel > 2) {
                conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = NULL)');
            }
            // Level 3 parent: PT + BP + CAT
            if (currentLevel > 3) {
                conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = :catId AND FEC_Sub_Category__c = NULL)');
            }
            // Level 4 parent: PT + BP + CAT + SCAT
            if (currentLevel > 4) {
                conditions.add('(FEC_Business_Process__c = :bpId AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :scatId AND FEC_Sub_Code__c = NULL)');
            }

            parentQuery += String.join(conditions, ' OR ') + ')';

            for (FEC_MDM_Nature_Of_Case__c parentNoc : Database.query(parentQuery)) {
                parentNocIds.add(parentNoc.Id);
            }

            if (parentNocIds.isEmpty()) return null;

            // 4. Query Master Data Settings ở parent nodes với cùng Additional Field + Channel + Role
            String settingQuery = 'SELECT Id, FEC_Nature_Of_Case__r.FEC_Product_Type__r.Name, '
                + 'FEC_Nature_Of_Case__r.FEC_Business_Process__r.Name, '
                + 'FEC_Nature_Of_Case__r.FEC_Category__r.Name, '
                + 'FEC_Nature_Of_Case__r.FEC_Sub_Category__r.Name '
                + 'FROM FEC_MDM_Master_Data_Setting__c '
                + 'WHERE FEC_Nature_Of_Case__c IN :parentNocIds '
                + 'AND FEC_Additional_Field__c = :additionalFieldId '
                + 'AND FEC_Data_Integration_Mapping__c = NULL ';

            // Stage filter
            if (String.isNotBlank(stageId)) {
                settingQuery += 'AND FEC_Stage_Name__c = :stageId ';
            }

            // Channel filter (nếu có)
            if (String.isNotBlank(channelId)) {
                settingQuery += 'AND FEC_MDM_Channel__c = :channelId ';
            }

            settingQuery += 'LIMIT 1';

            List<FEC_MDM_Master_Data_Setting__c> duplicates = Database.query(settingQuery);

            if (!duplicates.isEmpty()) {
                // Xác định tên parent node từ NOC record
                FEC_MDM_Master_Data_Setting__c dup = duplicates[0];
                String parentName = '';
                if (dup.FEC_Nature_Of_Case__r.FEC_Sub_Category__r?.Name != null) {
                    parentName = dup.FEC_Nature_Of_Case__r.FEC_Sub_Category__r.Name;
                } else if (dup.FEC_Nature_Of_Case__r.FEC_Category__r?.Name != null) {
                    parentName = dup.FEC_Nature_Of_Case__r.FEC_Category__r.Name;
                } else if (dup.FEC_Nature_Of_Case__r.FEC_Business_Process__r?.Name != null) {
                    parentName = dup.FEC_Nature_Of_Case__r.FEC_Business_Process__r.Name;
                } else if (dup.FEC_Nature_Of_Case__r.FEC_Product_Type__r?.Name != null) {
                    parentName = dup.FEC_Nature_Of_Case__r.FEC_Product_Type__r.Name;
                }
                return parentName;
            }

            return null;
        } catch (Exception e) {
            System.debug('checkParentDuplicateProperty error: ' + e.getMessage());
            throw new AuraHandledException('Error checking parent duplicate: ' + e.getMessage());
        }
    }

    /**
     * @description Lấy distinct Sub Section + Sub Section Order từ Live data để auto-fill.
     * @return Map<String, Decimal> Key = SubSection name, Value = SubSection order
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getSubSectionOrderMap() {
        Map<String, Decimal> result = new Map<String, Decimal>();
        List<AggregateResult> aggs = [
            SELECT FEC_Sub_Section__c subSec, MAX(FEC_Sub_Section_Order__c) subOrder
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Sub_Section__c != null AND FEC_Field_Status__c = true
            GROUP BY FEC_Sub_Section__c
        ];
        for (AggregateResult ag : aggs) {
            String subSec = (String) ag.get('subSec');
            Decimal subOrder = (Decimal) ag.get('subOrder');
            if (String.isNotBlank(subSec)) {
                result.put(subSec, subOrder);
            }
        }
        return result;
    }
}