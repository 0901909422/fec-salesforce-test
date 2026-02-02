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
        String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
        String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        
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

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Sec_Info');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_CARD_SEC_INFO_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, body);

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
            .getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

        Dom.XmlNode response;
        for (Dom.XmlNode n : body.getChildElements()) {
            response = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ===== SYS =====
        Dom.XmlNode sysNode = response.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTime_x = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // ===== CARD SEC INFO =====
        Dom.XmlNode infoNode = response.getChildElement('CardSecInfo', null);
        if (infoNode == null) return result;

        result.CardSecInfo = new CardSecInfo();

        // MainCardProduct
        Dom.XmlNode mcp = infoNode.getChildElement('MainCardProduct', null);
        if (mcp != null) {
            result.CardSecInfo.MainCardProduct = new MainCardProduct();
            result.CardSecInfo.MainCardProduct.PurchaseLimit = FEC_CommonUltils.xmlValToDecimal(mcp,'PurchaseLimit');
            result.CardSecInfo.MainCardProduct.DailyRetailLimit = FEC_CommonUltils.xmlValToDecimal(mcp,'DailyRetailLimit');
            result.CardSecInfo.MainCardProduct.CashLimit = FEC_CommonUltils.xmlValToDecimal(mcp,'CashLimit');
            result.CardSecInfo.MainCardProduct.DailyCashLimit = FEC_CommonUltils.xmlValToDecimal(mcp,'DailyCashLimit');
            result.CardSecInfo.MainCardProduct.Rate = FEC_CommonUltils.xmlValToDecimal(mcp,'Rate');
            result.CardSecInfo.MainCardProduct.DailyCashNumber = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(mcp,'DailyCashNumber'));
            result.CardSecInfo.MainCardProduct.DailyRetailNumber = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(mcp,'DailyRetailNumber'));
            result.CardSecInfo.MainCardProduct.StatementNotificationType = FEC_CommonUltils.getXmlValue(mcp,'StatementNotificationType');
            result.CardSecInfo.MainCardProduct.LastCreditLimitDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(mcp,'LastCreditLimitDate'));
            result.CardSecInfo.MainCardProduct.LastCreditLimit = FEC_CommonUltils.xmlValToDecimal(mcp,'LastCreditLimit');
            result.CardSecInfo.MainCardProduct.LastDelinquencyDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(mcp,'LastDelinquencyDate'));
        }

        // CardFullPayment
        Dom.XmlNode cfp = infoNode.getChildElement('CardFullPayment', null);
        if (cfp != null) {
            result.CardSecInfo.CardFullPayment = new CardFullPayment();
            result.CardSecInfo.CardFullPayment.DailyInterestCard = FEC_CommonUltils.xmlValToDecimal(cfp,'DailyInterestCard');
            result.CardSecInfo.CardFullPayment.CardPrincipal = FEC_CommonUltils.xmlValToDecimal(cfp,'CardPrincipal');
            result.CardSecInfo.CardFullPayment.DailyInterestIPP = FEC_CommonUltils.xmlValToDecimal(cfp,'DailyInterestIPP');
            result.CardSecInfo.CardFullPayment.IPPPrincipal = FEC_CommonUltils.xmlValToDecimal(cfp,'IPPPrincipal');
            result.CardSecInfo.CardFullPayment.IPPFee = FEC_CommonUltils.xmlValToDecimal(cfp,'IPPFee');
        }

        // MainCardPlastic
        Dom.XmlNode mcp2 = infoNode.getChildElement('MainCardPlastic', null);
        if (mcp2 != null) {
            result.CardSecInfo.MainCardPlastic = new MainCardPlastic();
            result.CardSecInfo.MainCardPlastic.EmbossingName = FEC_CommonUltils.getXmlValue(mcp2,'EmbossingName');
            result.CardSecInfo.MainCardPlastic.MaskedCardNumber = FEC_CommonUltils.getXmlValue(mcp2,'MaskedCardNumber');
            result.CardSecInfo.MainCardPlastic.ActivationDate = FEC_CommonUltils.getXmlValue(mcp2,'ActivationDate');
            result.CardSecInfo.MainCardPlastic.LastCodeChangeDate = FEC_CommonUltils.getXmlValue(mcp2,'LastCodeChangeDate');
            result.CardSecInfo.MainCardPlastic.EcomActiveFlag =
                FEC_CommonUltils.getXmlValue(mcp2,'EcomActiveFlag') == '1';
        }

        // MainCardBalance
        Dom.XmlNode mcb = infoNode.getChildElement('MainCardBalance', null);
        if (mcb != null) {
            result.CardSecInfo.MainCardBalance = new MainCardBalance();
            result.CardSecInfo.MainCardBalance.RemainingCashLimit = FEC_CommonUltils.xmlValToDecimal(mcb,'RemainingCashLimit');
            result.CardSecInfo.MainCardBalance.RemainingRetailLimit = FEC_CommonUltils.xmlValToDecimal(mcb,'RemainingRetailLimit');
            result.CardSecInfo.MainCardBalance.DailyRemainingCashLimit = FEC_CommonUltils.xmlValToDecimal(mcb,'DailyRemainingCashLimit');
            result.CardSecInfo.MainCardBalance.CurrentBalance = FEC_CommonUltils.xmlValToDecimal(mcb,'CurrentBalance');
            result.CardSecInfo.MainCardBalance.TotalBalance = FEC_CommonUltils.xmlValToDecimal(mcb,'TotalBalance');
        }

        // PassDue
        Dom.XmlNode mcb3 = infoNode.getChildElement('PassDue', null);
        if (mcb3 != null) {
            result.CardSecInfo.PassDue = new PassDue();
            result.CardSecInfo.PassDue.ResponsibleUnit = FEC_CommonUltils.getXmlValue(mcb3,'ResponsibleUnit');
            result.CardSecInfo.PassDue.ResposiblePerson = FEC_CommonUltils.getXmlValue(mcb3,'ResposiblePerson');
            result.CardSecInfo.PassDue.ResposiblePersonPhone = FEC_CommonUltils.getXmlValue(mcb3,'ResposiblePersonPhone');
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
                    sup.CardNumber = FEC_CommonUltils.getXmlValue(child, 'CardNumber');
                    sup.EmbossingName = FEC_CommonUltils.getXmlValue(child, 'EmbossingName');
                    sup.CustomerName = FEC_CommonUltils.getXmlValue(child, 'CustomerName');
                    sup.CustomerRelation = FEC_CommonUltils.getXmlValue(child, 'CustomerRelation');
                    sup.CardholderName = FEC_CommonUltils.getXmlValue(child, 'CardholderName');
                    sup.Status = FEC_CommonUltils.getXmlValue(child, 'Status');
                    sup.ExpiryDate = FEC_CommonUltils.getXmlValue(child, 'ExpiryDate');
                    sup.ContactPhone = FEC_CommonUltils.getXmlValue(child, 'ContactPhone');
                    sup.CardIssueDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(child, 'CardIssueDate'));
                    sup.CardActivationDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(child, 'CardActivationDate'));
                    sup.PlasticIndicator = FEC_CommonUltils.getXmlValue(child, 'PlasticIndicator');
                    sup.BlockCode = FEC_CommonUltils.getXmlValue(child, 'BlockCode');
                    sup.CardholderFlag = FEC_CommonUltils.getXmlValue(child, 'CardholderFlag');
                    sup.Gender = FEC_CommonUltils.getXmlValue(child, 'Gender');
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
                    ipp.IPPPlan = FEC_CommonUltils.getXmlValue(child, 'IPPPlan');
                    ipp.IPPBalance = FEC_CommonUltils.xmlValToDecimal(child, 'IPPBalance');
                    ipp.InterestRate = FEC_CommonUltils.xmlValToDecimal(child, 'InterestRate');
                    ipp.Term = FEC_CommonUltils.xmlValToDecimal(child, 'CurrentTerm');
                    ipp.IPPStartDate = FEC_CommonUltils.getXmlValue(child, 'IPPStartDate');
                    ipp.IPPMatureDate = FEC_CommonUltils.getXmlValue(child, 'IPPMatureDate');
                    ipp.IPPCurrentBalance = FEC_CommonUltils.xmlValToDecimal(child, 'IPPCurrentBalance');
                    ipp.PaymentAmount = FEC_CommonUltils.xmlValToDecimal(child, 'PaymentAmount');
                    ipp.IPPRecordNo = FEC_CommonUltils.getXmlValue(child, 'IPPRecordNo');
                    ipp.OpeningBalance = FEC_CommonUltils.xmlValToDecimal(child, 'OpeningBalance');
                    ipp.MonthlyPrincipal = FEC_CommonUltils.xmlValToDecimal(child, 'MonthlyPrincipal');
                    ipp.MonthlyInterest = FEC_CommonUltils.xmlValToDecimal(child, 'MonthlyInterest');
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

        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL, FEC_ConstantCommon.REQUESTOR_MOBILE_APP };
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

}