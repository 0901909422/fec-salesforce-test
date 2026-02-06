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
        public List<CardsDelivery> CardsDeliveries;
        public List<IPP> IPPs;
    }

    // =========================================================================
    // IPP
    // =========================================================================
    public class IPP {
        public String IPPPlan;
        public Decimal IPPBalance;
        public Decimal InterestRate;
        public Decimal CurrentTerm;
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
    public class CardsDelivery {
        public String CardNumber; // Card Number
        public String KindOfIssue; // Type of Issue
        public String DeliveryDate; // Delivery Date
    }

    /* =====================================================
       PUBLIC SHORT METHOD
       ===================================================== */
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
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Sec_Info');
        HttpRequest req = new HttpRequest();
        //  req.setEndpoint(
        //     apiSetting?.FEC_Call_Mock__c
        //         ? MOCKUP_ENDPOINT
        //         : apiSetting.FEC_Endpoint__c + ENDPOINT
        // );
        req.setEndpoint('https://d7f82a1e-a770-41e5-a1ea-0d684a148359.mock.pstmn.io');
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/CIF_CardInfo/GetCardSecInfo'
        );

        req.setBody(
            buildSoapBody(transID, requestorId, dateTimeStr, accountNumber)
        );

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
        }

        ResponseWrapper wrapper = parseResponse(res.getBody());

        if (wrapper.Sys != null && wrapper.Sys.Code != 1) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{wrapper.Sys.Description})
            );
        }

        return wrapper;
    }

    /* =====================================================
       SOAP REQUEST
       ===================================================== */
    private static String buildSoapBody(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode env = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );
        env.setAttribute('xmlns:cif', 'http://fecredit.com.vn/CIF_CardInfo');

        env.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = env.addChildElement('soapenv:Body', null, null);
        Dom.XmlNode act = body.addChildElement('cif:GetCardSecInfo', null, null);

        Dom.XmlNode sys = act.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        act.addChildElement('AccountNumber', null, null)
           .addTextNode(accountNumber);

        return doc.toXmlString();
    }

    /* =====================================================
       VALIDATION
       ===================================================== */
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {

        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
                if (String.isBlank(requestorId)) {
                throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
            }
        }

        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL, FEC_ConstantCommon.REQUESTOR_MOBILE_APP };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }

        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' ').replace('Z',''));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr})
            );
        }

        if (String.isBlank(accountNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'AccountNumber'}));

        } 
        if (accountNumber.length() > 255) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'AccountNumber', '255'})
            );
        }
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

        // CardsDeliveries
        Dom.XmlNode deliveriesNode = infoNode.getChildElement('CardsDeliveries', null);
        if (deliveriesNode != null) {
            result.CardSecInfo.CardsDeliveries = new List<CardsDelivery>();
            for (Dom.XmlNode child : deliveriesNode.getChildElements()) {
                String childName = child.getName();
                // Bỏ qua namespace prefix nếu có
                if (childName.contains(':')) {
                    childName = childName.substring(childName.indexOf(':') + 1);
                }
                if (childName == 'CardsDelivery') {
                    CardsDelivery delivery = new CardsDelivery();
                    delivery.CardNumber = FEC_CommonUltils.getXmlValue(child, 'CardNumber');
                    delivery.KindOfIssue = FEC_CommonUltils.getXmlValue(child, 'KindOfIssue');
                    delivery.DeliveryDate = FEC_CommonUltils.getXmlValue(child, 'DeliveryDate');
                    result.CardSecInfo.CardsDeliveries.add(delivery);
                }
            }
        }

        // IPPs – hỗ trợ nhiều bản ghi schedule: nhiều <IPP> hoặc OPENING_BALANCE_1, _2, ... trong 1 <IPP>
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
                    result.CardSecInfo.IPPs.addAll(expandIPPToScheduleItems(child));
                }
            }
        }

        return result;
    }

    /**
     * Một <IPP> có thể có OPENING_BALANCE_1, _2, ... _36 (nhiều kỳ) hoặc chỉ OpeningBalance (1 kỳ).
     * Trả về danh sách IPP (1 item per kỳ) để lưu nhiều bản ghi IPP Schedule.
     */
    private static List<IPP> expandIPPToScheduleItems(Dom.XmlNode ippNode) {
        List<IPP> listOut = new List<IPP>();
        if (ippNode == null) return listOut;

        String ippPlan = FEC_CommonUltils.getXmlValue(ippNode, 'IPPPlan');
        String ippRecordNoFromXml = FEC_CommonUltils.getXmlValue(ippNode, 'IPPRecordNo');
        if (String.isBlank(ippRecordNoFromXml)) {
            throw new CalloutException('GetCardSecInfo response missing IPPRecordNo for an IPP');
        }
        String ippRecordNo = ippRecordNoFromXml.trim();
        Decimal ippBalance =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'IPPBalance');
        Decimal interestRate =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'InterestRate');
        Decimal currentTerm =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'CurrentTerm');
        String ippStartDate = FEC_CommonUltils.getXmlValue(ippNode, 'IPPStartDate');
        String ippMatureDate = FEC_CommonUltils.getXmlValue(ippNode, 'IPPMatureDate');
        Decimal ippCurrentBalance =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'IPPCurrentBalance');
        Decimal paymentAmount =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'PaymentAmount');
        Decimal monthlyPrincipal =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'MonthlyPrincipal');
        Decimal monthlyInterest =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'MonthlyInterest');

        // Mỗi kỳ (1-36): OPENING_BALANCE_k, PAYMENT_AMT_k, MONTHLY_PRINCIPAL_k, MONTHLY_INTEREST_k
        for (Integer k = 1; k <= 36; k++) {
            String keyOpening = 'OPENING_BALANCE_' + k;
            String valOpening = FEC_CommonUltils.getXmlValue(ippNode, keyOpening);
            if (String.isNotBlank(valOpening) && valOpening.trim() != '') {
                try {
                    Decimal openingK = Decimal.valueOf(valOpening.trim());
                    Decimal paymentK =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'PAYMENT_AMT_' + k);
                    Decimal principalK =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'MONTHLY_PRINCIPAL_' + k);
                    Decimal interestK =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'MONTHLY_INTEREST_' + k);
                    IPP ipp = new IPP();
                    ipp.IPPPlan = ippPlan;
                    ipp.IPPRecordNo = ippRecordNo;
                    ipp.IPPBalance = ippBalance;
                    ipp.InterestRate = interestRate;
                    ipp.CurrentTerm = currentTerm;
                    ipp.IPPStartDate = ippStartDate;
                    ipp.IPPMatureDate = ippMatureDate;
                    ipp.IPPCurrentBalance = ippCurrentBalance;
                    ipp.PaymentAmount = paymentK != null ? paymentK : paymentAmount;
                    ipp.MonthlyPrincipal = principalK != null ? principalK : monthlyPrincipal;
                    ipp.MonthlyInterest = interestK != null ? interestK : monthlyInterest;
                    ipp.OpeningBalance = openingK;
                    listOut.add(ipp);
                } catch (Exception e) { /* skip invalid number */ }
            }
        }

        if (listOut.isEmpty()) {
            Decimal openingBalance =  FEC_CommonUltils.xmlValToDecimal(ippNode, 'OpeningBalance');
            IPP ipp = new IPP();
            ipp.IPPPlan = ippPlan;
            ipp.IPPRecordNo = ippRecordNo;
            ipp.IPPBalance = ippBalance;
            ipp.InterestRate = interestRate;
            ipp.CurrentTerm = currentTerm;
            ipp.IPPStartDate = ippStartDate;
            ipp.IPPMatureDate = ippMatureDate;
            ipp.IPPCurrentBalance = ippCurrentBalance;
            ipp.PaymentAmount = paymentAmount;
            ipp.MonthlyPrincipal = monthlyPrincipal;
            ipp.MonthlyInterest = monthlyInterest;
            ipp.OpeningBalance = openingBalance != null ? openingBalance : 0;
            listOut.add(ipp);
        }
        return listOut;
    }

}