@IsTest
private class FEC_IntegrationSoapFraud_Test {

    /**
     * WebServiceMock implementation that returns proper response objects
     * for each SOAP method call. This covers the WebServiceCallout.invoke
     * branches in ServicePortSOAP.
     */
    public class FraudSoapMock implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            if (responseType.contains('CreateFraudCaseResponseType')) {
                FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
                r.CaseID = 'FH-MOCK-001';
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1';
                r.Sys.Description = 'OK';
                response.put('response_x', r);
            } else if (responseType.contains('CancelFraudCaseResponseType')) {
                FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
                r.CaseID = 'FH-CANCEL-001';
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1';
                response.put('response_x', r);
            } else if (responseType.contains('ProcessCaseResponseType')) {
                FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1';
                response.put('response_x', r);
            } else if (responseType.contains('GetFraudCaseStatusResponseType')) {
                FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1';
                response.put('response_x', r);
            } else if (responseType.contains('GetFraudAttachedFileResponseType')) {
                FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
                r.FileName = 'mock.pdf';
                r.FileContent = 'base64data';
                r.FileType = 'pdf';
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                response.put('response_x', r);
            } else if (responseType.contains('GetFraudMasterDataResponseType')) {
                FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType r = 
                    new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType();
                r.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
                r.Sys.Code = '1';
                response.put('response_x', r);
            }
        }
    }

    @IsTest
    static void test_AllDtoClasses() {
        // Top-level service class
        FEC_IntegrationSoapFraudcaseService svc = new FEC_IntegrationSoapFraudcaseService();
        System.assertNotEquals(null, svc);

        // Customer / Request / Creator
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Individual';
        System.assertEquals('Individual', cust.UserType);

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';
        System.assertEquals('test@test.com', creator.CreatorEmail);

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType2 creator2 = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType2();
        creator2.CreatorEmail = 'test@test.com';

        FEC_IntegrationSoapFraudcaseService.CustomerInfoType custType = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfoType();
        custType.UserType = 'Individual';

        // Sys types
        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();
        System.assertEquals('CH001', sys.Channel);

        FEC_IntegrationSoapFraudcaseService.SysType2 sys2 = new FEC_IntegrationSoapFraudcaseService.SysType2();
        sys2.TransactionID = 'TXN-001';
        sys2.DateTime_x = Datetime.now();
        sys2.Code = '1';
        sys2.Description = 'OK';

        FEC_IntegrationSoapFraudcaseService.SysType3 sys3 = new FEC_IntegrationSoapFraudcaseService.SysType3();
        sys3.Channel = 'CH001';

        // Case Info
        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FH-001';
        ci.Remarks = 'Test';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType2 ci2 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        ci2.CaseID = 'FH-001';
        ci2.IncludeFinishedRequest = true;

        FEC_IntegrationSoapFraudcaseService.CaseInfoType3 ci3 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType3();
        ci3.CaseID = 'FH-001';
        ci3.CaseStatus = 'New';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 ci4 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        ci4.CaseID = 'FH-001';
        ci4.Decision = 'Confirmed';
        ci4.SubDecision = 'Sub';
        ci4.Reason = 'Reason';
        ci4.Remarks = 'Remarks';

        // AdditionalInfo
        FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element();
        ai.ID = 'NID';
        ai.Value = '123';

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element aic = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element();
        aic.ID = 'NID';
        aic.Value = '123';
        aic.Type = 'string';
        aic.Mandatory = true;

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoType aiType = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoType();
        aiType.ID = 'NID';
        aiType.Value = '123';

        // Request Info
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseID = 'FH-001';
        req.CaseType = 'FRAUD';
        req.ProductType = 'CC';

        FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element reqC = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element();
        reqC.CaseID = 'FH-001';
        reqC.CaseType = 'FRAUD';

        FEC_IntegrationSoapFraudcaseService.RequestInfoType reqT = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType();
        reqT.CaseType = 'FRAUD';

        FEC_IntegrationSoapFraudcaseService.RequestInfoType2 reqT2 = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        reqT2.CaseID = 'FH-001';
        reqT2.FileID = 'F001';

        // Response types
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType cResp = 
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
        cResp.CaseID = 'FH-001';

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType cancelResp = 
            new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
        cancelResp.CaseID = 'FH-001';

        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType pResp = 
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType gResp = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType();

        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType mResp = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType();

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType fResp = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
        fResp.FileName = 'test.pdf';
        fResp.FileContent = 'base64data';
        fResp.FileType = 'pdf';

        // Request types
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType cReq = 
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType();

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType cancelReq = 
            new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseRequestType();

        FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType pReq = 
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType();

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType gReq = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType();

        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType mReq = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType();

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType fReq = 
            new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType();

        // Hierarchy types
        FEC_IntegrationSoapFraudcaseService.MasterDataItemsType mItem = 
            new FEC_IntegrationSoapFraudcaseService.MasterDataItemsType();
        mItem.ID = 'M1';
        mItem.Name = 'Master 1';

        FEC_IntegrationSoapFraudcaseService.ChildrenType child = 
            new FEC_IntegrationSoapFraudcaseService.ChildrenType();
        child.ID = 'C1';
        child.Name = 'Child 1';
        child.PosOrder = 1;

        FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType addProp = 
            new FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType();
        addProp.ID = 'AP1';
        addProp.Name = 'Property 1';

        FEC_IntegrationSoapFraudcaseService.AvailableValuesType av = 
            new FEC_IntegrationSoapFraudcaseService.AvailableValuesType();
        av.ID = 'V1';
        av.Name = 'Value 1';

        // Investigation
        FEC_IntegrationSoapFraudcaseService.InvestigationResultsType inv = 
            new FEC_IntegrationSoapFraudcaseService.InvestigationResultsType();
        inv.AppID = 'APP1';
        inv.Conclusion = 'Confirmed';

        FEC_IntegrationSoapFraudcaseService.TasksType task = 
            new FEC_IntegrationSoapFraudcaseService.TasksType();
        task.Name = 'Task 1';
        task.UIC = 'UIC1';
        task.Deadline = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType cd = 
            new FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType();
        cd.ID = 'CD1';
        cd.Value = 'Detail';

        FEC_IntegrationSoapFraudcaseService.OriginalRequestType orig = 
            new FEC_IntegrationSoapFraudcaseService.OriginalRequestType();

        // Final assertion to mark the test executed all instantiations
        System.assertEquals('FH-001', cResp.CaseID);
    }

    @IsTest
    static void test_ServicePortSOAP_Init() {
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();
        System.assertNotEquals(null, port);
        System.assertNotEquals(null, port.endpoint_x);
        port.timeout_x = 60000;
        port.inputHttpHeaders_x = new Map<String, String>();
        port.outputHttpHeaders_x = new Map<String, String>();
        port.clientCertName_x = 'cert';
        port.clientCert_x = 'value';
        port.clientCertPasswd_x = 'pwd';
    }

    @IsTest
    static void test_ServicePortSOAP_CreateFraudCase() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust = 
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Individual';

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        req.CaseType = 'FRAUD';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType r = 
            port.CreateFraudCase(sys, cust, req, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertEquals('FH-MOCK-001', r.CaseID);
    }

    @IsTest
    static void test_ServicePortSOAP_CancelFraudCase() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FH-001';
        ci.Remarks = 'Test';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType r = 
            port.CancelFraudCase(sys, ci, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void test_ServicePortSOAP_MoveCaseToNextStage() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci = new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FH-001';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType r = 
            port.MoveCaseToNextStage(sys, ci, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void test_ServicePortSOAP_ProcessCase() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 ci4 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        ci4.CaseID = 'FH-001';
        ci4.Decision = 'Confirmed';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.SysType2 r = 
            port.ProcessCase(sys, ci4, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void test_ServicePortSOAP_GetFraudCaseStatus() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';
        sys.TransactionID = 'TXN-001';
        sys.DateTime_x = Datetime.now();

        FEC_IntegrationSoapFraudcaseService.CaseInfoType2 ci2 = new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        ci2.CaseID = 'FH-001';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType r = 
            port.GetFraudCaseStatus(sys, ci2, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void test_ServicePortSOAP_GetFraudAttachedFile() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';

        FEC_IntegrationSoapFraudcaseService.RequestInfoType2 req2 = 
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        req2.CaseID = 'FH-001';
        req2.FileID = 'F001';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator = 
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType r = 
            port.GetFraudAttachedFile(sys, req2, creator);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void test_ServicePortSOAP_GetFraudMasterData() {
        Test.setMock(WebServiceMock.class, new FraudSoapMock());
        FEC_IntegrationSoapFraudcaseService.ServicePortSOAP port = 
            new FEC_IntegrationSoapFraudcaseService.ServicePortSOAP();

        FEC_IntegrationSoapFraudcaseService.SysType sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'CH001';

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType r = 
            port.GetFraudMasterData(sys);
        Test.stopTest();

        System.assertNotEquals(null, r);
    }
}