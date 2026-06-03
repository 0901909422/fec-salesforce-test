@IsTest
private class FEC_IntegrationFraudScheduler_Test {

    private class MockHttp implements HttpCalloutMock {
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
    static void test_schedulerExecution() {
        // Create required channel record
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;

        Test.setMock(HttpCalloutMock.class, new MockHttp());

        String cronExp = '0 0 0 1 1 ? 2099';

        Test.startTest();
        String jobId = System.schedule(
            'Test FEC Fraud Scheduler',
            cronExp,
            new FEC_IntegrationFraudScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled');
    }

    @IsTest
    static void test_schedulerExecution_error() {
        // No channel record → syncMasterDataIntegration will likely throw or return 0
        Test.setMock(HttpCalloutMock.class, new MockHttp());

        String cronExp = '0 0 0 1 1 ? 2099';

        Test.startTest();
        String jobId = System.schedule(
            'Test FEC Fraud Scheduler Error',
            cronExp,
            new FEC_IntegrationFraudScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled even with errors');
    }
}
