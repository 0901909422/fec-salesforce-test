@IsTest
private class FEC_GetAssetsList_Test {

    // XML Mock phản hồi từ server
    private static final String MOCK_XML_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetAssetsListResponse>' +
        '      <Sys><Code>1</Code><Description>Success</Description></Sys>' +
        '      <Assets>' +
        '        <Asset>' +
        '          <Type>Vehicle</Type><Cost>10000</Cost><EngineNo>ENG001</EngineNo><ChasisNo>CH001</ChasisNo>' +
        '          <AssetBoughtOn>2026-01-01</AssetBoughtOn>' +
        '        </Asset>' +
        '      </Assets>' +
        '      <Collaterals>' +
        '        <Collateral><Value>5000</Value><MakeDate>2026-01-01</MakeDate></Collateral>' +
        '      </Collaterals>' +
        '    </GetAssetsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    private static final String MOCK_XML_NO_COLLATERAL =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetAssetsListResponse>' +
        '      <Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '      <Assets><Asset><Type>Bike</Type><Cost></Cost><AmountPledged></AmountPledged>' +
        '      <AssetBoughtOn></AssetBoughtOn></Asset></Assets>' +
        '    </GetAssetsListResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test.example.com',
            FEC_Enviroment__c = FEC_ConstantCommon.ENVIROMENT_NON_PRODUCTION
        );
        Case c = new Case(Subject = 'Test Case', FEC_Contract_Number__c = 'CTR123');
        insert c;
    }

    @IsTest
    static void testGetAssetsList_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));
        
        FEC_GetAssetsList.AssetsListRequest req = new FEC_GetAssetsList.AssetsListRequest();
        req.ContractNumber = 'CTR123';

        Test.startTest();
        FEC_GetAssetsList.AssetsListResult res = FEC_GetAssetsList.getAssetsList(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('Vehicle', res.assets[0].type);
    }

    @IsTest
    static void testUpdateCaseAssets_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_Asset__c asset = FEC_GetAssetsList.updateCaseAssets(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, asset.Id);
        System.assertEquals('ENG001', asset.FEC_Engine_No__c);
        System.assertEquals(10000, asset.FEC_Asset_Cost__c);
    }

    @IsTest
    static void testBuildEnvelope_ValidationAndEscapeXml() {
        FEC_GetAssetsList.AssetsListRequest req = new FEC_GetAssetsList.AssetsListRequest();
        req.ContractNumber = 'A&B<>"\'';
        String timestamp = '2026-06-01 10:00:00';

        Test.startTest();
        String envelope = FEC_GetAssetsList.buildEnvelope(req, 'TXN-ESC', timestamp);
        FEC_GetAssetsList.AssetsListResult nullXml = FEC_GetAssetsList.parseResponse(null, 500);
        FEC_GetAssetsList.AssetsListResult badXml = FEC_GetAssetsList.parseResponse('not-valid-xml', 200);
        Test.stopTest();

        System.assert(envelope.contains('&amp;'));
        System.assert(envelope.contains('&lt;'));
        System.assertEquals(false, nullXml.success);
        System.assertEquals(false, badXml.success);
    }

    @IsTest
    static void testBuildEnvelope_ValidationErrors() {
        FEC_GetAssetsList.AssetsListRequest req = new FEC_GetAssetsList.AssetsListRequest();
        req.ContractNumber = 'CTR123';
        String ts = '2026-06-01 10:00:00';

        Boolean transIdError = false;
        Boolean timestampError = false;
        Boolean contractError = false;

        Test.startTest();
        try {
            FEC_GetAssetsList.buildEnvelope(req, '', ts);
        } catch (FEC_APIServiceException e) {
            transIdError = true;
        }
        try {
            FEC_GetAssetsList.buildEnvelope(req, 'TXN', '');
        } catch (FEC_APIServiceException e) {
            timestampError = true;
        }
        req.ContractNumber = '';
        try {
            FEC_GetAssetsList.buildEnvelope(req, 'TXN', ts);
        } catch (FEC_APIServiceException e) {
            contractError = true;
        }
        Test.stopTest();

        System.assertEquals(true, transIdError);
        System.assertEquals(true, timestampError);
        System.assertEquals(true, contractError);
    }

    @IsTest
    static void testParseResponse_MalformedStructure() {
        String noResponseBody =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body></soapenv:Body></soapenv:Envelope>';
        String noSys =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><GetAssetsListResponse></GetAssetsListResponse></soapenv:Body></soapenv:Envelope>';
        String namespaced =
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><ns0:GetAssetsListResponse xmlns:ns0="http://fecredit.com.vn/CIF_LoanInfo">' +
            '<Sys><Code>1</Code></Sys></ns0:GetAssetsListResponse></soapenv:Body></soapenv:Envelope>';

        Test.startTest();
        FEC_GetAssetsList.AssetsListResult r1 = FEC_GetAssetsList.parseResponse(noResponseBody, 200);
        FEC_GetAssetsList.AssetsListResult r2 = FEC_GetAssetsList.parseResponse(noSys, 200);
        FEC_GetAssetsList.AssetsListResult r3 = FEC_GetAssetsList.parseResponse(namespaced, 200);
        Test.stopTest();

        System.assertEquals(false, r1.success);
        System.assertEquals(false, r2.success);
        System.assertEquals(true, r3.success);
    }

    @IsTest
    static void testGetAssetsList_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new ThrowingHttpMock());

        FEC_GetAssetsList.AssetsListRequest req = new FEC_GetAssetsList.AssetsListRequest();
        req.ContractNumber = 'CTR123';

        Test.startTest();
        FEC_GetAssetsList.AssetsListResult res = FEC_GetAssetsList.getAssetsList(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.errorMessage);
    }

    @IsTest
    static void testSendRequest_NonMockEndpoint() {
        FEC_API_Setting__c settings = FEC_API_Setting__c.getOrgDefaults();
        settings.FEC_Call_Mock__c = false;
        update settings;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_RESPONSE));
        FEC_GetAssetsList.AssetsListRequest req = new FEC_GetAssetsList.AssetsListRequest();
        req.ContractNumber = 'CTR123';

        Test.startTest();
        String envelope = FEC_GetAssetsList.buildEnvelope(req, 'TXN-SEND', '2026-06-01 10:00:00');
        HttpResponse res = FEC_GetAssetsList.sendRequest(envelope);
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testUpdateCaseAssets_NullAndInvalidCase() {
        Boolean invalidCaseThrown = false;
        Boolean blankContractThrown = false;

        Test.startTest();
        System.assertEquals(null, FEC_GetAssetsList.updateCaseAssets(null));

        try {
            FEC_GetAssetsList.updateCaseAssets('500000000000001AAA');
        } catch (AuraHandledException e) {
            invalidCaseThrown = true;
        }

        Case noContract = new Case(Subject = 'No Contract');
        insert noContract;
        try {
            FEC_GetAssetsList.updateCaseAssets(noContract.Id);
        } catch (AuraHandledException e) {
            blankContractThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, invalidCaseThrown);
        System.assertEquals(true, blankContractThrown);
    }

    @IsTest
    static void testUpdateCaseAssets_SearchContractAndUpsertExisting() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_NO_COLLATERAL));

        Case searchOnly = new Case(
            Subject = 'Search Contract Case',
            FEC_Search_Contract_Number__c = '  CTR-SEARCH  '
        );
        insert searchOnly;

        FEC_Asset__c existing = new FEC_Asset__c(FEC_Case__c = searchOnly.Id, FEC_Engine_No__c = 'OLD');
        insert existing;

        Test.startTest();
        FEC_Asset__c updated = FEC_GetAssetsList.updateCaseAssets(searchOnly.Id);
        Test.stopTest();

        FEC_Asset__c reloaded = [
            SELECT Id, FEC_Asset_Type__c, FEC_Asset_Cost__c, FEC_Make_Date__c
            FROM FEC_Asset__c
            WHERE Id = :updated.Id
        ];
        System.assertEquals(existing.Id, reloaded.Id);
        System.assertEquals('Bike', reloaded.FEC_Asset_Type__c);
        System.assertEquals(null, reloaded.FEC_Asset_Cost__c);
        System.assertEquals(null, reloaded.FEC_Make_Date__c);
    }

    @IsTest
    static void testUpdateCaseAssets_Error() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        // Mock lỗi API (Code != 1)
        String errorXml = MOCK_XML_RESPONSE.replace('<Code>1</Code>', '<Code>0</Code>');
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, errorXml));

        Test.startTest();
        try {
            FEC_GetAssetsList.updateCaseAssets(c.Id);
            System.assert(false, 'Phải throw exception khi API trả về lỗi.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    private class ThrowingHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code; String body;
        MockHttpResponseGenerator(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}