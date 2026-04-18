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

    public static final String SYS_CODE_DATA_FOUND     = '1';
    public static final String SYS_CODE_ERROR          = '0';
    public static final String SYS_CODE_DATA_NOT_FOUND = '3';

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

            String endpoint = (apiSetting != null && String.isNotBlank(apiSetting.FEC_Endpoint__c))
                ? (apiSetting.FEC_Endpoint__c + (apiConfig != null ? apiConfig.FEC_Endpoint__c : ''))
                : ('callout:FECredit_Service' + (apiConfig != null ? apiConfig.FEC_Endpoint__c : '/esb/telecom/SMSLogWS/GetSMSInfoFromITTelco'));

            // KH test thành công không set SOAPAction; chỉ gửi header khi CMDT có giá trị (một số gateway khác có thể cần)
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

            FEC_CommonUltils.logApi(
                'FEC_GetSMSInfoFromITTelcoCallout',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapRequest,
                res,
                null
            );

            if (res != null && (res.getStatusCode() == 200 || res.getStatusCode() == 201)) {
                result = parseSoapResponse(res.getBody());
                result.httpStatus = res.getStatusCode();
                if (SYS_CODE_ERROR.equals(result.sysCode)) {
                    result.success = false;
                    if (String.isBlank(result.errorMessage)) {
                        result.errorMessage = result.sysDescription;
                    }
                } else if (SYS_CODE_DATA_FOUND.equals(result.sysCode) || SYS_CODE_DATA_NOT_FOUND.equals(result.sysCode)) {
                    result.success = true;
                } else {
                    result.success = String.isNotBlank(result.sysCode);
                    if (!result.success && String.isBlank(result.errorMessage)) {
                        result.errorMessage = 'Unknown Sys.Code: ' + result.sysCode;
                    }
                }
            } else {
                result.httpStatus = (res != null) ? res.getStatusCode() : 0;
                result.errorMessage = (res != null) ? res.getBody() : 'No response from server';
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('### GetSMSInfoFromITTelco ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
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
                    result.errorMessage = 'Unexpected SOAP response (no GetSMSInfoFromITTelcoResponse)';
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

            Dom.XmlNode recordsParent = responseNode.getChildElement('Records', null);
            if (recordsParent == null) {
                recordsParent = FEC_CommonUltils.findChildByName(responseNode, 'Records');
            }

            if (recordsParent != null) {
                for (Dom.XmlNode child : recordsParent.getChildElements()) {
                    if (child == null || child.getName() == null) {
                        continue;
                    }
                    String nm = child.getName();
                    Boolean isRecord = (nm == 'Record' || nm.endsWith(':Record'));
                    Boolean looksLikeRow = (FEC_CommonUltils.getXmlValue(child, 'Phone') != null
                        || FEC_CommonUltils.getValueSafe(child, 'Phone') != null);

                    if (!isRecord && !looksLikeRow) {
                        continue;
                    }

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
                    String singleSent = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'SentDate'),
                        FEC_CommonUltils.getValueSafe(child, 'SentDate')
                    );
                    if (String.isNotBlank(singleSent) && (row.sentDates == null || row.sentDates.isEmpty())) {
                        row.sentDates.add(singleSent);
                    }

                    result.records.add(row);
                }
            }
        } catch (Exception e) {
            result.errorMessage = 'Parsing Error: ' + e.getMessage();
        }

        return result;
    }

    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }
}
