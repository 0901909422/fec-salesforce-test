/****************************************************************************************
 * File Name    : FEC_GetApplicationsList
 * Author       : Quangdv7
 * Date         : 2026-01-10
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-10    Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetApplicationsList {

    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://fd9aa4d8-7d69-4390-8d25-79e29d6669c3.mock.pstmn.io';

    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<ApplicationInfo> Applications;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class ApplicationInfo {
        public String ApplicationID;
        public String ProductGroup;
        public String DateStatus;
        public String LastStatus;
        public String SaleName;
        public String SaleUnitCode;
        public String SalePhoneNumber;
        public String PersonId;
        public String SystemId;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetApplicationsList(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        validateRequest(transID, requestorId, dateTimeStr, cifNumber);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            apiSetting?.FEC_Call_Mock__c
                ? MOCKUP_ENDPOINT
                : apiSetting.FEC_Endpoint__c + ENDPOINT
        );
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/CIF_CustomerInfo/GetApplicationsList'
        );

        req.setBody(
            buildSoapBody(
                transID,
                requestorId,
                dateTimeStr,
                cifNumber
            )
        );

        Http http = new Http();
        HttpResponse res = http.send(req);

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
       SOAP BODY BUILDER
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

        Dom.XmlNode body = envelope.addChildElement(
            'soapenv:Body',
            null,
            null
        );

        Dom.XmlNode action = body.addChildElement(
            'cif:GetApplicationsList',
            null,
            null
        );

        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('CIFNumber', null, null)
              .addTextNode(cifNumber);

        return doc.toXmlString();
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

        // APPLICATIONS
        result.Applications = new List<ApplicationInfo>();
        Dom.XmlNode appsNode =
            responseNode.getChildElement('Applications', null);

        if (appsNode != null) {
            for (Dom.XmlNode a : appsNode.getChildElements()) {
                ApplicationInfo app = new ApplicationInfo();
                app.ApplicationID = FEC_CommonUltils.getXmlValue(a, 'ApplicationID');
                app.ProductGroup = FEC_CommonUltils.getXmlValue(a, 'ProductGroup');
                app.DateStatus = FEC_CommonUltils.getXmlValue(a, 'DateStatus');
                app.LastStatus = FEC_CommonUltils.getXmlValue(a, 'LastStatus');
                app.SaleName = FEC_CommonUltils.getXmlValue(a, 'SaleName');
                app.SaleUnitCode = FEC_CommonUltils.getXmlValue(a, 'SaleUnitCode');
                app.SalePhoneNumber = FEC_CommonUltils.getXmlValue(a, 'SalePhoneNumber');
                app.PersonId = FEC_CommonUltils.getXmlValue(a, 'PersonId');
                app.SystemId = FEC_CommonUltils.getXmlValue(a, 'SystemId');
                result.Applications.add(app);
            }
        }

        return result;
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
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
    }
}
