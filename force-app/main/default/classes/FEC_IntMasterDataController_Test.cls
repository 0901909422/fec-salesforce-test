@IsTest
private class FEC_IntMasterDataController_Test {

    private class FraudServiceMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<ns1:GetFraudMasterDataResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>OK</ns1:Description></ns1:Sys>' +
                '</ns1:GetFraudMasterDataResponse>' +
                '</soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void test_syncFraudMasterData() {
        Test.setMock(HttpCalloutMock.class, new FraudServiceMock());

        Test.startTest();
        String result = FEC_IntegrationMasterDataController.syncFraudMasterData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result message');
    }
}