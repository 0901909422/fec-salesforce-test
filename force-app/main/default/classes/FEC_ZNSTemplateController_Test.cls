@IsTest
private class FEC_ZNSTemplateController_Test {

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

    private static String buildLongString(Integer size) {
        String value = '';

        for (Integer i = 0; i < size; i++) {
            value += 'X';
        }

        return value;
    }

    private static Id insertRecord(String objectApiName, Map<String, Object> values) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        System.assertNotEquals(null, sObjectType, 'Object does not exist: ' + objectApiName);

        SObject rec = sObjectType.newSObject();

        for (String fieldApiName : values.keySet()) {
            putIfCreateable(rec, fieldApiName, values.get(fieldApiName));
        }

        populateRequiredFields(rec);
        insert rec;

        return (Id) rec.get('Id');
    }

    private static void putIfCreateable(SObject rec, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }

        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        if (!fields.containsKey(fieldApiName)) {
            return;
        }

        if (fields.get(fieldApiName).getDescribe().isCreateable()) {
            rec.put(fieldApiName, value);
        }
    }

    private static void populateRequiredFields(SObject rec) {
        Map<String, Schema.SObjectField> fields =
            rec.getSObjectType().getDescribe().fields.getMap();

        for (String fieldApiName : fields.keySet()) {
            if (fieldApiName == 'Id' || rec.get(fieldApiName) != null) {
                continue;
            }

            Schema.DescribeFieldResult d = fields.get(fieldApiName).getDescribe();

            if (!d.isCreateable() || d.isNillable() || d.isDefaultedOnCreate()) {
                continue;
            }

            Object value = getSampleValue(d);

            if (value != null) {
                rec.put(fieldApiName, value);
            }
        }
    }

    private static Object getSampleValue(Schema.DescribeFieldResult d) {
        Schema.DisplayType t = d.getType();

        if (t == Schema.DisplayType.Boolean) {
            return false;
        }

        if (t == Schema.DisplayType.Date) {
            return Date.today();
        }

        if (t == Schema.DisplayType.DateTime) {
            return Datetime.now();
        }

        if (t == Schema.DisplayType.Time) {
            return Time.newInstance(9, 0, 0, 0);
        }

        if (t == Schema.DisplayType.Integer) {
            return 1;
        }

        if (t == Schema.DisplayType.Long) {
            return 1L;
        }

        if (
            t == Schema.DisplayType.Double ||
            t == Schema.DisplayType.Currency ||
            t == Schema.DisplayType.Percent
        ) {
            return 1;
        }

        if (
            t == Schema.DisplayType.Picklist ||
            t == Schema.DisplayType.MultiPicklist
        ) {
            for (Schema.PicklistEntry pe : d.getPicklistValues()) {
                if (pe.isActive()) {
                    return pe.getValue();
                }
            }

            return null;
        }

        if (t == Schema.DisplayType.Reference) {
            for (Schema.SObjectType refType : d.getReferenceTo()) {
                if (refType.getDescribe().getName() == 'User') {
                    return UserInfo.getUserId();
                }
            }

            return null;
        }

        Integer maxLength = d.getLength() > 0
            ? Math.min(d.getLength(), 40)
            : 40;

        String value = 'Unit Test Value';

        return value.length() > maxLength
            ? value.substring(0, maxLength)
            : value;
    }

    private class ZNSControllerHttpMock implements HttpCalloutMock {
        private String scenario;

        ZNSControllerHttpMock(String scenario) {
            this.scenario = scenario;
        }

        public HttpResponse respond(HttpRequest req) {
            if (scenario == 'calloutException') {
                throw new CalloutException('Forced controller callout exception.');
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
            res.setStatusCode(200);
            res.setStatus('OK');

            if (scenario == 'empty') {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},"templates":[]}'
                );
                return res;
            }

            if (scenario == 'dmlError') {
                res.setBody(
                    '{"Sys":{"Code":1,"Description":"OK"},"templates":[' +
                        '{"template_id":"DMLError001","template_name":"' + buildLongString(300) + '","template_status":"ENABLE","department":"cs"}' +
                    ']}'
                );
                return res;
            }

            res.setBody(
                '{"Sys":{"Code":1,"Description":"OK"},"templates":[' +
                    '{"template_id":"CTRL001","template_name":"Controller ZNS 1","template_status":"ENABLE","department":"cs"},' +
                    '{"template_id":"CTRL002","template_name":"Controller ZNS 2","template_status":"DISABLE","department":"cs"}' +
                ']}'
            );

            return res;
        }

        private HttpResponse buildGetTemplateByIdResponse(HttpResponse res, String endpoint) {
            res.setStatusCode(200);
            res.setStatus('OK');

            String templateId = endpoint != null && endpoint.contains('CTRL002')
                ? 'CTRL002'
                : 'CTRL001';

            res.setBody(
                '{"Sys":{"Code":1,"Description":"OK"},' +
                '"zalo_code":0,' +
                '"zalo_message":"OK",' +
                '"result":{' +
                    '"templateId":"' + templateId + '",' +
                    '"templateName":"Controller ZNS",' +
                    '"status":"ENABLE",' +
                    '"previewUrl":"https://preview.example/' + templateId + '",' +
                    '"listParams":[' +
                        '{"name":"amount_' + templateId + '","require":true,"type":"NUMBER","maxLength":20,"minLength":1,"acceptNull":false}' +
                    ']' +
                '}}'
            );

            return res;
        }
    }

    @IsTest
    static void testUpdateZNSTemplatesEmptyResult() {
        Test.setMock(HttpCalloutMock.class, new ZNSControllerHttpMock('empty'));

        Test.startTest();
        FEC_ZNSTemplateController.UpdateResult result =
            FEC_ZNSTemplateController.updateZNSTemplates();
        Test.stopTest();

        System.assertEquals(false, result.success, 'Expected failure result for empty API data.');
        System.assertEquals('Không có dữ liệu trả về từ API.', result.message);
        System.assertEquals(0, result.templateCount);
        System.assertEquals(0, result.paramCount);
    }

    @IsTest
    static void testUpdateZNSTemplatesDmlExceptionPath() {
        Test.setMock(HttpCalloutMock.class, new ZNSControllerHttpMock('dmlError'));

        Boolean thrown = false;

        Test.startTest();
        try {
            FEC_ZNSTemplateController.updateZNSTemplates();
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected DML exception to be wrapped as AuraHandledException.');
    }

    @IsTest
    static void testUpdateZNSTemplatesCalloutExceptionPath() {
        Test.setMock(HttpCalloutMock.class, new ZNSControllerHttpMock('calloutException'));

        Boolean thrown = false;

        Test.startTest();
        try {
            FEC_ZNSTemplateController.updateZNSTemplates();
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected CalloutException to be wrapped as AuraHandledException.');
    }

    @IsTest
    static void testUpdateResultConstructor() {
        FEC_ZNSTemplateController.UpdateResult result =
            new FEC_ZNSTemplateController.UpdateResult(true, 'OK', 3, 4);

        System.assertEquals(true, result.success);
        System.assertEquals('OK', result.message);
        System.assertEquals(3, result.templateCount);
        System.assertEquals(4, result.paramCount);
    }
}