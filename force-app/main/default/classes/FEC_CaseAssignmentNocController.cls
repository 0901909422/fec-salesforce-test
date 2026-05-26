public with sharing class FEC_CaseAssignmentNocController {
    public class OptionItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public OptionItem(String optionLabel, String optionValue) {
            label = optionLabel;
            value = optionValue;
        }
    }

    public class AssignmentNocItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String productType;
        @AuraEnabled public String category;
        @AuraEnabled public String subCategory;
        @AuraEnabled public String subCode;
    }

    @AuraEnabled(cacheable=true)
    public static List<AssignmentNocItem> getNocItems(Id assignmentId) {
        List<AssignmentNocItem> items = new List<AssignmentNocItem>();
        if (assignmentId == null) {
            return items;
        }

        for (FEC_Case_Assignment_NOC__c noc : [
            SELECT
                Id,
                Name,
                FEC_Product_Type__r.Name,
                FEC_Category__r.Name,
                FEC_Sub_Category__r.Name,
                FEC_Sub_Code__r.Name
            FROM FEC_Case_Assignment_NOC__c
            WHERE FEC_Case_Assignment_Name__c = :assignmentId
            ORDER BY CreatedDate DESC
        ]) {
            AssignmentNocItem item = new AssignmentNocItem();
            item.id = noc.Id;
            item.name = noc.Name;
            item.productType = noc.FEC_Product_Type__r != null ? noc.FEC_Product_Type__r.Name : null;
            item.category = noc.FEC_Category__r != null ? noc.FEC_Category__r.Name : null;
            item.subCategory = noc.FEC_Sub_Category__r != null ? noc.FEC_Sub_Category__r.Name : null;
            item.subCode = noc.FEC_Sub_Code__r != null ? noc.FEC_Sub_Code__r.Name : null;
            items.add(item);
        }
        return items;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getProductTypeOptions() {
        List<OptionItem> options = new List<OptionItem>();
        for (AggregateResult ar : [
            SELECT FEC_Product_Type__c productTypeId, FEC_Product_Type__r.Name productTypeName
            FROM FEC_Nature_of_Case__c
            WHERE
                FEC_Active__c = true
                AND FEC_Product_Type__c != null
                AND FEC_Product_Type__r.FEC_Active__c = true
            GROUP BY FEC_Product_Type__c, FEC_Product_Type__r.Name
            ORDER BY FEC_Product_Type__r.Name
        ]) {
            options.add(new OptionItem(
                String.valueOf(ar.get('productTypeName')),
                String.valueOf(ar.get('productTypeId'))
            ));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getCategoryOptions(Id productTypeId) {
        List<OptionItem> options = new List<OptionItem>();
        if (productTypeId == null) {
            return options;
        }

        Set<String> categoryNames = new Set<String>();
        for (AggregateResult ar : [
            SELECT FEC_Category__r.Name categoryName
            FROM FEC_Nature_of_Case__c
            WHERE
                FEC_Active__c = true
                AND FEC_Product_Type__c = :productTypeId
                AND FEC_Category__c != null
                AND FEC_Category__r.FEC_Active__c = true
            GROUP BY FEC_Category__r.Name
        ]) {
            String categoryName = String.valueOf(ar.get('categoryName'));
            if (String.isNotBlank(categoryName)) {
                categoryNames.add(categoryName);
            }
        }

        if (categoryNames.isEmpty()) {
            return options;
        }

        List<String> sortedNames = new List<String>();
        sortedNames.addAll(categoryNames);
        sortedNames.sort();
        for (String categoryName : sortedNames) {
            options.add(new OptionItem(categoryName, categoryName));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getSubCategoryOptions(Id productTypeId, String categoryKey) {
        List<OptionItem> options = new List<OptionItem>();
        if (productTypeId == null || String.isBlank(categoryKey)) {
            return options;
        }

        for (AggregateResult ar : [
            SELECT FEC_Sub_Category__c subCategoryId, FEC_Sub_Category__r.Name subCategoryName
            FROM FEC_Nature_of_Case__c
            WHERE
                FEC_Active__c = true
                AND FEC_Product_Type__c = :productTypeId
                AND FEC_Category__r.Name = :categoryKey
                AND FEC_Sub_Category__c != null
                AND FEC_Sub_Category__r.FEC_Active__c = true
            GROUP BY FEC_Sub_Category__c, FEC_Sub_Category__r.Name
            ORDER BY FEC_Sub_Category__r.Name
        ]) {
            options.add(new OptionItem(
                String.valueOf(ar.get('subCategoryName')),
                String.valueOf(ar.get('subCategoryId'))
            ));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionItem> getSubCodeOptions(Id productTypeId, String categoryKey, Id subCategoryId) {
        List<OptionItem> options = new List<OptionItem>();
        if (productTypeId == null || String.isBlank(categoryKey) || subCategoryId == null) {
            return options;
        }

        for (AggregateResult ar : [
            SELECT FEC_Sub_Code__c subCodeId, FEC_Sub_Code__r.Name subCodeName
            FROM FEC_Nature_of_Case__c
            WHERE
                FEC_Active__c = true
                AND FEC_Product_Type__c = :productTypeId
                AND FEC_Category__r.Name = :categoryKey
                AND FEC_Sub_Category__c = :subCategoryId
                AND FEC_Sub_Code__c != null
                AND FEC_Sub_Code__r.FEC_Active__c = true
            GROUP BY FEC_Sub_Code__c, FEC_Sub_Code__r.Name
            ORDER BY FEC_Sub_Code__r.Name
        ]) {
            options.add(new OptionItem(
                String.valueOf(ar.get('subCodeName')),
                String.valueOf(ar.get('subCodeId'))
            ));
        }
        return options;
    }

    @AuraEnabled
    public static Id createNoc(
        Id assignmentId,
        Id productTypeId,
        String categoryKey,
        Id subCategoryId,
        Id subCodeId
    ) {
        if (assignmentId == null) {
            throw new AuraHandledException('Case Assignment is required.');
        }

        List<FEC_Case_Assignment__c> parentAssignments = [
            SELECT Id, FEC_Status__c
            FROM FEC_Case_Assignment__c
            WHERE Id = :assignmentId
            LIMIT 1
        ];
        if (parentAssignments.isEmpty()) {
            throw new AuraHandledException('Case Assignment was not found.');
        }
        if (
            parentAssignments[0].FEC_Status__c !=
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        ) {
            throw new AuraHandledException(
                'You can only add Case Assignment NOC when Case Assignment Status is Draft.'
            );
        }

        Id categoryId = resolveProductCategoryId(categoryKey);

        FEC_Case_Assignment_NOC__c noc = new FEC_Case_Assignment_NOC__c(
            FEC_Case_Assignment_Name__c = assignmentId,
            FEC_Product_Type__c = productTypeId,
            FEC_Category__c = categoryId,
            FEC_Sub_Category__c = subCategoryId,
            FEC_Sub_Code__c = subCodeId
        );
        insert noc;
        return noc.Id;
    }

    @AuraEnabled
    public static Id updateNoc(
        Id nocId,
        Id productTypeId,
        String categoryKey,
        Id subCategoryId,
        Id subCodeId
    ) {
        if (nocId == null) {
            throw new AuraHandledException('Case Assignment NOC is required.');
        }

        List<FEC_Case_Assignment_NOC__c> existingRows = [
            SELECT Id, FEC_Case_Assignment_Name__c, FEC_Case_Assignment_Name__r.FEC_Status__c
            FROM FEC_Case_Assignment_NOC__c
            WHERE Id = :nocId
            LIMIT 1
        ];
        if (existingRows.isEmpty()) {
            throw new AuraHandledException('Case Assignment NOC was not found.');
        }
        FEC_Case_Assignment_NOC__c existing = existingRows[0];
        if (
            existing.FEC_Case_Assignment_Name__r == null ||
            existing.FEC_Case_Assignment_Name__r.FEC_Status__c !=
            FEC_ConstantCommon.FEC_CASE_ASSIGNMENT_STATUS_DRAFT
        ) {
            throw new AuraHandledException(
                'You can only edit Case Assignment NOC when Case Assignment Status is Draft.'
            );
        }

        Id categoryId = resolveProductCategoryId(categoryKey);
        FEC_Case_Assignment_NOC__c noc = new FEC_Case_Assignment_NOC__c(
            Id = nocId,
            FEC_Product_Type__c = productTypeId,
            FEC_Category__c = categoryId,
            FEC_Sub_Category__c = subCategoryId,
            FEC_Sub_Code__c = subCodeId
        );
        update noc;
        return noc.Id;
    }

    private static final String DEFAULT_CATALOG_NAME = 'FEC Default Catalog';

    private static Id resolveProductCategoryId(String categoryKey) {
        if (String.isBlank(categoryKey)) {
            return null;
        }

        List<ProductCategory> existing = [
            SELECT Id, Name
            FROM ProductCategory
            WHERE Name = :categoryKey
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Id catalogId = resolveDefaultCatalogId();
        ProductCategory created = new ProductCategory(
            Name = categoryKey,
            CatalogId = catalogId,
            IsNavigational = false
        );
        insert created;
        return created.Id;
    }

    private static Id resolveDefaultCatalogId() {
        List<ProductCatalog> catalogs = [
            SELECT Id, Name
            FROM ProductCatalog
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!catalogs.isEmpty()) {
            return catalogs[0].Id;
        }

        ProductCatalog catalog = new ProductCatalog(Name = DEFAULT_CATALOG_NAME);
        insert catalog;
        return catalog.Id;
    }
}