/****************************************************************************************
 * File Name    : FEC_GetDocumentsList
 * Author       : Quangdv7
 * Date         : 2026-01-17
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-17    Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetDocumentsList {

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://241aef91-9cc1-4b9c-9618-629c9b022c47.mock.pstmn.io';


    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<DocumentInfo> Documents;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class DocumentInfo {
        public String DocumentID;
        public String DocumentType;
        public Date IssueDate;
        public String IDDocumentNumber;
        public String IssuePlace;
        public String OmnidocsLink;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetDocumentsList(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        try {

            validateRequest(transId, requestorId, dateTimeStr, cifNumber);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);

            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CustomerInfo/GetDocumentsList');

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<cif:GetDocumentsList>' +
                            '<Sys>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                        '</cif:GetDocumentsList>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetDocumentsList service returned HTTP error: ' +
                    res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                        ? response.Sys.Description
                        : 'GetDocumentsList service returned error'
                );
            }

            return response;

        } catch (Exception ex) {
            System.debug('### GET DOCUMENTS LIST ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        // ===================== TRANSID =====================
        if (String.isBlank(transId)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (transId.length() > 36) {
            throw new CalloutException(
                'TransID is null or invalid or no longer than 36 characters'
            );
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{ 'APS', 'CRM', 'PORTAL' };
        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {

            throw new CalloutException(
                'RequestorID is null or invalid, "' +
                requestorId +
                '" is not type of RequestorID'
            );
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime is null or invalid, "' +
                dateTimeStr +
                '" is not type of Datetime'
            );
        }

        // ===================== CIF NUMBER =====================
        if (String.isBlank(cifNumber)) {
            throw new CalloutException('CIFNumber is null or invalid');
        }
        if (cifNumber.length() > 255) {
            throw new CalloutException(
                'CIFNumber is null or invalid or no longer than 255 characters'
            );
        }

        Boolean cifExists = true;
        if (!cifExists) {
            throw new CalloutException('CIFNumber is null or invalid');
        }
    }

    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode =
            envelope.getChildElement(
                'Body',
                'http://schemas.xmlsoap.org/soap/envelope/'
            );

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ================= SYS =================
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = getVal(sysNode, 'TransID');
            result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
            result.Sys.Code = toInteger(getVal(sysNode, 'Code'));
            result.Sys.Description = getVal(sysNode, 'Description');
        }

        // ================= CIF NUMBER =================
        result.CIFNumber = getVal(responseNode, 'CIFNumber');

        // ================= DOCUMENTS =================
        result.Documents = new List<DocumentInfo>();

        Dom.XmlNode documentsNode =
            responseNode.getChildElement('Documents', null);

        if (documentsNode != null) {
            for (Dom.XmlNode dNode : documentsNode.getChildElements()) {
                if (dNode.getName() == 'Document') {
                    DocumentInfo d = new DocumentInfo();
                    d.DocumentID = getVal(dNode, 'DocumentID');
                    d.DocumentType = getVal(dNode, 'DocumentType');
                    d.IssueDate = toDate(getVal(dNode, 'IssueDate'));
                    d.IDDocumentNumber = getVal(dNode, 'IDDocumentNumber');
                    d.IssuePlace = getVal(dNode, 'IssuePlace');
                    d.OmnidocsLink = getVal(dNode, 'OmnidocsLink');
                    result.Documents.add(d);
                }
            }
        }

        return result;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode node, String name) {
        if (node == null) return null;
        Dom.XmlNode c = node.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Integer toInteger(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }

    private static Date toDate(String v) {
        return String.isBlank(v) ? null : Date.valueOf(v);
    }
}