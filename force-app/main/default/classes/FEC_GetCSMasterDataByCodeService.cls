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
                             ? CustomerType.Language : 'EN';

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
            res.RequestInfo.Category = ensureNotBlank(categoryCode);
            res.RequestInfo.SubCategory = ensureNotBlank(subCategoryCode);
            res.RequestInfo.SubCode = ensureNotBlank(subCode);
            res.RequestInfo.ProductLineId = ensureNotBlank(productTypeCode);
            res.RequestInfo.CaseType = ensureNotBlank(caseTypeCode);
            res.RequestInfo.Remarks = ensureNotBlank(Remarks);

            res.CustomerInfo = (CustomerType != null) ? CustomerType : new CustomerTypeRequest();
            if (res.CustomerInfo.Language == null) res.CustomerInfo.Language = '';
            if (res.CustomerInfo.UserType == null) res.CustomerInfo.UserType = '';

            res.AdditionalInfo = (AdditionalInfo != null) ? AdditionalInfo : new AdditionalInfoRequest();
            if (res.AdditionalInfo.ID == null) res.AdditionalInfo.ID = '';
            if (res.AdditionalInfo.Value == null) res.AdditionalInfo.Value = '';

            res.DataItems = new List<DataItemType>();
            if (!productMap.isEmpty()) {
                res.DataItems.addAll(productMap.values());
            } else {
                DataItemType emptyProduct = new DataItemType('', '', '', null, '', FEC_ConstantCommon.KEY_PRODUCT_TYPE_PRODUCT);
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
            this.errorMessage = '';
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
                    pickNameByLanguage(noc.FEC_Business_Process__r.Name, noc.FEC_Business_Process__r.FEC_Name_VN__c, language),
                    ensureNotBlank(noc.FEC_Business_Process__r.FEC_Name_VN__c),
                    toInt(noc.FEC_Business_Process__r.FEC_Order__c),
                    noc.FEC_Customer_Type__c,
                    FEC_ConstantCommon.KEY_CASETYPE
                );

                if (noc.FEC_Category__r != null &&
                    String.isNotBlank(noc.FEC_Category__r.FEC_Code__c)) {

                    ChildItemType category = getOrCreateChild(
                        caseType,
                        noc.FEC_Category__r.FEC_Code__c,
                        pickNameByLanguage(noc.FEC_Category__r.Name, noc.FEC_Category__r.FEC_Name_VN__c, language),
                        ensureNotBlank(noc.FEC_Category__r.FEC_Name_VN__c),
                        toInt(noc.FEC_Category__r.FEC_Order__c),
                        noc.FEC_Customer_Type__c,
                        FEC_ConstantCommon.KEY_CATEGORY
                    );

                    if (noc.FEC_Sub_Category__r != null &&
                        String.isNotBlank(noc.FEC_Sub_Category__r.FEC_Code__c)) {

                        ChildItemType subCategory = getOrCreateChild(
                            category,
                            noc.FEC_Sub_Category__r.FEC_Code__c,
                            pickNameByLanguage(noc.FEC_Sub_Category__r.Name, noc.FEC_Sub_Category__r.FEC_Name_VN__c, language),
                            ensureNotBlank(noc.FEC_Sub_Category__r.FEC_Name_VN__c),
                            toInt(noc.FEC_Sub_Category__r.FEC_Order__c),
                            noc.FEC_Customer_Type__c,
                            FEC_ConstantCommon.KEY_SUBCATEGORY
                        );

                        if (noc.FEC_Sub_Code__r != null &&
                            String.isNotBlank(noc.FEC_Sub_Code__r.FEC_Code__c)) {

                            getOrCreateChild(
                                subCategory,
                                noc.FEC_Sub_Code__r.FEC_Code__c,
                                pickNameByLanguage(noc.FEC_Sub_Code__r.Name, noc.FEC_Sub_Code__r.FEC_Name_VN__c, language),
                                ensureNotBlank(noc.FEC_Sub_Code__r.FEC_Name_VN__c),
                                toInt(noc.FEC_Sub_Code__r.FEC_Order__c),
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
            pickNameByLanguage(noc.FEC_Product_Type__r.Name, noc.FEC_Product_Type__r.FEC_Name_VN__c, language),
            ensureNotBlank(noc.FEC_Product_Type__r.FEC_Name_VN__c),
            toInt(noc.FEC_Product_Type__r.FEC_Order__c),
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
        newChild.ID = ensureNotBlank(id);
        newChild.Name = ensureNotBlank(name);
        newChild.NameVN = ensureNotBlank(nameVN);
        newChild.PosOrder = order;
        newChild.ApplyTo = ensureNotBlank(applyTo);
        newChild.Type = ensureNotBlank(type);
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
        newChild.ID = ensureNotBlank(id);
        newChild.Name = ensureNotBlank(name);
        newChild.NameVN = ensureNotBlank(nameVN);
        newChild.PosOrder = order;
        newChild.ApplyTo = ensureNotBlank(applyTo);
        newChild.Type = ensureNotBlank(type);
        parent.Children.add(newChild);
        return newChild;
    }

    private static ChildItemType newEmptyNode(String type) {
        ChildItemType node = new ChildItemType();
        node.ID = '';
        node.Name = '';
        node.NameVN = '';
        node.PosOrder = null;
        node.ApplyTo = '';
        node.Type = ensureNotBlank(type);
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
        res.Sys.TransactionID = ensureNotBlank(res.Sys.TransactionID);
        res.Sys.Code = ensureNotBlank(res.Sys.Code);
        res.Sys.Description = ensureNotBlank(res.Sys.Description);
        if (res.Sys.DateTime_x == null) res.Sys.DateTime_x = System.now();

        if (res.RequestInfo == null) res.RequestInfo = new RequestInfoType();
        res.RequestInfo.Category = ensureNotBlank(res.RequestInfo.Category);
        res.RequestInfo.SubCategory = ensureNotBlank(res.RequestInfo.SubCategory);
        res.RequestInfo.SubCode = ensureNotBlank(res.RequestInfo.SubCode);
        res.RequestInfo.ProductLineId = ensureNotBlank(res.RequestInfo.ProductLineId);
        res.RequestInfo.CaseType = ensureNotBlank(res.RequestInfo.CaseType);
        res.RequestInfo.Remarks = ensureNotBlank(res.RequestInfo.Remarks);

        if (res.CustomerInfo == null) res.CustomerInfo = new CustomerTypeRequest();
        res.CustomerInfo.UserType = ensureNotBlank(res.CustomerInfo.UserType);
        res.CustomerInfo.Language = ensureNotBlank(res.CustomerInfo.Language);

        if (res.AdditionalInfo == null) res.AdditionalInfo = new AdditionalInfoRequest();
        res.AdditionalInfo.ID = ensureNotBlank(res.AdditionalInfo.ID);
        res.AdditionalInfo.Value = ensureNotBlank(res.AdditionalInfo.Value);

        if (res.DataItems == null) res.DataItems = new List<DataItemType>();
        for (DataItemType di : res.DataItems) {
            di.ID = ensureNotBlank(di.ID);
            di.Name = ensureNotBlank(di.Name);
            di.NameVN = ensureNotBlank(di.NameVN);
            di.ApplyTo = ensureNotBlank(di.ApplyTo);
            di.Type = ensureNotBlank(di.Type);
            if (di.Children == null) di.Children = new List<ChildItemType>();
            for (ChildItemType c1 : di.Children) {
                normalizeChild(c1);
            }
        }
    }

    private static void normalizeChild(ChildItemType node) {
        node.ID = ensureNotBlank(node.ID);
        node.Name = ensureNotBlank(node.Name);
        node.NameVN = ensureNotBlank(node.NameVN);
        node.ApplyTo = ensureNotBlank(node.ApplyTo);
        node.Type = ensureNotBlank(node.Type);
        if (node.Children == null) node.Children = new List<ChildItemType>();
        for (ChildItemType child : node.Children) {
            normalizeChild(child);
        }
    }

    // =========================================================================
    // STRING / UTIL
    // =========================================================================
    private static String pickNameByLanguage(String nameEN, String nameVN, String language) {
        String lang = String.valueOf(language);
        if (lang != null && lang.toUpperCase() == 'VN') {
            return String.isNotBlank(nameVN) ? nameVN : (String.isNotBlank(nameEN) ? nameEN : '');
        }
        return String.isNotBlank(nameEN) ? nameEN : (String.isNotBlank(nameVN) ? nameVN : '');
    }

    private static String ensureNotBlank(String value) {
        return String.isNotBlank(value) ? value : '';
    }

    private static Integer toInt(Decimal d) {
        return d == null ? null : Integer.valueOf(d);
    }

    private static GetCSMasterDataByCodeResponse initResponse(SysRequestType Sys) {
        GetCSMasterDataByCodeResponse res = new GetCSMasterDataByCodeResponse();
        res.Sys = new SysResponseType();
        res.Sys.TransactionID = (Sys != null) ? Sys.TransactionID : null;
        res.Sys.DateTime_x = System.now();
        res.Sys.Code = '';
        res.Sys.Description = '';
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
            this.ID = ensureNotBlank(id);
            this.Name = ensureNotBlank(name);
            this.NameVN = ensureNotBlank(nameVN);
            this.PosOrder = order;
            this.ApplyTo = ensureNotBlank(applyTo);
            this.Type = ensureNotBlank(type);
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
            this.ID = '';
            this.Name = '';
            this.NameVN = '';
            this.ApplyTo = '';
            this.Type = '';
            this.PosOrder = null;
            this.Children = new List<ChildItemType>();
        }
    }
}