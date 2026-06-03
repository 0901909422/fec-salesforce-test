/**
 * Unit tests for FEC_SaleInfoUpdateQueueable (merge sale-disburse data into application cache JSON).
 */
@IsTest
private class FEC_SaleInfoUpdateQueueable_Test {

    private static final String APP_ID_1 = 'APP-SIU-001';
    private static final String APP_ID_2 = 'APP-SIU-002';
    private static final String APP_ID_OTHER = 'APP-SIU-999';

    @TestSetup
    static void setupData() {
        Case c = new Case(Subject = 'FEC_SaleInfoUpdateQueueable_Test');
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

    private static FEC_Application_List__c applicationListWithCache() {
        return [
            SELECT Id, FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            LIMIT 1
        ];
    }

    private static FEC_Application_List__c insertApplicationListWithBlankCache() {
        Case c = new Case(Subject = 'FEC_SaleInfoUpdateQueueable_BlankCache');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(FEC_Case__c = c.Id);
        insert history;

        FEC_Application_List__c al = new FEC_Application_List__c(
            FEC_Customer_History__c = history.Id
        );
        insert al;
        return al;
    }

    private static String buildSaleMapJson(Map<String, Map<String, String>> saleByAppId) {
        Map<String, Object> raw = new Map<String, Object>();
        for (String appId : saleByAppId.keySet()) {
            Map<String, Object> sale = new Map<String, Object>();
            for (String field : saleByAppId.get(appId).keySet()) {
                sale.put(field, saleByAppId.get(appId).get(field));
            }
            raw.put(appId, sale);
        }
        return JSON.serialize(raw);
    }

    private static Map<String, String> sampleSaleFields() {
        return new Map<String, String>{
            'CC_CODE' => 'CC77',
            'CC_NAME' => 'CC Seventy Seven',
            'DSA_CODE' => 'DSA77',
            'DSA_NAME' => 'DSA Seventy Seven',
            'TSA_CODE' => 'TSA77',
            'TSA_NAME' => 'TSA Seventy Seven'
        };
    }

    private static void runUpdateQueueable(FEC_SaleInfoUpdateQueueable job) {
        Test.startTest();
        job.execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testExecute_MergesSaleFieldsIntoCache() {
        FEC_Application_List__c al = applicationListWithCache();
        String saleMapJson = buildSaleMapJson(
            new Map<String, Map<String, String>>{ APP_ID_1 => sampleSaleFields() }
        );

        runUpdateQueueable(new FEC_SaleInfoUpdateQueueable(al.Id, saleMapJson));

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains('"ccCode":"CC77"'), 'Cache must include merged CC code.');
        System.assert(cache.contains('"ccName":"CC Seventy Seven"'), 'Cache must include merged CC name.');
        System.assert(cache.contains('"dSACode":"DSA77"'), 'Cache must include merged DSA code.');
        System.assert(cache.contains('"dSAName":"DSA Seventy Seven"'), 'Cache must include merged DSA name.');
        System.assert(cache.contains('"tSACode":"TSA77"'), 'Cache must include merged TSA code.');
        System.assert(cache.contains('"tSAName":"TSA Seventy Seven"'), 'Cache must include merged TSA name.');
        System.assert(cache.contains(APP_ID_2), 'Unmatched application row must remain in cache.');
        System.assertEquals(
            1,
            cache.split('"ccCode"').size() - 1,
            'Only the matching application row must receive sale fields.'
        );
    }

    @IsTest
    static void testExecute_MergesOnlyMatchingRows() {
        FEC_Application_List__c al = applicationListWithCache();
        Map<String, Map<String, String>> saleByApp = new Map<String, Map<String, String>>();
        saleByApp.put(APP_ID_1, sampleSaleFields());
        saleByApp.put(APP_ID_2, new Map<String, String>{
            'CC_CODE' => 'CC22',
            'CC_NAME' => 'CC Twenty Two',
            'DSA_CODE' => 'DSA22',
            'DSA_NAME' => 'DSA Twenty Two',
            'TSA_CODE' => 'TSA22',
            'TSA_NAME' => 'TSA Twenty Two'
        });

        runUpdateQueueable(
            new FEC_SaleInfoUpdateQueueable(al.Id, buildSaleMapJson(saleByApp))
        );

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains('"ccCode":"CC77"'), 'First row must be updated.');
        System.assert(cache.contains('"ccCode":"CC22"'), 'Second row must be updated.');
    }

    @IsTest
    static void testExecute_NoMatchingApplication_LeavesCacheWithoutSaleFields() {
        FEC_Application_List__c al = applicationListWithCache();
        String saleMapJson = buildSaleMapJson(
            new Map<String, Map<String, String>>{ APP_ID_OTHER => sampleSaleFields() }
        );

        runUpdateQueueable(new FEC_SaleInfoUpdateQueueable(al.Id, saleMapJson));

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains(APP_ID_1), 'Cache must still contain first application.');
        System.assert(cache.contains(APP_ID_2), 'Cache must still contain second application.');
        System.assert(!cache.contains('"ccCode"'), 'No row should receive sale fields.');
    }

    @IsTest
    static void testExecute_BlankCache_ReturnsEarly() {
        FEC_Application_List__c al = insertApplicationListWithBlankCache();
        String saleMapJson = buildSaleMapJson(
            new Map<String, Map<String, String>>{ APP_ID_1 => sampleSaleFields() }
        );

        runUpdateQueueable(new FEC_SaleInfoUpdateQueueable(al.Id, saleMapJson));

        FEC_Application_List__c loaded = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ];
        System.assertEquals(null, loaded.FEC_API_Cache_Applications__c, 'Blank cache must not be updated.');
    }

    @IsTest
    static void testExecute_EmptySaleMap_UpdatesCacheWithoutSaleFields() {
        FEC_Application_List__c al = applicationListWithCache();

        runUpdateQueueable(new FEC_SaleInfoUpdateQueueable(al.Id, '{}'));

        String cache = [
            SELECT FEC_API_Cache_Applications__c
            FROM FEC_Application_List__c
            WHERE Id = :al.Id
        ].FEC_API_Cache_Applications__c;

        System.assert(cache.contains(APP_ID_1), 'Cache rows must remain after empty sale map.');
        System.assert(!cache.contains('"ccCode"'), 'Empty sale map must not add sale fields.');
    }
}
