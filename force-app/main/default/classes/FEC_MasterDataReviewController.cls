public with sharing class FEC_MasterDataReviewController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCustomerTypeOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Customer_Type__c ct FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Customer_Type__c != null GROUP BY FEC_Customer_Type__c]) {
            String val = (String)ar.get(FEC_Constants.ALIAS_CT);
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => val, FEC_UIConstants.MAP_VALUE => val});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductOptions(String customerType) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Product_Type__r.Id pId, FEC_Product_Type__r.FEC_Code__c pCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Customer_Type__c = :customerType
                                  GROUP BY FEC_Product_Type__r.Id, FEC_Product_Type__r.FEC_Code__c]) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_P_CODE), FEC_UIConstants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_P_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBizOptions(String productId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Business_Process__r.Id bId, FEC_Business_Process__r.FEC_Code__c bCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :productId 
                                  GROUP BY FEC_Business_Process__r.Id, FEC_Business_Process__r.FEC_Code__c]) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_B_CODE), FEC_UIConstants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_B_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategoryOptions(String productId, String bizId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Category__r.Id cId, FEC_Category__r.FEC_Code__c cCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId
                                  GROUP BY FEC_Category__r.Id, FEC_Category__r.FEC_Code__c]) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_C_CODE), FEC_UIConstants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_C_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCatOptions(String productId, String bizId, String catId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Sub_Category__r.Id scId, FEC_Sub_Category__r.FEC_Code__c scCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId AND FEC_Category__c = :catId
                                  GROUP BY FEC_Sub_Category__r.Id, FEC_Sub_Category__r.FEC_Code__c]) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_SC_CODE), FEC_UIConstants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_SC_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Sub_Code__r.Id sccId, FEC_Sub_Code__r.FEC_Code__c sccCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :subCatId
                                  GROUP BY FEC_Sub_Code__r.Id, FEC_Sub_Code__r.FEC_Code__c]) {
            options.add(new Map<String, String>{FEC_UIConstants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_SCC_CODE), FEC_UIConstants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_SCC_ID)});
        }
        return options;
    }
    
    @AuraEnabled
    public static ComparisonResult getComparisonData(String productId, String bizId, String catId, String subCatId, String subCodeId) {
        ComparisonResult finalResult = new ComparisonResult();
        List<FEC_MDM_Nature_Of_Case__c> mdmNocs = [SELECT Id, FEC_Code__c FROM FEC_MDM_Nature_Of_Case__c 
                                                   WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId 
                                                   AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :subCatId 
                                                   AND FEC_Sub_Code__c = :subCodeId];
        if (mdmNocs.isEmpty()) return finalResult;
        Id mdmNocId = mdmNocs[0].Id;
        List<FEC_MDM_Master_Data_Setting__c> mdmSettings = [
            SELECT Name, FEC_Code__c, FEC_Section__c, FEC_Field_Mandatory__c,
                   FEC_Field_Status__c, FEC_Field_ReadOnly__c, FEC_Field_Order_Display__c,
                   FEC_Applicable_Role__c, FEC_Field_Editable__c, FEC_Editable_Role__c,
                   FEC_Field_Masking__c, FEC_Masking_Type__c, FEC_Field_Reverted__c,
                   FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c,
                   FEC_Sub_Section_Field_Layout__c,
                   FEC_Data_Integration_Mapping__c, FEC_Editable_User_Group__c,
                   FEC_Additional_Field__r.Name, Process_Change_Status__c
            FROM FEC_MDM_Master_Data_Setting__c 
            WHERE FEC_Nature_Of_Case__c = :mdmNocId
        ];
        if (mdmSettings.isEmpty()) return finalResult;
        Set<String> mdmCodes = new Set<String>();
        for (FEC_MDM_Master_Data_Setting__c m : mdmSettings) {
            if(String.isNotBlank(m.FEC_Code__c)) mdmCodes.add(m.FEC_Code__c);
        }
        Map<String, FEC_Master_Data_Setting__c> liveMap = new Map<String, FEC_Master_Data_Setting__c>();
        if(!mdmCodes.isEmpty()) {
            for (FEC_Master_Data_Setting__c lv : [
                SELECT Name, FEC_Code__c, FEC_Section__c, FEC_Field_Mandatory__c,
                       FEC_Field_Status__c, FEC_Field_ReadOnly__c, FEC_Field_Order_Display__c,
                       FEC_Applicable_Role__c, FEC_Field_Editable__c, FEC_Editable_Role__c,
                       FEC_Field_Masking__c, FEC_Masking_Type__c, FEC_Field_Reverted__c,
                       FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c,
                       FEC_Sub_Section_Field_Layout__c,
                       FEC_Data_Integration_Mapping__c, FEC_Editable_User_Group__c
                FROM FEC_Master_Data_Setting__c
                WHERE FEC_Code__c IN :mdmCodes
            ]) {
                liveMap.put(lv.FEC_Code__c, lv);
            }
        }
        for (FEC_MDM_Master_Data_Setting__c mdm : mdmSettings) {
            FEC_Master_Data_Setting__c live = liveMap.get(mdm.FEC_Code__c);
            ComparisonWrapper wrapped = new ComparisonWrapper(mdm, live);
            if(wrapped.isNew) finalResult.newList.add(wrapped);
            else if(wrapped.hasChanged) finalResult.updateList.add(wrapped);
            else finalResult.syncedList.add(wrapped);
        }
        return finalResult;
    }
    
    public class ComparisonResult {
        @AuraEnabled public List<ComparisonWrapper> newList = new List<ComparisonWrapper>();
        @AuraEnabled public List<ComparisonWrapper> updateList = new List<ComparisonWrapper>();
        @AuraEnabled public List<ComparisonWrapper> syncedList = new List<ComparisonWrapper>();
    }
    
    public class ComparisonWrapper {
        @AuraEnabled public String name, propertyName, externalId, status;
        @AuraEnabled public List<FieldDiff> diffs = new List<FieldDiff>();
        @AuraEnabled public Boolean isNew, hasChanged = false;
        @AuraEnabled public Integer diffCount = 0;
        
        public ComparisonWrapper(FEC_MDM_Master_Data_Setting__c mdm, FEC_Master_Data_Setting__c live) {
            this.name = mdm.Name;
            this.propertyName = mdm.FEC_Additional_Field__r?.Name;
            this.externalId = mdm.FEC_Code__c;
            this.status = mdm.Process_Change_Status__c;
            this.isNew = (live == null);
            // Text fields (non-lookup, safe to compare across Live/MDM)
            compare(live?.FEC_Section__c, mdm.FEC_Section__c, FEC_UIConstants.LABEL_SECTION);
            compare(live?.FEC_Sub_Section__c, mdm.FEC_Sub_Section__c, FEC_UIConstants.LABEL_SUB_SECTION);
            compare(String.valueOf(live?.FEC_Sub_Section_Order__c), String.valueOf(mdm.FEC_Sub_Section_Order__c), FEC_UIConstants.LABEL_SUB_SECTION_ORDER);
            compare(String.valueOf(live?.FEC_Sub_Section_Layout__c), String.valueOf(mdm.FEC_Sub_Section_Layout__c), FEC_UIConstants.LABEL_SUB_SECTION_LAYOUT);
            compare(String.valueOf(live?.FEC_Sub_Section_Field_Layout__c), String.valueOf(mdm.FEC_Sub_Section_Field_Layout__c), FEC_UIConstants.LABEL_SUB_SECTION_FIELD_LAYOUT);
            compare(String.valueOf(live?.FEC_Field_Order_Display__c), String.valueOf(mdm.FEC_Field_Order_Display__c), FEC_UIConstants.LABEL_ORDER_DISPLAY);
            // Boolean fields
            compare(String.valueOf(live?.FEC_Field_Status__c), String.valueOf(mdm.FEC_Field_Status__c), FEC_UIConstants.LABEL_FIELD_STATUS);
            compare(String.valueOf(live?.FEC_Field_Mandatory__c), String.valueOf(mdm.FEC_Field_Mandatory__c), FEC_UIConstants.LABEL_MANDATORY);
            compare(String.valueOf(live?.FEC_Field_ReadOnly__c), String.valueOf(mdm.FEC_Field_ReadOnly__c), FEC_UIConstants.LABEL_READONLY);
            compare(String.valueOf(live?.FEC_Field_Editable__c), String.valueOf(mdm.FEC_Field_Editable__c), FEC_UIConstants.LABEL_EDITABLE);
            compare(String.valueOf(live?.FEC_Field_Masking__c), String.valueOf(mdm.FEC_Field_Masking__c), FEC_UIConstants.LABEL_MASKING);
            compare(String.valueOf(live?.FEC_Field_Reverted__c), String.valueOf(mdm.FEC_Field_Reverted__c), FEC_UIConstants.LABEL_REVERTED);
            // Text/picklist fields
            compare(live?.FEC_Applicable_Role__c, mdm.FEC_Applicable_Role__c, FEC_UIConstants.LABEL_APPLICABLE_ROLE);
            compare(live?.FEC_Editable_Role__c, mdm.FEC_Editable_Role__c, FEC_UIConstants.LABEL_EDITABLE_ROLE);
            compare(live?.FEC_Masking_Type__c, mdm.FEC_Masking_Type__c, FEC_UIConstants.LABEL_MASKING_TYPE);
            compare(live?.FEC_Data_Integration_Mapping__c, mdm.FEC_Data_Integration_Mapping__c, FEC_UIConstants.LABEL_DATA_INTEGRATION);
            compare(live?.FEC_Editable_User_Group__c, mdm.FEC_Editable_User_Group__c, FEC_UIConstants.LABEL_EDITABLE_USER_GROUP);
        }
         
        private void compare(String vOld, String vNew, String label) {
            String s1 = (vOld == null) ? '' : vOld;
            String s2 = (vNew == null) ? '' : vNew;
            Boolean isDiff = (s1 != s2);
            if(isDiff) {
                this.hasChanged = true;
                this.diffCount++;
            }
            this.diffs.add(new FieldDiff(label, s1, s2));
        }
    }
     
     public class FieldDiff {
         @AuraEnabled public String label, oldVal, newVal, cellClass;
         @AuraEnabled public Boolean isDifferent;
         public FieldDiff(String lb, String ov, String nv) {
            label = lb; oldVal = (ov == '' ? FEC_UIConstants.PLACEHOLDER_EMPTY : ov); newVal = (nv == '' ? FEC_UIConstants.PLACEHOLDER_EMPTY : nv);
            isDifferent = (ov != nv);
            cellClass = isDifferent ? FEC_UIConstants.CSS_WARN : '';
         }
     }
 }