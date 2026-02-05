public with sharing class FEC_MasterDataReviewController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCustomerTypeOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Customer_Type__c ct FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Customer_Type__c != null GROUP BY FEC_Customer_Type__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            String val = (String)ar.get(FEC_Constants.ALIAS_CT);
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => val, FEC_Constants.MAP_VALUE => val});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductOptions(String customerType) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Product_Type_Name__r.Id pId, FEC_Product_Type_Name__r.FEC_Code__c pCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Customer_Type__c = :customerType
                                  GROUP BY FEC_Product_Type_Name__r.Id, FEC_Product_Type_Name__r.FEC_Code__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_P_CODE), FEC_Constants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_P_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBizOptions(String productId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Business_Process_Name__r.Id bId, FEC_Business_Process_Name__r.FEC_Code__c bCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type_Name__c = :productId 
                                  GROUP BY FEC_Business_Process_Name__r.Id, FEC_Business_Process_Name__r.FEC_Code__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_B_CODE), FEC_Constants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_B_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategoryOptions(String productId, String bizId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Category_Name__r.Id cId, FEC_Category_Name__r.FEC_Code__c cCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type_Name__c = :productId AND FEC_Business_Process_Name__c = :bizId
                                  GROUP BY FEC_Category_Name__r.Id, FEC_Category_Name__r.FEC_Code__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_C_CODE), FEC_Constants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_C_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCatOptions(String productId, String bizId, String catId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Sub_Category_Name__r.Id scId, FEC_Sub_Category_Name__r.FEC_Code__c scCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type_Name__c = :productId AND FEC_Business_Process_Name__c = :bizId AND FEC_Category_Name__c = :catId
                                  GROUP BY FEC_Sub_Category_Name__r.Id, FEC_Sub_Category_Name__r.FEC_Code__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_SC_CODE), FEC_Constants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_SC_ID)});
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for(AggregateResult ar : [SELECT FEC_Sub_Code__r.Id sccId, FEC_Sub_Code__r.FEC_Code__c sccCode 
                                  FROM FEC_MDM_Nature_Of_Case__c WHERE FEC_Product_Type_Name__c = :productId AND FEC_Business_Process_Name__c = :bizId AND FEC_Category_Name__c = :catId AND FEC_Sub_Category_Name__c = :subCatId
                                  GROUP BY FEC_Sub_Code__r.Id, FEC_Sub_Code__r.FEC_Code__c LIMIT :FEC_Constants.QUERY_LIMIT]) {
            options.add(new Map<String, String>{FEC_Constants.MAP_LABEL => (String)ar.get(FEC_Constants.ALIAS_SCC_CODE), FEC_Constants.MAP_VALUE => (String)ar.get(FEC_Constants.ALIAS_SCC_ID)});
        }
        return options;
    }
    
    @AuraEnabled
    public static ComparisonResult getComparisonData(String productId, String bizId, String catId, String subCatId, String subCodeId) {
        ComparisonResult finalResult = new ComparisonResult();
        List<FEC_MDM_Nature_Of_Case__c> mdmNocs = [SELECT Id, ExternalID__c FROM FEC_MDM_Nature_Of_Case__c 
                                                   WHERE FEC_Product_Type_Name__c = :productId AND FEC_Business_Process_Name__c = :bizId 
                                                   AND FEC_Category_Name__c = :catId AND FEC_Sub_Category_Name__c = :subCatId 
                                                   AND FEC_Sub_Code__c = :subCodeId LIMIT 1];
        if(mdmNocs.isEmpty()) return finalResult;
        Id mdmNocId = mdmNocs[0].Id;
        List<FEC_MDM_Master_Data_Setting__c> mdmSettings = [SELECT Name, ExternalID__c, FEC_Channel__c, FEC_Stage_Name__c, 
                                                            FEC_Section__c, FEC_Field_Mandatory__c, FEC_Additional_Field__r.Name,
                                                            Process_Change_Status__c
                                                            FROM FEC_MDM_Master_Data_Setting__c 
                                                            WHERE FEC_Nature_Of_Case__c = :mdmNocId LIMIT :FEC_Constants.QUERY_LIMIT];
        if(mdmSettings.isEmpty()) return finalResult;
        Set<String> mdmExtIds = new Set<String>();
        for(FEC_MDM_Master_Data_Setting__c m : mdmSettings) {
            if(String.isNotBlank(m.ExternalID__c)) mdmExtIds.add(m.ExternalID__c);
        }
        Map<String, FEC_Master_Data_Setting__c> liveMap = new Map<String, FEC_Master_Data_Setting__c>();
        if(!mdmExtIds.isEmpty()) {
            for(FEC_Master_Data_Setting__c live : [SELECT Name, ExternalID__c, FEC_Channel__c, FEC_Stage_Name__c, 
                                                   FEC_Section__c, FEC_Field_Mandatory__c, FEC_Additional_Field__r.Name 
                                                   FROM FEC_Master_Data_Setting__c WHERE ExternalID__c IN :mdmExtIds LIMIT :FEC_Constants.QUERY_LIMIT]) {
                liveMap.put(live.ExternalID__c, live);
            }
        }
        for(FEC_MDM_Master_Data_Setting__c mdm : mdmSettings) {
            ComparisonWrapper wrapped = new ComparisonWrapper(mdm, liveMap.get(mdm.ExternalID__c));
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
        
        public ComparisonWrapper(FEC_MDM_Master_Data_Setting__c mdm, FEC_Master_Data_Setting__c live) {
            this.name = mdm.Name;
            this.propertyName = mdm.FEC_Additional_Field__r?.Name;
            this.externalId = mdm.ExternalID__c;
            this.status = mdm.Process_Change_Status__c;
            this.isNew = (live == null);
            compare(live?.FEC_Channel__c, mdm.FEC_Channel__c, FEC_Constants.LABEL_CHANNEL);
            compare(live?.FEC_Section__c, mdm.FEC_Section__c, FEC_Constants.LABEL_SECTION);
            compare(String.valueOf(live?.FEC_Field_Mandatory__c), String.valueOf(mdm.FEC_Field_Mandatory__c), FEC_Constants.LABEL_MANDATORY);
            compare(live?.FEC_Additional_Field__r?.Name, mdm.FEC_Additional_Field__r?.Name, FEC_Constants.LABEL_PROPERTY_NAME);
         }
         
         private void compare(String vOld, String vNew, String label) {
             String s1 = (vOld == null) ? '' : vOld;
             String s2 = (vNew == null) ? '' : vNew;
             if(s1 != s2) this.hasChanged = true;
             this.diffs.add(new FieldDiff(label, s1, s2));
         }
     }
     
     public class FieldDiff {
         @AuraEnabled public String label, oldVal, newVal, cellClass;
         @AuraEnabled public Boolean isDifferent;
         public FieldDiff(String lb, String ov, String nv) {
            label = lb; oldVal = (ov == '' ? FEC_Constants.PLACEHOLDER_EMPTY : ov); newVal = (nv == '' ? FEC_Constants.PLACEHOLDER_EMPTY : nv);
            isDifferent = (ov != nv);
            cellClass = isDifferent ? FEC_Constants.CSS_WARN : '';
         }
     }
 }
