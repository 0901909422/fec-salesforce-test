public with sharing class FEC_GetCSCaseStatusService {
    
    // -------------------------------------------------
    // MAIN SERVICE METHOD
    // -------------------------------------------------
    @AuraEnabled
    public static GetCSCaseStatusResponse GetCSCaseStatus(GetCSCaseStatusRequest req) {
        
        GetCSCaseStatusResponse response = new GetCSCaseStatusResponse();
        response.Sys = new SysType2();
        response.CaseResultInfo = new CaseResultInfoType();
        response.OriginalRequest = new OriginalRequestType();
        
        Boolean isSuccess = false;
        String errorMessage;
        String transactionId;
        
        if (req != null && req.Sys != null) {
            response.Sys.TransactionID = req.Sys.TransactionID;
            transactionId = req.Sys.TransactionID;
        }
        response.Sys.DateTime_x = String.valueOf(System.now());
        
        CaseResultInfoType result = new CaseResultInfoType();
        OriginalRequestType originalRequest = new OriginalRequestType();
        originalRequest.Sys = req.Sys;
        try {
            System.debug('=== START GetCSCaseStatus ===');
            System.debug('Request: ' + JSON.serialize(req));
            
            validateRequest(req);
            
            Case resultCase = getCaseById(req.CaseRequestInfo.CaseID);
            
            result.CaseID = resultCase.Id;
            result.CaseStatus = resultCase.FEC_Case_Status__c;
            result.Remarks = resultCase.FEC_Remarks__c;
            result.CreatedTime = String.valueOf(resultCase.CreatedDate);
            result.UpdatedTime = String.valueOf(resultCase.LastModifiedDate);
            
            
            
            
            //    đang thiếu EmailAddress;
            originalRequest.CustomerInfo = new CustomerInfoType();
            originalRequest.CustomerInfo.Name = resultCase.FEC_Customer_Name__c;
            originalRequest.CustomerInfo.PhoneNumber = req.CaseRequestInfo.PhoneNumber;
            originalRequest.CustomerInfo.NationalID = req.CaseRequestInfo.NationalID;
            originalRequest.CustomerInfo.UserType = req.CaseRequestInfo.UserType;
            originalRequest.CustomerInfo.ContractOrAccountNumber = req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber;
            originalRequest.CustomerInfo.EmailAddress = '';
            
            
            
            //     đang thiếu AdditionalInfo;
            
            
            originalRequest.RequestInfo = new RequestInfoType();
            FEC_Business_Process__c caseType = getCaseType(resultCase.FEC_Business_Process__c);
            originalRequest.RequestInfo.CaseType = caseType != null ? caseType.Name : null;
            
            FEC_Product_Type__c productType = getProductType(resultCase.FEC_Product_Type__c);
            originalRequest.RequestInfo.ProductType = productType != null ? productType.FEC_Name_VN__c : null;
            
            FEC_Category__c category = getCategory(resultCase.FEC_Category__c);
            originalRequest.RequestInfo.Category = category != null ? category.FEC_Name_VN__c : null;
            
            FEC_Sub_Category__c subCategory = getSubCategory(resultCase.FEC_SubCategory__c);
            originalRequest.RequestInfo.SubCategory = subCategory != null ? subCategory.FEC_Name_VN__c : null;
            
            FEC_Sub_Code__c subCode = getSubCode(resultCase.FEC_SubCode__c);
            originalRequest.RequestInfo.SubCode = subCode != null ? subCode.FEC_Name_VN__c : null;
            originalRequest.RequestInfo.Remarks = resultCase.FEC_Remarks__c;
            
            originalRequest.RequestInfo.AdditionalInfo = new AdditionalInfor();
            originalRequest.RequestInfo.AdditionalInfo.ID = '';
            originalRequest.RequestInfo.AdditionalInfo.Value = '';
            
            
            originalRequest.CreatorInfo = new CreatorInfoType();
            User creator = getCreatorInfo(resultCase.CreatedById);
            originalRequest.CreatorInfo.CreatorEmail = creator != null ? creator.Email : null;
            
            isSuccess = true;
            response.Sys.Code = 1;
            response.Sys.Description = 'Success';
            
        } catch (Exception e) {
            errorMessage = e.getMessage();
            
            System.debug('ERROR: ' + errorMessage);
            response.Sys.Code = 2;
            response.Sys.Description = errorMessage;
            response.CaseResultInfo = null;
            response.OriginalRequest = null;
        }
        
        if (isSuccess) {
            response.CaseResultInfo = result;
            response.OriginalRequest = originalRequest;
        }
        // ✅ LOG API (ALWAYS)
        logApiFull(
            'GetCSCaseStatus',   // endpoint name
        'POST',
        req,
        response,
        isSuccess,
        isSuccess ? '200' : '500',
        errorMessage,
        transactionId
            );
        
        return response;
    }
    
    
    private static Case getCaseById(String caseId) {
        String pattern = '%' + caseId + '%';
        
        List<Case> cases = [
        SELECT 
            Id,
            CaseNumber,
            OwnerId,
            CreatedById,
            CreatedDate,
            LastModifiedDate,
            FEC_Customer_Name__c,
            FEC_Phone_Number__c,
            FEC_National_ID_Passport_ID__c,
            FEC_Case_Status__c,
            FEC_Remarks__c,
            FEC_Account_or_Contract__c,
            FEC_Product_Type__c,
            FEC_Category__c,
            FEC_SubCategory__c,
            FEC_SubCode__c,
            FEC_Business_Process__c
        FROM Case
        WHERE FEC_ID_Search__c LIKE :pattern
        LIMIT 1
    ];
        
        if (cases.isEmpty()) {
            throw new ServiceException(
                System.Label.FEC_CS_CASE_NOT_FOUND_MSG + caseId
                );
        }
        
        return cases[0];
    }
    
    // =================================================
    // GET CASE TYPE
    // =================================================
    private static FEC_Business_Process__c getCaseType(String businessProcessID) {
        List<FEC_Business_Process__c> processes = [
        SELECT Id, Name, FEC_Active__c
        FROM FEC_Business_Process__c
        WHERE Id = :businessProcessID
        LIMIT 1
    ];
        
        return processes.isEmpty() ? null : processes[0];
    }
    
    // =================================================
    // GET PRODUCT TYPE
    // =================================================
    private static FEC_Product_Type__c getProductType(String productTypeID) {
        List<FEC_Product_Type__c> productTypes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Product_Type__c
        WHERE Id = :productTypeID
        LIMIT 1
    ];
        
        return productTypes.isEmpty() ? null : productTypes[0];
    }
    
    // =================================================
    // GET CATEGORY
    // =================================================
    private static FEC_Category__c getCategory(String categoryID) {
        List<FEC_Category__c> categories = [
        SELECT Id, Name, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Category__c
        WHERE Id = :categoryID
        LIMIT 1
    ];
        
        return categories.isEmpty() ? null : categories[0];
    }
    
    // =================================================
    // GET SUB CATEGORY
    // =================================================
    private static FEC_Sub_Category__c getSubCategory(String subCategoryID) {
        List<FEC_Sub_Category__c> subCategories = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Category__c
        WHERE Id = :subCategoryID
        LIMIT 1
    ];
        
        return subCategories.isEmpty() ? null : subCategories[0];
    }
    
    // =================================================
    // GET SUB CODE (OPTIONAL)
    // =================================================
    private static FEC_Sub_Code__c getSubCode(String subCodeID) {
        if (String.isBlank(subCodeID)) {
            return null;
        }
        
        List<FEC_Sub_Code__c> subCodes = [
        SELECT Id, FEC_Name_VN__c, FEC_Active__c
        FROM FEC_Sub_Code__c
        WHERE Id = :subCodeID
        LIMIT 1
    ];
        
        return subCodes.isEmpty() ? null : subCodes[0];
    }
    
    // -------------------------------------------------
    // GET CREATOR INFO
    // -------------------------------------------------
    private static User getCreatorInfo(String userId) {
        if (String.isBlank(userId)) {
            return null;
        }
        List<User> users = [
        SELECT Id, Name, Email
        FROM User
        WHERE Id = :userId
        LIMIT 1
    ];
        
        return users.isEmpty() ? null : users[0];
    }
    
    private static void validateRequest(GetCSCaseStatusRequest req){
        
        if(req==null) throw new ServiceException(System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG);
        
        if(req.Sys==null) throw new ServiceException(System.Label.FEC_CS_CASE_SYS_MISSING_MSG);
        
        if(String.isBlank(req.Sys.Channel))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CHANNEL_REQUIRED_MSG);
        
        
        
        // Channel required
        if(String.isBlank(req.Sys.Channel))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CHANNEL_REQUIRED_MSG);
        
        // FIX NEW #3 - Channel must exist
        if(!channelSet.contains(req.Sys.Channel)){
            throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_INVALID_CHANNEL_MSG + req.Sys.Channel);
        }
        
        // FIX #4 TransactionID required + <=36
        if(String.isBlank(req.Sys.TransactionID))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_REQUIRED_MSG);
        
        if(req.Sys.TransactionID.length()>36)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_MAX_MSG);
        
        if(!isISO8601(req.Sys.DateTime_x))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_DATETIME_INVALID_MSG);
        
        if(req.CaseRequestInfo==null)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CASEREQUESTINFO_REQUIRED_MSG);
        
        if(String.isBlank(req.CaseRequestInfo.CaseID))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CASEID_REQUIRED_MSG);
        
        if(String.isBlank(req.CaseRequestInfo.NationalID)) {
            throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_NATIONALID_REQUIRE_MSG);
        }
        
        if (req.CaseRequestInfo.IncludeFinishedRequest == null) {
            throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_INCLUDE_FINISHED_REQUEST_REQUIRE_MSG);
        }
        
        if(req.CaseRequestInfo.ContractOrAccountInfos == null)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_INFOS_REQUIRED_MSG);
        
        ContractOrAccountInfosType info = req.CaseRequestInfo.ContractOrAccountInfos;
        
        if(String.isBlank(info.ContractOrAccountNumber))
            throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_CONTRACT_OR_ACCOUNT_NUMBER_REQUIRE_MSG);
        
        if(info.ContractOrAccountNumber.length() > 255)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_NUMBER_MAX_MSG);
        
        if(String.isBlank(info.ProductType))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_PRODUCT_TYPE_REQUIRED_MSG);
        
        if(String.isBlank(req.CaseRequestInfo.PhoneNumber))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_PHONE_REQUIRED_MSG);
        
        if(String.isBlank(req.CaseRequestInfo.UserType))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_USERTYPE_REQUIRED_MSG);
        
        if(req.CaseRequestInfo.UserType.length()>15)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_USERTYPE_MAX_MSG);
    }
    
    private static Boolean isISO8601(String s){
        if(String.isBlank(s)) return false;
        try{
            Datetime.valueOfGmt(
                s.replace('T',' ').replace('Z','')
                );
            return true;
        }catch(Exception e){
            return false;
        }
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
            apiResponse.setBody(FEC_CommonUltils.serializeSafe(responseObj));
            
            FEC_CommonUltils.logApi(
                'GetCSCaseStatus',
            endpoint,
            method,
            FEC_CommonUltils.serializeSafe(requestObj),
            apiResponse,
            errorMessage
                );
            
        } catch (Exception e) {
            System.debug('LOG_API_ERROR: ' + e.getMessage());
        }
    }
    
    
    // Custom exception class
    private class ServiceException extends Exception {}
    // -------------------------------------------------
    // REQUEST TYPES
    // -------------------------------------------------
    public class GetCSCaseStatusRequest {
        @AuraEnabled public SysType Sys;
        @AuraEnabled public CaseRequestInfoType CaseRequestInfo;
    }
    
    public class SysType {
        @AuraEnabled public String Channel;
        @AuraEnabled public String TransactionID;
        @AuraEnabled public String  DateTime_x;
    }
    
    public class CaseRequestInfoType {
        @AuraEnabled public  ContractOrAccountInfosType ContractOrAccountInfos;
        @AuraEnabled public  String PhoneNumber;
        @AuraEnabled public  String UserType;
        @AuraEnabled public  String CaseID;
        @AuraEnabled public  Boolean IncludeFinishedRequest;
        @AuraEnabled public  String NationalID;
    }
    
    public class ContractOrAccountInfosType {
        @AuraEnabled public String ContractOrAccountNumber;
        @AuraEnabled public String ProductType;
    }
    
    // -------------------------------------------------
    // RESPONSE TYPES
    // -------------------------------------------------
    public class GetCSCaseStatusResponse {
        @AuraEnabled public SysType2 Sys;
        @AuraEnabled public CaseResultInfoType CaseResultInfo;
        @AuraEnabled public OriginalRequestType OriginalRequest;
    }
    
    public class SysType2 {
        @AuraEnabled public String TransactionID;
        @AuraEnabled public String DateTime_x;
        @AuraEnabled public Integer Code;
        @AuraEnabled public String Description;
    }
    
    public class CaseResultInfoType {
        @AuraEnabled public String CaseID;
        @AuraEnabled public String CaseStatus;
        @AuraEnabled public String Remarks;
        @AuraEnabled public String CreatedTime;
        @AuraEnabled public String UpdatedTime;
    }
    
    public class OriginalRequestType {
        @AuraEnabled public SysType Sys;
        @AuraEnabled public CustomerInfoType CustomerInfo;
        @AuraEnabled public RequestInfoType RequestInfo;
        @AuraEnabled public CreatorInfoType CreatorInfo;
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
        @AuraEnabled public String ProductType;
        @AuraEnabled public String Category;
        @AuraEnabled public String SubCategory;
        @AuraEnabled public String SubCode;
        @AuraEnabled public String Remarks;
        @AuraEnabled public AdditionalInfor AdditionalInfo;
    }
    
    
    public class AdditionalInfor {
        @AuraEnabled public String ID;
        @AuraEnabled public String Value;
    }
    
    public class CreatorInfoType {
        @AuraEnabled public String CreatorEmail;
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
}