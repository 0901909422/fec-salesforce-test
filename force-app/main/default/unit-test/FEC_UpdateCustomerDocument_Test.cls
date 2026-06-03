/**
 * Unit tests for FEC_UpdateCustomerDocument (SOAP UpdateCustomerDocument callout).
 */
@IsTest
private class FEC_UpdateCustomerDocument_Test {

    private static void ensureApiSettings() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    @TestSetup
    static void setupData() {
        ensureApiSettings();
    }

    private static FEC_UpdateCustomerDocument.UpdateDocumentRequest buildValidRequest() {
        FEC_UpdateCustomerDocument.UpdateDocumentRequest req =
            new FEC_UpdateCustomerDocument.UpdateDocumentRequest();
        req.CIFNumber = 'CIF001';
        req.DocumentID = 'DOC001';
        req.DocumentType = 'NationalID';
        req.IssueDate = '2020-01-15';
        req.IDDocumentNumber = '001234567890';
        req.ExpirationDate = '2030-01-15';
        req.IssuePlace = 'Ha Noi';
        req.OmnidocsLink = 'https://omni.example/doc/1';
        return req;
    }

    private class SoapSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><TransID>T123</TransID><DateTime>2026-01-01T00:00:00</DateTime>' +
                '<Code>0</Code><Description>Success</Description></Sys>' +
                '</cif:UpdateCustomerDocumentResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class SoapNoTransIdMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><Code>0</Code><Description>OK</Description></Sys>' +
                '</cif:UpdateCustomerDocumentResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class SoapFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
                '<Sys><TransID>T999</TransID><Code>1</Code><Description>Failed</Description></Sys>' +
                '</cif:UpdateCustomerDocumentResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class ThrowingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    @IsTest
    static void testGenerateTransIdAndFormatTimestamp() {
        Test.startTest();
        String transId = FEC_UpdateCustomerDocument.generateTransId();
        String timestamp = FEC_UpdateCustomerDocument.formatTimestamp();
        Test.stopTest();

        System.assertNotEquals(null, transId);
        System.assert(String.isNotBlank(transId));
        System.assert(String.isNotBlank(timestamp));
        System.assert(timestamp.contains('T'));
    }

    @IsTest
    static void testBuildEnvelope_IncludesOptionalFieldsAndEscapesXml() {
        FEC_UpdateCustomerDocument.UpdateDocumentRequest req = buildValidRequest();
        req.CIFNumber = 'CIF&Co';
        req.IssuePlace = 'City <A> "Main"';

        Test.startTest();
        String envelope = FEC_UpdateCustomerDocument.buildEnvelope(
            req,
            FEC_UpdateCustomerDocument.generateTransId(),
            FEC_UpdateCustomerDocument.formatTimestamp()
        );
        Test.stopTest();

        System.assert(envelope.contains('CIF&amp;Co'));
        System.assert(envelope.contains('&lt;A&gt;'));
        System.assert(envelope.contains('&quot;Main&quot;'));
        System.assert(envelope.contains('<IDDocumentNumber>'));
        System.assert(envelope.contains('<OmnidocsLink>'));
        System.assert(envelope.contains('<RequestorID>APS</RequestorID>'));
    }

    @IsTest
    static void testBuildEnvelope_OmitsNullOptionalFields() {
        FEC_UpdateCustomerDocument.UpdateDocumentRequest req =
            new FEC_UpdateCustomerDocument.UpdateDocumentRequest();
        req.CIFNumber = 'CIF002';
        req.DocumentID = 'DOC002';
        req.DocumentType = 'Passport';
        req.IssueDate = '2021-06-01';

        Test.startTest();
        String envelope = FEC_UpdateCustomerDocument.buildEnvelope(
            req,
            'TRANS-001',
            '2026-06-02T10:00:00'
        );
        Test.stopTest();

        System.assert(envelope.contains('<DocumentID>DOC002</DocumentID>'));
        System.assert(!envelope.contains('<IDDocumentNumber>'));
        System.assert(!envelope.contains('<ExpirationDate>'));
        System.assert(!envelope.contains('<IssuePlace>'));
        System.assert(!envelope.contains('<OmnidocsLink>'));
    }

