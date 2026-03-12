/****************************************************************************************
 * File Name    : FEC_GetLoanSecInfo
 * Author       : toannd61
 * Description  : Get Loan Sec Information from CIF_LoanInfo service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-03-09     toannd61            Create
****************************************************************************************/

public with sharing class FEC_GetLoanSecInfo {

    private static ResponseLog responseLog;

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public LoanSecInfo LoanSecInfo;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class LoanSecInfo {
        public Loan Loan;
        public List<PaymentHistory> PaymentHistories;
        public PassDue PassDue;
        public String TerminationSimulation;
        public String LPI;
        public String ReversalTransactions;
    }

    // ===================== PASS DUE =====================
    public class PassDue {
        public Integer InstallmentsRemaining;
        public String ResponsiblePerson;
        public Date DateAssigned;
    }

    // ===================== LOAN =====================
    public class Loan {
        public Decimal TotalInstallmentPaid;
        public Decimal TotalPrincipalPaid;
        public Decimal TotalInterestPaid;
        public Decimal RestExcessAmounts;
        public Decimal PrincipalOutstanding;
        public Decimal AdditionalAmount;
    }

    // ===================== PAYMENT HISTORY =====================
    public class PaymentHistory {
        public Date BookingDate;
        public Decimal PrinciplePaid;
        public Decimal InterestPaid;
        public Decimal RepaymentFeePaid;
        public Decimal PenaltyFee;
        public Decimal PenaltyFeePaid;
        public Date ValueDate;
        public Decimal AmountOfMoney;
        public String ChkNo;
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
    // PUBLIC METHOD - Simplified
    // =========================================================================
    public static ResponseWrapper getLoanSecInfo(String contractNumber) {
        String transId = UUID.randomUUID().toString();
        String requestorId = FEC_ConstantCommon.REQUESTOR_CRM;
        String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.DATETIME_FORMAT);

        return callGetLoanSecInfo(transId, requestorId, dateTimeStr, contractNumber);
    }

    // =========================================================================
    // PUBLIC METHOD - Full parameters
    // =========================================================================
    public static ResponseWrapper callGetLoanSecInfo(
        String transId,
        String requestorId,
        String dateTimeStr,
        String contractNumber
    ) {
        try {
            validateRequest(transId, requestorId, dateTimeStr, contractNumber);

            String soapBody = buildSoapBody(transId, requestorId, dateTimeStr, contractNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Loan_Sec_Info');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_LOAN_SEC_INFO_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE,
                apiConfig?.FEC_SOAP_Action__c, null, soapBody
            );

            responseLog = new ResponseLog(
                'FEC_GetLoanSecInfo',
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

            logApiResponse();
            return response;

        } catch (Exception ex) {
            System.debug('### GET LOAN SEC INFO ERROR: ' + ex.getMessage());
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
            doc.createRootElement('soapenv:Envelope', null, null);

        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:cif', 'http://fecredit.com.vn/CIF_LoanInfo');

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('cif:GetLoanSecInfo', null, null);

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

        // LOAN SEC INFO
        Dom.XmlNode lsiNode = resp.getChildElement('LoanSecInfo', null);
        if (lsiNode != null) {
            result.LoanSecInfo = new LoanSecInfo();
            result.LoanSecInfo.Loan = parseLoan(lsiNode.getChildElement('Loan', null));
            result.LoanSecInfo.PaymentHistories =
                parsePaymentHistories(lsiNode.getChildElement('PaymentHistories', null));
            result.LoanSecInfo.PassDue =
                parsePassDue(lsiNode.getChildElement('PassDue', null));
            result.LoanSecInfo.TerminationSimulation =
                FEC_CommonUltils.getXmlValue(lsiNode, 'TerminationSimulation');
            result.LoanSecInfo.LPI =
                FEC_CommonUltils.getXmlValue(lsiNode, 'LPI');
            result.LoanSecInfo.ReversalTransactions =
                FEC_CommonUltils.getXmlValue(lsiNode, 'ReversalTransactions');
        }

        return result;
    }

    // =========================================================================
    // PARSE HELPERS
    // =========================================================================
    private static Loan parseLoan(Dom.XmlNode n) {
        if (n == null) return null;
        Loan l = new Loan();
        l.TotalInstallmentPaid = FEC_CommonUltils.xmlValToDecimal(n, 'TotalInstallmentPaid');
        l.TotalPrincipalPaid = FEC_CommonUltils.xmlValToDecimal(n, 'TotalPrincipalPaid');
        l.TotalInterestPaid = FEC_CommonUltils.xmlValToDecimal(n, 'TotalInterestPaid');
        l.RestExcessAmounts = FEC_CommonUltils.xmlValToDecimal(n, 'RestExcessAmounts');
        l.PrincipalOutstanding = FEC_CommonUltils.xmlValToDecimal(n, 'PrincipalOutstanding');
        l.AdditionalAmount = FEC_CommonUltils.xmlValToDecimal(n, 'AdditionalAmount');
        return l;
    }

    private static PassDue parsePassDue(Dom.XmlNode n) {
        if (n == null) return null;
        PassDue p = new PassDue();
        p.InstallmentsRemaining = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(n, 'InstallmentsRemaining'));
        p.ResponsiblePerson = FEC_CommonUltils.getXmlValue(n, 'ResposiblePerson');
        p.DateAssigned = FEC_CommonUltils.xmlValToDate(n, 'DateAssgined');
        return p;
    }

    private static List<PaymentHistory> parsePaymentHistories(Dom.XmlNode n) {
        List<PaymentHistory> listData = new List<PaymentHistory>();
        if (n == null) return listData;
        for (Dom.XmlNode p : n.getChildElements()) {
            PaymentHistory ph = new PaymentHistory();
            ph.BookingDate = FEC_CommonUltils.xmlValToDate(p, 'BookingDate');
            ph.PrinciplePaid = FEC_CommonUltils.xmlValToDecimal(p, 'PrinciplePaid');
            ph.InterestPaid = FEC_CommonUltils.xmlValToDecimal(p, 'InterestPaid');
            ph.RepaymentFeePaid = FEC_CommonUltils.xmlValToDecimal(p, 'RepaymentFeePaid');
            ph.PenaltyFee = FEC_CommonUltils.xmlValToDecimal(p, 'PenaltyFee');
            ph.PenaltyFeePaid = FEC_CommonUltils.xmlValToDecimal(p, 'PenaltyFeePaid');
            ph.ValueDate = FEC_CommonUltils.xmlValToDate(p, 'ValueDate');
            ph.AmountOfMoney = FEC_CommonUltils.xmlValToDecimal(p, 'AmountOfMoney');
            ph.ChkNo = FEC_CommonUltils.getXmlValue(p, 'ChkNo');
            listData.add(ph);
        }
        return listData;
    }

    // =========================================================================
    // LOGGING
    // =========================================================================
    private static void logApiResponse() {
        if (responseLog != null) {
            FEC_CommonUltils.logApi(
                responseLog.apiName,
                responseLog.endpoint,
                responseLog.method,
                responseLog.requestBody,
                responseLog.response,
                responseLog.errorMessage
            );
        }
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
}