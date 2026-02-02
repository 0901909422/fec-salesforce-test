/****************************************************************************************
 * File Name    : FEC_GetStatus
 * Author       : Toannd61
 * Date         : 2025-12-15
 * Description  : Update data for API service with Validation & Data Mapping
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 3.2      2025-01-13     Toannd61            Update
 ****************************************************************************************/

public with sharing class FEC_GetStatus {

    private static final String SOAP_NS = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String SERVICE_NS = 'http://fecredit.com.vn/CMS_DeliveryCardStatusWS'; 
    
    private static final String ENDPOINT = '/CMS_DeliveryCardStatusWS';
    private static final String MOCKUP_ENDPOINT = 'https://fa2dbdcc-9a32-4469-8fc0-d9ca8def9cdd.mock.pstmn.io/CIF_CardInfo';
    
    private static final Integer MAX_ID_LEN = 36; 
    private static final Integer MAX_ACCOUNT_LEN = 255;

    // --- WRAPPER CLASS ---
    public class CardDeliveryInfo {
        // Sys Info
        @AuraEnabled public String transId { get; set; }
        @AuraEnabled public String sysDateTime { get; set; } 
        @AuraEnabled public String responseCode { get; set; } 
        @AuraEnabled public String responseDesc { get; set; } 
        
        // Info Data
        @AuraEnabled public String accountNumber { get; set; }  
        @AuraEnabled public String cardNumber { get; set; }     
        @AuraEnabled public String trackingNo { get; set; }     
        @AuraEnabled public String issueDate { get; set; }      
        @AuraEnabled public String status { get; set; }         
        @AuraEnabled public String description { get; set; }    
        @AuraEnabled public String deliveryNotes { get; set; }  
        @AuraEnabled public String receiverName { get; set; }   
    }

    @AuraEnabled
    public static CardDeliveryInfo getDeliveryStatus(String accountNumber) {
        try {
            // 1. CHUẨN BỊ DỮ LIỆU
            String transId = UUID.randomUUID().toString(); 
            String requestorId = UUID.randomUUID().toString(); 
            String reqTime = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            
            // 2. VALIDATION
            validateRequest(transId, requestorId, reqTime, accountNumber);

            // 3. TẠO REQUEST XML
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', SOAP_NS, 'soapenv');
            envelope.addChildElement('Header', SOAP_NS, null);
            Dom.XmlNode body = envelope.addChildElement('Body', SOAP_NS, null);
            Dom.XmlNode requestNode = body.addChildElement('GetStatus', SERVICE_NS, 'cms');
            
            Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId); 
            sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
            
            requestNode.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
            
            // Lấy cấu hình API từ Custom Setting
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

            // 4. GỬI REQUEST
            HttpRequest req = new HttpRequest();
            // Cập nhật endpoint thực tế của bạn hoặc dùng Mock
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            // req.setEndpoint('https://fa2dbdcc-9a32-4469-8fc0-d9ca8def9cdd.mock.pstmn.io/CMS_DeliveryCardStatusWS'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE);
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CMS_DeliveryCardStatusWS/GetStatus'); 
            req.setBodyDocument(doc);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse kết quả và trả về wrapper
                CardDeliveryInfo info = parseDeliveryResponse(res.getBodyDocument());
                
                // Kiểm tra responseCode từ API
                // Code = "1" là success theo API spec
                // Nếu không phải "1" thì có thể là account không tồn tại hoặc lỗi khác
                if (info.responseCode != '1') {
                    throw new CalloutException('Account Number is null or invalid');
                }
                
                return info;
            } else {
                throw new CalloutException('API Error: ' + res.getStatus() + ' Body: ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ==========================================
    // VALIDATION LOGIC
    // ==========================================
    public static void validateRequest(String transId, String requestorId, String dateTimeStr, String accountNumber) {
        if (String.isBlank(transId)) throw new CalloutException('TransID is null or invalid');
        if (transId.length() > MAX_ID_LEN) throw new CalloutException('TransID is null or invalid or no longer than 36 characters');

        if (String.isBlank(requestorId)) throw new CalloutException('RequestorID is null or invalid');
        if (requestorId.length() > MAX_ID_LEN) throw new CalloutException('RequestorID is null or invalid'); 

        if (String.isBlank(dateTimeStr)) throw new CalloutException('DateTime is null or invalid');
        String datePattern = FEC_ConstantCommon.PATTERN_SYS_TIME;
        if (!Pattern.compile(datePattern).matcher(dateTimeStr).matches()) throw new CalloutException('DateTime is null or invalid or wrong format');

        if (String.isBlank(accountNumber)) throw new CalloutException('AccountNumber is null or invalid');
        if (accountNumber.length() > MAX_ACCOUNT_LEN) throw new CalloutException('AccountNumber is null or invalid or no longer than 255 characters');
    }

    // --- PARSE LOGIC ---
    private static CardDeliveryInfo parseDeliveryResponse(Dom.Document doc) {
        CardDeliveryInfo info = new CardDeliveryInfo();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = root.getChildElement('Body', SOAP_NS);
        Dom.XmlNode responseNode = body.getChildElement('GetStatusResponse', SERVICE_NS);
        
        if (responseNode != null) {
            Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
            info.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            info.sysDateTime = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            info.responseCode = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
            info.responseDesc = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
            
            Dom.XmlNode infoNode = responseNode.getChildElement('Info', null);
            if (infoNode != null) {
                info.accountNumber = FEC_CommonUltils.getXmlValue(infoNode, 'AccountNumber');
                info.cardNumber = FEC_CommonUltils.getXmlValue(infoNode, 'CardNumber');        
                info.trackingNo = FEC_CommonUltils.getXmlValue(infoNode, 'TrackingNo');
                info.issueDate = FEC_CommonUltils.getXmlValue(infoNode, 'IssuelastUpdate');
                info.status = FEC_CommonUltils.getXmlValue(infoNode, 'Status');
                info.description = FEC_CommonUltils.getXmlValue(infoNode, 'Description');
                info.deliveryNotes = FEC_CommonUltils.getXmlValue(infoNode, 'Deliverynotes');
                info.receiverName = FEC_CommonUltils.getXmlValue(infoNode, 'ReceiverName');    
            }
        }
        return info;
    }

}