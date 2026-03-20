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
            if (Sys == null) throw new ServiceException('Sys element is mandatory');
            if (CaseInfo == null) throw new ServiceException('CaseInfo element is mandatory');
            
            validateInputDetail(Sys, CaseInfo);
            
            // B. Query Case
            Case c = getCaseById(CaseInfo.CaseID);
            
            // C. Validate Logic
            validateCaseStatus(c);
            
            // D. Check Permissions
            if (!Schema.sObjectType.Case.fields.Status.isUpdateable()) {
                throw new ServiceException('Insufficient permissions to update Case Status');
            }
            
            // E. Update Case
            c.Status = STATUS_CANCELLED;
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
        if (String.isBlank(Sys.Channel)) throw new ServiceException('Channel is mandatory');
        Set<String> validChannels = new Set<String>{'Inbound', 'Outbound', 'Chat', 'Email', 'F2F', 'Letter', 'External', 'Internal'};
        if (!validChannels.contains(Sys.Channel)) throw new ServiceException('Invalid Channel. Allowed: Inbound, Outbound, Chat, Email, F2F, Letter, External, Internal');

        // 2. TransactionID
        // Check không được để trống TransactionID
        if (String.isBlank(Sys.TransactionID)) throw new ServiceException('TransactionID is mandatory');
        if (Sys.TransactionID.length() > 36) throw new ServiceException('TransactionID length cannot exceed 36 characters');

        // 3. CaseID
        if (String.isBlank(CaseInfo.CaseID)) throw new ServiceException('CaseInfo.CaseID is mandatory');
        if (CaseInfo.CaseID.length() > 15) throw new ServiceException('CaseID length cannot exceed 15 characters'); 

        // 4. Contract
        if (String.isBlank(CaseInfo.ContractOrAccountNumber)) throw new ServiceException('CaseInfo.ContractOrAccountNumber is mandatory');
        if (CaseInfo.ContractOrAccountNumber.length() > 255) throw new ServiceException('ContractOrAccountNumber length cannot exceed 255 characters');

        // 5. Phone Number Validation
        if (String.isBlank(CaseInfo.PhoneNumber)) throw new ServiceException('CaseInfo.PhoneNumber is mandatory');
        {
            String phone = CaseInfo.PhoneNumber.trim();
            // Validate format
            Boolean isValidVN = Pattern.matches(FEC_ConstantCommon.PHONE_REGEX_VN, phone);
            Boolean isValidIntl = Pattern.matches(FEC_ConstantCommon.PHONE_REGEX_INTL, phone);
            if (!isValidVN && !isValidIntl) {
                throw new ServiceException('PhoneNumber format is invalid. Expected format: Vietnamese (0xxxxxxxxx - 10 digits) or International (+xxxxxxxx - 8 to 15 digits with country code)');
            }
            if (phone.length() > 16) {
                throw new ServiceException('PhoneNumber length cannot exceed 16 characters');
            }
        }

        // 6. UserType
        if (String.isBlank(CaseInfo.UserType)) throw new ServiceException('CaseInfo.UserType is mandatory');
        Set<String> validUserTypes = new Set<String>{'EXISTING', 'NON-EXISTING'};
        if (!validUserTypes.contains(CaseInfo.UserType)) throw new ServiceException('Invalid UserType. Allowed: EXISTING, NON-EXISTING');
        
        // 7. Date
        if (Sys.DateTime_x == null) throw new ServiceException('Sys.DateTime is mandatory');
    }
    
    private static Case getCaseById(String caseIdInput) {
        List<Case> cases = [SELECT Id, Status, Type, FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c, FEC_ID_Search__c 
                            FROM Case 
                            WHERE FEC_ID_Search__c = :caseIdInput 
                            LIMIT 1];
        
        if (cases.isEmpty()) {
            throw new ServiceException('Case not found with ID: ' + caseIdInput);
        }
        return cases[0];
    }
    
    private static void validateCaseStatus(Case c) {
        if (c.Status == FEC_ConstantCommon.STATUS_CLOSED || c.Status == FEC_ConstantCommon.STATUS_COMPLETED) throw new ServiceException('Case is already Closed or Completed');
        
        // Đổi thông báo lỗi khi case đã cancel
        if (c.Status == FEC_ConstantCommon.STATUS_CANCELLED) {
            throw new ServiceException('Case is already resolved.');
        }
    }
    
    private static String safeString(String input) { return input == null ? '' : input; }
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