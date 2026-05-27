/****************************************************************************************
* File Name    : FEC_GetCardFinancialTransactions
* Author       : Quangdv7
* Date         : 2025-12-16
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2025-12-16     Quangdv7             Create
   1.1      2026-05-12     Agent                FinancialTransaction: MCC, TRNXCurrencyCode (+ XML fallbacks)
   1.2      2026-05-13     Agent                parseResponse: accept FinancialTransactions row nodes (host payload)
   1.3      2026-05-13     Agent                Find Transactions node with/without CIF namespace
   1.4      2026-05-13     Agent                Single 6-arg call entry; removed optional non-prod bypass overload
 
****************************************************************************************/
 
public with sharing class FEC_GetCardFinancialTransactions {
 
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
        /** Merchant category (sheet: MCC). */
        public String MCC;
        /** Currency on transaction (sheet: TRNXCurrencyCode). */
        public String TRNXCurrencyCode;
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

            validateRequest(transId, requestorId, dateTimeStr, accountNumber, fromDate,toDate);

            // ================= CONFIG =================
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Financial_Transaction');

            // =====================================================
            // ENV OVERRIDE 
            // =====================================================
            String accountNumberParam;
            Date fromDateParam;
            Date toDateParam;

            if (String.isNotBlank(apiSetting?.FEC_Enviroment__c)
                && apiSetting.FEC_Enviroment__c == FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION) {

                accountNumberParam = apiConfig?.FEC_Account_Number_Hard_Code__c;
                fromDateParam = apiConfig?.FEC_FromDate_Hard_Code__c;
                toDateParam =  apiConfig?.FEC_ToDate_Hard_Code__c;

            } else {
                accountNumberParam = accountNumber;
                fromDateParam = fromDate;
                toDateParam = toDate;
            }
            
            String soapBody = buildSoapBody(
                transId,
                requestorId,
                dateTimeStr,
                accountNumberParam,
                fromDateParam,
                toDateParam
            );
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CARD_FINANCIAL_TRANSACTION_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            
            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
                );
            }
 
            ResponseWrapper response = parseResponse(res.getBody());
 
            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }
            
            return response;
 
        } catch (Exception ex) {
            System.debug('### FIN TXN ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // BUILD SOAP REQUEST
    // =========================================================================
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        Date fromDate,
        Date toDate
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
            'xmlns:cif',
            'http://fecredit.com.vn/CIF_CardInfo'
        );
        
         // ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);
        
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        
        // ===== Main Action =====
        Dom.XmlNode action =
            body.addChildElement('ns1:GetCardFinancialTransactions', null, null);
        
        action.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/CIF_CardInfo'
        );

        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('AccountNumber', null, null)
              .addTextNode(accountNumber);

        if (fromDate != null) {
            action.addChildElement('FromDate', null, null)
                  .addTextNode(String.valueOf(fromDate));
        }
        
        if (toDate != null) {
            action.addChildElement('ToDate', null, null)
                  .addTextNode(String.valueOf(toDate));
        }

        return doc.toXmlString();
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
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr}));
        }
 
        // ===================== ACCOUNT NUMBER =====================
        if (String.isBlank(accountNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'}));
        }
        if (accountNumber.length() > 255) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'AccountNumber', '255'}));
        }
 
        // ===================== FROM DATE =====================
        if (fromDate != null) {
            try {
                String test = fromDate.format(); // YYYY-MM-DD
            } catch(Exception e) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{'FromDate', String.valueOf(fromDate)}));
            }
        }
 
        // ===================== TO DATE =====================
        if (toDate != null) {
            try {
                String test = toDate.format(); // YYYY-MM-DD
            } catch(Exception e) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Date_Format_Invalid, new List<String>{'ToDate', String.valueOf(toDate)}));
            }
 
            if (fromDate != null && toDate < fromDate) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_From_To_Invalid, new List<String>{'ToDate', 'FromDate'}));
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
 
        // ================= TRANSACTIONS =================
        result.Transactions = new List<FinancialTransaction>();

        Dom.XmlNode txnsNode = responseNode.getChildElement('Transactions', null);
        if (txnsNode == null) {
            txnsNode = FEC_CommonUltils.findChildByName(responseNode, 'Transactions');
        }
        if (txnsNode == null) {
            txnsNode = responseNode.getChildElement(
                'Transactions',
                'http://fecredit.com.vn/CIF_CardInfo'
            );
        }
        if (txnsNode != null) {

            for (Dom.XmlNode txnNode : txnsNode.getChildElements()) {

                if (!isFinancialTxnRowElement(txnNode)) {
                    continue;
                }

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
                ft.MCC = firstNonBlankFin(
                    FEC_CommonUltils.getXmlValue(txnNode, 'MCC'),
                    FEC_CommonUltils.getXmlValue(txnNode, 'MerchantCategoryCode')
                );
                ft.TRNXCurrencyCode = firstNonBlankFin(
                    FEC_CommonUltils.getXmlValue(txnNode, 'TRNXCurrencyCode'),
                    FEC_CommonUltils.getXmlValue(txnNode, 'CurrencyCode'),
                    FEC_CommonUltils.getXmlValue(txnNode, 'TRNX_Currency_Code')
                );

                result.Transactions.add(ft);
            }
        }

        return result;
    }

    /** Host may send {@code Transaction} or {@code FinancialTransactions} per row under Transactions. */
    private static Boolean isFinancialTxnRowElement(Dom.XmlNode n) {
        if (n == null) {
            return false;
        }
        String nm = n.getName();
        if (String.isBlank(nm)) {
            return false;
        }
        Integer colon = nm.indexOf(':');
        if (colon >= 0) {
            nm = nm.substring(colon + 1);
        }
        return nm.equalsIgnoreCase('Transaction')
            || nm.equalsIgnoreCase('FinancialTransactions');
    }

    private static String firstNonBlankFin(String a, String b) {
        if (!String.isBlank(a)) {
            return a.trim();
        }
        if (!String.isBlank(b)) {
            return b.trim();
        }
        return null;
    }

    private static String firstNonBlankFin(String a, String b, String c) {
        String ab = firstNonBlankFin(a, b);
        if (!String.isBlank(ab)) {
            return ab;
        }
        if (!String.isBlank(c)) {
            return c.trim();
        }
        return null;
    }
}