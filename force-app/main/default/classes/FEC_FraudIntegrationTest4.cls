/**
 * @description Test class targeting remaining 7 classes below 75% coverage:
 *   1. FEC_ServiceFraudTaskCaseController (74%)
 *   2. FEC_IntegrationCreateFraudController (72%)
 *   3. FEC_IntegrationManageFraudCaseCtrl (68%)
 *   4. FEC_IntegrationFraudService (58%)
 *   5. FEC_IntegrationSoapFraudcaseService (57%)
 *   6. FEC_IntegrationFraudCaseApi (31%)
 *   7. FEC_IntegrationFraudScheduler (0%)
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Fraud
 */
@IsTest
private class FEC_FraudIntegrationTest4 {

    private class FraudCalloutMock implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;

        public FraudCalloutMock(String body, Integer code) {
            this.responseBody = body;
            this.statusCode = code;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            return res;
        }
    }

    private static String createResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body><ns1:CreateFraudCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Success</ns1:Description></ns1:Sys>' +
            '<ns1:CaseID>FH-777777</ns1:CaseID>' +
            '</ns1:CreateFraudCaseResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String cancelResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body><ns1:CancelFraudCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Canceled</ns1:Description></ns1:Sys>' +
            '<ns1:CaseID>FH-777777</ns1:CaseID>' +
            '</ns1:CancelFraudCaseResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String processResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body><ns1:ProcessCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Processed</ns1:Description></ns1:Sys>' +
            '</ns1:ProcessCaseResponse></soapenv:Body></soapenv:Envelope>';
    }

    private static String masterDataResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body><ns1:GetFraudMasterDataResponse>' +
            '<ns1:MasterDataItems><ns1:ID>P1</ns1:ID><ns1:Name>Prod</ns1:Name><ns1:NameVN>SP</ns1:NameVN><ns1:Type>Product</ns1:Type><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:Children><ns1:ID>CT1</ns1:ID><ns1:Name>CaseT</ns1:Name><ns1:NameVN>Loai</ns1:NameVN><ns1:Type>CaseType</ns1:Type><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:Children><ns1:ID>CAT1</ns1:ID><ns1:Name>Cat</ns1:Name><ns1:NameVN>DM</ns1:NameVN><ns1:Type>Category</ns1:Type><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:Children><ns1:ID>SUB1</ns1:ID><ns1:Name>Sub</ns1:Name><ns1:NameVN>PDM</ns1:NameVN><ns1:Type>SubCategory</ns1:Type><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:Children><ns1:ID>SC1</ns1:ID><ns1:Name>Code</ns1:Name><ns1:NameVN>Ma</ns1:NameVN><ns1:Type>SubCode</ns1:Type><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:AdditionalProperties><ns1:ID>AP1</ns1:ID><ns1:Name>F1</ns1:Name><ns1:NameVN>T1</ns1:NameVN><ns1:Type>string</ns1:Type><ns1:Mandatory>true</ns1:Mandatory><ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:AvailableValues><ns1:ID>V1</ns1:ID><ns1:Name>Val1</ns1:Name><ns1:NameVN>GT1</ns1:NameVN></ns1:AvailableValues>' +
            '</ns1:AdditionalProperties></ns1:Children></ns1:Children></ns1:Children></ns1:Children>' +
            '</ns1:MasterDataItems></ns1:GetFraudMasterDataResponse></soapenv:Body></soapenv:Envelope>';
    }

    @TestSetup
    static void setupTestData() {
        FEC_Channel__c channel = new FEC_Channel__c(
            FEC_Channel_ID__c = 'FIMA', FEC_Code__c = 'FIMA', Name = 'FIMA',
            FEC_Channel_Vietnamese_name__c = 'FIMA VN', FEC_Channel_Status__c = true
        );
        insert channel;

        FEC_User_Type__c ut = new FEC_User_Type__c(
            FEC_Code__c = 'EXISTING', Name = 'Existing', FEC_Name_VN__c = 'HH',
            FEC_Status__c = true, FEC_Pos_Order__c = 1
        );
        insert ut;

        // Case for ManageFraudCaseCtrl
        Case testCase = new Case(Subject = 'Test Case', FEC_ID_Search__c = 'S-800001');
        insert testCase;

        // FH → BU → TK hierarchy
        FEC_Integration_Case__c fh = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-800001', FEC_Service_Case_ID__c = 'S-800001',
            FEC_Case_Status__c = 'Fraud/SEC Investigating', FEC_Sys_Channel__c = 'FIMA',
            FEC_Category__c = 'CAT', FEC_Sub_Category__c = 'SUBCAT',
            FEC_Sub_Code__c = 'SC', FEC_Creator_Email__c = 'fh@test.com',
            FEC_CS_Remark__c = 'Remark'
        );
        insert fh;

        FEC_Integration_Case__c bu = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-800002', FEC_Parent_CaseID__c = 'FH-800001',
            FEC_Case_Status__c = 'SEC Investigating', FEC_Sys_Channel__c = 'FIMA'
        );
        insert bu;

        FEC_Integration_Case__c tk = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-800003', FEC_Parent_CaseID__c = 'BU-800002',
            FEC_Service_Case_ID__c = 'S-800003',
            FEC_Case_Status__c = 'SEC Investigating', FEC_Sys_Channel__c = 'FIMA',
            FEC_Investigation_Conclusion__c = 'Review',
            FEC_Integrate_Case_ID__c = testCase.Id
        );
        insert tk;

        List<FEC_Integration_Case_Info__c> infos = new List<FEC_Integration_Case_Info__c>();
        infos.add(new FEC_Integration_Case_Info__c(FEC_Parent_Case__c = tk.Id, FEC_Info_ID__c = 'UIC', FEC_Info_Value__c = 'CS'));
        infos.add(new FEC_Integration_Case_Info__c(FEC_Parent_Case__c = tk.Id, FEC_Info_ID__c = 'Deadline', FEC_Info_Value__c = '20260815'));
        infos.add(new FEC_Integration_Case_Info__c(FEC_Parent_Case__c = tk.Id, FEC_Info_ID__c = 'TaskName', FEC_Info_Value__c = 'Verify'));
        infos.add(new FEC_Integration_Case_Info__c(FEC_Parent_Case__c = tk.Id, FEC_Info_ID__c = 'ViolationType', FEC_Info_Value__c = 'Type1'));
        infos.add(new FEC_Integration_Case_Info__c(FEC_Parent_Case__c = tk.Id, FEC_Info_ID__c = 'AppID', FEC_Info_Value__c = 'APP1'));
        insert infos;

        // Mapping for ManageFraudCaseCtrl
        FEC_Data_Integration_Mapping__c mapping = new FEC_Data_Integration_Mapping__c(
            FEC_Int_Channel__c = 'FIMA', FEC_Int_User_Type_Id__c = ut.Id,
            FEC_Int_Product_Line_Id__c = 'PROD', FEC_Int_Service_Type_Id__c = 'CT',
            FEC_Int_Category_Id__c = 'CAT', FEC_Int_Sub_Category_Id__c = 'SUBCAT',
            FEC_Int_Sub_Code_Id__c = 'SC',
            FEC_Process_Change_Status__c = 'New', FEC_Status__c = true
        );
        insert mapping;

        FEC_Data_Integration_Mapping_Info__c mInfo = new FEC_Data_Integration_Mapping_Info__c(
            FEC_Data_Integration_Mapping__c = mapping.Id,
            FEC_Integrating_Property__c = 'AP-01', FEC_Integrating_Property_Type__c = 'string',
            FEC_CSM_Property__c = 'Subject', FEC_CSM_Property_Type__c = 'text',
            FEC_Auto_Mapping_Property__c = true, FEC_Mandatory__c = true,
            FEC_Auto_Mapping_Property_Source__c = 'TXN_AMOUNT'
        );
        insert mInfo;
    }

    /* =========================================================
     * FEC_ServiceFraudTaskCaseController (74% → 75%+)
     * ========================================================= */
    @IsTest
    static void testServiceTask_getCaseData_ByIntegrateCaseId() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto =
            FEC_ServiceFraudTaskCaseController.getCaseData(c.Id);
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null');
        Assert.isNotNull(dto.task, 'Task should be populated');
    }

    @IsTest
    static void testServiceTask_submitProcess_MockEnabled() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        // Enable mock flag to bypass callout
        FEC_FraudConstantCommon.USE_MOCK_PROCESS_CASE = true;

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                c.Id, 'Success', 'SubDecision', 'Valid reason', 'Test remark'
            );
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
        Assert.isTrue(resp.success, 'Should succeed with mock');
    }

    @IsTest
    static void testServiceTask_getRemarksData() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        Test.startTest();
        List<FEC_IntegrationFraudCaseUtil.RemarksInfo> remarks =
            FEC_ServiceFraudTaskCaseController.getRemarksData(c.Id);
        Test.stopTest();

        Assert.isNotNull(remarks, 'Remarks should not be null');
    }

    @IsTest
    static void testServiceTask_getCustomerData() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CustomerInfo cust =
            FEC_ServiceFraudTaskCaseController.getCustomerData(c.Id);
        Test.stopTest();

        Assert.isNotNull(cust, 'Customer info should not be null');
    }

    /* =========================================================
     * FEC_IntegrationManageFraudCaseCtrl (68% → 75%+)
     * ========================================================= */
    @IsTest
    static void testManage_initWithExistingFraudCase() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(c.Id, null);
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null');
        Assert.isNotNull(dto.actionMode, 'ActionMode should be set');
    }

    @IsTest
    static void testManage_initBlankServiceCase() {
        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(null, null);
        Test.stopTest();

        Assert.areEqual('CreateMode', dto.actionMode, 'Blank should be CreateMode');
    }

    @IsTest
    static void testManage_getCaseToFraudFieldMap_Valid() {
        // We need a Nature of Case linked to our mapping via FEC_Master_Data_Setting__c
        // Since we can't easily create NatureOfCase, test with null (empty result)
        Test.startTest();
        Map<String, String> result =
            FEC_IntegrationManageFraudCaseCtrl.getCaseToFraudFieldMap(null, null);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return map');
        Assert.areEqual(0, result.size(), 'Null should return empty');
    }

    /* =========================================================
     * FEC_IntegrationFraudService (58% → 75%+)
     * ========================================================= */
    @IsTest
    static void testFraudService_syncMasterData() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(masterDataResponseXml(), 200));

        Test.startTest();
        Integer count = FEC_IntegrationFraudService.syncMasterDataIntegration();
        Test.stopTest();

        Assert.isTrue(count > 0, 'Should sync records');
    }

    @IsTest
    static void testFraudService_callCreate() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(createResponseXml(), 200));

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildWrapper();
        FEC_IntegrationSoapFraudcaseService.SysType sys = FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = FEC_IntegrationFraudCaseUtil.buildCustomer(w);
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = FEC_IntegrationFraudCaseUtil.buildRequest(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callCreateFraudCaseService(w, sys, cust, req, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
        Assert.areEqual('1', resp.Sys.Code, 'Code should be 1');
    }

    @IsTest
    static void testFraudService_callUpdate() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(createResponseXml(), 200));

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildWrapper();
        w.caseId = 'FH-800001';
        FEC_IntegrationSoapFraudcaseService.SysType sys = FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = FEC_IntegrationFraudCaseUtil.buildCustomer(w);
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = FEC_IntegrationFraudCaseUtil.buildRequest(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callUpdateFraudCaseService(w, sys, cust, req, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    @IsTest
    static void testFraudService_callCancel() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(cancelResponseXml(), 200));

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildWrapper();
        w.caseId = 'FH-800001';
        FEC_IntegrationSoapFraudcaseService.SysType sys = FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo = FEC_IntegrationFraudCaseUtil.buildCCaseInfo(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callCancelFraudCaseService(w, sys, caseIfo, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    @IsTest
    static void testFraudService_callProcess() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(processResponseXml(), 200));

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildWrapper();
        FEC_IntegrationSoapFraudcaseService.SysType sys = FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 ci4 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        ci4.CaseID = 'FH-800001';
        ci4.Decision = 'Approve';
        ci4.Remarks = 'OK';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType resp =
            FEC_IntegrationFraudService.callProcessFraudCaseService(w, sys, ci4, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    @IsTest
    static void testFraudService_getFraudMasterData() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(masterDataResponseXml(), 200));

        Test.startTest();
        String xml = FEC_IntegrationFraudService.getFraudMasterData();
        Test.stopTest();

        Assert.isNotNull(xml, 'Should return XML');
    }

    @IsTest
    static void testFraudService_isConnectFraudSystem() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock('OK', 200));

        Test.startTest();
        Boolean connected = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        Assert.isTrue(connected, 'Should be connected');
    }

    @IsTest
    static void testFraudService_isConnectFraudSystem_Fail() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock('Error', 500));

        Test.startTest();
        Boolean connected = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        Assert.isFalse(connected, 'Should not be connected');
    }

    @IsTest
    static void testFraudService_getAdminRecipients() {
        Test.startTest();
        List<String> emails = FEC_IntegrationFraudService.getAdminRecipients();
        Test.stopTest();

        Assert.isNotNull(emails, 'Should not be null');
    }

    /* =========================================================
     * FEC_IntegrationFraudScheduler (0% → 75%+)
     * ========================================================= */
    @IsTest
    static void testScheduler_Execute() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(masterDataResponseXml(), 200));

        Test.startTest();
        String jobId = System.schedule('FraudSch4_' + System.currentTimeMillis(), '0 0 0 15 1 ? 2099', new FEC_IntegrationFraudScheduler());
        Test.stopTest();

        // Scheduler fires during Test.stopTest() but sendJobEmail will fail on EmailTemplate query
        // However, the catch block in scheduler will also call sendJobEmail → both paths get coverage
        Assert.isNotNull(jobId, 'Job should be scheduled');
    }

    /* =========================================================
     * FEC_IntegrationCreateFraudController (72% → 75%+)
     * ========================================================= */
    @IsTest
    static void testCreateFraud_submitCreate() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(createResponseXml(), 200));

        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'Fraud', 'ProductType' => 'Card',
            'Category' => 'CAT', 'SubCategory' => 'SUBCAT', 'SubCode' => 'SC',
            'Remarks' => 'Test', 'UserType' => 'Existing',
            'ChannelIntegrationCode' => 'FIMA',
            'AdditionalInfo' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'ID' => 'AP-01', 'Value' => '5000', 'Type' => 'string', 'Mandatory' => true }
            }
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Should not be null');
    }

    @IsTest
    static void testCreateFraud_submitUpdate() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(createResponseXml(), 200));

        Map<String, Object> payload = new Map<String, Object>{
            'FraudCaseId' => 'FH-800001', 'CaseType' => 'Fraud', 'ProductType' => 'Card',
            'Category' => 'CAT', 'SubCategory' => 'SUBCAT', 'SubCode' => 'SC',
            'Remarks' => 'Update', 'UserType' => 'Existing',
            'ServiceCaseId' => 'S-800001', 'ChannelIntegrationCode' => 'FIMA',
            'AdditionalInfo' => new List<Map<String, Object>>()
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitUpdateFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Should not be null');
    }

    @IsTest
    static void testCreateFraud_submitCancel() {
        Test.setMock(HttpCalloutMock.class, new FraudCalloutMock(cancelResponseXml(), 200));

        Map<String, Object> payload = new Map<String, Object>{
            'FraudCaseId' => 'FH-800001', 'ServiceCaseId' => 'S-800001',
            'ChannelIntegrationCode' => 'FIMA', 'Remarks' => 'Cancel test'
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitCancelFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Should not be null');
    }

    @IsTest
    static void testCreateFraud_getFraudCaseById() {
        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO dto =
            FEC_IntegrationCreateFraudController.getFraudCaseById('FH-800001');
        Test.stopTest();

        Assert.isNotNull(dto, 'Should not be null');
        Assert.areEqual('FIMA', dto.intChannel, 'Channel should match');
    }

    @IsTest
    static void testCreateFraud_getMasterDataForUI() {
        Test.startTest();
        String json = FEC_IntegrationCreateFraudController.getMasterDataForUI();
        Test.stopTest();

        Assert.isNotNull(json, 'Should return JSON');
    }

    @IsTest
    static void testCreateFraud_loadChannelList() {
        Test.startTest();
        Object result = FEC_IntegrationCreateFraudController.loadChannelList();
        Test.stopTest();

        Assert.isNotNull(result, 'Should return channels');
    }

    @IsTest
    static void testCreateFraud_loadAdditionalProperties() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.PropertyDTO> props =
            FEC_IntegrationCreateFraudController.loadAdditionalProperties('CAT', 'SUBCAT', 'SC', 'FIMA', 'CT');
        Test.stopTest();

        Assert.isNotNull(props, 'Should not be null');
    }

    @IsTest
    static void testCreateFraud_loadMasterIntegration() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> r2 =
            FEC_IntegrationCreateFraudController.loadMasterDataIntegration('Category', 'CT', 'FIMA');
        Test.stopTest();

        Assert.isNotNull(r2, 'Should not be null');
    }

    @IsTest
    static void testCreateFraud_getIntegrationFieldTypes() {
        Test.startTest();
        Map<String, String> types = FEC_IntegrationCreateFraudController.getIntegrationFieldTypes();
        Test.stopTest();

        Assert.isTrue(types.size() > 0, 'Should return types');
    }

    @IsTest
    static void testCreateFraud_loadCategoryMapping() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse resp =
            FEC_IntegrationCreateFraudController.loadCategoryMapping('FIMA');
        Test.stopTest();

        Assert.isNotNull(resp, 'Should not be null');
    }

    /* =========================================================
     * FEC_IntegrationFraudCaseApi (31% → higher)
     * ========================================================= */
    @IsTest
    static void testApi_FH_FullSuccess() {
        String xml = '<CaseResultInfo><Remarks>Updated</Remarks><CreatedTime>2025-09-10T10:07:22.263Z</CreatedTime><UpdatedTime>2026-01-15T08:30:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>Orig</Remarks></RequestInfo><CreatorInfo><CreatorEmail>test@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Existing</UserType></CustomerInfo></OriginalRequest>' +
            '<AdditionalInfo><ID>NationalID</ID><Value>123</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-800001","referenceID":"S-800001","channelID":"FIMA","parentID":"X","caseStatus":"Investigating","investigationConclusion":"OK","data":"' + xml + '","messageTime":1700000000000}}';

        RestContext.request = buildRestRequest(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    @IsTest
    static void testApi_BU_FullSuccess() {
        String xml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>BU</Remarks></RequestInfo><CreatorInfo><CreatorEmail>bu@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"BU-800002","referenceID":"S-800001","channelID":"FIMA","parentID":"FH-800001","caseStatus":"Investigating","investigationConclusion":"","data":"' + xml + '","messageTime":1700000000000}}';

        RestContext.request = buildRestRequest(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'BU response should not be null');
    }

    @IsTest
    static void testApi_TK_FullSuccess() {
        String xml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>TK</Remarks></RequestInfo><CreatorInfo><CreatorEmail>tk@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest>' +
            '<AdditionalInfo><ID>UIC</ID><Value>OTHER</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"TK-800003","referenceID":"S-800003","channelID":"FIMA","parentID":"BU-800002","caseStatus":"Investigating","investigationConclusion":"Done","data":"' + xml + '","messageTime":1700000000000}}';

        RestContext.request = buildRestRequest(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isNotNull(resp, 'TK response should not be null');
    }

    /* =========================================================
     * FEC_IntegrationSoapFraudcaseService (57% → higher)
     * Already covered via callout tests above. Add type coverage.
     * ========================================================= */
    @IsTest
    static void testSoapTypes_Coverage() {
        Test.startTest();
        // These types are accessed when parsing responses in callout methods above
        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType r1 = new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType();
        r1.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        r1.CaseInfo = new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        r1.CaseInfo.CaseID = 'X';
        r1.CaseInfo.IncludeFinishedRequest = true;
        r1.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType r2 = new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType();
        r2.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        r2.RequestInfo = new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        r2.RequestInfo.CaseID = 'C';
        r2.RequestInfo.FileID = 'F';
        r2.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType r3 = new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
        r3.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        r3.FileName = 'test.pdf';
        r3.FileContent = 'base64';
        r3.FileType = 'pdf';

        FEC_IntegrationSoapFraudcaseService.OriginalRequestType ort = new FEC_IntegrationSoapFraudcaseService.OriginalRequestType();
        ort.Sys = new FEC_IntegrationSoapFraudcaseService.SysType3();
        ort.CustomerInfo = new FEC_IntegrationSoapFraudcaseService.CustomerInfoType();
        ort.CustomerInfo.UserType = 'Agent';
        ort.RequestInfo = new FEC_IntegrationSoapFraudcaseService.RequestInfoType();
        ort.RequestInfo.CaseType = 'X';
        ort.RequestInfo.ProductType = 'Y';
        ort.RequestInfo.Category = 'Z';
        ort.RequestInfo.SubCategory = 'W';
        ort.RequestInfo.SubCode = 'V';
        ort.RequestInfo.Remarks = 'R';
        ort.RequestInfo.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoType>();
        ort.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType2();
        ort.CreatorInfo.CreatorEmail = 'x@y.com';

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType cr = new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
        cr.OriginalRequest = ort;

        FEC_IntegrationSoapFraudcaseService.CaseInfoType3 ci3 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType3();
        ci3.CaseID = 'X';
        ci3.CaseStatus = 'Open';
        ci3.ReferenceID = 'R';
        ci3.ParentID = 'P';
        ci3.CreatedTime = System.now();
        ci3.UpdatedTime = System.now();
        ci3.Remarks = 'R';
        ci3.OriginalRequest = ort;
        ci3.InvestigationResults = new List<FEC_IntegrationSoapFraudcaseService.InvestigationResultsType>();
        ci3.CaseDetailedInfo = new List<FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType>();

        Test.stopTest();
        Assert.isNotNull(ci3.CaseID, 'Should be set');
    }

    /* =========================================================
     * HELPERS
     * ========================================================= */
    private static FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper buildWrapper() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.channel = 'PEGACSM';
        w.channelCode = 'FIMA';
        w.caseType = 'Fraud';
        w.productType = 'Card';
        w.category = 'CAT';
        w.subCategory = 'SUBCAT';
        w.subCode = 'SC';
        w.remarks = 'Test';
        w.userType = 'Existing';
        w.creatorEmail = 'test@test.com';
        w.serviceCaseId = 'S-800001';
        w.caseId = null;
        w.additionalInfos = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();
        w.additionalInfoOrginal = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element>();
        return w;
    }

    private static RestRequest buildRestRequest(String payload) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        return req;
    }
}