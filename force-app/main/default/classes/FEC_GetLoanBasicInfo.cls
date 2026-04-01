/****************************************************************************************
 * File Name    : FEC_GetLoanBasicInfo
 * Author       : Quangdv7
 * Description  : Get Loan Basic Information from CIF_LoanInfo service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-25     Quangdv7          Create
****************************************************************************************/

public with sharing class FEC_GetLoanBasicInfo {

    private static ResponseLog responseLog;

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public LoanBasicInfo LoanBasicInfo;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class LoanBasicInfo {
        public Loan Loan;
        public RepaymentFeeOverdue RepaymentFeeOverdue;
        public InterestOnOverdueInterest InterestOnOverdueInterest;
        public Product Product;
        public TerminationSimulation TerminationSimulation;
        public PassDue PassDue;
        public List<PaymentHistory> PaymentHistories;
        public List<RepaymentSchedule> RepaymentSchedules;
    }

    // ===================== LOAN =====================
    public class Loan {
        public String ApplicationID;
        public String ContractNumber;
        public String ContractType;
        public String ContractStatus;
        public Boolean SoldStatus;
        public Date AgreementDate;
        public Date DisbursalDate;
        public String DisbursalDealerName;
        public Decimal AssetCost;
        public String AssetDescription;
        public Decimal TotalInstallmentAmount;
        public String CCCode;
        public String CCName;
        public Decimal SecurityDeposit;
        public Decimal SysCalcChargeAmount;
        public Decimal ChargeAmtCollected;
        public Decimal ChargeWaived;
        public Decimal OutstandingChargeAmount;
        public String Purpose;
        public String CompanyName;
    }

    // ===================== OVERDUE =====================
    public class RepaymentFeeOverdue {
        public Decimal AssessedAmount;
        public Decimal CollectedAmount;
        public Decimal WaivedAmount;
        public Decimal OutstandingAmount;
    }

    public class InterestOnOverdueInterest {
        public Decimal AssessedAmount;
        public Decimal CollectedAmount;
        public Decimal WaivedAmount;
        public Decimal OutstandingAmount;
    }

    // ===================== PRODUCT =====================
    public class Product {
        public Decimal LoanAmount;
        public Decimal Rate;
        public Decimal RepaymentFee;
        public Decimal EMI;
        public Integer Tenure;
        public Date FirstPaymentDate;
        public Date LastPaymentDate;
        public String Product;
        public String Scheme;
        public Decimal InsuranceAmount;
        public Integer Tennure;
        public Date ClosureDate;
        public Date ChargeOffDate;
        public Decimal PrincipalDue;
        public Decimal InterestDue;
    }

    public class TerminationSimulation {
        public Decimal ExcessAmounts;
        public Date NextDueDate;
    }

    public class PassDue {
        public Integer DPD;
        public String ResponsibleUnit;
        public Decimal TotalOverdueAmount;
        public Decimal OverduePenalty;
    }

    public class PaymentHistory {
        public Date ValueDate;
        public Decimal AmountOfMoney;
    }

    public class RepaymentSchedule {
        public Integer InstallmentNo;
        public Date InstallmentStartDate;
        public Date DueDate;
        public Decimal OpeningPrincipal;
        public Decimal EMI;
        public Decimal RepaymentFee;
        public Decimal InstallmentAmount;
        public Decimal Principal;
        public Decimal Interest;
        public Decimal ClosingPrincipal;
    }

    // =========================================================================
    // RESPONSE LOG CLASS
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
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetLoanBasicInfo(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNumber
    ) {
        try {
            validateRequest(transId, requestorId, dateTimeStr, contractNumber);

            String soapBody = buildSoapBody(transId, requestorId, dateTimeStr, contractNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Loan_Basic_Info');

            //String endpoint = apiSetting?.FEC_Call_Mock__c
                //? FEC_MockupEndpoint.GET_LOAN_BASIC_INFO_ENDPOINT_MOCKUP
                //: (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
                    
            String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;


            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE,
                apiConfig?.FEC_SOAP_Action__c, null, soapBody
            );

            responseLog = new ResponseLog(
                'FEC_GetLoanBasicInfo',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapBody,
                res,
                null
            );

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

        } catch (Exception ex) {
            if (responseLog != null) {
                responseLog.errorMessage = ex.getMessage();
            }
            // System.debug('### GET LOAN BASIC INFO ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // BUILD SOAP BODY
    // =========================================================================
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNumber
    ) {

        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope =
            doc.createRootElement(
                'soapenv:Envelope',
                null,
                null
            );

        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:cif', 'http://fecredit.com.vn/CIF_LoanInfo');

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('cif:GetLoanBasicInfo', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('TransID', null, null)
            .addTextNode(transId);
        sys.addChildElement('RequestorID', null, null)
            .addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null)
            .addTextNode(dateTimeStr);
        action.addChildElement('ContractNumber', null, null)
            .addTextNode(contractNumber);

        return doc.toXmlString();
    }


    // =========================================================================
    // PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode body = doc.getRootElement()
            .getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);

        Dom.XmlNode resp;
        for (Dom.XmlNode n : body.getChildElements()) {
            resp = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // SYS
        Dom.XmlNode sysNode = resp.getChildElement('Sys', null);
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }

        // LOAN BASIC INFO
        Dom.XmlNode lbiNode = resp.getChildElement('LoanBasicInfo', null);
        if (lbiNode != null) {
            result.LoanBasicInfo = new LoanBasicInfo();
            result.LoanBasicInfo.Loan = parseLoan(lbiNode.getChildElement('Loan', null));
            result.LoanBasicInfo.RepaymentFeeOverdue =
                parseRepaymentFeeOverdue(lbiNode.getChildElement('RepaymentFeeOverdue', null));
            result.LoanBasicInfo.InterestOnOverdueInterest =
                parseInterestOnOverdueInterest(lbiNode.getChildElement('InterestOnOverdueInterest', null));
            result.LoanBasicInfo.Product =
                parseProduct(lbiNode.getChildElement('Product', null));
            result.LoanBasicInfo.TerminationSimulation =
                parseTerminationSimulation(lbiNode.getChildElement('TerminationSimulation', null));
            result.LoanBasicInfo.PassDue =
                parsePassDue(lbiNode.getChildElement('PassDue', null));
            result.LoanBasicInfo.PaymentHistories =
                parsePaymentHistories(lbiNode.getChildElement('PaymentHistories', null));
            result.LoanBasicInfo.RepaymentSchedules =
                parseRepaymentSchedules(lbiNode.getChildElement('RepaymentSchedules', null));
        }

        return result;
    }

    // =========================================================================
    // PARSE HELPERS
    // =========================================================================
    private static Loan parseLoan(Dom.XmlNode n) {
        if (n == null) return null;
        Loan l = new Loan();
        l.ApplicationID = FEC_CommonUltils.getXmlValue(n, 'ApplicationID');
        l.ContractNumber = FEC_CommonUltils.getXmlValue(n, 'ContractNumber');
        l.ContractType = FEC_CommonUltils.getXmlValue(n, 'ContractType');
        l.ContractStatus = FEC_CommonUltils.getXmlValue(n, 'ContractStatus');
        String soldStr = FEC_CommonUltils.getXmlValue(n, 'SoldStatus');
        l.SoldStatus = String.isBlank(soldStr) ? null : soldStr.toLowerCase() == 'true';
        l.AgreementDate = FEC_CommonUltils.xmlValToDate(n, 'AgreementDate');
        l.DisbursalDate = FEC_CommonUltils.xmlValToDate(n, 'DisbursalDate');
        l.DisbursalDealerName = FEC_CommonUltils.getXmlValue(n, 'DisbursalDealerName');
        l.AssetCost = FEC_CommonUltils.xmlValToDecimal(n, 'AssetCost');
        l.AssetDescription = FEC_CommonUltils.getXmlValue(n, 'AssetDescription');
        l.TotalInstallmentAmount = FEC_CommonUltils.xmlValToDecimal(n, 'TotalInstallmentAmount');
        l.CCCode = FEC_CommonUltils.getXmlValue(n, 'CCCode');
        l.CCName = FEC_CommonUltils.getXmlValue(n, 'CCName');
        l.SecurityDeposit = FEC_CommonUltils.xmlValToDecimal(n, 'SecurityDeposit');
        l.SysCalcChargeAmount = FEC_CommonUltils.xmlValToDecimal(n, 'SysCalcChargeAmount');
        l.ChargeAmtCollected = FEC_CommonUltils.xmlValToDecimal(n, 'ChargeAmtCollected');
        l.ChargeWaived = FEC_CommonUltils.xmlValToDecimal(n, 'ChargeWaived');
        l.OutstandingChargeAmount = FEC_CommonUltils.xmlValToDecimal(n, 'OutstandingChargeAmount');
        l.Purpose = FEC_CommonUltils.getXmlValue(n, 'Purpose');
        l.CompanyName = FEC_CommonUltils.getXmlValue(n, 'CompanyName');
        return l;
    }

    private static RepaymentFeeOverdue parseRepaymentFeeOverdue(Dom.XmlNode n) {
        if (n == null) return null;
        RepaymentFeeOverdue r = new RepaymentFeeOverdue();
        r.AssessedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'AssessedAmount');
        r.CollectedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'CollectedAmount');
        r.WaivedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'WaivedAmount');
        r.OutstandingAmount = FEC_CommonUltils.xmlValToDecimal(n, 'OutstandingAmount');
        return r;
    }

    private static InterestOnOverdueInterest parseInterestOnOverdueInterest(Dom.XmlNode n) {
        if (n == null) return null;
        InterestOnOverdueInterest i = new InterestOnOverdueInterest();
        i.AssessedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'AssessedAmount');
        i.CollectedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'CollectedAmount');
        i.WaivedAmount = FEC_CommonUltils.xmlValToDecimal(n, 'WaivedAmount');
        i.OutstandingAmount = FEC_CommonUltils.xmlValToDecimal(n, 'OutstandingAmount');
        return i;
    }

    private static Product parseProduct(Dom.XmlNode n) {
        if (n == null) return null;
        Product p = new Product();
        p.LoanAmount = FEC_CommonUltils.xmlValToDecimal(n, 'LoanAmount');
        p.Rate = FEC_CommonUltils.xmlValToDecimal(n, 'Rate');
        p.RepaymentFee = FEC_CommonUltils.xmlValToDecimal(n, 'RepaymentFee');
        p.EMI = FEC_CommonUltils.xmlValToDecimal(n, 'EMI');
        p.Tenure = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(n, 'Tenure'));
        p.FirstPaymentDate = FEC_CommonUltils.xmlValToDate(n, 'FirstPaymentDate');
        p.LastPaymentDate = FEC_CommonUltils.xmlValToDate(n, 'LastPaymentDate');
        p.Product = FEC_CommonUltils.getXmlValue(n, 'Product');
        p.Scheme = FEC_CommonUltils.getXmlValue(n, 'Scheme');
        p.InsuranceAmount = FEC_CommonUltils.xmlValToDecimal(n, 'InsuranceAmount');
        p.Tennure = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(n, 'Tennure'));
        p.ClosureDate = FEC_CommonUltils.xmlValToDate(n, 'ClosureDate');
        p.ChargeOffDate = FEC_CommonUltils.xmlValToDate(n, 'ChargeOffDate');
        p.PrincipalDue = FEC_CommonUltils.xmlValToDecimal(n, 'PrincipalDue');
        p.InterestDue = FEC_CommonUltils.xmlValToDecimal(n, 'InterestDue');
        return p;
    }

    private static TerminationSimulation parseTerminationSimulation(Dom.XmlNode n) {
        if (n == null) return null;
        TerminationSimulation t = new TerminationSimulation();
        t.ExcessAmounts = FEC_CommonUltils.xmlValToDecimal(n, 'ExcessAmounts');
        t.NextDueDate = FEC_CommonUltils.xmlValToDate(n, 'NextDueDate');
        return t;
    }

    private static PassDue parsePassDue(Dom.XmlNode n) {
        if (n == null) return null;
        PassDue p = new PassDue();
        p.DPD = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(n, 'DPD'));
        p.ResponsibleUnit = FEC_CommonUltils.getXmlValue(n, 'ResponsibleUnit');
        p.TotalOverdueAmount = FEC_CommonUltils.xmlValToDecimal(n, 'TotalOverdueAmount');
        p.OverduePenalty = FEC_CommonUltils.xmlValToDecimal(n, 'OverduePenalty');
        return p;
    }

    private static List<PaymentHistory> parsePaymentHistories(Dom.XmlNode n) {
        List<PaymentHistory> listData = new List<PaymentHistory>();
        if (n == null) return listData;
        for (Dom.XmlNode p : n.getChildElements()) {
            PaymentHistory ph = new PaymentHistory();
            ph.ValueDate = FEC_CommonUltils.xmlValToDate(p, 'ValueDate');
            ph.AmountOfMoney = FEC_CommonUltils.xmlValToDecimal(p, 'AmountOfMoney');
            listData.add(ph);
        }
        return listData;
    }

    private static List<RepaymentSchedule> parseRepaymentSchedules(Dom.XmlNode n) {
        List<RepaymentSchedule> listData = new List<RepaymentSchedule>();
        if (n == null) return listData;
        for (Dom.XmlNode r : n.getChildElements()) {
            RepaymentSchedule rs = new RepaymentSchedule();
            rs.InstallmentNo = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(r, 'InstallmentNo'));
            rs.InstallmentStartDate = FEC_CommonUltils.xmlValToDate(r, 'InstallmentStartDate');
            rs.DueDate = FEC_CommonUltils.xmlValToDate(r, 'DueDate');
            rs.OpeningPrincipal = FEC_CommonUltils.xmlValToDecimal(r, 'OpeningPrincipal');
            rs.EMI = FEC_CommonUltils.xmlValToDecimal(r, 'EMI');
            rs.RepaymentFee = FEC_CommonUltils.xmlValToDecimal(r, 'RepaymentFee');
            rs.InstallmentAmount = FEC_CommonUltils.xmlValToDecimal(r, 'InstallmentAmount');
            rs.Principal = FEC_CommonUltils.xmlValToDecimal(r, 'Principal');
            rs.Interest = FEC_CommonUltils.xmlValToDecimal(r, 'Interest');
            rs.ClosingPrincipal = FEC_CommonUltils.xmlValToDecimal(r, 'ClosingPrincipal');
            listData.add(rs);
        }
        return listData;
    }


    // =========================================================================
    // VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNumber
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
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr})
            );
        }
        if (String.isBlank(contractNumber)) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'ContractNumber'})
            );
        }

        Set<String> validRequestorIds = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
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