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

    private static final String SERVICE_NS = 'http://fecredit.com.vn/CMS_DeliveryCardStatusWS'; 
    
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
            String requestorId = FEC_ConstantCommon.API_REQUESTOR_ID; 
            String reqTime = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
            
            // 2. VALIDATION
            validateRequest(transId, requestorId, reqTime, accountNumber);

            // 3. TẠO REQUEST XML
            Dom.Document doc = new Dom.Document();
            Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
            envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, null);
            Dom.XmlNode requestNode = body.addChildElement('GetStatus', SERVICE_NS, 'cms');
            
            Dom.XmlNode sysNode = requestNode.addChildElement('Sys', null, null);
            sysNode.addChildElement('TransID', null, null).addTextNode(transId);
            sysNode.addChildElement('RequestorID', null, null).addTextNode(requestorId); 
            sysNode.addChildElement('DateTime', null, null).addTextNode(reqTime);
            
            requestNode.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
            
            // 4. GỬI REQUEST
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Status');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_STATUS_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, doc, '');

            if (res.getStatusCode() == 200) {
                // Parse kết quả và trả về wrapper
                CardDeliveryInfo info = parseDeliveryResponse(res.getBodyDocument());
                
                // Kiểm tra responseCode từ API
                // Code = "1" là success theo API spec
                // Nếu không phải "1" thì có thể là account không tồn tại hoặc lỗi khác
                if (info.responseCode != '1') {
                    throw new CalloutException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{info.responseDesc}));
                }
                
                return info;
            } else {
                throw new CalloutException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{res.getStatus() + ' Body: ' + res.getBody()}));
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
        if (String.isBlank(transId) || transId.length() > MAX_ID_LEN) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId) || requestorId.length() > MAX_ID_LEN) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        String datePattern = FEC_ConstantCommon.PATTERN_SYS_TIME;
        if (!Pattern.compile(datePattern).matcher(dateTimeStr).matches()) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr}));
        }
        if (String.isBlank(accountNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'}));
        }
        if (accountNumber.length() > MAX_ACCOUNT_LEN) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'AccountNumber', '255'}));
        }
    }

    // --- PARSE LOGIC ---
    private static CardDeliveryInfo parseDeliveryResponse(Dom.Document doc) {
        CardDeliveryInfo info = new CardDeliveryInfo();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
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