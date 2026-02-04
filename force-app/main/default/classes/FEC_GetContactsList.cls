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

        String soapBody = buildSoapBody(transId, requestorId, dateTimeStr, cifNumber);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Contacts_List');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_CONTACTS_LIST_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode()})
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
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }

        Set<String> validRequestorIds =
            new Set<String>{ FEC_ConstantCommon.REQUESTOR_APS, FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL, FEC_ConstantCommon.REQUESTOR_PEGA };

        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{dateTimeStr}));
        }

        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }

        if (cifNumber.length() > 255) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'CifNumber', '255'}));
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
            envelope.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        if (responseNode == null) {
            throw new CalloutException(System.Label.FEC_MSG_Response_Null);
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
            result.Sys.TransID     = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code        = Integer.valueOf(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        /* ===== CIF ===== */
        result.CIFNumber = FEC_CommonUltils.getXmlValue(resultNode, 'CIFNumber');

        /* ===== CONTACTS ===== */
        result.Contacts = new List<ContactInfo>();
        Dom.XmlNode contactsNode = getChild(resultNode, 'Contacts');

        if (contactsNode != null) {
            for (Dom.XmlNode cNode : contactsNode.getChildElements()) {
                if (cNode.getName().endsWith('Contact')) {
                    ContactInfo c = new ContactInfo();
                    c.ContactId         = FEC_CommonUltils.getXmlValue(cNode, 'ContactId');
                    c.Channel           = FEC_CommonUltils.getXmlValue(cNode, 'Channel');
                    c.CommunicationType = FEC_CommonUltils.getXmlValue(cNode, 'CommunicationType');
                    c.ContactString     = FEC_CommonUltils.getXmlValue(cNode, 'ContactString');
                    c.OfficeExtension   = FEC_CommonUltils.getXmlValue(cNode, 'OfficeExtension');
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