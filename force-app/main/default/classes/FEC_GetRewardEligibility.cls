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
            req.setHeader('Content-Type', FEC_ConstantCommon.API_CONTENT_TYPE);
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
            FEC_ConstantCommon.REQUESTOR_CRM,
            FEC_ConstantCommon.REQUESTOR_PORTAL,
            FEC_ConstantCommon.REQUESTOR_MOBILE_APP
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
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // ================= MAIN DATA =================
        result.LMSAccount = FEC_CommonUltils.getXmlValue(responseNode, 'LMSAccount');
        result.CustomerName = FEC_CommonUltils.getXmlValue(responseNode, 'CustomerName');
        result.SchemeID = FEC_CommonUltils.getXmlValue(responseNode, 'SchemeID');

        result.EarnedPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'EarnedPoints');
        result.BoughtPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'BoughtPoints');
        result.BonusPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'BonusPoints');
        result.RedeemedPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'RedeemedPoints');
        result.ClosedPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'ClosedPoints');
        result.CalculatedClosedPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'CalculatedClosedPoints');
        result.ExpiredPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'ExpiredPoints');
        result.AdjustedInPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'AdjustedInPoints');
        result.AdjustedOutPoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'AdjustedOutPoints');
        result.CTDGrace = FEC_CommonUltils.xmlValToDecimal(responseNode, 'CTDGrace');
        result.CTDTotal = FEC_CommonUltils.xmlValToDecimal(responseNode, 'CTDTotal');
        result.CTDSpendEarned = FEC_CommonUltils.xmlValToDecimal(responseNode, 'CTDSpendEarned');
        result.AvailablePoints = FEC_CommonUltils.xmlValToDecimal(responseNode, 'AvailablePoints');
        result.OutstandingTxn = FEC_CommonUltils.xmlValToDecimal(responseNode, 'OutstandingTxn');
        result.CustomerMobile = FEC_CommonUltils.getXmlValue(responseNode, 'CustomerMobile');

        // ================= REDEMPTION OPTIONS =================
        Dom.XmlNode redemptionNode = responseNode.getChildElement('RedemptionOptions', null);
        if (redemptionNode != null) {
            result.RedemptionOptions = new RedemptionOptions();
            result.RedemptionOptions.EvoucherEligible =
                Boolean.valueOf(FEC_CommonUltils.getXmlValue(redemptionNode, 'EvoucherEligible'));
            result.RedemptionOptions.CashbackEligible =
                Boolean.valueOf(FEC_CommonUltils.getXmlValue(redemptionNode, 'CashbackEligible'));
            result.RedemptionOptions.MvoucherEligible =
                Boolean.valueOf(FEC_CommonUltils.getXmlValue(redemptionNode, 'MvoucherEligible'));
        }

        // ================= PRODUCTS =================
        Dom.XmlNode productsNode = responseNode.getChildElement('Products', null);
        if (productsNode != null) {
            result.Products = new List<Product>();
            for (Dom.XmlNode pNode : productsNode.getChildElements()) {
                Product p = new Product();
                p.ProductCode = FEC_CommonUltils.getXmlValue(pNode, 'ProductCode');
                p.ProductName = FEC_CommonUltils.getXmlValue(pNode, 'ProductName');
                p.RequiredPoints = FEC_CommonUltils.xmlValToDecimal(pNode, 'RequiredPoints');
                result.Products.add(p);
            }
        }

        return result;
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