/****************************************************************************************
 * File Name    : FEC_GetCSMasterDataByCodeService
 * Author       : Quangdv7
 * Date         : 2025-12-11
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-11     Quangdv7             Create
 
****************************************************************************************/

global with sharing class FEC_GetCSMasterDataByCodeService {

    // =========================================================================
    // CONSTANTS
    // =========================================================================
    private static final Integer MAX_LENGTH_STANDARD = 255;
    private static final Integer MAX_LENGTH_USER_TYPE = 15;
    private static final Set<String> VALID_CHANNELS = new Set<String>{ FEC_ConstantCommon.KEY_VALID_CHANNELS_WED, FEC_ConstantCommon.KEY_VALID_CHANNELS_MOBILE, FEC_ConstantCommon.KEY_VALID_CHANNELS_API, FEC_ConstantCommon.KEY_VALID_CHANNELS_PORTAL};
    
    // =========================================================================
    // MAIN
    // =========================================================================
    webservice static GetCSMasterDataByCodeResponse GetCSMasterDataByCodeRequest(
        SysRequestType Sys,
        MasterDataCodeType MasterDataCode,
        CustomerTypeRequest CustomerType,
        AdditionalInfoRequest AdditionalInfo,
        String Remarks
    ) {
        GetCSMasterDataByCodeResponse res = initResponse(Sys);

        try {
            // ===== VALIDATION SYS =====
            ValidationResult sysValidation = validateSys(Sys);
            if (!sysValidation.isValid) {
                res.Sys.Code = FEC_ConstantCommon.KEY_ERROR;
                res.Sys.Description = sysValidation.errorMessage;
                normalizeResponse(res);
                return res;
            }

            // ===== VALIDATION MASTER DATA CODE =====
            ValidationResult masterDataValidation = validateMasterDataCode(MasterDataCode);
            if (!masterDataValidation.isValid) {
                res.Sys.Code = FEC_ConstantCommon.KEY_ERROR;
                res.Sys.Description = masterDataValidation.errorMessage;
                normalizeResponse(res);
                return res;
            }

            // ===== VALIDATION CUSTOMER TYPE =====
            ValidationResult customerValidation = validateCustomerType(CustomerType);
            if (!customerValidation.isValid) {
                res.Sys.Code = FEC_ConstantCommon.KEY_ERROR;
                res.Sys.Description = customerValidation.errorMessage;
                normalizeResponse(res);
                return res;
            }

            // Extract values
            String productTypeCode = (MasterDataCode != null) ? MasterDataCode.ProductType : null;
            String caseTypeCode = (MasterDataCode != null) ? MasterDataCode.CaseType : null;
            String categoryCode = (MasterDataCode != null) ? MasterDataCode.Category : null;
            String subCategoryCode = (MasterDataCode != null) ? MasterDataCode.SubCategory : null;
            String subCode = (MasterDataCode != null) ? MasterDataCode.SubCode : null;
            String language = (CustomerType != null && String.isNotBlank(CustomerType.Language))
                             ? CustomerType.Language : FEC_ConstantCommon.LANGUAGE_EN;

            // Query Nature of Case records
            List<FEC_Nature_of_Case__c> records = queryNatureOfCase(
                productTypeCode,
                caseTypeCode,
                categoryCode,
                subCategoryCode,
                subCode
            );

            // Build hierarchy tree
            Map<String, DataItemType> productMap = buildHierarchy(records, language);

            for (DataItemType product : productMap.values()) {
                ensureFullChildLevelsForProduct(product);
            }

            // ===== Build Response =====
            res.RequestInfo = new RequestInfoType();
            res.RequestInfo.Category = FEC_CommonUltils.defaultToEmpty(categoryCode);
            res.RequestInfo.SubCategory = FEC_CommonUltils.defaultToEmpty(subCategoryCode);
            res.RequestInfo.SubCode = FEC_CommonUltils.defaultToEmpty(subCode);
            res.RequestInfo.ProductLineId = FEC_CommonUltils.defaultToEmpty(productTypeCode);
            res.RequestInfo.CaseType = FEC_CommonUltils.defaultToEmpty(caseTypeCode);
            res.RequestInfo.Remarks = FEC_CommonUltils.defaultToEmpty(Remarks);

            res.CustomerInfo = (CustomerType != null) ? CustomerType : new CustomerTypeRequest();
            if (res.CustomerInfo.Language == null) res.CustomerInfo.Language = FEC_ConstantCommon.STR_EMPTY;
            if (res.CustomerInfo.UserType == null) res.CustomerInfo.UserType = FEC_ConstantCommon.STR_EMPTY;

            res.AdditionalInfo = (AdditionalInfo != null) ? AdditionalInfo : new AdditionalInfoRequest();
            if (res.AdditionalInfo.ID == null) res.AdditionalInfo.ID = FEC_ConstantCommon.STR_EMPTY;
            if (res.AdditionalInfo.Value == null) res.AdditionalInfo.Value = FEC_ConstantCommon.STR_EMPTY;

            res.DataItems = new List<DataItemType>();
            if (!productMap.isEmpty()) {
                res.DataItems.addAll(productMap.values());
            } else {
                DataItemType emptyProduct = new DataItemType(FEC_ConstantCommon.STR_EMPTY, FEC_ConstantCommon.STR_EMPTY, FEC_ConstantCommon.STR_EMPTY, null, FEC_ConstantCommon.STR_EMPTY, FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT);
                ensureFullChildLevelsForProduct(emptyProduct);
                res.DataItems.add(emptyProduct);
            }

            res.Sys.Code = FEC_ConstantCommon.SUCCESS_MESSAGE;
            res.Sys.Description = System.Label.FEC_MSG_Get_CS_Data_Success;

        } catch (Exception e) {
            res.Sys.Code = FEC_ConstantCommon.KEY_ERROR;
            res.Sys.Description = FEC_ConstantCommon.KEY_ERROR + e.getMessage();
        }

        normalizeResponse(res);
        return res;
    }

    // =========================================================================
    // VALIDATION METHODS
    // =========================================================================
    
    /**
     * Validate Sys Request
     */
    private static ValidationResult validateSys(SysRequestType Sys) {
        ValidationResult result = new ValidationResult();
        
        if (Sys == null) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Sys_Null;
            return result;
        }

        // Validate Channel
        if (String.isBlank(Sys.Channel)) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Channel_Null;
            return result;
        }
        
        if (!VALID_CHANNELS.contains(Sys.Channel.toUpperCase())) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Channel_Null + Sys.Channel + '"';
            return result;
        }

        // Validate TransactionID
        if (String.isBlank(Sys.TransactionID)) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_TransactionId_Null;
            return result;
        }
        
        if (Sys.TransactionID.length() > MAX_LENGTH_STANDARD) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_TransactionId_Null + 
                                 Sys.TransactionID + System.Label.FEC_MSG_No_Longer;
            return result;
        }

        // Validate DateTime
        if (Sys.DateTime_x == null) {
            result.isValid = false;
            result.errorMessage = System.Label.FEC_MSG_Datetime_Null;
            return result;
        }

        result.isValid = true;
        return result;
    }

    /**
     * Validate Master Data Code
     */
    private static ValidationResult validateMasterDataCode(MasterDataCodeType MasterDataCode) {
        ValidationResult result = new ValidationResult();
        
        if (MasterDataCode == null) {
            result.isValid = true;
            return result;
        }

        // Validate ProductType
        if (String.isNotBlank(MasterDataCode.ProductType)) {
            if (MasterDataCode.ProductType.length() > MAX_LENGTH_STANDARD) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_ProductType_Null;
                return result;
            }
            
            if (!isValidProductType(MasterDataCode.ProductType)) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_ProductType_Null;
                return result;
            }
        }

        // Validate CaseType
        if (String.isNotBlank(MasterDataCode.CaseType)) {
            if (MasterDataCode.CaseType.length() > MAX_LENGTH_STANDARD) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_CaseType_Null;
                return result;
            }
            
            if (!isValidCaseType(MasterDataCode.CaseType)) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_CaseType_Null;
                return result;
            }
        }

        // Validate Category
        if (String.isNotBlank(MasterDataCode.Category)) {
            if (MasterDataCode.Category.length() > MAX_LENGTH_STANDARD) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_Category_Null;
            }
            
            if (!isValidCategory(MasterDataCode.Category)) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_Category_Null;
                return result;
            }
        }

        // Validate SubCategory
        if (String.isNotBlank(MasterDataCode.SubCategory)) {
            if (MasterDataCode.SubCategory.length() > MAX_LENGTH_STANDARD) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_SubCategory_Null;
                return result;
            }
            
            if (!isValidSubCategory(MasterDataCode.SubCategory)) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_SubCategory_Null;
                return result;
            }
        }

        // Validate SubCode
        if (String.isNotBlank(MasterDataCode.SubCode)) {
            if (MasterDataCode.SubCode.length() > MAX_LENGTH_STANDARD) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_SubCode_Null;
                return result;
            }
            
            if (!isValidSubCode(MasterDataCode.SubCode)) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_SubCode_Null;
                return result;
            }
        }

        result.isValid = true;
        return result;
    }

    /**
     * Validate Customer Type
     */
    private static ValidationResult validateCustomerType(CustomerTypeRequest CustomerType) {
        ValidationResult result = new ValidationResult();
        
        if (CustomerType == null) {
            result.isValid = true;
            return result;
        }

        // Validate UserType
        if (String.isNotBlank(CustomerType.UserType)) {
            if (CustomerType.UserType.length() > MAX_LENGTH_USER_TYPE) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_UserType_Null;
            }
            
            // Optional: Check if UserType is valid
            Set<String> validUserTypes = new Set<String>{ FEC_ConstantCommon.CASE_EXISTING_CUSTOMER, FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER, FEC_ConstantCommon.KEY_PROSPECT};
            if (!validUserTypes.contains(CustomerType.UserType.toUpperCase())) {
                result.isValid = false;
                result.errorMessage = System.Label.FEC_MSG_UserType_Null;
                return result;
            }
        }

        result.isValid = true;
        return result;
    }

    // =========================================================================
    // EXISTENCE CHECK METHODS
    // =========================================================================
    
    private static Boolean isValidProductType(String code) {
        Integer count = [
            SELECT COUNT()
            FROM FEC_Product_Type__c
            WHERE FEC_Code__c = :code
            AND FEC_Active__c = true
            LIMIT 1
        ];
        return count > 0;
    }

    private static Boolean isValidCaseType(String code) {
        Integer count = [
            SELECT COUNT()
            FROM FEC_Business_Process__c
            WHERE FEC_Code__c = :code
            AND FEC_Active__c = true
            LIMIT 1
        ];
        return count > 0;
    }

    private static Boolean isValidCategory(String code) {
        Integer count = [
            SELECT COUNT()
            FROM FEC_Category__c
            WHERE FEC_Code__c = :code
            AND FEC_Active__c = true
            LIMIT 1
        ];
        return count > 0;
    }

    private static Boolean isValidSubCategory(String code) {
        Integer count = [
            SELECT COUNT()
            FROM FEC_Sub_Category__c
            WHERE FEC_Code__c = :code
            AND FEC_Active__c = true
            LIMIT 1
        ];
        return count > 0;
    }

    private static Boolean isValidSubCode(String code) {
        Integer count = [
            SELECT COUNT()
            FROM FEC_Sub_Code__c
            WHERE FEC_Code__c = :code
            AND FEC_Active__c = true
            LIMIT 1
        ];
        return count > 0;
    }

    // =========================================================================
    // VALIDATION RESULT CLASS
    // =========================================================================
    private class ValidationResult {
        Boolean isValid;
        String errorMessage;
        
        ValidationResult() {
            this.isValid = false;
            this.errorMessage = FEC_ConstantCommon.STR_EMPTY;
        }
    }

    // =========================================================================
    // QUERY
    // =========================================================================
    private static List<FEC_Nature_of_Case__c> queryNatureOfCase(
        String productTypeCode,
        String caseTypeCode,
        String categoryCode,
        String subCategoryCode,
        String subCode
    ) {
        String query =
            'SELECT ' +
                'FEC_Customer_Type__c, ' +
                'FEC_Product_Type__r.FEC_Code__c, ' +
                'FEC_Product_Type__r.Name, ' +
                'FEC_Product_Type__r.FEC_Name_VN__c, ' +
                'FEC_Product_Type__r.FEC_Order__c, ' +
                'FEC_Business_Process__r.FEC_Code__c, ' +
                'FEC_Business_Process__r.Name, ' +
                'FEC_Business_Process__r.FEC_Name_VN__c, ' +
                'FEC_Business_Process__r.FEC_Order__c, ' +
                'FEC_Category__r.FEC_Code__c, ' +
                'FEC_Category__r.Name, ' +
                'FEC_Category__r.FEC_Name_VN__c, ' +
                'FEC_Category__r.FEC_Order__c, ' +
                'FEC_Sub_Category__r.FEC_Code__c, ' +
                'FEC_Sub_Category__r.Name, ' +
                'FEC_Sub_Category__r.FEC_Name_VN__c, ' +
                'FEC_Sub_Category__r.FEC_Order__c, ' +
                'FEC_Sub_Code__r.FEC_Code__c, ' +
                'FEC_Sub_Code__r.Name, ' +
                'FEC_Sub_Code__r.FEC_Name_VN__c, ' +
                'FEC_Sub_Code__r.FEC_Order__c ' +
            'FROM FEC_Nature_of_Case__c ' +
            'WHERE Id != null';

        if (String.isNotBlank(productTypeCode)) {
            query += ' AND FEC_Product_Type__r.FEC_Code__c = \'' + String.escapeSingleQuotes(productTypeCode) + '\'';
        }
        if (String.isNotBlank(caseTypeCode)) {
            query += ' AND FEC_Business_Process__r.FEC_Code__c = \'' + String.escapeSingleQuotes(caseTypeCode) + '\'';
        }
        if (String.isNotBlank(categoryCode)) {
            query += ' AND FEC_Category__r.FEC_Code__c = \'' + String.escapeSingleQuotes(categoryCode) + '\'';
        }
        if (String.isNotBlank(subCategoryCode)) {
            query += ' AND FEC_Sub_Category__r.FEC_Code__c = \'' + String.escapeSingleQuotes(subCategoryCode) + '\'';
        }
        if (String.isNotBlank(subCode)) {
            query += ' AND FEC_Sub_Code__r.FEC_Code__c = \'' + String.escapeSingleQuotes(subCode) + '\'';
        }

        return Database.query(query);
    }

    // =========================================================================
    // BUILD HIERARCHY
    // =========================================================================
    private static Map<String, DataItemType> buildHierarchy(
        List<FEC_Nature_of_Case__c> records,
        String language
    ) {
        Map<String, DataItemType> productMap = new Map<String, DataItemType>();

        for (FEC_Nature_of_Case__c noc : records) {
            if (noc.FEC_Product_Type__r == null ||
                String.isBlank(noc.FEC_Product_Type__r.FEC_Code__c)) {
                continue;
            }

            DataItemType product = getOrCreateProduct(productMap, noc, language);

            if (noc.FEC_Business_Process__r != null &&
                String.isNotBlank(noc.FEC_Business_Process__r.FEC_Code__c)) {

                ChildItemType caseType = getOrCreateChild(
                    product,
                    noc.FEC_Business_Process__r.FEC_Code__c,
                    FEC_CommonUltils.pickNameByLanguage(noc.FEC_Business_Process__r.Name, noc.FEC_Business_Process__r.FEC_Name_VN__c, language),
                    FEC_CommonUltils.defaultToEmpty(noc.FEC_Business_Process__r.FEC_Name_VN__c),
                    FEC_CommonUltils.toInt(noc.FEC_Business_Process__r.FEC_Order__c),
                    noc.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_CASETYPE
                );

                if (noc.FEC_Category__r != null &&
                    String.isNotBlank(noc.FEC_Category__r.FEC_Code__c)) {

                    ChildItemType category = getOrCreateChild(
                        caseType,
                        noc.FEC_Category__r.FEC_Code__c,
                        FEC_CommonUltils.pickNameByLanguage(noc.FEC_Category__r.Name, noc.FEC_Category__r.FEC_Name_VN__c, language),
                        FEC_CommonUltils.defaultToEmpty(noc.FEC_Category__r.FEC_Name_VN__c),
                        FEC_CommonUltils.toInt(noc.FEC_Category__r.FEC_Order__c),
                        noc.FEC_Customer_Type__c,
                        FEC_ConstantCommon.KEY_CATEGORY
                    );

                    if (noc.FEC_Sub_Category__r != null &&
                        String.isNotBlank(noc.FEC_Sub_Category__r.FEC_Code__c)) {

                        ChildItemType subCategory = getOrCreateChild(
                            category,
                            noc.FEC_Sub_Category__r.FEC_Code__c,
                            FEC_CommonUltils.pickNameByLanguage(noc.FEC_Sub_Category__r.Name, noc.FEC_Sub_Category__r.FEC_Name_VN__c, language),
                            FEC_CommonUltils.defaultToEmpty(noc.FEC_Sub_Category__r.FEC_Name_VN__c),
                            FEC_CommonUltils.toInt(noc.FEC_Sub_Category__r.FEC_Order__c),
                            noc.FEC_Customer_Type__c,
                            FEC_ConstantCommon.KEY_SUBCATEGORY
                        );

                        if (noc.FEC_Sub_Code__r != null &&
                            String.isNotBlank(noc.FEC_Sub_Code__r.FEC_Code__c)) {

                            getOrCreateChild(
                                subCategory,
                                noc.FEC_Sub_Code__r.FEC_Code__c,
                                FEC_CommonUltils.pickNameByLanguage(noc.FEC_Sub_Code__r.Name, noc.FEC_Sub_Code__r.FEC_Name_VN__c, language),
                                FEC_CommonUltils.defaultToEmpty(noc.FEC_Sub_Code__r.FEC_Name_VN__c),
                                FEC_CommonUltils.toInt(noc.FEC_Sub_Code__r.FEC_Order__c),
                                noc.FEC_Customer_Type__c,
                                FEC_ConstantCommon.KEY_SUBCODE
                            );
                        }
                    }
                }
            }
        }

        return productMap;
    }

    // =========================================================================
    // HELPER METHODS - CREATE / ENSURE CHILDREN
    // =========================================================================
    private static DataItemType getOrCreateProduct(
        Map<String, DataItemType> productMap,
        FEC_Nature_of_Case__c noc,
        String language
    ) {
        String pCode = noc.FEC_Product_Type__r.FEC_Code__c;

        DataItemType existing = productMap.get(pCode);
        if (existing != null) {
            return existing;
        }

        DataItemType product = new DataItemType(
            pCode,
            FEC_CommonUltils.pickNameByLanguage(noc.FEC_Product_Type__r.Name, noc.FEC_Product_Type__r.FEC_Name_VN__c, language),
            FEC_CommonUltils.defaultToEmpty(noc.FEC_Product_Type__r.FEC_Name_VN__c),
            FEC_CommonUltils.toInt(noc.FEC_Product_Type__r.FEC_Order__c),
            noc.FEC_Customer_Type__c,
            FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT
        );
        productMap.put(pCode, product);
        return product;
    }

    private static ChildItemType getOrCreateChild(
        DataItemType parent,
        String id,
        String name,
        String nameVN,
        Integer order,
        String applyTo,
        String type
    ) {
        if (parent.Children == null) parent.Children = new List<ChildItemType>();

        for (ChildItemType child : parent.Children) {
            if (child.ID == id) return child;
        }

        ChildItemType newChild = new ChildItemType();
        newChild.ID = FEC_CommonUltils.defaultToEmpty(id);
        newChild.Name = FEC_CommonUltils.defaultToEmpty(name);
        newChild.NameVN = FEC_CommonUltils.defaultToEmpty(nameVN);
        newChild.PosOrder = order;
        newChild.ApplyTo = FEC_CommonUltils.defaultToEmpty(applyTo);
        newChild.Type = FEC_CommonUltils.defaultToEmpty(type);
        parent.Children.add(newChild);
        return newChild;
    }

    private static ChildItemType getOrCreateChild(
        ChildItemType parent,
        String id,
        String name,
        String nameVN,
        Integer order,
        String applyTo,
        String type
    ) {
        if (parent.Children == null) parent.Children = new List<ChildItemType>();

        for (ChildItemType child : parent.Children) {
            if (child.ID == id) return child;
        }

        ChildItemType newChild = new ChildItemType();
        newChild.ID = FEC_CommonUltils.defaultToEmpty(id);
        newChild.Name = FEC_CommonUltils.defaultToEmpty(name);
        newChild.NameVN = FEC_CommonUltils.defaultToEmpty(nameVN);
        newChild.PosOrder = order;
        newChild.ApplyTo = FEC_CommonUltils.defaultToEmpty(applyTo);
        newChild.Type = FEC_CommonUltils.defaultToEmpty(type);
        parent.Children.add(newChild);
        return newChild;
    }

    private static ChildItemType newEmptyNode(String type) {
        ChildItemType node = new ChildItemType();
        node.ID = FEC_ConstantCommon.STR_EMPTY;
        node.Name = FEC_ConstantCommon.STR_EMPTY;
        node.NameVN = FEC_ConstantCommon.STR_EMPTY;
        node.PosOrder = null;
        node.ApplyTo = FEC_ConstantCommon.STR_EMPTY;
        node.Type = FEC_CommonUltils.defaultToEmpty(type);
        node.Children = new List<ChildItemType>();
        return node;
    }

    private static void ensureFullChildLevelsForProduct(DataItemType product) {
        if (product.Children == null) product.Children = new List<ChildItemType>();
        if (product.Children.isEmpty()) {
            product.Children.add(newEmptyNode(FEC_ConstantCommon.KEY_CASETYPE));
        }
        
        for (ChildItemType caseType : product.Children) {
            if (caseType.Children == null) caseType.Children = new List<ChildItemType>();
            if (caseType.Children.isEmpty()) {
                caseType.Children.add(newEmptyNode(FEC_ConstantCommon.KEY_CATEGORY));
            }
            
            for (ChildItemType category : caseType.Children) {
                if (category.Children == null) category.Children = new List<ChildItemType>();
                if (category.Children.isEmpty()) {
                    category.Children.add(newEmptyNode(FEC_ConstantCommon.KEY_SUBCATEGORY));
                }
                
                for (ChildItemType subCategory : category.Children) {
                    if (subCategory.Children == null) subCategory.Children = new List<ChildItemType>();
                    if (subCategory.Children.isEmpty()) {
                        subCategory.Children.add(newEmptyNode(FEC_ConstantCommon.KEY_SUBCODE));
                    }
                }
            }
        }
    }

    // =========================================================================
    // NORMALIZE
    // =========================================================================
    private static void normalizeResponse(GetCSMasterDataByCodeResponse res) {
        if (res == null) return;

        if (res.Sys == null) res.Sys = new SysResponseType();
        res.Sys.TransactionID =FEC_CommonUltils.defaultToEmpty(res.Sys.TransactionID);
        res.Sys.Code = FEC_CommonUltils.defaultToEmpty(res.Sys.Code);
        res.Sys.Description = FEC_CommonUltils.defaultToEmpty(res.Sys.Description);
        if (res.Sys.DateTime_x == null) res.Sys.DateTime_x = System.now();

        if (res.RequestInfo == null) res.RequestInfo = new RequestInfoType();
        res.RequestInfo.Category = FEC_CommonUltils.defaultToEmpty(res.RequestInfo.Category);
        res.RequestInfo.SubCategory = FEC_CommonUltils.defaultToEmpty(res.RequestInfo.SubCategory);
        res.RequestInfo.SubCode = FEC_CommonUltils.defaultToEmpty(res.RequestInfo.SubCode);
        res.RequestInfo.ProductLineId = FEC_CommonUltils.defaultToEmpty(res.RequestInfo.ProductLineId);
        res.RequestInfo.CaseType = FEC_CommonUltils.defaultToEmpty(res.RequestInfo.CaseType);
        res.RequestInfo.Remarks =FEC_CommonUltils.defaultToEmpty(res.RequestInfo.Remarks);

        if (res.CustomerInfo == null) res.CustomerInfo = new CustomerTypeRequest();
        res.CustomerInfo.UserType = FEC_CommonUltils.defaultToEmpty(res.CustomerInfo.UserType);
        res.CustomerInfo.Language = FEC_CommonUltils.defaultToEmpty(res.CustomerInfo.Language);

        if (res.AdditionalInfo == null) res.AdditionalInfo = new AdditionalInfoRequest();
        res.AdditionalInfo.ID = FEC_CommonUltils.defaultToEmpty(res.AdditionalInfo.ID);
        res.AdditionalInfo.Value = FEC_CommonUltils.defaultToEmpty(res.AdditionalInfo.Value);

        if (res.DataItems == null) res.DataItems = new List<DataItemType>();
        for (DataItemType di : res.DataItems) {
            di.ID = FEC_CommonUltils.defaultToEmpty(di.ID);
            di.Name = FEC_CommonUltils.defaultToEmpty(di.Name);
            di.NameVN = FEC_CommonUltils.defaultToEmpty(di.NameVN);
            di.ApplyTo = FEC_CommonUltils.defaultToEmpty(di.ApplyTo);
            di.Type = FEC_CommonUltils.defaultToEmpty(di.Type);
            if (di.Children == null) di.Children = new List<ChildItemType>();
            for (ChildItemType c1 : di.Children) {
                normalizeChild(c1);
            }
        }
    }

    private static void normalizeChild(ChildItemType node) {
        node.ID = FEC_CommonUltils.defaultToEmpty(node.ID);
        node.Name = FEC_CommonUltils.defaultToEmpty(node.Name);
        node.NameVN = FEC_CommonUltils.defaultToEmpty(node.NameVN);
        node.ApplyTo = FEC_CommonUltils.defaultToEmpty(node.ApplyTo);
        node.Type = FEC_CommonUltils.defaultToEmpty(node.Type);
        if (node.Children == null) node.Children = new List<ChildItemType>();
        for (ChildItemType child : node.Children) {
            normalizeChild(child);
        }
    }

    // =========================================================================
    // InitResponse 
    // =========================================================================
    private static GetCSMasterDataByCodeResponse initResponse(SysRequestType Sys) {
        GetCSMasterDataByCodeResponse res = new GetCSMasterDataByCodeResponse();
        res.Sys = new SysResponseType();
        res.Sys.TransactionID = (Sys != null) ? Sys.TransactionID : null;
        res.Sys.DateTime_x = System.now();
        res.Sys.Code = FEC_ConstantCommon.STR_EMPTY;
        res.Sys.Description = FEC_ConstantCommon.STR_EMPTY;
        res.RequestInfo = new RequestInfoType();
        res.CustomerInfo = new CustomerTypeRequest();
        res.AdditionalInfo = new AdditionalInfoRequest();
        res.DataItems = new List<DataItemType>();
        return res;
    }

    // =========================================================================
    // DTO CLASSES
    // =========================================================================
    global class SysRequestType {
        webservice String Channel;
        webservice String TransactionID;
        webservice Datetime DateTime_x;
    }

    global class MasterDataCodeType {
        webservice String ProductType;
        webservice String CaseType;
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
    }

    global class CustomerTypeRequest {
        webservice String UserType;
        webservice String Language;
    }

    global class AdditionalInfoRequest {
        webservice String ID;
        webservice String Value;
    }

    global class GetCSMasterDataByCodeResponse {
        webservice SysResponseType Sys;
        webservice RequestInfoType RequestInfo;
        webservice CustomerTypeRequest CustomerInfo;
        webservice AdditionalInfoRequest AdditionalInfo;
        webservice List<DataItemType> DataItems;
    }

    global class SysResponseType {
        webservice String TransactionID;
        webservice Datetime DateTime_x;
        webservice String Code;
        webservice String Description;
    }

    global class RequestInfoType {
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
        webservice String ProductLineId;
        webservice String CaseType;
        webservice String Remarks;
    }

    global class DataItemType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice String Type;
        webservice List<ChildItemType> Children;

        global DataItemType(
            String id, String name, String nameVN,
            Integer order, String applyTo, String type
        ) {
            this.ID = FEC_CommonUltils.defaultToEmpty(id);
            this.Name = FEC_CommonUltils.defaultToEmpty(name);
            this.NameVN = FEC_CommonUltils.defaultToEmpty(nameVN);
            this.PosOrder = order;
            this.ApplyTo = FEC_CommonUltils.defaultToEmpty(applyTo);
            this.Type = FEC_CommonUltils.defaultToEmpty(type);
            this.Children = new List<ChildItemType>();
        }
    }

    global class ChildItemType {
        webservice String ID;
        webservice String Name;
        webservice String NameVN;
        webservice Integer PosOrder;
        webservice String ApplyTo;
        webservice String Type;
        webservice List<ChildItemType> Children;

        global ChildItemType() {
            this.ID = FEC_ConstantCommon.STR_EMPTY;
            this.Name = FEC_ConstantCommon.STR_EMPTY;
            this.NameVN = FEC_ConstantCommon.STR_EMPTY;
            this.ApplyTo = FEC_ConstantCommon.STR_EMPTY;
            this.Type = FEC_ConstantCommon.STR_EMPTY;
            this.PosOrder = null;
            this.Children = new List<ChildItemType>();
        }
    }
}