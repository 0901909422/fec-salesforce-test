/****************************************************************************************
 * File Name    : FEC_GetRewardEligibility
 * Author       : Quangdv7
 * Date         : 2025-12-16
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-16     Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetRewardEligibility {
    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CMS_RewardWS';
    private static final String MOCKUP_ENDPOINT = 'https://ac989dc3-34ec-4c62-98cf-54ea477582c2.mock.pstmn.io';

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetRewardEligibility(
        String transId,
        String requestorId,
        String dateTimeStr,
        String accountNumber
    ) {
        try {
            validateRequest(transId, requestorId, dateTimeStr, accountNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://esbservice.fecredit.org/CMS_RewardWS/GetRewardEligibility');

            // ================= SOAP REQUEST BODY =================
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:ns1="http://esbservice.fecredit.org/CMS_RewardWS/">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<ns1:GetRewardEligibility>' +
                            '<SysRequest>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</SysRequest>' +
                            '<AccountNumber>' + accountNumber + '</AccountNumber>' +
                        '</ns1:GetRewardEligibility>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException('Reward service response is empty or invalid: '  + res.getStatusCode());
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'Reward service returned error'
                );
            }

            return response;

        } catch (Exception ex) {
            System.debug('### REWARD ERROR: ' + ex.getMessage());
            throw ex;
        }
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
        if (String.isBlank(transId)) {
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

        if (transId.length() > 36) {
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
            throw new CalloutException('RequestorID is null or invalid, "' + requestorId + '" is not type of RequestorID' );
        }

        try {
            String normalized = dateTimeStr
                .replace('T', ' ')
                .replace(' GMT', '');
            Datetime.valueOf(normalized);
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
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

        if (bodyNode == null) {
            throw new CalloutException('Invalid SOAP response: Body not found');
        }

        Dom.XmlNode responseNode = bodyNode.getChildElement(
            'GetRewardEligibilityResponse',
            'http://esbservice.fecredit.org/CMS_RewardWS/'
        );

        if (responseNode == null) {
            throw new CalloutException(
                'Invalid SOAP response: GetRewardEligibilityResponse not found'
            );
        }

        ResponseWrapper result = new ResponseWrapper();

        // ================= SYS RESPONSE =================
        Dom.XmlNode sysNode = responseNode.getChildElement('SysResponse', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = getChildValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = getChildValue(sysNode, 'DateTime');
        result.Sys.Code = toInt(getChildValue(sysNode, 'Code'));
        result.Sys.Description = getChildValue(sysNode, 'Description');

        // ================= MAIN DATA =================
        result.LMSAccount = getChildValue(responseNode, 'LMSAccount');
        result.CustomerName = getChildValue(responseNode, 'CustomerName');
        result.SchemeID = getChildValue(responseNode, 'SchemeID');

        result.EarnedPoints = getDecimal(responseNode, 'EarnedPoints');
        result.BoughtPoints = getDecimal(responseNode, 'BoughtPoints');
        result.BonusPoints = getDecimal(responseNode, 'BonusPoints');
        result.RedeemedPoints = getDecimal(responseNode, 'RedeemedPoints');
        result.ClosedPoints = getDecimal(responseNode, 'ClosedPoints');
        result.CalculatedClosedPoints = getDecimal(responseNode, 'CalculatedClosedPoints');
        result.ExpiredPoints = getDecimal(responseNode, 'ExpiredPoints');
        result.AdjustedInPoints = getDecimal(responseNode, 'AdjustedInPoints');
        result.AdjustedOutPoints = getDecimal(responseNode, 'AdjustedOutPoints');
        result.CTDGrace = getDecimal(responseNode, 'CTDGrace');
        result.CTDTotal = getDecimal(responseNode, 'CTDTotal');
        result.CTDSpendEarned = getDecimal(responseNode, 'CTDSpendEarned');
        result.AvailablePoints = getDecimal(responseNode, 'AvailablePoints');
        result.OutstandingTxn = getDecimal(responseNode, 'OutstandingTxn');
        result.CustomerMobile = getChildValue(responseNode, 'CustomerMobile');

        // ================= REDEMPTION OPTIONS =================
        Dom.XmlNode redemptionNode = responseNode.getChildElement('RedemptionOptions', null);
        if (redemptionNode != null) {
            result.RedemptionOptions = new RedemptionOptions();
            result.RedemptionOptions.EvoucherEligible =
                Boolean.valueOf(getChildValue(redemptionNode, 'EvoucherEligible'));
            result.RedemptionOptions.CashbackEligible =
                Boolean.valueOf(getChildValue(redemptionNode, 'CashbackEligible'));
            result.RedemptionOptions.MvoucherEligible =
                Boolean.valueOf(getChildValue(redemptionNode, 'MvoucherEligible'));
        }

        // ================= PRODUCTS =================
        Dom.XmlNode productsNode = responseNode.getChildElement('Products', null);
        if (productsNode != null) {
            result.Products = new List<Product>();
            for (Dom.XmlNode pNode : productsNode.getChildElements()) {
                Product p = new Product();
                p.ProductCode = getChildValue(pNode, 'ProductCode');
                p.ProductName = getChildValue(pNode, 'ProductName');
                p.RequiredPoints = getDecimal(pNode, 'RequiredPoints');
                result.Products.add(p);
            }
        }

        return result;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getChildValue(Dom.XmlNode node, String name) {
        if (node == null) return null;
        Dom.XmlNode child = node.getChildElement(name, null);
        return child == null ? null : child.getText();
    }

    private static Decimal getDecimal(Dom.XmlNode node, String name) {
        String val = getChildValue(node, name);
        return String.isBlank(val) ? null : Decimal.valueOf(val);
    }

    private static Integer toInt(String val) {
        return String.isBlank(val) ? null : Integer.valueOf(val);
    }

    // =========================================================================
    // RESPONSE CLASSES
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;

        public String LMSAccount;
        public String CustomerName;
        public String SchemeID;

        public Decimal EarnedPoints;
        public Decimal BoughtPoints;
        public Decimal BonusPoints;
        public Decimal RedeemedPoints;
        public Decimal ClosedPoints;
        public Decimal CalculatedClosedPoints;
        public Decimal ExpiredPoints;
        public Decimal AdjustedInPoints;
        public Decimal AdjustedOutPoints;
        public Decimal CTDGrace;
        public Decimal CTDTotal;
        public Decimal CTDSpendEarned;
        public Decimal AvailablePoints;
        public Decimal OutstandingTxn;

        public RedemptionOptions RedemptionOptions;
        public List<Product> Products;    
        public String CustomerMobile;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class RedemptionOptions {
        public Boolean EvoucherEligible;
        public Boolean CashbackEligible;
        public Boolean MvoucherEligible;
    }
    public class Product {
    public String ProductCode;
    public String ProductName;
    public Decimal RequiredPoints;
}
}