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

    private static final String CIF_NS  = 'http://fecredit.com.vn/CIF_CustomerInfo';
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://f7589df3-646e-4406-92b4-d6bc1964e063.mock.pstmn.io';

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


        validateRequest(transId, requestorId, dateTimeStr, cifNumber);
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
        req.setMethod('POST');
        req.setTimeout(120000);

        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CustomerInfo/GetDocumentsList');

        req.setBody(
            buildSoapBody(transId, requestorId, dateTimeStr, cifNumber)
        );

        HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }

        return response;
    }

    // =========================================================================
    // BUILD SOAP BODY
    // =========================================================================
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope =
            doc.createRootElement(
                'soapenv:Envelope',
                FEC_ConstantCommon.SOAP_ENV,
                'soapenv'
            );

        envelope.setAttribute('xmlns:cif', CIF_NS);

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('cif:GetDocumentsList', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null)
            .addTextNode(transId);
        sys.addChildElement('RequestorID', null, null)
            .addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null)
            .addTextNode(dateTimeStr);

        action.addChildElement('CIFNumber', null, null)
            .addTextNode(cifNumber);

        return doc.toXmlString();
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
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        
        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_APS, FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL };
        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {

            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{dateTimeStr})
            );
        }

        // ===================== CIF NUMBER =====================
        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }
        if (cifNumber.length() > 255) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'CifNumber', '255'})
            );
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
                FEC_ConstantCommon.SOAP_ENV
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
            result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // ================= CIF NUMBER =================
        result.CIFNumber = FEC_CommonUltils.getXmlValue(responseNode, 'CIFNumber');

        // ================= DOCUMENTS =================
        result.Documents = new List<DocumentInfo>();

        Dom.XmlNode documentsNode =
            responseNode.getChildElement('Documents', null);

        if (documentsNode != null) {
            for (Dom.XmlNode dNode : documentsNode.getChildElements()) {
                if (dNode.getName() == 'Document') {
                    DocumentInfo d = new DocumentInfo();
                    d.DocumentID = FEC_CommonUltils.getXmlValue(dNode, 'DocumentID');
                    d.DocumentType = FEC_CommonUltils.getXmlValue(dNode, 'DocumentType');
                    d.IssueDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(dNode, 'IssueDate'));
                    d.IDDocumentNumber = FEC_CommonUltils.getXmlValue(dNode, 'IDDocumentNumber');
                    d.IssuePlace = FEC_CommonUltils.getXmlValue(dNode, 'IssuePlace');
                    d.OmnidocsLink = FEC_CommonUltils.getXmlValue(dNode, 'OmnidocsLink');
                    result.Documents.add(d);
                }
            }
        }

        return result;
    }

}