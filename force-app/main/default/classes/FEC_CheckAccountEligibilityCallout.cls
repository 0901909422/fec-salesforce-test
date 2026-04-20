/****************************************************************************************
* File Name    : FEC_CheckAccountEligibilityCallout
* Description  : SOAP CheckAccountEligibility (CMS_RewardDebitWS) — Top-up / E-voucher eligibility.
*                Gateway pattern: FEC_API_Setting__c.FEC_Endpoint__c + FEC_API_Config__mdt path.
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
* 1.0      2026-04-15     Cursor              Create
****************************************************************************************/
public with sharing class FEC_CheckAccountEligibilityCallout {
// CMDT phải khớp file FEC_API_Config.FEC_CMS_RewardDebitWS — path /esb/cms/CMS_RewardDebitWS (không dùng FEC_Get_Reward_Eligibility / CMS_RewardWS)
    public static final String API_CONFIG_NAME = 'FEC_CMS_RewardDebitWS';
    private static final String SERVICE_NS = 'http://esbservice.fecredit.org/CMS_RewardDebitWS/';

    // =========================================================================
    // RESPONSE WRAPPERS
    // =========================================================================
    public class RewardDebitProduct {
        @AuraEnabled public Integer productId      { get; set; }
        @AuraEnabled public String  name           { get; set; }
        @AuraEnabled public String  type           { get; set; }
        @AuraEnabled public Integer priceId        { get; set; }
        @AuraEnabled public Decimal price          { get; set; }
        @AuraEnabled public Integer redeemTypeId   { get; set; }
    }

    public class CheckAccountEligibilityResult {
        @AuraEnabled public String  transId        { get; set; }
        @AuraEnabled public String  dateTimeStr    { get; set; }
        @AuraEnabled public Integer status         { get; set; }
        @AuraEnabled public String  description    { get; set; }
        @AuraEnabled public String  customerName   { get; set; }
        @AuraEnabled public String  customerMobile { get; set; }
        @AuraEnabled public Integer availCr        { get; set; }
        @AuraEnabled public List<RewardDebitProduct> products { get; set; }

        @AuraEnabled public Boolean success        { get; set; }
        @AuraEnabled public String  errorMessage { get; set; }
        @AuraEnabled public Integer httpStatus     { get; set; }
    }

    // =========================================================================
    // MAIN CALLOUT
    // =========================================================================
    /**
     * SOAP CheckAccountEligibility for the given card account number (ACCT_NBR).
     */
    @AuraEnabled
    public static CheckAccountEligibilityResult checkAccountEligibility(String accountNumber) {
        CheckAccountEligibilityResult result = new CheckAccountEligibilityResult();
        result.success = false;
        result.products = new List<RewardDebitProduct>();

        String transId = FEC_CommonUltils.generateTransactionId();
        String timestamp = FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.DATETIME_FORMAT);

        try {
            if (String.isBlank(accountNumber)) {
                result.errorMessage = String.format(
                    System.Label.FEC_MSG_Param_Required,
                    new List<String>{ 'Account Number' }
                );
                return result;
            }

            // RequestorID map sang DWCRC.REWARD_NOTELIGIBLE_REQUEST.TICKET_CHANNEL (max 10) — không dùng API_REQUESTOR_ID ('SALESFORE-CSM' = 13 ký tự) → ORA-12899
            Dom.Document doc = buildSoapRequest(transId, FEC_ConstantCommon.REQUESTOR_CRM, timestamp, accountNumber);
            String soapRequest = doc.toXmlString();

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_CONFIG_NAME);

            String endpoint = (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);

            String soapAction = (apiConfig != null && String.isNotBlank(apiConfig.FEC_SOAP_Action__c))
                ? apiConfig.FEC_SOAP_Action__c
                : null;

            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                soapAction,
                null,
                soapRequest
            );

            FEC_CommonUltils.logApi(
                'FEC_CheckAccountEligibilityCallout',
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                soapRequest,
                res,
                null
            );

            if (res != null && res.getStatusCode() == 200) {
                result = parseSoapResponse(res.getBody());
                result.httpStatus = 200;
                if (!result.success && String.isBlank(result.errorMessage)) {
                    result.errorMessage = 'API Status: ' + result.status + ' | ' + result.description;
                }
            } else {
                result.success = false;
                result.httpStatus = (res != null) ? res.getStatusCode() : 0;
                result.errorMessage = (res != null) ? res.getBody() : 'No response from server';
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('### REWARD DEBIT CheckAccountEligibility ERROR: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
    }

    // =========================================================================
    // SOAP REQUEST / RESPONSE
    // =========================================================================
    private static Dom.Document buildSoapRequest(String transId, String requestorId, String timestamp, String acctNbr) {
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:ns1', SERVICE_NS);

        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode action = body.addChildElement('ns1:CheckAccountEligibility', null, null);

        Dom.XmlNode sysRequest = action.addChildElement('SysRequest', null, null);
        sysRequest.addChildElement('TransID', null, null).addTextNode(transId);
        sysRequest.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysRequest.addChildElement('DateTime', null, null).addTextNode(timestamp);

        action.addChildElement('ACCT_NBR', null, null).addTextNode(acctNbr);

        return doc;
    }

    private static CheckAccountEligibilityResult parseSoapResponse(String responseBody) {
        CheckAccountEligibilityResult result = new CheckAccountEligibilityResult();
        result.success = false;
        result.products = new List<RewardDebitProduct>();

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            Dom.XmlNode responseNode = (bodyNode != null)
                ? bodyNode.getChildElement('CheckAccountEligibilityResponse', SERVICE_NS)
                : null;

            if (responseNode == null) {
                responseNode = (bodyNode != null) ? FEC_CommonUltils.findChildByName(bodyNode, 'CheckAccountEligibilityResponse') : null;
            }

            if (responseNode == null) {
                Dom.XmlNode fault = (bodyNode != null) ? bodyNode.getChildElement('Fault', FEC_ConstantCommon.SOAP_ENV) : null;
                if (fault != null) {
                    result.errorMessage = FEC_CommonUltils.getXmlValue(fault, 'faultstring');
                } else {
                    result.errorMessage = 'Unexpected SOAP response (no CheckAccountEligibilityResponse)';
                }
                return result;
            }

            Dom.XmlNode sysNode = responseNode.getChildElement('SysResponse', null);
            if (sysNode == null) {
                sysNode = FEC_CommonUltils.findChildByName(responseNode, 'SysResponse');
            }

            if (sysNode != null) {
                result.transId = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
                result.dateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
                result.status = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Status'));
                result.description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
            }

            result.customerName = FEC_CommonUltils.getXmlValue(responseNode, 'CustomerName');
            if (result.customerName == null) {
                result.customerName = FEC_CommonUltils.getValueSafe(responseNode, 'CustomerName');
            }
            result.customerMobile = FEC_CommonUltils.getXmlValue(responseNode, 'CustomerMobile');
            if (result.customerMobile == null) {
                result.customerMobile = FEC_CommonUltils.getValueSafe(responseNode, 'CustomerMobile');
            }

            result.availCr = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(responseNode, 'AVAIL_CR'));
            if (result.availCr == null) {
                result.availCr = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(responseNode, 'AVAIL_CR'));
            }

            Dom.XmlNode productsNode = responseNode.getChildElement('Products', null);
            if (productsNode == null) {
                productsNode = FEC_CommonUltils.findChildByName(responseNode, 'Products');
            }

            if (productsNode != null) {
                for (Dom.XmlNode child : productsNode.getChildElements()) {
                    if (child == null || child.getName() == null) {
                        continue;
                    }
                    String nm = child.getName();
                    Boolean isProductEl = (nm == 'Product' || nm.endsWith(':Product'));
                    if (!isProductEl) {
                        continue;
                    }
                    RewardDebitProduct p = new RewardDebitProduct();
                    String idStr = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'ID'),
                        FEC_CommonUltils.getValueSafe(child, 'ID')
                    );
                    p.productId = FEC_CommonUltils.toInt(idStr);
                    p.name = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'Name'),
                        FEC_CommonUltils.getValueSafe(child, 'Name')
                    );
                    p.type = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'Type'),
                        FEC_CommonUltils.getValueSafe(child, 'Type')
                    );
                    String priceIdStr = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'PriceID'),
                        FEC_CommonUltils.getValueSafe(child, 'PriceID')
                    );
                    p.priceId = FEC_CommonUltils.toInt(priceIdStr);
                    p.price = FEC_CommonUltils.xmlValToDecimal(child, 'Price');
                    String redeemStr = firstNonBlank(
                        FEC_CommonUltils.getXmlValue(child, 'RedeemTypeID'),
                        FEC_CommonUltils.getValueSafe(child, 'RedeemTypeID')
                    );
                    p.redeemTypeId = FEC_CommonUltils.toInt(redeemStr);
                    result.products.add(p);
                }
            }

            // Spec: SysResponse.Status — 0 = Success
            result.success = (result.status != null && result.status == 0);
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Parsing Error: ' + e.getMessage();
        }

        return result;
    }

    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }
}
