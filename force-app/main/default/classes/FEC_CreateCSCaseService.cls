public with sharing class FEC_CreateCSCaseService {
    
    
    
    // =================================================
    // SOAP ENTRY POINT (WSDL COMPATIBLE)
    // =================================================
    @AuraEnabled
    public static CreateCSCaseResponse CreateCSCaseRequest(
        CaseRequestType req
    ) {
        Boolean isSuccess = true;
        String errorMessage;
        CreateCSCaseResponse response;
        try {
            
            // -------------------------
            // BASIC NULL CHECK
            // -------------------------
            if (req == null) {
                return errorResponse(null, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG);
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
            
            CustomerResponse customerResp = getCustomerInfo(req.CustomerInfo.ContractOrAccountNumber);
            // -------------------------
            // CREATE INTERACTION CASE
            // -------------------------
            FEC_CreateCaseHandler.FEC_InteractionCaseDTO interactionDTO =
                new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();
            
            String subChannel = String.isNotBlank(req.Sys.SubChannel)? req.Sys.SubChannel.trim(): null;
            
            if (internalSystems.contains(subChannel)) {
                interactionDTO.channel = FEC_ConstantCommon.CHANNEL_INTERNAL;
                interactionDTO.subChannel = subChannel;
            } else if (externalSystems.contains(subChannel)) {
                interactionDTO.channel = FEC_ConstantCommon.CHANNEL_EXTERNAL;
                interactionDTO.subChannel = subChannel;
            } else {
                interactionDTO.channel = FEC_ConstantCommon.CHANNEL_EXTERNAL;
                interactionDTO.subChannel = FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME;
            }
            
            FEC_CreateCaseHandler.FEC_InteractionCaseResponse interactionResp =
                FEC_CreateCaseHandler.createInteractionCase(interactionDTO);
            
            //--------------------------
            //CREATE CUSTOMER HISTORY IF CUSTOMER IS EXISTED
            //--------------------------
            
            FEC_Customer_History__c custHistoryRec = new FEC_Customer_History__c();
            Id customerHistoryId = null;
            if(customerResp != null ){
                custHistoryRec.Name = customerResp.name;
                custHistoryRec.FEC_Account_Number__c = customerResp.contractOrAccountNumber;
                custHistoryRec.FEC_Case__c = interactionResp.caseId;
                custHistoryRec.FEC_CIF_Number__c = customerResp.cifNumber;
                insert custHistoryRec;
                
                customerHistoryId = custHistoryRec.Id;
            }
            
            if (customerHistoryId != null) {
                FEC_CreateCaseHandler.updateInteractionCaseWithCustomerHistory(
                    interactionResp.caseId,
                customerHistoryId
                    );
            }
            
            
            // -------------------------
            // CREATE CUSTOMER CASE
            // -------------------------
            FEC_CreateCaseHandler.FEC_CustomerCaseDTO customerDTO =
                new FEC_CreateCaseHandler.FEC_CustomerCaseDTO();
            
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
            
            Case customerCase = FEC_CreateCaseHandler.createCustomerCase(
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
            List<String> filePayloads = new List<String>();
            
            if (req.RequestInfo.AdditionalInfo != null) {
                for (AdditionalInfoType info : req.RequestInfo.AdditionalInfo) {
                    if (
                        info != null &&
                        info.ID == FEC_ConstantCommon.UPLOAD_DOCUMENT &&
                        String.isNotBlank(info.Value)
                    ) {
                        filePayloads.add(info.Value);
                    }
                }
            }
            
            if (!filePayloads.isEmpty()) {
                uploadFilesToCase(customerCase.Id, filePayloads);
            }
            
            // -------------------------
            // SUCCESS RESPONSE
            // -------------------------
            // return createCaseResponse(
            //     caseNo,
            // req.Sys.TransactionID,
            // System.Label.FEC_CREATE_CS_CASE_SUCCESSFULLY_MSG
            //     );
            // ===== RESPONSE =====
            response = createCaseResponse(
                caseNo,
            req.Sys.TransactionID,
            System.Label.FEC_CREATE_CS_CASE_SUCCESSFULLY_MSG
                );
            
        } catch (ValidationException ve) {
            isSuccess = false;
            return errorResponse(ve.transactionId, ve.code, ve.getMessage());
        } catch (Exception e) {
            isSuccess = false;
            return errorResponse(
                req != null && req.Sys != null ? req.Sys.TransactionID : null,
            '500',
            'Internal server error: ' + e.getMessage()
                );
        }
        
        // 🔥 ALWAYS LOG HERE (DUY NHẤT 1 CHỖ)
        logApiFull(
            'CreateCSCase',
        'POST',
        req,
        response,
        isSuccess,
        isSuccess ? '200' : '500',
        errorMessage,
        req != null && req.Sys != null ? req.Sys.TransactionID : null
            );
        
        return response;
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
            throw new ValidationException(null, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_SYS_MISSING_MSG);
        }
        
        if (String.isBlank(sys.TransactionID) || sys.TransactionID.length() > 36) {
            throw new ValidationException(null, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_TRANSACTION_ID_MSG);
        }
        validateDateTime(sys.DateTime_x,  sys.TransactionID);
        validateChannel(sys.Channel, sys.TransactionID);
        
        validateCustomerInfo(customer, sys.TransactionID);
        
        if (request == null) {
            throw new ValidationException(sys.TransactionID, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_REQUEST_INFO_MISSING_MSG);
        }
        
        if (!String.isBlank(request.Remarks) && request.Remarks.length() > 4000) {
            throw new ValidationException(sys.TransactionID, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_REMARKS_TOO_LONG_MSG);
        }
        
        if (creator != null && !String.isBlank(creator.CreatorEmail)) {
            
            if (creator.CreatorEmail.length() > 255 ||
                !Pattern.matches(FEC_ConstantCommon.PATTERN_EMAIL, creator.CreatorEmail.toUpperCase())
            ) {
                
                throw new ValidationException(sys.TransactionID,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_CREATOR_EMAIL_MSG);
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
            throw new ValidationException(sys.TransactionID,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_SUBCODE_REQUIRED_MSG);
        }
        
        if(String.isBlank(request.Remarks)){
            throw new ValidationException(sys.TransactionID,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_REMARKS_REQUIRED_MSG);
        }
        
        if(request.AdditionalInfo!=null){
            for(AdditionalInfoType a: request.AdditionalInfo){
                
                if(String.isBlank(a.ID))
                    throw new ValidationException(sys.TransactionID,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_ADDITIONAL_INFO_ID_REQUIRED_MSG);
                
                if(String.isBlank(a.Value))
                    throw new ValidationException(sys.TransactionID,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_ADDITIONAL_INFO_VALUE_REQUIRED_MSG);
            }
        }
        return ctx;
    }
    
    //==================================================
    // CHANNEL VALIDATION
    //==================================================
    
    private static void validateChannel(String channel, String txnId) {
        
        // Required check
        if (String.isBlank(channel)) {
            throw new ValidationException(
                txnId,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_CHANNEL_REQUIRED_MSG
                );
        }
        
        // Normalize (tránh lỗi do space / case)
        String normalizedChannel = channel.trim();
        
        // Validate value
        if (!channelSet.contains(normalizedChannel)) {
            throw new ValidationException(
                txnId,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_CHANNEL_INVALID_MSG
                );
        }
    }
    
    
    private static void validateDateTime(DateTime dateTime_x, String txnId) {
        
        // Required check
        if (dateTime_x == null) {
            throw new ValidationException(
                txnId,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_DATETIME_INVALID_MSG
                );
        }
    }
    
    
    // =================================================
    // CUSTOMER VALIDATION
    // =================================================
    private static void validateCustomerInfo(CustomerInfoType c, String txnId) {
        if (c == null) {
            throw new ValidationException(txnId, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_CUSTOMER_INFO_MISSING_MSG);
        }
        
        if (String.isBlank(c.Name) || c.Name.length() > 255) {
            throw new ValidationException(txnId, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_CUSTOMER_NAME_MSG);
        }
        
        if (String.isBlank(c.UserType) || c.UserType.length() > 15) {
            throw new ValidationException(txnId, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_USER_TYPE_MSG);
        }
        
        if (String.isBlank(c.PhoneNumber)
            || c.PhoneNumber.length() > 15
            || !Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, c.PhoneNumber)
        ) {
            throw new ValidationException(txnId, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_PHONE_NUMBER_MSG);
        }
        
        if (String.isBlank(c.EmailAddress)
            || c.EmailAddress.length() > 255
            || !Pattern.matches(
            FEC_ConstantCommon.PATTERN_EMAIL,
        c.EmailAddress.toUpperCase()
            )
        ) {
            throw new ValidationException(txnId, System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_EMAIL_ADDRESS_MSG);
        }
        
        if(String.isBlank(c.NationalID) || c.NationalID.length()>15)
            throw new ValidationException(txnId,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_NATIONAL_ID_MSG);
        
        if(String.isBlank(c.ContractOrAccountNumber) || c.ContractOrAccountNumber.length()>255)
            throw new ValidationException(txnId,System.Label.FEC_CS_CASE_ERROR_CODE, System.Label.FEC_CS_CASE_INVALID_CONTRACT_OR_ACCOUNT_NUMBER_MSG);
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_TYPE_REQUIRED_MSG
                );
        }
        
        if (caseType.length() > 255) {
            throw new ValidationException(
                transactionId,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_TYPE_TOO_LONG_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_TYPE_TOO_LONG_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_PRODUCT_TYPE_INVALID_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_PRODUCT_TYPE_INVALID_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_CATEGORY_INVALID_MSG
                );
        }
        
        List<FEC_Category__c> categories = [
        SELECT Id, Name,FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Category__c
        WHERE Name = :category
        LIMIT 1
    ];
        
        if (categories.isEmpty() || categories[0].FEC_Active__c != true) {
            throw new ValidationException(
                transactionId,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_CATEGORY_INVALID_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_SUB_CATEGORY_INVALID_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_SUB_CATEGORY_INVALID_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_SUBCODE_TOO_LONG_MSG
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
            System.Label.FEC_CS_CASE_ERROR_CODE,
            System.Label.FEC_CS_CASE_SUBCODE_TOO_LONG_MSG
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
    
    private static void uploadFilesToCase(Id caseId, List<String> payloads) {
        
        List<ContentVersion> versions = new List<ContentVersion>();
        
        for (String payload : payloads) {
            
            List<String> parts = payload.split('\\|');
            
            if (parts.size() != 3) {
                continue; // skip invalid payload
            }
            
            Blob body = EncodingUtil.base64Decode(parts[2]);
            
            ContentVersion cv = new ContentVersion();
            cv.Title = parts[0];
            cv.PathOnClient = '/' + parts[0];
            cv.VersionData = body;
            cv.FirstPublishLocationId = caseId;
            
            versions.add(cv);
        }
        
        if (!versions.isEmpty()) {
            insert versions;
        }
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
        
        
        if (res == null || res.Customers == null || res.Customers.isEmpty()) {
            return null;
        }
        
        FEC_GetCustomerList.Customer c = res.Customers[0];
        resp.name = c.FullName;
        resp.contractOrAccountNumber = accountContractNumber;
        resp.cifNumber = c.CIFNumber;
        return resp;
    }
    
    private static void logApiFull(
        String endpoint,
    String method,
    Object requestObj,
    Object responseObj,
    Boolean isSuccess,
    String statusCode,
    String errorMessage,
    String transactionId
    ) {
        try {
            HttpResponse apiResponse = new HttpResponse();
            apiResponse.setStatusCode(isSuccess ? 200 : 500);
            apiResponse.setBody(serializeSafe(responseObj));
            
            FEC_CommonUltils.logApi(
                'CreateCSCase',
            endpoint,
            method,
            serializeSafe(requestObj),
            apiResponse,
            errorMessage
                );
            
        } catch (Exception e) {
            System.debug('LOG_API_ERROR: ' + e.getMessage());
        }
    }
    
    private static String serializeSafe(Object obj) {
        try {
            return obj != null ? JSON.serialize(obj) : null;
        } catch (Exception e) {
            return 'SERIALIZE_ERROR: ' + e.getMessage();
        }
    }
    
    private static String truncateLongString(String input) {
        Integer MAX_LENGTH = 30000; // adjust theo field length
        
        if (String.isBlank(input)) return input;
        
        return input.length() > MAX_LENGTH
            ? input.substring(0, MAX_LENGTH)
            : input;
    }
    
    // =================================================
    // REQUEST / RESPONSE TYPES (WSDL)
    // =================================================
    public class CaseRequestType {
        @AuraEnabled public SysType Sys;
        @AuraEnabled public CustomerInfoType CustomerInfo;
        @AuraEnabled public RequestInfoType RequestInfo;
        @AuraEnabled public CreatorInfoType CreatorInfo;
    }
    
    public class SysType {
        @AuraEnabled public String Channel;
        @AuraEnabled public String SubChannel;
        @AuraEnabled public String TransactionID;
        @AuraEnabled public Datetime DateTime_x;
    }
    
    public class CustomerInfoType {
        @AuraEnabled public String Name;
        @AuraEnabled public String PhoneNumber;
        @AuraEnabled public String UserType;
        @AuraEnabled public String NationalID;
        @AuraEnabled public String ContractOrAccountNumber;
        @AuraEnabled public String EmailAddress;
    }
    
    public class RequestInfoType {
        @AuraEnabled public String CaseType;
        @AuraEnabled public String RequestType;
        @AuraEnabled public String ProductType;
        @AuraEnabled public String Category;
        @AuraEnabled public String SubCategory;
        @AuraEnabled public String SubCode;
        @AuraEnabled public String Remarks;
        @AuraEnabled public List<AdditionalInfoType> AdditionalInfo;
    }
    
    public class AdditionalInfoType {
        @AuraEnabled public String ID;
        @AuraEnabled public String Value;
    }
    
    public class CreatorInfoType {
        @AuraEnabled public String CreatorName;
        @AuraEnabled public String CreatorCode;
        @AuraEnabled public String CreatorDepartment;
        @AuraEnabled public String CreatorPosition;
        @AuraEnabled public String CreatorEmail;
    }
    
    public class CreateCSCaseResponse {
        @AuraEnabled public SysType2 Sys;
        @AuraEnabled public String CaseID;
    }
    
    
    
    public class SysType2 {
        @AuraEnabled public String TransactionID;
        @AuraEnabled public String DateTime_x;
        @AuraEnabled public String Code;
        @AuraEnabled public String Description;
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
    
    private static Set<String> channelSet = new Set<String>{
        FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
        FEC_ConstantCommon.CHANNEL_OUTBOUND_NAME,
        FEC_ConstantCommon.CHANNEL_EMAIL_NAME,
        FEC_ConstantCommon.CHANNEL_LETTER_NAME,
        FEC_ConstantCommon.CHANNEL_F2F_NAME,
        FEC_ConstantCommon.CHANNEL_INTERNAL_NAME,
        FEC_ConstantCommon.CHANNEL_EXTERNAL_NAME
    };
    
    private static Set<String> internalSystems = new Set<String>{
        FEC_ConstantCommon.SYSTEM_SOURCE_VTIGER,
        FEC_ConstantCommon.SYSTEM_SOURCE_ISALE,
        FEC_ConstantCommon.SYSTEM_SOURCE_ICOLLECT
    };
    
    private static Set<String> externalSystems = new Set<String>{
        FEC_ConstantCommon.SYSTEM_SOURCE_WEBSITE,
        FEC_ConstantCommon.SYSTEM_SOURCE_FEOL,
        FEC_ConstantCommon.SYSTEM_SOURCE_ZALO
    };
}