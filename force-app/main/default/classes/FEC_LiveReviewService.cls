/**
 * @description Service layer for Review tab cascading filters + MDM↔Live comparison.
 *              Extracted from FEC_LiveDataViewController in Phase 2.4 refactor.
 * @author      DAT NGO
 * @date        2026-05-28
 * @category    MDM Refactor Phase 2.4
 */
public with sharing class FEC_LiveReviewService {

    public static List<Map<String, String>> getLiveReviewCustomerTypes() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Customer_Type__c ct
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Customer_Type__c != NULL
                GROUP BY FEC_Customer_Type__c
            ]) {
                String val = (String) ar.get(FEC_Constants.ALIAS_CT);
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => val,
                    FEC_UIConstants.MAP_VALUE => val
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveReviewProductOptions(String customerType) {
        if (String.isBlank(customerType)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Product_Type__r.Id pId, FEC_Product_Type__r.FEC_Code__c pCode
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Customer_Type__c = :customerType
                GROUP BY FEC_Product_Type__r.Id, FEC_Product_Type__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_P_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_P_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveReviewBizOptions(String productId) {
        if (String.isBlank(productId)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Business_Process__r.Id bId, FEC_Business_Process__r.FEC_Code__c bCode
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Product_Type__c = :productId
                GROUP BY FEC_Business_Process__r.Id, FEC_Business_Process__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_B_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_B_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveReviewCategoryOptions(String productId, String bizId) {
        if (String.isBlank(productId) || String.isBlank(bizId)) return new List<Map<String, String>>();
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Category__r.Id cId, FEC_Category__r.FEC_Code__c cCode
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Product_Type__c = :productId
                AND    FEC_Business_Process__c = :bizId
                GROUP BY FEC_Category__r.Id, FEC_Category__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_C_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_C_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveReviewSubCatOptions(String productId, String bizId, String catId) {
        if (String.isBlank(productId) || String.isBlank(bizId) || String.isBlank(catId)) {
            return new List<Map<String, String>>();
        }
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Sub_Category__r.Id scId, FEC_Sub_Category__r.FEC_Code__c scCode
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Product_Type__c = :productId
                AND    FEC_Business_Process__c = :bizId
                AND    FEC_Category__c = :catId
                GROUP BY FEC_Sub_Category__r.Id, FEC_Sub_Category__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SC_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SC_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static List<Map<String, String>> getLiveReviewSubCodeOptions(String productId, String bizId, String catId, String subCatId) {
        if (String.isBlank(productId) || String.isBlank(bizId) || String.isBlank(catId) || String.isBlank(subCatId)) {
            return new List<Map<String, String>>();
        }
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();
            for (AggregateResult ar : [
                SELECT FEC_Sub_Code__r.Id sccId, FEC_Sub_Code__r.FEC_Code__c sccCode
                FROM   FEC_Nature_Of_Case__c
                WHERE  FEC_Product_Type__c = :productId
                AND    FEC_Business_Process__c = :bizId
                AND    FEC_Category__c = :catId
                AND    FEC_Sub_Category__c = :subCatId
                GROUP BY FEC_Sub_Code__r.Id, FEC_Sub_Code__r.FEC_Code__c
            ]) {
                options.add(new Map<String, String>{
                    FEC_UIConstants.MAP_LABEL => (String) ar.get(FEC_Constants.ALIAS_SCC_CODE),
                    FEC_UIConstants.MAP_VALUE => (String) ar.get(FEC_Constants.ALIAS_SCC_ID)
                });
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    public static FEC_MasterDataReviewController.ComparisonResult getLiveReviewComparison(
        String productId, String bizId, String catId, String subCatId, String subCodeId
    ) {
        FEC_MasterDataReviewController.ComparisonResult finalResult = new FEC_MasterDataReviewController.ComparisonResult();

        if (String.isBlank(productId) || String.isBlank(bizId) ||
            String.isBlank(catId) || String.isBlank(subCatId) || String.isBlank(subCodeId)) {
            return finalResult;
        }

        try {
            List<SObject> safeNocs = queryMDMNocByFilter(productId, bizId, catId, subCatId, subCodeId);
            if (safeNocs.isEmpty()) return finalResult;
            Id mdmNocId = ((FEC_MDM_Nature_Of_Case__c) safeNocs[0]).Id;

            List<SObject> safeSettings = queryMDMSettingsByNoc(mdmNocId);
            if (safeSettings.isEmpty()) return finalResult;

            Set<String> mdmCodes = collectMDMCodes(safeSettings);
            Map<String, FEC_Master_Data_Setting__c> liveMap = queryLiveSettingsByCode(mdmCodes);

            categorizeSettings(safeSettings, liveMap, finalResult);
            return finalResult;
        } catch (Exception e) {
            throw new AuraHandledException(FEC_UIConstants.ERROR_GENERIC_PREFIX + ' ' + e.getMessage());
        }
    }

    private static List<SObject> queryMDMNocByFilter(String productId, String bizId, String catId, String subCatId, String subCodeId) {
        List<FEC_MDM_Nature_Of_Case__c> mdmNocs = [
            SELECT Id, FEC_Code__c
            FROM   FEC_MDM_Nature_Of_Case__c
            WHERE  FEC_Product_Type__c = :productId
            AND    FEC_Business_Process__c = :bizId
            AND    FEC_Category__c = :catId
            AND    FEC_Sub_Category__c = :subCatId
            AND    FEC_Sub_Code__c = :subCodeId
        ];
        return Security.stripInaccessible(AccessType.READABLE, mdmNocs).getRecords();
    }

    private static List<SObject> queryMDMSettingsByNoc(Id mdmNocId) {
        List<FEC_MDM_Master_Data_Setting__c> mdmSettings = [
            SELECT Name, FEC_Code__c, FEC_MDM_Channel__c, FEC_MDM_Channel__r.Name,
                   FEC_Stage_Name__c, FEC_Section__c, FEC_Field_Mandatory__c,
                   FEC_Additional_Field__r.Name, Process_Change_Status__c
            FROM   FEC_MDM_Master_Data_Setting__c
            WHERE  FEC_Nature_Of_Case__c = :mdmNocId
        ];
        return Security.stripInaccessible(AccessType.READABLE, mdmSettings).getRecords();
    }

    private static Set<String> collectMDMCodes(List<SObject> safeSettings) {
        Set<String> mdmCodes = new Set<String>();
        for (SObject s : safeSettings) {
            FEC_MDM_Master_Data_Setting__c m = (FEC_MDM_Master_Data_Setting__c) s;
            if (String.isNotBlank(m.FEC_Code__c)) mdmCodes.add(m.FEC_Code__c);
        }
        return mdmCodes;
    }

    private static Map<String, FEC_Master_Data_Setting__c> queryLiveSettingsByCode(Set<String> mdmCodes) {
        Map<String, FEC_Master_Data_Setting__c> liveMap = new Map<String, FEC_Master_Data_Setting__c>();
        if (mdmCodes.isEmpty()) return liveMap;
        List<FEC_Master_Data_Setting__c> liveQuery = [
            SELECT Name, FEC_Code__c, FEC_Channel__c, FEC_Channel__r.Name,
                   FEC_Stage_Name__c, FEC_Section__c, FEC_Field_Mandatory__c
            FROM   FEC_Master_Data_Setting__c
            WHERE  FEC_Code__c IN :mdmCodes
        ];
        List<SObject> safeLive = Security.stripInaccessible(AccessType.READABLE, liveQuery).getRecords();
        for (SObject s : safeLive) {
            FEC_Master_Data_Setting__c live = (FEC_Master_Data_Setting__c) s;
            liveMap.put(live.FEC_Code__c, live);
        }
        return liveMap;
    }

    private static void categorizeSettings(
        List<SObject> safeSettings,
        Map<String, FEC_Master_Data_Setting__c> liveMap,
        FEC_MasterDataReviewController.ComparisonResult finalResult
    ) {
        for (SObject s : safeSettings) {
            FEC_MDM_Master_Data_Setting__c mdm = (FEC_MDM_Master_Data_Setting__c) s;
            FEC_MasterDataReviewController.ComparisonWrapper wrapped =
                new FEC_MasterDataReviewController.ComparisonWrapper(mdm, liveMap.get(mdm.FEC_Code__c));
            if (wrapped.isNew) {
                finalResult.newList.add(wrapped);
            } else if (wrapped.hasChanged) {
                finalResult.updateList.add(wrapped);
            } else {
                finalResult.syncedList.add(wrapped);
            }
        }
    }
}