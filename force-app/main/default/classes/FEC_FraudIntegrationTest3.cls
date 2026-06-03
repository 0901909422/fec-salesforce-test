/**
 * @description Test class focused on FEC_IntegrationFraudCaseApi (REST API) and
 *              FEC_IntegrationMappingController to achieve >= 75% coverage.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Fraud
 */
@IsTest
private class FEC_FraudIntegrationTest3 {

    /* =========================================================
     * TEST DATA SETUP
     * ========================================================= */
    @TestSetup
    static void setupTestData() {
        // Channel
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Channel_ID__c = 'FIMA',
            FEC_Code__c = 'FIMA',
            Name = 'FIMA Channel',
            FEC_Channel_Vietnamese_name__c = 'Kênh FIMA',
            FEC_Channel_Status__c = true
        );
        insert channel;

        // User Type
        FEC_User_Type__c ut = new FEC_User_Type__c(
            FEC_Code__c = 'EXISTING',
            Name = 'Existing Customer',
            FEC_Name_VN__c = 'Khách hàng hiện hữu',
            FEC_Status__c = true,
            FEC_Pos_Order__c = 1
        );
        insert ut;

        // Additional Field
        FEC_Additional_Field__c addField = new FEC_Additional_Field__c(
            Name = 'Transaction Amount',
            FEC_Unique_ID__c = 'TXN_AMOUNT',
            FEC_Type__c = 'string',
            FEC_Name_VN__c = 'Số tiền giao dịch'
        );
        insert addField;

