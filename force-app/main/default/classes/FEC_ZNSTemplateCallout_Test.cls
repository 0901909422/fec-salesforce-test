@IsTest
private class FEC_ZNSTemplateCallout_Test {

    @testSetup
    static void setupData() {
        setupApiSetting();
    }

    private static void setupApiSetting() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();

        if (setting == null) {
            setting = new FEC_API_Setting__c();
        }

        if (setting.Id == null) {
            setting.SetupOwnerId = UserInfo.getOrganizationId();
        }

        setting.FEC_Call_Mock__c = false;
        setting.FEC_Endpoint__c = 'https://unit.test';

        upsert setting;
    }

    private class ZNSTemplateHttpMock implements HttpCalloutMock {
        private String scenario;

        ZNSTemplateHttpMock(String scenario) {
            this.scenario = scenario;
        }

        public HttpResponse respond(HttpRequest req) {
            if (scenario == 'calloutException') {
                throw new CalloutException('Forced callout exception from test mock.');
            }

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            Boolean isDetailCall = endpoint != null && endpoint.contains('TemplateID=');

            if (!isDetailCall) {
                return buildGetTemplatesResponse(res);
            }

            return buildGetTemplateByIdResponse(res, endpoint);
        }

        private HttpResponse buildGetTemplatesResponse(HttpResponse res) {
            if (scenario == 'templatesHttpError') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('{"error":"server error"}');
                return res;
            }

            res.setStatusCode(200);
            res.setStatus('OK');

            if (scenario == 'templatesBusinessError') {
                res.setBody(
                    '{"Sys":{"Code":0,"Description":"Business Error"},"templates":[]}'
                );
                return res;
            }

            if (scenario == 'templatesEmpty') {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},"templates":[]}'
                );
                return res;
            }

            res.setBody(
                '{"Sys":{"Code":1,"Description":"OK"},"templates":[' +
                    '{"template_id":"TPL001","template_name":"Welcome ZNS","template_status":"ENABLE","department":"cs"},' +
                    '{"template_id":"TPL002","template_name":"Disabled ZNS","template_status":"DISABLE","department":"cs"}' +
                ']}'
            );

            return res;
        }

        private HttpResponse buildGetTemplateByIdResponse(HttpResponse res, String endpoint) {
            if (scenario == 'detailHttpError') {
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
                res.setBody('{"error":"detail server error"}');
                return res;
            }

            res.setStatusCode(200);
            res.setStatus('OK');

            if (scenario == 'detailZaloError') {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},' +
                    '"zalo_code":1,' +
                    '"zalo_message":"Zalo Error",' +
                    '"result":null}'
                );
                return res;
            }

            if (endpoint != null && endpoint.contains('TPL001')) {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},' +
                    '"zalo_code":0,' +
                    '"zalo_message":"OK",' +
                    '"result":{' +
                        '"templateId":"TPL001",' +
                        '"templateName":"Welcome ZNS",' +
                        '"status":"ENABLE",' +
                        '"previewUrl":"https://preview.example/tpl001",' +
                        '"listParams":[' +
                            '{"name":"customer_name","require":true,"type":"STRING","maxLength":100,"minLength":1,"acceptNull":false},' +
                            '{"name":"due_date","require":false,"type":"DATE","maxLength":10,"minLength":0,"acceptNull":true}' +
                        ']' +
                    '}}'
                );
            } else {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},' +
                    '"zalo_code":0,' +
                    '"zalo_message":"OK",' +
                    '"result":{' +
                        '"templateId":"TPL002",' +
                        '"templateName":"Disabled ZNS",' +
                        '"status":"DISABLE",' +
                        '"previewUrl":null,' +
                        '"listParams":null' +
                    '}}'
                );
            }

            return res;
        }
    }

    @IsTest
    static void testFetchAndMapSuccess() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('success'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Expected non-empty callout result.');
        System.assertEquals(2, result.templates.size(), 'Expected 2 mapped templates.');
        System.assertEquals(2, result.paramMaps.size(), 'Expected 2 mapped params.');

        System.assertEquals('Welcome ZNS', result.templates[0].Name);
        System.assertEquals('TPL001', result.templates[0].FEC_Subject_Line__c);
        System.assertEquals('ENABLE', result.templates[0].FEC_Template_ZNS_Status__c);
        System.assertEquals(true, result.templates[0].FEC_Is_ZNS_Template__c);
        System.assertEquals(true, result.templates[0].FEC_Active__c);
        System.assertEquals('https://preview.example/tpl001', result.templates[0].FEC_Preview_ZNS_Url__c);

        System.assertEquals('Disabled ZNS', result.templates[1].Name);
        System.assertEquals(false, result.templates[1].FEC_Active__c);

        System.assertEquals('customer_name', result.paramMaps[0].Name);
        System.assertEquals('TPL001', result.paramMaps[0].Template_ID__c);
        System.assertEquals('STRING', result.paramMaps[0].Param_Type__c);
        System.assertEquals(true, result.paramMaps[0].Require__c);
        System.assertEquals(false, result.paramMaps[0].Accept_Null__c);
    }

    @IsTest
    static void testFetchAndMapEmptyTemplates() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('templatesEmpty'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assert(result.isEmpty(), 'Expected empty result when API returns no templates.');
    }

    @IsTest
    static void testFetchAndMapTemplatesHttpError() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('templatesHttpError'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assert(result.isEmpty(), 'Expected empty result when GetTemplates HTTP fails.');
    }

    @IsTest
    static void testFetchAndMapTemplatesBusinessError() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('templatesBusinessError'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assert(result.isEmpty(), 'Expected empty result when GetTemplates business code fails.');
    }

    @IsTest
    static void testFetchAndMapDetailHttpError() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('detailHttpError'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assertEquals(2, result.templates.size(), 'Expected templates to still be mapped.');
        System.assertEquals(0, result.paramMaps.size(), 'Expected no params when detail API fails.');
    }

    @IsTest
    static void testFetchAndMapDetailZaloError() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('detailZaloError'));

        Test.startTest();
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout().fetchAndMap();
        Test.stopTest();

        System.assertEquals(2, result.templates.size(), 'Expected templates to still be mapped.');
        System.assertEquals(0, result.paramMaps.size(), 'Expected no params when Zalo code fails.');
    }

    @IsTest
    static void testFetchAndMapCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ZNSTemplateHttpMock('calloutException'));

        Boolean thrown = false;

        Test.startTest();
        try {
            new FEC_ZNSTemplateCallout().fetchAndMap();
        } catch (CalloutException ex) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected CalloutException to propagate.');
    }

    @IsTest
    static void testCalloutResultIsEmpty() {
        FEC_ZNSTemplateCallout.CalloutResult result =
            new FEC_ZNSTemplateCallout.CalloutResult();

        System.assertEquals(true, result.isEmpty(), 'New wrapper should be empty.');
    }
}