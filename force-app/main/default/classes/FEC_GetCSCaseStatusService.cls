/**
 * SOAP webservice GetCSCaseStatus.
 * REST (raw SOAP XML): FEC_GetCSCaseStatusRestService → FEC_MyCaseSoapXml.
 */
global with sharing class FEC_GetCSCaseStatusService {
    
    // -------------------------------------------------
    // MAIN SERVICE METHOD
    // -------------------------------------------------
    
    webService static GetCSCaseStatusResponse GetCSCaseStatus(GetCSCaseStatusRequest req) {
        
        GetCSCaseStatusResponse response = new GetCSCaseStatusResponse();
        response.Sys = new SysType2();
        
        Boolean isSuccess = false;
        String errorMessage;
        String transactionId;
        
        if (req != null && req.Sys != null) {
            response.Sys.TransactionID = req.Sys.TransactionID;
            transactionId = req.Sys.TransactionID;
        }
        response.Sys.DateTime_x = String.valueOf(System.now());
        
        response.CaseResultInfos = new List<CaseResultInfoType>();
        
        try {
            System.debug('=== START GetCSCaseStatus ===');
            System.debug('Request: ' + JSON.serialize(req));
            
            validateRequest(req);
            
            List<Case> cases = getCases(
                req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber,
            req.CaseRequestInfo.CaseID,
            req.CaseRequestInfo.NationalID,
            req.CaseRequestInfo.PhoneNumber
                );
            
            List<CaseResultInfoType> results =
                new List<CaseResultInfoType>();
            
            for (Case resultCase : cases) {
                
                CaseResultInfoType result =
                    new CaseResultInfoType();
                
                result.CaseID = resultCase.Id;
                result.CaseStatus = resultCase.FEC_Case_Status__c;
                result.Remarks = resultCase.FEC_Remarks__c;
                result.CreatedTime =
                    String.valueOf(resultCase.CreatedDate);
                result.UpdatedTime =
                    String.valueOf(resultCase.LastModifiedDate);
                
                OriginalRequestType originalRequest =
                    new OriginalRequestType();
                
                originalRequest.Sys = req.Sys;
                
                // CustomerInfo
                originalRequest.CustomerInfo =
                    new CustomerInfoType();
                
                originalRequest.CustomerInfo.Name =
                    resultCase.FEC_Customer_Name__c;
                
                originalRequest.CustomerInfo.PhoneNumber =
                    resultCase.FEC_Phone_Number__c;
                
                originalRequest.CustomerInfo.NationalID =
                    resultCase.FEC_National_ID_Passport_ID__c;
                
                originalRequest.CustomerInfo.UserType =
                    req.CaseRequestInfo.UserType;
                
                originalRequest.CustomerInfo.ContractOrAccountNumber =
                    resultCase.FEC_Account_Contract_Number_Text__c;
                
                originalRequest.CustomerInfo.EmailAddress = '';
                
                // RequestInfo
                originalRequest.RequestInfo =
                    new RequestInfoType();
                
                FEC_Business_Process__c caseType =
                    getCaseType(resultCase.FEC_Business_Process__c);
                
                originalRequest.RequestInfo.CaseType =
                    caseType != null ? caseType.Name : null;
                
                FEC_Product_Type__c productType =
                    getProductType(resultCase.FEC_Product_Type__c);
                
                originalRequest.RequestInfo.ProductType =
                    productType != null
                    ? productType.FEC_Name_VN__c
                    : null;
                
                FEC_Category__c category =
                    getCategory(resultCase.FEC_Category__c);
                
                originalRequest.RequestInfo.Category =
                    category != null
                    ? category.FEC_Name_VN__c
                    : null;
                
                FEC_Sub_Category__c subCategory =
                    getSubCategory(resultCase.FEC_SubCategory__c);
                
                originalRequest.RequestInfo.SubCategory =
                    subCategory != null
                    ? subCategory.FEC_Name_VN__c
                    : null;
                
                FEC_Sub_Code__c subCode =
                    getSubCode(resultCase.FEC_SubCode__c);
                
                originalRequest.RequestInfo.SubCode =
                    subCode != null
                    ? subCode.FEC_Name_VN__c
                    : null;
                
                originalRequest.RequestInfo.Remarks =
                    resultCase.FEC_Remarks__c;
                
                originalRequest.RequestInfo.AdditionalInfo =
                    getAdditionalInfo(resultCase.Id);
                
                // CreatorInfo
                originalRequest.CreatorInfo =
                    new CreatorInfoType();
                
                User creator =
                    getCreatorInfo(resultCase.CreatedById);
                
                originalRequest.CreatorInfo.CreatorEmail =
                    creator != null ? creator.Email : null;
                
                result.OriginalRequest = originalRequest;
                
                results.add(result);
            }
            
            response.CaseResultInfos = results;
            
            isSuccess = true;
            response.Sys.Code = 1;
            response.Sys.Description = 'Success';
            
        } catch (Exception e) {
            
            errorMessage = e.getMessage();
            
            System.debug('ERROR: ' + errorMessage);
            
            response.Sys.Code = 2;
            response.Sys.Description = errorMessage;
            
            response.CaseResultInfos = null;
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
    
    private static List<Case> getCases(
        String accountNumber,
    String caseId,
    String nationalId,
    String phoneNumber
    ) {
        
        String soql =
            'SELECT ' +
            'Id,' +
            'CaseNumber,' +
            'OwnerId,' +
            'CreatedById,' +
            'CreatedDate,' +
            'LastModifiedDate,' +
            'FEC_Customer_Name__c,' +
            'FEC_Phone_Number__c,' +
            'FEC_National_ID_Passport_ID__c,' +
            'FEC_Case_Status__c,' +
            'FEC_Remarks__c,' +
            'FEC_Account_or_Contract__c,' +
            'FEC_Account_Contract_Number_Text__c,' +
            'FEC_Product_Type__c,' +
            'FEC_Category__c,' +
            'FEC_SubCategory__c,' +
            'FEC_SubCode__c,' +
            'FEC_Business_Process__c ' +
            'FROM Case WHERE Id != null';
        
        if (!String.isBlank(accountNumber)) {
            soql +=
                ' AND FEC_Account_Contract_Number_Text__c = :accountNumber';
        }
        
        if (!String.isBlank(nationalId)) {
            soql +=
                ' AND FEC_National_ID_Passport_ID__c = :nationalId';
        }
        
        if (!String.isBlank(phoneNumber)) {
            soql +=
                ' AND FEC_Phone_Number__c = :phoneNumber';
        }
        
        if (!String.isBlank(caseId)) {
            String pattern = '%' + caseId + '%';
            
            soql +=
                ' AND FEC_ID_Search__c LIKE :pattern';
        }
        
        soql += ' ORDER BY CreatedDate DESC';
        
        List<Case> cases = Database.query(soql);
        
        if (cases.isEmpty()) {
            throw new ServiceException(
                System.Label.FEC_CS_CASE_NOT_FOUND_MSG
                );
        }
        
        return cases;
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
        
        
        
        // // Channel required
        // if(String.isBlank(req.Sys.Channel))
        //     throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CHANNEL_REQUIRED_MSG);
        
        // // FIX NEW #3 - Channel must exist
        // if(!channelSet.contains(req.Sys.Channel)){
            //     throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_INVALID_CHANNEL_MSG + req.Sys.Channel);
        // }
        
        validateChannel(req.Sys.Channel);
        
        // FIX #4 TransactionID required + <=36
        if(String.isBlank(req.Sys.TransactionID))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_REQUIRED_MSG);
        
        if(req.Sys.TransactionID.length()>36)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_MAX_MSG);
        
        if(!isISO8601(req.Sys.DateTime_x))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_DATETIME_INVALID_MSG);
        
        if(req.CaseRequestInfo==null)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CASEREQUESTINFO_REQUIRED_MSG);
        
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
    
    //----Get Addition Info-----//
    private static List<AdditionalInfor> getAdditionalInfo(Id caseId) {
        
        List<AdditionalInfor> result = new List<AdditionalInfor>();
        
        Map<String, Schema.SObjectField> fields =
            FEC_Additional_Info__c.SObjectType.getDescribe().fields.getMap();
        
        String soql =
            'SELECT ' + String.join(new List<String>(fields.keySet()), ',') +
            ' FROM FEC_Additional_Info__c' +
            ' WHERE FEC_Case__c = :caseId' +
            ' LIMIT 1';
        
        List<SObject> records = Database.query(soql);
        
        if (records.isEmpty()) {
            return result;
        }
        
        FEC_Additional_Info__c info =
            (FEC_Additional_Info__c)records[0];
        
        Map<String, Object> populatedFields =
            info.getPopulatedFieldsAsMap();
        
        Set<String> excludeFields = new Set<String>{
            'Id',
            'OwnerId',
            'CreatedDate',
            'CreatedById',
            'LastModifiedDate',
            'LastModifiedById',
            'SystemModstamp',
            'FEC_Case__c'
        };
        
        for (String fieldName : populatedFields.keySet()) {
            
            if (excludeFields.contains(fieldName)) {
                continue;
            }
            
            AdditionalInfor item = new AdditionalInfor();
            item.ID = fieldName;
            item.Value = String.valueOf(populatedFields.get(fieldName));
            
            result.add(item);
        }
        
        return result;
    }
    
    
    private static void validateChannel(String channel) {
        
        if (String.isBlank(channel)) {
            throw new ServiceException(
                System.Label.FEC_CS_CASE_STATUS_CHANNEL_REQUIRED_MSG
                );
        }
        
        String normalizedChannel = channel.trim();
        
        List<FEC_Channel__c> channels = [
        SELECT Id
        FROM FEC_Channel__c
        WHERE FEC_Channel_ID__c = :normalizedChannel
        AND FEC_Channel_Status__c = true
        LIMIT 1
    ];
        
        if (channels.isEmpty()) {
            throw new ServiceException(
                System.Label.FEC_GET_CASE_STATUS_INVALID_CHANNEL_MSG + normalizedChannel
                );
        }
    }
    
    //-------------------------//
    
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
    global class GetCSCaseStatusRequest {
        webservice  SysType Sys;
        webservice  CaseRequestInfoType CaseRequestInfo;
    }
    
    global class SysType {
        webservice  String Channel;
        webservice  String TransactionID;
        webservice  String  DateTime_x;
    }
    
    global class CaseRequestInfoType {
        webservice   ContractOrAccountInfosType ContractOrAccountInfos;
        webservice   String PhoneNumber;
        webservice   String UserType;
        webservice   String CaseID;
        webservice   Boolean IncludeFinishedRequest;
        webservice   String NationalID;
    }
    
    global class ContractOrAccountInfosType {
        webservice  String ContractOrAccountNumber;
        webservice  String ProductType;
    }
    
    // -------------------------------------------------
    // RESPONSE TYPES
    // -------------------------------------------------
    global class GetCSCaseStatusResponse {
        webservice  SysType2 Sys;
        webservice List<CaseResultInfoType> CaseResultInfos;
    }
    
    global class SysType2 {
        webservice  String TransactionID;
        webservice  String DateTime_x;
        webservice  Integer Code;
        webservice  String Description;
    }
    
    // global class CaseResultInfoType {
        //     webservice  String CaseID;
        //     webservice  String CaseStatus;
        //     webservice  String Remarks;
        //     webservice  String CreatedTime;
        //     webservice  String UpdatedTime;
    // }
    
    global class CaseResultInfoType {
        
        webservice String CaseID;
        webservice String CaseStatus;
        webservice String Remarks;
        webservice String CreatedTime;
        webservice String UpdatedTime;
        
        webservice OriginalRequestType OriginalRequest;
    }
    
    global class OriginalRequestType {
        webservice  SysType Sys;
        webservice  CustomerInfoType CustomerInfo;
        webservice  RequestInfoType RequestInfo;
        webservice  CreatorInfoType CreatorInfo;
    }
    
    
    global class CustomerInfoType {
        webservice  String Name;
        webservice  String PhoneNumber;
        webservice  String UserType;
        webservice  String NationalID;
        webservice  String ContractOrAccountNumber;
        webservice  String EmailAddress;
    }
    
    global class RequestInfoType {
        webservice  String CaseType;
        webservice  String ProductType;
        webservice  String Category;
        webservice  String SubCategory;
        webservice  String SubCode;
        webservice  String Remarks;
        webservice List<AdditionalInfor> AdditionalInfo;
    }
    
    
    global class AdditionalInfor {
        webservice  String ID;
        webservice  String Value;
    }
    
    global class CreatorInfoType {
        webservice  String CreatorEmail;
    }
    
    
}