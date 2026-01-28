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

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CIF_CardInfo';
    private static final String MOCKUP_ENDPOINT = 'https://a37ae5f8-78f8-46ca-9500-1b5bf2b9f492.mock.pstmn.io';
    
    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
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
        try {

            validateRequest(transID, requestorId, dateTimeStr, accountNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CardInfo/GetCardBasicInfo');

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<cif:GetCardBasicInfo>' +
                            '<Sys>' +
                                '<TransID>' + transID + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                        '</cif:GetCardBasicInfo>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetCardBasicInfo service returned HTTP error: ' + res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetCardBasicInfo service returned error'
                );
            }
            
            return response;

        } catch (Exception ex) {
            System.debug('### GET CARD BASIC INFO ERROR: ' + ex.getMessage());
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
    // RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // SYS
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = getVal(sysNode, 'TransID');
        result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
        result.Sys.Code = toInt(getVal(sysNode, 'Code'));
        result.Sys.Description = getVal(sysNode, 'Description');

        Dom.XmlNode infoNode = responseNode.getChildElement('CardBasicInfo', null);
        if (infoNode == null) return result;
        result.CardBasicInfo = new CardBasicInfo();

        // MAIN CARD
        Dom.XmlNode main = infoNode.getChildElement('MainCard', null);
        result.CardBasicInfo.MainCard = new MainCard();

        result.CardBasicInfo.MainCard.Product               = getVal(main, 'Product');
        result.CardBasicInfo.MainCard.CustomerSegment       = getVal(main, 'CustomerSegment');
        result.CardBasicInfo.MainCard.PlasticIndicator      = getVal(main, 'PlasticIndicator');
        result.CardBasicInfo.MainCard.ProductAssociation    = getVal(main, 'ProductAssociation');
        result.CardBasicInfo.MainCard.Status                = getVal(main, 'Status');
        result.CardBasicInfo.MainCard.IPPFlag               = getVal(main, 'IPPFlag');
        result.CardBasicInfo.MainCard.InsuranceFlag         = getVal(main, 'InsuranceFlag');

        result.CardBasicInfo.MainCard.ContractNumber        = getVal(main, 'ContractNumber');
        result.CardBasicInfo.MainCard.AccountNumber         = getVal(main, 'AccountNumber');
        result.CardBasicInfo.MainCard.SecurityAnswer        = getVal(main, 'SecurityAnswer');
        result.CardBasicInfo.MainCard.ExpiryDate             = getDate(main, 'ExpiryDate');
        result.CardBasicInfo.MainCard.BillingCycle          = toInt(getVal(main, 'BillingCycle'));
        result.CardBasicInfo.MainCard.ActivatedFlag         = getVal(main, 'ActivatedFlag');

        /* ===== ACCOUNT STATUS ===== */
        result.CardBasicInfo.MainCard.WarningCode           = getVal(main, 'WarningCode');
        result.CardBasicInfo.MainCard.BlockCode1            = getVal(main, 'BlockCode1');
        result.CardBasicInfo.MainCard.BlockCode2            = getVal(main, 'BlockCode2');
        result.CardBasicInfo.MainCard.RsnBlockCode1          = getVal(main, 'RsnBlockCode1');
        result.CardBasicInfo.MainCard.RsnBlockCode2          = getVal(main, 'RsnBlockCode2');
        result.CardBasicInfo.MainCard.AccountBlockCode1Date = getDate(main, 'AccountBlockCode1Date');
        result.CardBasicInfo.MainCard.AccountBlockCode2Date = getDate(main, 'AccountBlockCode2Date');
        result.CardBasicInfo.MainCard.WarningCode360        = getVal(main, 'WarningCode360');

        /* ===== FINANCIAL ===== */
        result.CardBasicInfo.MainCard.OTB                   = getDec(main, 'OTB');
        result.CardBasicInfo.MainCard.HoldAmount            = getDec(main, 'HoldAmount');
        result.CardBasicInfo.MainCard.CreditLimit           = getDec(main, 'Limit');
        result.CardBasicInfo.MainCard.PaymentDate           = getDate(main, 'PaymentDate');
        result.CardBasicInfo.MainCard.LastPaymentAmount     = getDec(main, 'LastPaymentAmount');
        result.CardBasicInfo.MainCard.LoanBalance            = getDec(main, 'LoanBalance');

        /* ===== OTHER ===== */
        result.CardBasicInfo.MainCard.MaskedCardNumber      = getVal(main, 'MaskedCardNumber');
        result.CardBasicInfo.MainCard.PaymentHoliday        = getVal(main, 'PaymentHoliday');
        result.CardBasicInfo.MainCard.DigitalCardIndicator  = getVal(main, 'DigitalCardIndicator');
        result.CardBasicInfo.MainCard.MailingInd             = getVal(main, 'MailingInd');

        /// STATEMENT
        Dom.XmlNode stmt = infoNode.getChildElement('Statement', null);
        if (stmt != null) {
            result.CardBasicInfo.Statement = new StatementInfo();
            result.CardBasicInfo.Statement.StatementBalance =
                getDec(stmt, 'StatemenBalance');
            result.CardBasicInfo.Statement.LastStatementDate =
                getDate(stmt, 'LastStatementDate');
            result.CardBasicInfo.Statement.NextStatementDate =
                getDate(stmt, 'NextStatementDate');
            result.CardBasicInfo.Statement.LastStatementDueDate =
                getDate(stmt, 'LastStatementDueDate');
            result.CardBasicInfo.Statement.LastStatementMPA =
                getDec(stmt, 'LastStatementMPA');
        }

        // PASS DUE
        Dom.XmlNode pass = infoNode.getChildElement('PassDUE', null);
        result.CardBasicInfo.PassDUE = new PassDue();
        result.CardBasicInfo.PassDUE.DPD = toInt(getVal(pass, 'DPD'));

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
                    getDec(s, 'BalanceForBeginningOfPeriod');
                sp.BalanceEnd =
                    getDec(s, 'BalanceForEndOfPeriod');
                sp.MPA =
                    getDec(s, 'MPA');
                sp.StatementDate =
                    getDate(s, 'STATEMENT_DATE'); 

                result.CardBasicInfo.Statements.add(sp);
            }
        }

        // TRANSACTIONS
        result.CardBasicInfo.Transactions = new List<TransactionInfo>();
        Dom.XmlNode txns = infoNode.getChildElement('Transactions', null);
        if (txns != null) {
            for (Dom.XmlNode t : txns.getChildElements()) {

                TransactionInfo ti = new TransactionInfo();

                String trxDT = getVal(t, 'TRNXDateAndTime');
                if (!String.isBlank(trxDT)) {
                    ti.TRNXDateTime =
                        Datetime.valueOf(
                            trxDT.replace('T', ' ').substring(0, 19)
                        );
                }

                ti.Description        = getVal(t, 'Description');
                ti.CreditDebitFlag   = getVal(t, 'CreditDebitFlag');
                ti.TransactionType   = getVal(t, 'TransactionType');
                ti.Status            = getVal(t, 'Status');
                ti.Amount            = getDec(t, 'TRNXAmount');
                ti.TransactionCode   = getVal(t, 'TransactionCode');
                ti.Fee               = getDec(t, 'Fee');
                ti.PostingDate       = getDate(t, 'PostingDate');
                ti.SettlementDate    = getDate(t, 'SettlementDate');
                ti.Plan              = getVal(t, 'Plan');
                ti.RRN               = getVal(t, 'RRN');
                ti.MerchantName      = getVal(t, 'MerchantName');
                ti.PaymentFlag       = getVal(t, 'PaymentFlag');
                ti.IsCashTRNX        = getVal(t, 'IsCashTRNX');
                ti.PlanType          = getVal(t, 'PlanType');
                ti.LogicMod          = getVal(t, 'LOGIC_MOD');
                ti.OTPSent           = toInt(getVal(t, 'OTPSent'));

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
        if (String.isBlank(v)) return null;

        try {
            if (v.contains('-')) {
                return Date.valueOf(v);
            }

            if (v.length() == 8) {
                Integer year  = Integer.valueOf(v.substring(0, 4));
                Integer month = Integer.valueOf(v.substring(4, 6));
                Integer day   = Integer.valueOf(v.substring(6, 8));
                return Date.newInstance(year, month, day);
            }
        } catch (Exception e) {
            System.debug('### INVALID DATE FORMAT: ' + v);
        }

        return null;
    }
}