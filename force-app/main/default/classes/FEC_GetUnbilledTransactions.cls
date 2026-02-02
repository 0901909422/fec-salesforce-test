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

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Unbilled_Transaction');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_UNBILLED_TRANSACTION_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

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
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
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
            FEC_ConstantCommon.SOAP_ENV
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
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // ================= TRANSACTION RECORDS =================
        result.Transactions = new List<TransactionRecord>();
        Dom.XmlNode txnRecords = responseNode.getChildElement('TransactionRecords', null);
        if (txnRecords != null) {
            for (Dom.XmlNode txn : txnRecords.getChildElements()) {
                TransactionRecord tr = new TransactionRecord();
                tr.TransactionDate = FEC_CommonUltils.getXmlValue(txn, 'TransactionDate');
                tr.PostingDate = FEC_CommonUltils.getXmlValue(txn, 'PostingDate');
                tr.Description = FEC_CommonUltils.getXmlValue(txn, 'Description');
                tr.Amount = FEC_CommonUltils.xmlValToDecimal(txn, 'Amount');
                tr.CurrencyCode = FEC_CommonUltils.getXmlValue(txn, 'Number'); // Updated field name
                tr.ReferenceNumber = FEC_CommonUltils.getXmlValue(txn, 'ReferenceNumber');
                tr.TransactionType = FEC_CommonUltils.getXmlValue(txn, 'TransactionType');
                tr.MerchantName = FEC_CommonUltils.getXmlValue(txn, 'MerchantName');
                tr.MCC = FEC_CommonUltils.getXmlValue(txn, 'MCC');
                tr.Location = FEC_CommonUltils.getXmlValue(txn, 'Location');
                result.Transactions.add(tr);
            }
        }

        return result;
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