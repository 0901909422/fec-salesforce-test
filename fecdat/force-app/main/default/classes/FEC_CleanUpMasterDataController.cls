public with sharing class FEC_CleanUpMasterDataController {
    // Mapping giữa Object Nguồn và Object MDM Đích
    private static final Map<String, String> SYNC_MAP = new Map<String, String>{
        'FEC_Product_Type__c' => 'FEC_MDM_Product_Type__c',
        'FEC_Business_Process__c' => 'FEC_MDM_Business_Process__c',
        'FEC_Category__c' => 'FEC_MDM_Category__c',
        'FEC_Sub_Category__c' => 'FEC_MDM_Sub_Category__c',
        'FEC_Sub_Code__c' => 'FEC_MDM_Sub_Code__c',
        'FEC_Master_Data_Setting__c' => 'FEC_MDM_Master_Data_Setting__c',
        'FEC_Nature_Of_Case__c' => 'FEC_MDM_Nature_Of_Case__c',
        'FEC_Additional_Field__c' => 'FEC_MDM_Additional_Field__c',
        'FEC_Additional_Field_List_Value__c' => 'FEC_MDM_Additional_Field_List_Value__c',
        'FEC_Case_Stage__c' => 'FEC_MDM_Case_Stage__c'
    };
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        
        try {
            // --- 5 Tabs cũ ---
            masterDataMap.put('ProductType', [SELECT Id, Name, ExternalID__c, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_Product_Type__c ORDER BY Name]);
            masterDataMap.put('BusinessProcess', [SELECT Id, Name, ExternalID__c, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_Business_Process__c ORDER BY Name]);
            masterDataMap.put('Category', [SELECT Id, Name, ExternalID__c, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_Category__c ORDER BY Name]);
            masterDataMap.put('SubCategory', [SELECT Id, Name, ExternalID__c, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_Sub_Category__c ORDER BY Name]);
            masterDataMap.put('SubCode', [SELECT Id, Name, ExternalID__c, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_Sub_Code__c ORDER BY Name]);

            // --- 4 Tabs mới thêm ---
            // 6. Master Data Setting
            masterDataMap.put('MasterSetting', [SELECT Id, Name, ExternalID__c, FEC_Additional_Field__c, FEC_Stage_Name__c, FEC_Channel__c, FEC_Applicable_Role__c, FEC_Data_Integration_Mapping__c, Process_Change_Status__c FROM FEC_Master_Data_Setting__c ORDER BY Name]);
            
            masterDataMap.put('Channel', [SELECT Id, Name, ExternalID__c, Process_Change_Status__c FROM FEC_Channel__c ORDER BY Name]);
            
            // 7. Nature Of Case (trả về wrapper)
            List<FEC_Nature_Of_Case__c> nocList = [
                SELECT Id, Name, ExternalID__c, FEC_Product_Type_Name__r.Name, FEC_Business_Process_Name__r.Name, 
                       FEC_Category_Name__r.Name, FEC_Sub_Category_Name__r.Name,FEC_Sub_Code__r.Name, Process_Change_Status__c 
                FROM FEC_Nature_Of_Case__c LIMIT 1000
            ];
            System.debug('NOC Wrapper List nocList: ' + nocList);
            List<NatureOfCaseWrapper> nocWrapperList = new List<NatureOfCaseWrapper>();
            for (FEC_Nature_Of_Case__c noc : nocList) {
                nocWrapperList.add(new NatureOfCaseWrapper(noc));
            }
            System.debug('NOC Wrapper List nocWrapperList: ' + nocWrapperList);
            masterDataMap.put('NatureOfCase', nocWrapperList);
            
            // 8. Additional Field
            masterDataMap.put('AdditionalField', [SELECT Id, Name, ExternalID__c, FEC_Type__c, FEC_Name_VN__c, Process_Change_Status__c FROM FEC_Additional_Field__c ORDER BY Name]);
            
            // 8.1 Additional Field List Value
            masterDataMap.put('AdditionalFieldList', [SELECT Id, Name, ExternalID__c, FEC_Name_VN__c, Process_Change_Status__c FROM FEC_Additional_Field_List_Value__c ORDER BY Name]);
            
            
            // 9. Case Stage
            masterDataMap.put('CaseStage', [SELECT Id, Name, ExternalID__c,FEC_Business_Process__c, Process_Change_Status__c FROM FEC_Case_Stage__c ORDER BY Name]);
            
            
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi: ' + e.getMessage());
        }
        return masterDataMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMasterDataMDM() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        
        try {
            // --- 5 Tabs cũ ---
            masterDataMap.put('ProductType', [SELECT Id, ExternalID__c, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_MDM_Product_Type__c ORDER BY Name]);
            masterDataMap.put('BusinessProcess', [SELECT Id, ExternalID__c, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_MDM_Business_Process__c ORDER BY Name]);
            masterDataMap.put('Category', [SELECT Id, ExternalID__c, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_MDM_Category__c ORDER BY Name]);
            masterDataMap.put('SubCategory', [SELECT Id, ExternalID__c, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_MDM_Sub_Category__c ORDER BY Name]);
            masterDataMap.put('SubCode', [SELECT Id, ExternalID__c, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Pos_Order__c, FEC_Status__c, Process_Change_Status__c FROM FEC_MDM_Sub_Code__c ORDER BY Name]);

            // --- 4 Tabs mới thêm ---
            // 6. Master Data Setting
            masterDataMap.put('MasterSetting', [SELECT Id, ExternalID__c, Name, FEC_Customer_Type__c, FEC_Additional_Field__c, FEC_Stage_Name__c, FEC_Channel__c, FEC_Applicable_Role__c, FEC_Data_Integration_Mapping__c, Process_Change_Status__c FROM FEC_MDM_Master_Data_Setting__c ORDER BY Name]);
            // Channel
            masterDataMap.put('Channel', [SELECT Id, ExternalID__c, Name, Process_Change_Status__c FROM FEC_MDM_Channel__c ORDER BY Name]);
            
            // 7. Nature Of Case (trả về wrapper)
            List<FEC_MDM_Nature_Of_Case__c> nocList = [
                SELECT Id, ExternalID__c, Name, FEC_Customer_Type__c, FEC_Product_Type_Name__r.Name, FEC_Business_Process_Name__r.Name, 
                       FEC_Category_Name__r.Name, FEC_Sub_Category_Name__r.Name,FEC_Sub_Code__r.Name, Process_Change_Status__c 
                FROM FEC_MDM_Nature_Of_Case__c LIMIT 1000
            ];
            System.debug('NOC Wrapper List nocList: ' + nocList);
            List<NatureOfCaseMDMWrapper> nocWrapperList = new List<NatureOfCaseMDMWrapper>();
            for (FEC_MDM_Nature_Of_Case__c noc : nocList) {
                nocWrapperList.add(new NatureOfCaseMDMWrapper(noc));
            }
            System.debug('NOC Wrapper List nocWrapperList: ' + nocWrapperList);
            masterDataMap.put('NatureOfCase', nocWrapperList);
            
            // 8. Additional Field
            masterDataMap.put('AdditionalField', [SELECT Id, ExternalID__c, Name, FEC_Type__c, FEC_Name_VN__c, Process_Change_Status__c FROM FEC_MDM_Additional_Field__c ORDER BY Name]);
            
            // 8.1 Additional Field List Value
            masterDataMap.put('AdditionalFieldList', [SELECT Id, Name, ExternalID__c, FEC_Name_VN__c, Process_Change_Status__c FROM FEC_MDM_Additional_Field_List_Value__c ORDER BY Name]);
            
            
            // 9. Case Stage
            masterDataMap.put('CaseStage', [SELECT Id, ExternalID__c, Name,FEC_Business_Process__c, Process_Change_Status__c FROM FEC_MDM_Case_Stage__c ORDER BY Name]);
            
            
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi: ' + e.getMessage());
        }
        return masterDataMap;
    }
    
    
    @AuraEnabled
    public static void syncDataToMDM() {
        try {
            // Khởi chạy Batch với size = 1 để mỗi Object xử lý trong 1 Transaction riêng biệt
            Database.executeBatch(new FEC_SyncMasterDataBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException('Không thể bắt đầu tiến trình đồng bộ: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void pushMDMToLive() {
        try {
            // Chạy Batch với scope 1 để đảm bảo an toàn CPU cho từng Object
            Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException('Lỗi khi bắt đầu đồng bộ: ' + e.getMessage());
        }
    }
    
    public class NatureOfCaseMDMWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String ExternalID;
        @AuraEnabled public String Name;
        // @AuraEnabled public String FEC_Customer_Type;
        @AuraEnabled public String FEC_Product_Type_Name;
        @AuraEnabled public String FEC_Business_Process_Name;
        @AuraEnabled public String FEC_Category_Name;
        @AuraEnabled public String FEC_Sub_Category_Name;
        @AuraEnabled public String FEC_Sub_Code;
        @AuraEnabled public String Process_Change_Status;
        public NatureOfCaseMDMWrapper(FEC_MDM_Nature_Of_Case__c noc) {
            Id = noc.Id;
            ExternalID = noc.ExternalID__c;
            Name = noc.Name;
            // FEC_Customer_Type = noc.FEC_Customer_Type__c;
            FEC_Product_Type_Name = noc.FEC_Product_Type_Name__r != null ? noc.FEC_Product_Type_Name__r.Name : null;
            FEC_Business_Process_Name = noc.FEC_Business_Process_Name__r != null ? noc.FEC_Business_Process_Name__r.Name : null;
            FEC_Category_Name = noc.FEC_Category_Name__r != null ? noc.FEC_Category_Name__r.Name : null;
            FEC_Sub_Category_Name = noc.FEC_Sub_Category_Name__r != null ? noc.FEC_Sub_Category_Name__r.Name : null;
            FEC_Sub_Code = noc.FEC_Sub_Code__r != null ? noc.FEC_Sub_Code__r.Name : null;
            Process_Change_Status = noc.Process_Change_Status__c;
        }
    }
    public class NatureOfCaseWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String ExternalID;
        @AuraEnabled public String FEC_Product_Type_Name;
        @AuraEnabled public String FEC_Business_Process_Name;
        @AuraEnabled public String FEC_Category_Name;
        @AuraEnabled public String FEC_Sub_Category_Name;
        @AuraEnabled public String FEC_Sub_Code;
        @AuraEnabled public String Process_Change_Status;
        public NatureOfCaseWrapper(FEC_Nature_Of_Case__c noc) {
            Id = noc.Id;
            Name = noc.Name;
            ExternalID = noc.ExternalID__c;
            FEC_Product_Type_Name = noc.FEC_Product_Type_Name__r != null ? noc.FEC_Product_Type_Name__r.Name : null;
            FEC_Business_Process_Name = noc.FEC_Business_Process_Name__r != null ? noc.FEC_Business_Process_Name__r.Name : null;
            FEC_Category_Name = noc.FEC_Category_Name__r != null ? noc.FEC_Category_Name__r.Name : null;
            FEC_Sub_Category_Name = noc.FEC_Sub_Category_Name__r != null ? noc.FEC_Sub_Category_Name__r.Name : null;
            FEC_Sub_Code = noc.FEC_Sub_Code__r != null ? noc.FEC_Sub_Code__r.Name : null;
            Process_Change_Status = noc.Process_Change_Status__c;
        }
    }
}
