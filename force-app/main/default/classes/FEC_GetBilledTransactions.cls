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
            
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Billed_Transaction');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_BILLED_TRANSACTION_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

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
        Set<String> validRequestorIds = new Set<String>{FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP};
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