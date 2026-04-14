@isTest
global with sharing class FEC_CMSIPPBlockWSMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        Dom.Document doc = new Dom.Document();
        
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            null,
            null
        );
        
        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );
        
        
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        

        Dom.XmlNode action =
            body.addChildElement('NS1:CMSIPPBlockResponse', null, null);

            action.setAttribute(
            'xmlns:NS1',
            'http://fecredit.com.vn/CMS_IPP_BlockWS'
        );
        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode('123456');
        sys.addChildElement('RequestorID', null, null).addTextNode('12345678');
        sys.addChildElement('DateTime', null, null).addTextNode('2026-04-01T16:26:15.962');

          // BankBranch
        action.addChildElement('AvailableCredit', null, null).addTextNode('123');
        System.debug('doc: ' +json.serialize(doc.toXmlString()));
        res.setBody(doc.toXmlString());
        return res;
    }

}