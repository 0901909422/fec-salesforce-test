global with sharing class FEC_GetCSAttachedFile {

    webservice static GetCSAttachedFileResponseType GetCSAttachedFileRequest(
        SysType Sys,
        String ContractOrAccountInfos,
        String UserType,
        String CaseID,
        String FileID
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
            validateInput(Sys, ContractOrAccountInfos, UserType, CaseID, FileID);

            Case targetCase = getCaseById(CaseID);
            ContentVersion latestVersion = getAttachedFileVersion(targetCase.Id, FileID);

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
        String contractOrAccountInfos,
        String userType,
        String caseId,
        String fileId
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
        if (sys.TransactionID.length() > FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{
                    'TransactionID',
                    String.valueOf(FEC_ConstantCommon.CANCEL_CS_TRANSACTION_ID_MAX_LEN)
                }
            ));
        }
        if (String.isBlank(contractOrAccountInfos)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{'ContractOrAccountInfos'}
            ));
        }
        if (contractOrAccountInfos.length() > FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{
                    'ContractOrAccountInfos',
                    String.valueOf(FEC_ConstantCommon.CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN)
                }
            ));
        }

        if (String.isBlank(userType)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'UserType'}));
        }
        if (userType.length() > 15) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'UserType', '15'}
            ));
        }
        Set<String> validUserTypes = new Set<String>{
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
        };
        if (!validUserTypes.contains(userType)) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_CancelCS_UserType_Invalid,
                new List<String>{
                    FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE + ', ' + FEC_ConstantCommon.REQUEST_NON_EXISTING_USER_TYPE
                }
            ));
        }

        if (String.isBlank(caseId)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CaseID'}));
        }
        if (caseId.length() > FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN) {
            throw new ServiceException(String.format(
                System.Label.FEC_MSG_Param_Maxlength,
                new List<String>{'CaseID', String.valueOf(FEC_ConstantCommon.CANCEL_CS_CASE_ID_MAX_LEN)}
            ));
        }
        if (String.isBlank(fileId)) {
            throw new ServiceException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'FileID'}));
        }
        if (!isExpectedSObjectId(fileId, ContentDocument.SObjectType)) {
            throw new ServiceException(System.Label.FEC_MSG_GetCSAttached_FileID_Invalid);
        }
    }

    private static Case getCaseById(String caseId) {
        List<Case> cases = [
            SELECT Id
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
            SELECT Id, Title, FileExtension, VersionData
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

    global class GetCSAttachedFileResponseType {
        webservice SysType2 Sys;
        webservice String FileName;
        webservice String FileContent;
        webservice String FileType;
    }
}