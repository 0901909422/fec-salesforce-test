/**
 * Parse / build SOAP XML for MyCase services (WSDL urn:PegaRULES:SOAP:MyCase:Services).
 * CreateCSCase, CancelCSCase, GetCSCaseStatus, GetCSAttachedFile, GetCSMasterData, GetCSMasterDataByCode.
 */
public without sharing class FEC_MyCaseSoapXml {
    public static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;
    public static final String MYCASE_NS = 'urn:PegaRULES:SOAP:MyCase:Services';

    public class SoapParseException extends Exception {
        public String transactionId;
        public String code;
        public SoapParseException(String transactionId, String code, String message) {
            this.transactionId = transactionId;
            this.code = code;
            this.setMessage(message);
        }
    }

    public static FEC_CreateCSCaseService.CaseRequestType parseCreateCSCaseRequest(
        String rawXml
    ) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                System.Label.FEC_CS_CASE_ERROR_CODE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                System.Label.FEC_CS_CASE_ERROR_CODE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                System.Label.FEC_CS_CASE_ERROR_CODE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode createReq = findChildByLocalName(body, 'CreateCSCaseRequest');
        if (createReq == null) {
            throw new SoapParseException(
                null,
                System.Label.FEC_CS_CASE_ERROR_CODE,
                'CreateCSCaseRequest element not found'
            );
        }

        return mapCreateCSCaseRequest(createReq);
    }

    public static String buildCreateCSCaseSoapResponse(
        FEC_CreateCSCaseService.CreateCSCaseResponse resp
    ) {
        FEC_CreateCSCaseService.CreateCSCaseResponse r = resp != null
            ? resp
            : new FEC_CreateCSCaseService.CreateCSCaseResponse();

        String txnId = r.Sys != null ? r.Sys.TransactionID : '';
        String sysDateTime = r.Sys != null ? r.Sys.DateTime_x : String.valueOf(System.now());
        String code = r.Sys != null ? r.Sys.Code : '';
        String description = r.Sys != null ? r.Sys.Description : '';
        String caseId = r.CaseID;

        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' +
            SOAP_ENV +
            '">' +
            '<soap:Body>' +
            '<CreateCSCaseResponse xmlns="' +
            MYCASE_NS +
            '">' +
            '<Sys>' +
            '<TransactionID>' +
            xmlEscape(txnId) +
            '</TransactionID>' +
            '<DateTime>' +
            xmlEscape(sysDateTime) +
            '</DateTime>' +
            '<Code>' +
            xmlEscape(code) +
            '</Code>' +
            '<Description>' +
            xmlEscape(description) +
            '</Description>' +
            '</Sys>' +
            '<CaseID>' +
            xmlEscape(caseId) +
            '</CaseID>' +
            '</CreateCSCaseResponse>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    public static String buildErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_CreateCSCaseService.CreateCSCaseResponse err =
            new FEC_CreateCSCaseService.CreateCSCaseResponse();
        err.Sys = new FEC_CreateCSCaseService.SysType2();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = String.valueOf(System.now());
        err.Sys.Code = String.isNotBlank(code) ? code : System.Label.FEC_CS_CASE_ERROR_CODE;
        err.Sys.Description = message;
        err.CaseID = null;
        return buildCreateCSCaseSoapResponse(err);
    }

    // =========================================================================
    // CancelCSCase
    // =========================================================================

    public class CancelCSCaseParsedRequest {
        public FEC_CancelCSCaseService.SysType Sys;
        public FEC_CancelCSCaseService.CaseInfoType CaseInfo;
    }

    public static CancelCSCaseParsedRequest parseCancelCSCaseRequest(String rawXml) {
        Dom.XmlNode cancelReq = loadCancelCSCaseRequestNode(rawXml);
        CancelCSCaseParsedRequest parsed = new CancelCSCaseParsedRequest();
        parsed.Sys = mapCancelSys(cancelReq);
        parsed.CaseInfo = mapCancelCaseInfo(cancelReq);
        return parsed;
    }

    public static String buildCancelCSCaseSoapResponse(
        FEC_CancelCSCaseService.CancelCSCaseResponseType resp
    ) {
        FEC_CancelCSCaseService.CancelCSCaseResponseType r = resp != null
            ? resp
            : new FEC_CancelCSCaseService.CancelCSCaseResponseType();

        String xml = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' + SOAP_ENV + '">' +
            '<soap:Body>' +
            '<CancelCSCaseResponse xmlns="' + MYCASE_NS + '">' +
            buildCancelResponseSysXml(r.Sys) +
            buildXmlElement('CaseID', r.CaseID);
        if (r.OriginalRequest != null) {
            xml += buildOriginalRequestXml(r.OriginalRequest);
        }
        xml += '</CancelCSCaseResponse></soap:Body></soap:Envelope>';
        return xml;
    }

    public static String buildCancelCSCaseErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_CancelCSCaseService.CancelCSCaseResponseType err =
            new FEC_CancelCSCaseService.CancelCSCaseResponseType();
        err.Sys = new FEC_CancelCSCaseService.SysType2();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = System.now();
        err.Sys.Code = String.isNotBlank(code)
            ? code
            : FEC_ConstantCommon.CODE_FAILURE;
        err.Sys.Description = message;
        err.CaseID = null;
        err.OriginalRequest = null;
        return buildCancelCSCaseSoapResponse(err);
    }

    private static Dom.XmlNode loadCancelCSCaseRequestNode(String rawXml) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode cancelReq = findChildByLocalName(body, 'CancelCSCaseRequest');
        if (cancelReq == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'CancelCSCaseRequest element not found'
            );
        }
        return cancelReq;
    }

    private static FEC_CancelCSCaseService.SysType mapCancelSys(Dom.XmlNode cancelReq) {
        FEC_CancelCSCaseService.SysType sys = new FEC_CancelCSCaseService.SysType();
        Dom.XmlNode sysNode = findChildByLocalName(cancelReq, 'Sys');
        if (sysNode != null) {
            sys.Channel = textOf(sysNode, 'Channel');
            sys.TransactionID = textOf(sysNode, 'TransactionID');
            sys.DateTime_x = parseIsoDateTime(textOf(sysNode, 'DateTime'));
        }
        return sys;
    }

    private static FEC_CancelCSCaseService.CaseInfoType mapCancelCaseInfo(Dom.XmlNode cancelReq) {
        FEC_CancelCSCaseService.CaseInfoType caseInfo = new FEC_CancelCSCaseService.CaseInfoType();
        Dom.XmlNode caseInfoNode = findChildByLocalName(cancelReq, 'CaseInfo');
        if (caseInfoNode != null) {
            caseInfo.ContractOrAccountNumber = textOf(caseInfoNode, 'ContractOrAccountNumber');
            caseInfo.PhoneNumber = textOf(caseInfoNode, 'PhoneNumber');
            caseInfo.CaseID = textOf(caseInfoNode, 'CaseID');
            caseInfo.UserType = textOf(caseInfoNode, 'UserType');
        }
        return caseInfo;
    }

    private static String buildCancelResponseSysXml(FEC_CancelCSCaseService.SysType2 sys) {
        return '<Sys>' +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement(
                'DateTime',
                sys != null && sys.DateTime_x != null ? String.valueOf(sys.DateTime_x) : null
            ) +
            buildXmlElement('Code', sys != null ? sys.Code : null) +
            buildXmlElement('Description', sys != null ? sys.Description : null) +
            '</Sys>';
    }

    private static String buildCancelInputSysXml(FEC_CancelCSCaseService.SysType sys) {
        return '<Sys>' +
            buildXmlElement('Channel', sys != null ? sys.Channel : null) +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement(
                'DateTime',
                sys != null && sys.DateTime_x != null ? String.valueOf(sys.DateTime_x) : null
            ) +
            '</Sys>';
    }

    private static String buildOriginalRequestXml(
        FEC_CancelCSCaseService.OriginalRequestType originalRequest
    ) {
        String requestInfoXml = originalRequest.RequestInfo != null
            ? buildCancelRequestInfoXml(originalRequest.RequestInfo)
            : '<RequestInfo></RequestInfo>';
        return '<OriginalRequest>' +
            buildCancelInputSysXml(originalRequest.Sys) +
            '<CustomerInfo></CustomerInfo>' +
            requestInfoXml +
            '<CreatorInfo></CreatorInfo>' +
            '</OriginalRequest>';
    }

    private static String buildCancelRequestInfoXml(
        FEC_CancelCSCaseService.RequestInfoType requestInfo
    ) {
        return '<RequestInfo>' +
            buildXmlElement('CaseType', requestInfo.CaseType) +
            buildXmlElement('ProductType', requestInfo.ProductType) +
            buildXmlElement('Category', requestInfo.Category) +
            buildXmlElement('SubCategory', requestInfo.SubCategory) +
            buildXmlElement('SubCode', requestInfo.SubCode) +
            buildXmlElement('Remarks', requestInfo.Remarks) +
            '</RequestInfo>';
    }

    private static String buildXmlElement(String tag, String value) {
        if (value == null) {
            return '';
        }
        return '<' + tag + '>' + xmlEscape(value) + '</' + tag + '>';
    }

    // =========================================================================
    // GetCSCaseStatus
    // =========================================================================

    public static FEC_GetCSCaseStatusService.GetCSCaseStatusRequest parseGetCSCaseStatusRequest(
        String rawXml
    ) {
        Dom.XmlNode statusReq = loadGetCSCaseStatusRequestNode(rawXml);
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest parsed =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusRequest();
        parsed.Sys = mapGetStatusSys(statusReq);
        parsed.CaseRequestInfo = mapGetCaseRequestInfo(statusReq);
        return parsed;
    }

    public static String buildGetCSCaseStatusSoapResponse(
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse resp
    ) {
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse r = resp != null
            ? resp
            : new FEC_GetCSCaseStatusService.GetCSCaseStatusResponse();

        String xml = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' + SOAP_ENV + '">' +
            '<soap:Body>' +
            '<GetCSCaseStatusResponse xmlns="' + MYCASE_NS + '">' +
            buildGetStatusResponseSysXml(r.Sys);
        if (r.CaseResultInfo != null) {
            xml += buildGetCaseResultInfoXml(r.CaseResultInfo, r.OriginalRequest);
        }
        xml += '</GetCSCaseStatusResponse></soap:Body></soap:Envelope>';
        return xml;
    }

    public static String buildGetCSCaseStatusErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse err =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusResponse();
        err.Sys = new FEC_GetCSCaseStatusService.SysType2();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = String.valueOf(System.now());
        err.Sys.Code = parseGetStatusErrorCode(code);
        err.Sys.Description = message;
        err.CaseResultInfo = null;
        err.OriginalRequest = null;
        return buildGetCSCaseStatusSoapResponse(err);
    }

    private static Integer parseGetStatusErrorCode(String code) {
        if (String.isBlank(code)) {
            return 2;
        }
        try {
            return Integer.valueOf(code);
        } catch (Exception e) {
            return 2;
        }
    }

    private static Dom.XmlNode loadGetCSCaseStatusRequestNode(String rawXml) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode statusReq = findChildByLocalName(body, 'GetCSCaseStatusRequest');
        if (statusReq == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'GetCSCaseStatusRequest element not found'
            );
        }
        return statusReq;
    }

    private static FEC_GetCSCaseStatusService.SysType mapGetStatusSys(Dom.XmlNode statusReq) {
        FEC_GetCSCaseStatusService.SysType sys = new FEC_GetCSCaseStatusService.SysType();
        Dom.XmlNode sysNode = findChildByLocalName(statusReq, 'Sys');
        if (sysNode != null) {
            sys.Channel = textOf(sysNode, 'Channel');
            sys.TransactionID = textOf(sysNode, 'TransactionID');
            sys.DateTime_x = textOf(sysNode, 'DateTime');
        }
        return sys;
    }

    private static FEC_GetCSCaseStatusService.CaseRequestInfoType mapGetCaseRequestInfo(
        Dom.XmlNode statusReq
    ) {
        FEC_GetCSCaseStatusService.CaseRequestInfoType caseRequestInfo =
            new FEC_GetCSCaseStatusService.CaseRequestInfoType();
        Dom.XmlNode caseRequestNode = findChildByLocalName(statusReq, 'CaseRequestInfo');
        if (caseRequestNode == null) {
            return caseRequestInfo;
        }

        caseRequestInfo.PhoneNumber = textOf(caseRequestNode, 'PhoneNumber');
        caseRequestInfo.UserType = textOf(caseRequestNode, 'UserType');
        caseRequestInfo.CaseID = textOf(caseRequestNode, 'CaseID');
        caseRequestInfo.NationalID = textOf(caseRequestNode, 'NationalID');

        String includeFinished = textOf(caseRequestNode, 'IncludeFinishedRequest');
        if (String.isNotBlank(includeFinished)) {
            caseRequestInfo.IncludeFinishedRequest = Boolean.valueOf(includeFinished);
        }

        Dom.XmlNode contractInfosNode = findChildByLocalName(
            caseRequestNode,
            'ContractOrAccountInfos'
        );
        if (contractInfosNode != null) {
            caseRequestInfo.ContractOrAccountInfos =
                new FEC_GetCSCaseStatusService.ContractOrAccountInfosType();
            caseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber = textOf(
                contractInfosNode,
                'ContractOrAccountNumber'
            );
            caseRequestInfo.ContractOrAccountInfos.ProductType = textOf(
                contractInfosNode,
                'ProductType'
            );
        }
        return caseRequestInfo;
    }

    private static String buildGetStatusResponseSysXml(
        FEC_GetCSCaseStatusService.SysType2 sys
    ) {
        return '<Sys>' +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement('DateTime', sys != null ? sys.DateTime_x : null) +
            buildXmlElement(
                'Code',
                sys != null && sys.Code != null ? String.valueOf(sys.Code) : null
            ) +
            buildXmlElement('Description', sys != null ? sys.Description : null) +
            '</Sys>';
    }

    private static String buildGetCaseResultInfoXml(
        FEC_GetCSCaseStatusService.CaseResultInfoType caseResult,
        FEC_GetCSCaseStatusService.OriginalRequestType originalRequest
    ) {
        String xml = '<CaseResultInfo>' +
            buildXmlElement('CaseID', caseResult.CaseID) +
            buildXmlElement('CaseStatus', caseResult.CaseStatus) +
            buildXmlElement('Remarks', caseResult.Remarks) +
            buildXmlElement('CreatedTime', caseResult.CreatedTime) +
            buildXmlElement('UpdatedTime', caseResult.UpdatedTime);
        if (originalRequest != null) {
            xml += buildGetOriginalRequestXml(originalRequest);
        }
        xml += '</CaseResultInfo>';
        return xml;
    }

    private static String buildGetInputSysXml(FEC_GetCSCaseStatusService.SysType sys) {
        return '<Sys>' +
            buildXmlElement('Channel', sys != null ? sys.Channel : null) +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement('DateTime', sys != null ? sys.DateTime_x : null) +
            '</Sys>';
    }

    private static String buildGetOriginalRequestXml(
        FEC_GetCSCaseStatusService.OriginalRequestType originalRequest
    ) {
        return '<OriginalRequest>' +
            buildGetInputSysXml(originalRequest.Sys) +
            buildGetCustomerInfoXml(originalRequest.CustomerInfo) +
            buildGetRequestInfoXml(originalRequest.RequestInfo) +
            buildGetCreatorInfoXml(originalRequest.CreatorInfo) +
            '</OriginalRequest>';
    }

    private static String buildGetCustomerInfoXml(
        FEC_GetCSCaseStatusService.CustomerInfoType customerInfo
    ) {
        if (customerInfo == null) {
            return '<CustomerInfo></CustomerInfo>';
        }
        return '<CustomerInfo>' +
            buildXmlElement('Name', customerInfo.Name) +
            buildXmlElement('PhoneNumber', customerInfo.PhoneNumber) +
            buildXmlElement('UserType', customerInfo.UserType) +
            buildXmlElement('NationalID', customerInfo.NationalID) +
            buildXmlElement('ContractOrAccountNumber', customerInfo.ContractOrAccountNumber) +
            buildXmlElement('EmailAddress', customerInfo.EmailAddress) +
            '</CustomerInfo>';
    }

    private static String buildGetRequestInfoXml(
        FEC_GetCSCaseStatusService.RequestInfoType requestInfo
    ) {
        if (requestInfo == null) {
            return '<RequestInfo></RequestInfo>';
        }
        String xml = '<RequestInfo>' +
            buildXmlElement('CaseType', requestInfo.CaseType) +
            buildXmlElement('ProductType', requestInfo.ProductType) +
            buildXmlElement('Category', requestInfo.Category) +
            buildXmlElement('SubCategory', requestInfo.SubCategory) +
            buildXmlElement('SubCode', requestInfo.SubCode) +
            buildXmlElement('Remarks', requestInfo.Remarks);
        if (requestInfo.AdditionalInfo != null) {
            xml += '<AdditionalInfo>' +
                buildXmlElement('ID', requestInfo.AdditionalInfo.ID) +
                buildXmlElement('Value', requestInfo.AdditionalInfo.Value) +
                '</AdditionalInfo>';
        }
        xml += '</RequestInfo>';
        return xml;
    }

    private static String buildGetCreatorInfoXml(
        FEC_GetCSCaseStatusService.CreatorInfoType creatorInfo
    ) {
        if (creatorInfo == null) {
            return '<CreatorInfo></CreatorInfo>';
        }
        return '<CreatorInfo>' +
            buildXmlElement('CreatorEmail', creatorInfo.CreatorEmail) +
            '</CreatorInfo>';
    }

    // =========================================================================
    // GetCSAttachedFile
    // =========================================================================

    public class GetCSAttachedFileParsedRequest {
        public FEC_GetCSAttachedFile.SysType Sys;
        public FEC_GetCSAttachedFile.RequestInfoType RequestInfo;
    }

    public static GetCSAttachedFileParsedRequest parseGetCSAttachedFileRequest(String rawXml) {
        Dom.XmlNode attachedReq = loadGetCSAttachedFileRequestNode(rawXml);
        GetCSAttachedFileParsedRequest parsed = new GetCSAttachedFileParsedRequest();
        parsed.Sys = mapGetAttachedFileSys(attachedReq);
        parsed.RequestInfo = mapGetAttachedFileRequestInfo(attachedReq);
        return parsed;
    }

    public static String buildGetCSAttachedFileSoapResponse(
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType resp
    ) {
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType r = resp != null
            ? resp
            : new FEC_GetCSAttachedFile.GetCSAttachedFileResponseType();

        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' + SOAP_ENV + '">' +
            '<soap:Body>' +
            '<GetCSAttachedFileResponse xmlns="' + MYCASE_NS + '">' +
            buildGetAttachedFileResponseSysXml(r.Sys) +
            buildXmlElement('FileName', r.FileName) +
            buildXmlElement('FileContent', r.FileContent) +
            buildXmlElement('FileType', r.FileType) +
            '</GetCSAttachedFileResponse></soap:Body></soap:Envelope>';
    }

    public static String buildGetCSAttachedFileErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_GetCSAttachedFile.GetCSAttachedFileResponseType err =
            new FEC_GetCSAttachedFile.GetCSAttachedFileResponseType();
        err.Sys = new FEC_GetCSAttachedFile.SysType2();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = System.now();
        err.Sys.Code = String.isNotBlank(code) ? code : FEC_ConstantCommon.CODE_SYS_ERROR;
        err.Sys.Description = message;
        err.FileName = null;
        err.FileContent = null;
        err.FileType = null;
        return buildGetCSAttachedFileSoapResponse(err);
    }

    private static Dom.XmlNode loadGetCSAttachedFileRequestNode(String rawXml) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode attachedReq = findChildByLocalName(body, 'GetCSAttachedFileRequest');
        if (attachedReq == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'GetCSAttachedFileRequest element not found'
            );
        }
        return attachedReq;
    }

    private static FEC_GetCSAttachedFile.SysType mapGetAttachedFileSys(Dom.XmlNode attachedReq) {
        FEC_GetCSAttachedFile.SysType sys = new FEC_GetCSAttachedFile.SysType();
        Dom.XmlNode sysNode = findChildByLocalName(attachedReq, 'Sys');
        if (sysNode != null) {
            sys.Channel = textOf(sysNode, 'Channel');
            sys.TransactionID = textOf(sysNode, 'TransactionID');
            sys.DateTime_x = parseIsoDateTime(textOf(sysNode, 'DateTime'));
        }
        return sys;
    }

    private static FEC_GetCSAttachedFile.RequestInfoType mapGetAttachedFileRequestInfo(
        Dom.XmlNode attachedReq
    ) {
        FEC_GetCSAttachedFile.RequestInfoType requestInfo =
            new FEC_GetCSAttachedFile.RequestInfoType();
        Dom.XmlNode requestInfoNode = findChildByLocalName(attachedReq, 'RequestInfo');
        if (requestInfoNode == null) {
            return requestInfo;
        }

        requestInfo.CaseID = textOf(requestInfoNode, 'CaseID');
        requestInfo.UserType = textOf(requestInfoNode, 'UserType');
        requestInfo.FileID = textOf(requestInfoNode, 'FileID');

        Dom.XmlNode contractInfosNode = findChildByLocalName(
            requestInfoNode,
            'ContractOrAccountInfos'
        );
        if (contractInfosNode != null) {
            requestInfo.ContractOrAccountInfos =
                new FEC_GetCSAttachedFile.ContractOrAccountInfoType();
            requestInfo.ContractOrAccountInfos.ContractOrAccountNumber = textOf(
                contractInfosNode,
                'ContractOrAccountNumber'
            );
            requestInfo.ContractOrAccountInfos.ProductType = textOf(
                contractInfosNode,
                'ProductType'
            );
        }
        return requestInfo;
    }

    private static String buildGetAttachedFileResponseSysXml(
        FEC_GetCSAttachedFile.SysType2 sys
    ) {
        return '<Sys>' +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement(
                'DateTime',
                sys != null && sys.DateTime_x != null ? String.valueOf(sys.DateTime_x) : null
            ) +
            buildXmlElement('Code', sys != null ? sys.Code : null) +
            buildXmlElement('Description', sys != null ? sys.Description : null) +
            '</Sys>';
    }

    // =========================================================================
    // GetCSMasterData
    // =========================================================================

    public static FEC_GetCSMasterDataService.SysRequestType parseGetCSMasterDataRequest(
        String rawXml
    ) {
        Dom.XmlNode masterReq = loadGetCSMasterDataRequestNode(rawXml);
        return mapGetCSMasterDataSys(masterReq);
    }

    public static String buildGetCSMasterDataSoapResponse(
        FEC_GetCSMasterDataService.GetCSMasterDataResponse resp
    ) {
        FEC_GetCSMasterDataService.GetCSMasterDataResponse r = resp != null
            ? resp
            : new FEC_GetCSMasterDataService.GetCSMasterDataResponse();

        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' + SOAP_ENV + '">' +
            '<soap:Body>' +
            '<GetCSMasterDataResponse xmlns="' + MYCASE_NS + '">' +
            buildGetCSMasterDataResponseSysXml(r.Sys) +
            buildMasterDataItemsListXml(r.MasterDataItems) +
            '</GetCSMasterDataResponse></soap:Body></soap:Envelope>';
    }

    public static String buildGetCSMasterDataErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_GetCSMasterDataService.GetCSMasterDataResponse err =
            new FEC_GetCSMasterDataService.GetCSMasterDataResponse();
        err.Sys = new FEC_GetCSMasterDataService.SysResponseType();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = System.now();
        err.Sys.Code = String.isNotBlank(code) ? code : FEC_ConstantCommon.CODE_FAILURE;
        err.Sys.Description = message;
        err.MasterDataItems = new List<FEC_GetCSMasterDataService.MasterDataItemType>();
        return buildGetCSMasterDataSoapResponse(err);
    }

    private static Dom.XmlNode loadGetCSMasterDataRequestNode(String rawXml) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode masterReq = findChildByLocalName(body, 'GetCSMasterDataRequest');
        if (masterReq == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'GetCSMasterDataRequest element not found'
            );
        }
        return masterReq;
    }

    private static FEC_GetCSMasterDataService.SysRequestType mapGetCSMasterDataSys(
        Dom.XmlNode masterReq
    ) {
        FEC_GetCSMasterDataService.SysRequestType sys =
            new FEC_GetCSMasterDataService.SysRequestType();
        Dom.XmlNode sysNode = findChildByLocalName(masterReq, 'Sys');
        if (sysNode != null) {
            sys.Channel = textOf(sysNode, 'Channel');
            sys.TransactionID = textOf(sysNode, 'TransactionID');
            sys.DateTime_x = parseIsoDateTime(textOf(sysNode, 'DateTime'));
        }
        return sys;
    }

    private static String buildGetCSMasterDataResponseSysXml(
        FEC_GetCSMasterDataService.SysResponseType sys
    ) {
        return '<Sys>' +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement(
                'DateTime',
                sys != null && sys.DateTime_x != null ? String.valueOf(sys.DateTime_x) : null
            ) +
            buildXmlElement('Code', sys != null ? sys.Code : null) +
            buildXmlElement('Description', sys != null ? sys.Description : null) +
            '</Sys>';
    }

    private static String buildMasterDataItemsListXml(
        List<FEC_GetCSMasterDataService.MasterDataItemType> items
    ) {
        if (items == null || items.isEmpty()) {
            return '';
        }
        String xml = '';
        for (FEC_GetCSMasterDataService.MasterDataItemType item : items) {
            xml += buildMasterDataItemXml(item);
        }
        return xml;
    }

    private static String buildMasterDataItemXml(
        FEC_GetCSMasterDataService.MasterDataItemType item
    ) {
        if (item == null) {
            return '';
        }
        return '<MasterDataItems>' +
            buildXmlElement('ID', item.ID) +
            buildXmlElement('Name', item.Name) +
            buildXmlElement('NameVN', item.NameVN) +
            buildXmlIntegerElement('PosOrder', item.PosOrder) +
            buildXmlElement('ApplyTo', item.ApplyTo) +
            buildXmlElement('Type', item.Type) +
            buildMasterDataAdditionalPropertiesXml(item.AdditionalProperties) +
            buildMasterDataChildrenXml(item.Children) +
            '</MasterDataItems>';
    }

    private static String buildMasterDataChildrenXml(
        List<FEC_GetCSMasterDataService.ChildItemType> children
    ) {
        if (children == null || children.isEmpty()) {
            return '';
        }
        String xml = '';
        for (FEC_GetCSMasterDataService.ChildItemType child : children) {
            xml += buildMasterDataChildXml(child);
        }
        return xml;
    }

    private static String buildMasterDataChildXml(
        FEC_GetCSMasterDataService.ChildItemType child
    ) {
        if (child == null) {
            return '';
        }
        return '<Children>' +
            buildXmlElement('ID', child.ID) +
            buildXmlElement('Name', child.Name) +
            buildXmlElement('NameVN', child.NameVN) +
            buildXmlIntegerElement('PosOrder', child.PosOrder) +
            buildXmlElement('ApplyTo', child.ApplyTo) +
            buildXmlElement('Type', child.Type) +
            buildMasterDataAdditionalPropertiesXml(child.AdditionalProperties) +
            buildMasterDataChildrenXml(child.Children) +
            '</Children>';
    }

    private static String buildMasterDataAdditionalPropertiesXml(
        List<FEC_GetCSMasterDataService.AdditionalPropertyType> properties
    ) {
        if (properties == null || properties.isEmpty()) {
            return '';
        }
        String xml = '';
        for (FEC_GetCSMasterDataService.AdditionalPropertyType property : properties) {
            xml += buildMasterDataAdditionalPropertyXml(property);
        }
        return xml;
    }

    private static String buildMasterDataAdditionalPropertyXml(
        FEC_GetCSMasterDataService.AdditionalPropertyType property
    ) {
        if (property == null) {
            return '';
        }
        return '<AdditionalProperties>' +
            buildXmlElement('ID', property.ID) +
            buildXmlElement('Name', property.Name) +
            buildXmlElement('NameVN', property.NameVN) +
            buildXmlIntegerElement('PosOrder', property.PosOrder) +
            buildXmlElement('ApplyTo', property.ApplyTo) +
            buildXmlBooleanElement('Mandatory', property.Mandatory) +
            buildMasterDataAvailableValuesXml(property.AvailableValues) +
            buildXmlElement('Type', property.Type) +
            '</AdditionalProperties>';
    }

    private static String buildMasterDataAvailableValuesXml(
        List<FEC_GetCSMasterDataService.AvailableValueType> values
    ) {
        if (values == null || values.isEmpty()) {
            return '';
        }
        String xml = '';
        for (FEC_GetCSMasterDataService.AvailableValueType value : values) {
            if (value == null) {
                continue;
            }
            xml += '<AvailableValues>' +
                buildXmlElement('ID', value.ID) +
                buildXmlElement('Name', value.Name) +
                buildXmlElement('NameVN', value.NameVN) +
                '</AvailableValues>';
        }
        return xml;
    }

    private static String buildXmlIntegerElement(String tag, Integer value) {
        return value == null ? '' : buildXmlElement(tag, String.valueOf(value));
    }

    private static String buildXmlBooleanElement(String tag, Boolean value) {
        return value == null ? '' : buildXmlElement(tag, String.valueOf(value));
    }

    // =========================================================================
    // GetCSMasterDataByCode
    // =========================================================================

    public class GetCSMasterDataByCodeParsedRequest {
        public FEC_GetCSMasterDataByCodeService.SysRequestType Sys;
        public FEC_GetCSMasterDataByCodeService.MasterDataCodeType MasterDataCode;
        public FEC_GetCSMasterDataByCodeService.CustomerTypeRequest CustomerType;
        public FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest AdditionalInfo;
        public String Remarks;
    }

    public static GetCSMasterDataByCodeParsedRequest parseGetCSMasterDataByCodeRequest(
        String rawXml
    ) {
        Dom.XmlNode byCodeReq = loadGetCSMasterDataByCodeRequestNode(rawXml);
        GetCSMasterDataByCodeParsedRequest parsed = new GetCSMasterDataByCodeParsedRequest();
        parsed.Sys = mapGetCSMasterDataByCodeSys(byCodeReq);
        parsed.MasterDataCode = mapGetCSMasterDataByCodeMasterDataCode(byCodeReq);
        parsed.CustomerType = mapGetCSMasterDataByCodeCustomerType(byCodeReq);
        parsed.AdditionalInfo = mapGetCSMasterDataByCodeAdditionalInfo(byCodeReq);
        parsed.Remarks = textOf(byCodeReq, 'Remarks');
        return parsed;
    }

    public static String buildGetCSMasterDataByCodeSoapResponse(
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse resp
    ) {
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse r = resp != null
            ? resp
            : new FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse();

        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="' + SOAP_ENV + '">' +
            '<soap:Body>' +
            '<GetCSMasterDataByCodeResponse xmlns="' + MYCASE_NS + '">' +
            buildGetCSMasterDataByCodeResponseSysXml(r.Sys) +
            buildGetCSMasterDataByCodeRequestInfoXml(r.RequestInfo) +
            buildGetCSMasterDataByCodeCustomerInfoXml(r.CustomerInfo) +
            buildGetCSMasterDataByCodeDataItemsListXml(r.DataItems) +
            buildGetCSMasterDataByCodeAdditionalInfoXml(r.AdditionalInfo) +
            '</GetCSMasterDataByCodeResponse></soap:Body></soap:Envelope>';
    }

    public static String buildGetCSMasterDataByCodeErrorSoapResponse(
        String transactionId,
        String code,
        String message
    ) {
        FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse err =
            new FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse();
        err.Sys = new FEC_GetCSMasterDataByCodeService.SysResponseType();
        err.Sys.TransactionID = transactionId;
        err.Sys.DateTime_x = System.now();
        err.Sys.Code = String.isNotBlank(code) ? code : FEC_ConstantCommon.CODE_SYS_ERROR;
        err.Sys.Description = message;
        err.DataItems = new List<FEC_GetCSMasterDataByCodeService.DataItemType>();
        return buildGetCSMasterDataByCodeSoapResponse(err);
    }

    private static Dom.XmlNode loadGetCSMasterDataByCodeRequestNode(String rawXml) {
        if (String.isBlank(rawXml)) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
            );
        }

        Dom.Document doc = new Dom.Document();
        try {
            doc.load(rawXml.trim());
        } catch (Exception e) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'Invalid XML: ' + e.getMessage()
            );
        }

        Dom.XmlNode body = findSoapBody(doc.getRootElement());
        if (body == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'SOAP Body not found'
            );
        }

        Dom.XmlNode byCodeReq = findChildByLocalName(body, 'GetCSMasterDataByCodeRequest');
        if (byCodeReq == null) {
            throw new SoapParseException(
                null,
                FEC_ConstantCommon.CODE_FAILURE,
                'GetCSMasterDataByCodeRequest element not found'
            );
        }
        return byCodeReq;
    }

    private static FEC_GetCSMasterDataByCodeService.SysRequestType mapGetCSMasterDataByCodeSys(
        Dom.XmlNode byCodeReq
    ) {
        FEC_GetCSMasterDataByCodeService.SysRequestType sys =
            new FEC_GetCSMasterDataByCodeService.SysRequestType();
        Dom.XmlNode sysNode = findChildByLocalName(byCodeReq, 'Sys');
        if (sysNode != null) {
            sys.Channel = textOf(sysNode, 'Channel');
            sys.TransactionID = textOf(sysNode, 'TransactionID');
            sys.DateTime_x = parseIsoDateTime(textOf(sysNode, 'DateTime'));
        }
        return sys;
    }

    private static FEC_GetCSMasterDataByCodeService.MasterDataCodeType mapGetCSMasterDataByCodeMasterDataCode(
        Dom.XmlNode byCodeReq
    ) {
        FEC_GetCSMasterDataByCodeService.MasterDataCodeType masterDataCode =
            new FEC_GetCSMasterDataByCodeService.MasterDataCodeType();
        Dom.XmlNode masterDataCodeNode = findChildByLocalName(byCodeReq, 'MasterDataCode');
        if (masterDataCodeNode == null) {
            return masterDataCode;
        }
        masterDataCode.CaseType = textOf(masterDataCodeNode, 'CaseType');
        masterDataCode.Category = textOf(masterDataCodeNode, 'Category');
        masterDataCode.SubCategory = textOf(masterDataCodeNode, 'SubCategory');
        masterDataCode.ProductType = textOf(masterDataCodeNode, 'ProductType');
        masterDataCode.SubCode = textOf(masterDataCodeNode, 'SubCode');
        return masterDataCode;
    }

    private static FEC_GetCSMasterDataByCodeService.CustomerTypeRequest mapGetCSMasterDataByCodeCustomerType(
        Dom.XmlNode byCodeReq
    ) {
        FEC_GetCSMasterDataByCodeService.CustomerTypeRequest customerType =
            new FEC_GetCSMasterDataByCodeService.CustomerTypeRequest();
        Dom.XmlNode customerTypeNode = findChildByLocalName(byCodeReq, 'CustomerType');
        if (customerTypeNode == null) {
            return customerType;
        }
        customerType.UserType = textOf(customerTypeNode, 'UserType');
        customerType.Language = textOf(customerTypeNode, 'Language');
        return customerType;
    }

    private static FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest mapGetCSMasterDataByCodeAdditionalInfo(
        Dom.XmlNode byCodeReq
    ) {
        FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest additionalInfo =
            new FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest();
        Dom.XmlNode additionalInfoNode = findChildByLocalName(byCodeReq, 'AdditionalInfo');
        if (additionalInfoNode == null) {
            return additionalInfo;
        }
        additionalInfo.ID = textOf(additionalInfoNode, 'ID');
        additionalInfo.Value = textOf(additionalInfoNode, 'Value');
        return additionalInfo;
    }

    private static String buildGetCSMasterDataByCodeResponseSysXml(
        FEC_GetCSMasterDataByCodeService.SysResponseType sys
    ) {
        return '<Sys>' +
            buildXmlElement('TransactionID', sys != null ? sys.TransactionID : null) +
            buildXmlElement(
                'DateTime',
                sys != null && sys.DateTime_x != null ? String.valueOf(sys.DateTime_x) : null
            ) +
            buildXmlElement('Code', sys != null ? sys.Code : null) +
            buildXmlElement('Description', sys != null ? sys.Description : null) +
            '</Sys>';
    }

    private static String buildGetCSMasterDataByCodeRequestInfoXml(
        FEC_GetCSMasterDataByCodeService.RequestInfoType requestInfo
    ) {
        if (requestInfo == null) {
            return '<RequestInfo></RequestInfo>';
        }
        String productLineXml = String.isNotBlank(requestInfo.ProductLineId)
            ? '<ContractOrAccountInfos>' +
                buildXmlElement('ProductType', requestInfo.ProductLineId) +
                '</ContractOrAccountInfos>'
            : '';
        return '<RequestInfo>' +
            productLineXml +
            buildXmlElement('Category', requestInfo.Category) +
            buildXmlElement('SubCategory', requestInfo.SubCategory) +
            buildXmlElement('SubCode', requestInfo.SubCode) +
            buildXmlElement('CaseType', requestInfo.CaseType) +
            buildXmlElement('Remarks', requestInfo.Remarks) +
            '</RequestInfo>';
    }

    private static String buildGetCSMasterDataByCodeCustomerInfoXml(
        FEC_GetCSMasterDataByCodeService.CustomerTypeRequest customerInfo
    ) {
        if (customerInfo == null) {
            return '<CustomerInfo></CustomerInfo>';
        }
        return '<CustomerInfo>' +
            buildXmlElement('UserType', customerInfo.UserType) +
            buildXmlElement('Language', customerInfo.Language) +
            '</CustomerInfo>';
    }

    private static String buildGetCSMasterDataByCodeDataItemsListXml(
        List<FEC_GetCSMasterDataByCodeService.DataItemType> items
    ) {
        if (items == null || items.isEmpty()) {
            return '';
        }
        String xml = '';
        for (FEC_GetCSMasterDataByCodeService.DataItemType item : items) {
            xml += buildGetCSMasterDataByCodeDataItemXml(item);
        }
        return xml;
    }

    private static String buildGetCSMasterDataByCodeDataItemXml(
        FEC_GetCSMasterDataByCodeService.DataItemType item
    ) {
        if (item == null) {
            return '';
        }
        return '<DataItems>' +
            buildXmlElement('ID', item.ID) +
            buildXmlElement('Name', item.Name) +
            buildXmlElement('NameVN', item.NameVN) +
            buildXmlIntegerElement('PosOrder', item.PosOrder) +
            buildXmlElement('ApplyTo', item.ApplyTo) +
            buildXmlElement('Type', item.Type) +
            '</DataItems>';
    }

    private static String buildGetCSMasterDataByCodeAdditionalInfoXml(
        FEC_GetCSMasterDataByCodeService.AdditionalInfoRequest additionalInfo
    ) {
        if (additionalInfo == null) {
            return '';
        }
        if (String.isBlank(additionalInfo.ID) && String.isBlank(additionalInfo.Value)) {
            return '';
        }
        return '<AdditionalProperties>' +
            buildXmlElement('ID', additionalInfo.ID) +
            buildXmlElement('Value', additionalInfo.Value) +
            '</AdditionalProperties>';
    }

    private static FEC_CreateCSCaseService.CaseRequestType mapCreateCSCaseRequest(
        Dom.XmlNode createReq
    ) {
        FEC_CreateCSCaseService.CaseRequestType req =
            new FEC_CreateCSCaseService.CaseRequestType();

        Dom.XmlNode sysNode = findChildByLocalName(createReq, 'Sys');
        if (sysNode != null) {
            req.Sys = new FEC_CreateCSCaseService.SysType();
            req.Sys.Channel = textOf(sysNode, 'Channel');
            req.Sys.SubChannel = textOf(sysNode, 'SubChannel');
            req.Sys.TransactionID = textOf(sysNode, 'TransactionID');
            req.Sys.DateTime_x = parseIsoDateTime(textOf(sysNode, 'DateTime'));
        }

        Dom.XmlNode customerNode = findChildByLocalName(createReq, 'CustomerInfo');
        if (customerNode != null) {
            req.CustomerInfo = new FEC_CreateCSCaseService.CustomerInfoType();
            req.CustomerInfo.Name = textOf(customerNode, 'Name');
            req.CustomerInfo.PhoneNumber = textOf(customerNode, 'PhoneNumber');
            req.CustomerInfo.UserType = textOf(customerNode, 'UserType');
            req.CustomerInfo.NationalID = textOf(customerNode, 'NationalID');
            req.CustomerInfo.ContractOrAccountNumber = textOf(
                customerNode,
                'ContractOrAccountNumber'
            );
            req.CustomerInfo.EmailAddress = textOf(customerNode, 'EmailAddress');
        }

        Dom.XmlNode requestInfoNode = findChildByLocalName(createReq, 'RequestInfo');
        if (requestInfoNode != null) {
            req.RequestInfo = new FEC_CreateCSCaseService.RequestInfoType();
            req.RequestInfo.CaseType = textOf(requestInfoNode, 'CaseType');
            req.RequestInfo.RequestType = textOf(requestInfoNode, 'RequestType');
            req.RequestInfo.ProductType = textOf(requestInfoNode, 'ProductType');
            req.RequestInfo.Category = textOf(requestInfoNode, 'Category');
            req.RequestInfo.SubCategory = textOf(requestInfoNode, 'SubCategory');
            req.RequestInfo.SubCode = textOf(requestInfoNode, 'SubCode');
            req.RequestInfo.Remarks = textOf(requestInfoNode, 'Remarks');

            List<FEC_CreateCSCaseService.AdditionalInfoType> additional =
                new List<FEC_CreateCSCaseService.AdditionalInfoType>();
            for (Dom.XmlNode child : requestInfoNode.getChildElements()) {
                if (!'AdditionalInfo'.equalsIgnoreCase(localName(child))) {
                    continue;
                }
                FEC_CreateCSCaseService.AdditionalInfoType info =
                    new FEC_CreateCSCaseService.AdditionalInfoType();
                info.ID = textOf(child, 'ID');
                info.Value = textOf(child, 'Value');
                additional.add(info);
            }
            if (!additional.isEmpty()) {
                req.RequestInfo.AdditionalInfo = additional;
            }
        }

        Dom.XmlNode creatorNode = findChildByLocalName(createReq, 'CreatorInfo');
        if (creatorNode != null) {
            req.CreatorInfo = new FEC_CreateCSCaseService.CreatorInfoType();
            req.CreatorInfo.CreatorEmail = textOf(creatorNode, 'CreatorEmail');
            req.CreatorInfo.CreatorName = textOf(creatorNode, 'CreatorName');
            req.CreatorInfo.CreatorCode = textOf(creatorNode, 'CreatorCode');
            req.CreatorInfo.CreatorDepartment = textOf(
                creatorNode,
                'CreatorDepartment'
            );
            req.CreatorInfo.CreatorPosition = textOf(creatorNode, 'CreatorPosition');
        }

        return req;
    }

    /**
     * Map Interaction Case DTO từ XML CreateCSCase (Channel/SubChannel từ Sys).
     * Chỉ gọi từ FEC_CreateCSCaseService.CreateCSCaseRequest (MyCase API).
     * //Thangtv
     */
    public static FEC_CreateCaseHandler.FEC_InteractionCaseDTO buildInteractionCaseDto(
        FEC_CreateCSCaseService.CaseRequestType req
    ) {
        FEC_CreateCaseHandler.FEC_InteractionCaseDTO dto =
            new FEC_CreateCaseHandler.FEC_InteractionCaseDTO();

        if (req == null) {
            return dto;
        }

        if (req.Sys != null && String.isNotBlank(req.Sys.Channel)) {
            dto.channel = req.Sys.Channel.trim(); //Thangtv: FEC_Channel__c từ Sys.Channel XML
        }
        if (req.Sys != null && String.isNotBlank(req.Sys.SubChannel)) {
            dto.subChannel = req.Sys.SubChannel.trim();
        }
        if (req.CustomerInfo != null) {
            dto.phoneNumber = req.CustomerInfo.PhoneNumber;
            dto.email = req.CustomerInfo.EmailAddress;
        }
        return dto;
    }

    private static Dom.XmlNode findSoapBody(Dom.XmlNode root) {
        if (root == null) {
            return null;
        }
        Dom.XmlNode body = root.getChildElement('Body', SOAP_ENV);
        if (body != null) {
            return body;
        }
        return findChildByLocalName(root, 'Body');
    }

    private static Dom.XmlNode findChildByLocalName(Dom.XmlNode parent, String localName) {
        if (parent == null || String.isBlank(localName)) {
            return null;
        }
        for (Dom.XmlNode child : parent.getChildElements()) {
            if (localName.equalsIgnoreCase(localName(child))) {
                return child;
            }
        }
        return null;
    }

    private static String textOf(Dom.XmlNode parent, String childLocalName) {
        Dom.XmlNode child = findChildByLocalName(parent, childLocalName);
        if (child == null) {
            return null;
        }
        String value = child.getText();
        return value != null ? value.trim() : null;
    }

    private static String localName(Dom.XmlNode node) {
        if (node == null) {
            return null;
        }
        String name = node.getName();
        if (String.isBlank(name)) {
            return name;
        }
        Integer colonPos = name.indexOf(':');
        return colonPos >= 0 ? name.substring(colonPos + 1) : name;
    }

    private static Datetime parseIsoDateTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.trim();
        Boolean isUtc = normalized.endsWithIgnoreCase('Z');
        normalized = normalized.replace('Z', '').replace('z', '').replace('T', ' ');
        if (normalized.contains('.')) {
            normalized = normalized.substring(0, normalized.indexOf('.'));
        }
        if (normalized.length() > 19) {
            normalized = normalized.substring(0, 19);
        }
        try {
            return isUtc ? Datetime.valueOfGmt(normalized) : Datetime.valueOf(normalized);
        } catch (Exception e) {
            return null;
        }
    }

    private static String xmlEscape(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
}