        // Master Data Integration records (Product → CaseType → Category → SubCategory → SubCode → AdditionalProperty → AvailableValues)
        List<FEC_Master_Data_Integration__c> masterData = new List<FEC_Master_Data_Integration__c>();

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'Product', FEC_Source_Id__c = 'PROD-01',
            FEC_Source_Name__c = 'Credit Card', FEC_Source_NameVN__c = 'Thẻ tín dụng',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'CaseType', FEC_Source_Id__c = 'CT-01',
            FEC_Source_Parent_Id__c = 'PROD-01',
            FEC_Source_Name__c = 'Fraud Review', FEC_Source_NameVN__c = 'Xem xét gian lận',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'Category', FEC_Source_Id__c = 'CAT-01',
            FEC_Source_Parent_Id__c = 'CT-01',
            FEC_Source_Name__c = 'Card Fraud', FEC_Source_NameVN__c = 'Gian lận thẻ',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'SubCategory', FEC_Source_Id__c = 'SUBCAT-01',
            FEC_Source_Parent_Id__c = 'CAT-01',
            FEC_Source_Name__c = 'Lost Card', FEC_Source_NameVN__c = 'Mất thẻ',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'SubCode', FEC_Source_Id__c = 'SC-01',
            FEC_Source_Parent_Id__c = 'SUBCAT-01',
            FEC_Source_Name__c = 'Stolen', FEC_Source_NameVN__c = 'Bị đánh cắp',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty', FEC_Source_Id__c = 'AP-01',
            FEC_Source_Parent_Id__c = 'SC-01',
            FEC_Source_Name__c = 'Amount', FEC_Source_NameVN__c = 'Số tiền',
            FEC_Source_Field_Type__c = 'string', FEC_Source_Is_Mandatory__c = true,
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty', FEC_Source_Id__c = 'AP-02',
            FEC_Source_Parent_Id__c = 'SC-01',
            FEC_Source_Name__c = 'Location', FEC_Source_NameVN__c = 'Vị trí',
            FEC_Source_Field_Type__c = 'list', FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 2
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AvailableValues', FEC_Source_Id__c = 'AV-01',
            FEC_Source_Parent_Id__c = 'AP-02',
            FEC_Source_Name__c = 'HCM', FEC_Source_NameVN__c = 'TP.HCM',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AvailableValues', FEC_Source_Id__c = 'AV-02',
            FEC_Source_Parent_Id__c = 'AP-02',
            FEC_Source_Name__c = 'HN', FEC_Source_NameVN__c = 'Hà Nội',
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 2
        ));
        insert masterData;

        // Integration Cases (FH → BU → TK hierarchy)
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-700001', FEC_Service_Case_ID__c = 'S-700001',
            FEC_Case_Status__c = 'Fraud/SEC Investigating', FEC_Sys_Channel__c = 'FIMA',
            FEC_Category__c = 'CAT-01', FEC_Sub_Category__c = 'SUBCAT-01',
            FEC_Sub_Code__c = 'SC-01', FEC_Creator_Email__c = 'fraud@test.com'
        );
        insert fhCase;

        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-700002', FEC_Parent_CaseID__c = 'FH-700001',
            FEC_Case_Status__c = 'SEC Investigating', FEC_Sys_Channel__c = 'FIMA'
        );
        insert buCase;

        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-700003', FEC_Parent_CaseID__c = 'BU-700002',
            FEC_Service_Case_ID__c = 'S-700003',
            FEC_Case_Status__c = 'SEC Investigating', FEC_Sys_Channel__c = 'FIMA',
            FEC_Investigation_Conclusion__c = 'Under review'
        );
        insert tkCase;

        // Case Info for TK
        List<FEC_Integration_Case_Info__c> infos = new List<FEC_Integration_Case_Info__c>();
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id, FEC_Info_ID__c = 'NationalID', FEC_Info_Value__c = '123456789'));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = fhCase.Id, FEC_Info_ID__c = 'Phone', FEC_Info_Value__c = '0909123456'));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id, FEC_Info_ID__c = 'UIC', FEC_Info_Value__c = 'CS'));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id, FEC_Info_ID__c = 'ResultDetailCode', FEC_Info_Value__c = 'CUS'));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id, FEC_Info_ID__c = 'TaskName', FEC_Info_Value__c = 'Investigate'));
        insert infos;

        // Integration Mapping
        FEC_Data_Integration_Mapping__c mapping = new FEC_Data_Integration_Mapping__c(
            FEC_Int_Channel__c = 'FIMA',
            FEC_Int_User_Type_Id__c = ut.Id,
            FEC_Int_Product_Line_Id__c = 'PROD-01',
            FEC_Int_Service_Type_Id__c = 'CT-01',
            FEC_Int_Category_Id__c = 'CAT-01',
            FEC_Int_Sub_Category_Id__c = 'SUBCAT-01',
            FEC_Int_Sub_Code_Id__c = 'SC-01',
            FEC_Process_Change_Status__c = 'New',
            FEC_Status__c = true
        );
        insert mapping;

        // Mapping Info children
        List<FEC_Data_Integration_Mapping_Info__c> mapInfos = new List<FEC_Data_Integration_Mapping_Info__c>();
        mapInfos.add(new FEC_Data_Integration_Mapping_Info__c(
            FEC_Data_Integration_Mapping__c = mapping.Id,
            FEC_Integrating_Property__c = 'AP-01',
            FEC_Integrating_Property_Type__c = 'string',
            FEC_CSM_Property__c = 'Subject',
            FEC_CSM_Property_Type__c = 'text',
            FEC_Auto_Mapping_Property__c = false,
            FEC_Mandatory__c = true
        ));
        mapInfos.add(new FEC_Data_Integration_Mapping_Info__c(
            FEC_Data_Integration_Mapping__c = mapping.Id,
            FEC_Integrating_Property__c = 'AP-02',
            FEC_Integrating_Property_Type__c = 'list',
            FEC_CSM_Property__c = 'Description',
            FEC_CSM_Property_Type__c = 'text',
            FEC_Auto_Mapping_Property__c = true,
            FEC_Mandatory__c = false,
            FEC_Auto_Mapping_Property_Source__c = 'TXN_AMOUNT'
        ));
        insert mapInfos;
    }

    /* =========================================================
     * HELPER: Build XML for REST API tests
     * ========================================================= */
    private static String buildFullXml() {
        return '<CaseResultInfo>' +
            '<Remarks>Test remark</Remarks>' +
            '<CreatedTime>2025-09-10T10:07:22.263Z</CreatedTime>' +
            '<UpdatedTime>2026-01-15T08:30:00.000Z</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo><Remarks>Original</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>creator@test.com</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Existing</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
            '<AdditionalInfo><ID>NationalID</ID><Value>123456789</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>Phone</ID><Value>0909123456</Value></AdditionalInfo>' +
        '</CaseResultInfo>';
    }

    private static String buildPayload(String caseId, String referenceId, String channelId, String parentId, String caseStatus) {
        return '{"detail":{"caseID":"' + caseId + '","referenceID":"' + referenceId +
            '","channelID":"' + channelId + '","parentID":"' + parentId +
            '","caseStatus":"' + caseStatus +
            '","investigationConclusion":"Done","data":"' +
            buildFullXml().replace('"', '\\"') +
            '","messageTime":1700000000000}}';
    }

    private static void setupRestContext(String payload) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * FEC_IntegrationFraudCaseApi TESTS
     * ========================================================= */

    // FH Case - success path (existing case + parentID not null)
    @IsTest
    static void testApi_FH_SuccessUpdate() {
        String payload = buildPayload('FH-700001', 'S-700001', 'FIMA', 'PARENT-X', 'Investigating');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    // FH Case - parentID null → error
    @IsTest
    static void testApi_FH_ParentNull() {
        // parentID is null in JSON → should return error
        String payload = '{"detail":{"caseID":"FH-700001","referenceID":"S-700001","channelID":"FIMA","caseStatus":"New","investigationConclusion":"","data":"' +
            buildFullXml().replace('"', '\\"') + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    // FH Case - case not found
    @IsTest
    static void testApi_FH_CaseNotFound() {
        String payload = buildPayload('FH-NOTEXIST', 'S-NOTEXIST', 'FIMA', 'P-X', 'New');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'FH not found should fail');
    }

    // BU Case - success path
    @IsTest
    static void testApi_BU_Success() {
        String payload = buildPayload('BU-700002', 'S-700001', 'FIMA', 'FH-700001', 'Investigating');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'BU response should not be null');
    }

    // BU Case - parent not found
    @IsTest
    static void testApi_BU_ParentNotFound() {
        String payload = buildPayload('BU-NEW001', 'S-001', 'FIMA', 'FH-NOTEXIST', 'New');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'BU parent not found should fail');
    }

    // TK Case - success path (with SFT creation trigger: UIC=CS + ResultDetailCode=CUS)
    @IsTest
    static void testApi_TK_SuccessWithSFT() {
        String tkXml = '<CaseResultInfo>' +
            '<CreatedTime>2025-09-10T10:07:22Z</CreatedTime>' +
            '<UpdatedTime>2026-01-15T08:30:00Z</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo><Remarks>TK remark</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>tk@test.com</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Existing</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
            '<AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>ResultDetailCode</ID><Value>CUS</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>Phone</ID><Value>0901234567</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>NationalID</ID><Value>999888777</Value></AdditionalInfo>' +
        '</CaseResultInfo>';

        String payload = '{"detail":{"caseID":"TK-700003","referenceID":"S-700003","channelID":"FIMA","parentID":"BU-700002","caseStatus":"Investigating","investigationConclusion":"Done","data":"' +
            tkXml.replace('"', '\\"') + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'TK response should not be null');
    }

    // TK Case - parent not found
    @IsTest
    static void testApi_TK_ParentNotFound() {
        String payload = buildPayload('TK-NEW001', 'S-001', 'FIMA', 'BU-NOTEXIST', 'New');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'TK parent not found should fail');
    }

    // TK Case - without SFT trigger (UIC != CS)
    @IsTest
    static void testApi_TK_NoSFT() {
        String tkXml = '<CaseResultInfo>' +
            '<CreatedTime>2025-09-10T10:07:22Z</CreatedTime>' +
            '<UpdatedTime>2026-01-15T08:30:00Z</UpdatedTime>' +
            '<OriginalRequest>' +
                '<RequestInfo><Remarks>TK no SFT</Remarks></RequestInfo>' +
                '<CreatorInfo><CreatorEmail>nosft@test.com</CreatorEmail></CreatorInfo>' +
                '<CustomerInfo><UserType>Existing</UserType></CustomerInfo>' +
            '</OriginalRequest>' +
            '<AdditionalInfo><ID>UIC</ID><Value>OTHER</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>TaskName</ID><Value>Check</Value></AdditionalInfo>' +
        '</CaseResultInfo>';

        String payload = '{"detail":{"caseID":"TK-700003","referenceID":"S-700003","channelID":"FIMA","parentID":"BU-700002","caseStatus":"Pending","investigationConclusion":"","data":"' +
            tkXml.replace('"', '\\"') + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'TK without SFT response should not be null');
    }

    // Invalid case format
    @IsTest
    static void testApi_InvalidFormat() {
        String payload = buildPayload('XX-999', 'S-001', 'FIMA', '', 'New');
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Invalid format should fail');
    }

    // Missing caseID
    @IsTest
    static void testApi_MissingCaseId() {
        String payload = '{"detail":{"caseID":"","referenceID":"S-001","channelID":"FIMA","data":"<Root/>","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Empty caseID should fail');
    }

    // Missing XML data
    @IsTest
    static void testApi_MissingXmlData() {
        String payload = '{"detail":{"caseID":"FH-001","referenceID":"S-001","channelID":"FIMA","data":"","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Missing XML should fail');
    }

    // Missing CaseResultInfo node in XML
    @IsTest
    static void testApi_FH_MissingCaseResultInfo() {
        String badXml = '<Root><SomethingElse>data</SomethingElse></Root>';
        String payload = '{"detail":{"caseID":"FH-700001","referenceID":"S-700001","channelID":"FIMA","parentID":"P-X","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Missing CaseResultInfo should fail');
    }

    // Missing RequestInfo node
    @IsTest
    static void testApi_FH_MissingRequestInfo() {
        String badXml = '<CaseResultInfo><Remarks>X</Remarks><OriginalRequest><CreatorInfo><CreatorEmail>a@b.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>X</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-700001","referenceID":"S-700001","channelID":"FIMA","parentID":"P-X","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Missing RequestInfo should fail');
    }

    // Missing CreatorInfo node
    @IsTest
    static void testApi_FH_MissingCreatorInfo() {
        String badXml = '<CaseResultInfo><Remarks>X</Remarks><OriginalRequest><RequestInfo><Remarks>Y</Remarks></RequestInfo><CustomerInfo><UserType>X</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-700001","referenceID":"S-700001","channelID":"FIMA","parentID":"P-X","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Missing CreatorInfo should fail');
    }

    // Missing CustomerInfo node
    @IsTest
    static void testApi_FH_MissingCustomerInfo() {
        String badXml = '<CaseResultInfo><Remarks>X</Remarks><OriginalRequest><RequestInfo><Remarks>Y</Remarks></RequestInfo><CreatorInfo><CreatorEmail>a@b.com</CreatorEmail></CreatorInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-700001","referenceID":"S-700001","channelID":"FIMA","parentID":"P-X","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Missing CustomerInfo should fail');
    }

    // BU Case - missing CaseResultInfo
    @IsTest
    static void testApi_BU_MissingCaseResultInfo() {
        String badXml = '<Root><Nothing/></Root>';
        String payload = '{"detail":{"caseID":"BU-700002","referenceID":"S-001","channelID":"FIMA","parentID":"FH-700001","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'BU missing CaseResultInfo should fail');
    }

    // TK Case - missing OriginalRequest
    @IsTest
    static void testApi_TK_MissingOriginalRequest() {
        String badXml = '<CaseResultInfo><Remarks>X</Remarks></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"TK-700003","referenceID":"S-700003","channelID":"FIMA","parentID":"BU-700002","caseStatus":"New","data":"' +
            badXml + '","messageTime":1700000000000}}';
        setupRestContext(payload);

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'TK missing OriginalRequest should fail');
    }

    /* =========================================================
     * FEC_IntegrationMappingController TESTS
     * ========================================================= */

    // loadUserTypeList
    @IsTest
    static void testMapping_loadUserTypeList() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadUserTypeList();
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return user types');
    }

    // loadChannelList
    @IsTest
    static void testMapping_loadChannelList() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadChannelList();
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return channels');
    }

    // loadMasterIntegration - intUserType
    @IsTest
    static void testMapping_loadIntUserType() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('intUserType', null, 'FIMA');
        Test.stopTest();

        Assert.isNotNull(result, 'intUserType should not be null');
    }

    // loadMasterIntegration - productLine
    @IsTest
    static void testMapping_loadProductLine() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('productLine', null, 'FIMA');
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return products');
    }

    // loadMasterIntegration - CaseType
    @IsTest
    static void testMapping_loadCaseType() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('CaseType', 'PROD-01', 'FIMA');
        Test.stopTest();

        Assert.isNotNull(result, 'CaseType should not be null');
    }

    // loadMasterIntegration - Category
    @IsTest
    static void testMapping_loadCategory() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('Category', 'CT-01', 'FIMA');
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return categories');
    }

    // loadMasterIntegration - SubCategory
    @IsTest
    static void testMapping_loadSubCategory() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('SubCategory', 'CAT-01', 'FIMA');
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return subcategories');
    }

    // loadMasterIntegration - SubCode
    @IsTest
    static void testMapping_loadSubCode() {
        Test.startTest();
        List<FEC_IntegrationMappingController.NodeDTO> result =
            FEC_IntegrationMappingController.loadMasterIntegration('SubCode', 'SUBCAT-01', 'FIMA');
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return subcodes');
    }

    // loadAdditionalProperties
    @IsTest
    static void testMapping_loadAdditionalProperties() {
        FEC_User_Type__c ut = [SELECT Id FROM FEC_User_Type__c LIMIT 1];

        Test.startTest();
        List<FEC_IntegrationMappingController.PropertyDTO> result =
            FEC_IntegrationMappingController.loadAdditionalProperties(
                'CAT-01', 'SUBCAT-01', 'SC-01', 'FIMA', 'CT-01', ut.Id
            );
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return properties');
    }

    // searchAdditionalFields - with match
    @IsTest
    static void testMapping_searchAdditionalFields() {
        Test.startTest();
        List<FEC_IntegrationMappingController.CsmFieldDTO> result =
            FEC_IntegrationMappingController.searchAdditionalFields('TXN', 'string');
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should find TXN_AMOUNT field');
    }

    // searchAdditionalFields - blank keyword
    @IsTest
    static void testMapping_searchAdditionalFields_Blank() {
        Test.startTest();
        List<FEC_IntegrationMappingController.CsmFieldDTO> result =
            FEC_IntegrationMappingController.searchAdditionalFields('', 'string');
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Blank keyword should return empty');
    }

    // saveIntegrationMapping - success
    @IsTest
    static void testMapping_saveMapping_Success() {
        FEC_User_Type__c ut = [SELECT Id FROM FEC_User_Type__c LIMIT 1];

        String payloadJson = JSON.serialize(new Map<String, Object>{
            'header' => new Map<String, Object>{
                'userType' => ut.Id,
                'channel' => 'FIMA',
                'intUserType' => ut.Id,
                'productLine' => 'PROD-01',
                'serviceType' => 'CT-01',
                'category' => 'CAT-01',
                'subCategory' => 'SUBCAT-01',
                'subCode' => 'SC-01',
                'natureOfCaseId' => null,
                'caseStageId' => null,
                'screenCaseId' => null,
                'mappingId' => null
            },
            'details' => new List<Object>{
                new Map<String, Object>{
                    'property' => 'AP-01',
                    'type' => 'string',
                    'csmProperty' => 'Subject',
                    'csmPropertyType' => 'text',
                    'autoMapping' => false,
                    'mandatory' => true,
                    'autoMappingPropertySource' => null
                },
                new Map<String, Object>{
                    'property' => 'AP-02',
                    'type' => 'list',
                    'csmProperty' => 'Description',
                    'csmPropertyType' => 'text',
                    'autoMapping' => true,
                    'mandatory' => false,
                    'autoMappingPropertySource' => 'TXN_AMOUNT'
                }
            }
        });

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(payloadJson);
        Test.stopTest();

        Assert.isTrue(result.success, 'Save should succeed');
        Assert.isNotNull(result.mappingId, 'MappingId should be returned');
    }

    // saveIntegrationMapping - blank payload
    @IsTest
    static void testMapping_saveMapping_BlankPayload() {
        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping('');
        Test.stopTest();

        Assert.isFalse(result.success, 'Blank payload should fail');
    }

    // saveIntegrationMapping - null payload
    @IsTest
    static void testMapping_saveMapping_NullPayload() {
        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping(null);
        Test.stopTest();

        Assert.isFalse(result.success, 'Null payload should fail');
    }

    // loadIntegrationMapping - success
    @IsTest
    static void testMapping_loadMapping_Success() {
        FEC_Data_Integration_Mapping__c mapping = [SELECT Id FROM FEC_Data_Integration_Mapping__c LIMIT 1];

        Test.startTest();
        FEC_IntegrationMappingController.MappingDTO result =
            FEC_IntegrationMappingController.loadIntegrationMapping(mapping.Id);
        Test.stopTest();

        Assert.isNotNull(result.id, 'Loaded mapping should have Id');
        Assert.areEqual('FIMA', result.channel, 'Channel should be FIMA');
        Assert.isTrue(result.infos.size() > 0, 'Should have child infos');
    }

    // loadIntegrationMapping - blank id
    @IsTest
    static void testMapping_loadMapping_BlankId() {
        Test.startTest();
        FEC_IntegrationMappingController.MappingDTO result =
            FEC_IntegrationMappingController.loadIntegrationMapping('');
        Test.stopTest();

        Assert.isNull(result.id, 'Blank id should return empty DTO');
    }

    // loadIntegrationMapping - non-existing id
    @IsTest
    static void testMapping_loadMapping_NotFound() {
        Test.startTest();
        FEC_IntegrationMappingController.MappingDTO result =
            FEC_IntegrationMappingController.loadIntegrationMapping('a0000000000XXXX');
        Test.stopTest();

        Assert.isNull(result.id, 'Non-existing should return empty DTO');
    }
}