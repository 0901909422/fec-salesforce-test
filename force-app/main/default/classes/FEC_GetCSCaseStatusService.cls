/**
 * SOAP webservice GetCSCaseStatus.
 * REST (raw SOAP XML): FEC_GetCSCaseStatusRestService → FEC_MyCaseSoapXml.
 */
global with sharing class FEC_GetCSCaseStatusService {

    private static final Set<String> COMPLAINT_OR_FEEDBACK_ALLOWED_CATEGORIES =
        new Set<String>{
            FEC_ConstantCommon.FEC_CATEGORY_FEEDBACK,
            FEC_ConstantCommon.FEC_CATEGORY_FEEDBACK_UB
        };

    private static final Set<String> ADDITIONAL_INFO_EXCLUDE_FIELDS = new Set<String>{
        'Id',
        'Name',
        'OwnerId',
        'CreatedDate',
        'CreatedById',
        'LastModifiedDate',
        'LastModifiedById',
        'SystemModstamp',
        'IsDeleted',
        'FEC_Case__c'
    };
    
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
            
            List<Case> cases = applyFrdCaseFilters(
                getCases(
                    req.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber,
                    req.CaseRequestInfo.ContractOrAccountInfos.ProductType,
                    req.CaseRequestInfo.CaseID,
                    req.CaseRequestInfo.NationalID,
                    req.CaseRequestInfo.PhoneNumber,
                    req.CaseRequestInfo.UserType,
                    req.CaseRequestInfo.IncludeFinishedRequest
                )
            );

            Set<Id> caseIds = new Set<Id>();
            for (Case resultCase : cases) {
                caseIds.add(resultCase.Id);
            }
            Map<Id, List<AdditionalInfor>> additionalInfoByCaseId =
                getAdditionalInfoBulk(caseIds);
            
            List<CaseResultInfoType> results =
                new List<CaseResultInfoType>();
            
            for (Case resultCase : cases) {
                
                CaseResultInfoType result =
                    new CaseResultInfoType();
                
                result.CaseID = resultCase.FEC_ID_Search__c;
                result.CaseStatus = mapCaseStatusForApi(resultCase.FEC_Case_Status__c);
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
                    resultCase.FEC_Account_or_Contract__r != null
                    ? resultCase.FEC_Account_or_Contract__r.FEC_Primary_Phone__c
                    : null;
                
                originalRequest.CustomerInfo.NationalID =
                    resultCase.FEC_Account_or_Contract__r != null
                    ? resultCase.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c
                    : null;
                
                originalRequest.CustomerInfo.UserType =
                    req.CaseRequestInfo.UserType;
                
                originalRequest.CustomerInfo.ContractOrAccountNumber =
                    resultCase.FEC_Account_Contract_Number_Text__c;
                
                originalRequest.CustomerInfo.EmailAddress =
                    resultCase.FEC_Account_or_Contract__r != null
                    ? resultCase.FEC_Account_or_Contract__r.FEC_Email__c
                    : null;
                
                
                originalRequest.RequestInfo = new RequestInfoType();
                // RequestInfo
                originalRequest.RequestInfo.CaseType =
                    resultCase.FEC_Business_Process__r != null
                    ? resultCase.FEC_Business_Process__r.Name
                    : null;
                
                originalRequest.RequestInfo.ProductType =
                    resultCase.FEC_Product_Type__r != null
                    ? resultCase.FEC_Product_Type__r.FEC_Name_VN__c
                    : null;
                
                originalRequest.RequestInfo.Category =
                    resultCase.FEC_Category__r != null
                    ? resultCase.FEC_Category__r.FEC_Name_VN__c
                    : null;
                
                originalRequest.RequestInfo.SubCategory =
                    resultCase.FEC_SubCategory__r != null
                    ? resultCase.FEC_SubCategory__r.FEC_Name_VN__c
                    : null;
                
                originalRequest.RequestInfo.SubCode =
                    resultCase.FEC_SubCode__r != null
                    ? resultCase.FEC_SubCode__r.FEC_Name_VN__c
                    : null;

                RequestTypeMapping requestTypeMapping =
                    resolveRequestTypeMapping(resultCase);
                originalRequest.RequestInfo.RequestType =
                    requestTypeMapping.requestType;
                originalRequest.RequestInfo.RequestTypeVN =
                    requestTypeMapping.requestTypeVn;
                originalRequest.RequestInfo.RequestTypeEN =
                    requestTypeMapping.requestTypeEn;
                
                originalRequest.RequestInfo.Remarks =
                    resultCase.FEC_Remarks__c;
                
                originalRequest.RequestInfo.AdditionalInfo =
                    additionalInfoByCaseId.containsKey(resultCase.Id)
                        ? additionalInfoByCaseId.get(resultCase.Id)
                        : new List<AdditionalInfor>();
                
                // CreatorInfo
                originalRequest.CreatorInfo =
                    new CreatorInfoType();
                
                originalRequest.CreatorInfo.CreatorEmail =
                    resultCase.CreatedBy != null
                    ? resultCase.CreatedBy.Email
                    : null;
                
                result.OriginalRequest = originalRequest;
                
                results.add(result);
            }
            
            response.TotalCases = results.size();
            response.CaseResultInfos = results;
            
            isSuccess = true;
            response.Sys.Code = 1;
            response.Sys.Description = 'Success';
            
        } catch (Exception e) {
            
            errorMessage =
                e.getMessage()
                + ' | line='
                + e.getLineNumber();
            
            response.Sys.Code = 2;
            response.Sys.Description = errorMessage;
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
    
    private static List<Case> getCases(
        String accountNumber,
        String productType,
        String caseId,
        String nationalId,
        String phoneNumber,
        String userType,
        Boolean includeFinishedRequest
    ) {
        String customerType = normalizeCustomerTypeForFilter(userType);
        
        String soql =
            'SELECT ' +
            'Id,' +
            'FEC_ID_Search__c,' +
            'CaseNumber,' +
            
        'OwnerId,' +
            'CreatedById,' +
            'CreatedBy.Email,' +
            'CreatedDate,' +
            'LastModifiedDate,' +
            
        'FEC_Customer_Name__c,' +
            'FEC_Phone_Number__c,' +
            'FEC_National_ID_Passport_ID__c,' +
            'FEC_Case_Status__c,' +
            'FEC_FCR__c,' +
            'FEC_Remarks__c,' +
            
        'FEC_Account_or_Contract__c,' +
            'FEC_Account_or_Contract__r.FEC_Email__c,' +
            'FEC_Account_or_Contract__r.FEC_Primary_Phone__c,' +
            'FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c,' +
            
        'FEC_Account_Contract_Number_Text__c,' +
            
        'FEC_Product_Type__c,' +
            'FEC_Product_Type__r.FEC_Name_VN__c,' +
            
        'FEC_Category__c,' +
            'FEC_Category__r.Name,' +
            'FEC_Category__r.FEC_Name_VN__c,' +
            
        'FEC_SubCategory__c,' +
            'FEC_SubCategory__r.Name,' +
            'FEC_SubCategory__r.FEC_Alias__c,' +
            'FEC_SubCategory__r.FEC_Name_VN__c,' +
            
        'FEC_SubCode__c,' +
            'FEC_SubCode__r.FEC_Name_VN__c,' +
            
        'FEC_Business_Process__c,' +
            'FEC_Business_Process__r.Name,' +
            'FEC_Business_Process__r.FEC_Name_VN__c,' +
            'FEC_Business_Process__r.FEC_Alias__c ' +
            
        'FROM Case ' +
            'WHERE RecordType.DeveloperName = \'Customer_Case\'' +
            ' AND (FEC_FCR__c = false OR FEC_FCR__c = null)';
        
        if (!String.isBlank(accountNumber)) {
            soql +=
                ' AND FEC_Account_Contract_Number_Text__c = :accountNumber';
        }

        if (!String.isBlank(productType)) {
            soql +=
                ' AND FEC_Product_Type__r.FEC_Name_VN__c = :productType';
        }

        if (!String.isBlank(customerType)) {
            soql += ' AND FEC_Customer_Type__c = :customerType';
        }

        if (includeFinishedRequest != true) {
            String resolvedStatusPattern =
                FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED + '%';
            soql +=
                ' AND (FEC_Case_Status__c = null OR NOT FEC_Case_Status__c LIKE :resolvedStatusPattern)';
        }
        
        if (!String.isBlank(nationalId)) {
            soql +=
                ' AND FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c = :nationalId';
        }
        
        if (!String.isBlank(phoneNumber)) {
            soql +=
                ' AND FEC_Account_or_Contract__r.FEC_Primary_Phone__c = :phoneNumber';
        }
        
        if (!String.isBlank(caseId)) {
            
            String pattern = '%' + caseId + '%';
            
            soql +=
                ' AND FEC_ID_Search__c LIKE :pattern';
        }
        
        soql += ' ORDER BY CreatedDate DESC';
        
        return Database.query(soql);
    }

    /**
     * CRP-1726: exclude FCR cases and apply Complaint/Feedback category rules.
     */
    private static List<Case> applyFrdCaseFilters(List<Case> cases) {
        List<Case> filtered = new List<Case>();
        if (cases == null || cases.isEmpty()) {
            return filtered;
        }

        for (Case resultCase : cases) {
            if (resultCase.FEC_FCR__c == true) {
                continue;
            }
            if (!isEligibleForComplaintOrFeedbackRules(resultCase)) {
                continue;
            }
            filtered.add(resultCase);
        }
        return filtered;
    }

    /**
     * Complaint Or Feedback case type: only Feedback / Feedback UB categories.
     */
    private static Boolean isEligibleForComplaintOrFeedbackRules(Case resultCase) {
        if (!isComplaintOrFeedbackCaseType(resultCase)) {
            return true;
        }

        String categoryName = resultCase.FEC_Category__r != null
            ? resultCase.FEC_Category__r.Name
            : null;
        return COMPLAINT_OR_FEEDBACK_ALLOWED_CATEGORIES.contains(categoryName);
    }

    private static Boolean isComplaintOrFeedbackCaseType(Case resultCase) {
        String businessProcessName = resultCase.FEC_Business_Process__r != null
            ? resultCase.FEC_Business_Process__r.Name
            : null;
        if (isComplaintOrFeedbackBusinessProcess(businessProcessName)) {
            return true;
        }

        String categoryName = resultCase.FEC_Category__r != null
            ? resultCase.FEC_Category__r.Name
            : null;
        return categoryName == FEC_ConstantCommon.FEC_CATEGORY_COMPLAINT
            || categoryName == FEC_ConstantCommon.FEC_CATEGORY_FEEDBACK
            || categoryName == FEC_ConstantCommon.FEC_CATEGORY_FEEDBACK_UB;
    }

    private static Boolean isComplaintOrFeedbackBusinessProcess(String businessProcessName) {
        if (String.isBlank(businessProcessName)) {
            return false;
        }
        return businessProcessName == FEC_ConstantCommon.BP_COMPLAINT_OR_FEEDBACK
            || businessProcessName == FEC_ConstantCommon.BP_COMPLAINT
            || businessProcessName == FEC_ConstantCommon.BP_FEEDBACK;
    }

    /** CRP-1726 §5.2.1 — map internal status to API Vietnamese label. */
    private static String mapCaseStatusForApi(String status) {
        if (String.isBlank(status)) {
            return FEC_ConstantCommon.GET_CASE_STATUS_VN_UNDEFINED;
        }
        if (status.startsWith(FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED)) {
            return FEC_ConstantCommon.GET_CASE_STATUS_VN_CLOSED;
        }
        if (status.startsWith('Pending')) {
            return FEC_ConstantCommon.GET_CASE_STATUS_VN_IN_PROGRESS;
        }
        if (status.equalsIgnoreCase('Open')) {
            return FEC_ConstantCommon.GET_CASE_STATUS_VN_OPEN;
        }
        return FEC_ConstantCommon.GET_CASE_STATUS_VN_UNDEFINED;
    }

    /**
     * CRP-1726 §5.2.4 — Request Type from Sub Category or Business Process master data.
     */
    private static RequestTypeMapping resolveRequestTypeMapping(Case resultCase) {
        RequestTypeMapping mapping = new RequestTypeMapping();
        if (usesSubCategoryRequestType(resultCase)) {
            if (resultCase.FEC_SubCategory__r != null) {
                mapping.requestType = firstNonBlank(
                    resultCase.FEC_SubCategory__r.FEC_Alias__c,
                    resultCase.FEC_SubCategory__r.FEC_Name_VN__c,
                    resultCase.FEC_SubCategory__r.Name
                );
                mapping.requestTypeVn = resultCase.FEC_SubCategory__r.FEC_Name_VN__c;
                mapping.requestTypeEn = resultCase.FEC_SubCategory__r.Name;
            }
            return mapping;
        }

        if (resultCase.FEC_Business_Process__r != null) {
            mapping.requestType = firstNonBlank(
                resultCase.FEC_Business_Process__r.FEC_Alias__c,
                resultCase.FEC_Business_Process__r.FEC_Name_VN__c,
                resultCase.FEC_Business_Process__r.Name
            );
            mapping.requestTypeVn = resultCase.FEC_Business_Process__r.FEC_Name_VN__c;
            mapping.requestTypeEn = resultCase.FEC_Business_Process__r.Name;
        }
        return mapping;
    }

    private static Boolean usesSubCategoryRequestType(Case resultCase) {
        String businessProcessName = resultCase.FEC_Business_Process__r != null
            ? resultCase.FEC_Business_Process__r.Name
            : null;
        if (businessProcessName == FEC_ConstantCommon.BP_GENERAL_SERVICE) {
            return true;
        }
        if (businessProcessName == FEC_ConstantCommon.BP_COMPLAINT_OR_FEEDBACK) {
            return true;
        }
        if (isComplaintOrFeedbackBusinessProcess(businessProcessName)) {
            return true;
        }
        if (String.isNotBlank(businessProcessName)
            && businessProcessName.contains(FEC_ConstantCommon.BP_GSR)) {
            return true;
        }
        return false;
    }

    private static String firstNonBlank(String first, String second, String third) {
        if (!String.isBlank(first)) {
            return first;
        }
        if (!String.isBlank(second)) {
            return second;
        }
        return third;
    }

    private class RequestTypeMapping {
        public String requestType;
        public String requestTypeVn;
        public String requestTypeEn;
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
        
        // if(!isISO8601(req.Sys.DateTime_x))
        //     throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_DATETIME_INVALID_MSG);
        
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

        if (isExistingUserType(req.CaseRequestInfo.UserType)
            && String.isBlank(req.CaseRequestInfo.NationalID)) {
            throw new ServiceException(
                System.Label.FEC_GET_CASE_STATUS_NATIONALID_REQUIRE_MSG
            );
        }
    }

    private static Boolean isExistingUserType(String userType) {
        if (String.isBlank(userType)) {
            return false;
        }
        return userType.equalsIgnoreCase(FEC_ConstantCommon.CASE_EXISTING_CUSTOMER)
            || userType.equalsIgnoreCase(FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE);
    }

    /**
     * Map request UserType (e.g. EXISTING) to Case.FEC_Customer_Type__c picklist API value.
     */
    private static String normalizeCustomerTypeForFilter(String userType) {
        if (String.isBlank(userType)) {
            return null;
        }

        String normalized = userType.trim();
        if (normalized.equalsIgnoreCase(FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE)
            || normalized.equalsIgnoreCase(FEC_ConstantCommon.CASE_EXISTING_CUSTOMER)) {
            return FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        }
        if (normalized.equalsIgnoreCase('NONEXISTING')
            || normalized.equalsIgnoreCase(FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER)
            || normalized.equalsIgnoreCase('Non-existing')) {
            return 'Non-existing';
        }
        if (normalized.equalsIgnoreCase('ALL')) {
            return 'All';
        }
        return normalized;
    }
    
    private static Boolean isISO8601(String s) {
        if (String.isBlank(s)) {
            return false;
        }
        
        try {
            String dt = s.replace('T', ' ').replace('Z', '');
            
            Integer dotIndex = dt.indexOf('.');
            if (dotIndex > -1) {
                dt = dt.substring(0, dotIndex);
            }
            
            Datetime.valueOfGmt(dt);
            return true;
            
        } catch (Exception e) {
            return false;
        }
    }
    
    //----Get Addition Info (bulk)-----//
    private static Map<Id, List<AdditionalInfor>> getAdditionalInfoBulk(Set<Id> caseIds) {
        Map<Id, List<AdditionalInfor>> resultByCaseId =
            new Map<Id, List<AdditionalInfor>>();

        if (caseIds == null || caseIds.isEmpty()) {
            return resultByCaseId;
        }

        for (Id caseId : caseIds) {
            resultByCaseId.put(caseId, new List<AdditionalInfor>());
        }

        Map<String, Schema.SObjectField> fields =
            FEC_Additional_Info__c.SObjectType.getDescribe().fields.getMap();

        String soql =
            'SELECT ' +
            String.join(new List<String>(fields.keySet()), ',') +
            ' FROM FEC_Additional_Info__c' +
            ' WHERE FEC_Case__c IN :caseIds';

        Set<Id> processedCaseIds = new Set<Id>();
        for (SObject record : Database.query(soql)) {
            Id caseId = (Id) record.get('FEC_Case__c');
            if (processedCaseIds.contains(caseId)) {
                continue;
            }
            processedCaseIds.add(caseId);
            resultByCaseId.put(
                caseId,
                buildAdditionalInfoList((FEC_Additional_Info__c) record)
            );
        }

        return resultByCaseId;
    }

    private static List<AdditionalInfor> buildAdditionalInfoList(
        FEC_Additional_Info__c info
    ) {
        List<AdditionalInfor> result = new List<AdditionalInfor>();
        if (info == null) {
            return result;
        }

        Map<String, Object> populatedFields = info.getPopulatedFieldsAsMap();
        for (String fieldName : populatedFields.keySet()) {
            if (ADDITIONAL_INFO_EXCLUDE_FIELDS.contains(fieldName)) {
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
        AND FEC_Channel_Status__c = TRUE
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
        webservice Integer TotalCases;
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
        webservice  String RequestType;
        webservice  String RequestTypeVN;
        webservice  String RequestTypeEN;
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