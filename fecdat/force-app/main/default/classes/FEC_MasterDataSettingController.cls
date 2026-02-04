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
        
        String query = 'SELECT ' +
            'Id, Name, ' +
            'FEC_Section__c, ' +
            'FEC_Field_Status__c, ' +
            'FEC_Field_ReadOnly__c, ' +
            'FEC_Field_Order_Display__c, ' +
            'FEC_Field_Object_Name__c, ' +
            'FEC_Field_Mandatory__c, ' +
        'FEC_Applicable_Role__c, ' +
            'Process_Change_Status__c, ' +
        'FEC_Data_Integration_Mapping__c, ' + // ID của Mapping Fraud
            
        // Các trường quan hệ (Parent Fields)
        'FEC_Additional_Field__r.Name, ' +
            'FEC_Stage_Name__r.Name, ' +
            'FEC_Nature_Of_Case__r.Name, ' +
            'FEC_Channel__c, ' +
            'FEC_Case_Channel__r.Name ' +
            'FROM FEC_MDM_Master_Data_Setting__c ' +
            'WHERE FEC_Nature_Of_Case__c = :selectedNodeId ';
        
        // Lọc theo Stage nếu có truyền vào
        if (String.isNotBlank(selectedStageId)) {
            query += ' AND FEC_Stage_Name__c = :selectedStageId ';
        }
        
        // PHÂN LOẠI TAB:
        // Nếu isIntegration = true -> Lấy những record có gắn với Fraud Mapping
        // Nếu isIntegration = false -> Lấy những record cấu hình Property thông thường
        if (isIntegration != null) {
            if (isIntegration) {
                query += ' AND FEC_Data_Integration_Mapping__c != NULL ';
            } else {
                query += ' AND FEC_Data_Integration_Mapping__c = NULL ';
            }
        }
        
        query += ' ORDER BY FEC_Field_Order_Display__c ASC NULLS LAST, Name ASC LIMIT 500';
        
        List<FEC_MDM_Master_Data_Setting__c> settings = Database.query(query);
        
        return settings;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getChannels() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (FEC_MDM_Channel__c c : [SELECT Name FROM FEC_MDM_Channel__c ORDER BY Name]) {
            options.add(new Map<String, String>{'label' => c.Name, 'value' => c.Name});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getUserRoles() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (UserRole r : [SELECT Name FROM UserRole ORDER BY Name]) {
            options.add(new Map<String, String>{'label' => r.Name, 'value' => r.Name});
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
        
        // Thêm tùy chọn trống (None) để người dùng có thể chọn bỏ trống
        options.add(new Map<String, Object>{'label' => '-- None --', 'value' => ''});
        
        // Truy vấn các bản ghi Stage (chỉ khoảng 5 bản ghi nên truy vấn này là hiệu quả)
        List<FEC_Case_Stage__c> stages = [
        SELECT Id, Name 
        FROM FEC_Case_Stage__c 
        WITH SECURITY_ENFORCED 
        ORDER BY Name ASC
    ];
        
        // Chuyển đổi sang định dạng Combobox: {label: Name, value: Id}
        for (FEC_Case_Stage__c stage : stages) {
            options.add(new Map<String, Object>{
                'label' => stage.Name,
                'value' => stage.Id // Giá trị là ID của bản ghi Lookup
            });
        }
        return options;
    }
    
    /**
     * @description Hàm chung để lấy danh sách các tùy chọn Lookup từ bất kỳ Object nào có trường Name/Id.
     * @param sObjectName Tên API của Object (ví dụ: 'FEC_Case_Stage__c').
     * @return List<Map<String, Object>> Danh sách các tùy chọn dưới dạng {label: Name, value: Id}.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getLookupOptions(String sObjectName) {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        
        // Thêm tùy chọn trống (None)
        options.add(new Map<String, Object>{'label' => '-- None --', 'value' => ''});
        
        // 1. Kiểm tra tính hợp lệ của Object API Name
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(sObjectName);
        // 3. Tạo Dynamic SOQL Query
        String query = 'SELECT Id, Name FROM ' + sObjectName + ' WITH SECURITY_ENFORCED ORDER BY Name ASC';
        
        // 4. Thực thi Dynamic SOQL
        List<SObject> records = Database.query(query);
        
        // 5. Chuyển đổi sang định dạng Combobox
        for (SObject rec : records) {
            options.add(new Map<String, Object>{
                'label' => (String)rec.get('Name'),
                'value' => (String)rec.get('Id')
            });
        }
        return options;
    }
    
    /**
     * @description Hàm tiện ích để kiểm tra và trả về ID hoặc null.
     * @param mappingReq Map dữ liệu gửi từ LWC.
     * @param fieldName Tên trường Lookup cần kiểm tra.
     * @return String ID hợp lệ hoặc null.
     */
    private static String getOptionalId(Map<String, Object> mappingReq, String fieldName) {
        String value = (String)mappingReq.get(fieldName);
        // Trả về ID nếu nó không rỗng (và không null). Ngược lại, trả về null.
        return String.isNotBlank(value) ? value : null;
    }
    
    @AuraEnabled
    public static Id saveMasterDataSetting(Map<String, Object> mappingReq) {
        System.debug('--- START saveMasterDataSetting ---');
        
        String recordId = (String)mappingReq.get('Id');
        FEC_MDM_Master_Data_Setting__c recordToSave = String.isNotBlank(recordId)
            ? new FEC_MDM_Master_Data_Setting__c(Id = recordId)
            : new FEC_MDM_Master_Data_Setting__c();
        
        try {
            if (String.isBlank(recordId)) {
                recordToSave.Process_Change_Status__c = 'New';
                // Map thêm các trường bắt buộc cho bản ghi mới tại đây...
                recordToSave.FEC_Nature_Of_Case__c = getOptionalId(mappingReq, 'FEC_Nature_Of_Case__c');
                recordToSave.FEC_Stage_Name__c = getOptionalId(mappingReq, 'FEC_Stage_Name__c');
                recordToSave.FEC_Field_Mandatory__c = (Boolean)mappingReq.get('FEC_Field_Mandatory__c');
                recordToSave.FEC_Field_ReadOnly__c = (Boolean)mappingReq.get('FEC_Field_ReadOnly__c');
                recordToSave.FEC_Section__c = (String)mappingReq.get('FEC_Section__c');
                recordToSave.FEC_Field_Object_Name__c = (String)mappingReq.get('FEC_Field_Object_Name__c');
                recordToSave.FEC_Additional_Field__c = (String)mappingReq.get('FEC_Additional_Field__c');
                recordToSave.FEC_Applicable_Role__c = getOptionalId(mappingReq, 'FEC_Applicable_Role__c'); // <-- TRƯ
                recordToSave.FEC_Field_ReadOnly__c = (Boolean)mappingReq.get('FEC_Field_ReadOnly__c');
                recordToSave.FEC_Channel__c = getOptionalId(mappingReq, 'FEC_Channel__c');
                recordToSave.FEC_Case_Channel__c = getOptionalId(mappingReq, 'FEC_Case_Channel__c');
                recordToSave.FEC_Data_Integration_Mapping__c = getOptionalId(mappingReq, 'FEC_Data_Integration_Mapping__c');
                
                Object orderValue = mappingReq.get('FEC_Field_Order_Display__c');
                recordToSave.FEC_Field_Order_Display__c = (orderValue != null)
                    ? Integer.valueOf(String.valueOf(orderValue)) : null;
            }
            
            if (mappingReq.containsKey('FEC_Field_Status__c')) {
                recordToSave.FEC_Field_Status__c = (Boolean)mappingReq.get('FEC_Field_Status__c');
            }
            
            // 3. Thực hiện DML (Sử dụng insert khi đã xác định là Add mode)
            upsert recordToSave;
            System.debug('--- END saveMasterDataSetting Success: ' + recordToSave.Id + ' ---');
            return recordToSave.Id;
        } catch (DmlException dml) {
            throw new AuraHandledException('Lỗi DML saveMasterDataSetting cls: ' + dml.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi Chung Apex saveMasterDataSetting cls: ' + e.getMessage());
        }
    }
    
    /**
     * @description Xóa bản ghi Master Data Setting.
     * @param recordId ID của bản ghi cần xóa.
     * @return String 'Success' hoặc thông báo lỗi.
     */
    @AuraEnabled
    public static String deleteRecord(Id recordId) {
        FEC_MDM_Master_Data_Setting__c recordToDelete = new FEC_MDM_Master_Data_Setting__c(Id = recordId);
        delete recordToDelete;
        return 'Success';
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
            throw new AuraHandledException('Lỗi Apex: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCaseStageOptionsByBP(String businessProcessId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (FEC_MDM_Case_Stage__c stage : [
        SELECT Id, Name 
        FROM FEC_MDM_Case_Stage__c
        WHERE FEC_Business_Process__c = :businessProcessId 
        ORDER BY FEC_Pos_Order__c ASC
    ]) {
            options.add(new Map<String, String>{
                'label' => stage.Name,
                'value' => stage.Id
            });
        }
        return options;
    }
}
