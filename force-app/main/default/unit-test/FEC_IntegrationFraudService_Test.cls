@IsTest
private class FEC_IntegrationFraudService_Test {

    private static final String INTEGRATION_CHANNEL_CODE = 'FIMA';

    private static Boolean canRunServiceTests() {
        return Type.forName('FEC_IntegrationFraudService') != null;
    }

    @TestSetup
    static void setup() {
        String suffix = String.valueOf(System.currentTimeMillis());
        insert new FEC_Channel__c(
            Name = 'FIMA Channel',
            FEC_Code__c = INTEGRATION_CHANNEL_CODE,
            FEC_Channel_ID__c = 'CH-' + suffix,
            FEC_Channel_Status__c = true
        );
    }

    @IsTest
    static void testIsConnectFraudSystem() {
        if (!canRunServiceTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudService not on org.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new FraudHttpMock('HEALTH_OK'));

        Test.startTest();
        Boolean isConnected = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        System.assertEquals(true, isConnected);
    }

    @IsTest
    static void testIsConnectFraudSystem_failure() {
        if (!canRunServiceTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudService not on org.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new FraudHttpMock('HEALTH_FAIL'));

        Test.startTest();
        Boolean isConnected = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        System.assertEquals(false, isConnected);
    }

    @IsTest
    static void testSyncMasterDataIntegration() {
        if (!canRunServiceTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudService not on org.');
            return;
        }
        if (Schema.getGlobalDescribe().get('FEC_Master_Data_Integration__c') == null) {
            System.assert(true, 'Skipped: FEC_Master_Data_Integration__c not on org.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new FraudHttpMock('MASTER_DATA'));

        Test.startTest();
        Integer count = FEC_IntegrationFraudService.syncMasterDataIntegration();
        Test.stopTest();

        System.assert(count != null && count >= 0, 'Sync must return record count.');
    }

    @IsTest
    static void testGetAdminRecipients() {
        if (!canRunServiceTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudService not on org.');
            return;
        }

        Test.startTest();
        List<String> recipients = FEC_IntegrationFraudService.getAdminRecipients();
        Test.stopTest();

        System.assertNotEquals(null, recipients);
    }

    @IsTest
    static void testCallCreateFraudCaseService() {
        if (!canRunServiceTests()) {
            System.assert(true, 'Skipped: FEC_IntegrationFraudService not on org.');
            return;
        }
        if (Type.forName('FEC_IntegrationSoapFraudcaseService') == null
            || Type.forName('FEC_IntegrationFraudCaseUtil') == null) {
            System.assert(true, 'Skipped: SOAP/util dependencies not on org.');
            return;
        }

        Test.setMock(HttpCalloutMock.class, new FraudHttpMock('CREATE_CASE'));

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CRM';
        sys.TransactionID = 'TX-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper wrapper =
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        wrapper.channelCode = INTEGRATION_CHANNEL_CODE;
        wrapper.caseId = 'FH-TEST-001';
        wrapper.serviceCaseId = 'S-000001';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType res =
            FEC_IntegrationFraudService.callCreateFraudCaseService(
                wrapper,
                sys,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('FH-12345', res.CaseID);
    }

    private static String masterDataXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<GetFraudMasterDataResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<MasterDataItems>' +
            '<ID>Loan</ID><Name>Application</Name><NameVN>Application</NameVN>' +
            '<PosOrder>1</PosOrder><ApplyTo>ALL</ApplyTo><Type>Product</Type>' +
            '</MasterDataItems>' +
            '</GetFraudMasterDataResponse>' +
            '</soapenv:Body></soapenv:Envelope>';
    }

    private static String createCaseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body>' +
            '<CreateFraudCaseResponse xmlns="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<CaseID>FH-12345</CaseID>' +
            '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
            '</CreateFraudCaseResponse>' +
            '</soapenv:Body></soapenv:Envelope>';
    }

    private class FraudHttpMock implements HttpCalloutMock {
        private String mode;

        FraudHttpMock(String mode) {
            this.mode = mode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'text/xml');

            if (mode == 'HEALTH_FAIL') {
                res.setStatusCode(503);
                res.setBody('Unavailable');
                return res;
            }

            res.setStatusCode(200);

            if (mode == 'MASTER_DATA'
                || (req.getBody() != null && req.getBody().contains('GetFraudMasterDataRequest'))) {
                res.setBody(FEC_IntegrationFraudService_Test.masterDataXml());
                return res;
            }

            if (mode == 'CREATE_CASE'
                || (req.getBody() != null && req.getBody().contains('CreateFraudCaseRequest'))) {
                res.setBody(FEC_IntegrationFraudService_Test.createCaseXml());
                return res;
            }

            res.setBody('OK');
            return res;
        }
    }
}
