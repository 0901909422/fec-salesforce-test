@IsTest
private class FEC_IntegrationFraudCaseUtil_Test {

    @IsTest
    static void test_FieldRule() {
        FEC_Master_Data_Integration__c rec = new FEC_Master_Data_Integration__c(
            FEC_Source_Id__c = 'TestField',
            FEC_Source_Is_Mandatory__c = true,
            FEC_Source_Type__c = 'Product',
            FEC_Source_Field_Type__c = 'string'
        );
        insert rec;

        FEC_Master_Data_Integration__c queried = [
            SELECT FEC_Source_Id__c, FEC_Source_Is_Mandatory__c, FEC_Source_Type__c, FEC_Source_Field_Type__c
            FROM FEC_Master_Data_Integration__c WHERE Id = :rec.Id
        ];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FieldRule rule = new FEC_IntegrationFraudCaseUtil.FieldRule(queried);
        Test.stopTest();

        System.assertEquals('TestField', rule.fieldName);
        System.assertEquals(true, rule.mandatory);
        System.assertEquals('Product', rule.sourceType);
        System.assertEquals('string', rule.fieldType);
    }

    @IsTest
    static void test_FraudCaseResponse() {
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp = new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();
        resp.success = true;
        resp.message = 'OK';
        resp.fraudCaseId = 'FH-100001';
        resp.serviceCaseId = 'SVC-001';
        resp.responseCode = 1;
        resp.responseDescription = 'Success';

        System.assertEquals(true, resp.success);
        System.assertEquals('FH-100001', resp.fraudCaseId);
    }

    @IsTest
    static void test_UpdateCaseResponse() {
        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse ucr = new FEC_IntegrationFraudCaseUtil.UpdateCaseResponse();
        ucr.caseId = 'CASE1';
        ucr.caseMessage = 'msg';
        ucr.caseCode = '1';

        System.assertEquals('CASE1', ucr.caseId);
    }

    @IsTest
    static void test_generateUUID() {
        Test.startTest();
        String uuid = FEC_IntegrationFraudCaseUtil.generateUUID();
        Test.stopTest();

        System.assertNotEquals(null, uuid);
        System.assert(uuid.length() > 0, 'UUID should not be empty');
    }

    @IsTest
    static void test_randomTransactionId() {
        Test.startTest();
        String txnId = FEC_IntegrationFraudCaseUtil.randomTransactionId();
        Test.stopTest();

        System.assertNotEquals(null, txnId);
    }

    @IsTest
    static void test_randomCaseId() {
        Test.startTest();
        String caseId = FEC_IntegrationFraudCaseUtil.randomCaseId();
        Test.stopTest();

        System.assertNotEquals(null, caseId);
    }

    @IsTest
    static void test_nowAsXmlDateTime() {
        Test.startTest();
        String dtStr = FEC_IntegrationFraudCaseUtil.nowAsXmlDateTime();
        Test.stopTest();

        System.assert(dtStr.contains('T'), 'Should contain T separator');
        System.assert(dtStr.endsWith('Z'), 'Should end with Z');
    }

    @IsTest
    static void test_formatDateTime() {
        Datetime dt = Datetime.newInstance(2024, 7, 10, 14, 30, 0);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.formatDateTime(dt);
        String nullResult = FEC_IntegrationFraudCaseUtil.formatDateTime(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(null, nullResult);
    }

    @IsTest
    static void test_formatDDMMYYYY() {
        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('20240710');
        String nullResult = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY(null);
        String shortResult = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('2024');
        Test.stopTest();

        System.assertEquals('10/07/2024', result);
        System.assertEquals(null, nullResult);
        System.assertEquals(null, shortResult);
    }

    @IsTest
    static void test_getMimeType() {
        Test.startTest();
        System.assertEquals(FEC_FraudConstantCommon.MIME_PDF, FEC_IntegrationFraudCaseUtil.getMimeType('pdf'));
        System.assertEquals(FEC_FraudConstantCommon.MIME_PNG, FEC_IntegrationFraudCaseUtil.getMimeType('png'));
        System.assertEquals(FEC_FraudConstantCommon.MIME_DEFAULT, FEC_IntegrationFraudCaseUtil.getMimeType(null));
        System.assertEquals(FEC_FraudConstantCommon.MIME_DEFAULT, FEC_IntegrationFraudCaseUtil.getMimeType('xyz'));
        Test.stopTest();
    }

    @IsTest
    static void test_safeText() {
        Test.startTest();
        String shortText = 'Hello';
        System.assertEquals('Hello', FEC_IntegrationFraudCaseUtil.safeText(shortText));
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.safeText(null));
        System.assertEquals('', FEC_IntegrationFraudCaseUtil.safeText(''));
        Test.stopTest();
    }

