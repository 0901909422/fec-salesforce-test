global with sharing class FEC_CreateCSCaseService {
    
    webservice static CreateCSCaseResponse CreateCSCase(CaseRequestType req) {
        try {
            
            // Validate request
            ValidationContext ctx = requestValidation(req);
            // Map<String, Id> rtMap = getRecordTypeIds();
            
            // Case interactionCase = new Case();
            // interactionCase.RecordTypeId = rtMap.get('Interaction');
            // interactionCase.FEC_Channel__c = 'External';
            // interactionCase.FEC_Sub_Channel__c = 'Other';
            // interactionCase.FEC_Final_Status__c = 'Open';
            // // Existing customer → set contract/account
            // // if (req.CustomerInfo.UserType == 'Existing' &&
            // // String.isNotBlank(req.CustomerInfo.ContractOrAccountNumber)) {
                //     //     interactionCase.FEC_Contract_or_Account_Number__c =
                //     //         req.CustomerInfo.ContractOrAccountNumber;
            // // }
            
            // insert interactionCase;
            FEC_CreateCaseHanlder.FEC_InteractionCaseDTO interactionDTO =
                new FEC_CreateCaseHanlder.FEC_InteractionCaseDTO();
            interactionDTO.channel = 'External';
            interactionDTO.subChannel = 'Other';
            
            FEC_CreateCaseHanlder.FEC_InteractionCaseResponse interactionCase =
                FEC_CreateCaseHanlder.createInteractionCase(interactionDTO);
            
            
            
            // Case customerCase = new Case();
            // customerCase.RecordTypeId = rtMap.get('Customer_Case');
            
            // // ----- Customer Info -----
            // customerCase.FEC_Customer_Name__c   = req.CustomerInfo.Name;
            // customerCase.FEC_Phone_Number__c    = req.CustomerInfo.PhoneNumber;
            // customerCase.FEC_Customer_Type__c   = req.CustomerInfo.UserType;
            // customerCase.FEC_National_ID__c     = req.CustomerInfo.NationalID;
            // customerCase.FEC_Email__c           = req.CustomerInfo.EmailAddress;
            
            // Existing customer → reuse contract/account
            // if (req.CustomerInfo.UserType == 'Existing') {
                //     customerCase.FEC_Contract_or_Account_Number__c =
                //         req.CustomerInfo.ContractOrAccountNumber;
            // }
            
            // ----- Request Info -----
            // customerCase.FEC_Business_Process__c = ctx.businessProcessId;
            // customerCase.FEC_Product_Type__c     = ctx.productTypeId;
            // customerCase.FEC_Category__c         = ctx.categoryId;
            // customerCase.FEC_SubCategory__c     = ctx.subCategoryId;
            // customerCase.FEC_SubCode__c         = ctx.subCodeId;
            // customerCase.FEC_Remarks__c          = req.RequestInfo.Remarks;
            
            // ----- Link Interaction -----
            // customerCase.FEC_Interaction__c = interactionCase.Id;
            // insert customerCase;
            
            FEC_CreateCaseHanlder.FEC_CustomerCaseDTO customerDTO =
                new FEC_CreateCaseHanlder.FEC_CustomerCaseDTO();
            customerDTO.customerName = req.CustomerInfo.Name;
            customerDTO.phoneNumber = req.CustomerInfo.PhoneNumber;
            customerDTO.userType = req.CustomerInfo.UserType;
            customerDTO.productTypeId = ctx.productTypeId;
            customerDTO.categoryId = ctx.categoryId;
            customerDTO.subCategoryId = ctx.subCategoryId;
            customerDTO.subCodeId = ctx.subCodeId;
            customerDTO.remarks = req.RequestInfo.Remarks;
            
            Case customerCase = FEC_CreateCaseHanlder.createCustomerCase(
                customerDTO,
            interactionCase.caseId
                );
            
            customerCase = [
                SELECT Id, FEC_Link_ID__c
                FROM Case
                WHERE Id = :customerCase.Id
            ];
            
            String linkId = customerCase.FEC_Link_ID__c != null
                ? customerCase.FEC_Link_ID__c
                : customerCase.Id;
            
            String raw = linkId;
            String caseNo;
            
            if (raw != null && raw.contains('>') && raw.contains('</')) {
                caseNo = raw.substringBetween('>', '</');
            }
            
            
            // ----- Upload Document (nếu có) -----
            if (req.RequestInfo.AdditionalInfo != null) {
                for (AdditionalInfoType info : req.RequestInfo.AdditionalInfo) {
                    if (
                        info != null &&
                        info.ID == 'UploadDocument' &&
                        String.isNotBlank(info.Value)
                    ) {
                        uploadFileToCase(customerCase.Id, info.Value);
                    }
                }
            }
            
            // -------------------------------------------------
            // RETURN RESPONSE
            
            CreateCSCaseResponse response = createCaseResponse(
                caseNo,
            req.Sys.TransactionID,
            'Case created successfully.'
                );
            
            return response;
        } catch (ValidationException ve) {
            return errorResponse(ve.transactionId, ve.code, ve.getMessage());
        } catch (Exception e) {
            return errorResponse(
                req != null ? req.Sys.TransactionID : null,
            '500',
            'Internal server error: ' + e.getMessage()
                );
        }
    }
    
    // --------------------------------------------------
    // HELPER METHODS
    // --------------------------------------------------
    private static Map<String, Id> getRecordTypeIds() {
        Map<String, Id> rtMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName IN ('Interaction', 'Customer_Case')
        ]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }
        return rtMap;
    }
    
    // -------------------------------------------------
    // VALIDATION HELPERS
    // -------------------------------------------------
    private static ValidationContext  requestValidation(CaseRequestType req)
    {
        ValidationContext context = new ValidationContext();
        if (req == null) {
            throw new ValidationException(null, 'REQUEST_NULL', 'Request cannot be null.');
        }
        if (req.CustomerInfo == null) {
            throw new ValidationException(req.Sys.TransactionID, 'CUSTOMERINFO_NULL', 'CustomerInfo is missing.');
        }
        if (req.RequestInfo == null) {
            throw new ValidationException(req.Sys.TransactionID, 'REQUESTINFO_NULL', 'RequestInfo is missing.');
        }else{
            FEC_Business_Process__c process =
                validateCaseType(req.RequestInfo.CaseType, req.Sys.TransactionID);
            context.businessProcessId = process.Id;
            
            FEC_Product_Type__c productType =
                validateProductType(req.RequestInfo.ProductType, req.Sys.TransactionID);
            context.productTypeId = productType.Id;
            
            FEC_Category__c category =
                validateCategory(req.RequestInfo.Category, req.Sys.TransactionID);
            context.categoryId = category.Id;
            
            FEC_Sub_Category__c subCategory =
                validateSubCategory(req.RequestInfo.SubCategory, req.Sys.TransactionID);
            context.subCategoryId = subCategory.Id;
            
            FEC_Sub_Code__c subCode =
                validateSubCode(req.RequestInfo.SubCode, req.Sys.TransactionID);
            context.subCodeId = subCode.Id;
        }
        
        return context;
    }
    
    
    
    private static FEC_Business_Process__c validateCaseType(
        String caseType,
    String transactionId
    ) {
        if (String.isBlank(caseType)) {
            throw new ValidationException(
                transactionId,
            '110',
            'Casetype is blank or invalid'
                );
        }
        
        List<FEC_Business_Process__c> processes = [
        SELECT Id, Name, FEC_Status__c
        FROM FEC_Business_Process__c
        WHERE Name = :caseType
        LIMIT 1
    ];
        
        if (processes.isEmpty()) {
            throw new ValidationException(
                transactionId,
            '110',
            'CaseType is blank or invalid "' + caseType + '"'
                );
        }
        
        if (processes[0].FEC_Status__c != true) {
            throw new ValidationException(
                transactionId,
            '111',
            'CaseType is inactive "' + caseType + '"'
                );
        }
        
        return processes[0];
    }
    
    private static FEC_Product_Type__c validateProductType(
        String productType,
    String transactionId
    ) {
        if (String.isBlank(productType)) {
            throw new ValidationException(
                transactionId,
            '110',
            'ProductType is blank or invalid'
                );
        }
        
        List<FEC_Product_Type__c> productTypes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Product_Type__c 
        WHERE FEC_Name_VN__c = :productType
        LIMIT 1
    ];
        
        if (productTypes.isEmpty()) {
            throw new ValidationException(
                transactionId,
            '110',
            'ProductType is blank or invalid "' + productType + '"'
                );
        }
        
        if (productTypes[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '111',
            'ProductType is inactive "' + productType + '"'
                );
        }
        
        return productTypes[0];
    }
    
    private static FEC_Category__c  validateCategory(
        String category,
    String transactionId
    ) {
        if (String.isBlank(category)) {
            throw new ValidationException(
                transactionId,
            '110',
            'Category is blank or invalid'
                );
        }
        
        List<FEC_Category__c> categories = [
        SELECT Id, Name, FEC_Active__c
        FROM FEC_Category__c
        WHERE Name = :category
        LIMIT 1
    ];
        
        if (categories.isEmpty()) {
            throw new ValidationException(
                transactionId,
            '110',
            'Category is blank or invalid "' + category + '"'
                );
        }
        
        if (categories[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '111',
            'Category is inactive "' + category + '"'
                );
        }
        
        return categories[0];
    }
    
    private static FEC_Sub_Category__c validateSubCategory(
        String subCategory,
    String transactionId
    ) {
        if (String.isBlank(subCategory)) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCategory is blank or invalid'
                );
        }
        
        List<FEC_Sub_Category__c> subCategories = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Category__c
        WHERE FEC_Name_VN__c = :subCategory
        LIMIT 1
    ];
        
        if (subCategories.isEmpty()) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCategory is blank or invalid "' + subCategory + '"'
                );
        }
        
        if (subCategories[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '111',
            'SubCategory is inactive "' + subCategory + '"'
                );
        }
        
        return subCategories[0];
    }
    
    private static FEC_Sub_Code__c  validateSubCode(
        String subCode,
    String transactionId
    ) {
        if (String.isBlank(subCode)) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCode is blank or invalid'
                );
        }
        
        List<FEC_Sub_Code__c> subCodes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Code__c
        WHERE FEC_Name_VN__c = :subCode
        LIMIT 1
    ];
        
        if (subCodes.isEmpty()) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCode is blank or invalid "' + subCode + '"'
                );
        }
        
        if (subCodes[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '111',
            'SubCode is inactive "' + subCode + '"'
                );
        }
        
        return subCodes[0];
    }
    
    
    public static void uploadFileToCase( Id caseId, String uploadFileContent ) {
        
        // Tách chuỗi
        List<String> parts = uploadFileContent.split('\\|');
        
        // Gán giá trị
        String fileName = parts[0];      // Sampletext.txt
        String extension = parts[1];     // txt
        String base64Body = parts[2];    // Base64 content
        
        Blob fileBody = EncodingUtil.base64Decode(base64Body);
        
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = fileBody;
        cv.FirstPublishLocationId = caseId;
        insert cv;
    }
    // -------------------------------------------------
    // SUCCESS RESPONSE HELPER
    // -------------------------------------------------
    private static CreateCSCaseResponse createCaseResponse(
        String customerCaseID,
    String transactionID,
    String message
    ) {
        CreateCSCaseResponse response = new CreateCSCaseResponse();
        response.Sys = new SysType2();
        response.Sys.TransactionID = transactionID;
        response.Sys.DateTime_x = String.valueOf(System.now());
        response.Sys.Code = '1';
        response.Sys.Description = message;
        response.CaseID = customerCaseID;
        return response;
    }
    
    // -------------------------------------------------
    // ERROR RESPONSE HELPER
    // -------------------------------------------------
    private static CreateCSCaseResponse errorResponse(
        String transactionID,
    String code,
    String message
    ) {
        CreateCSCaseResponse error = new CreateCSCaseResponse();
        error.Sys = new SysType2();
        error.Sys.TransactionID = transactionID;
        error.Sys.DateTime_x = String.valueOf(System.now());
        error.Sys.Code = code;
        error.Sys.Description = message;
        return error;
    }
    
    
    // -------------------------------------------------
    // REQUEST TYPES
    // -------------------------------------------------
    
    global class CaseRequestType {
        webservice SysType Sys;
        webservice CustomerInfoType CustomerInfo;
        webservice RequestInfoType RequestInfo;
        webservice CreatorInfoType CreatorInfo;
    }
    
    
    global class SysType {
        webservice  String Channel;
        webservice  String TransactionID;
        webservice  Datetime DateTime_x;
    }
    
    global class CustomerInfoType {
        webservice String Name;
        webservice String PhoneNumber;
        webservice String UserType;
        webservice String NationalID;
        webservice String ContractOrAccountNumber;
        webservice String EmailAddress;
    }
    
    global class RequestInfoType {
        webservice String CaseType;
        webservice String RequestType;
        webservice String ProductType;
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
        webservice String Remarks;
        webservice List<AdditionalInfoType> AdditionalInfo;
        
    }
    
    global class AdditionalInfoType {
        webservice String ID;
        webservice String Value;
    }
    
    global class CreatorInfoType {
        webservice String CreatorName;
        webservice String CreatorCode;
        webservice String CreatorDepartment;
        webservice String CreatorPosition;
    }
    
    // -------------------------------------------------
    // RESPONSE TYPES
    // -------------------------------------------------
    global class CreateCSCaseResponse {
        webservice SysType2 Sys;
        webservice String CaseID;
    }
    
    global class SysType2 {
        webservice String TransactionID;
        webservice String DateTime_x;
        webservice String Code;
        webservice String Description;
    }
    
    
    //-------------------------------------------------
    // Exception Class
    //-------------------------------------------------
    public class ValidationException extends Exception {
        public String transactionId;
        public String code;
        private String message;
        
        public ValidationException(String txnId, String errCode, String msg) {
            this.transactionId = txnId;
            this.code = errCode;
            this.message = msg;
        }
        
        public override String getMessage() {
            return message;
        }
    }
    
    //-------------------------------------------------
    private class ValidationContext {
        Id businessProcessId;
        Id productTypeId;
        Id categoryId;
        Id subCategoryId;
        Id subCodeId;
    }
}