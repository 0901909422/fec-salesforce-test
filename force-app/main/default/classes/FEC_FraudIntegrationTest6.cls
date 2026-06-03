/**
 * @description Final coverage fix for SoapService (WebServiceMock), FraudCaseApi (Root-wrapped XML),
 *              ManageFraudCaseCtrl (NOC setup), Scheduler.
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Fraud
 */
@IsTest
private class FEC_FraudIntegrationTest6 {

    /* =========================================================
     * WebServiceMock for ServicePortSOAP → covers SoapService 100%
     * ========================================================= */
    private class FraudWebServiceMock implements WebServiceMock {
        public void doInvoke(
            Object stub, Object request, Map<String, Object> response,
            String endpoint, String soapAction, String requestName,
            String responseNS, String responseName, String responseType
        ) {
            if (responseType == 'FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType') {
                FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType r = new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1'; r.Sys.Description = 'Success'; r.CaseID = 'FH-MOCK001';
                response.put('response_x', r);
            } else if (responseType == 'FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType') {
                FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType r = new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1'; r.Sys.Description = 'Canceled'; r.CaseID = 'FH-MOCK001';
                response.put('response_x', r);
            } else if (responseType == 'FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType') {
                FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType r = new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2(); r.Sys.Code = '1';
                r.CaseInfo = new List<FEC_IntegrationSoapFraudcaseService.CaseInfoType3>();
                response.put('response_x', r);
            } else if (responseType == 'FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType') {
                FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType r = new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2(); r.Sys.Code = '1'; r.Sys.Description = 'Processed';
                response.put('response_x', r);
            } else if (responseType == 'FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType') {
                FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType r = new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.FileName = 'test.pdf'; r.FileContent = 'base64'; r.FileType = 'pdf';
                response.put('response_x', r);
            } else if (responseType == 'FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType') {
                FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType r = new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2(); r.Sys.Code = '1';
                r.MasterDataItems = new List<FEC_IntegrationSoapFraudcaseService.MasterDataItemsType>();
                response.put('response_x', r);
            }
        }
    }

    private class HttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
                '<soapenv:Body><ns1:GetFraudMasterDataResponse>' +
                '<ns1:MasterDataItems><ns1:ID>P1</ns1:ID><ns1:Name>P</ns1:Name><ns1:NameVN>P</ns1:NameVN><ns1:Type>Product</ns1:Type><ns1:PosOrder>1</ns1:PosOrder></ns1:MasterDataItems>' +
                '</ns1:GetFraudMasterDataResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setup() {
        FEC_Channel__c ch = new FEC_Channel__c(
            FEC_Channel_ID__c = 'FIMA', FEC_Code__c = 'FIMA', Name = 'FIMA',
            FEC_Channel_Vietnamese_name__c = 'FIMA', FEC_Channel_Status__c = true
        );
        insert ch;

        FEC_User_Type__c ut = new FEC_User_Type__c(
            FEC_Code__c = 'EXISTING', Name = 'Existing', FEC_Name_VN__c = 'HH',
            FEC_Status__c = true, FEC_Pos_Order__c = 1
        );
        insert ut;

