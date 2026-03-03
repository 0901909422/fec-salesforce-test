/****************************************************************************************
* File Name    : FEC_GetPaymentInfo
* Author       : Quangdv7
* Date         : 2025-12-16
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/
 
public with sharing class FEC_GetPaymentInfo {
    
    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
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
 
    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetPaymentInfo(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {
        try {
 
            validateRequest(transId, requestorId, dateTimeStr, contractNo);
            
            // ================= SOAP REQUEST BODY =================
            String soapBody = buildSoapBody(
                transId, 
                requestorId,
                dateTimeStr, 
                contractNo
                );
                
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Payment_Info');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_PAYMENT_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            
            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
            }
            ResponseWrapper response = parseResponse(res.getBody());
 
            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }
 
            return response;
 
        } catch (Exception ex) {
            System.debug('### PAYMENT INFO ERROR: ' + ex.getMessage());
            throw ex;
        }
        
    }

    /* =====================================================
       BUILD SOAP REQUEST
       ===================================================== */
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
        
    	// ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);
        
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        // ===== Main Action =====
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

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNo
    ) {
 
        // ===================== TRANSID =====================
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
 
        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP};
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
 
        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        
        if (!Pattern.matches(FEC_ConstantCommon.PATTERN_DATE_FORMAT_DDMMYYZZ,dateTimeStr)) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_Datetime_Invalid,
                    new List<String>{dateTimeStr}
                )
            );
        }
 
        // ===================== Contract NUMBER =====================
        if (String.isBlank(contractNo)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ContractNo'}));
        }
        if (contractNo.length() > 255) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'ContractNo', '255'}));
        }
    }
 
    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        ResponseWrapper result = new ResponseWrapper();
        result.Payments = new List<PaymentInfo>();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        Dom.XmlNode envelope = doc.getRootElement();
        if (envelope == null) return result;
    
        // ===== BODY =====
        Dom.XmlNode bodyNode = FEC_CommonUltils.findChildByName(envelope, 'Body');
    
        if (bodyNode == null) return result;
    
        // ===== RESPONSE NODE =====
        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }
    
        if (responseNode == null) return result;
    
        // ================= SYS =================
        Dom.XmlNode sysNode =
            FEC_CommonUltils.findChildByName(responseNode, 'Sys');
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
        }
    
        // ================= PAYMENTS =================
        for (Dom.XmlNode node : responseNode.getChildElements()) {
            String nodeName = node.getName();
            if (nodeName != null && nodeName.contains('Payment')) {
                PaymentInfo p = new PaymentInfo();
                p.AmountPaid = FEC_CommonUltils.xmlValToDecimal(node, 'Amount_Paid');
                p.TransactionDate = FEC_CommonUltils.getValueSafe(node, 'Transaction_Date');
                p.Username = FEC_CommonUltils.getValueSafe(node, 'Username');
                result.Payments.add(p);
            }
        }
        return result;
    }
}