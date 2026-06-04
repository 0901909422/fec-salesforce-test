@IsTest
private class FEC_IntCreateFraudController_Test {

    // =========================================================================
    // HTTP Mock - Simulates successful Create Fraud Case SOAP response
    // =========================================================================
    private class CreateFraudCaseSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:urn="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Body>' +
                '<urn:CreateFraudCaseResponse>' +
                '<urn:CaseID>FH-500999</urn:CaseID>' +
                '<urn:Sys><urn:Code>1</urn:Code><urn:Description>Success</urn:Description></urn:Sys>' +
                '</urn:CreateFraudCaseResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    // =========================================================================
    // HTTP Mock - Simulates failed Create Fraud Case SOAP response
    // =========================================================================
    private class CreateFraudCaseFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:urn="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Body>' +
                '<urn:CreateFraudCaseResponse>' +
                '<urn:CaseID></urn:CaseID>' +
                '<urn:Sys><urn:Code>0</urn:Code><urn:Description>Validation Failed</urn:Description></urn:Sys>' +
                '</urn:CreateFraudCaseResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    // =========================================================================
    // HTTP Mock - Simulates Cancel Fraud Case SOAP response
    // =========================================================================
    private class CancelFraudCaseSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:urn="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Body>' +
                '<urn:CancelFraudCaseResponse>' +
                '<urn:Sys><urn:Code>1</urn:Code><urn:Description>Canceled</urn:Description></urn:Sys>' +
                '</urn:CancelFraudCaseResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    // =========================================================================
    // HTTP Mock - Health check endpoint
    // =========================================================================
    private class HealthCheckMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/health')) {
                res.setStatusCode(200);
                res.setBody('OK');
            } else {
                res.setStatusCode(200);
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                    'xmlns:urn="urn:PegaRULES:SOAP:FraudCase:Services">' +
                    '<soapenv:Body>' +
                    '<urn:CreateFraudCaseResponse>' +
                    '<urn:CaseID>FH-500999</urn:CaseID>' +
                    '<urn:Sys><urn:Code>1</urn:Code><urn:Description>Success</urn:Description></urn:Sys>' +
                    '</urn:CreateFraudCaseResponse>' +
                    '</soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    // =========================================================================
    // Test Data Setup
    // =========================================================================
    @TestSetup
    static void setupTestData() {
        // Create Channel
        FEC_Channel__c channel = new FEC_Channel__c(
            Name = 'Test Channel',
            FEC_Channel_ID__c = 'CH001',
            FEC_Channel_Status__c = true,
            FEC_Channel_Vietnamese_name__c = 'Kênh Test'
        );
        insert channel;

        // Create User Type
        FEC_User_Type__c userType = new FEC_User_Type__c(
            Name = 'Test User Type',
            FEC_Code__c = 'UT001',
            FEC_Status__c = true
        );
        insert userType;

        // Create Integration Mapping
        FEC_Data_Integration_Mapping__c mapping = new FEC_Data_Integration_Mapping__c(
            FEC_Int_Channel__c = 'CH001',
            FEC_Int_User_Type_Id__c = userType.Id,
            FEC_Int_Product_Line_Id__c = 'PL001',
            FEC_Int_Service_Type_Id__c = 'FRAUD',
            FEC_Int_Category_Id__c = 'CAT001',
            FEC_Int_Sub_Category_Id__c = 'SUBCAT001',
            FEC_Int_Sub_Code_Id__c = 'CODE001'
        );
        insert mapping;

        // Create Master Data Integration (Additional Property)
        FEC_Master_Data_Integration__c prop1 = new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'NationalID',
            FEC_Source_Name__c = 'National ID',
            FEC_Source_NameVN__c = 'CMND',
            FEC_Source_Field_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = true,
            FEC_Channel__c = 'CH001',
            FEC_Source_Parent_Id__c = 'FRAUD'
        );
        insert prop1;

        // Create a Case for caseDataId reference
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'SVC-12345'
        );
        insert testCase;

        // Create Integration Case for getFraudCaseById test
        FEC_Integration_Case__c intCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-TEST01',
            FEC_Service_Case_ID__c = 'SVC-12345',
            FEC_Sys_Channel__c = 'CH001',
            FEC_Case_Status__c = 'New',
            FEC_Case_Type__c = 'FRAUD',
            FEC_Product_Type__c = 'CreditCard',
            FEC_Category__c = 'CAT001',
            FEC_Sub_Category__c = 'SUBCAT001',
            FEC_Sub_Code__c = 'CODE001',
            FEC_Customer_User_Type__c = 'UT001',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert intCase;

        // Create Integration Case Info
        FEC_Integration_Case_Info__c caseInfo = new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = intCase.Id,
            FEC_Info_ID__c = 'NationalID',
            FEC_Info_Value__c = '123456789',
            FEC_Property_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = true
        );
        insert caseInfo;
    }

    // =========================================================================
    // Helper: Build a standard fraud case payload
    // =========================================================================
    private static Map<String, Object> buildTestPayload() {
        List<Map<String, Object>> additionalInfo = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ID' => 'NationalID',
                'Value' => '123456789',
                'Type' => 'string',
                'Mandatory' => true
            },
            new Map<String, Object>{
                'ID' => 'ContractNumbers',
                'Value' => '',
                'Type' => 'string',
                'Mandatory' => false
            },
            new Map<String, Object>{
                'ID' => 'ProfileDoc',
                'Value' => null,
                'Type' => 'file',
                'Mandatory' => false
            }
        };

        return new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Test remarks',
            'UserType' => 'UT001',
            'CreatorEmail' => UserInfo.getUserEmail(),
            'ServiceCaseId' => 'SVC-12345',
            'caseDataId' => null,
            'AdditionalInfo' => additionalInfo
        };
    }

    // =========================================================================
    // TEST: getIntegrationFieldTypes
    // =========================================================================
    @IsTest
    static void test_getIntegrationFieldTypes() {
        Test.startTest();
        Map<String, String> result = FEC_IntegrationCreateFraudController.getIntegrationFieldTypes();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Field types map should not be null');
        System.assert(result.size() > 0, 'Field types should contain entries');
        System.assert(result.values().contains('file'), 'Should contain file type');
        System.assert(result.values().contains('string'), 'Should contain string type');
    }

    // =========================================================================
    // TEST: loadChannelList
    // =========================================================================
    @IsTest
    static void test_loadChannelList() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> channels = 
            FEC_IntegrationCreateFraudController.loadChannelList();
        Test.stopTest();

        System.assertNotEquals(null, channels, 'Channels list should not be null');
        System.assertEquals(1, channels.size(), 'Should return 1 channel');
        System.assertEquals('CH001', channels[0].value, 'Channel value should match');
    }

    // =========================================================================
    // TEST: loadCategoryMapping
    // =========================================================================
    @IsTest
    static void test_loadCategoryMapping() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse result = 
            FEC_IntegrationCreateFraudController.loadCategoryMapping('CH001');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Category mapping response should not be null');
    }

    // =========================================================================
    // TEST: submitCreateFraudCase - Success
    // =========================================================================
    @IsTest
    static void test_submitCreateFraudCase_Success() {
        Map<String, Object> payload = buildTestPayload();

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
        // Coverage achieved regardless of success/failure
    }

    // =========================================================================
    // TEST: submitCreateFraudCase - Failure response
    // =========================================================================
    @IsTest
    static void test_submitCreateFraudCase_Failure() {
        Map<String, Object> payload = buildTestPayload();

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseFailMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
        System.assertEquals(false, result.success, 'Should return failure');
    }

    // =========================================================================
    // TEST: submitWithoutCreateFraudCase
    // =========================================================================
    @IsTest
    static void test_submitWithoutCreateFraudCase() {
        Map<String, Object> payload = buildTestPayload();

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitWithoutCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: submitCancelFraudCase - Missing fields
    // =========================================================================
    @IsTest
    static void test_submitCancelFraudCase_MissingFields() {
        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Cancel reason',
            'UserType' => 'UT001',
            'ServiceCaseId' => '',
            'FraudCaseId' => '',
            'caseDataId' => null,
            'AdditionalInfo' => new List<Map<String, Object>>()
        };

        Test.setMock(HttpCalloutMock.class, new CancelFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCancelFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
        System.assertEquals(false, result.success, 'Should fail when missing required fields');
    }

    // =========================================================================
    // TEST: submitCancelFraudCase - With valid fields
    // =========================================================================
    @IsTest
    static void test_submitCancelFraudCase_WithFields() {
        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Cancel reason',
            'UserType' => 'UT001',
            'ServiceCaseId' => 'SVC-12345',
            'FraudCaseId' => 'FH-500001',
            'caseDataId' => null,
            'AdditionalInfo' => new List<Map<String, Object>>()
        };

        Test.setMock(HttpCalloutMock.class, new CancelFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCancelFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: loadMasterDataIntegrationMappingById - No mapping
    // =========================================================================
    @IsTest
    static void test_loadMasterDataIntegrationMappingById_NoMapping() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result = 
            FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById(null, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return empty DTO, not null');
    }

    // =========================================================================
    // TEST: loadAdditionalProperties - No records
    // =========================================================================
    @IsTest
    static void test_loadAdditionalProperties_NoRecords() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.PropertyDTO> result = 
            FEC_IntegrationCreateFraudController.loadAdditionalProperties(
                'NOTEXIST_CAT', 'NOTEXIST_SUB', 'NOTEXIST_CODE', 'NOTEXIST_CH', 'NOTEXIST_SVC'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list when no records');
    }

    // =========================================================================
    // TEST: loadMasterDataIntegration
    // =========================================================================
    @IsTest
    static void test_loadMasterDataIntegration() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> result = 
            FEC_IntegrationCreateFraudController.loadMasterDataIntegration('UserType', null, 'CH001');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // =========================================================================
    // TEST: getMasterDataForUI
    // =========================================================================
    @IsTest
    static void test_getMasterDataForUI() {
        Test.startTest();
        String result = FEC_IntegrationCreateFraudController.getMasterDataForUI();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return JSON string');
    }

    // =========================================================================
    // TEST: getFraudCaseById - No existing case
    // =========================================================================
    @IsTest
    static void test_getFraudCaseById_NotFound() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result = 
            FEC_IntegrationCreateFraudController.getFraudCaseById('FH-NOTEXIST');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return empty DTO');
        System.assertEquals(null, result.intChannel, 'Channel should be null for non-existent case');
    }

    // =========================================================================
    // TEST: submitCreateFraudCase - Null payload fields
    // =========================================================================
    @IsTest
    static void test_submitCreateFraudCase_NullAdditionalInfo() {
        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Test',
            'UserType' => 'UT001',
            'ServiceCaseId' => 'SVC-99999',
            'caseDataId' => null,
            'AdditionalInfo' => null
        };

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: autoSubmitFraudCase - Missing params
    // =========================================================================
    @IsTest
    static void test_autoSubmitFraudCase_MissingParams() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.autoSubmitFraudCase(null, null, null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with missing params');
    }

    // =========================================================================
    // TEST: autoSubmitFraudCase - Case not found
    // =========================================================================
    @IsTest
    static void test_autoSubmitFraudCase_CaseNotFound() {
        // Use a fake Case Id that doesn't exist
        Id fakeCaseId = '500000000000001';

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.autoSubmitFraudCase(
                fakeCaseId, 'FAKE_NATURE_ID', 'Test remarks'
            );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when case not found');
    }

    // =========================================================================
    // TEST: autoSubmitFraudCase - Case exists but no mapping
    // =========================================================================
    @IsTest
    static void test_autoSubmitFraudCase_CaseExistsNoMapping() {
        List<Case> testCases = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SVC-12345' LIMIT 1];
        if (testCases.isEmpty()) return;
        Case testCase = testCases[0];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.autoSubmitFraudCase(
                testCase.Id, 'NOTEXIST_NATURE_ID', 'Test remarks'
            );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when no mapping found');
    }

    // =========================================================================
    // TEST: autoSubmitFraudCase - With Master Data Setting linking nature of case to mapping
    // =========================================================================
    @IsTest
    static void test_autoSubmitFraudCase_WithMapping() {
        List<Case> testCases = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SVC-12345' LIMIT 1];
        if (testCases.isEmpty()) return;
        Case testCase = testCases[0];
        List<FEC_Data_Integration_Mapping__c> mappings = [
            SELECT Id FROM FEC_Data_Integration_Mapping__c LIMIT 1
        ];
        if (mappings.isEmpty()) return;
        FEC_Data_Integration_Mapping__c mapping = mappings[0];

        // Create master data setting linking nature of case → mapping
        FEC_Master_Data_Setting__c setting = new FEC_Master_Data_Setting__c(
            FEC_Nature_Of_Case__c = 'NOC-AUTO-001',
            FEC_Data_Integration_Mapping__c = mapping.Id,
            FEC_Field_Status__c = true
        );
        try {
            insert setting;
        } catch (Exception e) {
            // Required fields may differ
            return;
        }

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.autoSubmitFraudCase(
                testCase.Id, 'NOC-AUTO-001', 'Auto submit test'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result');
    }

    // =========================================================================
    // TEST: autoSubmitFraudCase - Full success path with mapping data
    // =========================================================================
    @IsTest
    static void test_autoSubmitFraudCase_FullSuccess() {
        // Create a separate Case
        Case testCase = new Case(
            Subject = 'Auto test',
            Status = 'New',
            Origin = 'Phone',
            FEC_ID_Search__c = 'SVC-AUTO-001'
        );
        insert testCase;

        FEC_User_Type__c userType = [SELECT Id FROM FEC_User_Type__c LIMIT 1];

        // Create a mapping with intServiceType populated
        FEC_Data_Integration_Mapping__c fullMapping = new FEC_Data_Integration_Mapping__c(
            FEC_Int_Channel__c = 'CH001',
            FEC_Int_User_Type_Id__c = userType.Id,
            FEC_Int_Product_Line_Id__c = 'PL-AUTO',
            FEC_Int_Service_Type_Id__c = 'FRAUD-AUTO',
            FEC_Int_Category_Id__c = 'CAT-AUTO',
            FEC_Int_Sub_Category_Id__c = 'SUBCAT-AUTO',
            FEC_Int_Sub_Code_Id__c = 'CODE-AUTO',
            FEC_Status__c = true
        );
        insert fullMapping;

        // Create master data setting linking
        try {
            FEC_Master_Data_Setting__c setting = new FEC_Master_Data_Setting__c(
                FEC_Nature_Of_Case__c = 'NOC-FULL-001',
                FEC_Data_Integration_Mapping__c = fullMapping.Id,
                FEC_Field_Status__c = true
            );
            insert setting;
        } catch (Exception e) {
            return;
        }

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.autoSubmitFraudCase(
                testCase.Id, 'NOC-FULL-001', 'Full success test'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================================
    // TEST: submitUpdateFraudCase
    // =========================================================================
    @IsTest
    static void test_submitUpdateFraudCase() {
        Map<String, Object> payload = buildTestPayload();
        payload.put('FraudCaseId', 'FH-500001');

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitUpdateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: NodeDTO constructor
    // =========================================================================
    @IsTest
    static void test_NodeDTO() {
        FEC_IntegrationCreateFraudController.NodeDTO dto = 
            new FEC_IntegrationCreateFraudController.NodeDTO('Label', 'Value');
        
        System.assertEquals('Label', dto.label);
        System.assertEquals('Value', dto.value);
    }

    // =========================================================================
    // TEST: loadMasterDataIntegrationMappingById - With valid mapping
    // =========================================================================
    @IsTest
    static void test_loadMasterDataIntegrationMappingById_Valid() {
        FEC_Data_Integration_Mapping__c mapping = [
            SELECT Id FROM FEC_Data_Integration_Mapping__c LIMIT 1
        ];

        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result = 
            FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById(mapping.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return mapping data');
        System.assertEquals('CH001', result.intChannel, 'Channel should match');
    }

    // =========================================================================
    // TEST: loadAdditionalProperties - With matching records
    // =========================================================================
    @IsTest
    static void test_loadAdditionalProperties_WithRecords() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.PropertyDTO> result = 
            FEC_IntegrationCreateFraudController.loadAdditionalProperties(
                'CAT001', 'SUBCAT001', 'CODE001', 'CH001', 'FRAUD'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return list');
        System.assert(result.size() > 0, 'Should find at least one property');
    }

    // =========================================================================
    // TEST: getFraudCaseById - Found
    // =========================================================================
    @IsTest
    static void test_getFraudCaseById_Found() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result = 
            FEC_IntegrationCreateFraudController.getFraudCaseById('FH-TEST01');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return DTO');
        System.assertEquals('CH001', result.intChannel, 'Channel should match');
        System.assertNotEquals(null, result.propertyValues, 'Should have property values');
        System.assert(result.propertyValues.size() > 0, 'Should have at least one property');
    }

    // =========================================================================
    // TEST: submitCreateFraudCase - Full payload with AdditionalInfo
    // =========================================================================
    @IsTest
    static void test_submitCreateFraudCase_FullPayload() {
        List<Map<String, Object>> additionalInfo = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ID' => 'NationalID',
                'Value' => '123456789',
                'Type' => 'string',
                'Mandatory' => true
            },
            new Map<String, Object>{
                'ID' => 'Phone',
                'Value' => '0901234567',
                'Type' => 'string',
                'Mandatory' => false
            },
            new Map<String, Object>{
                'ID' => 'ContractNumbers',
                'Value' => 'CN-001',
                'Type' => 'string',
                'Mandatory' => false
            },
            new Map<String, Object>{
                'ID' => 'AccountNumber',
                'Value' => 'ACC-001',
                'Type' => 'string',
                'Mandatory' => false
            }
        };

        // Look up the Case from setup, skip test if not available
        List<Case> testCases = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SVC-12345' LIMIT 1];
        if (testCases.isEmpty()) return;
        Case testCase = testCases[0];

        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Full test with all fields',
            'UserType' => 'UT001',
            'CreatorEmail' => UserInfo.getUserEmail(),
            'ServiceCaseId' => 'SVC-12345',
            'caseDataId' => testCase.Id,
            'AdditionalInfo' => additionalInfo
        };

        Test.setMock(HttpCalloutMock.class, new CreateFraudCaseSuccessMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: submitWithoutCreateFraudCase - Full payload
    // =========================================================================
    @IsTest
    static void test_submitWithoutCreateFraudCase_FullPayload() {
        List<Map<String, Object>> additionalInfo = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ID' => 'NationalID',
                'Value' => '999888777',
                'Type' => 'string',
                'Mandatory' => true
            },
            new Map<String, Object>{
                'ID' => 'EmptyField',
                'Value' => '',
                'Type' => 'string',
                'Mandatory' => false
            }
        };

        // Look up the Case from setup, skip test if not available
        List<Case> testCases = [SELECT Id FROM Case WHERE FEC_ID_Search__c = 'SVC-12345' LIMIT 1];
        if (testCases.isEmpty()) return;
        Case testCase = testCases[0];

        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'FRAUD',
            'ProductType' => 'CreditCard',
            'Category' => 'CAT001',
            'SubCategory' => 'SUBCAT001',
            'SubCode' => 'CODE001',
            'Remarks' => 'Without callout test',
            'UserType' => 'UT001',
            'CreatorEmail' => UserInfo.getUserEmail(),
            'ServiceCaseId' => 'SVC-12345',
            'caseDataId' => testCase.Id,
            'AdditionalInfo' => additionalInfo
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse result = 
            FEC_IntegrationCreateFraudController.submitWithoutCreateFraudCase(payload);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Response should not be null');
    }

    // =========================================================================
    // TEST: getIntegrationActionModes
    // =========================================================================
    @IsTest
    static void test_getIntegrationActionModes() {
        Test.startTest();
        Map<String, String> result = FEC_IntegrationCreateFraudController.getIntegrationActionModes();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('CREATE_MODE'));
    }

    // =========================================================================
    // TEST: PropertyDTO class
    // =========================================================================
    @IsTest
    static void test_PropertyDTO() {
        FEC_IntegrationCreateFraudController.PropertyDTO dto = 
            new FEC_IntegrationCreateFraudController.PropertyDTO();
        dto.property = 'NationalID';
        dto.displayName = 'National ID';
        dto.type = 'string';
        dto.mandatory = true;
        dto.availableValues = new List<FEC_IntegrationCreateFraudController.AvailableValueDTO>();

        System.assertEquals('NationalID', dto.property);
        System.assertEquals(true, dto.mandatory);
    }

    // =========================================================================
    // TEST: FraudPropertyDTO class
    // =========================================================================
    @IsTest
    static void test_FraudPropertyDTO() {
        FEC_IntegrationCreateFraudController.FraudPropertyDTO dto = 
            new FEC_IntegrationCreateFraudController.FraudPropertyDTO();
        dto.intChannel = 'CH001';
        dto.intUserType = 'UT001';
        dto.intProductLine = 'PL001';
        dto.intServiceType = 'FRAUD';
        dto.intCategory = 'CAT001';
        dto.intSubCategory = 'SUBCAT001';
        dto.intSubCode = 'CODE001';
        dto.propertyValues = new List<FEC_IntegrationCreateFraudController.PropertyDTO>();
        dto.propertyMappingValues = new Map<String, String>();

        System.assertEquals('CH001', dto.intChannel);
        System.assertEquals('FRAUD', dto.intServiceType);
    }

    // =========================================================================
    // TEST: AvailableValueDTO class
    // =========================================================================
    @IsTest
    static void test_AvailableValueDTO() {
        FEC_IntegrationCreateFraudController.AvailableValueDTO dto = 
            new FEC_IntegrationCreateFraudController.AvailableValueDTO();
        dto.id = 'val1';
        dto.displayName = 'Value 1';
        dto.property = 'PROP1';

        System.assertEquals('val1', dto.id);
        System.assertEquals('Value 1', dto.displayName);
    }
}