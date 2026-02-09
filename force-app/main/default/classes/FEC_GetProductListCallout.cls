public without sharing class FEC_GetProductListCallout {
    
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://2585e1bc-373f-45b8-8b0b-d25f87bd6422.mock.pstmn.io/CIF_CustomerInfo';
    
    public static CIF_GetProductsListResponse callService(String cifNumber) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            throw new CalloutException('API Setting not found');
        }
        
        String endpoint = apiSetting.FEC_Call_Mock__c
            ? MOCKUP_ENDPOINT
            : apiSetting.FEC_Endpoint__c + ENDPOINT;
        
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader(
            'SOAPAction',
        'GetProductsList'
            );
        req.setTimeout(60000);
        
        req.setBody(buildRequestBody(cifNumber));
        
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'SOAP call failed: ' + res.getStatus() + ' - ' + res.getBody()
                );
        }
        
        return parseResponse(res.getBody());
    }
    
    // =====================
    // Build SOAP Request
    // =====================
    // private static String buildRequestBody(String cifNumber) {
        //     String transId = String.valueOf(UUID.randomUUID());
        //     String dateTime_x = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ssXXX');
        
        //     return
        //         '<?xml version="1.0" encoding="UTF-8"?>' +
        //         '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        //         'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
        //         '<soapenv:Header/>' +
        //         '<soapenv:Body>' +
        //         '<cif:GetProductsList>' +
        //         '<Sys>' +
        //         '<TransID>' + transId + '</TransID>' +
        //         '<RequestorID>ESB</RequestorID>' +
        //         '<DateTime>' + dateTime_x + '</DateTime>' +
        //         '</Sys>' +
        //         '<CIFNumber>' + cifNumber + '</CIFNumber>' +
        //         '</cif:GetProductsList>' +
        //         '</soapenv:Body>' +
        //         '</soapenv:Envelope>';
    // }
    
    private static String buildRequestBody(String cifNumber) {
        String transId = String.valueOf(UUID.randomUUID());
        String dateTime_x = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ssXXX');
        
        Dom.Document doc = new Dom.Document();
        
        // Root Envelope + soapenv namespace
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
        'http://schemas.xmlsoap.org/soap/envelope/',
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
        'http://fecredit.com.vn/CIF_CustomerInfo',
        null
            );
        
        // Sys
        Dom.XmlNode sysNode = getProductsList.addChildElement('Sys', null, null);
        
        sysNode.addChildElement('TransID', null, null)
            .addTextNode(transId);
        
        sysNode.addChildElement('RequestorID', null, null)
            .addTextNode('ESB');
        
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
        'http://schemas.xmlsoap.org/soap/envelope/'
            );
        
        Dom.XmlNode responseNode = body.getChildElement(
            'GetProductsListResponse',
        'http://fecredit.com.vn/CIF_CustomerInfo'
            );
        
        if (responseNode == null) {
            throw new CalloutException('Invalid SOAP response: missing GetProductsListResponse');
        }
        
        CIF_GetProductsListResponse result = new CIF_GetProductsListResponse();
        
        Dom.XmlNode sys = responseNode.getChildElement('Sys', null);
        result.code = getText(sys, 'Code');
        result.description = getText(sys, 'Description');
        result.transId = getText(sys, 'TransID');
        result.dateTime_x = getText(sys, 'DateTime');
        result.cifNumber = getText(responseNode, 'CIFNumber');
        
        result.products = new List<ProductInfo>();
        
        Dom.XmlNode productsNode = responseNode.getChildElement('Products', null);
        if (productsNode != null && result.code == '1') {
            for (Dom.XmlNode productNode : productsNode.getChildElements()) {
                ProductInfo p = new ProductInfo();
                p.productName = getText(productNode, 'ProductName');
                p.productType = getText(productNode, 'ProductType');
                p.dateApplied = getText(productNode, 'DateApplied');
                p.applicationId = getText(productNode, 'ApplicationID');
                p.contractNumber = getText(productNode, 'ContractNumber');
                p.accountNumber = getText(productNode, 'AccountNumber');
                p.cardNumber = getText(productNode, 'CardNumber');
                p.dealId = getText(productNode, 'DealID');
                result.products.add(p);
            }
        }
        
        return result;
    }
    
    private static String getText(Dom.XmlNode parent, String childName) {
        if (parent == null) return null;
        Dom.XmlNode n = parent.getChildElement(childName, null);
        return n == null ? null : n.getText();
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