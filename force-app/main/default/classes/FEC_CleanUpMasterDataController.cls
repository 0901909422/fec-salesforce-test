public with sharing class FEC_CleanUpMasterDataController {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMasterData() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        
        try {
            // --- 5 Tabs cũ ---
            masterDataMap.put(FEC_Constants.KEY_PRODUCT_TYPE, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c FROM FEC_Product_Type__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_BUSINESS_PROCESS, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c FROM FEC_Business_Process__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_CATEGORY, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c FROM FEC_Category__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_SUB_CATEGORY, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c FROM FEC_Sub_Category__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_SUB_CODE, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Active__c FROM FEC_Sub_Code__c ORDER BY Name]);
            
            // --- 4 Tabs mới thêm ---
            // 6. Master Data Setting
            masterDataMap.put(FEC_Constants.KEY_MASTER_SETTING, [SELECT Id, Name, FEC_Code__c, FEC_Stage_Name__c, FEC_Nature_Of_Case__c, FEC_Channel__c FROM FEC_Master_Data_Setting__c ORDER BY Name]);
            
            masterDataMap.put(FEC_Constants.KEY_CHANNEL, [SELECT Id, Name, FEC_Code__c FROM FEC_Channel__c ORDER BY Name]);
            
            // 7. Nature Of Case (trả về wrapper)
            List<FEC_Nature_Of_Case__c> nocList = [
                SELECT Id, Name, FEC_Code__c, FEC_Product_Type__r.Name, FEC_Business_Process__r.Name, 
                        FEC_Category__r.Name, FEC_Sub_Category__r.Name, FEC_Sub_Code__r.Name 
                FROM FEC_Nature_Of_Case__c
            ];
            System.debug(FEC_Constants.DEBUG_NOC_LIST_PREFIX + nocList);
            List<NatureOfCaseWrapper> nocWrapperList = new List<NatureOfCaseWrapper>();
            for (FEC_Nature_Of_Case__c noc : nocList) {
                nocWrapperList.add(new NatureOfCaseWrapper(noc));
            }
            System.debug(FEC_Constants.DEBUG_NOC_WRAPPER_PREFIX + nocWrapperList);
            masterDataMap.put(FEC_Constants.KEY_NATURE_OF_CASE, nocWrapperList);
            
            // 8. Additional Field
            masterDataMap.put(FEC_Constants.KEY_ADDITIONAL_FIELD, [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c FROM FEC_Additional_Field__c ORDER BY Name]);
            
            // 8.1 Additional Field List Value
            masterDataMap.put(FEC_Constants.KEY_ADDITIONAL_FIELD_LIST, [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c FROM FEC_Additional_Field_List_Value__c ORDER BY Name]);
            
            
            // 9. Case Stage
            masterDataMap.put(FEC_Constants.KEY_CASE_STAGE, [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c FROM FEC_Case_Stage__c ORDER BY Name]);
            
            // 10. Action Button
            masterDataMap.put('ActionButton', [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c FROM FEC_Action_Button__c ORDER BY Name]);

            // 11. Stage Change (Wrapper)
            List<FEC_Stage_Change__c> scList = [
                SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name, 
                       FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c 
                FROM FEC_Stage_Change__c
            ];
            List<StageChangeWrapper> scWrapperList = new List<StageChangeWrapper>();
            for (FEC_Stage_Change__c sc : scList) {
                scWrapperList.add(new StageChangeWrapper(sc));
            }
            masterDataMap.put('StageChange', scWrapperList);
            
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAllMasterDataMDM() {
        Map<String, List<Object>> masterDataMap = new Map<String, List<Object>>();
        
        try {
            // --- 5 Tabs cũ ---
            masterDataMap.put(FEC_Constants.KEY_PRODUCT_TYPE, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c FROM FEC_MDM_Product_Type__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_BUSINESS_PROCESS, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c FROM FEC_MDM_Business_Process__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_CATEGORY, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c FROM FEC_MDM_Category__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_SUB_CATEGORY, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c FROM FEC_MDM_Sub_Category__c ORDER BY Name]);
            masterDataMap.put(FEC_Constants.KEY_SUB_CODE, [SELECT Id, Name, FEC_Alias__c, FEC_Code__c, FEC_Name_VN__c, FEC_Status__c, Process_Change_Status__c, FEC_Active__c FROM FEC_MDM_Sub_Code__c ORDER BY Name]);
            
            // --- 4 Tabs mới thêm ---
            // 6. Master Data Setting
            masterDataMap.put(FEC_Constants.KEY_MASTER_SETTING, [SELECT Id, Name, FEC_Code__c, FEC_Additional_Field__c, FEC_Nature_Of_Case__c, FEC_Stage_Name__c, FEC_Channel__c, FEC_Applicable_Role__c, FEC_Data_Integration_Mapping__c, Process_Change_Status__c FROM FEC_MDM_Master_Data_Setting__c ORDER BY Name]);
            // Channel
            masterDataMap.put(FEC_Constants.KEY_CHANNEL, [SELECT Id, Name, FEC_Code__c, Process_Change_Status__c FROM FEC_MDM_Channel__c ORDER BY Name]);
            
            // 7. Nature Of Case (trả về wrapper)
            List<FEC_MDM_Nature_Of_Case__c> nocList = [
                SELECT Id, Name, FEC_Code__c, FEC_Customer_Type__c, FEC_Product_Type__r.Name, FEC_Business_Process__r.Name, 
                       FEC_Category__r.Name, FEC_Sub_Category__r.Name,FEC_Sub_Code__r.Name, Process_Change_Status__c 
                FROM FEC_MDM_Nature_Of_Case__c
            ];
            System.debug(FEC_Constants.DEBUG_NOC_LIST_PREFIX + nocList);
            List<NatureOfCaseMDMWrapper> nocWrapperList = new List<NatureOfCaseMDMWrapper>();
            for (FEC_MDM_Nature_Of_Case__c noc : nocList) {
                nocWrapperList.add(new NatureOfCaseMDMWrapper(noc));
            }
            System.debug(FEC_Constants.DEBUG_NOC_WRAPPER_PREFIX + nocWrapperList);
            masterDataMap.put(FEC_Constants.KEY_NATURE_OF_CASE, nocWrapperList);
            
            // 8. Additional Field
            masterDataMap.put(FEC_Constants.KEY_ADDITIONAL_FIELD, [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Name_VN__c, Process_Change_Status__c FROM FEC_MDM_Additional_Field__c ORDER BY Name]);
            
            // 8.1 Additional Field List Value
            masterDataMap.put(FEC_Constants.KEY_ADDITIONAL_FIELD_LIST, [SELECT Id, Name, FEC_Code__c, FEC_Name_VN__c, FEC_Additional_Field__c, Process_Change_Status__c FROM FEC_MDM_Additional_Field_List_Value__c ORDER BY Name]);
            
            
            // 9. Case Stage
            masterDataMap.put(FEC_Constants.KEY_CASE_STAGE, [SELECT Id, Name, FEC_Code__c, FEC_Business_Process__c, Process_Change_Status__c FROM FEC_MDM_Case_Stage__c ORDER BY Name]);
            
            // 10. Action Button MDM
            masterDataMap.put('ActionButton', [SELECT Id, Name, FEC_Code__c, FEC_Type__c, FEC_Apex_Class__c, FEC_FlowID__c, FEC_Active__c, Process_Change_Status__c FROM FEC_MDM_Action_Button__c ORDER BY Name]);

            // 11. Stage Change MDM (Wrapper)
            List<FEC_MDM_Stage_Change__c> scListMdm = [
                SELECT Id, Name, FEC_Code__c, FEC_Previous_Stage__r.Name, FEC_Action_Button__r.Name, 
                       FEC_Next_Stage__r.Name, FEC_Next_Queue__c, FEC_Team_User_Group__c, FEC_Active__c, Process_Change_Status__c 
                FROM FEC_MDM_Stage_Change__c
            ];
            List<StageChangeMDMWrapper> scWrapperListMdm = new List<StageChangeMDMWrapper>();
            for (FEC_MDM_Stage_Change__c sc : scListMdm) {
                scWrapperListMdm.add(new StageChangeMDMWrapper(sc));
            }
            masterDataMap.put('StageChange', scWrapperListMdm);
            
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
        return masterDataMap;
    }
    
    
    @AuraEnabled
    public static void syncDataToMDM() {
        try {
            // Khởi chạy Batch với size = 1 để mỗi Object xử lý trong 1 Transaction riêng biệt
            Database.executeBatch(new FEC_SyncMasterDataBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_CANNOT_START_SYNC + ' ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void pushMDMToLive() {
        try {
            // Chạy Batch với scope 1 để đảm bảo an toàn CPU cho từng Object
            Database.executeBatch(new FEC_PushMDMToLiveBatch(), 1);
        } catch (Exception e) {
            throw new AuraHandledException(FEC_Constants.ERROR_CANNOT_START_PUSH + ' ' + e.getMessage());
        }
    }
    
    public class NatureOfCaseMDMWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String ExternalID;
        @AuraEnabled public String Code;
        @AuraEnabled public String Name;
        @AuraEnabled public String FEC_Customer_Type;
        @AuraEnabled public String FEC_Product_Type_Name;
        @AuraEnabled public String FEC_Business_Process_Name;
        @AuraEnabled public String FEC_Category_Name;
        @AuraEnabled public String FEC_Sub_Category_Name;
        @AuraEnabled public String FEC_Sub_Code;
        @AuraEnabled public String Process_Change_Status;
        public NatureOfCaseMDMWrapper(FEC_MDM_Nature_Of_Case__c noc) {
            Id = noc.Id;
            Code = noc.FEC_Code__c;
            Name = noc.Name;
            FEC_Customer_Type = noc.FEC_Customer_Type__c;
            FEC_Product_Type_Name = noc.FEC_Product_Type__r != null ? noc.FEC_Product_Type__r.Name : null;
            FEC_Business_Process_Name = noc.FEC_Business_Process__r != null ? noc.FEC_Business_Process__r.Name : null;
            FEC_Category_Name = noc.FEC_Category__r != null ? noc.FEC_Category__r.Name : null;
            FEC_Sub_Category_Name = noc.FEC_Sub_Category__r != null ? noc.FEC_Sub_Category__r.Name : null;
            FEC_Sub_Code = noc.FEC_Sub_Code__r != null ? noc.FEC_Sub_Code__r.Name : null;
            Process_Change_Status = noc.Process_Change_Status__c;
        }
    }
    public class NatureOfCaseWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Code;
        @AuraEnabled public String Name;
        @AuraEnabled public String FEC_Product_Type_Name;
        @AuraEnabled public String FEC_Business_Process_Name;
        @AuraEnabled public String FEC_Category_Name;
        @AuraEnabled public String FEC_Sub_Category_Name;
        @AuraEnabled public String FEC_Sub_Code;
        @AuraEnabled public String Process_Change_Status;
        public NatureOfCaseWrapper(FEC_Nature_Of_Case__c noc) {
            Id = noc.Id;
            Code = noc.FEC_Code__c;
            Name = noc.Name;
            FEC_Product_Type_Name = noc.FEC_Product_Type__r != null ? noc.FEC_Product_Type__r.Name : null;
            FEC_Business_Process_Name = noc.FEC_Business_Process__r != null ? noc.FEC_Business_Process__r.Name : null;
            FEC_Category_Name = noc.FEC_Category__r != null ? noc.FEC_Category__r.Name : null;
            FEC_Sub_Category_Name = noc.FEC_Sub_Category__r != null ? noc.FEC_Sub_Category__r.Name : null;
            FEC_Sub_Code = noc.FEC_Sub_Code__r != null ? noc.FEC_Sub_Code__r.Name : null;
        }
    }

    public class StageChangeWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Code;
        @AuraEnabled public String Name;
        @AuraEnabled public String FEC_Previous_Stage_Name;
        @AuraEnabled public String FEC_Action_Button_Name;
        @AuraEnabled public String FEC_Next_Stage_Name;
        @AuraEnabled public String FEC_Next_Queue;
        @AuraEnabled public String FEC_Team_User_Group;
        @AuraEnabled public Boolean FEC_Active;

        public StageChangeWrapper(FEC_Stage_Change__c sc) {
            Id = sc.Id;
            Code = sc.FEC_Code__c;
            Name = sc.Name;
            FEC_Previous_Stage_Name = sc.FEC_Previous_Stage__r != null ? sc.FEC_Previous_Stage__r.Name : null;
            FEC_Action_Button_Name = sc.FEC_Action_Button__r != null ? sc.FEC_Action_Button__r.Name : null;
            FEC_Next_Stage_Name = sc.FEC_Next_Stage__r != null ? sc.FEC_Next_Stage__r.Name : null;
            FEC_Next_Queue = sc.FEC_Next_Queue__c;
            FEC_Team_User_Group = sc.FEC_Team_User_Group__c;
            FEC_Active = sc.FEC_Active__c;
        }
    }

    public class StageChangeMDMWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Code;
        @AuraEnabled public String Name;
        @AuraEnabled public String FEC_Previous_Stage_Name;
        @AuraEnabled public String FEC_Action_Button_Name;
        @AuraEnabled public String FEC_Next_Stage_Name;
        @AuraEnabled public String FEC_Next_Queue;
        @AuraEnabled public String FEC_Team_User_Group;
        @AuraEnabled public Boolean FEC_Active;
        @AuraEnabled public String Process_Change_Status;

        public StageChangeMDMWrapper(FEC_MDM_Stage_Change__c sc) {
            Id = sc.Id;
            Code = sc.FEC_Code__c;
            Name = sc.Name;
            FEC_Previous_Stage_Name = sc.FEC_Previous_Stage__r != null ? sc.FEC_Previous_Stage__r.Name : null;
            FEC_Action_Button_Name = sc.FEC_Action_Button__r != null ? sc.FEC_Action_Button__r.Name : null;
            FEC_Next_Stage_Name = sc.FEC_Next_Stage__r != null ? sc.FEC_Next_Stage__r.Name : null;
            FEC_Next_Queue = sc.FEC_Next_Queue__c;
            FEC_Team_User_Group = sc.FEC_Team_User_Group__c;
            FEC_Active = sc.FEC_Active__c;
            Process_Change_Status = sc.Process_Change_Status__c;
        }
    }

    private static void deleteRecords(String objName, Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objName);
        if (t == null) {
            throw new AuraHandledException(FEC_Constants.ERROR_INVALID_SOBJECT_PREFIX + objName);
        }
        if (!t.getDescribe().isDeletable()) {
            throw new AuraHandledException(System.Label.FEC_Error_No_Delete_Permission);
        }
        String dmlQuery = 'SELECT Id FROM ' + objName + ' WHERE Id IN :ids';
        delete Database.query(dmlQuery);
    }
}