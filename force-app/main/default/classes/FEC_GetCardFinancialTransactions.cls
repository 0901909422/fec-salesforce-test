/****************************************************************************************
 * File Name    : FEC_GetCardFinancialTransactions
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetCardFinancialTransactions {

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CIF_CardInfo';
    private static final String MOCKUP_ENDPOINT = 'https://9d19f455-8916-4c0f-873d-b9e022bcdc75.mock.pstmn.io';

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public List<FinancialTransaction> Transactions;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class FinancialTransaction {
        public String TRNXDateAndTime;
        public String Description;
        public String CreditDebitFlag;
        public String TransactionType;
        public String Status;
        public Decimal TRNXAmount;
        public String TransactionCode;
        public Decimal Fee;
        public String PostingDate;
        public String SettlementDate;
        public String Plan;
        public String PlanType;
        public String RRN;
        public String AuthCode;
        public String MerchantName;
        public String PaymentFlag;
        public String IsCashTRNX;
        public Integer OTPSent;
        public String LOGIC_MOD;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetCardFinancialTransactions(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        Date fromDate,
        Date toDate
    ) {
        try {

            validateRequest(transID, requestorId, dateTimeStr, accountNumber, fromDate,toDate);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE);
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CardInfo/GetCardFinancialTransactions');

            // ================= SOAP REQUEST BODY =================
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<cif:GetCardFinancialTransactions>' +
                            '<Sys>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                            '<FromDate>' + fromDate.format() + '</FromDate>' +
                            '<ToDate>' + toDate.format() + '</ToDate>' +
                        '</cif:GetCardFinancialTransactions>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetCardFinancialTransactions service returned HTTP error: ' + res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetCardFinancialTransactions service returned error'
                );
            }
            
            return response;

        } catch (Exception ex) {
            System.debug('### FIN TXN ERROR: ' + ex.getMessage());
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
        String accountNumber,
        Date fromDate,
        Date toDate
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

        // ===================== ACCOUNT NUMBER =====================
        if (String.isBlank(accountNumber)) {
            throw new CalloutException('AccountNumber is null or invalid');
        }
        if (accountNumber.length() > 255) {
            throw new CalloutException('AccountNumber is null or invalid or no longer than 255 characters');
        }
        Boolean accountExists = true;
        if (!accountExists) {
            throw new CalloutException('AccountNumber is null or invalid');
        }

        // ===================== FROM DATE =====================
        if (fromDate != null) {
            try {
                String test = fromDate.format(); // YYYY-MM-DD
            } catch(Exception e) {
                throw new CalloutException('FromDate is null or invalid or must have format YYYY-MM-DD');
            }
        }

        // ===================== TO DATE =====================
        if (toDate != null) {
            try {
                String test = toDate.format(); // YYYY-MM-DD
            } catch(Exception e) {
                throw new CalloutException('ToDate is null or invalid or must have format YYYY-MM-DD');
            }

            if (fromDate != null && toDate < fromDate) {
                throw new CalloutException('ToDate is null or invalid or must be after FromDate');
            }
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
            envelope.getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

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

        // ================= TRANSACTIONS =================
        // ================= TRANSACTIONS =================
    result.Transactions = new List<FinancialTransaction>();

    Dom.XmlNode txnsNode = responseNode.getChildElement('Transactions', null);
    if (txnsNode != null) {

        for (Dom.XmlNode txnNode : txnsNode.getChildElements()) {

            if (txnNode.getName() != 'Transaction') continue;

            FinancialTransaction ft = new FinancialTransaction();
            ft.TRNXDateAndTime = FEC_CommonUltils.getXmlValue(txnNode, 'TRNXDateAndTime');
            ft.Description = FEC_CommonUltils.getXmlValue(txnNode, 'Description');
            ft.CreditDebitFlag = FEC_CommonUltils.getXmlValue(txnNode, 'CreditDebitFlag');
            ft.TransactionType = FEC_CommonUltils.getXmlValue(txnNode, 'TransactionType');
            ft.Status = FEC_CommonUltils.getXmlValue(txnNode, 'Status');
            ft.TRNXAmount = FEC_CommonUltils.xmlValToDecimal(txnNode, 'TRNXAmount');
            ft.TransactionCode = FEC_CommonUltils.getXmlValue(txnNode, 'TransactionCode');
            ft.Fee = FEC_CommonUltils.xmlValToDecimal(txnNode, 'Fee');
            ft.PostingDate = FEC_CommonUltils.getXmlValue(txnNode, 'PostingDate');
            ft.SettlementDate = FEC_CommonUltils.getXmlValue(txnNode, 'SettlementDate');
            ft.Plan = FEC_CommonUltils.getXmlValue(txnNode, 'Plan');
            ft.PlanType = FEC_CommonUltils.getXmlValue(txnNode, 'PlanType');
            ft.RRN = FEC_CommonUltils.getXmlValue(txnNode, 'RRN');
            ft.AuthCode = FEC_CommonUltils.getXmlValue(txnNode, 'AuthCode');
            ft.MerchantName = FEC_CommonUltils.getXmlValue(txnNode, 'MerchantName');
            ft.PaymentFlag = FEC_CommonUltils.getXmlValue(txnNode, 'PaymentFlag');
            ft.IsCashTRNX = FEC_CommonUltils.getXmlValue(txnNode, 'IsCashTRNX');
            ft.OTPSent = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(txnNode, 'OTPSent'));
            ft.LOGIC_MOD = FEC_CommonUltils.getXmlValue(txnNode, 'LOGIC_MOD');

            result.Transactions.add(ft);
        }

        }

        return result;
    }

}