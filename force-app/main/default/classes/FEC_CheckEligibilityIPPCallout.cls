/****************************************************************************************
* File Name    : FEC_CheckEligibilityIPPCallout
* Author       : Longnh76
* Date         : 2026-04-21
* Description  : Implementation of Check Eligibility SOAP API (CMS_IPP_BlockWS)
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
* 1.0      2026-04-21     Longnh76         Create
****************************************************************************************/

public with sharing class FEC_CheckEligibilityIPPCallout {
   //sử dụng API /esb/cms/CMS_IPP_BlockWS 
    public static final String API_CONFIG_NAME = 'FEC_CMS_IPP_BlockWS';
    private static final String SERVICE_NS = 'http://fecredit.com.vn/CMS_IPP_BlockWS';
    private static ResponseLog responseLog;
    
    // =========================================================================
    // RESPONSE WRAPPERS
    // =========================================================================
    public class CheckEligibilityResult {
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String dateTimeStr { get; set; }
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String accEligibility { get; set; } // "true"/"false" from Details.AccEligibility
        @AuraEnabled public String account { get; set; }
        
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public Integer httpStatus { get; set; }
    }

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

    // =========================================================================
    // MAIN CALLOUT METHOD
    // =========================================================================
    /**
     * Executes the SOAP callout to check account eligibility for IPP.
     * 
     * @param accountNumber The account number to check.
     * @return CheckEligibilityResult containing the API response.
     */
    @AuraEnabled
    public static CheckEligibilityResult checkAccountEligibility(String accountNumber) {
        CheckEligibilityResult result = new CheckEligibilityResult();
        result.success = false;
        String transId = FEC_CommonUltils.generateTransactionId();
        String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.STR_DATETIME_FORMAT_Z);
        
        try {
            // 1. Validate Input
            if (String.isBlank(accountNumber)) {
                result.success = false;
                result.errorMessage = String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'Account Number'});
                return result;
            }

            // 2. Build SOAP Request
            // Giống Reward Debit: tránh RequestorID quá dài nếu downstream map vào cột ngắn
            Dom.Document doc = buildSoapRequest(transId, FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN, timestamp, accountNumber);
            String soapRequest = doc.toXmlString();

            // 3. Resolve Endpoint & Callout
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            String endpoint = (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            String soapAction = (apiConfig != null && String.isNotBlank(apiConfig.FEC_SOAP_Action__c))
                ? apiConfig.FEC_SOAP_Action__c
                : null;

            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint, 
                FEC_ConstantCommon.API_METHOD_POST, 
                FEC_ConstantCommon.API_CONTENT_TYPE, 
                soapAction, 
                null, 
                soapRequest
            );

            // 4. Log Interaction
            responseLog = new ResponseLog(
                'FEC_CheckEligibilityIPPCallout',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapRequest,
                res,
                null
            );

            // 5. Handle Response
            if (res != null && res.getStatusCode() == 200) {
                result = parseSoapResponse(res.getBody());
                result.httpStatus = 200;
                if (!result.success && String.isBlank(result.errorMessage)) {
                    result.errorMessage = 'API Code: ' + result.code + ' | Description: ' + result.description + ' | Raw XML: ' + res.getBody();
                }
            } else {
                result.success = false;
                result.httpStatus = (res != null) ? res.getStatusCode() : 0;
                result.errorMessage = (res != null) ? res.getBody() : System.Label.FEC_MSG_No_Response;
            }

        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            if (responseLog != null) {
                responseLog.errorMessage = e.getMessage();
            }
            System.debug('### IPP CHECK ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
    }

    // /**
    //  * Persists the API log to the database.
    //  */
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
        }
    }

    // =========================================================================
    // HELPER METHODS: XML BUILDER & PARSER
    // =========================================================================
    private static Dom.Document buildSoapRequest(String transId, String requestorId, String timestamp, String accountNumber) {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:ns1', SERVICE_NS);
        
        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        
        Dom.XmlNode action = body.addChildElement('ns1:CheckEligibility', null, null);
        
        Dom.XmlNode sysRequest = action.addChildElement('Sys', null, null);
        sysRequest.addChildElement('TransID', null, null).addTextNode(transId);
        sysRequest.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysRequest.addChildElement('DateTime', null, null).addTextNode(timestamp);
        
        action.addChildElement('Account', null, null).addTextNode(accountNumber);
        
        return doc;
    }

    private static CheckEligibilityResult parseSoapResponse(String responseBody) {
        CheckEligibilityResult result = new CheckEligibilityResult();
        result.success = false;
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);
            
            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            Dom.XmlNode responseNode = (bodyNode != null) ? bodyNode.getChildElement('CheckEligibilityResponse', SERVICE_NS) : null;

            if (responseNode == null && bodyNode != null) {
                responseNode = FEC_CommonUltils.findChildByName(bodyNode, 'CheckEligibilityResponse');
            }
            if (responseNode == null) {
                responseNode = FEC_CommonUltils.findChildByName(root, 'CheckEligibilityResponse');
            }

            if (responseNode != null) {
                // Một số môi trường trả <SysResponse>, một số trả <Sys> (cùng Code / Description / TransID)
                Dom.XmlNode sysNode = responseNode.getChildElement('SysResponse', null);
                if (sysNode == null) {
                    sysNode = FEC_CommonUltils.findChildByName(responseNode, 'SysResponse');
                }
                if (sysNode == null) {
                    sysNode = responseNode.getChildElement('Sys', null);
                }
                if (sysNode == null) {
                    sysNode = FEC_CommonUltils.findChildByName(responseNode, 'Sys');
                }

                if (sysNode != null) {
                    result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
                    result.dateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
                    result.code = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
                    result.description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
                }

                // Details Mapping
                Dom.XmlNode detailsNode = responseNode.getChildElement('Details', null);
                if (detailsNode == null) {
                    detailsNode = FEC_CommonUltils.findChildByName(responseNode, 'Details');
                }

                if (detailsNode != null) {
                    result.accEligibility = FEC_CommonUltils.getXmlValue(detailsNode, 'AccEligibility');
                    result.account = FEC_CommonUltils.getXmlValue(detailsNode, 'Account');
                }

                // 0 hoặc 1 = thành công tùy spec ESB; Code khác (vd 2) = lỗi nghiệp vụ
                result.success = ('0'.equals(result.code) || '1'.equals(result.code));
                if (!result.success && String.isNotBlank(result.description)) {
                    result.errorMessage = result.description;
                }
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Parsing Error: ' + e.getMessage();
        }
        return result;
    }
}
