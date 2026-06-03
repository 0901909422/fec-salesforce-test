@IsTest
private class FEC_IntegrationFraudCaseUtil_Test {

    private static final String INTEGRATION_CASE_ID = 'FH-UTIL-001';

    private static Schema.SObjectType integrationCaseType() {
        return Schema.getGlobalDescribe().get('FEC_Integration_Case__c');
    }

    @TestSetup
    static void setupData() {
        Schema.SObjectType caseType = integrationCaseType();
        if (caseType == null) {
            return;
        }
        SObject rec = caseType.newSObject();
        rec.put('FEC_CaseID__c', INTEGRATION_CASE_ID);
        rec.put('FEC_Sys_Channel__c', 'CRM');
        insert rec;
    }

    // ─── XML / JSON parsing ─────────────────────────────────────────────

    @IsTest
    static void testNormalizeXml() {
        String raw = 'junk <root><data>hello</data></root> trailing';
        String result = FEC_IntegrationFraudCaseUtil.normalizeXml(raw);
        System.assertEquals('<root><data>hello</data></root>', result);
    }

    @IsTest
    static void testNormalizeXml_entitiesAndJsonEscapes() {
        String raw = 'prefix&lt;tag&gt;&quot;val&quot;\\\\end';
        String result = FEC_IntegrationFraudCaseUtil.normalizeXml(raw);
        System.assert(result.contains('<tag>'));
        System.assert(result.contains('"val"'));
    }

