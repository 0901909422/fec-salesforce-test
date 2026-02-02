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
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:rep="http://fecredit.com.vn/RepaymentInfo">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<rep:GetPaymentInfo>' +
                            '<Sys>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<ContractNo>' + contractNo + '</ContractNo>' +
                        '</rep:GetPaymentInfo>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Payment_Info');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_PAYMENT_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException('GetPaymentInfo service returned HTTP error: ' + res.getStatusCode());
            }
            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetPaymentInfo service returned error'
                );
            }
            return response;

        } catch (Exception ex) {
            System.debug('### PAYMENT INFO ERROR: ' + ex.getMessage());
            throw ex;
        }
        
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
        if (String.isBlank(transId)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (transId.length() > 36) {
            throw new CalloutException('TransID is null or invalid or no longer than 36 characters');
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP};
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid, "' + requestorId + '" is not type of RequestorID');
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException('DateTime is null or invalid, "' + dateTimeStr + '" is not type of Datetime');
        }

        // ===================== Contract NUMBER =====================
        if (String.isBlank(contractNo)) {
            throw new CalloutException('contractNo is null or invalid');
        }
        if (contractNo.length() > 255) {
            throw new CalloutException('contractNo is null or invalid or no longer than 255 characters');
        }
        Boolean contractExists = true;
        if (!contractExists) {
            throw new CalloutException('contractNo is null or invalid');
        }
    }

    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode =
            envelope.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ================= SYS =================
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // ================= PAYMENTS =================
        result.Payments = new List<PaymentInfo>();

        for (Dom.XmlNode payNode : responseNode.getChildElements()) {
            if (payNode.getName() == 'Payment') {
                PaymentInfo p = new PaymentInfo();
                p.AmountPaid = FEC_CommonUltils.xmlValToDecimal(payNode, 'Amount_Paid');
                p.TransactionDate = FEC_CommonUltils.getXmlValue(payNode, 'Transaction_Date');
                p.Username = FEC_CommonUltils.getXmlValue(payNode, 'Username');
                result.Payments.add(p);
            }
        }

        return result;
    }

}