/****************************************************************************************
 * File Name    : FEC_MFASOUTSTANDINGAUTHINQ
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
        public String AUTH_CD;
        public List<AuthTableRow> Auths;
    }

    public class AuthTableRow {
        public String EFF_DATE;
        public String EFF_DATE_AUTH_DETAIL;
        public String POSTING_DATE;
        public String AUTH_AMOUNT;
        public String Description;
        public String CreditDebitFlag;
        public String CREDIT_PLAN;
        public String AUTHORIZATION_CODE;
        public String AUTH_CD;
        public String MERCH_CAT;
        public String TXN_CURR_CODE;
        public String FINAL_ACTN;
        public String ACTN_RSN_DESC;
        public String DTL_AUTH_AMT;
        public String DTL_MERC_NAME_LOC;
        public String DTL_CR_PLAN;
        public String DTL_MERCH_CAT;
        public String DTL_TXN_CURR_CODE;
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
            
        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException( String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys == null || response.Sys.Code != 1) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
            );
        }
        if (response.VMXMsgOut != null && response.VMXMsgOut.SVC_RETURN == 'F'){
            String errorMsg = System.Label.FEC_MSG_API_Error;
            if (response.VMXMsgOut.RC_DATA != null 
                && !response.VMXMsgOut.RC_DATA.isEmpty()) {
        
                errorMsg = response.VMXMsgOut.RC_DATA[0].RETURN_DESC;
            }
        
            throw new CalloutException(errorMsg);
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
    
        Dom.XmlNode envelope = doc.createRootElement( 'soapenv:Envelope',null,null);
        
        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );
        envelope.setAttribute(
            'xmlns:v2',
            'http://fecredit.com.vn/cms/ws/v2'
        );

        // ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);

        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        // ===== v2:WSRequest =====
        Dom.XmlNode action =
            body.addChildElement('v2:WSRequest', null, null);

        // ================= SYS =================
        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null)
            .addTextNode(transID);

        sys.addChildElement('RequestorID', null, null)
            .addTextNode(requestorId);

        sys.addChildElement('DateTime', null, null)
            .addTextNode(dateTimeStr);

        if (!String.isBlank(vmxVersion)) {
            sys.addChildElement('VMXVersion', null, null)
                .addTextNode(vmxVersion);
        }

        // ================= BUSINESS NODE =================
        Dom.XmlNode fasNode =
            action.addChildElement('M_FAS_OUTSTANDING_AUTH_INQ', null, null);

        Dom.XmlNode vmxRoot =
            fasNode.addChildElement('VMX_ROOT', null, null);

        Dom.XmlNode msgIn =
            vmxRoot.addChildElement('VMX_MSGIN', null, null);

        msgIn.addChildElement('CONTEXT', null, null)
            .addTextNode(context);

        msgIn.addChildElement('SIGNON_NAME', null, null)
            .addTextNode(signOnName);

        msgIn.addChildElement('ORG', null, null)
            .addTextNode(org);

        msgIn.addChildElement('ACCT', null, null)
            .addTextNode(acct);

        return doc.toXmlString();
    }

    /* =====================================================
       RESPONSE PARSER
       ===================================================== */
    private static ResponseWrapper parseResponse(String xml) {

    ResponseWrapper result = new ResponseWrapper();
    result.VMXMsgOut = new VMXMsgOut();
    result.VMXMsgOut.RC_DATA = new List<RCData>();
    result.VMXMsgOut.Auths = new List<AuthTableRow>();

    if (String.isBlank(xml)) {
        return result;
    }

    Dom.Document doc = new Dom.Document();
    doc.load(xml);

    Dom.XmlNode envelope = doc.getRootElement();
    if (envelope == null) return result;

    // ===== BODY =====
    Dom.XmlNode bodyNode = FEC_CommonUltils.findChildByName(envelope, 'Body');
    if (bodyNode == null) return result;

    // ===== RESPONSE NODE =====
    Dom.XmlNode responseNode = null;
    for (Dom.XmlNode n : bodyNode.getChildElements()) {
        responseNode = n;
        break;
    }
    if (responseNode == null) return result;

    /* ================= SYS ================= */
    Dom.XmlNode sysNode =
        FEC_CommonUltils.findChildByName(responseNode, 'Sys');

    if (sysNode != null) {
        result.Sys = new SysResponse();
        result.Sys.TransID = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
    }

    /* ================= VMX_MSGOUT ================= */

    Dom.XmlNode fasNode = FEC_CommonUltils.findChildByName(responseNode, 'M_FAS_OUTSTANDING_AUTH_INQ');
    if (fasNode == null) return result;
    Dom.XmlNode rootNode = FEC_CommonUltils.findChildByName(fasNode, 'VMX_ROOT');
    if (rootNode == null) return result;
    Dom.XmlNode msgOutNode = FEC_CommonUltils.findChildByName(rootNode, 'VMX_MSGOUT');
    if (msgOutNode == null) return result;
    VMXMsgOut out = result.VMXMsgOut;
    out.SVC_RETURN = FEC_CommonUltils.getValueSafe(msgOutNode, 'SVC_RETURN');
    out.RC_NBR_OCCUR = FEC_CommonUltils.toInt( FEC_CommonUltils.getValueSafe(msgOutNode, 'RC_NBR_OCCUR'));
    out.O_CURR_NOD = FEC_CommonUltils.toInt( FEC_CommonUltils.getValueSafe(msgOutNode, 'O_CURR_NOD') );
    out.O_CURR_NBR = FEC_CommonUltils.toInt( FEC_CommonUltils.getValueSafe(msgOutNode, 'O_CURR_NBR'));
    out.FOREIGN_USE = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(msgOutNode, 'FOREIGN_USE'));
    out.ORG = FEC_CommonUltils.getValueSafe(msgOutNode, 'ORG');
    out.ACCT = FEC_CommonUltils.getValueSafe(msgOutNode, 'ACCT');
    out.REQ_TYPE = FEC_CommonUltils.getValueSafe(msgOutNode, 'REQ_TYPE');
    out.AUTH_CD = FEC_CommonUltils.getValueSafe(msgOutNode, 'AUTH_CD');
    out.MORE_DATA_FLAG = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(msgOutNode, 'MORE_DATA_FLAG') );
    out.NBR_RETURNED_ITEMS = FEC_CommonUltils.toInt( FEC_CommonUltils.getValueSafe(msgOutNode, 'NBR_RETURNED_ITEMS'));

    /* ================= RC_DATA ================= */
    for (Dom.XmlNode node : msgOutNode.getChildElements()) {
        String nodeName = node.getName();
        if (nodeName != null && nodeName.contains('RC_DATA')) {
            RCData d = new RCData();
            d.RETURN_CODE = FEC_CommonUltils.getValueSafe(node, 'RETURN_CODE');
            d.RETURN_DESC = FEC_CommonUltils.getValueSafe(node, 'RETURN_DESC');
            out.RC_DATA.add(d);
        }
    }

    /* ================= NEXT_TOKEN ================= */
    Dom.XmlNode nextNode = FEC_CommonUltils.findChildByName(msgOutNode, 'NEXT_TOKEN');
    if (nextNode != null) {
        out.NEXT_TOKEN = new Token();
        out.NEXT_TOKEN.EFF_DATE = FEC_CommonUltils.getValueSafe(nextNode, 'EFF_DATE_NEXT');
        out.NEXT_TOKEN.TIME_X = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(nextNode, 'TIME_NEXT'));
    }

    /* ================= PREV_TOKEN ================= */
    Dom.XmlNode prevNode = FEC_CommonUltils.findChildByName(msgOutNode, 'PREV_TOKEN');
    if (prevNode != null) {
        out.PREV_TOKEN = new Token();
        out.PREV_TOKEN.EFF_DATE = FEC_CommonUltils.getValueSafe(prevNode, 'EFF_DATE_PREV');
        out.PREV_TOKEN.TIME_X = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(prevNode, 'TIME_PREV'));
    }

    Dom.XmlNode authTableNode = FEC_CommonUltils.findChildByName(msgOutNode, 'AUTHS_TABLE');
    if (authTableNode != null) {
        for (Dom.XmlNode rowNode : authTableNode.getChildElements()) {
            if (rowNode == null) {
                continue;
            }
            String effRaw = readAuthTableCell(rowNode, 'EFF_DATE');
            if (String.isBlank(effRaw)) {
                effRaw = readAuthTableCell(rowNode, 'POSTING_DATE');
            }
            String amtRaw = firstNonBlankAuth(
                readAuthTableCell(rowNode, 'AUTH_AMOUNT'),
                readAuthTableCell(rowNode, 'AUTH_AMT')
            );
            if (String.isBlank(effRaw) && String.isBlank(amtRaw)) {
                continue;
            }
            if (String.isBlank(effRaw)) {
                effRaw = readAuthTableCell(rowNode, 'POSTING_DATE');
            }
            if (String.isBlank(effRaw)) {
                continue;
            }

            AuthTableRow ar = new AuthTableRow();
            ar.EFF_DATE = effRaw.trim();
            ar.POSTING_DATE = readAuthTableCell(rowNode, 'POSTING_DATE');
            ar.AUTH_AMOUNT = amtRaw;
            ar.Description = readAuthTableCell(rowNode, 'Description');
            if (String.isBlank(ar.Description)) {
                ar.Description = readAuthTableCell(rowNode, 'MERCHANT_NAME');
            }
            if (String.isBlank(ar.Description)) {
                ar.Description = readAuthTableCell(rowNode, 'MERC_NAME_LOC');
            }
            ar.CreditDebitFlag = readAuthTableCell(rowNode, 'CreditDebitFlag');
            if (String.isBlank(ar.CreditDebitFlag)) {
                ar.CreditDebitFlag = readAuthTableCell(rowNode, 'DEBIT_CREDIT_FLAG');
            }
            ar.CREDIT_PLAN = firstNonBlankAuth(
                readAuthTableCell(rowNode, 'CREDIT_PLAN'),
                readAuthTableCell(rowNode, 'CR_PLAN')
            );
            ar.AUTHORIZATION_CODE = firstNonBlankAuth(
                readAuthTableCell(rowNode, 'AUTHORIZATION_CODE'),
                readAuthTableCell(rowNode, 'AuthCode')
            );
            ar.AUTH_CD = firstNonBlankAuth(
                readAuthTableCell(rowNode, 'AUTH_CD'),
                out.AUTH_CD
            );
            ar.MERCH_CAT = readAuthTableCell(rowNode, 'MERCH_CAT');
            ar.TXN_CURR_CODE = readAuthTableCell(rowNode, 'TXN_CURR_CODE');
            ar.FINAL_ACTN = readAuthTableCell(rowNode, 'FINAL_ACTN');
            ar.ACTN_RSN_DESC = readAuthTableCell(rowNode, 'ACTN_RSN_DESC');
            out.Auths.add(ar);
        }
    }

    return result;
}

    private static String readAuthTableCell(Dom.XmlNode rowNode, String tagName) {
        if (rowNode == null || String.isBlank(tagName)) {
            return null;
        }
        String v = FEC_CommonUltils.getXmlValue(rowNode, tagName);
        if (!String.isBlank(v)) {
            return v.trim();
        }
        for (Dom.XmlNode childEl : rowNode.getChildElements()) {
            if (childEl != null
                && childEl.getName() != null
                && childEl.getName().equalsIgnoreCase(tagName)) {
                String t = childEl.getText();
                return String.isBlank(t) ? null : t.trim();
            }
        }
        return null;
    }

    private static String firstNonBlankAuth(String a, String b) {
        if (!String.isBlank(a)) {
            return a.trim();
        }
        if (!String.isBlank(b)) {
            return b.trim();
        }
        return null;
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
        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP,FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN};
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