    @IsTest
    static void testNormalizeXml_blankReturnsBlank() {
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.normalizeXml(null));
        System.assertEquals('', FEC_IntegrationFraudCaseUtil.normalizeXml(''));
    }

    @IsTest
    static void testExtractXml() {
        String raw = 'noise {"data":"<A><B>1</B></A>"} noise';
        System.assertEquals('<A><B>1</B></A>', FEC_IntegrationFraudCaseUtil.extractXml(raw));
    }

    @IsTest
    static void testExtractXml_noXmlReturnsNull() {
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.extractXml('no tags here'));
    }

    @IsTest
    static void testExtractFraudPayload() {
        String json =
            '{"detail":{"caseID":"FH-99","data":"<Case><Id>1</Id></Case>"}}';

        FEC_IntegrationFraudCaseUtil.FraudExtractResult result =
            FEC_IntegrationFraudCaseUtil.extractFraudPayload(json);

        System.assertNotEquals(null, result.detail);
        System.assertEquals('<Case><Id>1</Id></Case>', result.xmlData);
        System.assertEquals('FH-99', (String) result.detail.get('caseID'));
        System.assertEquals(false, result.detail.containsKey('data'));
    }

    @IsTest
    static void testCleanJson() {
        String raw =
            '{"detail":{"data":"<root>long xml</root>","messageTime":1700000000000}}';
        String cleaned = FEC_IntegrationFraudCaseUtil.cleanJson(raw);
        System.assert(cleaned.contains('"data":""'));
        System.assert(cleaned.contains('"messageTime"'));
    }

    // ─── DOM helpers ────────────────────────────────────────────────────

    @IsTest
    static void testDomFindValFindAll() {
        Dom.Document doc = new Dom.Document();
        doc.load(
            '<Root>' +
                '<RequestInfo><Remarks>note</Remarks></RequestInfo>' +
                '<Items><Item>A</Item><Item>B</Item></Items>' +
            '</Root>'
        );
        Dom.XmlNode root = doc.getRootElement();

        System.assertEquals('note', FEC_IntegrationFraudCaseUtil.val(root, 'Remarks'));
        System.assertNotEquals(null, FEC_IntegrationFraudCaseUtil.find(root, 'RequestInfo'));
        System.assertEquals(2, FEC_IntegrationFraudCaseUtil.findAll(root, 'Item').size());
    }

    @IsTest
    static void testFindAllDeep() {
        Dom.Document doc = new Dom.Document();
        doc.load(
            '<Root>' +
                '<Wrapper><AdditionalInfo><Id>1</Id></AdditionalInfo></Wrapper>' +
                '<AdditionalInfo><Id>2</Id></AdditionalInfo>' +
            '</Root>'
        );
        List<Dom.XmlNode> nodes =
            FEC_IntegrationFraudCaseUtil.findAllDeep(doc.getRootElement(), 'AdditionalInfo');
        System.assertEquals(2, nodes.size());
    }

    // ─── Formatters / mappers ───────────────────────────────────────────

    @IsTest
    static void testFormatDDMMYYYY() {
        System.assertEquals('25/12/2025', FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('20251225'));
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('2025'));
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('abcd1225'));
    }

    @IsTest
    static void testFormatDateTime() {
        DateTime dt = DateTime.newInstance(2025, 12, 25, 10, 30, 45);
        String formatted = FEC_IntegrationFraudCaseUtil.formatDateTime(dt);
        System.assert(String.isNotBlank(formatted));
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.formatDateTime(null));
    }

    @IsTest
    static void testParsePegaDatetime() {
        DateTime dt = FEC_IntegrationFraudCaseUtil.parsePegaDatetime('2025-09-10T10:07:22.263Z');
        System.assertNotEquals(null, dt);
        System.assertEquals(2025, dt.yearGmt());
        System.assertEquals(10, dt.hourGmt());
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.parsePegaDatetime(null));
    }

    @IsTest
    static void testMapCaseStatus() {
        System.assertEquals(
            FEC_FraudConstantCommon.SEC_INVESTIGATING,
            FEC_IntegrationFraudCaseUtil.mapCaseStatus(FEC_FraudConstantCommon.ALLOCATING)
        );
        System.assertEquals(
            FEC_FraudConstantCommon.FRAUD_SEC_INVESTIGATING,
            FEC_IntegrationFraudCaseUtil.mapCaseStatus(FEC_FraudConstantCommon.NEW_STATUS)
        );
        System.assertEquals('CustomStatus', FEC_IntegrationFraudCaseUtil.mapCaseStatus('CustomStatus'));
        System.assertEquals(null, FEC_IntegrationFraudCaseUtil.mapCaseStatus(null));
    }

    // ─── XML builders / response parsers ────────────────────────────────

    @IsTest
    static void testBuildTag() {
        System.assertEquals(
            '<ns1:Status>Active</ns1:Status>',
            FEC_IntegrationFraudCaseUtil.buildTag('Status', 'Active')
        );
        System.assertEquals('', FEC_IntegrationFraudCaseUtil.buildTag('Status', ''));
        String escaped = FEC_IntegrationFraudCaseUtil.buildTag('Msg', 'a & b <c>');
        System.assert(escaped.contains('&amp;'));
        System.assert(escaped.contains('&lt;'));
    }

    @IsTest
    static void testSuccessAndErrorResponseXml() {
        RestContext.response = new RestResponse();

        Dom.Document okDoc = FEC_IntegrationFraudCaseUtil.successResponseXml(
            'FH-100',
            'Updated'
        );
        String okXml = okDoc.toXmlString();
        System.assert(okXml.contains('FH-100'));
        System.assertEquals(FEC_FraudConstantCommon.SUCCESSFULL, RestContext.response.statusCode);

        RestContext.response = new RestResponse();
        Dom.Document errDoc = FEC_IntegrationFraudCaseUtil.errorResponseXml(
            'Bad request',
            FEC_FraudConstantCommon.CLIENT_ERROR
        );
        String errXml = errDoc.toXmlString();
        System.assert(errXml.contains('Bad request'));
        System.assertEquals(FEC_FraudConstantCommon.CLIENT_ERROR, RestContext.response.statusCode);
    }

    @IsTest
    static void testExtractCaseIdFromResponse() {
        String xml =
            '<Response>' +
                '<Success>true</Success>' +
                '<CaseID>FH-200</CaseID>' +
                '<Message>Done</Message>' +
            '</Response>';

        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse res =
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(xml);

        System.assertEquals('FH-200', res.caseId);
        System.assertEquals('Done', res.caseMessage);
        System.assertEquals('true', res.caseCode);
    }

    @IsTest
    static void testExtractCaseIdFromResponse_blankXml() {
        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse res =
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse('');
        System.assertEquals(null, res.caseId);
    }

    // ─── Utilities ──────────────────────────────────────────────────────

    @IsTest
    static void testGetMimeType() {
        System.assertEquals(
            FEC_FraudConstantCommon.MIME_PDF,
            FEC_IntegrationFraudCaseUtil.getMimeType('pdf')
        );
        System.assertEquals(
            FEC_FraudConstantCommon.MIME_DEFAULT,
            FEC_IntegrationFraudCaseUtil.getMimeType(null)
        );
        System.assertEquals(
            FEC_FraudConstantCommon.MIME_DEFAULT,
            FEC_IntegrationFraudCaseUtil.getMimeType('unknown-ext')
        );
    }

    @IsTest
    static void testSafeText() {
        System.assertEquals('short', FEC_IntegrationFraudCaseUtil.safeText('short'));
        String longText = 'x'.repeat(FEC_FraudConstantCommon.NUMBER_MAX_LENGTH + 100);
        System.assertEquals(
            FEC_FraudConstantCommon.NUMBER_MAX_LENGTH,
            FEC_IntegrationFraudCaseUtil.safeText(longText).length()
        );
    }

    @IsTest
    static void testBuildDTO() {
        FEC_IntegrationFraudCaseUtil.CategorySubCodeDTO dto =
            FEC_IntegrationFraudCaseUtil.buildDTO(
                'id1', 'Label', 'parent', 'VAL', 'map1', 'Group'
            );
        System.assertEquals('id1', dto.id);
        System.assertEquals('Label', dto.displayName);
        System.assertEquals('parent', dto.parentId);
        System.assertEquals('VAL', dto.value);
        System.assertEquals('map1', dto.mappingId);
        System.assertEquals('Group', dto.groupName);
    }

    @IsTest
    static void testCategoryMappingResponseConstructor() {
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse res =
            new FEC_IntegrationFraudCaseUtil.CategoryMappingResponse();
        System.assertNotEquals(null, res.categoryAll);
        System.assertEquals(0, res.subCategoriesAll.size());
    }

    @IsTest
    static void testRandomAndUuidHelpers() {
        System.assert(String.isNotBlank(FEC_IntegrationFraudCaseUtil.randomTransactionId()));
        System.assert(FEC_IntegrationFraudCaseUtil.randomCaseId().startsWith('FH-'));
        System.assert(String.isNotBlank(FEC_IntegrationFraudCaseUtil.generateUUID()));
        System.assert(FEC_IntegrationFraudCaseUtil.nowAsXmlDateTime().contains('T'));
    }

    @IsTest
    static void testGetIntegrationCaseById() {
        if (integrationCaseType() == null) {
            System.assert(true, 'Skipped: FEC_Integration_Case__c not on org.');
            return;
        }

        System.assertNotEquals(
            null,
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById(INTEGRATION_CASE_ID)
        );
        System.assertEquals(
            null,
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('NOT-EXIST')
        );
    }
}
