/****************************************************************************************
* File Name    : FEC_GetCardBasicInfo
* Author       : Quangdv7
* Date         : 2025-12-16
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/
 
public with sharing class FEC_GetCardBasicInfo {
 
    public static FEC_ResponseLog responseLog;
    public static Boolean isExecuteLog = false;

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        @AuraEnabled public SysResponse Sys;
        @AuraEnabled public CardBasicInfo CardBasicInfo;
    }

    public class SysResponse {
        @AuraEnabled public String TransID;
        @AuraEnabled public String DateTimeStr;
        @AuraEnabled public Integer Code;
        @AuraEnabled public String Description;
    }

    public class CardBasicInfo {
        @AuraEnabled public MainCard MainCard;
        @AuraEnabled public StatementInfo Statement;
        @AuraEnabled public PassDue PassDUE;
        @AuraEnabled public List<StatementPeriod> Statements;
        @AuraEnabled public List<TransactionInfo> Transactions;
        @AuraEnabled public CardHistories CardHistories;
    }

    public class CardHistories {
        @AuraEnabled public List<CardHistory> CardHistory;
    }

    public class MainCard {
        @AuraEnabled public String Product;
        @AuraEnabled public String CustomerSegment;
        @AuraEnabled public String PlasticIndicator;
        @AuraEnabled public String ProductAssociation;
        @AuraEnabled public String Status;
        @AuraEnabled public String IPPFlag;
        @AuraEnabled public String InsuranceFlag;
        @AuraEnabled public String ContractNumber;
        @AuraEnabled public String AccountNumber;
        @AuraEnabled public String SecurityAnswer;
        @AuraEnabled public Date ExpiryDate;
        @AuraEnabled public Integer BillingCycle;
        @AuraEnabled public String ActivatedFlag;
        @AuraEnabled public String BlockCode1;
        @AuraEnabled public String BlockCode2;
        @AuraEnabled public String WarningCode;
        @AuraEnabled public Decimal OTB;
        @AuraEnabled public Decimal HoldAmount;
        @AuraEnabled public Decimal CreditLimit;
        @AuraEnabled public Date PaymentDate;
        @AuraEnabled public Decimal LastPaymentAmount;
        @AuraEnabled public String MaskedCardNumber;
        @AuraEnabled public String PaymentHoliday;
        @AuraEnabled public String DigitalCardIndicator;
        @AuraEnabled public String RsnBlockCode1;
        @AuraEnabled public String RsnBlockCode2;
        @AuraEnabled public Date AccountBlockCode1Date;
        @AuraEnabled public Date AccountBlockCode2Date;
        @AuraEnabled public String WarningCode360;
        @AuraEnabled public String MailingInd;
        @AuraEnabled public Decimal LoanBalance;
        @AuraEnabled public String CardNumber;
        @AuraEnabled public String CardActivationDate;
        @AuraEnabled public String BlockCode;
        @AuraEnabled public Date BlckDate;
    }

    public class StatementInfo {
        @AuraEnabled public Decimal StatementBalance;
        @AuraEnabled public Date LastStatementDate;
        @AuraEnabled public Date NextStatementDate;
        @AuraEnabled public Date LastStatementDueDate;
        @AuraEnabled public Decimal LastStatementMPA;
    }

    public class PassDue {
        @AuraEnabled public Integer DPD;
    }

    public class StatementPeriod {
        @AuraEnabled public Decimal BalanceBegin;
        @AuraEnabled public Decimal BalanceEnd;
        @AuraEnabled public Decimal MPA;
        @AuraEnabled public Date StatementDate;
    }

    public class TransactionInfo {
        @AuraEnabled public Datetime TRNXDateTime;
        @AuraEnabled public String Description;
        @AuraEnabled public String CreditDebitFlag;
        @AuraEnabled public String TransactionType;
        @AuraEnabled public String Status;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String TransactionCode;
        @AuraEnabled public Decimal Fee;
        @AuraEnabled public Date PostingDate;
        @AuraEnabled public Date SettlementDate;
        @AuraEnabled public String Plan;
        @AuraEnabled public String RRN;
        @AuraEnabled public String MerchantName;
        @AuraEnabled public String PaymentFlag;
        @AuraEnabled public String IsCashTRNX;
        @AuraEnabled public String PlanType;
        @AuraEnabled public String LogicMod;
        @AuraEnabled public Integer OTPSent;
    }

    public class CardHistory {
        @AuraEnabled public String CardNumber;
        @AuraEnabled public String EmbossingName;
        @AuraEnabled public String ActivationDate;
        @AuraEnabled public String CardIssueDate;
        @AuraEnabled public String CardExpDate;
        @AuraEnabled public Date CardActivationDate;
    }
 
    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetCardBasicInfo(
        String transID,    
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        try {
 
            validateRequest(transID, requestorId, dateTimeStr, accountNumber);
 
            String soapBody = buildSoapBody(
                transID,
                requestorId,
                dateTimeStr,
                accountNumber
            );
 
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Basic_Info');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CARD_BASIC_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
    
            responseLog = new FEC_ResponseLog(
                'FEC_GetCardBasicInfo',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapBody,
                res,
                null
            );
            
            if (!isExecuteLog && (res.getStatusCode() != 200 || String.isBlank(res.getBody()))) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
                );
            }
 
            ResponseWrapper response = parseResponse(res.getBody());
 
            if (!isExecuteLog && response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }
            
            return response;
 
        } catch (Exception ex) {
            System.debug('### GET CARD BASIC INFO ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // BUILD SOAP REQUEST
    // =========================================================================
    private static String buildSoapBody(
        String transID,
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
            body.addChildElement('ns1:GetCardBasicInfo', null, null);
        
        action.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/CIF_CardInfo'
        );
        
        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('AccountNumber', null, null)
              .addTextNode(accountNumber);

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
    // RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {
 
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
 
        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
 
        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }
 
        ResponseWrapper result = new ResponseWrapper();
 
        // SYS
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
 
        Dom.XmlNode infoNode = responseNode.getChildElement('CardBasicInfo', null);
        if (infoNode == null) return result;
        result.CardBasicInfo = new CardBasicInfo();
 
        // MAIN CARD
        Dom.XmlNode main = infoNode.getChildElement('MainCard', null);
        result.CardBasicInfo.MainCard = new MainCard();
 
        result.CardBasicInfo.MainCard.Product               = FEC_CommonUltils.getXmlValue(main, 'Product');
        result.CardBasicInfo.MainCard.CustomerSegment       = FEC_CommonUltils.getXmlValue(main, 'CustomerSegment');
        result.CardBasicInfo.MainCard.PlasticIndicator      = FEC_CommonUltils.getXmlValue(main, 'PlasticIndicator');
        result.CardBasicInfo.MainCard.ProductAssociation    = FEC_CommonUltils.getXmlValue(main, 'ProductAssociation');
        result.CardBasicInfo.MainCard.Status                = FEC_CommonUltils.getXmlValue(main, 'Status');
        result.CardBasicInfo.MainCard.IPPFlag               = FEC_CommonUltils.getXmlValue(main, 'IPPFlag');
        result.CardBasicInfo.MainCard.InsuranceFlag         = FEC_CommonUltils.getXmlValue(main, 'InsuranceFlag');
 
        result.CardBasicInfo.MainCard.ContractNumber        = FEC_CommonUltils.getXmlValue(main, 'ContractNumber');
        result.CardBasicInfo.MainCard.AccountNumber         = FEC_CommonUltils.getXmlValue(main, 'AccountNumber');
        result.CardBasicInfo.MainCard.SecurityAnswer        = FEC_CommonUltils.getXmlValue(main, 'SecurityAnswer');
        result.CardBasicInfo.MainCard.ExpiryDate             = FEC_CommonUltils.xmlValToDate(main, 'ExpiryDate');
        result.CardBasicInfo.MainCard.BillingCycle          = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(main, 'BillingCycle'));
        result.CardBasicInfo.MainCard.ActivatedFlag         = FEC_CommonUltils.getXmlValue(main, 'ActivatedFlag');
 
        /* ===== ACCOUNT STATUS ===== */
        result.CardBasicInfo.MainCard.WarningCode           = FEC_CommonUltils.getXmlValue(main, 'WarningCode');
        result.CardBasicInfo.MainCard.BlockCode1            = FEC_CommonUltils.getXmlValue(main, 'BlockCode1');
        result.CardBasicInfo.MainCard.BlockCode2            = FEC_CommonUltils.getXmlValue(main, 'BlockCode2');
        result.CardBasicInfo.MainCard.RsnBlockCode1          = FEC_CommonUltils.getXmlValue(main, 'RsnBlockCode1');
        result.CardBasicInfo.MainCard.RsnBlockCode2          = FEC_CommonUltils.getXmlValue(main, 'RsnBlockCode2');
        result.CardBasicInfo.MainCard.AccountBlockCode1Date = FEC_CommonUltils.xmlValToDate(main, 'AccountBlockCode1Date');
        result.CardBasicInfo.MainCard.AccountBlockCode2Date = FEC_CommonUltils.xmlValToDate(main, 'AccountBlockCode2Date');
        result.CardBasicInfo.MainCard.WarningCode360        = FEC_CommonUltils.getXmlValue(main, 'WarningCode360');
 
        /* ===== FINANCIAL ===== */
        result.CardBasicInfo.MainCard.OTB                   = FEC_CommonUltils.xmlValToDecimal(main, 'OTB');
        result.CardBasicInfo.MainCard.HoldAmount            = FEC_CommonUltils.xmlValToDecimal(main, 'HoldAmount');
        result.CardBasicInfo.MainCard.CreditLimit           = FEC_CommonUltils.xmlValToDecimal(main, 'Limit');
        result.CardBasicInfo.MainCard.PaymentDate           = FEC_CommonUltils.xmlValToDate(main, 'PaymentDate');
        result.CardBasicInfo.MainCard.LastPaymentAmount     = FEC_CommonUltils.xmlValToDecimal(main, 'LastPaymentAmount');
        result.CardBasicInfo.MainCard.LoanBalance            = FEC_CommonUltils.xmlValToDecimal(main, 'LoanBalance');
 
        /* ===== OTHER ===== */
        result.CardBasicInfo.MainCard.MaskedCardNumber      = FEC_CommonUltils.getXmlValue(main, 'MaskedCardNumber');
        result.CardBasicInfo.MainCard.PaymentHoliday        = FEC_CommonUltils.getXmlValue(main, 'PaymentHoliday');
        result.CardBasicInfo.MainCard.DigitalCardIndicator  = FEC_CommonUltils.getXmlValue(main, 'DigitalCardIndicator');
        result.CardBasicInfo.MainCard.MailingInd            = FEC_CommonUltils.getXmlValue(main, 'MailingInd');
        result.CardBasicInfo.MainCard.CardNumber            = FEC_CommonUltils.getXmlValue(main, 'CardNumber');
        result.CardBasicInfo.MainCard.CardActivationDate    = FEC_CommonUltils.getXmlValue(main, 'CardActivationDate');
        result.CardBasicInfo.MainCard.BlockCode             = FEC_CommonUltils.getXmlValue(main, 'BlockCode');
        result.CardBasicInfo.MainCard.BlckDate              = FEC_CommonUltils.xmlValToDate(main, 'BlckDate');
 
        /// STATEMENT
        Dom.XmlNode stmt = infoNode.getChildElement('Statement', null);
        if (stmt != null) {
            result.CardBasicInfo.Statement = new StatementInfo();
            result.CardBasicInfo.Statement.StatementBalance =
                FEC_CommonUltils.xmlValToDecimal(stmt, 'StatemenBalance');
            result.CardBasicInfo.Statement.LastStatementDate =
                FEC_CommonUltils.xmlValToDate(stmt, 'LastStatementDate');
            result.CardBasicInfo.Statement.NextStatementDate =
                FEC_CommonUltils.xmlValToDate(stmt, 'NextStatementDate');
            result.CardBasicInfo.Statement.LastStatementDueDate =
                FEC_CommonUltils.xmlValToDate(stmt, 'LastStatementDueDate');
            result.CardBasicInfo.Statement.LastStatementMPA =
                FEC_CommonUltils.xmlValToDecimal(stmt, 'LastStatementMPA');
        }
 
        // PASS DUE
        Dom.XmlNode pass = infoNode.getChildElement('PassDUE', null);
        result.CardBasicInfo.PassDUE = new PassDue();
        result.CardBasicInfo.PassDUE.DPD = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(pass, 'DPD'));
 
        /* STATEMENTS PERIOD */
        result.CardBasicInfo.Statements = new List<StatementPeriod>();
        Dom.XmlNode stmts;
        for (Dom.XmlNode n : infoNode.getChildElements()) {
            if (n.getName() == 'Statements') {
                stmts = n;
                break;
            }
        }
 
        if (stmts != null) {
            for (Dom.XmlNode s : stmts.getChildElements()) {
 
                StatementPeriod sp = new StatementPeriod();
 
                sp.BalanceBegin =
                    FEC_CommonUltils.xmlValToDecimal(s, 'BalanceForBeginningOfPeriod');
                sp.BalanceEnd =
                    FEC_CommonUltils.xmlValToDecimal(s, 'BalanceForEndOfPeriod');
                sp.MPA =
                    FEC_CommonUltils.xmlValToDecimal(s, 'MPA');
                sp.StatementDate =
                    FEC_CommonUltils.xmlValToDate(s, 'STATEMENT_DATE');
 
                result.CardBasicInfo.Statements.add(sp);
            }
        }
 
        // TRANSACTIONS
        result.CardBasicInfo.Transactions = new List<TransactionInfo>();
        Dom.XmlNode txns = infoNode.getChildElement('Transactions', null);
        if (txns != null) {
            for (Dom.XmlNode t : txns.getChildElements()) {
 
                TransactionInfo ti = new TransactionInfo();
 
                String trxDT = FEC_CommonUltils.getXmlValue(t, 'TRNXDateAndTime');
                if (!String.isBlank(trxDT)) {
                    ti.TRNXDateTime =
                        Datetime.valueOf(
                            trxDT.replace('T', ' ').substring(0, 19)
                        );
                }
 
                ti.Description        = FEC_CommonUltils.getXmlValue(t, 'Description');
                ti.CreditDebitFlag   = FEC_CommonUltils.getXmlValue(t, 'CreditDebitFlag');
                ti.TransactionType   = FEC_CommonUltils.getXmlValue(t, 'TransactionType');
                ti.Status            = FEC_CommonUltils.getXmlValue(t, 'Status');
                ti.Amount            = FEC_CommonUltils.xmlValToDecimal(t, 'TRNXAmount');
                ti.TransactionCode   = FEC_CommonUltils.getXmlValue(t, 'TransactionCode');
                ti.Fee               = FEC_CommonUltils.xmlValToDecimal(t, 'Fee');
                ti.PostingDate       = FEC_CommonUltils.xmlValToDate(t, 'PostingDate');
                ti.SettlementDate    = FEC_CommonUltils.xmlValToDate(t, 'SettlementDate');
                ti.Plan              = FEC_CommonUltils.getXmlValue(t, 'Plan');
                ti.RRN               = FEC_CommonUltils.getXmlValue(t, 'RRN');
                ti.MerchantName      = FEC_CommonUltils.getXmlValue(t, 'MerchantName');
                ti.PaymentFlag       = FEC_CommonUltils.getXmlValue(t, 'PaymentFlag');
                ti.IsCashTRNX        = FEC_CommonUltils.getXmlValue(t, 'IsCashTRNX');
                ti.PlanType          = FEC_CommonUltils.getXmlValue(t, 'PlanType');
                ti.LogicMod          = FEC_CommonUltils.getXmlValue(t, 'LOGIC_MOD');
                ti.OTPSent           = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(t, 'OTPSent'));
 
                result.CardBasicInfo.Transactions.add(ti);
            }
        }

        // CARD HISTORIES
        Dom.XmlNode historiesNode = infoNode.getChildElement('CardHistories', null);
        if (historiesNode != null) {
            result.CardBasicInfo.CardHistories = new CardHistories();
            result.CardBasicInfo.CardHistories.CardHistory = new List<CardHistory>();
            for (Dom.XmlNode h : historiesNode.getChildElements()) {
                CardHistory ch = new CardHistory();
                ch.CardNumber = FEC_CommonUltils.getXmlValue(h, 'CardNumber');
                ch.EmbossingName = FEC_CommonUltils.getXmlValue(h, 'EmbossingName');
                ch.ActivationDate = FEC_CommonUltils.getXmlValue(h, 'ActivationDate');
                ch.CardIssueDate = FEC_CommonUltils.getXmlValue(h, 'CardIssueDate');
                ch.CardExpDate = FEC_CommonUltils.getXmlValue(h, 'CardExpDate');
                ch.CardActivationDate = FEC_CommonUltils.xmlValToDate(h, 'CardActivationDate'); 
                result.CardBasicInfo.CardHistories.CardHistory.add(ch);
            }
        }
 
        return result;
    }
 
}