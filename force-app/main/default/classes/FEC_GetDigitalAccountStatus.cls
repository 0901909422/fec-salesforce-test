/****************************************************************************************
* File Name    : FEC_GetDigitalAccountStatus
* Author       : Quangdv7
* Date         : 2026-01-17
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-01-17    Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetDigitalAccountStatus {
 
    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public List<DigitalAccountInfo> DigitalAccounts;
    }
 
    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }
 
    public class DigitalAccountInfo {
        public String Type;
        public String Status;
    }
 
    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetDigitalAccountStatus(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phone,
        String cifNumber
    ) {
 
        try {
 
            validateRequest(
                transId,
                requestorId,
                dateTimeStr,
                phone,
                cifNumber
            );
 
           String soapBody = buildSoapRequest(
                transId,
                requestorId,
                dateTimeStr,
                phone,
                cifNumber
            );

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Digital_Account_Status');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_DIGITAL_ACCOUNT_STATUS_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
 
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
 
        } catch (Exception ex) {
            System.debug(
                '### GET DIGITAL ACCOUNT STATUS ERROR: ' + ex.getMessage()
            );
            throw ex;
        }
    }

    // =========================================================================
    // BUILD SOAP REQUEST
    // =========================================================================
    private static String buildSoapRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phone,
        String cifNumber
    ) {

        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            'soapenv'
        );

        envelope.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/DigitalChannelWS'
        );

        // Header
        envelope.addChildElement(
            'Header',
            FEC_ConstantCommon.SOAP_ENV,
            'soapenv'
        );

        // Body
        Dom.XmlNode body = envelope.addChildElement(
            'Body',
            FEC_ConstantCommon.SOAP_ENV,
            'soapenv'
        );

        // Action
        Dom.XmlNode action = body.addChildElement(
            'GetDigitalAccountStatus',
            'http://fecredit.com.vn/DigitalChannelWS',
            'ns1'
        );

        action.setAttribute(
            'xmlns:xsi',
            'http://www.w3.org/2001/XMLSchema-instance'
        );

        Dom.XmlNode sys = action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('Phone', null, null).addTextNode(phone);
        action.addChildElement('CIFNumber', null, null).addTextNode(cifNumber);

        return doc.toXmlString();
    }
 
    // =========================================================================
    // REQUEST VALIDATION (GIỮ ĐÚNG STYLE CLASS MẪU)
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phone,
        String cifNumber
    ) {
 
        // ===================== TRANSID =====================
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
 
        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds =
            new Set<String>{ FEC_ConstantCommon.REQUESTOR_APS, FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL, FEC_ConstantCommon.REQUESTOR_PEGA };
 
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
 
        // ===================== PHONE =====================
        if (String.isBlank(phone)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'PhoneNumber'}));
        }
        if (String.isNotBlank(phone) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, phone)) {
 
            throw new CalloutException(
                System.Label.FEC_MSG_Phone_Number_Invalid
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
 
        // ================= DIGITAL ACCOUNTS =================
        result.DigitalAccounts = new List<DigitalAccountInfo>();
 
        Dom.XmlNode accountStatusNode =
            responseNode.getChildElement('AccountStatus', null);
 
        if (accountStatusNode != null) {
            for (Dom.XmlNode dNode : accountStatusNode.getChildElements()) {
                if (dNode.getName() == 'DigitalAccount') {
                    DigitalAccountInfo d = new DigitalAccountInfo();
                    d.Type = FEC_CommonUltils.getXmlValue(dNode, 'Type');
                    d.Status = FEC_CommonUltils.getXmlValue(dNode, 'Status');
                    result.DigitalAccounts.add(d);
                }
            }
        }
 
        return result;
    }
 
 
}