/**
 * @description Controller để xử lý logic truy vấn dữ liệu từ FEC_MDM_Master_Data_Setting__c.
 * Đóng vai trò là nơi cung cấp dữ liệu cấu hình (Settings) cho LWC.
 * @date 2025-12-03
 * @author DAT NGO
 */
public with sharing class FEC_MasterDataSettingController {
    
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
            'FEC_Additional_Field__r.Name','FEC_Stage_Name__r.Name','FEC_Nature_Of_Case__r.Name','FEC_Channel__c','FEC_Case_Channel__r.Name'
        };

        String baseQuery = 'SELECT ' + String.join(fields, ', ') + ' FROM FEC_MDM_Master_Data_Setting__c WHERE FEC_Nature_Of_Case__c = :selectedNodeId ';
        if (String.isNotBlank(selectedStageId)) {
            baseQuery += ' AND FEC_Stage_Name__c = :selectedStageId ';
        }
        if (isIntegration != null) {
            baseQuery += isIntegration ? ' AND FEC_Data_Integration_Mapping__c != NULL ' : ' AND FEC_Data_Integration_Mapping__c = NULL ';
        }

        String finalQuery = baseQuery + ' ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC';
        
        List<FEC_MDM_Master_Data_Setting__c> settings = Database.query(finalQuery + ' LIMIT ' + String.valueOf(FEC_Constants.QUERY_LIMIT));
        // Enforce FLS
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, settings).getRecords();
        return (List<FEC_MDM_Master_Data_Setting__c>) safe;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannels() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Channel__c> channels = [SELECT Name FROM FEC_MDM_Channel__c ORDER BY Name LIMIT :FEC_Constants.QUERY_LIMIT];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, channels).getRecords();
        for (FEC_MDM_Channel__c c : (List<FEC_MDM_Channel__c>) safe) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => c.Name, FEC_Constants.MAP_VALUE => c.Name});
        }
        return options;
     }
     
     @AuraEnabled(cacheable=true)
     public static List<Map<String, String>> getUserRoles() {
         List<Map<String, String>> options = new List<Map<String, String>>();
         List<UserRole> roles = [SELECT Name FROM UserRole ORDER BY Name LIMIT :FEC_Constants.QUERY_LIMIT];
         List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, roles).getRecords();
         for (UserRole r : (List<UserRole>) safe) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => r.Name, FEC_Constants.MAP_VALUE => r.Name});
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
        options.add(new Map<String, Object>{FEC_Constants.MAP_LABEL => FEC_Constants.LABEL_NONE, FEC_Constants.MAP_VALUE => ''});
        List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name 
        FROM FEC_Case_Stage__c 
        WITH SECURITY_ENFORCED 
        ORDER BY Name ASC
    LIMIT :FEC_Constants.QUERY_LIMIT
    ];
        for (FEC_Case_Stage__c stage : stages) {
            options.add(new Map<String, Object>{
                FEC_Constants.MAP_LABEL => stage.Name,
                FEC_Constants.MAP_VALUE => stage.Id
            });
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLookupOptions(String sObjectName) {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        options.add(new Map<String, Object>{FEC_Constants.MAP_LABEL => FEC_Constants.LABEL_NONE, FEC_Constants.MAP_VALUE => ''});
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectName);
        if (targetType == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_INVALID_SOBJECT_PREFIX + sObjectName);
        }
        String query = 'SELECT Id, Name FROM ' + sObjectName + ' WITH SECURITY_ENFORCED ORDER BY Name ASC LIMIT ' + String.valueOf(FEC_Constants.QUERY_LIMIT);
        List<SObject> records = Database.query(query);
        for (SObject rec : records) {
            options.add(new Map<String, Object>{FEC_Constants.MAP_LABEL => (String)rec.get('Name'), FEC_Constants.MAP_VALUE => (String)rec.get('Id')});
        }
        return options;
    }
    
    private static String getOptionalId(Map<String, Object> mappingReq, String fieldName) {
        String value = (String)mappingReq.get(fieldName);
        return String.isNotBlank(value) ? value : null;
    }
    
    @AuraEnabled
    public static Id saveMasterDataSetting(Map<String, Object> mappingReq) {
        System.debug('--- START saveMasterDataSetting ---');
        String recordId = (String)mappingReq.get(FEC_Constants.FIELD_ID);
        FEC_MDM_Master_Data_Setting__c recordToSave = String.isNotBlank(recordId)
            ? new FEC_MDM_Master_Data_Setting__c(Id = recordId)
            : new FEC_MDM_Master_Data_Setting__c();
        try {
            if (String.isBlank(recordId)) {
                recordToSave.Process_Change_Status__c = FEC_Constants.PROCESS_STATUS_NEW;
                recordToSave.FEC_Nature_Of_Case__c = getOptionalId(mappingReq, FEC_Constants.FIELD_NATURE_OF_CASE);
                recordToSave.FEC_Stage_Name__c = getOptionalId(mappingReq, FEC_Constants.FIELD_STAGE_NAME);
                recordToSave.FEC_Field_Mandatory__c = (Boolean)mappingReq.get(FEC_Constants.FIELD_FIELD_MANDATORY);
                recordToSave.FEC_Field_ReadOnly__c = (Boolean)mappingReq.get(FEC_Constants.FIELD_FIELD_READONLY);
                recordToSave.FEC_Section__c = (String)mappingReq.get(FEC_Constants.FIELD_SECTION);
                recordToSave.FEC_Field_Object_Name__c = (String)mappingReq.get(FEC_Constants.FIELD_FIELD_OBJECT_NAME);
                recordToSave.FEC_Additional_Field__c = (String)mappingReq.get(FEC_Constants.FIELD_ADDITIONAL_FIELD);
                recordToSave.FEC_Applicable_Role__c = getOptionalId(mappingReq, FEC_Constants.FIELD_APPLICABLE_ROLE);
                recordToSave.FEC_Field_ReadOnly__c = (Boolean)mappingReq.get(FEC_Constants.FIELD_FIELD_READONLY);
                recordToSave.FEC_Channel__c = getOptionalId(mappingReq, FEC_Constants.FIELD_CHANNEL);
                recordToSave.FEC_Case_Channel__c = getOptionalId(mappingReq, FEC_Constants.FIELD_CASE_CHANNEL);
                recordToSave.FEC_Data_Integration_Mapping__c = getOptionalId(mappingReq, FEC_Constants.FIELD_DATA_INTEGRATION_MAPPING);
                Object orderValue = mappingReq.get(FEC_Constants.FIELD_FIELD_ORDER_DISPLAY);
                recordToSave.FEC_Field_Order_Display__c = (orderValue != null)
                    ? Integer.valueOf(String.valueOf(orderValue)) : null;
            }
            if (mappingReq.containsKey(FEC_Constants.FIELD_FIELD_STATUS)) {
                recordToSave.FEC_Field_Status__c = (Boolean)mappingReq.get(FEC_Constants.FIELD_FIELD_STATUS);
            }
            upsert recordToSave;
            System.debug('--- END saveMasterDataSetting Success: ' + recordToSave.Id + ' ---');
            return recordToSave.Id;
        } catch (DmlException dml) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_DELETE_RECORD_PREFIX + ' ' + FEC_Constants.ERROR_INVALID_ID);
        }
        try {
             FEC_MDM_Master_Data_Setting__c recordToDelete = new FEC_MDM_Master_Data_Setting__c(Id = recordId);
             delete recordToDelete;
             return FEC_Constants.OPERATION_SUCCESS;
         } catch (Exception e) {
             System.debug('FEC_MasterDataSettingController.deleteRecord error: ' + e);
            throw new AuraHandledException(FEC_Constants.ERROR_SYSTEM + ' ' + e.getMessage());
         }
    }
    
    @AuraEnabled
    public static Id createCaseStage(
        String name,
    String code,
    String businessProcessId,
    String nameVN,
    Boolean status, // Đổi sang Boolean vì JS gửi true/false
    String alias,
    Integer posOrder // Đổi từ String sang Integer
    ) {
        try {
            FEC_MDM_Case_Stage__c stage = new FEC_MDM_Case_Stage__c(
                Name = name,
            FEC_Code__c = code,
            FEC_Business_Process__c = businessProcessId,
            FEC_Name_VN__c = nameVN,
            FEC_Status__c = status,
            FEC_Alias__c = alias,
            FEC_Pos_Order__c = posOrder
                );
            insert stage;
            return stage.Id;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStageOptionsByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<FEC_MDM_Case_Stage__c> stages = [
        SELECT Id, Name 
        FROM FEC_MDM_Case_Stage__c
        WHERE FEC_Business_Process__c = :businessProcessId 
        ORDER BY FEC_Pos_Order__c ASC
        LIMIT :FEC_Constants.QUERY_LIMIT
    ];
        List<SObject> safe = Security.stripInaccessible(AccessType.READABLE, stages).getRecords();
        for (FEC_MDM_Case_Stage__c stage : (List<FEC_MDM_Case_Stage__c>) safe) {
            options.add(new Map<String, String>{
                FEC_Constants.MAP_LABEL => stage.Name,
                FEC_Constants.MAP_VALUE => stage.Id
            });
        }
         return options;
     }
 }
