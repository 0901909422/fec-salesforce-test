/****************************************************************************************
 * File Name    : FEC_GetCustomerInfoBasic
 * Author       : Quangdv7
 * Date         : 2026-01-29
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-29     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_MFASOUTSTANDINGAUTHINQ {

    private static final String NS_VMX  = 'http://fecredit.com.vn/cms/ws/v2';

    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public VMXMsgOut VMXMsgOut;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class VMXMsgOut {
        public String SVC_RETURN;
        public Integer RC_NBR_OCCUR;
        public List<RCData> RC_DATA;
        public Integer O_CURR_NOD;
        public Integer O_CURR_NBR;
        public Integer FOREIGN_USE;
        public String ORG;
        public String ACCT;
        public String REQ_TYPE;
        public Token NEXT_TOKEN;
        public Token PREV_TOKEN;
        public Integer MORE_DATA_FLAG;
        public Integer NBR_RETURNED_ITEMS;
    }

    public class RCData {
        public String RETURN_CODE;
        public String RETURN_DESC;
    }

    public class Token {
        public String EFF_DATE;
        public Integer TIME_X;
    }

    /* =====================================================
       PUBLIC METHOD
       ===================================================== */
    public static ResponseWrapper callService(
        String transID,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String acct
    ) {
        validateRequest(transID, requestorId, dateTimeStr, context, signOnName, org, acct);

        String soapBody = buildSoapRequest(
                transID, 
                requestorId, 
                dateTimeStr, 
                vmxVersion,
                context,
                signOnName,
                org,
                acct
                );

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_MFASOUTSTANDINGAUTHINQ');
        
        String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_UNBILLED_TRANSACTION_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            // ===== LOG REQUEST + RESPONSE =====
            FEC_CommonUltils.logApi(
                'FEC_MFASOUTSTANDINGAUTHINQ',
                endpoint,
                'POST',
                soapBody,
                res,
                null
            );

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException( String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys != null || response.Sys.Code != 1) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
            );
        }

        return response;
    }

    /* =====================================================
       SOAP REQUEST
       ===================================================== */
    private static String buildSoapRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String acct
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            'soapenv'
        );

        Dom.XmlNode body = envelope.addChildElement(
            'Body',
            FEC_ConstantCommon.SOAP_ENV,
            'soapenv'
        );

        Dom.XmlNode wsRequest = body.addChildElement(
            'WSRequest',
            NS_VMX,
            'ns'
        );

        // ================= SYS =================
        Dom.XmlNode sys = wsRequest.addChildElement('Sys', NS_VMX, 'ns');
        sys.addChildElement('TransID', NS_VMX, 'ns').addTextNode(transID);
        sys.addChildElement('RequestorID', NS_VMX, 'ns').addTextNode(requestorId);
        sys.addChildElement('DateTime', NS_VMX, 'ns').addTextNode(dateTimeStr);

        if (!String.isBlank(vmxVersion)) {
            sys.addChildElement('VMXVersion', NS_VMX, 'ns')
                .addTextNode(vmxVersion);
        }

        // ================= BUSINESS NODE =================
        Dom.XmlNode fasNode = wsRequest.addChildElement(
            'M_FAS_OUTSTANDING_AUTH_INQ',
            NS_VMX,
            'ns'
        );

        Dom.XmlNode vmxRoot =
            fasNode.addChildElement('VMX_ROOT', NS_VMX, 'ns');

        Dom.XmlNode msgIn =
            vmxRoot.addChildElement('VMX_MSGIN', NS_VMX, 'ns');

        msgIn.addChildElement('CONTEXT', NS_VMX, 'ns').addTextNode(context);
        msgIn.addChildElement('SIGNON_NAME', NS_VMX, 'ns').addTextNode(signOnName);
        msgIn.addChildElement('ORG', NS_VMX, 'ns').addTextNode(org);
        msgIn.addChildElement('ACCT', NS_VMX, 'ns').addTextNode(acct);

        return doc.toXmlString();
    }

    /* =====================================================
       RESPONSE PARSER
       ===================================================== */
    private static ResponseWrapper parseResponse(String xml) {
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode = envelope.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
        Dom.XmlNode responseNode = bodyNode.getChildElement('WSResponse', NS_VMX);

        ResponseWrapper result = new ResponseWrapper();

        // SYS
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', NS_VMX);
        result.Sys = new SysResponse();
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // VMX_MSGOUT
        Dom.XmlNode msgOutNode =
            responseNode
                .getChildElement('M_FAS_OUTSTANDING_AUTH_INQ', NS_VMX)
                .getChildElement('VMX_ROOT', NS_VMX)
                .getChildElement('VMX_MSGOUT', NS_VMX);

        VMXMsgOut out = new VMXMsgOut();
        out.SVC_RETURN = FEC_CommonUltils.getXmlValue(msgOutNode, 'SVC_RETURN');
        out.RC_NBR_OCCUR = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'RC_NBR_OCCUR'));
        out.O_CURR_NOD = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'O_CURR_NOD'));
        out.O_CURR_NBR = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'O_CURR_NBR'));
        out.FOREIGN_USE = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'FOREIGN_USE'));
        out.ORG = FEC_CommonUltils.getXmlValue(msgOutNode, 'ORG');
        out.ACCT = FEC_CommonUltils.getXmlValue(msgOutNode, 'ACCT');
        out.REQ_TYPE = FEC_CommonUltils.getXmlValue(msgOutNode, 'REQ_TYPE');
        out.MORE_DATA_FLAG = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'MORE_DATA_FLAG'));
        out.NBR_RETURNED_ITEMS = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOutNode, 'NBR_RETURNED_ITEMS'));

        // RC_DATA
        out.RC_DATA = new List<RCData>();
        for (Dom.XmlNode n : msgOutNode.getChildElements()) {
            if (n.getName() == 'RC_DATA') {
                RCData d = new RCData();
                d.RETURN_CODE = FEC_CommonUltils.getXmlValue(n, 'RETURN_CODE');
                d.RETURN_DESC = FEC_CommonUltils.getXmlValue(n, 'RETURN_DESC');
                out.RC_DATA.add(d);
            }
        }

        // NEXT_TOKEN
        Dom.XmlNode nextNode = msgOutNode.getChildElement('NEXT_TOKEN', NS_VMX);
        if (nextNode != null) {
            out.NEXT_TOKEN = new Token();
            out.NEXT_TOKEN.EFF_DATE = FEC_CommonUltils.getXmlValue(nextNode, 'EFF_DATE_NEXT');
            out.NEXT_TOKEN.TIME_X = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(nextNode, 'TIME_NEXT'));
        }

        // PREV_TOKEN
        Dom.XmlNode prevNode = msgOutNode.getChildElement('PREV_TOKEN', NS_VMX);
        if (prevNode != null) {
            out.PREV_TOKEN = new Token();
            out.PREV_TOKEN.EFF_DATE = FEC_CommonUltils.getXmlValue(prevNode, 'EFF_DATE_PREV');
            out.PREV_TOKEN.TIME_X = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(prevNode, 'TIME_PREV'));
        }

        result.VMXMsgOut = out;
        return result;
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String context,
        String signOnName,
        String org,
        String acct
    ) {

        // ===================== TRANSID =====================
        if (String.isBlank(transID) || transID.length() > 36) {
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

        // ===================== CONTEXT =====================
        if (String.isBlank(context)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CONTEXT'}));
        }
        if (context.length() > 50) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'CONTEXT', '50'}));
        }

        // ===================== SIGNON_NAME =====================
        if (String.isBlank(signOnName)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'SIGN ON NAME'}));
        }
        if (signOnName.length() > 50) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'SIGN ON NAME', '50'}));
        }

        // ===================== ORG =====================
        if (String.isBlank(org)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ORG'}));
        }
        if (org.length() > 10) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'ORG', '10'}));
        }

        // ===================== ACCT =====================
        if (String.isBlank(acct)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ACCT'}));
        }
        if (acct.length() > 30) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'ACCT', '30'}));
        }
    }
}
