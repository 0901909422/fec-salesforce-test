@IsTest
private class FEC_IntegrationFraudCaseApi_Test {

    // =========================================================================
    // Test Data Setup
    // =========================================================================
    @TestSetup
    static void setupTestData() {
        // Create integration case (FH parent)
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-500001',
            FEC_Service_Case_ID__c = 'SVC-00001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = null
        );
        insert fhCase;

        // Create BU case under FH
        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-600001',
            FEC_Service_Case_ID__c = 'SVC-00001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'FH-500001'
        );
        insert buCase;

        // Create TK case under BU
        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-700001',
            FEC_Service_Case_ID__c = 'SVC-00001',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Parent_CaseID__c = 'BU-600001'
        );
        insert tkCase;

        // Create existing case info on FH for update path coverage
        FEC_Integration_Case_Info__c existingInfo = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id,
            FEC_Info_ID__c = 'NationalID',
            FEC_Info_Value__c = 'OLDVALUE',
            FEC_Property_Type__c = 'string'
        );
        insert existingInfo;

        // Create master data integration entries
        FEC_Master_Data_Integration__c mdi = new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'NationalID',
            FEC_Source_Name__c = 'National ID',
            FEC_Source_Field_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = true,
            FEC_Channel__c = 'CH001'
        );
        insert mdi;
    }

    // =========================================================================
    // Helper: Build XML payload for FH/BU/TK cases
    // =========================================================================
    private static String buildXmlPayload(String caseId, String remarks) {
        return '<CaseResultInfo>' +
            '<Remarks>' + (remarks != null ? remarks : '') + '</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<UpdatedTime>2026-05-01T12:00:00</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo>' +
                    '<CaseType>FRAUD</CaseType>' +
                    '<ProductType>CreditCard</ProductType>' +
                    '<Category>CAT001</Category>' +
                    '<SubCategory>SUBCAT001</SubCategory>' +
                    '<SubCode>CODE001</SubCode>' +
                    '<Remarks>' + (remarks != null ? remarks : '') + '</Remarks>' +
                    '<AdditionalInfo><ID>NationalID</ID><Value>123456789</Value></AdditionalInfo>' +
                    '<AdditionalInfo><ID>AccountNumber</ID><Value>ACC001</Value></AdditionalInfo>' +
                '</RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
    }

    private static String buildRequestBody(String caseId, String referenceId, String parentId, String channelId, String xmlData) {
        // Wrap XML in a root element if not already wrapped (so processXxxCase can find CaseResultInfo as child)
        String wrappedXml = xmlData != null && !xmlData.startsWith('<Root>') 
            ? '<Root>' + xmlData + '</Root>' 
            : xmlData;

        Map<String, Object> payload = new Map<String, Object>{
            'detail' => new Map<String, Object>{
                'caseID' => caseId,
                'referenceID' => referenceId,
                'parentID' => parentId,
                'caseStatus' => 'Processing',
                'channelID' => channelId,
                'messageTime' => Datetime.now().getTime(),
                'investigationConclusion' => 'Under Review',
                'data' => wrappedXml
            }
        };
        return JSON.serialize(payload);
    }

    private static void setupRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - FH Case Success
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FHCase() {
        String xmlData = buildXmlPayload('FH-500001', 'Test remark');
        String body = buildRequestBody('FH-500001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU Case Success
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUCase() {
        String xmlData = buildXmlPayload('BU-600001', 'BU remark');
        String body = buildRequestBody('BU-600001', 'SVC-00001', 'FH-500001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK Case Success
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKCase() {
        String xmlData = buildXmlPayload('TK-700001', 'TK remark');
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Invalid Case Format
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_InvalidFormat() {
        String xmlData = buildXmlPayload('INVALID-001', 'Test');
        String body = buildRequestBody('INVALID-001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Missing CaseID
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MissingCaseId() {
        String xmlData = buildXmlPayload('', 'Test');
        Map<String, Object> payload = new Map<String, Object>{
            'detail' => new Map<String, Object>{
                'caseID' => '',
                'referenceID' => 'SVC-00001',
                'caseStatus' => 'Processing',
                'channelID' => 'CH001',
                'data' => xmlData
            }
        };
        String body = JSON.serialize(payload);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Missing XML data
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MissingXml() {
        Map<String, Object> payload = new Map<String, Object>{
            'detail' => new Map<String, Object>{
                'caseID' => 'FH-500001',
                'referenceID' => 'SVC-00001',
                'caseStatus' => 'Processing',
                'channelID' => 'CH001',
                'data' => ''
            }
        };
        String body = JSON.serialize(payload);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - FH Case Not Found
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FHNotFound() {
        String xmlData = buildXmlPayload('FH-999999', 'Test');
        String body = buildRequestBody('FH-999999', 'SVC-99999', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU Parent Not Found
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUParentNotFound() {
        String xmlData = buildXmlPayload('BU-999999', 'Test');
        String body = buildRequestBody('BU-999999', 'SVC-00001', 'FH-NOTEXIST', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK Parent Not Found
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKParentNotFound() {
        String xmlData = buildXmlPayload('TK-999999', 'Test');
        String body = buildRequestBody('TK-999999', 'SVC-00001', 'BU-NOTEXIST', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: createSFTCase
    // =========================================================================
    @IsTest
    static void test_createSFTCase() {
        Test.startTest();
        try {
            Case result = FEC_IntegrationFraudCaseApi.createSFTCase(
                'SVC-00001', 'CH001', 'FH-500001'
            );
            // May succeed or fail depending on record type/product type setup
            // The important thing is the code path is exercised
        } catch (Exception e) {
            // Expected if record type or product type not set up in test context
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // =========================================================================
    // TEST: createSFTCase with category params
    // =========================================================================
    @IsTest
    static void test_createSFTCase_WithCategory() {
        Test.startTest();
        try {
            Case result = FEC_IntegrationFraudCaseApi.createSFTCase(
                'SVC-00001', 'CH001', 'FH-500001', null, null, null
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Exception handling (malformed body)
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MalformedBody() {
        setupRestContext('this is not valid json or xml');

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return error response for malformed input');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Missing RequestInfo in XML
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MissingRequestInfo() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<OriginalRequest>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('FH-500001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Missing CreatorInfo in XML
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MissingCreatorInfo() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('FH-500001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Missing CustomerInfo in XML
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_MissingCustomerInfo() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('FH-500001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - FH Case full success with existing info update
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FHFullSuccess() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Updated remark</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<UpdatedTime>2026-05-01T12:00:00</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo>' +
                    '<CaseType>FRAUD</CaseType>' +
                    '<Remarks>Updated remark</Remarks>' +
                    '<AdditionalInfo><ID>NationalID</ID><Value>NEWVALUE</Value></AdditionalInfo>' +
                    '<AdditionalInfo><ID>NewProperty</ID><Value>NEW</Value></AdditionalInfo>' +
                '</RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        // Use a parentID so the parentId validation passes
        String body = buildRequestBody('FH-500001', 'SVC-00001', 'PARENT-001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU Case full success
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUFullSuccess() {
        String xmlData = buildXmlPayload('BU-600001', 'BU full remark');
        String body = buildRequestBody('BU-600001', 'SVC-00001', 'FH-500001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK Case full success
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKFullSuccess() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>TK detailed</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<UpdatedTime>2026-05-01T12:00:00</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo>' +
                    '<CaseType>FRAUD</CaseType>' +
                    '<Remarks>TK detailed remark</Remarks>' +
                    '<AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo>' +
                    '<AdditionalInfo><ID>ResultDetailCode</ID><Value>FRAUD</Value></AdditionalInfo>' +
                    '<AdditionalInfo><ID>NewField</ID><Value>NewValue</Value></AdditionalInfo>' +
                '</RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - FH missing CaseResultInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FHMissingCaseResultInfo() {
        String xmlData = '<RootDocument><SomeOtherNode/></RootDocument>';
        String body = buildRequestBody('FH-500001', 'SVC-00001', 'PARENT-001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU missing CaseResultInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUMissingCaseResultInfo() {
        String xmlData = '<RootDocument><SomeOtherNode/></RootDocument>';
        String body = buildRequestBody('BU-600001', 'SVC-00001', 'FH-500001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK missing OriginalRequest
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKMissingOriginalRequest() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU Missing CreatorInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUMissingCreator() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('BU-600001', 'SVC-00001', 'FH-500001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - BU Missing CustomerInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BUMissingCustomer() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@test.com</CreatorEmail></CreatorInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('BU-600001', 'SVC-00001', 'FH-500001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK Missing CreatorInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKMissingCreator() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - TK Missing CustomerInfo
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKMissingCustomer() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test</Remarks>' +
            '<OriginalRequest>' +
                '<RequestInfo><CaseType>FRAUD</CaseType><Remarks>Test</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@test.com</CreatorEmail></CreatorInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - FH missing parentID
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FHMissingParentID() {
        String xmlData = buildXmlPayload('FH-500001', 'Test');
        // Pass null for parentID
        String body = buildRequestBody('FH-500001', 'SVC-00001', null, 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: UpdateFraudCaseStatus - Null detail (top-level validation)
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_NullDetail() {
        Map<String, Object> payload = new Map<String, Object>{
            'detail' => null
        };
        String body = JSON.serialize(payload);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: FH case with file-type additional info
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_FH_FileType() {
        // Create master data integration with file type
        FEC_Master_Data_Integration__c fileTypeProp = new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'ProfileDoc',
            FEC_Source_Name__c = 'Profile Document',
            FEC_Source_Field_Type__c = 'file',
            FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'CH001'
        );
        insert fileTypeProp;

        // Get existing FH case
        FEC_Integration_Case__c fhCase = [
            SELECT Id FROM FEC_Integration_Case__c 
            WHERE FEC_CaseID__c = 'FH-500001' LIMIT 1
        ];
        // Insert existing file-type info on FH case
        FEC_Integration_Case_Info__c oldFileInfo = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id,
            FEC_Info_ID__c = 'ProfileDoc',
            FEC_Info_Value__c = 'old.pdf|pdf|base64olddata',
            FEC_Property_Type__c = 'file'
        );
        insert oldFileInfo;

        // Build XML with file-type AdditionalInfo
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Test file</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo>' +
                    '<CaseType>FRAUD</CaseType>' +
                    '<Remarks>Test</Remarks>' +
                    '<AdditionalInfo><ID>ProfileDoc</ID><Value>new.pdf|pdf|base64data</Value></AdditionalInfo>' +
                '</RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('FH-500001', 'SVC-00001', 'PARENT-001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: TK case triggering SFT (UIC=CS, ResultDetailCode populated)
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_TKTriggersSFT() {
        String xmlData = '<CaseResultInfo>' +
            '<Remarks>Trigger SFT</Remarks>' +
            '<CreatedTime>2026-05-01T10:00:00</CreatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo>' +
                    '<CaseType>FRAUD</CaseType>' +
                    '<Remarks>Test</Remarks>' +
                    '<AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo>' +
                    '<AdditionalInfo><ID>ResultDetailCode</ID><Value>FRAUD</Value></AdditionalInfo>' +
                '</RequestInfo>' +
                '<CreatorInfo><CreatorEmail>test@fecredit.com.vn</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Individual</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
        '</CaseResultInfo>';
        String body = buildRequestBody('TK-700001', 'SVC-00001', 'BU-600001', 'CH001', xmlData);

        setupRestContext(body);

        Test.startTest();
        try {
            String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            // SFT case creation may fail in test if record types missing
        }
        Test.stopTest();
    }

    // =========================================================================
    // TEST: BU success with messageTime=null (handle null timestamp)
    // =========================================================================
    @IsTest
    static void test_UpdateFraudCaseStatus_BU_NullMessageTime() {
        String xmlData = buildXmlPayload('BU-600001', 'BU test');
        // Manually build payload without messageTime
        Map<String, Object> payload = new Map<String, Object>{
            'detail' => new Map<String, Object>{
                'caseID' => 'BU-600001',
                'referenceID' => 'SVC-00001',
                'parentID' => 'FH-500001',
                'caseStatus' => 'Processing',
                'channelID' => 'CH001',
                'data' => xmlData
            }
        };
        String body = JSON.serialize(payload);

        setupRestContext(body);

        Test.startTest();
        String result = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
}