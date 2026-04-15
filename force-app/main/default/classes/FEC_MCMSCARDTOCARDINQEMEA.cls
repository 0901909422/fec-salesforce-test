/***************************************************************************************
 * File Name    : FEC_MCMSCARDTOCARDINQEMEA
 * Author       : Quangdv7
 * Date         : 2026-04-14
 * Description  : Get Card-to-Card inquiry data for API service M_CMS_CARD_TO_CARD_INQ_EMEA
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-04-14     Quangdv7                   Create
 
***************************************************************************************/

public with sharing class FEC_MCMSCARDTOCARDINQEMEA {

    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public VMXMsgOut   VMXMsgOut;
    }

    public class SysResponse {
        public String  TransID;
        public String  DateTimeStr;
        public Integer Code;
        public String  Description;
    }

    public class VMXMsgOut {
        public String      SVC_RETURN;
        public Integer     RC_NBR_OCCUR;
        public OutputArea  OUTPUT_AREA;
        public List<RCData> RC_DATA;
    }

    public class OutputArea {
        public String        MORE_RECS;
        public Integer       NBR_OF_OCCUR;
        public List<OutputData> OUTPUT_DATA;
    }

    public class OutputData {
        public String  SEQ;
        public String  ORG;
        public String  CARD_NBR;
        public Integer CARD_SEQ;
        public String  STAT;
        public String  BLK_CD;
        public String  DT_OPENED;
        public String  DT_EXP;
        public String  DT_BLK;
        public String  BLK_SECUR_ID;
        public String  POST_TO_ACCT;
        public String  EMBR_NAME_1;
        public String  EMBOSSED_NAME_1;
        public Integer TYPE_OF_CARD;
        public Integer CARDHOLDER_TYPE;
        public Integer GNDR_CD;
        public String  CARD_ACTIVATED_DT;
        public String  DT_STAT;
        public String  XFR_ACCT;
        public String  XFR_CARD_NBR;
        public String  NEW_CARD_NBR;
        public String  OLD_CARD_NBR;
        public Integer EMAIL_NOTIFY;
        public Integer SMS_OUTCOME;
        public Integer EMBLM_ID;
        public String  CUST_NBR;
        public Integer MS_ACCT_LOGO;
        public String  NEW_CARD_USG;
        public String  DT_LST_ADDR_CHNG;
        public String  CURR_CARD_FROM_DT;
        public Integer PIN_SUPPR;
    }

    public class RCData {
        public String RETURN_CODE;
        public String RETURN_DESC;
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
        String cardNbr,
        String name
    ) {
        validateRequest(transID, requestorId, dateTimeStr, vmxVersion, context, signOnName, org, cardNbr, name);

        String soapBody = buildSoapRequest(
            transID,
            requestorId,
            dateTimeStr,
            vmxVersion,
            context,
            signOnName,
            org,
            cardNbr,
            name
        );

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_MCMSCARDTOCARDINQEMEA');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_UNBILLED_TRANSACTION_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

        HttpResponse res = FEC_CommonUltils.calloutApi(
            endpoint, 'POST',
            FEC_ConstantCommon.API_CONTENT_TYPE,
            apiConfig?.FEC_SOAP_Action__c,
            null,
            soapBody
        );

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error,
                    new List<String>{ res.getStatusCode().toString() })
            );
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys == null || response.Sys.Code != 1) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_API_Error,
                    new List<String>{ response.Sys?.Description })
            );
        }

        if (response.VMXMsgOut != null && response.VMXMsgOut.SVC_RETURN == 'F') {
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
    String cardNbr,
    String name
) {
    Dom.Document doc = new Dom.Document();

    Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
    envelope.setAttribute('xmlns:soapenv', 'http://schemas.xmlsoap.org/soap/envelope/');
    envelope.setAttribute('xmlns:ns1', 'http://fecredit.com.vn/cms/ws/v2');

    // Header
    envelope.addChildElement('soapenv:Header', null, null);

    // Body
    Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);

    // WSRequest
    Dom.XmlNode action = body.addChildElement('ns1:WSRequest', null, null);

    // Sys
    Dom.XmlNode sys = action.addChildElement('Sys', null, null);
    sys.addChildElement('TransID', null, null).addTextNode(transID);
    sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);

    sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

    if (!String.isBlank(vmxVersion)) {
        sys.addChildElement('VMXVersion', null, null).addTextNode(vmxVersion);
    }

    // ===== BUSINESS NODE =====
    Dom.XmlNode cmsNode =
        action.addChildElement('M_FAS_OUTSTANDING_AUTH_INQ', null, null);

    Dom.XmlNode vmxRoot = cmsNode.addChildElement('VMX_ROOT', null, null);
    Dom.XmlNode msgIn   = vmxRoot.addChildElement('VMX_MSGIN', null, null);

    msgIn.addChildElement('CONTEXT', null, null).addTextNode(context);
    msgIn.addChildElement('SIGNON_NAME', null, null).addTextNode(signOnName);
    msgIn.addChildElement('ORG', null, null).addTextNode(org);
    msgIn.addChildElement('CARD_NBR', null, null).addTextNode(cardNbr);

    if (!String.isBlank(name)) {
        msgIn.addChildElement('NAME', null, null).addTextNode(name);
    }

    return doc.toXmlString();
    }

    /* =====================================================
       RESPONSE PARSER
       ===================================================== */
    private static ResponseWrapper parseResponse(String xml) {

        ResponseWrapper result  = new ResponseWrapper();
        result.VMXMsgOut        = new VMXMsgOut();
        result.VMXMsgOut.RC_DATA = new List<RCData>();
        result.VMXMsgOut.OUTPUT_AREA = new OutputArea();
        result.VMXMsgOut.OUTPUT_AREA.OUTPUT_DATA = new List<OutputData>();

        if (String.isBlank(xml)) return result;

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
        Dom.XmlNode sysNode = FEC_CommonUltils.findChildByName(responseNode, 'Sys');
        if (sysNode != null) {
            result.Sys             = new SysResponse();
            result.Sys.TransID     = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
            result.Sys.Code        = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
        }

        /* ================= VMX_MSGOUT ================= */
        Dom.XmlNode cmsNode    = FEC_CommonUltils.findChildByName(responseNode, 'M_CMS_CARD_TO_CARD_INQ_EMEA');
        if (cmsNode == null)   return result;
        Dom.XmlNode rootNode   = FEC_CommonUltils.findChildByName(cmsNode, 'VMX_ROOT');
        if (rootNode == null)  return result;
        Dom.XmlNode msgOutNode = FEC_CommonUltils.findChildByName(rootNode, 'VMX_MSGOUT');
        if (msgOutNode == null) return result;

        VMXMsgOut out   = result.VMXMsgOut;
        out.SVC_RETURN  = FEC_CommonUltils.getValueSafe(msgOutNode, 'SVC_RETURN');
        out.RC_NBR_OCCUR = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(msgOutNode, 'RC_NBR_OCCUR'));

        /* ================= RC_DATA ================= */
        for (Dom.XmlNode node : msgOutNode.getChildElements()) {
            String nodeName = node.getName();
            if (nodeName != null && nodeName.contains('RC_DATA')) {
                RCData d      = new RCData();
                d.RETURN_CODE = FEC_CommonUltils.getValueSafe(node, 'RETURN_CODE');
                d.RETURN_DESC = FEC_CommonUltils.getValueSafe(node, 'RETURN_DESC');
                out.RC_DATA.add(d);
            }
        }

        /* ================= OUTPUT_AREA ================= */
        Dom.XmlNode outputAreaNode = FEC_CommonUltils.findChildByName(msgOutNode, 'OUTPUT_AREA');
        if (outputAreaNode != null) {
            OutputArea area    = out.OUTPUT_AREA;
            area.MORE_RECS     = FEC_CommonUltils.getValueSafe(outputAreaNode, 'MORE_RECS');
            area.NBR_OF_OCCUR  = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(outputAreaNode, 'NBR_OF_OCCUR'));

            /* ---- OUTPUT_DATA[] ---- */
            for (Dom.XmlNode node : outputAreaNode.getChildElements()) {
                String nodeName = node.getName();
                if (nodeName != null && nodeName.contains('OUTPUT_DATA')) {
                    OutputData d          = new OutputData();
                    d.SEQ                 = FEC_CommonUltils.getValueSafe(node, 'SEQ');
                    d.ORG                 = FEC_CommonUltils.getValueSafe(node, 'ORG');
                    d.CARD_NBR            = FEC_CommonUltils.getValueSafe(node, 'CARD_NBR');
                    d.CARD_SEQ            = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'CARD_SEQ'));
                    d.STAT                = FEC_CommonUltils.getValueSafe(node, 'STAT');
                    d.BLK_CD              = FEC_CommonUltils.getValueSafe(node, 'BLK_CD');
                    d.DT_OPENED           = FEC_CommonUltils.getValueSafe(node, 'DT_OPENED');
                    d.DT_EXP              = FEC_CommonUltils.getValueSafe(node, 'DT_EXP');
                    d.DT_BLK              = FEC_CommonUltils.getValueSafe(node, 'DT_BLK');
                    d.BLK_SECUR_ID        = FEC_CommonUltils.getValueSafe(node, 'BLK_SECUR_ID');
                    d.POST_TO_ACCT        = FEC_CommonUltils.getValueSafe(node, 'POST_TO_ACCT');
                    d.EMBR_NAME_1         = FEC_CommonUltils.getValueSafe(node, 'EMBR_NAME_1');
                    d.EMBOSSED_NAME_1     = FEC_CommonUltils.getValueSafe(node, 'EMBOSSED_NAME_1');
                    d.TYPE_OF_CARD        = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'TYPE_OF_CARD'));
                    d.CARDHOLDER_TYPE     = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'CARDHOLDER_TYPE'));
                    d.GNDR_CD             = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'GNDR_CD'));
                    d.CARD_ACTIVATED_DT   = FEC_CommonUltils.getValueSafe(node, 'CARD_ACTIVATED_DT');
                    d.DT_STAT             = FEC_CommonUltils.getValueSafe(node, 'DT_STAT');
                    d.XFR_ACCT            = FEC_CommonUltils.getValueSafe(node, 'XFR_ACCT');
                    d.XFR_CARD_NBR        = FEC_CommonUltils.getValueSafe(node, 'XFR_CARD_NBR');
                    d.NEW_CARD_NBR        = FEC_CommonUltils.getValueSafe(node, 'NEW_CARD_NBR');
                    d.OLD_CARD_NBR        = FEC_CommonUltils.getValueSafe(node, 'OLD_CARD_NBR');
                    d.EMAIL_NOTIFY        = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'EMAIL_NOTIFY'));
                    d.SMS_OUTCOME         = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'SMS_OUTCOME'));
                    d.EMBLM_ID            = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'EMBLM_ID'));
                    d.CUST_NBR            = FEC_CommonUltils.getValueSafe(node, 'CUST_NBR');
                    d.MS_ACCT_LOGO        = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'MS_ACCT_LOGO'));
                    d.NEW_CARD_USG        = FEC_CommonUltils.getValueSafe(node, 'NEW_CARD_USG');
                    d.DT_LST_ADDR_CHNG   = FEC_CommonUltils.getValueSafe(node, 'DT_LST_ADDR_CHNG');
                    d.CURR_CARD_FROM_DT  = FEC_CommonUltils.getValueSafe(node, 'CURR_CARD_FROM_DT');
                    d.PIN_SUPPR          = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(node, 'PIN_SUPPR'));
                    area.OUTPUT_DATA.add(d);
                }
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
        String vmxVersion,
        String context,
        String signOnName,
        String org,
        String cardNbr,
        String name
    ) {
        // ===================== TRANSID =====================
        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP,
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{ dateTimeStr })
            );
        }

        // ===================== VMX VERSION =====================
       if (String.isBlank(vmxVersion)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'VMXVersion' })
            );
        }

        // ===================== CONTEXT =====================
        if (String.isBlank(context)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'CONTEXT' })
            );
        }
        if (context.length() > 50) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'CONTEXT', '50' })
            );
        }

        // ===================== SIGNON_NAME =====================
        if (String.isBlank(signOnName)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'SIGN ON NAME' })
            );
        }
        if (signOnName.length() > 50) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'SIGN ON NAME', '50' })
            );
        }

        // ===================== ORG =====================
        if (String.isBlank(org)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'ORG' })
            );
        }
        if (org.length() < 10) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'ORG', '10' })
            );
        }

        // ===================== CARD_NBR =====================
        if (String.isBlank(cardNbr)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'CARD_NBR' })
            );
        }
        if (cardNbr.length() > 19) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'CARD_NBR', '19' })
            );
        }

        // ===================== NAME =====================
        if (!String.isBlank(name) && name.length() > 50) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'NAME', '50' })
            );
        }
    }
}