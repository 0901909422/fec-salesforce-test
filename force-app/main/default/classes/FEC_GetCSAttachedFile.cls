global with sharing class FEC_GetCSAttachedFile {

    webservice static GetCSAttachedFileResponseType GetCSAttachedFileRequest(
        SysType Sys,
        RequestInfoType RequestInfo
    ) {
        GetCSAttachedFileResponseType response = new GetCSAttachedFileResponseType();
        response.Sys = new SysType2();
        response.Sys.DateTime_x = System.now();
        if (Sys == null) {
            Sys = new SysType();
        }
        if (String.isBlank(Sys.TransactionID)) {
            Sys.TransactionID = UUID.randomUUID().toString();
        }
        if (Sys.DateTime_x == null) {
            Sys.DateTime_x = System.now();
        }
        if (Sys != null) {
            response.Sys.TransactionID = Sys.TransactionID;
        }

        try {
            validateInput(Sys, RequestInfo);

            Case targetCase = getCaseById(RequestInfo.CaseID);
            validateCaseAccess(targetCase, RequestInfo.ContractOrAccountInfos, RequestInfo.UserType);
            
            ContentVersion latestVersion = getAttachedFileVersion(targetCase.Id, RequestInfo.FileID);

            response.Sys.Code = FEC_ConstantCommon.CODE_SUCCESS;
            response.Sys.Description = FEC_ConstantCommon.SUCCESS_MESSAGE;
            response.FileName = latestVersion.Title;
            response.FileType = getFileType(latestVersion.FileExtension);
            response.FileContent = EncodingUtil.base64Encode(latestVersion.VersionData);
        } catch (Exception e) {
            handleError(response, e.getMessage());
        }

        return response;
    }

    private static void validateInput(
        SysType sys,
        RequestInfoType requestInfo
    ) {
        if (sys == null) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Sys'}));
        }
        if (String.isBlank(sys.Channel)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Channel'}));
        }
        if (!FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS.contains(sys.Channel)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_Channel_Invalid,
                new List<String>{String.join(FEC_ConstantCommon.CANCEL_CS_VALID_CHANNELS_ORDERED, ', ')}
            ));
        }
        if (String.isNotBlank(sys.TransactionID) && sys.TransactionID.length() > FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{
                    'TransactionID',
                    String.valueOf(FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN)
                }
            ));
        }

        if (requestInfo == null) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'RequestInfo'}
            ));
        }

        if (requestInfo.ContractOrAccountInfos == null) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'ContractOrAccountInfos'}
            ));
        }
        if (String.isBlank(requestInfo.ContractOrAccountInfos.ContractOrAccountNumber)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'ContractOrAccountNumber'}
            ));
        }
        if (requestInfo.ContractOrAccountInfos.ContractOrAccountNumber.length() > FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{
                    'ContractOrAccountNumber',
                    String.valueOf(FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN)
                }
            ));
        }
        if (String.isBlank(requestInfo.ContractOrAccountInfos.ProductType)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'ProductType'}
            ));
        }

        if (String.isBlank(requestInfo.UserType)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'UserType'}));
        }
        if (requestInfo.UserType.length() > 15) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'UserType', '15'}
            ));
        }
        Set<String> validUserTypes = new Set<String>{
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
        };
        if (!validUserTypes.contains(requestInfo.UserType)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_UserType_Invalid,
                new List<String>{
                    FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE + ', ' + FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
                }
            ));
        }

        if (String.isBlank(requestInfo.CaseID)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseID'}));
        }
        if (requestInfo.CaseID.length() > FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'CaseID', String.valueOf(FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN)}
            ));
        }
        if (String.isBlank(requestInfo.FileID)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'FileID'}));
        }
        if (!isExpectedSObjectId(requestInfo.FileID, ContentDocument.SObjectType)) {
            throw new ServiceException(System.Label.FEC_MSG_GetCSAttached_FileID_Invalid);
        }
    }

    private static Case getCaseById(String caseId) {
        List<Case> cases = [
            SELECT Id, FEC_ID_Search__c, FEC_Customer_Type__c, 
                   FEC_Account_Number__c, FEC_Contract_Number__c,
                   FEC_Account_or_Contract__c, AccountId
            FROM Case
            WHERE FEC_ID_Search__c = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_Case_Not_Found,
                new List<String>{caseId}
            ));
        }
        return cases[0];
    }
    
    private static void validateCaseAccess(Case targetCase, ContractOrAccountInfoType contractOrAccountInfos, String userType) {
        if (String.isNotBlank(userType)) {
            String expectedCustomerType = userType.equals(FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE) 
                ? FEC_ConstantCommon.CASE_EXISTING_CUSTOMER 
                : FEC_ConstantCommon.CASE_NON_EXISTING_CUSTOMER;
            
            if (targetCase.FEC_Customer_Type__c != expectedCustomerType) {
                throw new ServiceException(String.format(
                    'Case customer type mismatch. Expected: {0}, Found: {1}',
                    new List<String>{expectedCustomerType, String.valueOf(targetCase.FEC_Customer_Type__c)}
                ));
            }
        }
        
        if (contractOrAccountInfos != null && 
            String.isNotBlank(contractOrAccountInfos.ContractOrAccountNumber)) {
            String requestNumber = contractOrAccountInfos.ContractOrAccountNumber;
            Boolean isMatch = false;
            
            if (String.isNotBlank(targetCase.FEC_Account_Number__c) && 
                targetCase.FEC_Account_Number__c.equals(requestNumber)) {
                isMatch = true;
            } else if (String.isNotBlank(targetCase.FEC_Contract_Number__c) && 
                       targetCase.FEC_Contract_Number__c.equals(requestNumber)) {
                isMatch = true;
            }
            
            if (!isMatch) {
                throw new ServiceException('Contract or Account information does not match the case');
            }
        }
    }

    private static ContentVersion getAttachedFileVersion(Id caseSfId, String fileId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseSfId
            AND ContentDocumentId = :fileId
            LIMIT 1
        ];
        if (links.isEmpty()) {
            throw new ServiceException(System.Label.FEC_MSG_GetCSAttached_File_Not_Linked_To_Case);
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, VersionData, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_GetCSAttached_File_No_Content,
                new List<String>{fileId}
            ));
        }
        
        return versions[0];
    }

    private static String getFileType(String fileExtension) {
        if (String.isBlank(fileExtension)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return fileExtension.length() > 10 ? fileExtension.substring(0, 10) : fileExtension;
    }

    private static Boolean isSalesforceId(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        Integer len = value.length();
        if (len != 15 && len != 18) {
            return false;
        }
        try {
            Id parsedId = Id.valueOf(value);
            return parsedId != null;
        } catch (Exception ex) {
            return false;
        }
    }

    private static Boolean isExpectedSObjectId(String value, Schema.SObjectType expectedType) {
        if (!isSalesforceId(value)) {
            return false;
        }
        Id parsedId = Id.valueOf(value);
        return parsedId.getSObjectType() == expectedType;
    }

    private static void handleError(GetCSAttachedFileResponseType response, String errorMessage) {
        response.Sys.Code = FEC_ConstantCommon.CODE_SYS_ERROR;
        response.Sys.Description = errorMessage.startsWith(FEC_ConstantCommon.ERROR_PREFIX)
            ? errorMessage
            : (FEC_ConstantCommon.ERROR_PREFIX + errorMessage);
        response.FileName = null;
        response.FileContent = null;
        response.FileType = null;

        System.debug(LoggingLevel.ERROR, errorMessage);
    }

    private class ServiceException extends Exception {}

    global class SysType {
        webservice String Channel;
        webservice Datetime DateTime_x;
        webservice String TransactionID;
    }

    global class SysType2 {
        webservice Datetime DateTime_x;
        webservice String Code;
        webservice String Description;
        webservice String TransactionID;
    }

    global class ContractOrAccountInfoType {
        webservice String ContractOrAccountNumber;
        webservice String ProductType;
    }

    global class RequestInfoType {
        webservice String CaseID;
        webservice String UserType;
        webservice String FileID;
        webservice ContractOrAccountInfoType ContractOrAccountInfos;
    }

    global class GetCSAttachedFileResponseType {
        webservice SysType2 Sys;
        webservice String FileName;
        webservice String FileContent;
        webservice String FileType;
    }
}