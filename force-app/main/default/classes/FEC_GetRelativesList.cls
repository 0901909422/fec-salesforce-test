/****************************************************************************************
 * File Name    : FEC_GetRelativesList
 * Author       : Quangdv7
 * Date         : 2026-01-10
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-10    Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetRelativesList {

    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://402b743b-c2fe-4963-9461-82c1aa9ad5ea.mock.pstmn.io';

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<RelativeInfo> Relatives;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class RelativeInfo {
        public String RelationType;
        public String FullName;
        public String PhoneNumber;
        public String NumberStr;
        public String Building;
        public String Street;
        public String Ward;
        public String City;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetRelativesList(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
       

        validateRequest(transID, requestorId, dateTimeStr, cifNumber);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CustomerInfo/GetRelativesList');
        req.setBody(
            buildSoapBody(transID, requestorId, dateTimeStr, cifNumber)
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

    /* =====================================================
       SOAP BODY
       ===================================================== */
    private static String buildSoapBody(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );

        envelope.setAttribute(
            'xmlns:cif',
            'http://fecredit.com.vn/CIF_CustomerInfo'
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('cif:GetRelativesList', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('cifNumber', null, null)
              .addTextNode(cifNumber);

        return doc.toXmlString();
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }

        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_APS,
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{dateTimeStr})
            );
        }
    }

    // =========================================================================
    // RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // SYS
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // CIF NUMBER
        result.CIFNumber = FEC_CommonUltils.getXmlValue(responseNode, 'CIFNumber');

        // RELATIVES
        result.Relatives = new List<RelativeInfo>();
        Dom.XmlNode relativesNode = responseNode.getChildElement('Relatives', null);
        if (relativesNode != null) {
            for (Dom.XmlNode r : relativesNode.getChildElements()) {
                RelativeInfo rel = new RelativeInfo();
                rel.RelationType = FEC_CommonUltils.getXmlValue(r, 'RelationType');
                rel.FullName = FEC_CommonUltils.getXmlValue(r, 'FullName');
                rel.PhoneNumber = FEC_CommonUltils.getXmlValue(r, 'PhoneNumber');
                rel.NumberStr = FEC_CommonUltils.getXmlValue(r, 'Number');
                rel.Building = FEC_CommonUltils.getXmlValue(r, 'Building');
                rel.Street = FEC_CommonUltils.getXmlValue(r, 'Street');
                rel.Ward = FEC_CommonUltils.getXmlValue(r, 'Ward');
                rel.City = FEC_CommonUltils.getXmlValue(r, 'City');
                result.Relatives.add(rel);
            }
        }

        return result;
    }

}