    @IsTest
    static void testBuildEnvelope_ValidationErrors() {
        FEC_UpdateCustomerDocument.UpdateDocumentRequest base = buildValidRequest();
        Boolean missingCif = false;
        Boolean missingDocId = false;
        Boolean missingDocType = false;
        Boolean missingIssueDate = false;
        Boolean invalidIssueDate = false;
        Boolean invalidExpirationDate = false;
        Boolean cifTooLong = false;
        Boolean blankTransId = false;
        Boolean blankTimestamp = false;

        Test.startTest();
        try {
            base.CIFNumber = '';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            missingCif = true;
        }

        base = buildValidRequest();
        try {
            base.DocumentID = '';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            missingDocId = true;
        }

        base = buildValidRequest();
        try {
            base.DocumentType = '';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            missingDocType = true;
        }

        base = buildValidRequest();
        try {
            base.IssueDate = '';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            missingIssueDate = true;
        }

        base = buildValidRequest();
        try {
            base.IssueDate = '15-01-2020';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            invalidIssueDate = true;
        }

        base = buildValidRequest();
        try {
            base.ExpirationDate = 'not-a-date';
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            invalidExpirationDate = true;
        }

        base = buildValidRequest();
        try {
            base.CIFNumber = 'X'.repeat(256);
            FEC_UpdateCustomerDocument.buildEnvelope(base, 'T1', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            cifTooLong = true;
        }

        try {
            FEC_UpdateCustomerDocument.buildEnvelope(buildValidRequest(), '', '2026-01-01T00:00:00');
        } catch (FEC_APIServiceException e) {
            blankTransId = true;
        }

        try {
            FEC_UpdateCustomerDocument.buildEnvelope(buildValidRequest(), 'T1', '');
        } catch (FEC_APIServiceException e) {
            blankTimestamp = true;
        }
        Test.stopTest();

        System.assertEquals(true, missingCif);
        System.assertEquals(true, missingDocId);
        System.assertEquals(true, missingDocType);
        System.assertEquals(true, missingIssueDate);
        System.assertEquals(true, invalidIssueDate);
        System.assertEquals(true, invalidExpirationDate);
        System.assertEquals(true, cifTooLong);
        System.assertEquals(true, blankTransId);
        System.assertEquals(true, blankTimestamp);
    }

    @IsTest
    static void testParseResponse_SuccessAndCode4() {
        String successXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '<Sys><TransID>T0</TransID><Code>0</Code><Description>OK</Description></Sys>' +
            '</cif:UpdateCustomerDocumentResponse></soapenv:Body></soapenv:Envelope>';
        String code4Xml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '<Sys><TransID>T4</TransID><Code>4</Code><Description>Accepted</Description></Sys>' +
            '</cif:UpdateCustomerDocumentResponse></soapenv:Body></soapenv:Envelope>';

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult okRes =
            FEC_UpdateCustomerDocument.parseResponse(successXml, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult code4Res =
            FEC_UpdateCustomerDocument.parseResponse(code4Xml, 200);
        Test.stopTest();

        System.assertEquals(true, okRes.success);
        System.assertEquals('0', okRes.code);
        System.assertEquals('T0', okRes.transId);
        System.assertEquals(true, code4Res.success);
        System.assertEquals('4', code4Res.code);
    }

    @IsTest
    static void testParseResponse_ErrorPaths() {
        String noResponseXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><Error>Failed</Error></soapenv:Body></soapenv:Envelope>';
        String emptyBodyXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body></soapenv:Body></soapenv:Envelope>';
        String noSysXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '</cif:UpdateCustomerDocumentResponse></soapenv:Body></soapenv:Envelope>';
        String failCodeXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<cif:UpdateCustomerDocumentResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '<Sys><Code>9</Code></Sys></cif:UpdateCustomerDocumentResponse></soapenv:Body></soapenv:Envelope>';

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult nullRes =
            FEC_UpdateCustomerDocument.parseResponse(null, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult noResponseRes =
            FEC_UpdateCustomerDocument.parseResponse(noResponseXml, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult emptyBodyRes =
            FEC_UpdateCustomerDocument.parseResponse(emptyBodyXml, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult noSysRes =
            FEC_UpdateCustomerDocument.parseResponse(noSysXml, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult failCodeRes =
            FEC_UpdateCustomerDocument.parseResponse(failCodeXml, 200);
        FEC_UpdateCustomerDocument.UpdateDocumentResult badXmlRes =
            FEC_UpdateCustomerDocument.parseResponse('not-valid-xml', 200);
        Test.stopTest();

        System.assertEquals(false, nullRes.success);
        System.assertEquals('Empty response body', nullRes.errorMessage);
        System.assertEquals(false, noResponseRes.success);
        System.assertEquals(false, emptyBodyRes.success);
        System.assertEquals(false, noSysRes.success);
        System.assertEquals(false, failCodeRes.success);
        System.assertEquals(false, badXmlRes.success);
        System.assertNotEquals(null, badXmlRes.errorMessage);
    }

    @IsTest
    static void testParseResponse_NoSoapBody() {
        String noBodyXml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Header/></soapenv:Envelope>';

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.parseResponse(noBodyXml, 200);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('No SOAP Body', res.errorMessage);
    }

    @IsTest
    static void testParseResponse_FallbackResponseNodeName() {
        String xml =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<ns0:UpdateCustomerDocumentResponse xmlns:ns0="http://fecredit.com.vn/CIF_CustomerInfoUpdate">' +
            '<Sys><TransID>TFB</TransID><Code>0</Code><Description>OK</Description></Sys>' +
            '</ns0:UpdateCustomerDocumentResponse></soapenv:Body></soapenv:Envelope>';

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.parseResponse(xml, 200);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('TFB', res.transId);
    }

    @IsTest
    static void testUpdateCustomerDocument_Success() {
        Test.setMock(HttpCalloutMock.class, new SoapSuccessMock());

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.updateCustomerDocument(buildValidRequest());
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('0', res.code);
        System.assertEquals(200, res.httpStatus);
        System.assertNotEquals(null, res.rawResponse);
        System.assertNotEquals(null, res.transId);
    }

    @IsTest
    static void testUpdateCustomerDocument_FillsMissingTransId() {
        Test.setMock(HttpCalloutMock.class, new SoapNoTransIdMock());

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.updateCustomerDocument(buildValidRequest());
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertNotEquals(null, res.transId);
    }

    @IsTest
    static void testUpdateCustomerDocument_ApiFailureCode() {
        Test.setMock(HttpCalloutMock.class, new SoapFailMock());

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.updateCustomerDocument(buildValidRequest());
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertEquals('1', res.code);
    }

    @IsTest
    static void testUpdateCustomerDocument_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new ThrowingCalloutMock());

        Test.startTest();
        FEC_UpdateCustomerDocument.UpdateDocumentResult res =
            FEC_UpdateCustomerDocument.updateCustomerDocument(buildValidRequest());
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assert(res.errorMessage.contains('Callout error'));
    }

    @IsTest
    static void testSendRequest_ReturnsHttpResponse() {
        Test.setMock(HttpCalloutMock.class, new SoapSuccessMock());
        String envelope = FEC_UpdateCustomerDocument.buildEnvelope(
            buildValidRequest(),
            'TRANS-SEND',
            '2026-06-02T12:00:00'
        );

        Test.startTest();
        HttpResponse httpRes = FEC_UpdateCustomerDocument.sendRequest(envelope);
        Test.stopTest();

        System.assertNotEquals(null, httpRes);
        System.assertEquals(200, httpRes.getStatusCode());
        System.assert(String.isNotBlank(httpRes.getBody()));
    }
}