    @IsTest
    static void test_buildTag() {
        Test.startTest();
        String tag = FEC_IntegrationFraudCaseUtil.buildTag('CaseID', 'FH-001');
        String emptyTag = FEC_IntegrationFraudCaseUtil.buildTag('CaseID', '');
        Test.stopTest();

        System.assert(tag.contains('CaseID'));
        System.assert(tag.contains('FH-001'));
        System.assertEquals('', emptyTag);
    }

    @IsTest
    static void test_mapCaseStatus() {
        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.mapCaseStatus('Allocating');
        String nullResult = FEC_IntegrationFraudCaseUtil.mapCaseStatus(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(null, nullResult);
    }

    @IsTest
    static void test_normalizeXml() {
        String xmlWithBom = '\uFEFF<root><child>test</child></root>';

        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.normalizeXml(xmlWithBom);
        String nullResult = FEC_IntegrationFraudCaseUtil.normalizeXml(null);
        Test.stopTest();

        System.assert(result.startsWith('<'), 'Should start with < after BOM removal');
        System.assertEquals(null, nullResult);
    }

    @IsTest
    static void test_cleanJson() {
        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.cleanJson(null);
        String emptyResult = FEC_IntegrationFraudCaseUtil.cleanJson('');
        Test.stopTest();

        System.assertEquals(null, result);
        System.assertEquals('', emptyResult);
    }

    @IsTest
    static void test_extractXml() {
        String raw = 'prefix<root><child/></root>suffix';

        Test.startTest();
        String result = FEC_IntegrationFraudCaseUtil.extractXml(raw);
        Test.stopTest();

        System.assert(result.startsWith('<'));
        System.assert(result.endsWith('>'));
    }

    @IsTest
    static void test_extractCaseIdFromResponse() {
        String xml = '<Response><CaseId>FH-001</CaseId><Message>OK</Message><Sys><Code>1</Code></Sys></Response>';

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse resp =
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(xml);
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @IsTest
    static void test_findAndVal() {
        Dom.Document doc = new Dom.Document();
        doc.load('<root><child>Hello</child></root>');
        Dom.XmlNode root = doc.getRootElement();

        Test.startTest();
        Dom.XmlNode child = FEC_IntegrationFraudCaseUtil.find(root, 'child');
        String val = FEC_IntegrationFraudCaseUtil.val(root, 'child');
        List<Dom.XmlNode> all = FEC_IntegrationFraudCaseUtil.findAll(root, 'child');
        List<Dom.XmlNode> allDeep = FEC_IntegrationFraudCaseUtil.findAllDeep(root, 'child');
        Test.stopTest();

        System.assertNotEquals(null, child);
        System.assertEquals('Hello', val);
        System.assertEquals(1, all.size());
        System.assert(allDeep.size() >= 1);
    }

    @IsTest
    static void test_getIntegrationCaseById() {
        Test.startTest();
        FEC_Integration_Case__c result = FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('NONEXIST');
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void test_parsePegaDatetime() {
        Test.startTest();
        Datetime result = FEC_IntegrationFraudCaseUtil.parsePegaDatetime('2024-07-10T14:30:00.000Z');
        Datetime nullResult = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(null, nullResult);
    }

    @IsTest
    static void test_extractPayload() {
        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'Fraud',
            'ProductType' => 'Card',
            'Category' => 'CAT01',
            'SubCategory' => 'SUB01',
            'SubCode' => 'SC01',
            'Remarks' => 'Test',
            'UserType' => 'Individual',
            'ServiceCaseId' => 'SVC-001',
            'caseDataId' => 'CASE-001',
            'AdditionalInfo' => new List<Object>()
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper wrapper =
            FEC_IntegrationFraudCaseUtil.extractPayload(payload);
        Test.stopTest();

        System.assertNotEquals(null, wrapper);
    }
}
