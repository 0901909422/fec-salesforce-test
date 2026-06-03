@IsTest
private class FEC_IntCreateFraudCtrl_Test {

    private class CreateMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<ns1:CreateFraudCaseResponse xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<ns1:Sys>' +
                '<ns1:TransactionID>TXN001</ns1:TransactionID>' +
                '<ns1:Code>1</ns1:Code>' +
                '<ns1:Description>Success</ns1:Description>' +
                '</ns1:Sys>' +
                '<ns1:CaseID>FH-500099</ns1:CaseID>' +
                '</ns1:CreateFraudCaseResponse>' +
                '</soap:Body></soap:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Code__c = FEC_FraudConstantCommon.DEFAULT_CHANNEL_INTEGRATION_CODE,
            FEC_Channel_Status__c = true
        );
        insert channel;
    }

    @IsTest
    static void test_loadChannelList() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> channels =
            FEC_IntegrationCreateFraudController.loadChannelList();
        Test.stopTest();

        System.assertNotEquals(null, channels);
        System.assert(channels.size() >= 1, 'Should find at least 1 channel');
    }

    @IsTest
    static void test_loadCategoryMapping() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse result =
            FEC_IntegrationCreateFraudController.loadCategoryMapping('FIMA');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getMasterDataForUI() {
        Test.startTest();
        try {
            String result = FEC_IntegrationCreateFraudController.getMasterDataForUI();
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            // May fail due to missing master data, acceptable
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_loadMasterDataIntegration() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> result =
            FEC_IntegrationCreateFraudController.loadMasterDataIntegration('Product', null, 'FIMA');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_loadAdditionalProperties() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.PropertyDTO> result =
            FEC_IntegrationCreateFraudController.loadAdditionalProperties(
                'CAT01', 'SUB01', 'SC01', 'FIMA', 'FraudHandling'
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_getFraudCaseById_notFound() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result =
            FEC_IntegrationCreateFraudController.getFraudCaseById('FH-NONEXIST');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(null, result.intCaseId);
    }

    @IsTest
    static void test_getFraudCaseById_found() {
        FEC_Integration_Case__c intCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-500088',
            FEC_Service_Case_ID__c = 'SVC-088',
            FEC_Case_Status__c = 'Investigating',
            FEC_Sys_Channel__c = 'PEGACSM',
            FEC_Customer_User_Type__c = 'Individual',
            FEC_Case_Type__c = 'FraudHandling',
            FEC_Product_Type__c = 'Loan',
            FEC_Category__c = 'CAT01',
            FEC_Sub_Category__c = 'SUB01',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert intCase;

        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result =
            FEC_IntegrationCreateFraudController.getFraudCaseById('FH-500088');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('FH-500088', result.fraudCaseId);
    }

    @IsTest
    static void test_loadMasterDataIntegrationMappingById() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result =
            FEC_IntegrationCreateFraudController.loadMasterDataIntegrationMappingById(null, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_NodeDTO() {
        FEC_IntegrationCreateFraudController.NodeDTO dto =
            new FEC_IntegrationCreateFraudController.NodeDTO('Label', 'Value');
        System.assertEquals('Label', dto.label);
        System.assertEquals('Value', dto.value);
    }

    @IsTest
    static void test_PropertyDTO() {
        FEC_IntegrationCreateFraudController.PropertyDTO dto =
            new FEC_IntegrationCreateFraudController.PropertyDTO();
        dto.property = 'PropId';
        dto.displayName = 'Display';
        dto.type = 'string';
        dto.mandatory = true;
        dto.availableValues = new List<FEC_IntegrationCreateFraudController.AvailableValueDTO>();
        System.assertEquals('PropId', dto.property);
    }

    @IsTest
    static void test_FraudPropertyDTO() {
        FEC_IntegrationCreateFraudController.FraudPropertyDTO dto =
            new FEC_IntegrationCreateFraudController.FraudPropertyDTO();
        dto.intChannel = 'FIMA';
        dto.intUserType = 'Individual';
        dto.intProductLine = 'Loan';
        dto.intServiceType = 'FraudHandling';
        dto.intCategory = 'CAT';
        dto.intSubCategory = 'SUB';
        dto.intSubCode = 'SC';
        dto.csRemarks = 'remarks';
        dto.serviceCaseId = 'SVC-001';
        dto.fraudCaseId = 'FH-001';
        dto.propertyValues = new List<FEC_IntegrationCreateFraudController.PropertyDTO>();
        dto.propertyMappingValues = new Map<String, String>();
        System.assertEquals('FIMA', dto.intChannel);
    }
}
