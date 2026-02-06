/****************************************************************************************
 * File Name    : FEC_GetPaymentInfo
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetPaymentInfo {
   
    private static final String ENDPOINT = '/RepaymentInfo';
    private static final String MOCKUP_ENDPOINT = 'https://3a8edd17-dba1-4faa-9413-96a8c69491a6.mock.pstmn.io';


    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public List<PaymentInfo> Payments;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class PaymentInfo {
        public Decimal AmountPaid;
        public String TransactionDate;
        public String Username;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetPaymentInfo(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {

        validateRequest(transId, requestorId, dateTimeStr, contractNo);
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
        req.setMethod('POST');
        req.setTimeout(120000);

        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/RepaymentInfo#GetPaymentInfo'
        );

        req.setBody(
            buildSoapBody(transId, requestorId, dateTimeStr, contractNo)
        );

        HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
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
        String contractNo
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );

        envelope.setAttribute(
            'xmlns:cif',
            'http://fecredit.com.vn/RepaymentInfo'
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('rep:GetPaymentInfo', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('contractNo', null, null)
              .addTextNode(contractNo);

        return doc.toXmlString();
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {

        // ===================== TRANSID =====================
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP};
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr}));
        }

        // ===================== Contract NUMBER =====================
        if (String.isBlank(contractNo)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ContractNo'}));
        }
        if (contractNo.length() > 255) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'ContractNo', '255'}));
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
            envelope.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

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

        // ================= PAYMENTS =================
        result.Payments = new List<PaymentInfo>();

        for (Dom.XmlNode payNode : responseNode.getChildElements()) {
            if (payNode.getName() == 'Payment') {
                PaymentInfo p = new PaymentInfo();
                p.AmountPaid = FEC_CommonUltils.xmlValToDecimal(payNode, 'Amount_Paid');
                p.TransactionDate = FEC_CommonUltils.getXmlValue(payNode, 'Transaction_Date');
                p.Username = FEC_CommonUltils.getXmlValue(payNode, 'Username');
                result.Payments.add(p);
            }
        }

        return result;
    }

}