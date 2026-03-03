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
 
            // ================= SOAP REQUEST BODY =================
            String soapBody = buildSoapBody(
                transId, 
                requestorId, 
                dateTimeStr, 
                accountNumber
                );
                
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Reward_Eligibility');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_REWARD_ELIGIBILITY_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            
            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
            }
 
            ResponseWrapper response = parseResponse(res.getBody());
 
            if (response.Sys != null && response.Sys.Code != 1) {
                throw new CalloutException(
                    String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
                );
            }
 
            return response;
 
        } catch (Exception ex) {
            System.debug('### REWARD ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    /* =====================================================
       SOAP BODY
       ===================================================== */
    private static String buildSoapBody(
        String transId,
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
            'xmlns:ns1',
            'http://esbservice.fecredit.org/CMS_RewardWS/'
        );

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action =
            body.addChildElement('ns1:GetRewardEligibility', null, null);

        Dom.XmlNode sys =
            action.addChildElement('Sys', null, null);

        sys.addChildElement('transId', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        action.addChildElement('accountNumber', null, null)
              .addTextNode(accountNumber);

        return doc.toXmlString();
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
        if (String.isBlank(transId) || transId.length() > 36) {
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
            String normalized = dateTimeStr
                .replace('T', ' ')
                .replace(' GMT', '');
            Datetime.valueOf(normalized);
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
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {
 
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
 
        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
 
        if (bodyNode == null) {
            throw new CalloutException(System.Label.FEC_MSG_Response_Null);
        }
 
        Dom.XmlNode responseNode = bodyNode.getChildElement(
            'GetRewardEligibilityResponse',
            'http://esbservice.fecredit.org/CMS_RewardWS/'
        );
 
        if (responseNode == null) {
            throw new CalloutException(
                System.Label.FEC_MSG_Response_Null
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