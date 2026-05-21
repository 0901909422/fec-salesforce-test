/****************************************************************************************
 * File Name    : FEC_VmxAcctBlkcdUpdEmeaCallout
 * Author       : Linh
 * Date         : 2026-05-22
 * Description  : Callout to VMX_ACCT_BLKCD_UPD_EMEA (VMX Integration - EMEA Account Block Code Update)
 * Design       : 91. VMX_ACCT_BLKCD_UPD_EMEA.xlsx
 * Context Path : /CMS_VMXIntegrationWS
 * SOAPAction   : http://fecredit.com.vn/cms/ws/v2/VMX_ACCT_BLKCD_UPD_EMEA
 ****************************************************************************************/

public with sharing class FEC_VmxAcctBlkcdUpdEmeaCallout {

    private static final String SERVICE_NS = 'http://fecredit.com.vn/CMS_VMXIntegrationWS';
    private static final String WS_RESPONSE_NS = 'http://fecredit.com.vn/cms/ws/v2';
    private static final String SERVICE_ROOT = 'VMX_ACCT_BLKCD_UPD_EMEA';
    private static final String API_LOG_NAME = 'FEC_Vmx_Acct_Blkcd_Upd_Emea';

    private static ResponseLog responseLog;

    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(String apiName, String endpoint, String method, String requestBody, HttpResponse response, String errorMessage) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }

    // ==========================================
    // 1. INPUT DTO
    // ==========================================
    public class BlkcdUpdInput {
        @AuraEnabled public String context { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String org { get; set; }
        @AuraEnabled public String functionCd { get; set; }
        @AuraEnabled public String blkCd { get; set; }
        @AuraEnabled public String blkCdInd { get; set; }
        @AuraEnabled public String foreignUse { get; set; }
        @AuraEnabled public String cardNbr { get; set; }
        @AuraEnabled public String vmxVersion { get; set; }
    }

    // ==========================================
    // 2. OUTPUT DTO
    // ==========================================
    public class BlkcdUpdResult {
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String responseCode { get; set; }
        @AuraEnabled public String responseDesc { get; set; }

        @AuraEnabled public String svcReturn { get; set; }
        @AuraEnabled public Integer rcNbrOccur { get; set; }
        @AuraEnabled public String org { get; set; }
        @AuraEnabled public String foreignOrg { get; set; }
        @AuraEnabled public String account { get; set; }
        @AuraEnabled public String cardNbr { get; set; }
        @AuraEnabled public String blkCdLocal1 { get; set; }
        @AuraEnabled public String blkCdLocal2 { get; set; }
        @AuraEnabled public String blkCdForeign1 { get; set; }
        @AuraEnabled public String blkCdForeign2 { get; set; }
        @AuraEnabled public String funcCd { get; set; }
        @AuraEnabled public String foreignUse { get; set; }
        @AuraEnabled public String processFlg1 { get; set; }
        @AuraEnabled public String processFlg2 { get; set; }
        @AuraEnabled public String processFlg3 { get; set; }
        @AuraEnabled public String processFlg4 { get; set; }
        @AuraEnabled public String processFlg5 { get; set; }
        @AuraEnabled public String acctRestructure { get; set; }
    }

    // ==========================================
    // 3. MAIN METHOD
    // ==========================================
    @AuraEnabled
    public static BlkcdUpdResult updateAccountBlockCode(BlkcdUpdInput input) {
        try {
            return executeUpdateAccountBlockCode(input);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        } finally {
            logApiResponse();
        }
    }

    public static BlkcdUpdResult executeUpdateAccountBlockCode(BlkcdUpdInput input) {
        applyDesignDefaults(input);
        validateInput(input);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Vmx_Acct_Blkcd_Upd_Emea');
        String cardNbrParam = resolveCardNbr(apiSetting, apiConfig, input.cardNbr);

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
        addTextNode(msgIn, 'FUNCTION_CD', input.functionCd);
        addTextNode(msgIn, 'BLK_CD', input.blkCd);
        addTextNode(msgIn, 'BLK_CD_IND', input.blkCdInd);
        addTextNode(msgIn, 'FOREIGN_USE', input.foreignUse);
        addTextNode(msgIn, 'CARD_NBR', cardNbrParam);

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
                if (String.isNotBlank(responseBody)) {
                    responseBody = FEC_CommonUltils.cleanResponseBody(responseBody);
                    Dom.Document responseDoc = new Dom.Document();
                    responseDoc.load(responseBody);
                    BlkcdUpdResult result = parseResponse(responseDoc);
                    if (result.responseCode != null && result.responseCode != '1') {
                        throw new CalloutException(
                            String.format(
                                System.Label.FEC_MSG_API_Error,
                                new List<String>{ result.responseDesc }
                            )
                        );
                    }
                    if (result.svcReturn == 'F') {
                        throw new CalloutException(System.Label.FEC_MSG_API_Error);
                    }
                    return result;
                }
                throw new CalloutException(System.Label.FEC_MSG_Response_Null);
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

    public static Boolean isBlkcdUpdSuccess(BlkcdUpdResult result) {
        return result != null
            && result.responseCode == '1'
            && result.svcReturn != 'F';
    }

    // ==========================================
    // 4. DEFAULT INPUT (design defaults)
    // ==========================================
    public static BlkcdUpdInput buildDefaultInput(String cardNbr) {
        BlkcdUpdInput input = new BlkcdUpdInput();
        input.context = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        input.name = FEC_ConstantCommon.REQUESTOR_VMX_CONTEXT;
        input.org = FEC_ConstantCommon.REQUESTOR_ORG;
        input.functionCd = 'B';
        input.blkCd = 'C';
        input.blkCdInd = '1';
        input.foreignUse = '0';
        input.cardNbr = cardNbr;
        input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA_BLKCD_UPD;
        return input;
    }

    private static void applyDesignDefaults(BlkcdUpdInput input) {
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
        if (String.isBlank(input.functionCd)) {
            input.functionCd = 'B';
        }
        if (String.isBlank(input.blkCd)) {
            input.blkCd = 'C';
        }
        if (String.isBlank(input.blkCdInd)) {
            input.blkCdInd = '1';
        }
        if (String.isBlank(input.foreignUse)) {
            input.foreignUse = '0';
        }
        if (String.isBlank(input.vmxVersion)) {
            input.vmxVersion = FEC_ConstantCommon.REQUESTOR_VMXVERSION_EMEA_BLKCD_UPD;
        }
    }

    // ==========================================
    // 5. VALIDATION
    // ==========================================
    private static void validateInput(BlkcdUpdInput input) {
        if (input == null) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Input' }));
        }
        if (String.isBlank(input.context)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'CONTEXT' }));
        }
        if (String.isBlank(input.name)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'NAME' }));
        }
        if (String.isBlank(input.org)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'ORG' }));
        }
        if (String.isBlank(input.functionCd)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'FUNCTION_CD' }));
        }
        if (String.isBlank(input.blkCd)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'BLK_CD' }));
        }
        if (String.isBlank(input.blkCdInd)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'BLK_CD_IND' }));
        }
        if (String.isBlank(input.foreignUse)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'FOREIGN_USE' }));
        }
        if (String.isBlank(input.cardNbr)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'CARD_NBR' }));
        }
        if (String.isBlank(input.vmxVersion)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'VMXVersion' }));
        }
    }

    private static String resolveCardNbr(
        FEC_API_Setting__c apiSetting,
        FEC_API_Config__mdt apiConfig,
        String cardNbr
    ) {
        if (String.isNotBlank(apiSetting?.FEC_Enviroment__c)
            && apiSetting.FEC_Enviroment__c == FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION
            && String.isNotBlank(apiConfig?.FEC_Account_Number_Hard_Code__c)) {
            return apiConfig.FEC_Account_Number_Hard_Code__c;
        }
        return cardNbr;
    }

    // ==========================================
    // 6. PARSER
    // ==========================================
    private static BlkcdUpdResult parseResponse(Dom.Document doc) {
        BlkcdUpdResult result = new BlkcdUpdResult();
        Dom.XmlNode root = doc.getRootElement();
        String rootName = root.getName();
        Dom.XmlNode wsResponse = null;

        if (rootName == 'WSResponse' || rootName.contains('WSResponse')) {
            wsResponse = root;
        } else if (rootName == 'Envelope') {
            Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            if (body != null) {
                wsResponse = body.getChildElement('WSResponse', WS_RESPONSE_NS);
                if (wsResponse == null) {
                    wsResponse = body.getChildElement('WSResponse', null);
                }
                if (wsResponse == null) {
                    Dom.XmlNode responseNode = body.getChildElement(SERVICE_ROOT + 'Response', SERVICE_NS);
                    if (responseNode != null) {
                        return parseLegacyResponse(responseNode);
                    }
                }
            }
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

    private static BlkcdUpdResult parseLegacyResponse(Dom.XmlNode responseNode) {
        BlkcdUpdResult result = new BlkcdUpdResult();
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        if (sysNode != null) {
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }
        parseVmxMsgOut(responseNode, result);
        return result;
    }

    private static void parseVmxMsgOut(Dom.XmlNode parent, BlkcdUpdResult result) {
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
        result.org = FEC_CommonUltils.getXmlValue(msgOut, 'ORG');
        result.foreignOrg = FEC_CommonUltils.getXmlValue(msgOut, 'FOREIGN_ORG');
        result.account = FEC_CommonUltils.getXmlValue(msgOut, 'ACCOUNT');
        result.cardNbr = FEC_CommonUltils.getXmlValue(msgOut, 'CARD_NBR');
        result.blkCdLocal1 = FEC_CommonUltils.getXmlValue(msgOut, 'BLK_CD_LOCAL_1');
        result.blkCdLocal2 = FEC_CommonUltils.getXmlValue(msgOut, 'BLK_CD_LOCAL_2');
        result.blkCdForeign1 = FEC_CommonUltils.getXmlValue(msgOut, 'BLK_CD_FOREIGN_1');
        result.blkCdForeign2 = FEC_CommonUltils.getXmlValue(msgOut, 'BLK_CD_FOREIGN_2');
        result.funcCd = FEC_CommonUltils.getXmlValue(msgOut, 'FUNC_CD');
        result.foreignUse = FEC_CommonUltils.getXmlValue(msgOut, 'FOREIGN_USE');
        result.processFlg1 = FEC_CommonUltils.getXmlValue(msgOut, 'PROCESS_FLG_1');
        result.processFlg2 = FEC_CommonUltils.getXmlValue(msgOut, 'PROCESS_FLG_2');
        result.processFlg3 = FEC_CommonUltils.getXmlValue(msgOut, 'PROCESS_FLG_3');
        result.processFlg4 = FEC_CommonUltils.getXmlValue(msgOut, 'PROCESS_FLG_4');
        result.processFlg5 = FEC_CommonUltils.getXmlValue(msgOut, 'PROCESS_FLG_5');
        result.acctRestructure = FEC_CommonUltils.getXmlValue(msgOut, 'ACCT_RESTRUCTURE');
    }

    // ==========================================
    // 7. HELPERS
    // ==========================================
    private static void addTextNode(Dom.XmlNode parent, String name, String value) {
        parent.addChildElement(name, null, null).addTextNode(value == null ? '' : value);
    }
}
