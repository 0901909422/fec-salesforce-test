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

     
    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/EStatementService';
    private static final String MOCKUP_ENDPOINT = 'https://fa889db0-0d70-4ff0-a772-7a7fc2347c26.mock.pstmn.io';


    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public AccountRecord Account;
        public List<TransactionRecord> Transactions;
        public List<LoanRecord> Loans;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
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
        try {

            validateRequest(transID, requestorId, dateTimeStr, accountNumber, statementMonth);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);

            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://esbservice.fecredit.org/EStatementService/GetBilledTransactions');

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<est:GetAccountDetails>' +
                            '<est:SysRequest>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</est:SysRequest>' +
                            '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                            '<StatementMonth>' + statementMonth + '</StatementMonth>' +
                        '</est:GetAccountDetails>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetBilledTransactions service returned HTTP error: ' + res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetBilledTransactions service returned error'
                );
            }
            
            return response;

        } catch (Exception ex) {
            System.debug('### BILLED TXN ERROR: ' + ex.getMessage());
            throw ex;
        }
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
        if (String.isBlank(transID)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (transID.length() > 36) {
            throw new CalloutException('TransID is null or invalid or no longer than 36 characters');
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{'CRM','PORTAL','MOBILE_APP'};
        if (String.isBlank(requestorId) || !validRequestorIds.contains(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid "' + requestorId + '" is not type of RequestorID');
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException('DateTime is null or invalid "' + dateTimeStr + '" is not type of Datetime');
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

        // ===================== STATEMENT MONTH =====================
        if (String.isBlank(statementMonth)) {
            throw new CalloutException('StatementMonth is null or invalid or must have format MM/YYYY');
        }
    
        Pattern p = Pattern.compile('^(0[1-9]|1[0-2])/\\d{4}$');
        if (!p.matcher(statementMonth).matches()) {
            throw new CalloutException('StatementMonth is null or invalid or must have format MM/YYYY');
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
            envelope.getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

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
            result.Sys.TransID = getVal(sysNode, 'TransID');
            result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
            result.Sys.Code = toInteger(getVal(sysNode, 'Code'));
            result.Sys.Description = getVal(sysNode, 'Description');
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
        a.AccountNumber = getVal(acc, 'AccountNumber');
        a.AccountStatus = getVal(acc, 'AccountStatus');
        a.CustomerName = getVal(acc, 'CustomerName');
        a.CreditLimit = getDec(acc, 'CreditLimit');
        a.CurrentBalance = getDec(acc, 'CurrentBalance');
        a.AvailableCredit = getDec(acc, 'AvailableCredit');
        a.CashLimit = getDec(acc, 'CashLimit');
        a.AvailableCashLimit = getDec(acc, 'AvailableCashLimit');
        a.LastStatementDate = getVal(acc, 'LastStatementDate');
        a.MinimumPaymentDue = getDec(acc, 'MinimumPaymentDue');
        a.PaymentDueDate = getVal(acc, 'PaymentDueDate');
        a.DateLastPayment = getVal(acc, 'DateLastPayment');
        a.EmailAddress = getVal(acc, 'EmailAddress');
        return a;
    }

    private static List<TransactionRecord> parseTransactions(Dom.XmlNode node) {
        List<TransactionRecord> txns = new List<TransactionRecord>();
        if (node == null) return txns;

        for (Dom.XmlNode txn : node.getChildElements()) {
            TransactionRecord t = new TransactionRecord();
            t.TransactionDate = getVal(txn, 'TransactionDate');
            t.PostingDate = getVal(txn, 'PostingDate');
            t.Description = getVal(txn, 'Description');
            t.Amount = getDec(txn, 'Amount');
            t.CurrencyCode = getVal(txn, 'Currency');
            t.ReferenceNumber = getVal(txn, 'ReferenceNumber');
            t.TransactionType = getVal(txn, 'TransactionType');
            t.MerchantName = getVal(txn, 'MerchantName');
            t.MCC = getVal(txn, 'MCC');
            t.Location = getVal(txn, 'Location');
            txns.add(t);
        }
        return txns;
    }

    private static List<LoanRecord> parseLoans(Dom.XmlNode node) {
        List<LoanRecord> loans = new List<LoanRecord>();
        if (node == null) return loans;

        for (Dom.XmlNode ln : node.getChildElements()) {
            LoanRecord l = new LoanRecord();
            l.LoanNumber = getVal(ln, 'LoanNumber');
            l.OutstandingAmount = getDec(ln, 'OutstandingAmount');
            loans.add(l);
        }
        return loans;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode node, String name) {
        if (node == null) return null;
        Dom.XmlNode c = node.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Decimal getDec(Dom.XmlNode node, String name) {
        String v = getVal(node, name);
        return String.isBlank(v) ? null : Decimal.valueOf(v);
    }

    private static Integer toInteger(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }
}