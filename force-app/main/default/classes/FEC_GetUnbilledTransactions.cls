/****************************************************************************************
 * File Name    : FEC_GetUnbilledTransactions
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetUnbilledTransactions {

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/EStatementService';
    private static final String MOCKUP_ENDPOINT = 'https://82338791-908c-4531-95b3-3d8e5ab19fe7.mock.pstmn.io';

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetUnbilledTransactions(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        try {

            validateRequest(transID, requestorId, dateTimeStr, accountNumber);
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);

            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://esbservice.fecredit.org/EStatementService/GetUnbilledTransactions');

            // ================= SOAP REQUEST BODY =================
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:est="http://esbservice.fecredit.org/EStatementService/">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<est:GetUnbilledTransactions>' +
                            '<est:SysRequest>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</est:SysRequest>' +
                            '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                        '</est:GetUnbilledTransactions>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetUnbilledTransactions service returned HTTP error: ' + res.getStatusCode()
                );
            }

             ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetUnbilledTransactions service returned error'
                );
            }
            
            return response;

        } catch (Exception ex) {
            System.debug('### UNBILLED TXN ERROR: ' + ex.getMessage());
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
        String accountNumber
    ) {
        if (String.isBlank(transID)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid');
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        if (String.isBlank(accountNumber)) {
            throw new CalloutException('AccountNumber is null or invalid');
        }

        if (transID.length() > 36) {
            throw new CalloutException(
                'TransID is null or invalid or no longer than 36 characters'
            );
        }

        Set<String> validRequestorIds = new Set<String>{
            'CRM',
            'PORTAL',
            'MOBILE_APP'
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid, "' + requestorId + '" is not type of RequestorID');
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime is null or invalid, "' + dateTimeStr + '" is not type of Datetime'
            );
        }

        if (accountNumber.length() > 255) {
            throw new CalloutException(
                'AccountNumber is null or invalid or no longer than 255 characters'
            );
        }

        Boolean accountExists = true;
        if (!accountExists) {
            throw new CalloutException(
                'AccountNumber is null or invalid or no longer than 255 characters'
            );
        }
    }

    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode = envelope.getChildElement(
            'Body',
            'http://schemas.xmlsoap.org/soap/envelope/'
        );

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ================= SYS RESPONSE =================
        Dom.XmlNode sysNode = responseNode.getChildElement('SysResponse', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = getVal(sysNode, 'TransID');
        result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
        result.Sys.Code = toInteger(getVal(sysNode, 'Code'));
        result.Sys.Description = getVal(sysNode, 'Description');

        // ================= TRANSACTION RECORDS =================
        result.Transactions = new List<TransactionRecord>();
        Dom.XmlNode txnRecords = responseNode.getChildElement('TransactionRecords', null);
        if (txnRecords != null) {
            for (Dom.XmlNode txn : txnRecords.getChildElements()) {
                TransactionRecord tr = new TransactionRecord();
                tr.TransactionDate = getVal(txn, 'TransactionDate');
                tr.PostingDate = getVal(txn, 'PostingDate');
                tr.Description = getVal(txn, 'Description');
                tr.Amount = getDec(txn, 'Amount');
                tr.CurrencyCode = getVal(txn, 'Number'); // Updated field name
                tr.ReferenceNumber = getVal(txn, 'ReferenceNumber');
                tr.TransactionType = getVal(txn, 'TransactionType');
                tr.MerchantName = getVal(txn, 'MerchantName');
                tr.MCC = getVal(txn, 'MCC');
                tr.Location = getVal(txn, 'Location');
                result.Transactions.add(tr);
            }
        }

        return result;
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

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public List<TransactionRecord> Transactions;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
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
}