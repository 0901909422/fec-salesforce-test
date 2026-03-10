global with sharing class FEC_GetCSCaseStatusService {
    
    // -------------------------------------------------
    // MAIN SERVICE METHOD
    // -------------------------------------------------
    webservice static GetCSCaseStatusResponse GetCSCaseStatus(GetCSCaseStatusRequest req) {
        
        // Initialize response
        GetCSCaseStatusResponse response = new GetCSCaseStatusResponse();
        response.Sys = new SysType2();
        response.CaseResultInfo = new List<CaseResultInfoType>();
        
        // Build Sys response from request
        if (req != null && req.Sys != null) {
            response.Sys.Channel = req.Sys.Channel;
            response.Sys.TransactionID = req.Sys.TransactionID;
        }
        response.Sys.DateTime_x = String.valueOf(System.now());
        
        // Prepare CaseResultInfo
        CaseResultInfoType result = new CaseResultInfoType();
        
        try {
            // Validate request
            validateRequest(req);
            // Query Case
            Case c = getCaseById(req.CaseRequestInfo.CaseID);
            
            result.CaseID = c.Id;
            result.CaseStatus = c.FEC_Case_Status__c;
            result.Remarks = c.FEC_Remarks__c;
            result.CreatedTime = String.valueOf(c.CreatedDate);
            result.UpdatedTime = String.valueOf(c.LastModifiedDate);
            
            // Build OriginalRequest
            result.OriginalRequest = new OriginalRequestType();
            result.OriginalRequest.Sys = req.Sys;
            result.OriginalRequest.CustomerInfo = new CustomerInfoType();
            result.OriginalRequest.RequestInfo = new RequestInfoType();
            result.OriginalRequest.CreatorInfo = new CreatorInfoType();
            
        } catch (Exception e) {
            // Error response
            result.CaseID = (req != null && req.CaseRequestInfo != null) ? req.CaseRequestInfo.CaseID : null;
            result.CaseStatus = 'ERROR';
            result.Remarks = e.getMessage();
            result.CreatedTime = String.valueOf(System.now());
            result.UpdatedTime = String.valueOf(System.now());
        }
        
        response.CaseResultInfo.add(result);
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
        
        if(req==null) throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_REQUEST_INVALID_MSG);
        
        if(req.Sys==null) throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_SYS_REQUIRED_MSG);
        
        if(String.isBlank(req.Sys.Channel))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CHANNEL_REQUIRED_MSG);
        
        // FIX #2 Channel must exist
        // if(!VALID_CHANNELS.contains(req.Sys.Channel))
        //     throw new ServiceException('Invalid Channel');
        
        // FIX #4 TransactionID required + <=36
        if(String.isBlank(req.Sys.TransactionID))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_REQUIRED_MSG);
        
        if(req.Sys.TransactionID.length()>36)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_TRANSACTIONID_MAX_MSG);
        
        // FIX #3 ISO 8601 check
        if(!isISO8601(req.Sys.DateTime_x))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_DATETIME_INVALID_MSG);
        
        if(req.CaseRequestInfo==null)
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CASEREQUESTINFO_REQUIRED_MSG);
        
        if(String.isBlank(req.CaseRequestInfo.CaseID))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CASEID_REQUIRED_MSG);
        
        // FIX #5 ContractOrAccountInfos required
        if(req.CaseRequestInfo.ContractOrAccountInfos==null ||
            req.CaseRequestInfo.ContractOrAccountInfos.isEmpty())
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_INFOS_REQUIRED_MSG);
        
        for(ContractOrAccountInfosType info : req.CaseRequestInfo.ContractOrAccountInfos){
            
            // FIX #6 length <=255
            if(info.ContractOrAccountNumber!=null &&
                info.ContractOrAccountNumber.length()>255)
                throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_CONTRACT_OR_ACCOUNT_NUMBER_MAX_MSG);
            
            // FIX #7 ProductType required
            if(String.isBlank(info.ProductType))
                throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_PRODUCT_TYPE_REQUIRED_MSG);
        }
        
        // FIX #8 Phone required
        if(String.isBlank(req.CaseRequestInfo.PhoneNumber))
            throw new ServiceException(System.Label.FEC_CS_CASE_STATUS_PHONE_REQUIRED_MSG);
        
        // FIX #9 UserType required + <=15
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
        webservice  List<ContractOrAccountInfosType> ContractOrAccountInfos;
        webservice  String PhoneNumber;
        webservice  String UserType;
        webservice  String CaseID;
        webservice  String IncludeFinishedRequest;
        webservice  String NationalID;
    }
    
    global class ContractOrAccountInfosType {
        webservice String ContractOrAccountNumber;
        webservice String ProductType;
    }
    
    // -------------------------------------------------
    // RESPONSE TYPES
    // -------------------------------------------------
    global class GetCSCaseStatusResponse {
        webservice SysType2 Sys;
        webservice List<CaseResultInfoType> CaseResultInfo;
    }
    
    global class SysType2 {
        webservice String Channel;
        webservice String TransactionID;
        webservice String  DateTime_x;
    }
    
    global class CaseResultInfoType {
        webservice String CaseID;
        webservice String CaseStatus;
        webservice String Remarks;
        webservice String  CreatedTime;
        webservice String  UpdatedTime;
        webservice OriginalRequestType OriginalRequest;
    }
    
    global class OriginalRequestType {
        webservice SysType Sys;
        webservice CustomerInfoType CustomerInfo;
        webservice RequestInfoType RequestInfo;
        webservice CreatorInfoType CreatorInfo;
    }
    
    
    // -------------------------------------------------
    // EMPTY PLACEHOLDER CLASSES
    // -------------------------------------------------
    global class CustomerInfoType {}
    global class RequestInfoType {}
    global class CreatorInfoType {}
    
}