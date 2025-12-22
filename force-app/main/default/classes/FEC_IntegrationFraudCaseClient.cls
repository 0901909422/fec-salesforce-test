public with sharing class FEC_IntegrationFraudCaseClient {

    public static Boolean useMock = true;
    public static String lastRawResponseXML;

    private static fecSoapFraudcaseServices.BasicHttpBinding_ISCLService initClient() {
        fecSoapFraudcaseServices.BasicHttpBinding_ISCLService client =
            new fecSoapFraudcaseServices.BasicHttpBinding_ISCLService();
        client.endpoint_x = 'callout:FimaFraudService';
        return client;
    }

    // ===============================
    // CREATE FRAUD CASE (MOCK)
    // ===============================
    public static fecSoapFraudcaseServices.CreateFraudCaseResponse_element createCase(
    fecSoapFraudcaseServices.Sys sys,
    fecSoapFraudcaseServices.CustomerInfo customerInfo,
    fecSoapFraudcaseServices.RequestInfo requestInfo,
    fecSoapFraudcaseServices.CreatorInfo creatorInfo
    ) {
        if (useMock) {

            String txnId   = randomTransactionId();
            String caseId  = randomCaseId();
            String dtStr   = nowAsXmlDateTime();
            String xml =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '  <soap:Body>' +
            '    <ns1:CreateFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '      <ns1:Sys>' +
            '        <ns1:TransactionID>' + txnId + '</ns1:TransactionID>' +
            '        <ns1:DateTime>' + dtStr + '</ns1:DateTime>' +
            '        <ns1:Code>1</ns1:Code>' +
            '        <ns1:Description>Create Success</ns1:Description>' +
            '      </ns1:Sys>' +
            '      <ns1:CaseID>'+ caseId +'</ns1:CaseID>' +
            '    </ns1:CreateFraudCaseResponse>' +
            '  </soap:Body>' +
            '</soap:Envelope>';
            
            // String xml =
            // '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            // '  <soap:Body>' +
            // '    <ns1:CreateFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            // '      <ns1:Sys>' +
            // '        <ns1:TransactionID>' + txnId + '</ns1:TransactionID>' +
            // '        <ns1:DateTime>' + dtStr + '</ns1:DateTime>' +
            // '        <ns1:Code>0</ns1:Code>' +
            // '        <ns1:Description>AppId 12046658 exists in FH-500080; AppId 12046658 exists in FH-500067; AppId 12046658 exists in FH-500078; AppId 12046658 exists in FH-500079; AppId 12046658 exists in FH-500081</ns1:Description>' +
            // '      </ns1:Sys>' +            
            // '    </ns1:CreateFraudCaseResponse>' +
            // '  </soap:Body>' +
            // '</soap:Envelope>';

            lastRawResponseXML = xml;

            Dom.Document doc = new Dom.Document();
            doc.load(xml);

            Dom.XmlNode envelope = doc.getRootElement();

            // Body may be soap:Body, Soap:Body, SOAP:Body etc.
            Dom.XmlNode body = null;
            for (Dom.XmlNode c : envelope.getChildElements()) {
                if (c.getName().toLowerCase().endsWith('body')) {
                    body = c;
                    break;
                }
            }
            if (body == null) {
                System.debug('Body not found in SOAP XML');
                return new fecSoapFraudcaseServices.CreateFraudCaseResponse_element();
            }

            // Find CreateFraudCaseResponse
            Dom.XmlNode resp = null;
            for (Dom.XmlNode c : body.getChildElements()) {
                if (c.getName().endsWith('CreateFraudCaseResponse')) {
                    resp = c;
                    break;
                }
            }
            if (resp == null) {
                System.debug('CreateFraudCaseResponse not found');
                return new fecSoapFraudcaseServices.CreateFraudCaseResponse_element();
            }

            fecSoapFraudcaseServices.CreateFraudCaseResponse_element result =
                new fecSoapFraudcaseServices.CreateFraudCaseResponse_element();

            // Parse Sys
            for (Dom.XmlNode c : resp.getChildElements()) {
                String nodeName = c.getName().toLowerCase();
                if (nodeName.endsWith('sys')) {
                    fecSoapFraudcaseServices.SysResponse s = new fecSoapFraudcaseServices.SysResponse();

                    s.TransactionID = getText(c, 'TransactionID');
                    s.Code          = getText(c, 'Code');
                    s.Description   = getText(c, 'Description');

                    String dt = getText(c, 'DateTime');
                    if (dt != null) {
                        // Convert ISO8601 → Apex datetime
                        s.DateTime_x = datetime.valueOfGmt(
                            dt.substring(0,19).replace('T',' ')
                        );
                    }

                    result.Sys = s;
                }
                if (nodeName.endsWith('caseid')) {
                    result.CaseID = c.getText();
                }
            }

            return result;
        }

        // REAL CALL
        return initClient().CreateFraudCase(sys, customerInfo, requestInfo, creatorInfo);
    }

    private static String randomTransactionId() {
        Long seed = Crypto.getRandomInteger();           // Always valid
        Blob input = Blob.valueOf(String.valueOf(seed)); // Convert Long → String → Blob
        Blob digest = Crypto.generateDigest('SHA1', input);
        return EncodingUtil.convertToHex(digest);        // Return hex string
    }
    


    private static String randomCaseId() {
        Integer raw = Math.abs(Crypto.getRandomInteger());
        Integer rnd = Math.mod(raw, 1000000);  // 0–999999, no error
        return 'FH-' + String.valueOf(rnd).leftPad(6, '0');
    }


    private static String nowAsXmlDateTime() {
        return Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    }



    // Helper: get child by name ignoring namespace
    private static String getText(Dom.XmlNode parent, String tag) {
        for (Dom.XmlNode c : parent.getChildElements()) {
            if (c.getName().toLowerCase().endsWith(tag.toLowerCase())) {
                return c.getText();
            }
        }
        return null;
    }



    // ===============================
    // CANCEL FRAUD CASE (MOCK)
    // ===============================
    public static fecSoapFraudcaseServices.CancelFraudCaseResponse_element cancelCase(
        fecSoapFraudcaseServices.Sys sys,
        fecSoapFraudcaseServices.CaseInfo caseInfo,
        fecSoapFraudcaseServices.CreatorInfo creatorInfo
    ) {
        if (useMock) {
            String xml =
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                    '<CancelFraudCaseResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">' +
                        '<Status>Success</Status>' +
                        '<Message>Mock cancel completed</Message>' +
                    '</CancelFraudCaseResponse>' +
                '</soap:Body>' +
            '</soap:Envelope>';

            Dom.Document doc = new Dom.Document();
            doc.load(xml);

            Dom.XmlNode cancelNode = doc.getRootElement()
                .getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/')
                .getChildElement('CancelFraudCaseResponse', 'urn:PegaRULES:SOAP:FraudCase:Services');

            fecSoapFraudcaseServices.CancelFraudCaseResponse_element res =
                new fecSoapFraudcaseServices.CancelFraudCaseResponse_element();
            return res;
        }

        return initClient().CancelFraudCase(sys, caseInfo, creatorInfo);
    }


    // ===============================
    // GET MASTER DATA (MOCK)
    // ===============================
    public static fecSoapFraudcaseServices.GetFraudMasterDataResponse_element getMasterData(
        fecSoapFraudcaseServices.Sys sys
    ) {
        if (useMock) {

            // return mock response object
            String xml = FEC_FraudCaseMockData.getFraudMasterData();
            lastRawResponseXML = xml;
            return buildMockMasterDataResponse(xml);            
        }
        // REAL SOAP CALL
        return initClient().GetFraudMasterData(sys);
    }
   
    private static fecSoapFraudcaseServices.GetFraudMasterDataResponse_element 
    buildMockMasterDataResponse(String xml)
    {
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = getChildIgnoreNS(root, 'Body');
        Dom.XmlNode resp = findChildByEndsWith(body, 'GetFraudMasterDataResponse');

        fecSoapFraudcaseServices.GetFraudMasterDataResponse_element res =
            new fecSoapFraudcaseServices.GetFraudMasterDataResponse_element();

        // ===========================
        // 1) PARSE Sys (to match real SOAP)
        // ===========================
        Dom.XmlNode sysNode = getChildIgnoreNS(resp, 'Sys');
        if (sysNode != null) {
            fecSoapFraudcaseServices.SysResponse sys = 
                new fecSoapFraudcaseServices.SysResponse();

            sys.TransactionID = getXmlValue(sysNode, 'TransactionID');
            sys.Code          = getXmlValue(sysNode, 'Code');
            sys.Description   = getXmlValue(sysNode, 'Description');
            //sys.DateTime      = getXmlValue(sysNode, 'DateTime');

            res.Sys = sys;
        } else {
            // ensure field exists (match real mode)
            res.Sys = new fecSoapFraudcaseServices.SysResponse();
        }

        // ===========================
        // 2) BUILD MasterDataItems[]
        // ===========================
        res.MasterDataItems = new List<fecSoapFraudcaseServices.MasterDataItem>();

        Dom.XmlNode masterNode = getChildIgnoreNS(resp, 'MasterData');
        List<Dom.XmlNode> groups;

        // Support both formats (<MasterData> and direct children)
        if (masterNode != null) {
            groups = masterNode.getChildElements();
        } else {
            groups = resp.getChildElements();
        }

        for (Dom.XmlNode groupNode : groups) {

            if (groupNode.getName().endsWith('Sys')) continue;

            for (Dom.XmlNode node : groupNode.getChildElements()) {

                fecSoapFraudcaseServices.MasterDataItem item =
                    new fecSoapFraudcaseServices.MasterDataItem();

                item.ID       = getXmlValue(node, 'ID');
                item.Name     = getXmlValue(node, 'Name');
                item.NameVN   = getXmlValue(node, 'NameVN');
                item.PosOrder = toDecimal(getXmlValue(node, 'PosOrder'));
                item.ApplyTo  = getXmlValue(node, 'ApplyTo');
                item.Type_x   = getXmlValue(node, 'Type');

                // Match WSDL: children list must exist
                item.Children = new List<fecSoapFraudcaseServices.SclMasterCaseType>();

                // Match WSDL: AdditionalProperties list must exist
                item.AdditionalProperties =
                    new List<fecSoapFraudcaseServices.AdditionalProperty>();

                res.MasterDataItems.add(item);
            }
        }

        return res;
    }


    // --------------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------------
    private static String text(Dom.XmlNode parent, String name) {
        for (Dom.XmlNode c : parent.getChildElements())
            if (c.getName() == name) return c.getText();
        return null;
    }
    private static String getXmlValue(Dom.XmlNode parent, String tag) {
        Dom.XmlNode child = parent.getChildElement(tag, null);
        return (child != null) ? child.getText() : null;
    }
    
    private static Decimal toDecimal(String s) {
        return (s == null) ? null : Decimal.valueOf(s);
    }

    // Helper: convert to integer safely
    private static Integer toInt(String s) {
        return (s == null) ? null : Integer.valueOf(s);
    }
    private static Dom.XmlNode getChildIgnoreNS(Dom.XmlNode node, String name) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName() == name ||
                (c.getName().contains(':') && c.getName().endsWith(name)))
                return c;
        return null;
    }
    private static Dom.XmlNode findChildByEndsWith(Dom.XmlNode node, String suffix) {
        for (Dom.XmlNode c : node.getChildElements())
            if (c.getName().endsWith(suffix)) return c;
        return null;
    }
   
   
}