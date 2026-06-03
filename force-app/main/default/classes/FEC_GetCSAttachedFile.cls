/**
 * SOAP webservice GetCSAttachedFile.
 * REST (raw SOAP XML): FEC_GetCSAttachedFileRestService → FEC_MyCaseSoapXml.
 */
global with sharing class FEC_GetCSAttachedFile {

    webservice static GetCSAttachedFileResponseType GetCSAttachedFileRequest(
        SysType Sys,
        RequestInfoType RequestInfo
    ) {
        GetCSAttachedFileResponseType response = new GetCSAttachedFileResponseType();
        Boolean isSuccess = true;
        String errorMessage;

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
            isSuccess = false;
            errorMessage = e.getMessage();
            handleError(response, errorMessage);
        }

        GetCSAttachedFileRequestPayload requestPayload = new GetCSAttachedFileRequestPayload();
        requestPayload.Sys = Sys;
        requestPayload.RequestInfo = RequestInfo;

        logApiFull(
            'GetCSAttachedFile',
            'POST',
            requestPayload,
            buildLogResponsePayload(response),
            isSuccess,
            isSuccess ? '200' : '500',
            errorMessage,
            Sys != null ? Sys.TransactionID : null
        );

        return response;
    }

    private static void validateInput(
        SysType sys,
        RequestInfoType requestInfo
    ) {
        if (sys == null) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Sys'}));
        }
        validateActiveChannel(sys.Channel);
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
                    System.Label.FEC_MSG_Case_Customer_Type_Mismatch,
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
                throw new ServiceException(System.Label.FEC_MSG_Contract_Or_Account_Info_Case_Mismatch);
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

    private static void validateActiveChannel(String channel) {
        if (String.isBlank(channel)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Channel'}));
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
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_Channel_Invalid,
                new List<String>{ getActiveChannelIdsForError() }
            ));
        }
    }

    private static String getActiveChannelIdsForError() {
        List<String> channelIds = new List<String>();
        for (FEC_Channel__c ch : [
            SELECT FEC_Channel_ID__c
            FROM FEC_Channel__c
            WHERE FEC_Channel_Status__c = true
            AND FEC_Channel_ID__c != null
            ORDER BY FEC_Channel_ID__c ASC
        ]) {
            channelIds.add(ch.FEC_Channel_ID__c);
        }
        return String.join(channelIds, ', ');
    }

    private static GetCSAttachedFileResponseLogType buildLogResponsePayload(
        GetCSAttachedFileResponseType response
    ) {
        GetCSAttachedFileResponseLogType logResponse = new GetCSAttachedFileResponseLogType();
        logResponse.Sys = response.Sys;
        logResponse.FileName = response.FileName;
        logResponse.FileType = response.FileType;
        if (String.isNotBlank(response.FileContent)) {
            logResponse.FileContent = '[OMITTED:length=' + response.FileContent.length() + ']';
        }
        return logResponse;
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
                'GetCSAttachedFile',
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

    private class GetCSAttachedFileRequestPayload {
        public SysType Sys;
        public RequestInfoType RequestInfo;
    }

    private class GetCSAttachedFileResponseLogType {
        public SysType2 Sys;
        public String FileName;
        public String FileContent;
        public String FileType;
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