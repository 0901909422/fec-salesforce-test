/****************************************************************************************
* File Name    : FEC_GetAccountDetails
* Author       : Auto-generated
* Date         : 2026-06-16
* Description  : GetAccountDetails SOAP API (EStatementService)
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-06-16       linhdev                  Create
 
****************************************************************************************/

public with sharing class FEC_GetAccountDetails {

    public static final String API_CONFIG_NAME = 'FEC_Get_Account_Details';
    private static final String SERVICE_NS = 'http://esbservice.fecredit.org/EStatementService/';
    private static final Integer TENURE_STEP_MONTHS = 3;

    private static FEC_ResponseLog responseLog;

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetAccountDetails(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        try {

            validateRequest(transId, requestorId, dateTimeStr, accountNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            String accountNumberParam = String.isNotBlank(accountNumber)
                ? accountNumber.trim()
                : accountNumber;

            String soapBody = buildSoapBody(
                transId,
                requestorId,
                dateTimeStr,
                accountNumberParam
            );

            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                apiConfig?.FEC_SOAP_Action__c,
                null,
                soapBody
            );

            responseLog = new FEC_ResponseLog(
                'FEC_GetAccountDetails',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapBody,
                res,
                null
            );

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{ res.getStatusCode().toString() })
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys != null && response.Sys.Status != 0) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{ response.Sys.Description })
                );
            }

            return response;

        } catch (Exception ex) {
            if (responseLog != null) {
                responseLog.errorMessage = ex.getMessage();
            }
            System.debug('### GET ACCOUNT DETAILS ERROR: ' + ex.getMessage());
            throw ex;
        } finally {
            logApiResponse();
        }
    }

    @AuraEnabled
    public static ResponseWrapper getAccountDetails(String accountNumber) {
        return callGetAccountDetails(
            FEC_CommonUltils.generateTransactionId(),
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            FEC_CommonUltils.formatTransferCallRequestDateTime(Datetime.now()),
            accountNumber
        );
    }

    public static void logApiResponse() {
        FEC_CommonUltils.logApiResponse(responseLog);
        responseLog = null;
    }

    /**
     * Tenure Logic: danh sách kỳ hạn từ MinTenure đến MaxTenure, bước nhảy 3 tháng.
     */
    public static List<Integer> buildTenureList(Integer minTenure, Integer maxTenure) {
        List<Integer> tenures = new List<Integer>();
        if (minTenure == null || maxTenure == null || minTenure > maxTenure) {
            return tenures;
        }
        for (Integer tenure = minTenure; tenure <= maxTenure; tenure += TENURE_STEP_MONTHS) {
            tenures.add(tenure);
        }
        return tenures;
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
            SERVICE_NS
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('ns1:GetAccountDetails', null, null);

        Dom.XmlNode sys =
            action.addChildElement('ns1:SysRequest', null, null);

        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('AccountNumber', null, null)
              .addTextNode(accountNumber);

        action.addChildElement('IPPAvailabilityCheck', null, null)
              .addTextNode('true');

        return doc.toXmlString();
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        if (String.isBlank(accountNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'AccountNumber' }));
        }

        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP,
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN,
            FEC_ConstantCommon.REQUESTOR_PEGA_CSM,
            FEC_ConstantCommon.REQUESTOR_PEGA
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }

        if (accountNumber.length() > 255) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{ 'AccountNumber', '255' })
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
        if (envelope == null) {
            return result;
        }

        Dom.XmlNode bodyNode =
            FEC_CommonUltils.findChildByName(envelope, 'Body');
        if (bodyNode == null) {
            return result;
        }

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }
        if (responseNode == null) {
            return result;
        }

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

        result.UnbilledTransactionView =
            FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(responseNode, 'UnbilledTransactionView'));
        result.BilledTransactionView =
            FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(responseNode, 'BilledTransactionView'));

        Dom.XmlNode accountRecordsNode =
            FEC_CommonUltils.findChildByName(responseNode, 'AccountRecords');
        if (accountRecordsNode != null) {
            Dom.XmlNode accountRecordNode =
                FEC_CommonUltils.findChildByName(accountRecordsNode, 'AccountRecord');
            if (accountRecordNode != null) {
                result.Account = parseAccountRecord(accountRecordNode);
            }
        }

        Dom.XmlNode txnRecords =
            FEC_CommonUltils.findChildByName(responseNode, 'TransactionRecords');
        if (txnRecords != null) {
            for (Dom.XmlNode txn : txnRecords.getChildElements()) {
                if (!txn.getName().equalsIgnoreCase('TransactionRecord')) {
                    continue;
                }
                TransactionRecord tr = new TransactionRecord();
                tr.TransactionDate = FEC_CommonUltils.getValueSafe(txn, 'TransactionDate');
                tr.PostingDate = FEC_CommonUltils.getValueSafe(txn, 'PostingDate');
                tr.Description = FEC_CommonUltils.getValueSafe(txn, 'Description');
                tr.Amount = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(txn, 'Amount'));
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

    private static AccountRecord parseAccountRecord(Dom.XmlNode accountRecordNode) {
        AccountRecord account = new AccountRecord();
        account.AccountNumber = FEC_CommonUltils.getValueSafe(accountRecordNode, 'AccountNumber');
        account.AccountStatus = FEC_CommonUltils.getValueSafe(accountRecordNode, 'AccountStatus');
        account.CustomerName = FEC_CommonUltils.getValueSafe(accountRecordNode, 'CustomerName');
        account.CreditLimit = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'CreditLimit'));
        account.CurrentBalance = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'CurrentBalance'));
        account.AvailableCredit = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'AvailableCredit'));
        account.CashLimit = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'CashLimit'));
        account.AvailableCashLimit = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'AvailableCashLimit'));
        account.LastStatementDate = FEC_CommonUltils.getValueSafe(accountRecordNode, 'LastStatementDate');
        account.MinimumPaymentDue = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'MinimumPaymentDue'));
        account.PaymentDueDate = FEC_CommonUltils.getValueSafe(accountRecordNode, 'PaymentDueDate');
        account.DateLastPayment = FEC_CommonUltils.getValueSafe(accountRecordNode, 'DateLastPayment');
        account.EmailAddress = FEC_CommonUltils.getValueSafe(accountRecordNode, 'EmailAddress');
        account.OpeningPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'OpeningPoints'));
        account.ClosingPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'ClosingPoints'));
        account.RewardPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'RewardPoints'));
        account.RedeemedPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'RedeemedPoints'));
        account.EarnedPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'EarnedPoints'));
        account.BonusPoints = FEC_CommonUltils.parseAmountSafe(FEC_CommonUltils.getValueSafe(accountRecordNode, 'BonusPoints'));
        account.IPPEligibilityFlag = FEC_CommonUltils.getValueSafe(accountRecordNode, 'IPPEligibilityFlag');

        Dom.XmlNode retailIppNode =
            FEC_CommonUltils.findChildByName(accountRecordNode, 'RetailIPPInfo');
        if (retailIppNode != null) {
            account.RetailIPPInfo = new IPPInfo();
            account.RetailIPPInfo.PlanNumber = FEC_CommonUltils.getValueSafe(retailIppNode, 'PlanNumber');
            account.RetailIPPInfo.InterestRate =
                FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(retailIppNode, 'InterestRate'));
        }

        Dom.XmlNode cashIppNode =
            FEC_CommonUltils.findChildByName(accountRecordNode, 'CashIPPInfo');
        if (cashIppNode != null) {
            account.CashIPPInfo = new CashIPPInfo();
            account.CashIPPInfo.PlanNumber = FEC_CommonUltils.getValueSafe(cashIppNode, 'PlanNumber');
            account.CashIPPInfo.InterestRate =
                FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(cashIppNode, 'InterestRate'));
            account.CashIPPInfo.MinTenure =
                FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(cashIppNode, 'MinTenure'));
            account.CashIPPInfo.MaxTenure =
                FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(cashIppNode, 'MaxTenure'));
            account.CashIPPInfo.TenureList = buildTenureList(
                account.CashIPPInfo.MinTenure,
                account.CashIPPInfo.MaxTenure
            );
        }

        return account;
    }

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        @AuraEnabled public SysResponse Sys;
        @AuraEnabled public Integer UnbilledTransactionView;
        @AuraEnabled public Integer BilledTransactionView;
        @AuraEnabled public AccountRecord Account;
        @AuraEnabled public List<TransactionRecord> Transactions;
    }

    public class SysResponse {
        @AuraEnabled public String TransID;
        @AuraEnabled public String DateTimeStr;
        @AuraEnabled public Integer Status;
        @AuraEnabled public String Description;
    }

    public class AccountRecord {
        @AuraEnabled public String AccountNumber;
        @AuraEnabled public String AccountStatus;
        @AuraEnabled public String CustomerName;
        @AuraEnabled public Decimal CreditLimit;
        @AuraEnabled public Decimal CurrentBalance;
        @AuraEnabled public Decimal AvailableCredit;
        @AuraEnabled public Decimal CashLimit;
        @AuraEnabled public Decimal AvailableCashLimit;
        @AuraEnabled public String LastStatementDate;
        @AuraEnabled public Decimal MinimumPaymentDue;
        @AuraEnabled public String PaymentDueDate;
        @AuraEnabled public String DateLastPayment;
        @AuraEnabled public String EmailAddress;
        @AuraEnabled public Decimal OpeningPoints;
        @AuraEnabled public Decimal ClosingPoints;
        @AuraEnabled public Decimal RewardPoints;
        @AuraEnabled public Decimal RedeemedPoints;
        @AuraEnabled public Decimal EarnedPoints;
        @AuraEnabled public Decimal BonusPoints;
        @AuraEnabled public String IPPEligibilityFlag;
        @AuraEnabled public IPPInfo RetailIPPInfo;
        @AuraEnabled public CashIPPInfo CashIPPInfo;
    }

    public class IPPInfo {
        @AuraEnabled public String PlanNumber;
        @AuraEnabled public Integer InterestRate;
    }

    public class CashIPPInfo {
        @AuraEnabled public String PlanNumber;
        @AuraEnabled public Integer InterestRate;
        @AuraEnabled public Integer MinTenure;
        @AuraEnabled public Integer MaxTenure;
        @AuraEnabled public List<Integer> TenureList;
    }

    public class TransactionRecord {
        @AuraEnabled public String TransactionDate;
        @AuraEnabled public String PostingDate;
        @AuraEnabled public String Description;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String CurrencyCode;
        @AuraEnabled public String ReferenceNumber;
        @AuraEnabled public String TransactionType;
        @AuraEnabled public String MerchantName;
        @AuraEnabled public String MCC;
        @AuraEnabled public String Location;
    }
}
