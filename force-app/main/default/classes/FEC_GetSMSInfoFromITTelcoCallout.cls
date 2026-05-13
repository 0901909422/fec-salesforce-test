/****************************************************************************************
* File Name    : FEC_GetSMSInfoFromITTelcoCallout
* Description  : SOAP GetSMSInfoFromITTelco (SMSLogWS) — tra cứu log SMS theo số điện thoại.
*                Khớp bản test KH: endpoint .../GetSMSInfoFromITTelco, body ns1:GetSMSInfoFromITTelco,
*                không gửi header SOAPAction (FEC_SOAP_Action__c để trống trong CMDT).
*                Auth Basic qua Mulesoft: cấu hình trên Named Credential / endpoint nội bộ.
*                Sys.Code: 1 = DATA_FOUND, 3 = DATA_NOT_FOUND, 0 = ERROR
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
* 1.0      2026-04-15     Cursor              Create
****************************************************************************************/
public with sharing class FEC_GetSMSInfoFromITTelcoCallout {

    public static final String API_CONFIG_NAME = 'FEC_GetSMSInfoFromITTelco';
    private static final String SERVICE_NS = 'http://esbservice.fecredit.org/SMSLogWS/';

    public static final String SYS_CODE_DATA_FOUND     = FEC_ConstantCommon.CODE_SUCCESS;     // '1'
    public static final String SYS_CODE_ERROR          = FEC_ConstantCommon.CODE_SYS_ERROR;   // '0'
    public static final String SYS_CODE_DATA_NOT_FOUND = FEC_ConstantCommon.CODE_FAILURE;     // '3'

    // =========================================================================
    // RESPONSE WRAPPERS
    // =========================================================================
    public class SmsLogRecord {
        @AuraEnabled public String        phone                { get; set; }
        @AuraEnabled public String        smsTemplateCode      { get; set; }
        @AuraEnabled public String        smsTemplateContent   { get; set; }
        @AuraEnabled public List<String>  sentDates            { get; set; }
    }

    public class GetSMSInfoResult {
        @AuraEnabled public String  sysTransId     { get; set; }
        @AuraEnabled public String  sysDateTime    { get; set; }
        @AuraEnabled public String  sysCode        { get; set; }
        @AuraEnabled public String  sysDescription { get; set; }
        @AuraEnabled public String  phoneNumber    { get; set; }
        @AuraEnabled public List<SmsLogRecord> records { get; set; }

        /** HTTP 200 và parse được; Sys.Code khác 0 (tức 1 hoặc 3). */
        @AuraEnabled public Boolean success        { get; set; }
        /** Sys.Code == 1 */
        @AuraEnabled public Boolean dataFound      { get; set; }
        /** Sys.Code == 3 */
        @AuraEnabled public Boolean dataNotFound   { get; set; }
        @AuraEnabled public String  errorMessage   { get; set; }
        @AuraEnabled public Integer httpStatus     { get; set; }
    }

    // =========================================================================
    // LOGGING (same pattern as FEC_CheckEligibleCallout.ResponseLog + logApiResponse)
    // =========================================================================
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

    private static ResponseLog responseLog;

    // =========================================================================
    // MAIN CALLOUT
    // =========================================================================
    /**
     * Gọi SOAP GetSMSInfoFromITTelco với số điện thoại cần tra cứu.
     */
    @AuraEnabled
    public static GetSMSInfoResult getSmsInfoFromItTelco(String phoneNumber) {
        GetSMSInfoResult result = new GetSMSInfoResult();
        result.success = false;
        result.dataFound = false;
        result.dataNotFound = false;
        result.records = new List<SmsLogRecord>();

        String transId = FEC_CommonUltils.generateTransactionId();
        String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.DATETIME_FORMAT);

        try {
            if (String.isBlank(phoneNumber)) {
                result.errorMessage = String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Phone Number' }
                );
                return result;
            }

            String normalizedPhone = phoneNumber.trim();
            Dom.Document doc = buildSoapRequest(transId, FEC_ConstantCommon.API_REQUESTOR_ID, timestamp, normalizedPhone);
            String soapRequest = doc.toXmlString();

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            String baseEndpoint = (apiSetting != null && String.isNotBlank(apiSetting.FEC_Endpoint__c)) ? apiSetting.FEC_Endpoint__c : '';
            String configEndpoint = (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c)) ? apiConfig.FEC_Endpoint__c : '';
            
            String endpoint = baseEndpoint + configEndpoint;

            String soapAction = (apiConfig != null && String.isNotBlank(apiConfig.FEC_SOAP_Action__c)) ? apiConfig.FEC_SOAP_Action__c : null;

            responseLog = new ResponseLog(API_CONFIG_NAME, endpoint, FEC_ConstantCommon.API_METHOD_POST, soapRequest, null, null);

            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                soapAction,
                null,
                soapRequest
            );

            responseLog.response = res;

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                result = parseSoapResponse(res.getBody());
                result.success = (SYS_CODE_DATA_FOUND.equals(result.sysCode) || SYS_CODE_DATA_NOT_FOUND.equals(result.sysCode));
                if (!result.success) {
                    result.errorMessage = String.isNotBlank(result.sysDescription) ? result.sysDescription : result.errorMessage;
                }
            } else {
                result.success = false;
                result.httpStatus = res.getStatusCode();
                result.errorMessage = 'HTTP Error: ' + res.getStatus();
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();

            if (responseLog != null) {
                responseLog.errorMessage = e.getMessage();
            }

            System.debug('### GetSMSInfoFromITTelco ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString());
        } finally {
            logApiResponse();
        }

        return result;
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
        }
    }

    // =========================================================================
    // SOAP REQUEST / RESPONSE
    // =========================================================================
    private static Dom.Document buildSoapRequest(String transId, String requestorId, String timestamp, String phoneNumber) {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:ns1', SERVICE_NS);

        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action = body.addChildElement('ns1:GetSMSInfoFromITTelco', null, null);

        Dom.XmlNode sysNode = action.addChildElement('Sys', null, null);
        sysNode.addChildElement('TransID', null, null).addTextNode(transId);
        sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysNode.addChildElement('DateTime', null, null).addTextNode(timestamp);

        action.addChildElement('PhoneNumber', null, null).addTextNode(phoneNumber);

        return doc;
    }

    private static GetSMSInfoResult parseSoapResponse(String responseBody) {
        GetSMSInfoResult result = new GetSMSInfoResult();
        result.success = false;
        result.dataFound = false;
        result.dataNotFound = false;
        result.records = new List<SmsLogRecord>();

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            Dom.XmlNode responseNode = (bodyNode != null)
                ? bodyNode.getChildElement('GetSMSInfoFromITTelcoResponse', SERVICE_NS)
                : null;

            if (responseNode == null) {
                responseNode = (bodyNode != null) ? FEC_CommonUltils.findChildByName(bodyNode, 'GetSMSInfoFromITTelcoResponse') : null;
            }
            if (responseNode == null) {
                responseNode = (bodyNode != null)
                    ? bodyNode.getChildElement('GetSMSInfoFromITelcoResponse', SERVICE_NS)
                    : null;
            }
            if (responseNode == null) {
                responseNode = (bodyNode != null) ? FEC_CommonUltils.findChildByName(bodyNode, 'GetSMSInfoFromITelcoResponse') : null;
            }

            if (responseNode == null) {
                Dom.XmlNode fault = (bodyNode != null) ? bodyNode.getChildElement('Fault', FEC_ConstantCommon.SOAP_ENV) : null;
                if (fault != null) {
                    result.errorMessage = FEC_CommonUltils.getXmlValue(fault, 'faultstring');
                } else {
                    result.errorMessage = System.Label.FEC_MSG_Unexpected_SOAP_Response;
                }
                return result;
            }

            Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
            if (sysNode == null) {
                sysNode = FEC_CommonUltils.findChildByName(responseNode, 'Sys');
            }
            if (sysNode == null) {
                sysNode = responseNode.getChildElement('SysResponse', null);
            }
            if (sysNode == null) {
                sysNode = FEC_CommonUltils.findChildByName(responseNode, 'SysResponse');
            }

            if (sysNode != null) {
                result.sysTransId = firstNonBlank(
                    FEC_CommonUltils.getXmlValue(sysNode, 'TransID'),
                    FEC_CommonUltils.getValueSafe(sysNode, 'TransID')
                );
                result.sysDateTime = firstNonBlank(
                    FEC_CommonUltils.getXmlValue(sysNode, 'DateTime'),
                    FEC_CommonUltils.getValueSafe(sysNode, 'DateTime')
                );
                result.sysCode = firstNonBlank(
                    FEC_CommonUltils.getXmlValue(sysNode, 'Code'),
                    FEC_CommonUltils.getValueSafe(sysNode, 'Code')
                );
                result.sysDescription = firstNonBlank(
                    FEC_CommonUltils.getXmlValue(sysNode, 'Description'),
                    FEC_CommonUltils.getValueSafe(sysNode, 'Description')
                );
            }

            result.phoneNumber = firstNonBlank(
                FEC_CommonUltils.getXmlValue(responseNode, 'PhoneNumber'),
                FEC_CommonUltils.getValueSafe(responseNode, 'PhoneNumber')
            );

            result.dataFound = SYS_CODE_DATA_FOUND.equals(result.sysCode);
            result.dataNotFound = SYS_CODE_DATA_NOT_FOUND.equals(result.sysCode);

            // XML structure has repeating <Records> nodes directly under responseNode
            for (Dom.XmlNode child : responseNode.getChildElements()) {
                if (child == null) continue;

                String nm = child.getName();
                // Check if this node is a record (handle both plural and singular tags)
                if (nm == 'Records' || nm == 'Record' || nm.endsWith(':Records') || nm.endsWith(':Record')) {
                    
                    SmsLogRecord row = new SmsLogRecord();
                    row.sentDates = new List<String>();
                    
                    row.phone = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'Phone'),
                        FEC_CommonUltils.getValueSafe(child, 'Phone')
                    );
                    row.smsTemplateCode = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'SMSTemplateCode'),
                        FEC_CommonUltils.getValueSafe(child, 'SMSTemplateCode')
                    );
                    row.smsTemplateContent = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'SMSTemplateContent'),
                        FEC_CommonUltils.getValueSafe(child, 'SMSTemplateContent')
                    );

                    // Parse the list of sent dates within each record
                    Dom.XmlNode sentDatesNode = child.getChildElement('SentDates', null);
                    if (sentDatesNode == null) {
                        sentDatesNode = FEC_CommonUltils.findChildByName(child, 'SentDates');
                    }
                    if (sentDatesNode != null) {
                        for (Dom.XmlNode sd : sentDatesNode.getChildElements()) {
                            if (sd != null && (sd.getName() == 'SentDate' || (sd.getName() != null && sd.getName().endsWith(':SentDate')))) {
                                String t = sd.getText();
                                if (String.isNotBlank(t)) {
                                    row.sentDates.add(t.trim());
                                }
                            }
                        }
                    }
                    
                    // Fallback for single SentDate field
                    String singleSent = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'SentDate'),
                        FEC_CommonUltils.getValueSafe(child, 'SentDate')
                    );
                    if (String.isNotBlank(singleSent) && row.sentDates.isEmpty()) {
                        row.sentDates.add(singleSent);
                    }

                    result.records.add(row);
                }
            }
            
            // Re-evaluate business success flags based on parsed records
            result.dataFound = !result.records.isEmpty();
            result.dataNotFound = result.records.isEmpty() && SYS_CODE_DATA_NOT_FOUND.equals(result.sysCode);
        } catch (Exception e) {
            result.errorMessage = 'Parsing Error: ' + e.getMessage();
        }

        return result;
    }

    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }
}
