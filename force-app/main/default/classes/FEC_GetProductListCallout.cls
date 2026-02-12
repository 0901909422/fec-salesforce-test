public without sharing class FEC_GetProductListCallout {
    private static final String CIF_NS ='http://fecredit.com.vn/CIF_CustomerInfo';
    
    public static CIF_GetProductsListResponse callService(String cifNumber) {
        
        String soapBody = buildRequestBody(cifNumber);
    
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Product_List');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_PRODUCTS_LIST_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
            );
        }

        return parseResponse(res.getBody());
    }
    
    
    private static String buildRequestBody(String cifNumber) {
        String transId = String.valueOf(UUID.randomUUID());
        String dateTime_x = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT);
        
        Dom.Document doc = new Dom.Document();
        
        // Root Envelope + soapenv namespace
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );
        
        // Header
        envelope.addChildElement('soapenv:Header', null, null);
        
        // Body
        Dom.XmlNode body = envelope.addChildElement('soapenv:Body', null, null);
        
        // cif:GetProductsList
        Dom.XmlNode getProductsList =
            body.addChildElement(
            'cif:GetProductsList',
            CIF_NS,
            null
        );
        
        // Sys
        Dom.XmlNode sysNode = getProductsList.addChildElement('Sys', null, null);
        
        sysNode.addChildElement('TransID', null, null)
            .addTextNode(transId);
        
        sysNode.addChildElement('RequestorID', null, null)
            .addTextNode(FEC_ConstantCommon.REQUESTOR_ESB);
        
        sysNode.addChildElement('DateTime', null, null)
            .addTextNode(dateTime_x);
        
        // CIFNumber
        getProductsList.addChildElement('CIFNumber', null, null)
            .addTextNode(cifNumber);
        
        return doc.toXmlString();
    }
    
    
    // =====================
    // Parse SOAP Response
    // =====================
    private static CIF_GetProductsListResponse parseResponse(String xml) {
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        
        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode body = envelope.getChildElement(
            'Body',
            FEC_ConstantCommon.SOAP_ENV
        );
        
        Dom.XmlNode responseNode = body.getChildElement(
            'GetProductsListResponse',
            CIF_NS
        );
        
        if (responseNode == null) {
            throw new CalloutException('Invalid SOAP response: missing GetProductsListResponse');
        }
        
        CIF_GetProductsListResponse result = new CIF_GetProductsListResponse();
        
        Dom.XmlNode sys = responseNode.getChildElement('Sys', null);
        result.code = FEC_CommonUltils.getXmlValue(sys, 'Code');
        result.description = FEC_CommonUltils.getXmlValue(sys, 'Description');
        result.transId = FEC_CommonUltils.getXmlValue(sys, 'TransID');
        result.dateTime_x = FEC_CommonUltils.getXmlValue(sys, 'DateTime');
        result.cifNumber = FEC_CommonUltils.getXmlValue(responseNode, 'CIFNumber');
        
        result.products = new List<ProductInfo>();
        
        Dom.XmlNode productsNode = responseNode.getChildElement('Products', null);
        if (productsNode != null && result.code == '1') {
            for (Dom.XmlNode productNode : productsNode.getChildElements()) {
                ProductInfo p = new ProductInfo();
                p.productName = FEC_CommonUltils.getXmlValue(productNode, 'ProductName');
                p.productType = FEC_CommonUltils.getXmlValue(productNode, 'ProductType');
                p.dateApplied = FEC_CommonUltils.getXmlValue(productNode, 'DateApplied');
                p.applicationId = FEC_CommonUltils.getXmlValue(productNode, 'ApplicationID');
                p.contractNumber = FEC_CommonUltils.getXmlValue(productNode, 'ContractNumber');
                p.accountNumber = FEC_CommonUltils.getXmlValue(productNode, 'AccountNumber');
                p.cardNumber = FEC_CommonUltils.getXmlValue(productNode, 'CardNumber');
                p.dealId = FEC_CommonUltils.getXmlValue(productNode, 'DealID');
                result.products.add(p);
            }
        }
        
        return result;
    }
    
    // =====================
    // DTO Classes
    // =====================
    public class CIF_GetProductsListResponse {
        public String transId;
        public String dateTime_x;
        public String code;
        public String description;
        public String cifNumber;
        public List<ProductInfo> products;
    }
    
    public class ProductInfo {
        public String productName;
        public String productType;
        public String dateApplied;
        public String applicationId;
        public String contractNumber;
        public String accountNumber;
        public String cardNumber;
        public String dealId;
    }
}