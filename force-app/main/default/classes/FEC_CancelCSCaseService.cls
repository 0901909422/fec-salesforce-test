/****************************************************************************************
 * File Name    : FEC_CancelCSCaseService
 * Author       : Toannd61
 * Date         : 2025-12-1
 * Description  : Update data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 3.1      2025-12-30     Toannd61            Update
****************************************************************************************/

global with sharing class FEC_CancelCSCaseService {
    
    
    // 2. MAIN SERVICE METHOD
    // REST/XML: FEC_CancelCSCaseRestService → FEC_MyCaseSoapXml.parseCancelCSCaseRequest → CancelCSCaseRequest
    webservice static CancelCSCaseResponseType CancelCSCaseRequest(
        SysType Sys, 
        CaseInfoType CaseInfo
    ) {
        CancelCSCaseResponseType response = new CancelCSCaseResponseType();
        
        // LUÔN LUÔN khởi tạo Sys để trả về TransactionID và DateTime dù lỗi hay thành công
        response.Sys = new SysType2();
        response.Sys.DateTime_x = System.now();
        if (Sys != null) {
            response.Sys.TransactionID = Sys.TransactionID;
        }

        try {
            // A. Validate Input
            if (Sys == null) {
                throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Sys'}));
            }
            if (CaseInfo == null) {
                throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseInfo'}));
            }
            
            validateInputDetail(Sys, CaseInfo);
            
            // B. Query Case
            Case c = getCaseById(CaseInfo.CaseID);
            
            // C. Validate Logic
            validateCaseStatus(c);
            
            // D. Check Permissions
            if (!Schema.sObjectType.Case.fields.Status.isUpdateable()) {
                throw new ServiceException(System.Label.FEC_MSG_CancelCS_Insufficient_Permissions);
            }
            
            // E. Update Case
            c.Status = FEC_ConstantCommon.STATUS_CANCELLED;
            update c;
            
            // F. XỬ LÝ RESPONSE THÀNH CÔNG (FULL DATA)
            response.Sys.Code = FEC_ConstantCommon.CODE_SUCCESS;
            response.Sys.Description = FEC_ConstantCommon.SUCCESS_MESSAGE_CANCEL_CASE;
            response.CaseID = CaseInfo.CaseID;
            
            // Map full info
            response.OriginalRequest = new OriginalRequestType();
            response.OriginalRequest.Sys = Sys; // Map lại input Sys vào output
            response.OriginalRequest.CustomerInfo = new CustomerInfoType(); 
            response.OriginalRequest.CreatorInfo = new CreatorInfoType();   
            
            response.OriginalRequest.RequestInfo = new RequestInfoType();
            response.OriginalRequest.RequestInfo.CaseType       = safeString(c.Type);
            response.OriginalRequest.RequestInfo.ProductType    = safeString(c.FEC_Product_Type__c);
            response.OriginalRequest.RequestInfo.Category       = safeString(c.FEC_Category__c);
            response.OriginalRequest.RequestInfo.SubCategory    = safeString(c.FEC_SubCategory__c);
            response.OriginalRequest.RequestInfo.SubCode        = safeString(c.FEC_SubCode__c);
            response.OriginalRequest.RequestInfo.Remarks        = FEC_ConstantCommon.SUCCESS_MESSAGE_CANCEL_CASE;
            response.OriginalRequest.RequestInfo.AdditionalInfo = new List<AdditionalInfoType>();

        } catch (Exception e) {
            // G. XỬ LÝ RESPONSE LỖI
            handleError(response, e.getMessage());
        }
        
        return response;
    }
    
    // 3. HELPER METHODS
    
    private static void handleError(CancelCSCaseResponseType response, String errorMessage) {
        response.Sys.Code = FEC_ConstantCommon.CODE_FAILURE;

        response.Sys.Description = errorMessage.startsWith(FEC_ConstantCommon.ERROR_PREFIX) ? errorMessage : (FEC_ConstantCommon.ERROR_PREFIX + errorMessage);
        
        // Gán null để ẩn hoàn toàn khỏi XML response
        response.CaseID = null;
        response.OriginalRequest = null;
        
        System.debug(LoggingLevel.ERROR, errorMessage);
    }

    private static void validateInputDetail(SysType Sys, CaseInfoType CaseInfo) {
        // 1. Channel
        if (String.isBlank(Sys.Channel)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Channel'}));
        }
        if (!FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS.contains(Sys.Channel)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_Channel_Invalid,
                new List<String>{String.join(FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED, ', ')}
            ));
        }

        // 2. TransactionID
        if (String.isBlank(Sys.TransactionID)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'TransactionID'}));
        }
        if (Sys.TransactionID.length() > FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'TransactionID', String.valueOf(FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN)}
            ));
        }

        // 3. CaseID
        if (String.isBlank(CaseInfo.CaseID)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseInfo.CaseID'}));
        }
        if (CaseInfo.CaseID.length() > FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'CaseID', String.valueOf(FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN)}
            ));
        }

        // 4. Contract
        if (String.isBlank(CaseInfo.ContractOrAccountNumber)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseInfo.ContractOrAccountNumber'}));
        }
        if (CaseInfo.ContractOrAccountNumber.length() > FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'ContractOrAccountNumber', String.valueOf(FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN)}
            ));
        }

        // 5. Phone Number Validation
        if (String.isBlank(CaseInfo.PhoneNumber)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseInfo.PhoneNumber'}));
        }
        {
            String phone = CaseInfo.PhoneNumber.trim();
            Boolean isValidVN = Pattern.matches(FEC_ConstantCommon.PHONE_REGEX_VN, phone);
            Boolean isValidIntl = Pattern.matches(FEC_ConstantCommon.PHONE_REGEX_INTL, phone);
            if (!isValidVN && !isValidIntl) {
                throw new ServiceException(System.Label.FEC_MSG_CancelCS_Phone_Format_Invalid);
            }
            if (phone.length() > FEC_ConstantCommon.CANCEL_CS_PHONE_MAX_LEN) {
                throw new ServiceException(String.format(
                    System.Label.FEC_MSG_Param_Maxlength,
                    new List<String>{'PhoneNumber', String.valueOf(FEC_ConstantCommon.CANCEL_CS_PHONE_MAX_LEN)}
                ));
            }
        }

        // 6. UserType
        if (String.isBlank(CaseInfo.UserType)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseInfo.UserType'}));
        }
        Set<String> validUserTypes = new Set<String>{
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
        };
        if (!validUserTypes.contains(CaseInfo.UserType)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_UserType_Invalid,
                new List<String>{
                    FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE + ', ' + FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
                }
            ));
        }
        
        // 7. Date
        if (Sys.DateTime_x == null) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Sys.DateTime'}));
        }
    }
    
    private static Case getCaseById(String caseIdInput) {
        List<Case> cases = [SELECT Id, Status, Type, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, FEC_ID_Search__c 
                            FROM Case 
                            WHERE FEC_ID_Search__c = :caseIdInput 
                            LIMIT 1];
        
        if (cases.isEmpty()) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_CancelCS_Case_Not_Found, new List<String>{caseIdInput}));
        }
        return cases[0];
    }
    
    private static void validateCaseStatus(Case c) {
        if (c.Status == FEC_ConstantCommon.STATUS_CLOSED || c.Status == FEC_ConstantCommon.STATUS_COMPLETED) {
            throw new ServiceException(System.Label.FEC_MSG_CancelCS_Case_Already_Closed_Or_Completed);
        }
        
        if (c.Status == FEC_ConstantCommon.STATUS_CANCELLED) {
            throw new ServiceException(System.Label.FEC_MSG_CancelCS_Case_Already_Resolved);
        }
    }
    
    private static String safeString(String input) {
        return input == null ? FEC_ConstantCommon.STR_EMPTY : input;
    }
    private class ServiceException extends Exception {}
    
    // -------------------------------------------------
    // 4. DATA STRUCTURES
    // -------------------------------------------------
    global class SysType {
        webservice String Channel;
        webservice Datetime DateTime_x;
        webservice String TransactionID;
    }
    global class CaseInfoType {
        webservice String ContractOrAccountNumber;
        webservice String PhoneNumber;
        webservice String CaseID;
        webservice String UserType;
    }
    global class CancelCSCaseResponseType {
        webservice SysType2 Sys;
        webservice String CaseID;
        webservice OriginalRequestType OriginalRequest;
    }
    global class SysType2 {
        webservice Datetime DateTime_x;
        webservice String Code;
        webservice String Description;
        webservice String TransactionID;
    }
    global class OriginalRequestType {
        webservice SysType Sys;
        webservice CustomerInfoType CustomerInfo;
        webservice RequestInfoType RequestInfo;
        webservice CreatorInfoType CreatorInfo;
    }
    global class RequestInfoType {
        webservice String CaseType;
        webservice String ProductType;
        webservice String Category;
        webservice String SubCategory;
        webservice String SubCode;
        webservice String Remarks;
        webservice List<AdditionalInfoType> AdditionalInfo;
    }
    global class CustomerInfoType {}
    global class AdditionalInfoType {}
    global class CreatorInfoType {}
}