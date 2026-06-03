/**
 * Unit tests for FEC_SaleInfoQueueable (async sale-disburse callouts + FEC_SaleInfoUpdateQueueable chain).
 */
@IsTest
private class FEC_SaleInfoQueueable_Test {

    private static final String APP_ID_1 = 'APP-SIQ-001';
    private static final String APP_ID_2 = 'APP-SIQ-002';

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION,
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test.example.com'
        );

        Case c = new Case(Subject = 'FEC_SaleInfoQueueable_Test');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(FEC_Case__c = c.Id);
        insert history;

        String cacheJson =
            '[' +
            '{"applicationId":"' + APP_ID_1 + '","lastStatus":"Approved"},' +
            '{"applicationId":"' + APP_ID_2 + '","lastStatus":"Pending"}' +
            ']';

        insert new FEC_Application_List__c(
            FEC_Customer_History__c = history.Id,
            FEC_API_Cache_Applications__c = cacheJson
        );
    }

    private static FEC_Application_List__c applicationList() {
        return [
            SELECT Id, FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            LIMIT 1
        ];
    }

    private static String mockSaleJson(String appId) {
        return '{' +
            '"Sys":{"TransID":"TXN-SIQ","DateTime":"2026-05-27T10:00:00.000Z","Code":1,"Description":"OK"},' +
            '"CustomerSaleInfos":[{"APPLICATION_ID":"' + appId + '",' +
            '"CC_CODE":"CC99","CC_NAME":"CC Ninety Nine",' +
            '"DSA_CODE":"DSA99","DSA_NAME":"DSA Ninety Nine",' +
            '"TSA_CODE":"TSA99","TSA_NAME":"TSA Ninety Nine"}]' +
            '}';
    }

    private class SaleDisburseMock implements HttpCalloutMock {
        private Boolean throwOnSecond;
        private Boolean returnEmptyForSecond;

        SaleDisburseMock(Boolean throwOnSecond, Boolean returnEmptyForSecond) {
            this.throwOnSecond = throwOnSecond;
            this.returnEmptyForSecond = returnEmptyForSecond;
        }

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';

            if (throwOnSecond && endpoint.contains(APP_ID_2)) {
                throw new CalloutException('Simulated callout failure');
            }

            String appId = endpoint.contains(APP_ID_2) ? APP_ID_2 : APP_ID_1;
            String body = returnEmptyForSecond && appId == APP_ID_2
                ? '{"Sys":{"Code":1,"DateTime":"2026-05-27T10:00:00.000Z"},"CustomerSaleInfos":[]}'
                : mockSaleJson(appId);

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(body);
            return res;
        }
    }

    private class FailingSaleDisburseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('All callouts fail');
        }
    }

    private static void runQueueable(FEC_SaleInfoQueueable job) {
        Test.startTest();
        job.execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testExecute_MergesSaleInfoIntoCache() {
        FEC_Application_List__c al = applicationList();
        Test.setMock(HttpCalloutMock.class, new SaleDisburseMock(false, false));

        runQueueable(new FEC_SaleInfoQueueable(al.Id, new List<String>{ APP_ID_1 }));

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains('"ccCode":"CC99"'), 'Cache must include merged CC code.');
        System.assert(cache.contains('"dSACode":"DSA99"'), 'Cache must include merged DSA code.');
        System.assert(cache.contains('"tSACode":"TSA99"'), 'Cache must include merged TSA code.');
        System.assert(cache.contains(APP_ID_1), 'Cache must still contain application id.');
    }

    @IsTest
    static void testExecute_EmptyCustomerSaleInfos_LeavesRowWithoutSaleFields() {
        FEC_Application_List__c al = applicationList();
        Test.setMock(HttpCalloutMock.class, new SaleDisburseMock(false, true));

        runQueueable(
            new FEC_SaleInfoQueueable(al.Id, new List<String>{ APP_ID_1, APP_ID_2 })
        );

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains('"ccCode":"CC99"'), 'First application should merge sale info.');
        System.assert(!cache.contains('"ccCode":null'), 'Second application must not add empty sale merge.');
    }

    @IsTest
    static void testExecute_CalloutException_StillCompletesChain() {
        FEC_Application_List__c al = applicationList();
        Test.setMock(HttpCalloutMock.class, new FailingSaleDisburseMock());

        runQueueable(new FEC_SaleInfoQueueable(al.Id, new List<String>{ APP_ID_1 }));

        String cacheAfter = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cacheAfter.contains(APP_ID_1), 'Cache row must remain after failed callout.');
        System.assert(!cacheAfter.contains('"ccCode"'), 'Failed callout must not merge sale fields.');
    }

    @IsTest
    static void testExecute_MultipleApplications_PartialSuccess() {
        FEC_Application_List__c al = applicationList();
        Test.setMock(HttpCalloutMock.class, new SaleDisburseMock(true, false));

        runQueueable(
            new FEC_SaleInfoQueueable(al.Id, new List<String>{ APP_ID_1, APP_ID_2 })
        );

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains('"ccCode":"CC99"'), 'Successful app callout must merge sale info.');
        System.assert(cache.contains(APP_ID_2), 'Second application row must remain in cache.');
    }
}
