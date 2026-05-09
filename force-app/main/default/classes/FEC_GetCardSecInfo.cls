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

    private static ResponseLog responseLog;

    // =========================================================================
    // RESPONSE LOG
    // =========================================================================
    public class ResponseLog {
        public String apiName;
        public String endpoint;
        public String method;
        public String requestBody;
        public HttpResponse response;
        public String errorMessage;

        public ResponseLog(String apiName, String endpoint, String method, String requestBody, HttpResponse response, String errorMessage) {
            this.apiName = apiName;
            this.endpoint = endpoint;
            this.method = method;
            this.requestBody = requestBody;
            this.response = response;
            this.errorMessage = errorMessage;
        }
    }
 
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
        public List<CardStatement> CardStatements;
    }
  
    // =========================================================================
    // IPP
    // =========================================================================
    public class IPP {
        public String IPPPlan;
        public Decimal IPPBalance;
        public Decimal InterestRate;
        public Decimal currentTerm;
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
        public Date DateAssgined;
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
    // CARDS DELIVERY (CardsDeliveries / CardDelivery trong GetCardSecInfo)
    // =========================================================================
    public class CardsDelivery {
        public String CardNumber;
        public String KindOfIssue;
        public String DeliveryDate;
        /** Ngày phát hành / cập nhật (XML: IssuelastUpdate) */
        public String IssuelastUpdate;
        public String FinalSt;
        public String Recipient;
        public String TrackingNo;
        public String DelayNotes;
    }
  
    // =========================================================================
    // PUBLIC CALL METHOD - Simplified version for easy usage
    // =========================================================================
    public static ResponseWrapper getCardSecInfo(String accountNumber) {
        String transId = UUID.randomUUID().toString();
        String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
        String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);
        
        return callGetCardSecInfo(transId, requestorId, dateTimeStr, accountNumber, false);
    }
  
    // =========================================================================
    // CARD STATEMENT
    // =========================================================================
    public class CardStatement {
        public Decimal MPAStructure;
        public Decimal FeeTotal;
  
        public Decimal TotalInterest;
        public Decimal InterestCurrent;
        public Decimal InterestPrevious;
        public Decimal OpeningInterest;
  
        public Decimal TotalPrincipal;
        public Decimal PrincipalCurrent;
        public Decimal PrincipalPrevious;
        public Decimal OpeningPrincipal;
  
        public Decimal IPPPrincipal;
        public Decimal IPPInterest;
        public Decimal IPPFee;
        public Decimal IPPOutBalance;
  
        public Decimal BalanceForBeginningOfPeriod;
        public Decimal BalanceForEndOfPeriod;
  
        public Decimal MPA;
  
        public Date StatementDate;
        public Decimal QualGraceBal;
  
        public Decimal TotalPastDue;
        public Decimal TotalPaymentDue;
  
        public Date DueDate;
    }
  
    // =========================================================================
    // PUBLIC CALL METHOD - Full version with all parameters
    // =========================================================================
    public static ResponseWrapper callGetCardSecInfo(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        Boolean isTestApi
    ) {
  
        validateRequest(transID, requestorId, dateTimeStr, accountNumber, isTestApi);

        if (isTestApi) {
            throw new CalloutException(
                String.format(
                    System.Label.FEC_MSG_API_Error,
                    new List<String>{ 'API Fail' }
                )
            );
        }
        
        // Build SOAP request using Dom.XmlNode
        Dom.Document doc = new Dom.Document();
        
        // Create Envelope with namespaces
        Dom.XmlNode envelope = doc.createRootElement('Envelope', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        envelope.setNamespace('cif', 'http://fecredit.com.vn/CIF_CardInfo');
        
        // Create Header
        envelope.addChildElement('Header', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        
        // Create Body
        Dom.XmlNode body = envelope.addChildElement('Body', FEC_ConstantCommon.SOAP_ENV, 'soapenv');
        
        // Create GetCardSecInfo
        Dom.XmlNode getCardSecInfo = body.addChildElement('GetCardSecInfo', 'http://fecredit.com.vn/CIF_CardInfo', 'cif');
        
        // Create Sys node
        Dom.XmlNode sys = getCardSecInfo.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transID);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);
        
        // Create AccountNumber
        getCardSecInfo.addChildElement('AccountNumber', null, null).addTextNode(accountNumber);
        
        String requestBody = doc.toXmlString();
  
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Card_Sec_Info');
  
        String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, requestBody);

        responseLog = new ResponseLog(
            'FEC_GetCardSecInfo',
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            requestBody,
            res,
            null
        );
  
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
            result.CardSecInfo.PassDue.DateAssgined = FEC_CommonUltils.parseDate(FEC_CommonUltils.getXmlValue(mcb3,'DateAssgined'));
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
                    sup.CardIssueDate = FEC_CommonUltils.parseDate(FEC_CommonUltils.getXmlValue(child, 'CardIssueDate'));
                    sup.CardActivationDate = FEC_CommonUltils.parseDate(FEC_CommonUltils.getXmlValue(child, 'CardActivationDate'));
                    sup.PlasticIndicator = FEC_CommonUltils.getXmlValue(child, 'PlasticIndicator');
                    sup.BlockCode = FEC_CommonUltils.getXmlValue(child, 'BlockCode');
                    sup.CardholderFlag = FEC_CommonUltils.getXmlValue(child, 'CardholderFlag');
                    sup.Gender = FEC_CommonUltils.getXmlValue(child, 'Gender');
                    result.CardSecInfo.SupplementaryCards.add(sup);
                }
            }
        }
        
        // CardsDeliveries (mỗi phần tử có thể là CardsDelivery hoặc CardDelivery; có thể lồng CardDelivery)
        Dom.XmlNode deliveriesNode = infoNode.getChildElement('CardsDeliveries', null);
        if (deliveriesNode != null) {
            result.CardSecInfo.CardsDeliveries = new List<CardsDelivery>();
            for (Dom.XmlNode child : deliveriesNode.getChildElements()) {
                String childName = child.getName();
                if (childName.contains(':')) {
                    childName = childName.substring(childName.indexOf(':') + 1);
                }
                if (childName != 'CardsDelivery' && childName != 'CardDelivery') {
                    continue;
                }
                Dom.XmlNode src = child;
                Dom.XmlNode nested = child.getChildElement('CardDelivery', null);
                if (nested != null) {
                    src = nested;
                }
                CardsDelivery delivery = new CardsDelivery();
                delivery.CardNumber = FEC_CommonUltils.getXmlValue(src, 'CardNumber');
                delivery.KindOfIssue = FEC_CommonUltils.getXmlValue(src, 'KindOfIssue');
                if (String.isBlank(delivery.KindOfIssue) && src != child) {
                    delivery.KindOfIssue = FEC_CommonUltils.getXmlValue(child, 'KindOfIssue');
                }
                delivery.DeliveryDate = FEC_CommonUltils.getXmlValue(src, 'DeliveryDate');
                if (String.isBlank(delivery.DeliveryDate) && src != child) {
                    delivery.DeliveryDate = FEC_CommonUltils.getXmlValue(child, 'DeliveryDate');
                }
                delivery.IssuelastUpdate = FEC_CommonUltils.getXmlValue(src, 'IssuelastUpdate');
                if (String.isBlank(delivery.IssuelastUpdate)) {
                    delivery.IssuelastUpdate = FEC_CommonUltils.getXmlValue(src, 'IssueLastUpdate');
                }
                delivery.FinalSt = FEC_CommonUltils.getXmlValue(src, 'FinalSt');
                delivery.Recipient = FEC_CommonUltils.getXmlValue(src, 'Recipient');
                delivery.TrackingNo = FEC_CommonUltils.getXmlValue(src, 'TrackingNo');
                delivery.DelayNotes = FEC_CommonUltils.getXmlValue(src, 'DelayNotes');
                result.CardSecInfo.CardsDeliveries.add(delivery);
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
                    // Dùng expandIPPToScheduleItems để tách OPENING_BALANCE_1..36, PAYMENT_AMT_k, ... thành từng kỳ.
                    List<IPP> expanded = expandIPPToScheduleItems(child);
                    if (expanded != null && !expanded.isEmpty()) {
                        result.CardSecInfo.IPPs.addAll(expanded);
                    }
                }
            }
        }
  
        // CARDSTATEMENT
        Dom.XmlNode cardStatementNode = infoNode.getChildElement('CardStatements', null);
        if (cardStatementNode != null) {
            result.CardSecInfo.CardStatements = new List<CardStatement>();
  
            for (Dom.XmlNode child : cardStatementNode.getChildElements()) {
  
                String childName = child.getName();
                if (childName.contains(':')) {
                    childName = childName.substring(childName.indexOf(':') + 1);
                }
  
                if (childName == 'CardStatement') {
  
                    CardStatement cs = new CardStatement();
  
                    cs.MPAStructure = FEC_CommonUltils.xmlValToDecimal(child,'MPAStructure');
                    cs.FeeTotal = FEC_CommonUltils.xmlValToDecimal(child,'FeeTotal');
  
                    cs.TotalInterest = FEC_CommonUltils.xmlValToDecimal(child,'TotalInterest');
                    cs.InterestCurrent = FEC_CommonUltils.xmlValToDecimal(child,'InterestCurrent');
                    cs.InterestPrevious = FEC_CommonUltils.xmlValToDecimal(child,'InterestPrevious');
                    cs.OpeningInterest = FEC_CommonUltils.xmlValToDecimal(child,'OpeningInterest');
  
                    cs.TotalPrincipal = FEC_CommonUltils.xmlValToDecimal(child,'TotalPrincipal');
                    cs.PrincipalCurrent = FEC_CommonUltils.xmlValToDecimal(child,'PrincipalCurrent');
                    cs.PrincipalPrevious = FEC_CommonUltils.xmlValToDecimal(child,'PrincipalPrevious');
                    cs.OpeningPrincipal = FEC_CommonUltils.xmlValToDecimal(child,'OpeningPrincipal');
  
                    cs.IPPPrincipal = FEC_CommonUltils.xmlValToDecimal(child,'IPPPrincipal');
                    cs.IPPInterest = FEC_CommonUltils.xmlValToDecimal(child,'IPPInterest');
                    cs.IPPFee = FEC_CommonUltils.xmlValToDecimal(child,'IPPFee');
                    cs.IPPOutBalance = FEC_CommonUltils.xmlValToDecimal(child,'IPPOutBalance');
  
                    cs.BalanceForBeginningOfPeriod = FEC_CommonUltils.xmlValToDecimal(child,'BalanceForBeginningOfPeriod');
                    cs.BalanceForEndOfPeriod = FEC_CommonUltils.xmlValToDecimal(child,'BalanceForEndOfPeriod');
  
                    cs.MPA = FEC_CommonUltils.xmlValToDecimal(child,'MPA');
  
                    cs.StatementDate = FEC_CommonUltils.parseDate(FEC_CommonUltils.getXmlValue(child,'STATMENT_DATE'));
                    cs.QualGraceBal = FEC_CommonUltils.xmlValToDecimal(child,'QualGraceBal');
  
                    cs.TotalPastDue = FEC_CommonUltils.xmlValToDecimal(child,'TotalPastDue');
                    cs.TotalPaymentDue = FEC_CommonUltils.xmlValToDecimal(child,'TotalPaymentDue');
  
                    cs.DueDate = FEC_CommonUltils.parseDate(FEC_CommonUltils.getXmlValue(child,'DueDate'));
  
                    result.CardSecInfo.CardStatements.add(cs);
                }
            }
        }
  
        return result;
    }
  
    /**
     * Tách <IPP> có OPENING_BALANCE_1, _2, ... _36 thành danh sách IPP (1 item per kỳ) để lưu IPP Schedule.
     * Chỉ trả về item khi có OPENING_BALANCE_k; không fallback sang OpeningBalance root.
     */
    private static List<IPP> expandIPPToScheduleItems(Dom.XmlNode ippNode) {
        List<IPP> listOut = new List<IPP>();
        if (ippNode == null) return listOut;
  
        String ippPlan = FEC_CommonUltils.getXmlValue(ippNode, 'IPPPlan');
        String ippRecordNoFromXml = FEC_CommonUltils.getXmlValue(ippNode, 'IPPRecordNo');
        if (String.isBlank(ippRecordNoFromXml)) {
            ippRecordNoFromXml = FEC_CommonUltils.getValueSafe(ippNode, 'IPPRecordNo');
        }
        String ippRecordNo = String.isBlank(ippRecordNoFromXml) ? null : ippRecordNoFromXml.trim();
        Decimal ippBalance = FEC_CommonUltils.xmlValToDecimal(ippNode, 'IPPBalance');
        Decimal interestRate = FEC_CommonUltils.xmlValToDecimal(ippNode, 'InterestRate');
        Decimal currentTerm = FEC_CommonUltils.xmlValToDecimal(ippNode, 'CurrentTerm');
        String ippStartDate = FEC_CommonUltils.getXmlValue(ippNode, 'IPPStartDate');
        String ippMatureDate = FEC_CommonUltils.getXmlValue(ippNode, 'IPPMatureDate');
        Decimal ippCurrentBalance = FEC_CommonUltils.xmlValToDecimal(ippNode, 'IPPCurrentBalance');
        Decimal paymentAmount = FEC_CommonUltils.xmlValToDecimal(ippNode, 'PaymentAmount');
        Decimal monthlyPrincipal = FEC_CommonUltils.xmlValToDecimal(ippNode, 'MonthlyPrincipal');
        Decimal monthlyInterest = FEC_CommonUltils.xmlValToDecimal(ippNode, 'MonthlyInterest');
  
        // Mỗi kỳ (1-36): OPENING_BALANCE_k, PAYMENT_AMT_k, MONTHLY_PRINCIPAL_k, MONTHLY_INTEREST_k
        for (Integer k = 1; k <= 36; k++) {
            String keyOpening = 'OPENING_BALANCE_' + k;
            String valOpening = FEC_CommonUltils.getXmlValue(ippNode, keyOpening);
            if (String.isNotBlank(valOpening) && valOpening.trim() != '') {
                try {
                    Decimal openingK = Decimal.valueOf(valOpening.trim());
                    Decimal paymentK = FEC_CommonUltils.xmlValToDecimal(ippNode, 'PAYMENT_AMT_' + k);
                    Decimal principalK = FEC_CommonUltils.xmlValToDecimal(ippNode, 'MONTHLY_PRINCIPAL_' + k);
                    Decimal interestK = FEC_CommonUltils.xmlValToDecimal(ippNode, 'MONTHLY_INTEREST_' + k);
                    IPP ipp = new IPP();
                    ipp.IPPPlan = ippPlan;
                    ipp.IPPRecordNo = ippRecordNo;
                    ipp.IPPBalance = ippBalance;
                    ipp.InterestRate = interestRate;
                    ipp.currentTerm = currentTerm;
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
        return listOut;
    }
  
    // =========================================================================
    // VALIDATION (KEEP FULL)
    // =========================================================================
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String accountNumber,
        Boolean isTestApi
    ) {
  
        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
  
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
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

    public static void logApiResponse() {
        if (responseLog != null) {
            FEC_CommonUltils.logApi(
                responseLog.apiName,
                responseLog.endpoint,
                responseLog.method,
                responseLog.requestBody,
                responseLog.response,
                responseLog.errorMessage);
        }
    }
}