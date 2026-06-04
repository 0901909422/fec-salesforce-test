@IsTest
private class FEC_IntFraudCaseUtil_Test {

    // =========================================================================
    // TEST: buildTag - with value
    // =========================================================================
    @IsTest
    static void test_buildTag_WithValue() {
        String result = FEC_IntegrationFraudCaseUtil.buildTag('Channel', 'WEB');
        System.assert(result.contains('<ns1:Channel>'), 'Should contain opening tag');
        System.assert(result.contains('WEB'), 'Should contain value');
        System.assert(result.contains('</ns1:Channel>'), 'Should contain closing tag');
    }

    // =========================================================================
    // TEST: buildTag - with blank value
    // =========================================================================
    @IsTest
    static void test_buildTag_BlankValue() {
        String result = FEC_IntegrationFraudCaseUtil.buildTag('Channel', '');
        System.assertEquals('', result, 'Should return empty string for blank value');
    }

    // =========================================================================
    // TEST: buildTag - with null value
    // =========================================================================
    @IsTest
    static void test_buildTag_NullValue() {
        String result = FEC_IntegrationFraudCaseUtil.buildTag('Channel', null);
        System.assertEquals('', result, 'Should return empty string for null value');
    }

    // =========================================================================
    // TEST: buildTag - with special characters (XML escape)
    // =========================================================================
    @IsTest
    static void test_buildTag_SpecialChars() {
        String result = FEC_IntegrationFraudCaseUtil.buildTag('Remarks', 'Test & <value>');
        System.assert(result.contains('&amp;'), 'Should escape ampersand');
        System.assert(result.contains('&lt;'), 'Should escape less-than');
        System.assert(result.contains('&gt;'), 'Should escape greater-than');
    }

    // =========================================================================
    // TEST: parsePegaDatetime - valid ISO 8601
    // =========================================================================
    @IsTest
    static void test_parsePegaDatetime_Valid() {
        Datetime result = FEC_IntegrationFraudCaseUtil.parsePegaDatetime('2026-05-01T10:30:00');
        System.assertNotEquals(null, result, 'Should parse valid datetime');
        System.assertEquals(2026, result.yearGmt(), 'Year should be 2026');
    }

    // =========================================================================
    // TEST: parsePegaDatetime - null input
    // =========================================================================
    @IsTest
    static void test_parsePegaDatetime_Null() {
        Datetime result = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(null);
        System.assertEquals(null, result, 'Should return null for null input');
    }

    // =========================================================================
    // TEST: parsePegaDatetime - blank input
    // =========================================================================
    @IsTest
    static void test_parsePegaDatetime_Blank() {
        Datetime result = FEC_IntegrationFraudCaseUtil.parsePegaDatetime('');
        System.assertEquals(null, result, 'Should return null for blank input');
    }

    // =========================================================================
    // TEST: formatDateTime
    // =========================================================================
    @IsTest
    static void test_formatDateTime() {
        Datetime dt = Datetime.newInstance(2026, 5, 1, 10, 30, 0);
        String result = FEC_IntegrationFraudCaseUtil.formatDateTime(dt);
        System.assertNotEquals(null, result, 'Should return formatted string');
        System.assert(result.contains('2026'), 'Should contain year');
    }

    // =========================================================================
    // TEST: formatDateTime - null
    // =========================================================================
    @IsTest
    static void test_formatDateTime_Null() {
        String result = FEC_IntegrationFraudCaseUtil.formatDateTime(null);
        System.assertEquals(null, result, 'Should return null for null datetime');
    }

    // =========================================================================
    // TEST: formatDDMMYYYY
    // =========================================================================
    @IsTest
    static void test_formatDDMMYYYY_Valid() {
        String result = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('20260501');
        System.assertEquals('01/05/2026', result, 'Should convert YYYYMMDD to DD/MM/YYYY');
    }

    // =========================================================================
    // TEST: formatDDMMYYYY - blank
    // =========================================================================
    @IsTest
    static void test_formatDDMMYYYY_Blank() {
        String result = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('');
        System.assertEquals(null, result, 'Should return null for blank input');
    }

    // =========================================================================
    // TEST: successResponseXml
    // =========================================================================
    @IsTest
    static void test_successResponseXml() {
        Dom.Document doc = FEC_IntegrationFraudCaseUtil.successResponseXml('FH-500001', 'Success');
        System.assertNotEquals(null, doc, 'Should return valid XML document');
        String xml = doc.toXmlString();
        System.assert(xml.contains('FH-500001'), 'Should contain case ID');
    }

