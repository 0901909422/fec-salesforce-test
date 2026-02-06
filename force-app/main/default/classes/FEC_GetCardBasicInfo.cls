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

    private static final String ENDPOINT = '/CIF_CardInfo';
    private static final String MOCKUP_ENDPOINT ='https://1d899e3a-18af-403a-a989-fcdb8e64a2c8.mock.pstmn.io';

    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
    public class ResponseWrapper {
        public SysResponse Sys;
        public CardBasicInfo CardBasicInfo;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class CardBasicInfo {
        public MainCard MainCard;
        public StatementInfo Statement;
        public PassDue PassDUE;
        public List<StatementPeriod> Statements;
        public List<TransactionInfo> Transactions;
    }

    public class MainCard {
        public String Product;
        public String CustomerSegment;
        public String PlasticIndicator;
        public String ProductAssociation;
        public String Status;
        public String IPPFlag;
        public String InsuranceFlag;
        public String ContractNumber;
        public String AccountNumber;
        public String SecurityAnswer;
        public Date ExpiryDate;
        public Integer BillingCycle;
        public String ActivatedFlag;
        public String BlockCode1;
        public String BlockCode2;
        public String WarningCode;
        public Decimal OTB;
        public Decimal HoldAmount;
        public Decimal CreditLimit;
        public Date PaymentDate;
        public Decimal LastPaymentAmount;
        public String MaskedCardNumber;
        public String PaymentHoliday;
        public String DigitalCardIndicator;
        public String RsnBlockCode1;
        public String RsnBlockCode2;
        public Date AccountBlockCode1Date;
        public Date AccountBlockCode2Date;
        public String WarningCode360;
        public String MailingInd;
        public Decimal LoanBalance;
    }

    public class StatementInfo {
        public Decimal StatementBalance;
        public Date LastStatementDate;
        public Date NextStatementDate;
        public Date LastStatementDueDate;
        public Decimal LastStatementMPA;
    }

    public class PassDue {
        public Integer DPD;
    }

    public class StatementPeriod {
        public Decimal BalanceBegin;
        public Decimal BalanceEnd;
        public Decimal MPA;
        public Date StatementDate;
    }

    public class TransactionInfo {
        public Datetime TRNXDateTime;
        public String Description;
        public String CreditDebitFlag;
        public String TransactionType;
        public String Status;
        public Decimal Amount;
        public String TransactionCode;
        public Decimal Fee;
        public Date PostingDate;
        public Date SettlementDate;
        public String Plan;
        public String RRN;
        public String MerchantName;
        public String PaymentFlag;
        public String IsCashTRNX;
        public String PlanType;
        public String LogicMod;
        public Integer OTPSent;
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

        validateRequest(transID, requestorId, dateTimeStr, accountNumber);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            apiSetting?.FEC_Call_Mock__c
                ? MOCKUP_ENDPOINT
                : apiSetting.FEC_Endpoint__c + ENDPOINT
        );
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/CIF_CardInfo/GetCardBasicInfo'
        );

        req.setBody(
            buildSoapBody(
                transID,
                requestorId,
                dateTimeStr,
                accountNumber
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

            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }

        return response;
    }

    /* =====================================================
       SOAP BODY
       ===================================================== */
    private static String buildSoapBody(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );

        envelope.setAttribute(
            'xmlns:cif',
            'http://fecredit.com.vn/CIF_CardInfo'
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('cif:GetCardBasicInfo', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

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
        result.CardBasicInfo.MainCard.MailingInd             = FEC_CommonUltils.getXmlValue(main, 'MailingInd');

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
                    FEC_CommonUltils.xmlGetDateYYYYMMDD(s, 'STATEMENT_DATE'); 
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

        return result;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode n, String name) {
        if (n == null) return null;
        Dom.XmlNode c = n.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Decimal getDec(Dom.XmlNode n, String name) {
        String v = getVal(n, name);
        return String.isBlank(v) ? null : Decimal.valueOf(v);
    }

    private static Integer toInt(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }

    private static Date getDate(Dom.XmlNode n, String name) {
        String v = getVal(n, name);
        return String.isBlank(v) ? null : Date.valueOf(v);
    }
    private static Date getDateYYYYMMDD(Dom.XmlNode n, String name) {
        String v = getVal(n, name);
        if (String.isBlank(v)) return null;

        if (v.length() == 8) {
            String yyyy = v.substring(0, 4);
            String mm   = v.substring(4, 6);
            String dd   = v.substring(6, 8);
            return Date.valueOf(yyyy + '-' + mm + '-' + dd);
        }

        return null;
    }
}