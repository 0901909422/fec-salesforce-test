/**
 * @description Live mirror of FEC_MasterDataReviewController.
 *              Cascading filter methods query Live FEC_Nature_Of_Case__c.
 *              Comparison method matches Live records vs MDM records by FEC_Code__c.
 * @date   2026
 */
public with sharing class FEC_LiveMasterDataReviewController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCustomerTypeOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Customer_Type__c ct
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Customer_Type__c != null
            GROUP BY FEC_Customer_Type__c
        ]) {
            String val = (String) ar.get(FEC_Constants.ALIAS_CT);
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => val,
                FEC_UIConstants.MAP_VALUE => val
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductOptions(String customerType) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Product_Type__r.Id pId, FEC_Product_Type__r.FEC_Code__c pCode
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Customer_Type__c = :customerType
            GROUP BY FEC_Product_Type__r.Id, FEC_Product_Type__r.FEC_Code__c
        ]) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_P_CODE),
                FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_P_ID)
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBizOptions(String productId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Business_Process__r.Id bId, FEC_Business_Process__r.FEC_Code__c bCode
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Product_Type__c = :productId
            GROUP BY FEC_Business_Process__r.Id, FEC_Business_Process__r.FEC_Code__c
        ]) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_B_CODE),
                FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_B_ID)
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategoryOptions(String productId, String bizId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Category__r.Id cId, FEC_Category__r.FEC_Code__c cCode
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId
            GROUP BY FEC_Category__r.Id, FEC_Category__r.FEC_Code__c
        ]) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_C_CODE),
                FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_C_ID)
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCatOptions(String productId, String bizId, String catId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Sub_Category__r.Id scId, FEC_Sub_Category__r.FEC_Code__c scCode
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId AND FEC_Category__c = :catId
            GROUP BY FEC_Sub_Category__r.Id, FEC_Sub_Category__r.FEC_Code__c
        ]) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SC_CODE),
                FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SC_ID)
            });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT FEC_Sub_Code__r.Id sccId, FEC_Sub_Code__r.FEC_Code__c sccCode
            FROM FEC_Nature_Of_Case__c
            WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId
              AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :subCatId
            GROUP BY FEC_Sub_Code__r.Id, FEC_Sub_Code__r.FEC_Code__c
        ]) {
            options.add(new Map<String, String>{
                FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SCC_CODE),
                FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SCC_ID)
            });
        }
        return options;
    }

    @AuraEnabled
    public static FEC_MasterDataReviewController.ComparisonResult getComparisonData(
        String productId, String bizId, String catId, String subCatId, String subCodeId
    ) {
        // Reuse MDM's wrapper class — it accepts (mdm, live) ordering.
        // For Live module we invert the comparison: treat Live as the "source of truth"
        // and match MDM by FEC_Code__c.
        FEC_MasterDataReviewController.ComparisonResult result = new FEC_MasterDataReviewController.ComparisonResult();

        List<FEC_Nature_Of_Case__c> liveNocs = [
            SELECT Id, FEC_Code__c FROM FEC_Nature_Of_Case__c
            WHERE FEC_Product_Type__c = :productId AND FEC_Business_Process__c = :bizId
              AND FEC_Category__c = :catId AND FEC_Sub_Category__c = :subCatId AND FEC_Sub_Code__c = :subCodeId
        ];
        if (liveNocs.isEmpty()) return result;
        Id liveNocId = liveNocs[0].Id;

        List<FEC_Master_Data_Setting__c> liveSettings = [
            SELECT Name, FEC_Code__c, FEC_Section__c, FEC_Field_Mandatory__c,
                   FEC_Field_Status__c, FEC_Field_ReadOnly__c, FEC_Field_Order_Display__c,
                   FEC_Applicable_Role__c, FEC_Field_Editable__c, FEC_Editable_Role__c,
                   FEC_Field_Masking__c, FEC_Masking_Type__c, FEC_Field_Reverted__c,
                   FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c,
                   FEC_Sub_Section_Field_Layout__c,
                   FEC_Data_Integration_Mapping__c, FEC_Editable_User_Group__c,
                   FEC_Additional_Field__r.Name
            FROM FEC_Master_Data_Setting__c
            WHERE FEC_Nature_Of_Case__c = :liveNocId
        ];
        if (liveSettings.isEmpty()) return result;

        Set<String> liveCodes = new Set<String>();
        for (FEC_Master_Data_Setting__c l : liveSettings) {
            if (String.isNotBlank(l.FEC_Code__c)) liveCodes.add(l.FEC_Code__c);
        }

        Map<String, FEC_MDM_Master_Data_Setting__c> mdmMap = new Map<String, FEC_MDM_Master_Data_Setting__c>();
        if (!liveCodes.isEmpty()) {
            for (FEC_MDM_Master_Data_Setting__c mdm : [
                SELECT Name, FEC_Code__c, FEC_Section__c, FEC_Field_Mandatory__c,
                       FEC_Field_Status__c, FEC_Field_ReadOnly__c, FEC_Field_Order_Display__c,
                       FEC_Applicable_Role__c, FEC_Field_Editable__c, FEC_Editable_Role__c,
                       FEC_Field_Masking__c, FEC_Masking_Type__c, FEC_Field_Reverted__c,
                       FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c,
                       FEC_Sub_Section_Field_Layout__c,
                       FEC_Data_Integration_Mapping__c, FEC_Editable_User_Group__c,
                       FEC_Additional_Field__r.Name, Process_Change_Status__c
                FROM FEC_MDM_Master_Data_Setting__c
                WHERE FEC_Code__c IN :liveCodes
            ]) {
                mdmMap.put(mdm.FEC_Code__c, mdm);
            }
        }

        // Build wrappers using existing constructor (mdm, live)
        // For records where MDM is missing → "New" on Live side (will sync to MDM at EOD)
        // For records where both exist with diffs → "Updated"
        for (FEC_Master_Data_Setting__c live : liveSettings) {
            FEC_MDM_Master_Data_Setting__c mdm = mdmMap.get(live.FEC_Code__c);
            if (mdm == null) {
                // Live exists, MDM does not yet — mark as "New" (will sync to MDM at EOD)
                // Create a placeholder wrapper without setting non-writeable fields
                FEC_MDM_Master_Data_Setting__c placeholder = new FEC_MDM_Master_Data_Setting__c(
                    FEC_Code__c = live.FEC_Code__c
                );
                FEC_MasterDataReviewController.ComparisonWrapper wrapped =
                    new FEC_MasterDataReviewController.ComparisonWrapper(placeholder, null);
                result.newList.add(wrapped);
            } else {
                FEC_MasterDataReviewController.ComparisonWrapper wrapped =
                    new FEC_MasterDataReviewController.ComparisonWrapper(mdm, live);
                if (wrapped.hasChanged) result.updateList.add(wrapped);
                else result.syncedList.add(wrapped);
            }
        }
        return result;
    }
}