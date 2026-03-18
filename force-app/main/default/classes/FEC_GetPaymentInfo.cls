/** GetPaymentInfo SOAP — RepaymentInfo. */
public with sharing class FEC_GetPaymentInfo {

    private static ResponseLog responseLog;

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

    public static ResponseWrapper callGetPaymentInfo(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {
        try {
            validateRequest(transId, requestorId, dateTimeStr, contractNo);
            String soapBody = buildSoapBody(transId, requestorId, dateTimeStr, contractNo);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Payment_Info');

            // String endpoint = apiSetting?.FEC_Call_Mock__c
            //     ? FEC_MockupEndpoint.GET_PAYMENT_INFO_ENDPOINT_MOCKUP
            //     : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

            responseLog = new ResponseLog(
                'FEC_GetPaymentInfo', endpoint, 'POST', soapBody, res, null
            );

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
            }
            String responseBody = res.getBody();
            ResponseWrapper response = parseResponse(responseBody);
            if (response.Payments == null || response.Payments.isEmpty()) {
                String snippet = responseBody != null && responseBody.length() > 500 ? responseBody.substring(0, 500) + '...' : responseBody;
                System.debug('### GetPaymentInfo: parsed 0 Payments. Response snippet: ' + snippet);
            }

            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }

            return response;

        } catch (Exception ex) {
            if (responseLog != null) {
                responseLog.errorMessage = ex.getMessage();
            }
            System.debug('### PAYMENT INFO ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    private static String buildSoapBody(
        String transID,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            null,
            null
        );

        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );

        envelope.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/RepaymentInfo'
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        Dom.XmlNode action =
            body.addChildElement('ns1:GetPaymentInfo', null, null);

        action.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/RepaymentInfo'
        );

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('ContractNo', null, null)
              .addTextNode(contractNo);

        return doc.toXmlString();
    }

    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }

        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP,FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN};
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        Boolean validFormat = Pattern.matches(FEC_ConstantCommon.PATTERN_DATE_FORMAT_DDMMYYZZ, dateTimeStr)
            || Pattern.matches(FEC_ConstantCommon.PATTERN_DATE_TIME, dateTimeStr);
        if (!validFormat) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Datetime_Invalid,
                    new List<String>{dateTimeStr}
                )
            );
        }

        if (String.isBlank(contractNo)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ContractNo'}));
        }
        if (contractNo.length() > 255) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'ContractNo', '255'}));
        }
    }

    private static ResponseWrapper parseResponse(String xml) {
        ResponseWrapper result = new ResponseWrapper();
        result.Payments = new List<PaymentInfo>();
        if (String.isBlank(xml)) return result;
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xml);
            Dom.XmlNode envelope = doc.getRootElement();
        if (envelope == null) return result;

        Dom.XmlNode bodyNode = FEC_CommonUltils.findChildByName(envelope, 'Body');

        if (bodyNode == null) return result;

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        if (responseNode == null) return result;

        Dom.XmlNode sysNode =
            FEC_CommonUltils.findChildByName(responseNode, 'Sys');
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
        }

        // Payments: wrapper <Payments> hoặc <Payment> trực tiếp dưới response
        Dom.XmlNode paymentsWrapper = FEC_CommonUltils.findChildByName(responseNode, 'Payments');
        if (paymentsWrapper != null) {
            for (Dom.XmlNode node : paymentsWrapper.getChildElements()) {
                if (isPaymentItemNode(node)) {
                    result.Payments.add(parsePaymentNode(node));
                }
            }
        }
        if (result.Payments.isEmpty()) {
            for (Dom.XmlNode node : responseNode.getChildElements()) {
                if (isPaymentItemNode(node)) {
                    result.Payments.add(parsePaymentNode(node));
                }
            }
        }
        } catch (Exception e) {
            System.debug('### GetPaymentInfo parseResponse ERROR: ' + e.getMessage());
            System.debug('### GetPaymentInfo parseResponse stack: ' + e.getStackTraceString());
        }
        return result;
    }

    private static Boolean isPaymentItemNode(Dom.XmlNode node) {
        if (node == null) return false;
        String name = node.getName();
        if (String.isBlank(name)) return false;
        String localName = name.contains(':') ? name.substring(name.indexOf(':') + 1) : name;
        if (String.isBlank(localName)) return false;
        return 'Payment'.equalsIgnoreCase(localName) || 'PaymentInfo'.equalsIgnoreCase(localName);
    }

    private static PaymentInfo parsePaymentNode(Dom.XmlNode node) {
        PaymentInfo p = new PaymentInfo();
        String amountStr = FEC_CommonUltils.getValueSafe(node, 'Amount_Paid');
        p.AmountPaid = parseDecimalSafe(amountStr);
        p.TransactionDate = FEC_CommonUltils.getValueSafe(node, 'Transaction_Date');
        p.Username = FEC_CommonUltils.getValueSafe(node, 'Username');
        return p;
    }

    private static Decimal parseDecimalSafe(String v) {
        if (String.isBlank(v)) return null;
        try {
            return Decimal.valueOf(v.trim());
        } catch (Exception e) {
            return null;
        }
    }
}
