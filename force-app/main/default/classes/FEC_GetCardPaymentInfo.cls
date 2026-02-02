/****************************************************************************************
 * File Name    : FEC_GetCardPaymentInfo
 * Author       : Toannd61
 * Date         : 2025-12-15
 * Description  : Update data for API service with Validation
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 3.3      2025-01-08     Toannd61            Update
 ****************************************************************************************/

 public with sharing class FEC_GetCardPaymentInfo {

    private static final String CIF_NS = 'http://fecredit.com.vn/CIF_CardInfo'; 

    // Cấu hình Validation
    private static final Integer MAX_ID_LEN = 36;
    private static final Integer MAX_ACCOUNT_LEN = 255;

    // ==========================================
    // 1. WRAPPER CLASS
    // ==========================================
    public class CardPaymentResult {
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String sysDateTime { get; set; }
        @AuraEnabled public String responseCode { get; set; }
        @AuraEnabled public String responseDesc { get; set; }
        @AuraEnabled public Decimal fullPaymentAmount { get; set; } 
    }

    // ==========================================
    // 2. MAIN METHOD
    // ==========================================
    @AuraEnabled
    public static CardPaymentResult getCardPaymentInfo(String accountNumber, Date queryDate) {
        try {
            // ---------------------------------------------------------
            // A. CHUẨN BỊ DỮ LIỆU
            // ---------------------------------------------------------
            String transId = UUID.randomUUID().toString();
            String requestorId = UUID.randomUUID().toString(); 
            String sysTime = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            
            // Convert Date sang String format YYYY-MM-DD
            String dateStr = '';
            if (queryDate != null) {
                dateStr = DateTime.newInstance(queryDate.year(), queryDate.month(), queryDate.day()).format(FEC_ConstantCommon.DATE_FORMAT);
            }

            // ---------------------------------------------------------
            // B. VALIDATION (GỌI HÀM KIỂM TRA)
            // ---------------------------------------------------------
            validateRequest(transId, requestorId, sysTime, accountNumber, dateStr);

            // ---------------------------------------------------------
            // C. TẠO REQUEST XML
            // ---------------------------------------------------------
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode requestNode = body.addChildElement('GetCardPaymentInfo', CIF_NS, 'cif');
            
            // Sys Block
            Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId);
            sysNode.addChildElement('DateTime', null, null).addTextNode(sysTime);
            
            // Data Block
            requestNode.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
            requestNode.addChildElement('Date', null, null).addTextNode(dateStr);

            // ---------------------------------------------------------
            // D. GỬI CALLOUT
            // ---------------------------------------------------------
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Payment_Info');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CARD_PAYMENT_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

            // ---------------------------------------------------------
            // E. XỬ LÝ RESPONSE
            // ---------------------------------------------------------
            if (res.getStatusCode() == 200) {
                return parseResponse(res.getBodyDocument());
            } else {
                throw new CalloutException('SOAP API Error: ' + res.getStatus() + ' - ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception in getCardPaymentInfo: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }   

    // ==========================================
    // 3. VALIDATION LOGIC 
    // ==========================================
    private static void validateRequest(String transId, String requestorId, String sysTime, String accountNumber, String dateStr) {
        
        // 1 & 2. Validate TransID
        if (String.isBlank(transId)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (transId.length() > MAX_ID_LEN) {
            throw new CalloutException('TransID is null or invalid or no longer than 36 characters');
        }

        // 1 & 3. Validate RequestorID
        if (String.isBlank(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid');
        }
        if (requestorId.length() > MAX_ID_LEN) {
            throw new CalloutException('RequestorID is null or invalid');
        }

        // 1 & 4. Validate Sys.DateTime
        if (String.isBlank(sysTime)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        // Regex format: yyyy-MM-ddTHH:mm:ss
        String sysTimePattern = FEC_ConstantCommon.PATTERN_SYS_TIME;
        if (!Pattern.matches(sysTimePattern, sysTime)) {
            throw new CalloutException('DateTime is null or invalid or wrong format');
        }

        // 1 & 5. Validate AccountNumber
        if (String.isBlank(accountNumber)) {
            throw new CalloutException('AccountNumber is null or invalid');
        }
        if (accountNumber.length() > MAX_ACCOUNT_LEN) {
            throw new CalloutException('AccountNumber is null or invalid or no longer than 255 characters');
        }

        // 1 & 6. Validate Date (Query Date)
        if (String.isBlank(dateStr)) {
            throw new CalloutException('Date is null or invalid or must have format YYYY-MM-DD');
        }
        // Regex format: YYYY-MM-DD
        String datePattern = '^\\d{4}-\\d{2}-\\d{2}$';
        if (!Pattern.matches(datePattern, dateStr)) {
            throw new CalloutException('Date is null or invalid or must have format YYYY-MM-DD');
        }
    }

    // ==========================================
    // 4. PARSER
    // ==========================================
    private static CardPaymentResult parseResponse(Dom.Document doc) {
        CardPaymentResult result = new CardPaymentResult();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
        Dom.XmlNode responseNode = body.getChildElement('GetCardPaymentInfoResponse', CIF_NS);
        
        if (responseNode != null) {
            Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
            result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.sysDateTime = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime'); 
            result.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            result.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
            
            Dom.XmlNode paymentNode = responseNode.getChildElement('PaymentInfo', null);
            if (paymentNode != null) {
                String amtStr = FEC_CommonUltils.getXmlValue(paymentNode, 'FullPaymentAmount');
                if (String.isNotBlank(amtStr)) {
                    result.fullPaymentAmount = Decimal.valueOf(amtStr);
                } else {
                    result.fullPaymentAmount = 0;
                }
            }
        }
        return result;
    }

}