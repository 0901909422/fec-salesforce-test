/****************************************************************************************
 * File Name    : FEC_VMXAUTHDETAILINQ
 * Author       : DungLT56
 * Date         : 2026-05-21
 * Description  : Get data for API service VMX_AUTH_DETAIL_INQ (Pending authorization detail)
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-05-21     Agent                Create — MODULE007 / AUTH_GRP
   1.1      2026-05-21     Agent                Request: VMX_AUTH_DETAIL_INQ / NAME / ACCT_NBR / CONT_DATA / E8V6
****************************************************************************************/

public with sharing class FEC_VMXAUTHDETAILINQ {
    
    private static final String NS_VMX = 'http://fecredit.com.vn/cms/ws/v2';
    private static final String SERVICE_VMX_AUTH_DETAIL_INQ = 'VMX_AUTH_DETAIL_INQ';
    private static final String API_CONFIG = 'FEC_VMX_AUTH_DETAIL_INQ';
    private static final String VMX_VERSION_DEFAULT = 'E8V6';
    private static final String VMX_MSGIN_NAME_DEFAULT = 'FECVMX';

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
        public String CURRENCY_CODE;
        public Integer CURRENCY_NOD;
        public String OTB;
        public Integer NBR_AUTHS;
        /** VMX_MSGOUT.AUTH_CD (message level; Pending approval). */
        public String AUTH_CD;
        public List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> Auths;
    }

    public class RCData {
        public String RETURN_CODE;
        public String RETURN_DESC;
    }

    /* =====================================================
       PUBLIC METHOD — Pending: VMX_AUTH_DETAIL_INQ
       ===================================================== */
    public static List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow> callServiceAsAuthRows(
        String transID,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String name,
        String acctNbr,
        String contData
    ) {
        ResponseWrapper res = callService(
            transID,
            requestorId,
            dateTimeStr,
            vmxVersion,
            context,
            name,
            acctNbr,
            contData
        );
        if (res != null
            && res.VMXMsgOut != null
            && res.VMXMsgOut.Auths != null) {
            return res.VMXMsgOut.Auths;
        }
        return new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();
    }

    public static ResponseWrapper callService(
        String transID,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String name,
        String acctNbr,
        String contData
    ) {
        return callServiceInternal(
            transID,
            requestorId,
            dateTimeStr,
            vmxVersion,
            context,
            name,
            acctNbr,
            contData
        );
    }

    private static ResponseWrapper callServiceInternal(
        String transID,
        String requestorId,
        String dateTimeStr,
        String vmxVersion,
        String context,
        String name,
        String acctNbr,
        String contData
    ) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig =
            FEC_API_Config__mdt.getInstance(API_CONFIG);

        String acctForCall = resolveAccountForCall(acctNbr, apiSetting, apiConfig);

        String ctx = String.isNotBlank(context)
            ? context.trim()
            : FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        String msgName = String.isNotBlank(name)
            ? name.trim()
            : VMX_MSGIN_NAME_DEFAULT;
        String ver = String.isNotBlank(vmxVersion)
            ? vmxVersion.trim()
            : VMX_VERSION_DEFAULT;
        String cont = contData != null ? contData : '';

        validateRequest(
            transID,
            requestorId,
            dateTimeStr,
            ctx,
            msgName,
            acctForCall
        );

        String soapBody = buildSoapRequest(
            transID,
            requestorId,
            dateTimeStr,
            ver,
            ctx,
            msgName,
            acctForCall,
            cont
        );

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_UNBILLED_TRANSACTION_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

        // Same as FEC_MFASOUTSTANDINGAUTHINQ: no SOAPAction header when metadata is null.
        String soapAction = apiConfig?.FEC_SOAP_Action__c;

        HttpResponse res = FEC_CommonUltils.calloutApi(
            endpoint,
            'POST',
            FEC_ConstantCommon.API_CONTENT_TYPE,
            soapAction,
            null,
            soapBody
        );

        // FEC_CommonUltils.logApi(
        //         'FEC_VMXAUTHDETAILINQ',
        //         endpoint,
        //         'POST',
        //         soapBody,
        //         res,
        //         null
        //     );

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_HTTP_Error,
                    new List<String>{ res.getStatusCode().toString() }
                )
            );
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys == null || response.Sys.Code != 1) {
            String sysDesc = response.Sys != null
                ? response.Sys.Description
                : '';
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_API_Error,
                    new List<String>{ sysDesc }
                )
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

    /**
     * Non-Production: ACCT_NBR from FEC_API_Config.FEC_VMX_AUTH_DETAIL_INQ.
     * Production: caller account.
     */
    private static String resolveAccountForCall(
        String acctNbr,
        FEC_API_Setting__c apiSetting,
        FEC_API_Config__mdt apiConfig
    ) {
        if (apiSetting?.FEC_Enviroment__c
                == FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION
            && String.isNotBlank(apiConfig?.FEC_Account_Number_Hard_Code__c)) {
            return apiConfig.FEC_Account_Number_Hard_Code__c.trim();
        }
        return String.isNotBlank(acctNbr) ? acctNbr.trim() : acctNbr;
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
        String name,
        String acctNbr,
        String contData
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode wsRequest =
            body.addChildElement('ns1:WSRequest', null, null);
        wsRequest.setAttribute('xmlns:ns1', NS_VMX);

        Dom.XmlNode sys = wsRequest.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);
        sys.addChildElement('VMXVersion', null, null).addTextNode(vmxVersion);

        Dom.XmlNode serviceNode =
            wsRequest.addChildElement(SERVICE_VMX_AUTH_DETAIL_INQ, null, null);
        Dom.XmlNode vmxRoot =
            serviceNode.addChildElement('VMX_ROOT', null, null);
        Dom.XmlNode msgIn =
            vmxRoot.addChildElement('VMX_MSGIN', null, null);

        msgIn.addChildElement('CONTEXT', null, null).addTextNode(context);
        msgIn.addChildElement('NAME', null, null).addTextNode(name);
        msgIn.addChildElement('ACCT_NBR', null, null).addTextNode(acctNbr);
        msgIn.addChildElement('CONT_DATA', null, null).addTextNode(contData);

        return doc.toXmlString();
    }

    /* =====================================================
       RESPONSE PARSER
       ===================================================== */
    private static ResponseWrapper parseResponse(String xml) {

        ResponseWrapper result = new ResponseWrapper();
        result.VMXMsgOut = new VMXMsgOut();
        result.VMXMsgOut.RC_DATA = new List<RCData>();
        result.VMXMsgOut.Auths =
            new List<FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow>();

        String xmlBody = prepareResponseXml(xml);
        if (String.isBlank(xmlBody)) {
            return result;
        }

        Dom.Document doc = new Dom.Document();
        doc.load(xmlBody);

        Dom.XmlNode envelope = doc.getRootElement();
        if (envelope == null) {
            return result;
        }

        // ===== BODY =====
        Dom.XmlNode bodyNode = FEC_CommonUltils.findChildByName(envelope, 'Body');
        if (bodyNode == null) {
            return result;
        }

        // ===== RESPONSE NODE =====
        Dom.XmlNode responseNode = null;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }
        if (responseNode == null) {
            return result;
        }

        /* ================= SYS ================= */
        Dom.XmlNode sysNode =
            FEC_CommonUltils.findChildByName(responseNode, 'Sys');

        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID =
                FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
            result.Sys.DateTimeStr =
                FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(
                FEC_CommonUltils.getValueSafe(sysNode, 'Code')
            );
            result.Sys.Description =
                FEC_CommonUltils.getValueSafe(sysNode, 'Description');
        }

        /* ================= VMX_MSGOUT ================= */
        Dom.XmlNode serviceNode = FEC_CommonUltils.findChildByName(
            responseNode,
            SERVICE_VMX_AUTH_DETAIL_INQ
        );
        if (serviceNode == null) {
            serviceNode = findChildByLocalName(
                responseNode,
                SERVICE_VMX_AUTH_DETAIL_INQ
            );
        }
        if (serviceNode == null) {
            return result;
        }

        Dom.XmlNode rootNode =
            FEC_CommonUltils.findChildByName(serviceNode, 'VMX_ROOT');
        if (rootNode == null) {
            return result;
        }

        Dom.XmlNode msgOutNode =
            FEC_CommonUltils.findChildByName(rootNode, 'VMX_MSGOUT');
        if (msgOutNode == null) {
            return result;
        }

        VMXMsgOut out = result.VMXMsgOut;
        out.SVC_RETURN =
            FEC_CommonUltils.getValueSafe(msgOutNode, 'SVC_RETURN');
        out.RC_NBR_OCCUR = FEC_CommonUltils.toInt(
            FEC_CommonUltils.getValueSafe(msgOutNode, 'RC_NBR_OCCUR')
        );
        out.CURRENCY_CODE =
            FEC_CommonUltils.getValueSafe(msgOutNode, 'CURRENCY_CODE');
        out.CURRENCY_NOD = FEC_CommonUltils.toInt(
            FEC_CommonUltils.getValueSafe(msgOutNode, 'CURRENCY_NOD')
        );
        out.AUTH_CD = FEC_CommonUltils.getValueSafe(msgOutNode, 'AUTH_CD');

        Dom.XmlNode module007 = findChildByLocalNameContains(
            msgOutNode,
            'module007'
        );
        if (module007 != null) {
            out.OTB = FEC_CommonUltils.getValueSafe(module007, 'OTB');
            Dom.XmlNode retrvOut = findChildByLocalNameContains(
                module007,
                'retrv_auth_dtl'
            );
            if (retrvOut != null) {
                out.NBR_AUTHS = FEC_CommonUltils.toInt(
                    FEC_CommonUltils.getValueSafe(retrvOut, 'NBR_AUTHS')
                );
            }
        }

        /* ================= RC_DATA ================= */
        for (Dom.XmlNode node : msgOutNode.getChildElements()) {
            String nodeName = node.getName();
            if (nodeName != null && nodeName.contains('RC_DATA')) {
                RCData d = new RCData();
                d.RETURN_CODE =
                    FEC_CommonUltils.getValueSafe(node, 'RETURN_CODE');
                d.RETURN_DESC =
                    FEC_CommonUltils.getValueSafe(node, 'RETURN_DESC');
                out.RC_DATA.add(d);
            }
        }

        /* ================= AUTH_GRP (MODULE007 / RETRV_AUTH_DTL_OUT) ================= */
        List<Dom.XmlNode> authGrps = collectAuthGrpNodes(msgOutNode);
        for (Dom.XmlNode grp : authGrps) {
            FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar =
                authRowFromAuthGrp(grp, out.AUTH_CD);
            if (ar != null) {
                out.Auths.add(ar);
            }
        }

        return result;
    }

    /**
     * Maps VMX_AUTH_DETAIL…MODULE007…RETRV_AUTH_DTL_OUT.AUTH_GRP fields (sheet spec).
     */
    private static FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow authRowFromAuthGrp(
        Dom.XmlNode n,
        String msgAuthCd
    ) {
        if (n == null) {
            return null;
        }

        String effRaw = firstNonBlankAuth(
            pickXmlField(n, 'EFF_DATE'),
            pickXmlField(n, 'EffDate')
        );
        if (String.isBlank(effRaw)) {
            effRaw = pickXmlField(n, 'POSTING_DATE');
        }
        String amtRaw = firstNonBlankAuth(
            pickXmlField(n, 'AUTH_AMT'),
            pickXmlField(n, 'AUTH_AMOUNT')
        );
        String merchDesc = firstNonBlankAuth(
            pickXmlField(n, 'MERC_NAME_LOC'),
            firstNonBlankAuth(
                pickXmlField(n, 'Description'),
                pickXmlField(n, 'MERCHANT_NAME')
            )
        );
        String plan = firstNonBlankAuth(
            pickXmlField(n, 'CR_PLAN'),
            pickXmlField(n, 'CREDIT_PLAN')
        );

        if (String.isBlank(effRaw)
            && String.isBlank(amtRaw)
            && String.isBlank(merchDesc)
            && String.isBlank(plan)) {
            return null;
        }
        if (String.isBlank(effRaw)) {
            return null;
        }

        FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow ar =
            new FEC_MFASOUTSTANDINGAUTHINQ.AuthTableRow();
        ar.EFF_DATE = effRaw.trim();
        ar.EFF_DATE_AUTH_DETAIL = firstNonBlankAuth(
            pickXmlField(n, 'EFF_DATE'),
            pickXmlField(n, 'EffDate')
        );
        ar.POSTING_DATE = pickXmlField(n, 'POSTING_DATE');
        ar.AUTH_AMOUNT = amtRaw;
        ar.Description = merchDesc;
        ar.CREDIT_PLAN = plan;
        ar.AUTHORIZATION_CODE = firstNonBlankAuth(
            pickXmlField(n, 'AUTHORIZATION_CODE'),
            pickXmlField(n, 'AuthCode')
        );
        ar.AUTH_CD = pickXmlField(n, 'AUTH_CD');
        ar.MERCH_CAT = pickXmlField(n, 'MERCH_CAT');
        ar.TXN_CURR_CODE = pickXmlField(n, 'TXN_CURR_CODE');
        ar.FINAL_ACTN = pickXmlField(n, 'FINAL_ACTN');
        ar.ACTN_RSN_DESC = firstNonBlankAuth(
            pickXmlField(n, 'ACTN_RSN_DESC'),
            pickXmlField(n, 'ACTN_RSN')
        );

        ar.DTL_AUTH_AMT = pickXmlField(n, 'AUTH_AMT');
        ar.DTL_MERC_NAME_LOC = pickXmlField(n, 'MERC_NAME_LOC');
        ar.DTL_CR_PLAN = pickXmlField(n, 'CR_PLAN');
        ar.DTL_MERCH_CAT = pickXmlField(n, 'MERCH_CAT');
        ar.DTL_TXN_CURR_CODE = pickXmlField(n, 'TXN_CURR_CODE');
        ar.DTL_FINAL_ACTN = pickXmlField(n, 'FINAL_ACTN');
        ar.DTL_ACTN_RSN_DESC = pickXmlField(n, 'ACTN_RSN_DESC');
        ar.MSGOUT_AUTH_CD = msgAuthCd;

        return ar;
    }

    /**
     * AUTH_GRP nodes under RETRV_AUTH_DTL_OUT; else BFS fallback under VMX_MSGOUT.
     */
    private static List<Dom.XmlNode> collectAuthGrpNodes(Dom.XmlNode msgOut) {
        List<Dom.XmlNode> groups = new List<Dom.XmlNode>();
        if (msgOut == null) {
            return groups;
        }

        Dom.XmlNode retrvOut = findChildByLocalNameContains(
            msgOut,
            'retrv_auth_dtl'
        );
        if (retrvOut != null) {
            for (Dom.XmlNode child : retrvOut.getChildElements()) {
                if (child != null && isAuthGrpNode(child)) {
                    groups.add(child);
                }
            }
        }

        if (groups.isEmpty()) {
            collectAuthGrpNodesBfs(msgOut, groups);
        }
        return groups;
    }

    private static void collectAuthGrpNodesBfs(
        Dom.XmlNode root,
        List<Dom.XmlNode> groups
    ) {
        List<Dom.XmlNode> queue = new List<Dom.XmlNode>{ root };
        Integer hops = 0;
        while (!queue.isEmpty() && hops < 500) {
            hops++;
            Dom.XmlNode node = queue.remove(0);
            if (node == null) {
                continue;
            }
            if (isAuthGrpNode(node)) {
                groups.add(node);
                continue;
            }
            for (Dom.XmlNode c : node.getChildElements()) {
                queue.add(c);
            }
        }
    }

    private static Boolean isAuthGrpNode(Dom.XmlNode n) {
        if (n == null || n.getName() == null) {
            return false;
        }
        String nm = n.getName();
        Integer colon = nm.indexOf(':');
        String local = colon >= 0 ? nm.substring(colon + 1) : nm;
        return local.equalsIgnoreCase('AUTH_GRP');
    }

    private static Dom.XmlNode findChildByLocalName(
        Dom.XmlNode root,
        String localName
    ) {
        if (root == null || String.isBlank(localName)) {
            return null;
        }
        List<Dom.XmlNode> queue = new List<Dom.XmlNode>{ root };
        Integer hops = 0;
        while (!queue.isEmpty() && hops < 500) {
            hops++;
            Dom.XmlNode n = queue.remove(0);
            if (n == null) {
                continue;
            }
            String nm = n.getName();
            if (nm != null) {
                Integer colon = nm.indexOf(':');
                String local = colon >= 0 ? nm.substring(colon + 1) : nm;
                if (local.equalsIgnoreCase(localName)) {
                    return n;
                }
            }
            for (Dom.XmlNode c : n.getChildElements()) {
                queue.add(c);
            }
        }
        return null;
    }

    private static Dom.XmlNode findChildByLocalNameContains(
        Dom.XmlNode root,
        String fragment
    ) {
        if (root == null || String.isBlank(fragment)) {
            return null;
        }
        String frag = fragment.toLowerCase();
        List<Dom.XmlNode> queue = new List<Dom.XmlNode>{ root };
        Integer hops = 0;
        while (!queue.isEmpty() && hops < 500) {
            hops++;
            Dom.XmlNode n = queue.remove(0);
            if (n == null) {
                continue;
            }
            String nm = n.getName();
            if (nm != null) {
                Integer colon = nm.indexOf(':');
                String local = colon >= 0 ? nm.substring(colon + 1) : nm;
                if (local.toLowerCase().contains(frag)) {
                    return n;
                }
            }
            for (Dom.XmlNode c : n.getChildElements()) {
                queue.add(c);
            }
        }
        return null;
    }

    /** Direct child (getValueSafe) then case-insensitive child match. */
    private static String pickXmlField(Dom.XmlNode n, String tag) {
        if (n == null || String.isBlank(tag)) {
            return null;
        }
        String v = FEC_CommonUltils.getValueSafe(n, tag);
        if (!String.isBlank(v)) {
            return v.trim();
        }
        for (Dom.XmlNode childEl : n.getChildElements()) {
            if (childEl != null
                && childEl.getName() != null) {
                String nm = childEl.getName();
                Integer colon = nm.indexOf(':');
                String local = colon >= 0 ? nm.substring(colon + 1) : nm;
                if (local.equalsIgnoreCase(tag)) {
                    String t = childEl.getText();
                    return String.isBlank(t) ? null : t.trim();
                }
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

    /**
     * Strips BOM/noise before &lt; and rejects JSON (gateway errors often return application/json).
     */
    private static String prepareResponseXml(String rawBody) {
        if (String.isBlank(rawBody)) {
            return rawBody;
        }
        String trimmed = rawBody.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            String preview = trimmed.length() > 500
                ? trimmed.substring(0, 500) + '...'
                : trimmed;
            String errorHint = preview.contains('404')
                ? 'Verify FEC_Endpoint__c + FEC_API_Setting__c.FEC_Endpoint__c (e.g. .../esb/cms/CMS_VMXIntegrationWS) and leave FEC_SOAP_Action__c empty like MFAS.'
                : 'Check endpoint and request format.';
            throw new CalloutException(
                'VMX_AUTH_DETAIL_INQ: expected XML SOAP response but received JSON. ' +
                    errorHint +
                    ' Body: ' +
                    preview
            );
        }
        String cleaned = FEC_CommonUltils.cleanResponseBody(trimmed);
        if (String.isBlank(cleaned)) {
            throw new CalloutException(
                'VMX_AUTH_DETAIL_INQ: empty or non-XML response body.'
            );
        }
        if (!cleaned.startsWith('<')) {
            throw new CalloutException(
                'VMX_AUTH_DETAIL_INQ: response is not valid XML. Body starts with: ' +
                    cleaned.substring(0, Math.min(120, cleaned.length()))
            );
        }
        return cleaned;
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String context,
        String name,
        String acctNbr
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
        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {
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
                String.format(
                    System.Label.FEC_MSG_Datetime_Invalid,
                    new List<String>{ dateTimeStr }
                )
            );
        }

        // ===================== CONTEXT =====================
        if (String.isBlank(context)) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'CONTEXT' }
                )
            );
        }
        if (context.length() > 50) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Maxlength,
                    new List<String>{ 'CONTEXT', '50' }
                )
            );
        }

        // ===================== NAME =====================
        if (String.isBlank(name)) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'NAME' }
                )
            );
        }
        if (name.length() > 50) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Maxlength,
                    new List<String>{ 'NAME', '50' }
                )
            );
        }

        // ===================== ACCT_NBR =====================
        if (String.isBlank(acctNbr)) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'ACCT_NBR' }
                )
            );
        }
        if (acctNbr.length() > 30) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Param_Maxlength,
                    new List<String>{ 'ACCT_NBR', '30' }
                )
            );
        }
    }
}