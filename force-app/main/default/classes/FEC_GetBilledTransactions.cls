/****************************************************************************************
 * File Name    : FEC_GetBilledTransactions
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetBilledTransactions {

    private static final String ENDPOINT = '/EStatementService';
    private static final String MOCKUP_ENDPOINT =
        'https://ffc810e2-9dcf-4d66-a26a-91b8eeb7dbc9.mock.pstmn.io';

    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public AccountRecord Account;
        public List<TransactionRecord> Transactions;
        public List<LoanRecord> Loans;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Status;
        public String Description;
    }

    public class AccountRecord {
        public String AccountNumber;
        public String AccountStatus;
        public String CustomerName;
        public Decimal CreditLimit;
        public Decimal CurrentBalance;
        public Decimal AvailableCredit;
        public Decimal CashLimit;
        public Decimal AvailableCashLimit;
        public String LastStatementDate;
        public Decimal MinimumPaymentDue;
        public String PaymentDueDate;
        public String DateLastPayment;
        public String EmailAddress;
    }

    public class TransactionRecord {
        public String TransactionDate;
        public String PostingDate;
        public String Description;
        public Decimal Amount;
        public String CurrencyCode; 
        public String ReferenceNumber;
        public String TransactionType;
        public String MerchantName;
        public String MCC;
        public String Location;
    }

    public class LoanRecord {
        public String LoanNumber;
        public Decimal OutstandingAmount;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetBilledTransactions(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        String statementMonth
    ) {

        validateRequest(transID, requestorId, dateTimeStr, accountNumber, statementMonth);
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setEndpoint(
            apiSetting?.FEC_Call_Mock__c
                ? MOCKUP_ENDPOINT
                : apiSetting.FEC_Endpoint__c + ENDPOINT
        );
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://esbservice.fecredit.org/EStatementService/GetBilledTransactions'
        );

        req.setBody(
            buildSoapBody(
                transID,
                requestorId,
                dateTimeStr,
                accountNumber,
                statementMonth
            )
        );

        Http http = new Http();
        HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys != null && response.Sys.Status != 0) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }

        return response;
    }

    /* =====================================================
       SOAP BODY (DOM – SAFE)
       ===================================================== */
    private static String buildSoapBody(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        String statementMonth
    ) {

        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );

        envelope.setAttribute(
            'xmlns:est',
            'http://esbservice.fecredit.org/EStatementService/'
        );

        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('est:GetAccountDetails', null, null);

        Dom.XmlNode sys =
            action.addChildElement('est:SysRequest', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('AccountNumber', null, null)
              .addTextNode(accountNumber);

        action.addChildElement('StatementMonth', null, null)
              .addTextNode(statementMonth);

        return doc.toXmlString();
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        String statementMonth
    ) {

        // ===================== TRANSID =====================
        if (String.isBlank(transID) || transID.length() > 36) {
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
        
        // ===================== STATEMENT MONTH =====================
        if (String.isBlank(statementMonth)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'StatementMonth'}));
        }
    
        Pattern p = Pattern.compile(FEC_ConstantCommon.PATTERN_DATE_FORMAT_MMYYYY);
        if (!p.matcher(statementMonth).matches()) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Format_Invalid, new List<String>{'StatementMonth', FEC_ConstantCommon.DATE_FORMAT_MMYYYY}));
        }
    }

    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {
        System.debug('XML RAW >>>' + xml);
        
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

        // -------- SYS RESPONSE --------
        Dom.XmlNode sysNode = responseNode.getChildElement('SysResponse', null);
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // -------- ACCOUNT RECORD --------
        Dom.XmlNode accountRecords = responseNode.getChildElement('AccountRecords', null);
        if (accountRecords != null) {
            Dom.XmlNode acc = accountRecords.getChildElement('AccountRecord', null);
            if (acc != null) {
                result.Account = parseAccount(acc);
            }
        }

        // -------- TRANSACTIONS --------
        result.Transactions = parseTransactions(
            responseNode.getChildElement('TransactionRecords', null)
        );

        // -------- LOANS --------
        result.Loans = parseLoans(
            responseNode.getChildElement('LoanRecords', null)
        );

        return result;
    }

    // =========================================================================
    // PARSERS
    // =========================================================================
    private static AccountRecord parseAccount(Dom.XmlNode acc) {
        AccountRecord a = new AccountRecord();
        a.AccountNumber = FEC_CommonUltils.getXmlValue(acc, 'AccountNumber');
        a.AccountStatus = FEC_CommonUltils.getXmlValue(acc, 'AccountStatus');
        a.CustomerName = FEC_CommonUltils.getXmlValue(acc, 'CustomerName');
        a.CreditLimit = FEC_CommonUltils.xmlValToDecimal(acc, 'CreditLimit');
        a.CurrentBalance = FEC_CommonUltils.xmlValToDecimal(acc, 'CurrentBalance');
        a.AvailableCredit = FEC_CommonUltils.xmlValToDecimal(acc, 'AvailableCredit');
        a.CashLimit = FEC_CommonUltils.xmlValToDecimal(acc, 'CashLimit');
        a.AvailableCashLimit = FEC_CommonUltils.xmlValToDecimal(acc, 'AvailableCashLimit');
        a.LastStatementDate = FEC_CommonUltils.getXmlValue(acc, 'LastStatementDate');
        a.MinimumPaymentDue = FEC_CommonUltils.xmlValToDecimal(acc, 'MinimumPaymentDue');
        a.PaymentDueDate = FEC_CommonUltils.getXmlValue(acc, 'PaymentDueDate');
        a.DateLastPayment = FEC_CommonUltils.getXmlValue(acc, 'DateLastPayment');
        a.EmailAddress = FEC_CommonUltils.getXmlValue(acc, 'EmailAddress');
        return a;
    }

    private static List<TransactionRecord> parseTransactions(Dom.XmlNode node) {
        List<TransactionRecord> txns = new List<TransactionRecord>();
        if (node == null) return txns;

        for (Dom.XmlNode txn : node.getChildElements()) {
            TransactionRecord t = new TransactionRecord();
            t.TransactionDate = FEC_CommonUltils.getXmlValue(txn, 'TransactionDate');
            t.PostingDate = FEC_CommonUltils.getXmlValue(txn, 'PostingDate');
            t.Description = FEC_CommonUltils.getXmlValue(txn, 'Description');
            t.Amount = FEC_CommonUltils.xmlValToDecimal(txn, 'Amount');
            t.CurrencyCode = FEC_CommonUltils.getXmlValue(txn, 'Currency');
            t.ReferenceNumber = FEC_CommonUltils.getXmlValue(txn, 'ReferenceNumber');
            t.TransactionType = FEC_CommonUltils.getXmlValue(txn, 'TransactionType');
            t.MerchantName = FEC_CommonUltils.getXmlValue(txn, 'MerchantName');
            t.MCC = FEC_CommonUltils.getXmlValue(txn, 'MCC');
            t.Location = FEC_CommonUltils.getXmlValue(txn, 'Location');
            txns.add(t);
        }
        return txns;
    }

    private static List<LoanRecord> parseLoans(Dom.XmlNode node) {
        List<LoanRecord> loans = new List<LoanRecord>();
        if (node == null) return loans;

        for (Dom.XmlNode ln : node.getChildElements()) {
            LoanRecord l = new LoanRecord();
            l.LoanNumber = FEC_CommonUltils.getXmlValue(ln, 'LoanNumber');
            l.OutstandingAmount = FEC_CommonUltils.xmlValToDecimal(ln, 'OutstandingAmount');
            loans.add(l);
        }
        return loans;
    }

}