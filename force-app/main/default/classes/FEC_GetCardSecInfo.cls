/****************************************************************************************
 * File Name    : FEC_GetCardSecInfo
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetCardSecInfo {

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CIF_CardInfo';
    private static final String MOCKUP_ENDPOINT = 'https://d7f82a1e-a770-41e5-a1ea-0d684a148359.mock.pstmn.io';

    // =========================================================================
    // RESPONSE WRAPPER
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public CardSecInfo CardSecInfo;
    }

    // =========================================================================
    // SYS
    // =========================================================================
    public class SysResponse {
        public String TransID;
        public String DateTime_x;
        public Integer Code;
        public String Description;
    }

    // =========================================================================
    // CARD SEC INFO
    // =========================================================================
    public class CardSecInfo {
        public MainCardProduct MainCardProduct;
        public CardFullPayment CardFullPayment;
        public MainCardPlastic MainCardPlastic;
        public MainCardBalance MainCardBalance;
        public PassDue PassDue;
        public List<CardInsurance> CardsInsurances;
        public List<SupplementaryCard> SupplementaryCards;
        public List<IPP> IPPs;
    }

    // =========================================================================
    // IPP
    // =========================================================================
    public class IPP {
        public String IPPPlan;
        public Decimal IPPBalance;
        public Decimal InterestRate;
        public Decimal Term;
        public String IPPStartDate;
        public String IPPMatureDate;
        public Decimal IPPCurrentBalance;
        public Decimal PaymentAmount;
        public String IPPRecordNo;
        public Decimal OpeningBalance;
        public Decimal MonthlyPrincipal;
        public Decimal MonthlyInterest;
    }

    // =========================================================================
    // MAIN CARD PRODUCT
    // =========================================================================
    public class MainCardProduct {
        public Decimal PurchaseLimit;
        public Decimal DailyRetailLimit;
        public Decimal CashLimit;
        public Decimal DailyCashLimit;
        public Decimal Rate;
        public Integer DailyCashNumber;
        public Integer DailyRetailNumber;
        public String StatementNotificationType;
        public Date LastCreditLimitDate;
        public Decimal LastCreditLimit;
        public Date LastDelinquencyDate;
    }

    // =========================================================================
    // CARD FULL PAYMENT
    // =========================================================================
    public class CardFullPayment {
        public Decimal DailyInterestCard;
        public Decimal CardPrincipal;
        public Decimal DailyInterestIPP;
        public Decimal IPPPrincipal;
        public Decimal IPPFee;
    }

    // =========================================================================
    // MAIN CARD PLASTIC
    // =========================================================================
    public class MainCardPlastic {
        public String EmbossingName;
        public String MaskedCardNumber;
        public String ActivationDate;
        public String LastCodeChangeDate;
        public Boolean EcomActiveFlag;
    }

    // =========================================================================
    // MAIN CARD BALANCE
    // =========================================================================
    public class MainCardBalance {
        public Decimal RemainingCashLimit;
        public Decimal RemainingRetailLimit;
        public Decimal DailyRemainingCashLimit;
        public Decimal CurrentBalance;
        public Decimal TotalBalance;
    }

    // =========================================================================
    // PASS DUE
    // =========================================================================
    public class PassDue {
        public String ResponsibleUnit;
        public String ResposiblePerson;
        public String ResposiblePersonPhone;
    }

    // =========================================================================
    // INSURANCE
    // =========================================================================
    public class CardInsurance {
        public String InsuranceType;
        public Decimal InsuranceTotalBalance;
        public Decimal InsuranceMonthlyBalance;
        public Date InsuranceStartDate;
        public Date InsuranceEndDate;
    }

    // =========================================================================
    // SUPPLEMENTARY CARD
    // =========================================================================
    public class SupplementaryCard {
        public String CardNumber;
        public String EmbossingName;
        public String CustomerName;
        public String CustomerRelation;
        public String CardholderName;
        public String Status;
        public String ExpiryDate;
        public String ContactPhone;
        public Date CardIssueDate;
        public Date CardActivationDate;
        public String PlasticIndicator;
        public String BlockCode;
        public String CardholderFlag;
        public String Gender;
    }

    // =========================================================================
    // PUBLIC CALL METHOD - Simplified version for easy usage
    // =========================================================================
    public static ResponseWrapper getCardSecInfo(String accountNumber) {
        String transId = UUID.randomUUID().toString();
        String requestorId = 'CRM';
        String dateTimeStr = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss');
        
        return callGetCardSecInfo(transId, requestorId, dateTimeStr, accountNumber);
    }

    // =========================================================================
    // PUBLIC CALL METHOD - Full version with all parameters
    // =========================================================================
    public static ResponseWrapper callGetCardSecInfo(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {

        validateRequest(transID, requestorId, dateTimeStr, accountNumber);
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        //req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
        req.setEndpoint('https://d7f82a1e-a770-41e5-a1ea-0d684a148359.mock.pstmn.io');
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CardInfo/GetCardSecInfo');

        String body =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<cif:GetCardSecInfo>' +
                        '<Sys>' +
                            '<TransID>' + transID + '</TransID>' +
                            '<RequestorID>' + requestorId + '</RequestorID>' +
                            '<DateTime>' + dateTimeStr + '</DateTime>' +
                        '</Sys>' +
                        '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                    '</cif:GetCardSecInfo>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        req.setBody(body);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException('HTTP error ' + res.getStatusCode());
        }

        ResponseWrapper wrapper = parseResponse(res.getBody());

        if (wrapper.Sys == null || wrapper.Sys.Code != 1) {
            throw new CalloutException(wrapper.Sys != null
                ? wrapper.Sys.Description
                : 'Unknown service error'
            );
        }

        return wrapper;
    }

    // =========================================================================
    // SOAP PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode body = doc.getRootElement()
            .getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

        Dom.XmlNode response;
        for (Dom.XmlNode n : body.getChildElements()) {
            response = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ===== SYS =====
        Dom.XmlNode sysNode = response.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = getVal(sysNode, 'TransID');
        result.Sys.DateTime_x = getVal(sysNode, 'DateTime');
        result.Sys.Code = toInt(getVal(sysNode, 'Code'));
        result.Sys.Description = getVal(sysNode, 'Description');

        // ===== CARD SEC INFO =====
        Dom.XmlNode infoNode = response.getChildElement('CardSecInfo', null);
        if (infoNode == null) return result;

        result.CardSecInfo = new CardSecInfo();

        // MainCardProduct
        Dom.XmlNode mcp = infoNode.getChildElement('MainCardProduct', null);
        if (mcp != null) {
            result.CardSecInfo.MainCardProduct = new MainCardProduct();
            result.CardSecInfo.MainCardProduct.PurchaseLimit = getDec(mcp,'PurchaseLimit');
            result.CardSecInfo.MainCardProduct.DailyRetailLimit = getDec(mcp,'DailyRetailLimit');
            result.CardSecInfo.MainCardProduct.CashLimit = getDec(mcp,'CashLimit');
            result.CardSecInfo.MainCardProduct.DailyCashLimit = getDec(mcp,'DailyCashLimit');
            result.CardSecInfo.MainCardProduct.Rate = getDec(mcp,'Rate');
            result.CardSecInfo.MainCardProduct.DailyCashNumber = toInt(getVal(mcp,'DailyCashNumber'));
            result.CardSecInfo.MainCardProduct.DailyRetailNumber = toInt(getVal(mcp,'DailyRetailNumber'));
            result.CardSecInfo.MainCardProduct.StatementNotificationType = getVal(mcp,'StatementNotificationType');
            result.CardSecInfo.MainCardProduct.LastCreditLimitDate = toDate(getVal(mcp,'LastCreditLimitDate'));
            result.CardSecInfo.MainCardProduct.LastCreditLimit = getDec(mcp,'LastCreditLimit');
            result.CardSecInfo.MainCardProduct.LastDelinquencyDate = toDate(getVal(mcp,'LastDelinquencyDate'));
        }

        // CardFullPayment
        Dom.XmlNode cfp = infoNode.getChildElement('CardFullPayment', null);
        if (cfp != null) {
            result.CardSecInfo.CardFullPayment = new CardFullPayment();
            result.CardSecInfo.CardFullPayment.DailyInterestCard = getDec(cfp,'DailyInterestCard');
            result.CardSecInfo.CardFullPayment.CardPrincipal = getDec(cfp,'CardPrincipal');
            result.CardSecInfo.CardFullPayment.DailyInterestIPP = getDec(cfp,'DailyInterestIPP');
            result.CardSecInfo.CardFullPayment.IPPPrincipal = getDec(cfp,'IPPPrincipal');
            result.CardSecInfo.CardFullPayment.IPPFee = getDec(cfp,'IPPFee');
        }

        // MainCardPlastic
        Dom.XmlNode mcp2 = infoNode.getChildElement('MainCardPlastic', null);
        if (mcp2 != null) {
            result.CardSecInfo.MainCardPlastic = new MainCardPlastic();
            result.CardSecInfo.MainCardPlastic.EmbossingName = getVal(mcp2,'EmbossingName');
            result.CardSecInfo.MainCardPlastic.MaskedCardNumber = getVal(mcp2,'MaskedCardNumber');
            result.CardSecInfo.MainCardPlastic.ActivationDate = getVal(mcp2,'ActivationDate');
            result.CardSecInfo.MainCardPlastic.LastCodeChangeDate = getVal(mcp2,'LastCodeChangeDate');
            result.CardSecInfo.MainCardPlastic.EcomActiveFlag =
                getVal(mcp2,'EcomActiveFlag') == '1';
        }

        // MainCardBalance
        Dom.XmlNode mcb = infoNode.getChildElement('MainCardBalance', null);
        if (mcb != null) {
            result.CardSecInfo.MainCardBalance = new MainCardBalance();
            result.CardSecInfo.MainCardBalance.RemainingCashLimit = getDec(mcb,'RemainingCashLimit');
            result.CardSecInfo.MainCardBalance.RemainingRetailLimit = getDec(mcb,'RemainingRetailLimit');
            result.CardSecInfo.MainCardBalance.DailyRemainingCashLimit = getDec(mcb,'DailyRemainingCashLimit');
            result.CardSecInfo.MainCardBalance.CurrentBalance = getDec(mcb,'CurrentBalance');
            result.CardSecInfo.MainCardBalance.TotalBalance = getDec(mcb,'TotalBalance');
        }

        // PassDue
        Dom.XmlNode mcb3 = infoNode.getChildElement('PassDue', null);
        if (mcb3 != null) {
            result.CardSecInfo.PassDue = new PassDue();
            result.CardSecInfo.PassDue.ResponsibleUnit = getVal(mcb3,'ResponsibleUnit');
            result.CardSecInfo.PassDue.ResposiblePerson = getVal(mcb3,'ResposiblePerson');
            result.CardSecInfo.PassDue.ResposiblePersonPhone = getVal(mcb3,'ResposiblePersonPhone');
        }

        // SupplementaryCards
        Dom.XmlNode suppCardsNode = infoNode.getChildElement('SupplementaryCards', null);
        if (suppCardsNode != null) {
            result.CardSecInfo.SupplementaryCards = new List<SupplementaryCard>();
            for (Dom.XmlNode child : suppCardsNode.getChildElements()) {
                String childName = child.getName();
                // Bỏ qua namespace prefix nếu có
                if (childName.contains(':')) {
                    childName = childName.substring(childName.indexOf(':') + 1);
                }
                if (childName == 'SupplementaryCard') {
                    SupplementaryCard sup = new SupplementaryCard();
                    sup.CardNumber = getVal(child, 'CardNumber');
                    sup.EmbossingName = getVal(child, 'EmbossingName');
                    sup.CustomerName = getVal(child, 'CustomerName');
                    sup.CustomerRelation = getVal(child, 'CustomerRelation');
                    sup.CardholderName = getVal(child, 'CardholderName');
                    sup.Status = getVal(child, 'Status');
                    sup.ExpiryDate = getVal(child, 'ExpiryDate');
                    sup.ContactPhone = getVal(child, 'ContactPhone');
                    sup.CardIssueDate = toDate(getVal(child, 'CardIssueDate'));
                    sup.CardActivationDate = toDate(getVal(child, 'CardActivationDate'));
                    sup.PlasticIndicator = getVal(child, 'PlasticIndicator');
                    sup.BlockCode = getVal(child, 'BlockCode');
                    sup.CardholderFlag = getVal(child, 'CardholderFlag');
                    sup.Gender = getVal(child, 'Gender');
                    result.CardSecInfo.SupplementaryCards.add(sup);
                }
            }
        }

        // IPPs
        Dom.XmlNode ippsNode = infoNode.getChildElement('IPPs', null);
        if (ippsNode != null) {
            result.CardSecInfo.IPPs = new List<IPP>();
            for (Dom.XmlNode child : ippsNode.getChildElements()) {
                String childName = child.getName();
                // Bỏ qua namespace prefix nếu có
                if (childName.contains(':')) {
                    childName = childName.substring(childName.indexOf(':') + 1);
                }
                if (childName == 'IPP') {
                    IPP ipp = new IPP();
                    ipp.IPPPlan = getVal(child, 'IPPPlan');
                    ipp.IPPBalance = getDec(child, 'IPPBalance');
                    ipp.InterestRate = getDec(child, 'InterestRate');
                    ipp.Term = getDec(child, 'CurrentTerm');
                    ipp.IPPStartDate = getVal(child, 'IPPStartDate');
                    ipp.IPPMatureDate = getVal(child, 'IPPMatureDate');
                    ipp.IPPCurrentBalance = getDec(child, 'IPPCurrentBalance');
                    ipp.PaymentAmount = getDec(child, 'PaymentAmount');
                    ipp.IPPRecordNo = getVal(child, 'IPPRecordNo');
                    ipp.OpeningBalance = getDec(child, 'OpeningBalance');
                    ipp.MonthlyPrincipal = getDec(child, 'MonthlyPrincipal');
                    ipp.MonthlyInterest = getDec(child, 'MonthlyInterest');
                    result.CardSecInfo.IPPs.add(ipp);
                }
            }
        }

        return result;
    }

    // =========================================================================
    // VALIDATION (KEEP FULL)
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

        if (transID.length() > 36) {
            throw new CalloutException('TransID is null or invalid or no longer than 36 characters');
        }

        if (String.isBlank(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid');
        }

        Set<String> validRequestorIds = new Set<String>{ 'CRM', 'PORTAL', 'MOBILE_APP' };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(
                'RequestorID is null or invalid, "' + requestorId + '" is not type of RequestorID'
            );
        }

        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' ').replace('Z',''));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime is null or invalid, "' + dateTimeStr + '" is not type of Datetime'
            );
        }

        if (String.isBlank(accountNumber)) {
            throw new CalloutException('AccountNumber is null or invalid');
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
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode n, String name) {
        Dom.XmlNode c = n == null ? null : n.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Decimal getDec(Dom.XmlNode n, String name) {
        String v = getVal(n, name);
        return String.isBlank(v) ? null : Decimal.valueOf(v);
    }

    private static Integer toInt(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }

    private static Date toDate(String v) {
        return String.isBlank(v) ? null : Date.valueOf(v);
    }
}