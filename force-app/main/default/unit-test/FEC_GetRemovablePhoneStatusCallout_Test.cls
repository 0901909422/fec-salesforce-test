@IsTest
private class FEC_GetRemovablePhoneStatusCallout_Test {
    private class SoapSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('GetRemovablePhoneStatus', req.getHeader('SOAPAction'));
            System.assert(req.getBody().contains('<Phone>0901234567</Phone>'));
            System.assert(req.getBody().contains('<RequestorID>PEGA_CSM</RequestorID>'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<Envelope><Sys><TransID>TRX-001</TransID><DateTime>2026-01-01T00:00:00.000Z</DateTime><Code>0</Code><Description>SUCCESS</Description></Sys></Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void testGenerateTransId_notBlank() {
        String transId = FEC_GetRemovablePhoneStatusCallout.generateTransId();
        System.assertNotEquals(null, transId);
        System.assert(transId.length() > 10, 'Generated transaction id should have UUID-like length.');
    }

    @IsTest
    static void testBuildEnvelope_containsExpectedNodes() {
        String xml = FEC_GetRemovablePhoneStatusCallout.buildEnvelope(
            '0901234567',
            'TRX-ABC',
            'PEGA_CSM',
            '2026-01-01T00:00:00.000Z'
        );

        System.assert(xml.contains('<TransID>TRX-ABC</TransID>'));
        System.assert(xml.contains('<RequestorID>PEGA_CSM</RequestorID>'));
        System.assert(xml.contains('<Phone>0901234567</Phone>'));
    }

    @IsTest
    static void testParseResponse_success() {
        String xml =
            '<Envelope><Sys><TransID>TRX-002</TransID><DateTime>2026-01-01T01:00:00.000Z</DateTime><Code>1</Code><Description>REMOVABLE</Description></Sys></Envelope>';

        FEC_GetRemovablePhoneStatusCallout.PhoneResult r =
            FEC_GetRemovablePhoneStatusCallout.parseResponse(xml);

        System.assertEquals('TRX-002', r.transId);
        System.assertEquals('2026-01-01T01:00:00.000Z', r.timestamp);
        System.assertEquals('1', r.code);
        System.assertEquals('REMOVABLE', r.description);
    }

    @IsTest
    static void testGetRemovablePhoneStatus_endToEndWithMock() {
        Test.setMock(HttpCalloutMock.class, new SoapSuccessMock());

        Test.startTest();
        FEC_GetRemovablePhoneStatusCallout.PhoneResult r =
            FEC_GetRemovablePhoneStatusCallout.getRemovablePhoneStatus('0901234567');
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertEquals('TRX-001', r.transId);
        System.assertEquals('0', r.code);
        System.assertEquals('SUCCESS', r.description);
    }
}
