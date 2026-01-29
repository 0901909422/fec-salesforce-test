/****************************************************************************************
 * File Name    : FEC_GetContactsList
 * Author       : Quangdv7
 * Date         : 2026-01-17
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-17     Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetContactsList {

    /* =====================================================
       CONSTANTS
       ===================================================== */
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String SOAP_ENV_NS =
        'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String MOCKUP_ENDPOINT = 'https://4c75f566-6635-45c2-b066-1b73036661d6.mock.pstmn.io';


    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<ContactInfo> Contacts;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class ContactInfo {
        public String ContactId;
        public String Channel;
        public String CommunicationType;
        public String ContactString;
        public String OfficeExtension;
    }

    /* =====================================================
       PUBLIC METHOD
       ===================================================== */
    public static ResponseWrapper callGetContactsList(
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
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/CIF_CustomerInfo/GetContactsList'
        );

        req.setBody(buildSoapBody(transId, requestorId, dateTimeStr, cifNumber));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                'GetContactsList HTTP error: ' + res.getStatusCode()
            );
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys == null || response.Sys.Code != 1) {
            throw new CalloutException(
                response.Sys != null
                    ? response.Sys.Description
                    : 'GetContactsList returned error'
            );
        }

        return response;
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException('Invalid TransID');
        }

        Set<String> validRequestorIds =
            new Set<String>{ 'APS', 'CRM', 'PORTAL', 'PEGA' };

        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException('Invalid RequestorID');
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException('Invalid DateTime');
        }

        if (String.isBlank(cifNumber) || cifNumber.length() > 255) {
            throw new CalloutException('Invalid CIFNumber');
        }
    }

    /* =====================================================
       SOAP PARSER (PREFIX + RESULT SAFE)
       ===================================================== */
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode =
            envelope.getChildElement('Body', SOAP_ENV_NS);

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        if (responseNode == null) {
            throw new CalloutException('SOAP Body empty');
        }

        Dom.XmlNode resultNode = getChild(responseNode, 'GetContactsListResult');
        if (resultNode == null) {
            resultNode = responseNode;
        }

        ResponseWrapper result = new ResponseWrapper();

        /* ===== SYS ===== */
        Dom.XmlNode sysNode = getChild(resultNode, 'Sys');
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID     = getVal(sysNode, 'TransID');
            result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
            result.Sys.Code        = Integer.valueOf(getVal(sysNode, 'Code'));
            result.Sys.Description = getVal(sysNode, 'Description');
        }

        /* ===== CIF ===== */
        result.CIFNumber = getVal(resultNode, 'CIFNumber');

        /* ===== CONTACTS ===== */
        result.Contacts = new List<ContactInfo>();
        Dom.XmlNode contactsNode = getChild(resultNode, 'Contacts');

        if (contactsNode != null) {
            for (Dom.XmlNode cNode : contactsNode.getChildElements()) {
                if (cNode.getName().endsWith('Contact')) {
                    ContactInfo c = new ContactInfo();
                    c.ContactId         = getVal(cNode, 'ContactId');
                    c.Channel           = getVal(cNode, 'Channel');
                    c.CommunicationType = getVal(cNode, 'CommunicationType');
                    c.ContactString     = getVal(cNode, 'ContactString');
                    c.OfficeExtension   = getVal(cNode, 'OfficeExtension');
                    result.Contacts.add(c);
                }
            }
        }

        return result;
    }

    /* =====================================================
       HELPERS
       ===================================================== */
    private static Dom.XmlNode getChild(Dom.XmlNode parent, String name) {
        if (parent == null) return null;
        for (Dom.XmlNode c : parent.getChildElements()) {
            if (c.getName().endsWith(name)) {
                return c;
            }
        }
        return null;
    }

    private static String getVal(Dom.XmlNode node, String name) {
        Dom.XmlNode c = getChild(node, name);
        return c == null ? null : c.getText();
    }

    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<cif:GetContactsList>' +
                        '<Sys>' +
                            '<TransID>' + transId + '</TransID>' +
                            '<RequestorID>' + requestorId + '</RequestorID>' +
                            '<DateTime>' + dateTimeStr + '</DateTime>' +
                        '</Sys>' +
                        '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                    '</cif:GetContactsList>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }
}