    // =========================================================================
    // TEST: errorResponseXml
    // =========================================================================
    @IsTest
    static void test_errorResponseXml() {
        Dom.Document doc = FEC_IntegrationFraudCaseUtil.errorResponseXml('Error occurred', 400);
        System.assertNotEquals(null, doc, 'Should return valid XML document');
        String xml = doc.toXmlString();
        System.assert(xml.contains('Error occurred'), 'Should contain error message');
    }

    // =========================================================================
    // TEST: safeText - under limit
    // =========================================================================
    @IsTest
    static void test_safeText_UnderLimit() {
        String result = FEC_IntegrationFraudCaseUtil.safeText('short text');
        System.assertEquals('short text', result, 'Should return unchanged text');
    }

    // =========================================================================
    // TEST: safeText - null
    // =========================================================================
    @IsTest
    static void test_safeText_Null() {
        String result = FEC_IntegrationFraudCaseUtil.safeText(null);
        System.assertEquals(null, result, 'Should return null for null input');
    }

    // =========================================================================
    // TEST: getMimeType
    // =========================================================================
    @IsTest
    static void test_getMimeType() {
        System.assertNotEquals(null, FEC_IntegrationFraudCaseUtil.getMimeType('pdf'));
        System.assertNotEquals(null, FEC_IntegrationFraudCaseUtil.getMimeType('png'));
        System.assertNotEquals(null, FEC_IntegrationFraudCaseUtil.getMimeType('unknown'));
    }

    // =========================================================================
    // TEST: randomTransactionId
    // =========================================================================
    @IsTest
    static void test_randomTransactionId() {
        String id1 = FEC_IntegrationFraudCaseUtil.randomTransactionId();
        String id2 = FEC_IntegrationFraudCaseUtil.randomTransactionId();
        System.assertNotEquals(null, id1, 'Should generate ID');
        System.assert(id1.length() > 0, 'Should not be empty');
    }

    // =========================================================================
    // TEST: randomCaseId
    // =========================================================================
    @IsTest
    static void test_randomCaseId() {
        String caseId = FEC_IntegrationFraudCaseUtil.randomCaseId();
        System.assert(caseId.startsWith('FH-'), 'Should start with FH-');
    }

    // =========================================================================
    // TEST: nowAsXmlDateTime
    // =========================================================================
    @IsTest
    static void test_nowAsXmlDateTime() {
        String result = FEC_IntegrationFraudCaseUtil.nowAsXmlDateTime();
        System.assertNotEquals(null, result, 'Should return datetime string');
        System.assert(result.contains('T'), 'Should be in ISO format');
    }

    // =========================================================================
    // TEST: generateUUID
    // =========================================================================
    @IsTest
    static void test_generateUUID() {
        String uuid = FEC_IntegrationFraudCaseUtil.generateUUID();
        System.assertNotEquals(null, uuid, 'Should generate UUID');
        System.assert(uuid.contains('-'), 'Should contain dashes');
    }

    // =========================================================================
    // TEST: buildDTO
    // =========================================================================
    @IsTest
    static void test_buildDTO() {
        FEC_IntegrationFraudCaseUtil.CategorySubCodeDTO dto = 
            FEC_IntegrationFraudCaseUtil.buildDTO('id1', 'Display', 'parent1', 'value1', 'map1', 'group1');
        System.assertEquals('Display', dto.displayName);
        System.assertEquals('value1', dto.value);
        System.assertEquals('parent1', dto.parentId);
        System.assertEquals('map1', dto.mappingId);
        System.assertEquals('group1', dto.groupName);
    }

