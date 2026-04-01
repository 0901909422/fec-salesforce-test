public with sharing class FEC_GetCSCaseStatusService {
    
    // -------------------------------------------------
    // MAIN SERVICE METHOD
    // -------------------------------------------------
    @AuraEnabled
    public static GetCSCaseStatusResponse GetCSCaseStatus(GetCSCaseStatusRequest req) {
        
        GetCSCaseStatusResponse response = new GetCSCaseStatusResponse();
        response.Sys = new SysType2();
        response.CaseResultInfo = new List<CaseResultInfoType>();
        
        Boolean isSuccess = false;
        String errorMessage;
        String transactionId;
        
        if (req != null && req.Sys != null) {
            response.Sys.Channel = req.Sys.Channel;
            response.Sys.TransactionID = req.Sys.TransactionID;
            transactionId = req.Sys.TransactionID;
        }
        
        response.Sys.DateTime_x = String.valueOf(System.now());
        
        CaseResultInfoType result = new CaseResultInfoType();
        
        try {
            System.debug('=== START GetCSCaseStatus ===');
            System.debug('Request: ' + JSON.serialize(req));
            
            validateRequest(req);
            
            Case c = getCaseById(req.CaseRequestInfo.CaseID);
            
            result.CaseID = c.Id;
            result.CaseStatus = c.FEC_Case_Status__c;
            result.Remarks = c.FEC_Remarks__c;
            result.CreatedTime = String.valueOf(c.CreatedDate);
            result.UpdatedTime = String.valueOf(c.LastModifiedDate);
            
            result.OriginalRequest = new OriginalRequestType();
            result.OriginalRequest.Sys = req.Sys;
            
            result.OriginalRequest.CustomerInfo = new CustomerInfoType();
            result.OriginalRequest.CustomerInfo.NationalID = req.CaseRequestInfo.NationalID;
            result.OriginalRequest.CustomerInfo.PhoneNumber = req.CaseRequestInfo.PhoneNumber;
            
            result.OriginalRequest.RequestInfo = new RequestInfoType();
            result.OriginalRequest.RequestInfo.IncludeFinishedRequest = req.CaseRequestInfo.IncludeFinishedRequest;
            result.OriginalRequest.RequestInfo.UserType = req.CaseRequestInfo.UserType;
            result.OriginalRequest.RequestInfo.ContractOrAccountInfos = req.CaseRequestInfo.ContractOrAccountInfos;
            
            result.OriginalRequest.CreatorInfo = new CreatorInfoType();
            result.OriginalRequest.CreatorInfo.CreatedById = c.OwnerId;
            
            isSuccess = true;
            
            System.debug('Response: ' + JSON.serialize(result));
            
        } catch (Exception e) {
            errorMessage = e.getMessage();
            
            System.debug('ERROR: ' + errorMessage);
            
            result.CaseID = (req != null && req.CaseRequestInfo != null)
                ? req.CaseRequestInfo.CaseID : null;
            result.CaseStatus = FEC_ConstantCommon.CASE_STATUS_ERROR;
            result.Remarks = errorMessage;
            result.CreatedTime = String.valueOf(System.now());
            result.UpdatedTime = String.valueOf(System.now());
        }
        
        response.CaseResultInfo.add(result);
        
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
        List<Case> cases = [
            SELECT Id, CaseNumber, OwnerId, CreatedDate, LastModifiedDate,FEC_Case_Status__c,FEC_Remarks__c
            FROM Case
            WHERE FEC_ID_Search__c  = :caseId
            LIMIT 1
        ];
        
        if (cases.isEmpty()) {
            throw new ServiceException(System.Label.FEC_CS_CASE_NOT_FOUND_MSG + caseId);
        }
        
        return cases[0];
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
        
        if(String.isBlank(req.CaseRequestInfo.IncludeFinishedRequest)) {
            throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_INCLUDE_FINISHED_REQUEST_REQUIRE_MSG);
        }
        if(req.CaseRequestInfo.ContractOrAccountInfos==null ||
            req.CaseRequestInfo.ContractOrAccountInfos.isEmpty())
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_INFOS_REQUIRED_MSG);
        
        for(ContractOrAccountInfosType info : req.CaseRequestInfo.ContractOrAccountInfos){
            
            // REQUIRED ContractOrAccountNumber
            if(String.isBlank(info.ContractOrAccountNumber)) {
                throw new ServiceException(System.Label.FEC_GET_CASE_STATUS_CONTRACT_OR_ACCOUNT_NUMBER_REQUIRE_MSG);
            }
            
            // length <=255
            if(info.ContractOrAccountNumber.length()>255)
                throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_NUMBER_MAX_MSG);
            
            if(String.isBlank(info.ProductType))
                throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_PRODUCT_TYPE_REQUIRED_MSG);
        }
        
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
        @AuraEnabled public  List<ContractOrAccountInfosType> ContractOrAccountInfos;
        @AuraEnabled public  String PhoneNumber;
        @AuraEnabled public  String UserType;
        @AuraEnabled public  String CaseID;
        @AuraEnabled public  String IncludeFinishedRequest;
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
        @AuraEnabled public List<CaseResultInfoType> CaseResultInfo;
    }
    
    public class SysType2 {
        @AuraEnabled public String Channel;
        @AuraEnabled public String TransactionID;
        @AuraEnabled public String  DateTime_x;
    }
    
    public class CaseResultInfoType {
        @AuraEnabled public String CaseID;
        @AuraEnabled public String CaseStatus;
        @AuraEnabled public String Remarks;
        @AuraEnabled public String  CreatedTime;
        @AuraEnabled public String  UpdatedTime;
        @AuraEnabled public OriginalRequestType OriginalRequest;
    }
    
    public class OriginalRequestType {
        @AuraEnabled public SysType Sys;
        @AuraEnabled public CustomerInfoType CustomerInfo;
        @AuraEnabled public RequestInfoType RequestInfo;
        @AuraEnabled public CreatorInfoType CreatorInfo;
    }
    
    
    
    public class CustomerInfoType {
        @AuraEnabled public String NationalID;
        @AuraEnabled public String PhoneNumber;
    }
    
    public class RequestInfoType {
        @AuraEnabled public String IncludeFinishedRequest;
        @AuraEnabled public String UserType;
        @AuraEnabled public List<ContractOrAccountInfosType> ContractOrAccountInfos;
    }
    
    public class CreatorInfoType {
        @AuraEnabled public String CreatedById;
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