public with sharing class FEC_CMSRewardRedeemService {
    public static final String API_CONFIG_NAME_MVOUCHER = 'FEC_Generate_MVoucher';
    public static final String API_CONFIG_NAME_EVOUCHER = 'FEC_Generate_EVoucher';
    public static final String API_CONFIG_NAME_CASHBACK = 'FEC_Generate_Cashback';
    private static final String SERVICE_NS = 'http://esbservice.fecredit.org/CMS_RewardWS/';

    @TestVisible private static String testEndpointOverride;
    @TestVisible private static String testSoapActionOverride;

    public class RedeemRequest {
        @AuraEnabled public String transId;
        @AuraEnabled public String requestorId;
        @AuraEnabled public String dateTimeStr;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerMobile;
        @AuraEnabled public String ticketId;
        @AuraEnabled public Decimal ticketPoint;
        @AuraEnabled public String adjustmentIndicator;
        @AuraEnabled public String productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productType;
        @AuraEnabled public String priceId;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Decimal cashback;
        @AuraEnabled public Integer redeemTypeId;
    }

    public class RedeemResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Integer httpStatus;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public String transId;
        @AuraEnabled public String dateTimeStr;
        @AuraEnabled public Integer status;
        @AuraEnabled public String description;
        @AuraEnabled public String redeemRefId;
        @AuraEnabled public String voucherRefId;
        @AuraEnabled public Decimal availablePoints;
        @AuraEnabled public String voucherLink;
    }

    @AuraEnabled
    public static RedeemResult generateMvoucher(RedeemRequest req) {
        return execute(req, 'GenerateMvoucher', API_CONFIG_NAME_MVOUCHER, FEC_ConstantCommon.PRODUCT_TYPE_MVOUCHER);
    }

    @AuraEnabled
    public static RedeemResult generateEvoucher(RedeemRequest req) {
        return execute(req, 'GenerateEvoucher', API_CONFIG_NAME_EVOUCHER, FEC_ConstantCommon.PRODUCT_TYPE_EVOUCHER);
    }

    @AuraEnabled
    public static RedeemResult generateCashback(RedeemRequest req) {
        return execute(req, 'GenerateCashback', API_CONFIG_NAME_CASHBACK, FEC_ConstantCommon.PRODUCT_TYPE_CASHBACK);
    }

    private static RedeemResult execute(
        RedeemRequest req,
        String actionName,
        String apiConfigName,
        String expectedProductType
    ) {
        RedeemResult result = new RedeemResult();
        result.success = false;

        String validationError = validateRequest(req, expectedProductType);
        if (String.isNotBlank(validationError)) {
            return error(validationError);
        }

        String endpoint = null;
        String soapAction = null;
        try {
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(apiConfigName);

            endpoint = buildEndpoint(apiSetting, apiConfig);
            soapAction = (apiConfig != null) ? apiConfig.FEC_SOAP_Action__c : null;
            if (String.isNotBlank(testEndpointOverride)) {
                endpoint = testEndpointOverride;
            }
            if (String.isNotBlank(testSoapActionOverride)) {
                soapAction = testSoapActionOverride;
            }

            if (String.isBlank(endpoint)) {
                return error(System.Label.FEC_MSG_Endpoint_Null);
            }

            String soapBody = buildSoapBody(req, actionName);
            HttpResponse res = FEC_CommonUltils.calloutApi(
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_ConstantCommon.API_CONTENT_TYPE,
                soapAction,
                null,
                soapBody
            );

            safeLog(apiConfigName, endpoint, FEC_ConstantCommon.API_METHOD_POST, soapBody, res, null);

            if (res == null) {
                return error(System.Label.FEC_MSG_No_Response);
            }

            result.httpStatus = res.getStatusCode();
            result.rawResponse = res.getBody();
            if (res.getStatusCode() != FEC_ConstantCommon.SUCCESS_CODE_200_NUM) {
                result.success = false;
                result.errorMessage = 'HTTP Error: ' + res.getStatusCode();
                return result;
            }

            RedeemResult parsed = parseResponse(res.getBody());
            parsed.httpStatus = res.getStatusCode();
            return parsed;
        } catch (Exception ex) {
            safeLog(
                apiConfigName,
                endpoint,
                FEC_ConstantCommon.API_METHOD_POST,
                FEC_CommonUltils.serializeSafe(req),
                null,
                ex.getMessage()
            );
            return error(ex.getMessage());
        }
    }

    private static String buildEndpoint(FEC_API_Setting__c apiSetting, FEC_API_Config__mdt apiConfig) {
        String base = (apiSetting != null && String.isNotBlank(apiSetting.FEC_Endpoint__c))
            ? apiSetting.FEC_Endpoint__c
            : FEC_ConstantCommon.STR_EMPTY;
        String path = (apiConfig != null && String.isNotBlank(apiConfig.FEC_Endpoint__c))
            ? apiConfig.FEC_Endpoint__c
            : FEC_ConstantCommon.STR_EMPTY;
        return base + path;
    }

    private static String buildSoapBody(RedeemRequest req, String actionName) {
        String transId = String.isNotBlank(req.transId)
            ? req.transId
            : FEC_CommonUltils.generateTransactionUUID();
        String requestorId = String.isNotBlank(req.requestorId)
            ? req.requestorId
            : FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;
        String dateTimeStr = String.isNotBlank(req.dateTimeStr)
            ? req.dateTimeStr
            : Datetime.now().formatGMT(FEC_ConstantCommon.DATETIME_FORMAT_GMT);
        String adjustmentIndicator = String.isNotBlank(req.adjustmentIndicator)
            ? req.adjustmentIndicator
            : '+';
        Decimal cashback = req.cashback == null ? 0 : req.cashback;

        Dom.Document doc = new Dom.Document();
        Dom.XmlNode envelope = doc.createRootElement('soapenv:Envelope', null, null);
        envelope.setAttribute('xmlns:soapenv', FEC_ConstantCommon.SOAP_ENV);
        envelope.setAttribute('xmlns:ns1', SERVICE_NS);

        envelope.addChildElement('soapenv:Header', null, null);
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        Dom.XmlNode actionNode = body.addChildElement('ns1:' + actionName, null, null);

        Dom.XmlNode sysRequest = actionNode.addChildElement('SysRequest', null, null);
        sysRequest.addChildElement('TransID', null, null).addTextNode(transId);
        sysRequest.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sysRequest.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        actionNode.addChildElement('AccountNumber', null, null).addTextNode(req.accountNumber);
        actionNode.addChildElement('CustomerName', null, null).addTextNode(req.customerName);
        actionNode.addChildElement('CustomerMobile', null, null).addTextNode(req.customerMobile);
        actionNode.addChildElement('TicketID', null, null).addTextNode(req.ticketId);
        actionNode.addChildElement('TicketPoint', null, null).addTextNode(String.valueOf(req.ticketPoint));
        actionNode.addChildElement('AdjustmentIndicator', null, null).addTextNode(adjustmentIndicator);

        Dom.XmlNode productNode = actionNode.addChildElement('Product', null, null);
        productNode.addChildElement('ID', null, null).addTextNode(req.productId);
        productNode.addChildElement('Name', null, null).addTextNode(req.productName);
        productNode.addChildElement('Type', null, null).addTextNode(req.productType);
        productNode.addChildElement('PriceID', null, null).addTextNode(req.priceId);
        productNode.addChildElement('Price', null, null).addTextNode(String.valueOf(req.price));
        productNode.addChildElement('Cashback', null, null).addTextNode(String.valueOf(cashback));
        productNode.addChildElement('RedeemTypeID', null, null).addTextNode(String.valueOf(req.redeemTypeId));

        return doc.toXmlString();
    }

    private static RedeemResult parseResponse(String responseBody) {
        RedeemResult result = new RedeemResult();
        result.rawResponse = responseBody;
        result.success = false;

        if (String.isBlank(responseBody)) {
            result.errorMessage = System.Label.FEC_MSG_Response_Null;
            return result;
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(FEC_CommonUltils.cleanResponseBody(responseBody));

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
            if (bodyNode == null) {
                result.errorMessage = System.Label.FEC_MSG_Response_Null;
                return result;
            }

            Dom.XmlNode responseNode = firstNonNull(
                FEC_CommonUltils.findChildByName(bodyNode, 'GenerateMvoucherResponse'),
                FEC_CommonUltils.findChildByName(bodyNode, 'GenerateEvoucherResponse'),
                FEC_CommonUltils.findChildByName(bodyNode, 'GenerateCashbackResponse')
            );
            if (responseNode == null) {
                Dom.XmlNode fault = bodyNode.getChildElement('Fault', FEC_ConstantCommon.SOAP_ENV);
                if (fault != null) {
                    result.errorMessage = FEC_CommonUltils.getValueSafe(fault, 'faultstring');
                } else {
                    result.errorMessage = System.Label.FEC_MSG_Unexpected_SOAP_Response;
                }
                return result;
            }

            Dom.XmlNode sysNode = FEC_CommonUltils.findChildByName(responseNode, 'SysResponse');
            if (sysNode != null) {
                result.transId = FEC_CommonUltils.getValueSafe(sysNode, 'TransID');
                result.dateTimeStr = FEC_CommonUltils.getValueSafe(sysNode, 'DateTime');
                result.status = FEC_CommonUltils.toInt(FEC_CommonUltils.getValueSafe(sysNode, 'Status'));
                result.description = FEC_CommonUltils.getValueSafe(sysNode, 'Description');
            }

            result.redeemRefId = FEC_CommonUltils.getValueSafe(responseNode, 'RedeemRefID');
            result.voucherRefId = FEC_CommonUltils.getValueSafe(responseNode, 'VoucherRefID');
            result.voucherLink = FEC_CommonUltils.getValueSafe(responseNode, 'VoucherLink');
            result.availablePoints = toDecimalSafe(FEC_CommonUltils.getValueSafe(responseNode, 'AvailablePoints'));
            result.success = (result.status != null && result.status == 0);

            if (!result.success && String.isBlank(result.errorMessage)) {
                result.errorMessage = result.description;
            }
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }

        return result;
    }

    private static String validateRequest(RedeemRequest req, String expectedProductType) {
        if (req == null) {
            return String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ FEC_ConstantCommon.FEC_CATEGORY_REQUEST });
        }
        if (String.isBlank(req.accountNumber) ||
            String.isBlank(req.customerName) ||
            String.isBlank(req.customerMobile) ||
            String.isBlank(req.ticketId) ||
            req.ticketPoint == null ||
            String.isBlank(req.productId) ||
            String.isBlank(req.productName) ||
            String.isBlank(req.productType) ||
            String.isBlank(req.priceId) ||
            req.price == null ||
            req.redeemTypeId == null) {
            return System.Label.FEC_MISSING_REQUIRED_FIELDS_MSG;
        }
        if (String.isNotBlank(expectedProductType) && req.productType != expectedProductType) {
            return 'Invalid product type. Expected: ' + expectedProductType;
        }
        if (String.isNotBlank(req.adjustmentIndicator) &&
            req.adjustmentIndicator != '+' &&
            req.adjustmentIndicator != '-') {
            return 'AdjustmentIndicator must be "+" or "-".';
        }
        return null;
    }

    private static Decimal toDecimalSafe(String v) {
        if (String.isBlank(v)) {
            return null;
        }
        try {
            return Decimal.valueOf(v);
        } catch (Exception e) {
            return null;
        }
    }

    private static void safeLog(
        String apiName,
        String endpoint,
        String method,
        String requestBody,
        HttpResponse response,
        String errorMessage
    ) {
        try {
            if (response == null) {
                HttpResponse fallback = new HttpResponse();
                fallback.setStatusCode(FEC_ConstantCommon.ERROR_CODE_500_NUM);
                fallback.setBody(errorMessage);
                FEC_CommonUltils.logApi(apiName, endpoint, method, requestBody, fallback, errorMessage);
            } else {
                FEC_CommonUltils.logApi(apiName, endpoint, method, requestBody, response, errorMessage);
            }
        } catch (Exception e) {
            System.debug('FEC_CMSRewardRedeemService safeLog error: ' + e.getMessage());
        }
    }

    private static RedeemResult error(String msg) {
        RedeemResult err = new RedeemResult();
        err.success = false;
        err.errorMessage = msg;
        return err;
    }

    private static Dom.XmlNode firstNonNull(Dom.XmlNode a, Dom.XmlNode b, Dom.XmlNode c) {
        if (a != null) {
            return a;
        }
        if (b != null) {
            return b;
        }
        return c;
    }
}