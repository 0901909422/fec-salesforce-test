/****************************************************************************************
 * File Name    : FEC_VmxNonmonUpdCallout
 * Description  : Callout to VMX_NONMON_UPD (CMS_VMXIntegrationWS — non-monetary account updates)
 * Context Path : /CMS_VMXIntegrationWS
 * SOAPAction   : VMX_NONMON_UPD
 ****************************************************************************************/

public without sharing class FEC_VmxNonmonUpdCallout {

    private static final String WS_RESPONSE_NS = 'http://fecredit.com.vn/cms/ws/v2';
    private static final String SERVICE_ROOT = 'VMX_NONMON_UPD';
    private static final String API_LOG_NAME = 'FEC_Vmx_Nonmon_Upd';
    private static final String DEFAULT_VMX_VERSION = 'E8V5';
    private static final Pattern API_DESCRIPTION_SUCCESS_PATTERN =
        Pattern.compile('(?i)(?:^|[^a-zA-Z])success(?:[^a-zA-Z]|$)');

    private static ResponseLog responseLog;

    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(
            String apiName,
            String endpoint,
            String method,
            String requestBody,
            HttpResponse response,
            String errorMessage
        ) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }

    public class NonmonUpdInput {
        public String context;
        public String name;
        public String org;
        public String account;
        public String actionCode;
        public String memo1;
        public String memo2;
        public String vmxVersion;
    }

    public class NonmonUpdResult {
        public String transId;
        public String responseCode;
        public String responseDesc;
        public String svcReturn;
        public Integer rcNbrOccur;
        public String outputOrg;
        public String errorMessage;
    }

    public static NonmonUpdInput buildDefaultInput() {
        NonmonUpdInput input = new NonmonUpdInput();
        input.context = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        input.name = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        input.org = FEC_ConstantCommon.REQUESTOR_ORG;
        input.vmxVersion = DEFAULT_VMX_VERSION;
        input.actionCode = 'PCSM';
        return input;
    }

    public static NonmonUpdResult executeNonmonUpdate(NonmonUpdInput input) {
        applyDesignDefaults(input);
        validateInput(input);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Vmx_Nonmon_Upd');

        String transId = UUID.randomUUID().toString();
        String requestorId = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        String reqTime = Datetime.now().formatGmt(FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);

        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        envelope.setNamespace('v2', WS_RESPONSE_NS);
        envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        Dom.XmlNode wsRequest = body.addChildElement('WSRequest', WS_RESPONSE_NS, 'v2');

        Dom.XmlNode sysNode = wsRequest.addChildElement('Sys', null, null);
        sysNode.addChildElement('TransID', null, null).addTextNode(transId);
        sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
        sysNode.addChildElement('VMXVersion', null, null).addTextNode(input.vmxVersion);

        Dom.XmlNode rootRequest = wsRequest.addChildElement(SERVICE_ROOT, null, null);
        Dom.XmlNode vmxRoot = rootRequest.addChildElement('VMX_ROOT', null, null);
        Dom.XmlNode msgIn = vmxRoot.addChildElement('VMX_MSGIN', null, null);

        addTextNode(msgIn, 'CONTEXT', input.context);
        addTextNode(msgIn, 'NAME', input.name);
        addTextNode(msgIn, 'ORG', input.org);
        addTextNode(msgIn, 'ACCOUNT', input.account);
        addTextNode(msgIn, 'ACTION_CODE', input.actionCode);

        Dom.XmlNode memosNode = msgIn.addChildElement('MEMOS', null, null);
        addTextNode(memosNode, 'MEMO_1', input.memo1);
        addTextNode(memosNode, 'MEMO_2', input.memo2);

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.EMEA_ACCOUNT_INQ_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        String requestBody = doc.toXmlString();

        try {
            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                apiConfig?.FEC_SOAP_Action__c,
                doc,
                ''
            );

            responseLog = new ResponseLog(
                API_LOG_NAME,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                requestBody,
                res,
                null
            );

            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                if (String.isBlank(responseBody)) {
                    throw new CalloutException(System.Label.FEC_MSG_Response_Null);
                }
                responseBody = FEC_CommonUltils.cleanResponseBody(responseBody);
                Dom.Document responseDoc = new Dom.Document();
                responseDoc.load(responseBody);
                return parseResponse(responseDoc);
            }

            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_API_Error,
                    new List<String>{ res.getStatus() + ' - ' + res.getBody() }
                )
            );
        } catch (Exception e) {
            if (responseLog == null) {
                responseLog = new ResponseLog(
                    API_LOG_NAME,
                    endpoint,
                    FEC_ConstantCommon.API_METHOD_POST,
                    requestBody,
                    null,
                    e.getMessage()
                );
            } else {
                responseLog.errorMessage = e.getMessage();
            }
            throw e;
        }
    }

    public static void logApiResponse() {
        if (responseLog != null) {
            FEC_CommonUltils.logApi(
                responseLog.apiName,
                responseLog.endpoint,
                responseLog.method,
                responseLog.requestBody,
                responseLog.response,
                responseLog.errorMessage
            );
            responseLog = null;
        }
    }

    public static Boolean isNonmonUpdSuccess(NonmonUpdResult result) {
        if (result == null || isVmxSvcReturnFailure(result)) {
            return false;
        }
        if (result.responseCode == '1') {
            return true;
        }
        return isNonmonUpdDescriptionSuccess(result.responseDesc);
    }

    public static Boolean isVmxSvcReturnFailure(NonmonUpdResult result) {
        return result != null
            && String.isNotBlank(result.svcReturn)
            && 'F'.equalsIgnoreCase(result.svcReturn.trim());
    }

    private static void applyDesignDefaults(NonmonUpdInput input) {
        if (input == null) {
            return;
        }
        if (String.isBlank(input.context)) {
            input.context = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        }
        if (String.isBlank(input.name)) {
            input.name = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        }
        if (String.isBlank(input.org)) {
            input.org = FEC_ConstantCommon.REQUESTOR_ORG;
        }
        if (String.isBlank(input.vmxVersion)) {
            input.vmxVersion = DEFAULT_VMX_VERSION;
        }
        if (String.isBlank(input.actionCode)) {
            input.actionCode = 'PCSM';
        }
    }

    private static void validateInput(NonmonUpdInput input) {
        if (input == null) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Input' }));
        }
        if (String.isBlank(input.account)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'ACCOUNT' }));
        }
        if (String.isBlank(input.memo1)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'MEMO_1' }));
        }
        if (String.isBlank(input.memo2)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'MEMO_2' }));
        }
    }

    private static NonmonUpdResult parseResponse(Dom.Document doc) {
        NonmonUpdResult result = new NonmonUpdResult();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode wsResponse = null;

        if (root.getName() == 'Envelope') {
            Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            if (body != null) {
                wsResponse = body.getChildElement('WSResponse', WS_RESPONSE_NS);
                if (wsResponse == null) {
                    wsResponse = body.getChildElement('WSResponse', null);
                }
            }
        } else if (root.getName() == 'WSResponse' || root.getName().contains('WSResponse')) {
            wsResponse = root;
        } else {
            wsResponse = root.getChildElement('WSResponse', WS_RESPONSE_NS);
            if (wsResponse == null) {
                wsResponse = root.getChildElement('WSResponse', null);
            }
        }

        if (wsResponse == null) {
            return result;
        }

        Dom.XmlNode sysNode = wsResponse.getChildElement('Sys', null);
        if (sysNode != null) {
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        Dom.XmlNode serviceNode = wsResponse.getChildElement(SERVICE_ROOT, null);
        if (serviceNode != null) {
            parseVmxMsgOut(serviceNode, result);
        }
        return result;
    }

    private static void parseVmxMsgOut(Dom.XmlNode parent, NonmonUpdResult result) {
        Dom.XmlNode vmxRoot = parent.getChildElement('VMX_ROOT', null);
        if (vmxRoot == null) {
            return;
        }
        Dom.XmlNode msgOut = vmxRoot.getChildElement('VMX_MSGOUT', null);
        if (msgOut == null) {
            return;
        }

        result.svcReturn = FEC_CommonUltils.getXmlValue(msgOut, 'SVC_RETURN');
        result.rcNbrOccur = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(msgOut, 'RC_NBR_OCCUR'));

        Dom.XmlNode outputArea = msgOut.getChildElement('OUTPUT_AREA', null);
        if (outputArea != null) {
            result.outputOrg = FEC_CommonUltils.getXmlValue(outputArea, 'ORG');
        }
    }

    private static Boolean isNonmonUpdDescriptionSuccess(String responseDesc) {
        if (String.isBlank(responseDesc)) {
            return false;
        }
        return API_DESCRIPTION_SUCCESS_PATTERN.matcher(responseDesc.trim()).find();
    }

    private static void addTextNode(Dom.XmlNode parent, String name, String value) {
        parent.addChildElement(name, null, null).addTextNode(value == null ? '' : value);
    }
}
