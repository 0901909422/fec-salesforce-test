public with sharing class FEC_CaseEditNOCController {

    @AuraEnabled
    public static List<String> getProductTypeIds(String recordId) {
        try {
            List<String> productTypeIds = new List<String>();
            Case objCase = [SELECT Id, FEC_Customer_Type__c FROM Case WHERE Id = :recordId];
            User currentUser = [SELECT Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId()];
            List<AggregateResult> natureOfCases = [
                SELECT FEC_Product_Type__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
                    AND FEC_Customer_Type__c != null
                    AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
                    AND FEC_Product_Type__c != null
                GROUP BY FEC_Product_Type__c
            ];
            for (AggregateResult ar : natureOfCases) {
                productTypeIds.add(String.valueOf(ar.get('FEC_Product_Type__c')));
            }
            return productTypeIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getCategoryIds(String recordId, String productTypeId) {
        try {
            List<String> categoryIds = new List<String>();
            Case objCase = [SELECT Id, FEC_Customer_Type__c FROM Case WHERE Id = :recordId];
            User currentUser = [SELECT Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId()];
            List<AggregateResult> natureOfCases = [
                SELECT FEC_Category__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
                    AND FEC_Customer_Type__c != null
                    AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
                    AND FEC_Product_Type__c = :productTypeId
                    AND FEC_Category__c != null
                GROUP BY FEC_Category__c
            ];
            for (AggregateResult ar : natureOfCases) {
                categoryIds.add(String.valueOf(ar.get('FEC_Category__c')));
            }
            return categoryIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getSubCategoryIds(String recordId, String productTypeId, String categoryId) {
        try {
            List<String> subCategoryIds = new List<String>();
            Case objCase = [SELECT Id, FEC_Customer_Type__c FROM Case WHERE Id = :recordId];
            User currentUser = [SELECT Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId()];
            List<AggregateResult> natureOfCases = [
                SELECT FEC_Sub_Category__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
                    AND FEC_Customer_Type__c != null
                    AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
                    AND FEC_Product_Type__c = :productTypeId
                    AND FEC_Category__c = :categoryId
                    AND FEC_Sub_Category__c != null
                GROUP BY FEC_Sub_Category__c
            ];
            for (AggregateResult ar : natureOfCases) {
                subCategoryIds.add(String.valueOf(ar.get('FEC_Sub_Category__c')));
            }
            return subCategoryIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<String> getSubCodeIds(String recordId, String productTypeId, String categoryId, String subCategoryId) {
        try {
            List<String> subCodeIds = new List<String>();
            Case objCase = [SELECT Id, FEC_Customer_Type__c FROM Case WHERE Id = :recordId];
            User currentUser = [SELECT Id, FEC_User_Group__c FROM User WHERE Id = :UserInfo.getUserId()];
            for (FEC_Nature_of_Case__c noc : [
                SELECT FEC_Sub_Code__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_User_Group__c INCLUDES (:currentUser.FEC_User_Group__c)
                    AND FEC_Customer_Type__c != null
                    AND FEC_Customer_Type__c = :objCase.FEC_Customer_Type__c
                    AND FEC_Product_Type__c = :productTypeId
                    AND FEC_Category__c = :categoryId
                    AND FEC_Sub_Category__c = :subCategoryId
                    AND FEC_Sub_Code__c != null
            ]) {
                subCodeIds.add(noc.FEC_Sub_Code__c);
            }
            return subCodeIds;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static FEC_Nature_of_Case__c getNatureOfCase(String productTypeId, String categoryId, String subCategoryId, String subCodeId) {
        try {
            List<FEC_Nature_of_Case__c> natureOfCases = [
                SELECT Id, FEC_Business_Process__c
                FROM FEC_Nature_of_Case__c
                WHERE FEC_Product_Type__c = :productTypeId
                    AND FEC_Category__c = :categoryId
                    AND FEC_Sub_Category__c = :subCategoryId
                    AND FEC_Sub_Code__c = :subCodeId
                LIMIT 1
            ];
            if (!natureOfCases.isEmpty()) {
                return natureOfCases.get(0);
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Case getCase(String recordId) {
        try {
            return [
                SELECT Id, CaseNumber, FEC_Account_or_Contract__c, 
                    FEC_Product_Type__c,
                    FEC_Category__c,
                    FEC_SubCategory__c,
                    FEC_SubCode__c
                FROM Case
                WHERE Id = :recordId
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}