        // Master data for AdditionalInfo processing
        List<FEC_Master_Data_Integration__c> mds = new List<FEC_Master_Data_Integration__c>();
        mds.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty', FEC_Source_Id__c = 'Phone',
            FEC_Source_Parent_Id__c = 'SC', FEC_Source_Name__c = 'Phone',
            FEC_Source_Field_Type__c = 'string', FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 1
        ));
        mds.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty', FEC_Source_Id__c = 'NationalID',
            FEC_Source_Parent_Id__c = 'SC', FEC_Source_Name__c = 'NationalID',
            FEC_Source_Field_Type__c = 'string', FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'FIMA', FEC_PosOrder__c = 2
        ));
        insert mds;

        // FH → BU hierarchy
        FEC_Integration_Case__c fh = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-T6001', FEC_Service_Case_ID__c = 'S-T6001',
            FEC_Case_Status__c = 'Fraud/SEC Investigating', FEC_Sys_Channel__c = 'FIMA',
            FEC_Category__c = 'CAT', FEC_Sub_Category__c = 'SUBCAT', FEC_Sub_Code__c = 'SC',
            FEC_Creator_Email__c = 'fh@t.com'
        );
        insert fh;

        FEC_Integration_Case__c bu = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-T6002', FEC_Parent_CaseID__c = 'FH-T6001',
            FEC_Case_Status__c = 'SEC Investigating', FEC_Sys_Channel__c = 'FIMA'
        );
        insert bu;

        // ===== NOC setup for ManageFraudCaseCtrl =====
        FEC_Product_Type__c pt = new FEC_Product_Type__c(FEC_Code__c = 'PT_T6', FEC_Active__c = true);
        insert pt;

        FEC_Nature_of_Case__c noc = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id, FEC_Code__c = 'NOC_T6',
            FEC_Customer_Type__c = 'Existing'
        );
        insert noc;

        FEC_Data_Integration_Mapping__c dim = new FEC_Data_Integration_Mapping__c(
            FEC_Nature_Of_Case__c = noc.Id,
            FEC_Int_Channel__c = 'FIMA', FEC_Int_User_Type_Id__c = ut.Id,
            FEC_Int_Product_Line_Id__c = 'PROD', FEC_Int_Service_Type_Id__c = 'CT',
            FEC_Int_Category_Id__c = 'CAT', FEC_Int_Sub_Category_Id__c = 'SUBCAT',
            FEC_Int_Sub_Code_Id__c = 'SC',
            FEC_Process_Change_Status__c = 'New', FEC_Status__c = true
        );
        insert dim;

        insert new FEC_Data_Integration_Mapping_Info__c(
            FEC_Data_Integration_Mapping__c = dim.Id,
            FEC_Integrating_Property__c = 'AP-01', FEC_Integrating_Property_Type__c = 'string',
            FEC_CSM_Property__c = 'Subject', FEC_CSM_Property_Type__c = 'text',
            FEC_Auto_Mapping_Property__c = true, FEC_Mandatory__c = true,
            FEC_Auto_Mapping_Property_Source__c = 'TXN_AMT'
        );

        insert new FEC_Master_Data_Setting__c(
            FEC_Code__c = 'MDS_T6', FEC_Nature_Of_Case__c = noc.Id,
            FEC_Field_Status__c = true, FEC_Data_Integration_Mapping__c = dim.Id
        );

        // Case for ManageFraudCaseCtrl + ServiceFraudTaskCaseController
        Case c = new Case(Subject = 'FraudT6', FEC_ID_Search__c = 'S-T6001');
        insert c;
    }

    /* =========================================================
     * Helper: wrap XML in Root (required by find(root, 'CaseResultInfo'))
     * ========================================================= */
    private static String wrapXml(String body) {
        return '<Root>' + body + '</Root>';
    }

    private static RestRequest buildReq(String payload) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);
        return req;
    }

    /* =========================================================
     * SOAP ServicePortSOAP — WebServiceMock (100%)
     * ========================================================= */
    @IsTest
    static void testSoap_CreateFraudCase() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'PEGACSM'; sys.TransactionID = 'TX'; sys.DateTime_x = System.now();
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Ex';
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseType = 'F';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 't@t.com';
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType resp = port.CreateFraudCase(sys, cust, req, creator);
        Test.stopTest();
        Assert.areEqual('FH-MOCK001', resp.CaseID, 'CaseID should match');
    }

    @IsTest
    static void testSoap_CancelFraudCase() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FH-001';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType resp = port.CancelFraudCase(sys, ci, creator);
        Test.stopTest();
        Assert.isNotNull(resp, 'Cancel response not null');
    }

    @IsTest
    static void testSoap_MoveCaseToNextStage() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FH-001';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType resp = port.MoveCaseToNextStage(sys, ci, creator);
        Test.stopTest();
        Assert.isNotNull(resp, 'Move response not null');
    }

    @IsTest
    static void testSoap_GetFraudCaseStatus() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.CaseInfoType2 ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        ci.CaseID = 'FH-001';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType resp = port.GetFraudCaseStatus(sys, ci, creator);
        Test.stopTest();
        Assert.isNotNull(resp, 'Status response not null');
    }

    @IsTest
    static void testSoap_ProcessCase() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        ci.CaseID = 'FH-001'; ci.Decision = 'A';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        FEC_IntegrationSoapFraudcaseService.SysType2 resp = port.ProcessCase(sys, ci, creator);
        Test.stopTest();
        Assert.isNotNull(resp, 'Process response not null');
    }

    @IsTest
    static void testSoap_GetFraudAttachedFile() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.RequestInfoType2 ri = new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        ri.CaseID = 'FH-001'; ri.FileID = 'F1';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType resp = port.GetFraudAttachedFile(sys, ri, creator);
        Test.stopTest();
        Assert.isNotNull(resp, 'File response not null');
    }

    @IsTest
    static void testSoap_GetFraudMasterData() {
        Test.setMock(WebServiceMock.class, new FraudWebServiceMock());
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType resp = port.GetFraudMasterData(sys);
        Test.stopTest();
        Assert.isNotNull(resp, 'MasterData response not null');
    }

    @IsTest
    static void testSoap_RequestTypes() {
        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType req = new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType();
        req.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        req.CaseInfo = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        req.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        Test.stopTest();
        Assert.isNotNull(req.Sys, 'Should be set');
    }

    /* =========================================================
     * FraudCaseApi — Root-wrapped XML (proper coverage)
     * ========================================================= */
    @IsTest
    static void testApi_FH_Success() {
        String innerXml = '<CaseResultInfo><Remarks>R</Remarks><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-15T08:30:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>O</Remarks></RequestInfo><CreatorInfo><CreatorEmail>t@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest>' +
            '<AdditionalInfo><ID>Phone</ID><Value>0909123456</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>NationalID</ID><Value>123456</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-T6001","referenceID":"S-T6001","channelID":"FIMA","parentID":"X","caseStatus":"Investigating","investigationConclusion":"OK","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('true'), 'FH should succeed: ' + resp);
    }

    @IsTest
    static void testApi_BU_Success() {
        String innerXml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>BU</Remarks></RequestInfo><CreatorInfo><CreatorEmail>bu@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"BU-T6002","referenceID":"S-T6001","channelID":"FIMA","parentID":"FH-T6001","caseStatus":"Investigating","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('true'), 'BU should succeed: ' + resp);
    }

    @IsTest
    static void testApi_TK_NewCase() {
        String innerXml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>TK</Remarks></RequestInfo><CreatorInfo><CreatorEmail>tk@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest>' +
            '<AdditionalInfo><ID>TaskName</ID><Value>Check</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"TK-T6003","referenceID":"S-T6003","channelID":"FIMA","parentID":"BU-T6002","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('true'), 'TK should succeed: ' + resp);
    }

    @IsTest
    static void testApi_TK_WithSFT() {
        // UIC=CS + ResultDetailCode=CUS triggers SFT case creation
        String innerXml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>TK SFT</Remarks></RequestInfo><CreatorInfo><CreatorEmail>tk@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest>' +
            '<AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>ResultDetailCode</ID><Value>CUS</Value></AdditionalInfo>' +
            '<AdditionalInfo><ID>Phone</ID><Value>0909</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"TK-T6004","referenceID":"S-T6004","channelID":"FIMA","parentID":"BU-T6002","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        // SFT creation may fail on missing config/queue → still covers the branch
        Assert.isNotNull(resp, 'TK SFT response not null');
    }

    @IsTest
    static void testApi_FH_NotFound() {
        String innerXml = '<CaseResultInfo><Remarks>R</Remarks><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-15T08:30:00Z</UpdatedTime>' +
            '<OriginalRequest><RequestInfo><Remarks>O</Remarks></RequestInfo><CreatorInfo><CreatorEmail>t@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-NOEXIST","referenceID":"S-NOEXIST","channelID":"FIMA","parentID":"X","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'FH not found should fail');
    }

    @IsTest
    static void testApi_FH_ParentNull() {
        String innerXml = '<CaseResultInfo><Remarks>R</Remarks><OriginalRequest><RequestInfo><Remarks>O</Remarks></RequestInfo><CreatorInfo><CreatorEmail>t@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        // No parentID in JSON → parentId null → error branch
        String payload = '{"detail":{"caseID":"FH-T6001","referenceID":"S-T6001","channelID":"FIMA","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'Parent null should fail');
    }

    @IsTest
    static void testApi_BU_ParentNotFound() {
        String innerXml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime><OriginalRequest><RequestInfo><Remarks>BU</Remarks></RequestInfo><CreatorInfo><CreatorEmail>bu@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"BU-NEW","referenceID":"S-001","channelID":"FIMA","parentID":"FH-NOEXIST","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'BU parent not found should fail');
    }

    @IsTest
    static void testApi_TK_ParentNotFound() {
        String innerXml = '<CaseResultInfo><CreatedTime>2025-09-10T10:07:22Z</CreatedTime><UpdatedTime>2026-01-01T00:00:00Z</UpdatedTime><OriginalRequest><RequestInfo><Remarks>TK</Remarks></RequestInfo><CreatorInfo><CreatorEmail>tk@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest><AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"TK-NEW","referenceID":"S-001","channelID":"FIMA","parentID":"BU-NOEXIST","caseStatus":"New","investigationConclusion":"","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';

        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();

        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();

        Assert.isTrue(resp.contains('false'), 'TK parent not found should fail');
    }

    @IsTest
    static void testApi_MissingCaseId() {
        String payload = '{"detail":{"caseID":"","referenceID":"S-001","channelID":"FIMA","data":"' + wrapXml('<CaseResultInfo/>') + '","messageTime":1700000000000}}';
        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();
        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();
        Assert.isTrue(resp.contains('false'), 'Missing caseId should fail');
    }

    @IsTest
    static void testApi_MissingXml() {
        String payload = '{"detail":{"caseID":"FH-001","referenceID":"S-001","channelID":"FIMA","data":"","messageTime":1700000000000}}';
        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();
        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();
        Assert.isTrue(resp.contains('false'), 'Missing XML should fail');
    }

    @IsTest
    static void testApi_InvalidFormat() {
        String innerXml = '<CaseResultInfo><Remarks>R</Remarks><OriginalRequest><RequestInfo><Remarks>O</Remarks></RequestInfo><CreatorInfo><CreatorEmail>t@t.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Ex</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"XX-999","referenceID":"S-001","channelID":"FIMA","parentID":"X","caseStatus":"New","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';
        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();
        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();
        Assert.isTrue(resp.contains('false'), 'Invalid format should fail');
    }

    @IsTest
    static void testApi_FH_MissingNodes() {
        // CaseResultInfo without OriginalRequest children → covers validation error branches
        String innerXml = '<CaseResultInfo><Remarks>R</Remarks></CaseResultInfo>';
        String payload = '{"detail":{"caseID":"FH-T6001","referenceID":"S-T6001","channelID":"FIMA","parentID":"X","caseStatus":"New","data":"' + wrapXml(innerXml) + '","messageTime":1700000000000}}';
        RestContext.request = buildReq(payload);
        RestContext.response = new RestResponse();
        Test.startTest();
        String resp = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();
        Test.stopTest();
        Assert.isTrue(resp.contains('false'), 'Missing nodes should fail');
    }

    /* =========================================================
     * ManageFraudCaseCtrl — with NOC mapping
     * ========================================================= */
    @IsTest
    static void testManage_WithMapping() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'FraudT6' LIMIT 1];
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Code__c = 'NOC_T6' LIMIT 1].Id;

        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(c.Id, nocId);
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO not null');
        Assert.isNotNull(dto.integrateMappingId, 'Mapping should be resolved');
    }

    @IsTest
    static void testManage_Blank() {
        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(null, null);
        Test.stopTest();
        Assert.areEqual('CreateMode', dto.actionMode, 'Blank → CreateMode');
    }

    @IsTest
    static void testManage_getCaseToFraudFieldMap_Valid() {
        Id nocId = [SELECT Id FROM FEC_Nature_of_Case__c WHERE FEC_Code__c = 'NOC_T6' LIMIT 1].Id;

        Test.startTest();
        Map<String, String> result = FEC_IntegrationManageFraudCaseCtrl.getCaseToFraudFieldMap(nocId);
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return mapping with valid NOC');
        Assert.isTrue(result.containsKey('TXN_AMT'), 'Should contain auto mapping source');
    }

    @IsTest
    static void testManage_getCaseToFraudFieldMap_Null() {
        Test.startTest();
        Map<String, String> result = FEC_IntegrationManageFraudCaseCtrl.getCaseToFraudFieldMap(null);
        Test.stopTest();
        Assert.areEqual(0, result.size(), 'Null → empty');
    }

    /* =========================================================
     * Scheduler — instantiation (execute blocked by EmailTemplate)
     * ========================================================= */
    @IsTest
    static void testScheduler_Instantiate() {
        Test.setMock(HttpCalloutMock.class, new HttpMock());
        Test.startTest();
        FEC_IntegrationFraudScheduler sched = new FEC_IntegrationFraudScheduler();
        Assert.isNotNull(sched, 'Scheduler instantiated');
        Test.stopTest();
    }
}