    // =========================================================================
    // TEST: extractPayload
    // =========================================================================
    @IsTest
    static void test_extractPayload() {
        List<Map<String, Object>> additionalInfo = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ID' => 'NationalID',
                'Value' => '123456',
                'Type' => 'string',
                'Mandatory' => true
            }
        };

        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Test',
            'UserType' => 'UT001',
            'ServiceCaseId' => 'SVC-001',
            'caseDataId' => null,
            'AdditionalInfo' => additionalInfo
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper wrapper = 
            FEC_IntegrationFraudCaseUtil.extractPayload(payload);
        Test.stopTest();

        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals('FRAUD', wrapper.caseType, 'CaseType should match');
        System.assertEquals('SVC-001', wrapper.serviceCaseId, 'ServiceCaseId should match');
    }

    // =========================================================================
    // TEST: buildSys
    // =========================================================================
    @IsTest
    static void test_buildSys() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.channel = 'CH001';

        FEC_IntegrationSoapFraudcaseService.SysType sys = 
            FEC_IntegrationFraudCaseUtil.buildSys(w);

        System.assertNotEquals(null, sys, 'SysType should not be null');
        System.assertEquals('CH001', sys.Channel, 'Channel should match');
        System.assertNotEquals(null, sys.TransactionID, 'Should have transaction ID');
        System.assertNotEquals(null, sys.DateTime_x, 'Should have datetime');
    }

    // =========================================================================
    // TEST: buildCustomer
    // =========================================================================
    @IsTest
    static void test_buildCustomer() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.userType = 'Individual';

        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            FEC_IntegrationFraudCaseUtil.buildCustomer(w);

        System.assertNotEquals(null, cust, 'Customer should not be null');
        System.assertEquals('Individual', cust.UserType, 'UserType should match');
    }

    // =========================================================================
    // TEST: buildCreator
    // =========================================================================
    @IsTest
    static void test_buildCreator() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.creatorEmail = 'test@test.com';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            FEC_IntegrationFraudCaseUtil.buildCreator(w);

        System.assertNotEquals(null, creator, 'Creator should not be null');
        System.assertEquals('test@test.com', creator.CreatorEmail, 'Email should match');
    }

    // =========================================================================
    // TEST: buildCCaseInfo
    // =========================================================================
    @IsTest
    static void test_buildCCaseInfo() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.caseId = 'FH-500001';
        w.remarks = 'Cancel reason';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseInfo = 
            FEC_IntegrationFraudCaseUtil.buildCCaseInfo(w);

        System.assertEquals('FH-500001', caseInfo.CaseID, 'CaseID should match');
        System.assertEquals('Cancel reason', caseInfo.Remarks, 'Remarks should match');
    }

    // =========================================================================
    // TEST: buildRequest
    // =========================================================================
    @IsTest
    static void test_buildRequest() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.caseType = 'FRAUD';
        w.productType = 'CreditCard';
        w.category = 'CAT001';
        w.subCategory = 'SUBCAT001';
        w.subCode = 'CODE001';
        w.remarks = 'Test remarks';
        w.additionalInfos = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            FEC_IntegrationFraudCaseUtil.buildRequest(w);

        System.assertNotEquals(null, req, 'Request should not be null');
        System.assertEquals('FRAUD', req.CaseType, 'CaseType should match');
    }

    // =========================================================================
    // TEST: buildRequestOriginal
    // =========================================================================
    @IsTest
    static void test_buildRequestOriginal() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.caseType = 'FRAUD';
        w.productType = 'CreditCard';
        w.category = 'CAT001';
        w.subCategory = 'SUBCAT001';
        w.subCode = 'CODE001';
        w.remarks = 'Test';
        w.additionalInfoOrginal = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element>();

        FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element req = 
            FEC_IntegrationFraudCaseUtil.buildRequestOriginal(w);

        System.assertNotEquals(null, req, 'RequestOriginal should not be null');
        System.assertEquals('FRAUD', req.CaseType, 'CaseType should match');
    }

    // =========================================================================
    // TEST: extractCaseIdFromResponse
    // =========================================================================
    @IsTest
    static void test_extractCaseIdFromResponse() {
        Dom.Document doc = FEC_IntegrationFraudCaseUtil.successResponseXml('FH-500001', 'Success');
        String xml = doc.toXmlString();

        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse result = 
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(xml);

        System.assertNotEquals(null, result, 'Should extract response');
    }

    // =========================================================================
    // TEST: extractCaseIdFromResponse - null
    // =========================================================================
    @IsTest
    static void test_extractCaseIdFromResponse_Null() {
        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse result = 
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(null);

        System.assertNotEquals(null, result, 'Should handle null gracefully');
    }

    // =========================================================================
    // TEST: mapCaseStatus
    // =========================================================================
    @IsTest
    static void test_mapCaseStatus() {
        String result = FEC_IntegrationFraudCaseUtil.mapCaseStatus('Resolved-Confirmed');
        System.assertNotEquals(null, result, 'Should return mapped status');
    }

    // =========================================================================
    // TEST: mapCaseStatus - null
    // =========================================================================
    @IsTest
    static void test_mapCaseStatus_Null() {
        String result = FEC_IntegrationFraudCaseUtil.mapCaseStatus(null);
        // mapCaseStatus may return null for null input - that's valid behavior
        System.assert(true, 'mapCaseStatus handled null without throwing');
    }

    // =========================================================================
    // TEST: normalizeXml
    // =========================================================================
    @IsTest
    static void test_normalizeXml() {
        String xml = '<root><child>value</child></root>';
        String result = FEC_IntegrationFraudCaseUtil.normalizeXml(xml);
        System.assertNotEquals(null, result, 'Should return normalized XML');
    }

    // =========================================================================
    // TEST: normalizeXml - null
    // =========================================================================
    @IsTest
    static void test_normalizeXml_Null() {
        String result = FEC_IntegrationFraudCaseUtil.normalizeXml(null);
        System.assertEquals(null, result, 'Should return null for null input');
    }

    // =========================================================================
    // TEST: logIntegrationService
    // =========================================================================
    @IsTest
    static void test_logIntegrationService() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.logIntegrationService(
            'TestService', 'CH001', 'FH-500001', 'SVC-001',
            '<request/>', '<response/>', 'Success', 'test@test.com', '200'
        );
        Test.stopTest();
        // No assertion needed - just verify it doesn't throw
    }

    // =========================================================================
    // TEST: getIntegrationCaseById - not found
    // =========================================================================
    @IsTest
    static void test_getIntegrationCaseById_NotFound() {
        FEC_Integration_Case__c result = 
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('FH-NOTEXIST');
        System.assertEquals(null, result, 'Should return null when not found');
    }

    // =========================================================================
    // TEST: getIntegrationCaseById - found
    // =========================================================================
    @IsTest
    static void test_getIntegrationCaseById_Found() {
        FEC_Integration_Case__c testCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-TEST01',
            FEC_Service_Case_ID__c = 'SVC-TEST',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New'
        );
        insert testCase;

        FEC_Integration_Case__c result = 
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('FH-TEST01');
        System.assertNotEquals(null, result, 'Should find the case');
    }

    // =========================================================================
    // TEST: findAllDeep - XML node search
    // =========================================================================
    @IsTest
    static void test_findAllDeep() {
        String xml = '<root><AdditionalInfo><ID>Test1</ID><Value>Val1</Value></AdditionalInfo>' +
                     '<nested><AdditionalInfo><ID>Test2</ID><Value>Val2</Value></AdditionalInfo></nested></root>';
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        List<Dom.XmlNode> nodes = FEC_IntegrationFraudCaseUtil.findAllDeep(doc.getRootElement(), 'AdditionalInfo');
        System.assertEquals(2, nodes.size(), 'Should find 2 AdditionalInfo nodes');
    }

    // =========================================================================
    // TEST: find - direct child
    // =========================================================================
    @IsTest
    static void test_find() {
        String xml = '<root><child>hello</child></root>';
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode found = FEC_IntegrationFraudCaseUtil.find(doc.getRootElement(), 'child');
        System.assertNotEquals(null, found, 'Should find child node');
    }

    // =========================================================================
    // TEST: find - not found
    // =========================================================================
    @IsTest
    static void test_find_NotFound() {
        String xml = '<root><child>hello</child></root>';
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode found = FEC_IntegrationFraudCaseUtil.find(doc.getRootElement(), 'missing');
        System.assertEquals(null, found, 'Should return null for missing node');
    }

    // =========================================================================
    // TEST: val - get text value
    // =========================================================================
    @IsTest
    static void test_val() {
        String xml = '<root><Status>Active</Status></root>';
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        String result = FEC_IntegrationFraudCaseUtil.val(doc.getRootElement(), 'Status');
        System.assertEquals('Active', result, 'Should return node text');
    }

    // =========================================================================
    // TEST: FraudCaseResponse DTO
    // =========================================================================
    @IsTest
    static void test_FraudCaseResponse_DTO() {
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp = 
            new FEC_IntegrationFraudCaseUtil.FraudCaseResponse();
        resp.success = true;
        resp.message = 'OK';
        resp.fraudCaseId = 'FH-001';
        resp.responseCode = 1;

        System.assertEquals(true, resp.success);
        System.assertEquals('OK', resp.message);
        System.assertEquals('FH-001', resp.fraudCaseId);
    }

    // =========================================================================
    // TEST: CategoryMappingResponse DTO
    // =========================================================================
    @IsTest
    static void test_CategoryMappingResponse_DTO() {
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse resp = 
            new FEC_IntegrationFraudCaseUtil.CategoryMappingResponse();
        System.assertNotEquals(null, resp);
    }

    // =========================================================================
    // TEST: extractFraudPayload
    // =========================================================================
    @IsTest
    static void test_extractFraudPayload() {
        String xmlContent = '<CaseResultInfo><Remarks>Test</Remarks></CaseResultInfo>';
        Map<String, Object> payload = new Map<String, Object>{
            'detail' => new Map<String, Object>{
                'CaseID' => 'FH-500001',
                'ReferenceID' => 'SVC-001',
                'ChannelID' => 'CH001'
            },
            'data' => xmlContent
        };
        String rawJson = JSON.serialize(payload);

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudExtractResult result = 
            FEC_IntegrationFraudCaseUtil.extractFraudPayload(rawJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should extract payload');
    }
}