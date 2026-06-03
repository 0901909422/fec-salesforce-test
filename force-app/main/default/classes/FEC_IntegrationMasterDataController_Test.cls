@IsTest
private class FEC_IntegrationMasterDataController_Test {

    private class MasterDataMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<GetFraudMasterDataResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<MasterDataItems>' +
                '<ID>P001</ID><Name>Product</Name><NameVN>SP</NameVN>' +
                '<Type>Product</Type><PosOrder>1</PosOrder><ApplyTo>All</ApplyTo>' +
                '</MasterDataItems>' +
                '</GetFraudMasterDataResponse>' +
                '</soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

    @IsTest
    static void test_syncFraudMasterData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;

        Test.setMock(HttpCalloutMock.class, new MasterDataMock());

        Test.startTest();
        String result = FEC_IntegrationMasterDataController.syncFraudMasterData();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.length() > 0, 'Should return a status message');
    }
}
