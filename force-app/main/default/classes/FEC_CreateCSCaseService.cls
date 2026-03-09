global with sharing class FEC_CreateCSCaseService {
    
    // =================================================
    // SOAP ENTRY POINT (WSDL COMPATIBLE)
    // =================================================
    webservice static CreateCSCaseResponse CreateCSCaseRequest(
        CaseRequestType req
    ) {
        try {
            
            // -------------------------
            // BASIC NULL CHECK
            // -------------------------
            if (req == null) {
                return errorResponse(null, '110', 'Request is null');
            }
            
            // -------------------------
            // VALIDATION
            // -------------------------
            ValidationContext ctx = requestValidation(
                req.Sys,
            req.CustomerInfo,
            req.RequestInfo,
            req.CreatorInfo
                );
            
            // -------------------------
            // CREATE INTERACTION CASE
            // -------------------------
            FEC_CreateCaseHanlder.FEC_InteractionCaseDTO interactionDTO =
                new FEC_CreateCaseHanlder.FEC_InteractionCaseDTO();
            interactionDTO.channel = 'External';
            interactionDTO.subChannel = 'Other';
            
            FEC_CreateCaseHanlder.FEC_InteractionCaseResponse interactionResp =
                FEC_CreateCaseHanlder.createInteractionCase(interactionDTO);
            
            //--------------------------
            //CREATE CUSTOMER HISTORY IF CUSTOMER IS EXISTED
            //--------------------------
            CustomerResponse customerResp = getCustomerInfo(req.CustomerInfo.ContractOrAccountNumber);
            FEC_Customer_History__c custHistoryRec = new FEC_Customer_History__c();
            if(customerResp != null ){
                custHistoryRec.Name = customerResp.name;
                custHistoryRec.FEC_Account_Number__c = customerResp.contractOrAccountNumber;
                custHistoryRec.FEC_Case__c = interactionResp.caseId;
                custHistoryRec.FEC_CIF_Number__c = customerResp.cifNumber;
                insert custHistoryRec;
            }
            
            // -------------------------
            // CREATE CUSTOMER CASE
            // -------------------------
            FEC_CreateCaseHanlder.FEC_CustomerCaseDTO customerDTO =
                new FEC_CreateCaseHanlder.FEC_CustomerCaseDTO();
            
            customerDTO.businessProcessId = ctx.businessProcessId;
            customerDTO.productTypeId     = ctx.productTypeId;
            customerDTO.categoryId        = ctx.categoryId;
            customerDTO.subCategoryId     = ctx.subCategoryId;
            customerDTO.subCodeId         = ctx.subCodeId;
            
            customerDTO.customerName = req.CustomerInfo.Name;
            customerDTO.phoneNumber = req.CustomerInfo.PhoneNumber;
            customerDTO.userType    = req.CustomerInfo.UserType;
            if (customerResp != null){
                customerDTO.customerHistoryId = custHistoryRec.Id;
            }
            customerDTO.remarks     = req.RequestInfo.Remarks;
            
            Case customerCase = FEC_CreateCaseHanlder.createCustomerCase(
                customerDTO,
            interactionResp.caseId
                );
            
            // Reload to get Link ID
            customerCase = [
                SELECT Id, FEC_Link_ID__c
                FROM Case
                WHERE Id = :customerCase.Id
            ];
            
            String caseNo = extractCaseNo(customerCase);
            
            // -------------------------
            // UPLOAD DOCUMENTS (OPTIONAL)
            // -------------------------
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
            
            // -------------------------
            // SUCCESS RESPONSE
            // -------------------------
            return createCaseResponse(
                caseNo,
            req.Sys.TransactionID,
            'Case created successfully.'
                );
            
        } catch (ValidationException ve) {
            return errorResponse(ve.transactionId, ve.code, ve.getMessage());
        } catch (Exception e) {
            return errorResponse(
                req != null && req.Sys != null ? req.Sys.TransactionID : null,
            '500',
            'Internal server error: ' + e.getMessage()
                );
        }
    }
    
    // =================================================
    // VALIDATION
    // =================================================
    private static ValidationContext requestValidation(
        SysType sys,
    CustomerInfoType customer,
    RequestInfoType request,
    CreatorInfoType creator
    ) {
        ValidationContext ctx = new ValidationContext();
        
        if (sys == null) {
            throw new ValidationException(null, '110', 'Sys is missing');
        }
        
        if (String.isBlank(sys.TransactionID) || sys.TransactionID.length() > 36) {
            throw new ValidationException(null, '110', 'Invalid TransactionID');
        }
        
        validateCustomerInfo(customer, sys.TransactionID);
        
        if (request == null) {
            throw new ValidationException(sys.TransactionID, '110', 'RequestInfo is missing');
        }
        
        if (!String.isBlank(request.Remarks) && request.Remarks.length() > 4000) {
            throw new ValidationException(sys.TransactionID, '110', 'Remarks too long');
        }
        
        if (creator != null && !String.isBlank(creator.CreatorEmail)) {
            
            if (creator.CreatorEmail.length() > 255 ||
                !Pattern.matches(
                '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$',
            creator.CreatorEmail.toUpperCase()
            )) {
                
                throw new ValidationException(sys.TransactionID,'110','Invalid CreatorEmail');
            }
        }
        
        ctx.businessProcessId = validateCaseType(request.CaseType, sys.TransactionID).Id;
        ctx.productTypeId    = validateProductType(request.ProductType, sys.TransactionID).Id;
        ctx.categoryId       = validateCategory(request.Category, sys.TransactionID).Id;
        ctx.subCategoryId    = validateSubCategory(request.SubCategory, sys.TransactionID).Id;
        
        if (!String.isBlank(request.SubCode)) {
            ctx.subCodeId = validateSubCode(request.SubCode, sys.TransactionID).Id;
        }
        
        if(String.isBlank(request.SubCode)){
            throw new ValidationException(sys.TransactionID,'110','SubCode required');
        }
        
        if(String.isBlank(request.Remarks)){
            throw new ValidationException(sys.TransactionID,'110','Remarks required');
        }
        
        if(request.AdditionalInfo!=null){
            for(AdditionalInfoType a: request.AdditionalInfo){
                
                if(String.isBlank(a.ID))
                    throw new ValidationException(sys.TransactionID,'110','AdditionalInfo.ID required');
                
                if(String.isBlank(a.Value))
                    throw new ValidationException(sys.TransactionID,'110','AdditionalInfo.Value required');
            }
        }
        return ctx;
    }
    
    // =================================================
    // CUSTOMER VALIDATION
    // =================================================
    private static void validateCustomerInfo(CustomerInfoType c, String txnId) {
        if (c == null) {
            throw new ValidationException(txnId, '110', 'CustomerInfo is missing');
        }
        
        if (String.isBlank(c.Name) || c.Name.length() > 255) {
            throw new ValidationException(txnId, '110', 'Invalid customer name');
        }
        
        if (String.isBlank(c.UserType) || c.UserType.length() > 15) {
            throw new ValidationException(txnId, '110', 'Invalid user type');
        }
        
        if (String.isBlank(c.PhoneNumber)
            || c.PhoneNumber.length() > 15
            || !Pattern.matches('^[0-9+]{8,15}$', c.PhoneNumber)
        ) {
            throw new ValidationException(txnId, '110', 'Invalid phone number');
        }
        
        if (String.isBlank(c.EmailAddress)
            || c.EmailAddress.length() > 255
            || !Pattern.matches(
            '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$',
        c.EmailAddress.toUpperCase()
            )
        ) {
            throw new ValidationException(txnId, '110', 'Invalid email');
        }
        
        if(String.isBlank(c.NationalID) || c.NationalID.length()>15)
            throw new ValidationException(txnId,'110','Invalid NationalID');
        
        if(String.isBlank(c.ContractOrAccountNumber) || c.ContractOrAccountNumber.length()>255)
            throw new ValidationException(txnId,'110','Invalid ContractOrAccountNumber');
    }
    
    // =================================================
    // BUSINESS VALIDATION (unchanged logic)
    // =================================================
    // =================================================
    // VALIDATE CASE TYPE
    // =================================================
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
        
        if (caseType.length() > 255) {
            throw new ValidationException(
                transactionId,
            '110',
            'CaseType is invalid or no longer than 255 characters'
                );
        }
        
        List<FEC_Business_Process__c> processes = [
        SELECT Id, Name, FEC_Active__c
        FROM FEC_Business_Process__c
        WHERE Name = :caseType
        LIMIT 1
    ];
        
        if (processes.isEmpty() || processes[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '110',
            'CaseType is invalid or no longer than 255 characters'
                );
        }
        
        return processes[0];
    }
    
    // =================================================
    // VALIDATE PRODUCT TYPE
    // =================================================
    private static FEC_Product_Type__c validateProductType(
        String productType,
    String transactionId
    ) {
        if (String.isBlank(productType) || productType.length() > 255) {
            throw new ValidationException(
                transactionId,
            '110',
            'ProductType is blank or invalid or no longer than 255 characters'
                );
        }
        
        List<FEC_Product_Type__c> productTypes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Product_Type__c
        WHERE FEC_Name_VN__c = :productType
        LIMIT 1
    ];
        
        if (productTypes.isEmpty() || productTypes[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '110',
            'ProductType is blank or invalid or no longer than 255 characters'
                );
        }
        
        return productTypes[0];
    }
    
    // =================================================
    // VALIDATE CATEGORY
    // =================================================
    private static FEC_Category__c validateCategory(
        String category,
    String transactionId
    ) {
        if (String.isBlank(category) || category.length() > 255) {
            throw new ValidationException(
                transactionId,
            '110',
            'Category is blank or invalid or no longer than 255 characters'
                );
        }
        
        List<FEC_Category__c> categories = [
        SELECT Id, Name, FEC_Active__c
        FROM FEC_Category__c
        WHERE Name = :category
        LIMIT 1
    ];
        
        if (categories.isEmpty() || categories[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '110',
            'Category is blank or invalid or no longer than 255 characters'
                );
        }
        
        return categories[0];
    }
    
    // =================================================
    // VALIDATE SUB CATEGORY
    // =================================================
    private static FEC_Sub_Category__c validateSubCategory(
        String subCategory,
    String transactionId
    ) {
        if (String.isBlank(subCategory) || subCategory.length() > 255) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCategory is blank or invalid or no longer than 255 characters'
                );
        }
        
        List<FEC_Sub_Category__c> subCategories = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Category__c
        WHERE FEC_Name_VN__c = :subCategory
        LIMIT 1
    ];
        
        if (subCategories.isEmpty() || subCategories[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '110',
            'SubCategory is blank or invalid or no longer than 255 characters'
                );
        }
        
        return subCategories[0];
    }
    
    // =================================================
    // VALIDATE SUB CODE (OPTIONAL)
    // =================================================
    private static FEC_Sub_Code__c validateSubCode(
        String subCode,
    String transactionId
    ) {
        if (String.isBlank(subCode)) {
            return null;
        }
        
        if (subCode.length() > 255) {
            throw new ValidationException(
                transactionId,
            '110',
            'Subcode is invalid or no longer than 255 characters'
                );
        }
        
        List<FEC_Sub_Code__c> subCodes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Code__c
        WHERE FEC_Name_VN__c = :subCode
        LIMIT 1
    ];
        
        if (subCodes.isEmpty() || subCodes[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            '110',
            'Subcode is invalid or no longer than 255 characters'
                );
        }
        
        return subCodes[0];
    }
    
    
    // =================================================
    // HELPERS
    // =================================================
    private static String extractCaseNo(Case c) {
        if (c.FEC_Link_ID__c != null &&
            c.FEC_Link_ID__c.contains('>') &&
            c.FEC_Link_ID__c.contains('</')
        ) {
            return c.FEC_Link_ID__c.substringBetween('>', '</');
        }
        return c.Id;
    }
    
    public static void uploadFileToCase(Id caseId, String payload) {
        List<String> parts = payload.split('\\|');
        
        if(parts.size() != 3){
            throw new ValidationException(null,'110','Invalid upload payload format');
        }
        
        Blob body = EncodingUtil.base64Decode(parts[2]);
        
        ContentVersion cv = new ContentVersion();
        cv.Title = parts[0];
        cv.PathOnClient = parts[0];
        cv.VersionData = body;
        cv.FirstPublishLocationId = caseId;
        insert cv;
    }
    
    private static CreateCSCaseResponse createCaseResponse(
        String caseId, String txnId, String msg
    ) {
        CreateCSCaseResponse r = new CreateCSCaseResponse();
        r.Sys = new SysType2();
        r.Sys.TransactionID = txnId;
        r.Sys.DateTime_x = String.valueOf(System.now());
        r.Sys.Code = '1';
        r.Sys.Description = msg;
        r.CaseID = caseId;
        return r;
    }
    
    private static CreateCSCaseResponse errorResponse(
        String txnId, String code, String msg
    ) {
        CreateCSCaseResponse r = new CreateCSCaseResponse();
        r.Sys = new SysType2();
        r.Sys.TransactionID = txnId;
        r.Sys.DateTime_x = String.valueOf(System.now());
        r.Sys.Code = code;
        r.Sys.Description = msg;
        return r;
    }
    
    private static CustomerResponse getCustomerInfo(String accountContractNumber  ) {
        CustomerResponse resp = new CustomerResponse();
        FEC_GetCustomerList.ResponseWrapper res =
            FEC_GetCustomerList.getCustomerList(
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,                 // requestorId
        null,           // phoneNumber
        null,                  // isReferenceSearch
        null,          // fullName
        null,            // nationalId
        null,               // applicationId
        null,     // creditCardNumber
        accountContractNumber,     // accountNumber
        null, // contractNumber
        null,  // email
        null               // personId
            );
        
        System.debug('===== RESPONSE =====');
        System.debug(res);
        
        if (res == null || res.Customers == null || res.Customers.isEmpty()) {
            return null;
        }
        
        if (res.Sys != null) {
            System.debug('SYS CODE: ' + res.Sys.Code);
        }
        
        System.debug('CUSTOMER COUNT: ' + res.Count);
        
        FEC_GetCustomerList.Customer c = res.Customers[0];
        resp.name = c.FullName;
        resp.contractOrAccountNumber = accountContractNumber;
        resp.cifNumber = c.CIFNumber;
        return resp;
    }
    
    
    
    // =================================================
    // REQUEST / RESPONSE TYPES (WSDL)
    // =================================================
    global class CaseRequestType {
        webservice SysType Sys;
        webservice CustomerInfoType CustomerInfo;
        webservice RequestInfoType RequestInfo;
        webservice CreatorInfoType CreatorInfo;
    }
    
    global class SysType {
        webservice String Channel;
        webservice String TransactionID;
        webservice Datetime DateTime_x;
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
        webservice String CreatorEmail;
    }
    
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
    
    // =================================================
    // EXCEPTION
    // =================================================
    public class ValidationException extends Exception {
        public String transactionId;
        public String code;
        public ValidationException(String t, String c, String m) {
            transactionId = t;
            code = c;
            this.setMessage(m);
        }
    }
    
    private class ValidationContext {
        Id businessProcessId;
        Id productTypeId;
        Id categoryId;
        Id subCategoryId;
        Id subCodeId;
    }
    
    public class CustomerResponse {
        public String name;
        public String contractOrAccountNumber;
        public String cifNumber;
    }
    
}