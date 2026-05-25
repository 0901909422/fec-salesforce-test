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
            
            // ================= CONFIG =================
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Unbilled_Transaction');

            // =====================================================
            // ENV OVERRIDE 
            // =====================================================
            String accountNumberParam;

            if (String.isNotBlank(apiSetting?.FEC_Enviroment__c)
                && apiSetting.FEC_Enviroment__c == FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION) {

                accountNumberParam = apiConfig?.FEC_Account_Number_Hard_Code__c;

            } else {
                accountNumberParam = accountNumber;
            }
            
            // ================= SOAP REQUEST BODY =================
            String soapBody = buildSoapBody(
                transId, 
                requestorId, 
                dateTimeStr, 
                accountNumberParam
                );
            
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_UNBILLED_TRANSACTION_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            
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
 
        } catch (Exception ex) {
            System.debug('### UNBILLED TXN ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    /* =====================================================
       SOAP BODY
       ===================================================== */
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        Dom.Document doc = new Dom.Document();
    
        // ===== Create Envelope WITHOUT namespace param =====
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            null,
            null
        );
    
        // ===== Manually bind namespaces =====
        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );
    
        envelope.setAttribute(
            'xmlns:ns1',
            'http://esbservice.fecredit.org/EStatementService/'
        );
    
        // ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);
    
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
    
        // ===== Main Action =====
        Dom.XmlNode action =
            body.addChildElement('ns1:GetUnbilledTransactions', null, null);
    
        // ===== SysRequest =====
        Dom.XmlNode sys =
            action.addChildElement('ns1:SysRequest', null, null);
    
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);
    
        // ===== AccountNumber =====
        action.addChildElement('AccountNumber', null, null)
              .addTextNode(accountNumber);
    
        // ===== IPPAvailabilityCheck =====
        action.addChildElement('IPPAvailabilityCheck', null, null)
              .addTextNode('true');
    
        return doc.toXmlString();
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
        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        if (String.isBlank(accountNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'}));
        }
 
        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
 
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr})
            );
        }
 
        if (accountNumber.length() > 255) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'AccountNumber', '255'})
            );
        }
 
    }
 
    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        ResponseWrapper result = new ResponseWrapper();
        result.Transactions = new List<TransactionRecord>();

        if (String.isBlank(xml)) {
            return result;
        }

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        if (envelope == null) return result;

        Dom.XmlNode bodyNode =
            FEC_CommonUltils.findChildByName(envelope, 'Body');
        if (bodyNode == null) return result;

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }
        if (responseNode == null) return result;

        // ===== SYS RESPONSE =====
        Dom.XmlNode sysNode =
            FEC_CommonUltils.findChildByName(responseNode, 'SysResponse');

        if (sysNode != null) {

            result.Sys = new SysResponse();

            result.Sys.TransID = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
            result.Sys.Status =
                FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Status'));
            result.Sys.Description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
        }

        // ===== TRANSACTIONS =====
        Dom.XmlNode txnRecords =
            FEC_CommonUltils.findChildByName(responseNode, 'TransactionRecords');

        if (txnRecords != null) {
            for (Dom.XmlNode txn : txnRecords.getChildElements()) {
                TransactionRecord tr = new TransactionRecord();
                String rawAmount = FEC_CommonUltils.getValueSafe(txn, 'Amount');

                tr.TransactionDate = FEC_CommonUltils.getValueSafe(txn, 'TransactionDate');
                tr.PostingDate = FEC_CommonUltils.getValueSafe(txn, 'PostingDate');
                tr.Description = FEC_CommonUltils.getValueSafe(txn, 'Description');
                tr.Amount = FEC_CommonUltils.parseAmountSafe(rawAmount);
                tr.CurrencyCode = FEC_CommonUltils.getValueSafe(txn, 'CurrencyCode');
                tr.ReferenceNumber = FEC_CommonUltils.getValueSafe(txn, 'ReferenceNumber');
                tr.TransactionType = FEC_CommonUltils.getValueSafe(txn, 'TransactionType');
                tr.MerchantName = FEC_CommonUltils.getValueSafe(txn, 'MerchantName');
                tr.MCC = FEC_CommonUltils.getValueSafe(txn, 'MCC');
                tr.Location = FEC_CommonUltils.getValueSafe(txn, 'Location');

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
        public Integer Status;
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