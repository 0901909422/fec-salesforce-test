@IsTest
private class FEC_IntegrationSoapFraudcaseService_Test {

    @IsTest
    static void test_CustomerInfo_element() {
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element obj =
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        obj.UserType = 'Individual';
        System.assertEquals('Individual', obj.UserType);
    }

    @IsTest
    static void test_ChildrenType() {
        FEC_IntegrationSoapFraudcaseService.ChildrenType obj =
            new FEC_IntegrationSoapFraudcaseService.ChildrenType();
        obj.ID = 'C001';
        obj.Name = 'Child';
        obj.NameVN = 'Con';
        obj.PosOrder = 1;
        obj.ApplyTo = 'ALL';
        obj.Type_x = 'Category';
        obj.AdditionalProperties = new List<FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType>();
        obj.Children = new List<FEC_IntegrationSoapFraudcaseService.ChildrenType>();
        System.assertEquals('C001', obj.ID);
    }

    @IsTest
    static void test_GetFraudMasterDataResponseType() {
        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType obj =
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType();
        obj.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        obj.MasterDataItems = new List<FEC_IntegrationSoapFraudcaseService.MasterDataItemsType>();
        System.assertNotEquals(null, obj.Sys);
    }

    @IsTest
    static void test_AvailableValuesType() {
        FEC_IntegrationSoapFraudcaseService.AvailableValuesType obj =
            new FEC_IntegrationSoapFraudcaseService.AvailableValuesType();
        obj.ID = 'AV1';
        obj.Name = 'Value1';
        obj.NameVN = 'Gia tri 1';
        System.assertEquals('AV1', obj.ID);
    }

    @IsTest
    static void test_CreateFraudCaseRequestType() {
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType obj =
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType();
        obj.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        obj.CustomerInfo = new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        obj.RequestInfo = new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        obj.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        System.assertNotEquals(null, obj.Sys);
    }

    @IsTest
    static void test_GetFraudAttachedFileResponseType() {
        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType obj =
            new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
        obj.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        obj.FileName = 'test.pdf';
        obj.FileContent = 'base64data';
        obj.FileType = 'application/pdf';
        System.assertEquals('test.pdf', obj.FileName);
    }

    @IsTest
    static void test_SysTypes() {
        FEC_IntegrationSoapFraudcaseService.SysType sys1 =
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys1.Channel = 'CSM';
        sys1.TransactionID = 'TXN001';
        sys1.DateTime_x = Datetime.now();
        System.assertEquals('CSM', sys1.Channel);

        FEC_IntegrationSoapFraudcaseService.SysType2 sys2 =
            new FEC_IntegrationSoapFraudcaseService.SysType2();
        sys2.TransactionID = 'TXN002';
        sys2.DateTime_x = Datetime.now();
        sys2.Code = '1';
        sys2.Description = 'Success';
        System.assertEquals('1', sys2.Code);

        FEC_IntegrationSoapFraudcaseService.SysType3 sys3 =
            new FEC_IntegrationSoapFraudcaseService.SysType3();
        sys3.Channel = 'FIMA';
        sys3.TransactionID = 'TXN003';
        sys3.DateTime_x = Datetime.now();
        System.assertEquals('FIMA', sys3.Channel);
    }

    @IsTest
    static void test_RequestInfoTypes() {
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element ri =
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        ri.CaseID = 'C001';
        ri.CaseType = 'Fraud';
        ri.ProductType = 'Card';
        ri.Category = 'CAT';
        ri.SubCategory = 'SUB';
        ri.SubCode = 'SC';
        ri.Remarks = 'test';
        ri.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();
        System.assertEquals('Fraud', ri.CaseType);

        FEC_IntegrationSoapFraudcaseService.RequestInfoType rit =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType();
        rit.CaseType = 'Fraud';
        rit.ProductType = 'Loan';
        rit.Category = 'CAT';
        rit.SubCategory = 'SUB';
        rit.Remarks = 'remark';
        rit.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoType>();
        System.assertEquals('Loan', rit.ProductType);

        FEC_IntegrationSoapFraudcaseService.RequestInfoType2 rit2 =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        rit2.CaseID = 'C1';
        rit2.FileID = 'F1';
        System.assertEquals('F1', rit2.FileID);
    }

    @IsTest
    static void test_CaseInfoTypes() {
        FEC_IntegrationSoapFraudcaseService.CaseInfoType ci =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        ci.CaseID = 'FIMA-001';
        ci.Remarks = 'Cancel';
        System.assertEquals('FIMA-001', ci.CaseID);

        FEC_IntegrationSoapFraudcaseService.CaseInfoType2 ci2 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        ci2.CaseID = 'C2';
        ci2.IncludeFinishedRequest = true;
        System.assertEquals(true, ci2.IncludeFinishedRequest);

        FEC_IntegrationSoapFraudcaseService.CaseInfoType3 ci3 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType3();
        ci3.CaseID = 'C3';
        ci3.CaseStatus = 'Active';
        ci3.ReferenceID = 'REF1';
        ci3.ParentID = 'P1';
        ci3.CreatedTime = Datetime.now();
        ci3.UpdatedTime = Datetime.now();
        ci3.Remarks = 'remark';
        ci3.OriginalRequest = new FEC_IntegrationSoapFraudcaseService.OriginalRequestType();
        ci3.InvestigationResults = new List<FEC_IntegrationSoapFraudcaseService.InvestigationResultsType>();
        ci3.CaseDetailedInfo = new List<FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType>();
        System.assertEquals('Active', ci3.CaseStatus);

        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 ci4 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        ci4.CaseID = 'C4';
        ci4.Decision = 'Approve';
        ci4.SubDecision = 'Full';
        ci4.Reason = 'Valid';
        ci4.Remarks = 'remark';
        System.assertEquals('Approve', ci4.Decision);
    }

    @IsTest
    static void test_ResponseTypes() {
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType cr =
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
        cr.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        cr.CaseID = 'FH-001';
        System.assertEquals('FH-001', cr.CaseID);

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType canc =
            new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
        canc.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        canc.CaseID = 'FH-002';
        System.assertEquals('FH-002', canc.CaseID);

        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType pr =
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
        pr.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        System.assertNotEquals(null, pr.Sys);

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType gs =
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType();
        gs.Sys = new FEC_IntegrationSoapFraudcaseService.SysType2();
        gs.CaseInfo = new List<FEC_IntegrationSoapFraudcaseService.CaseInfoType3>();
        System.assertNotEquals(null, gs.CaseInfo);
    }

    @IsTest
    static void test_RequestTypes() {
        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType gm =
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType();
        gm.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        System.assertNotEquals(null, gm.Sys);

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType gcs =
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType();
        gcs.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        gcs.CaseInfo = new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        gcs.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        System.assertNotEquals(null, gcs.CaseInfo);

        FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType pc =
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType();
        pc.Sys = new FEC_IntegrationSoapFraudcaseService.SysType();
        pc.CaseInfo = new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        pc.CreatorInfo = new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        System.assertNotEquals(null, pc.CaseInfo);
    }

    @IsTest
    static void test_MiscTypes() {
        FEC_IntegrationSoapFraudcaseService.MasterDataItemsType mdi =
            new FEC_IntegrationSoapFraudcaseService.MasterDataItemsType();
        mdi.ID = 'M1';
        mdi.Name = 'Master';
        mdi.NameVN = 'Du lieu';
        mdi.PosOrder = 1;
        mdi.ApplyTo = 'ALL';
        mdi.Type_x = 'Product';
        mdi.AdditionalProperties = new List<FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType>();
        mdi.Children = new List<FEC_IntegrationSoapFraudcaseService.ChildrenType>();
        System.assertEquals('M1', mdi.ID);

        FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType ap =
            new FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType();
        ap.ID = 'AP1';
        ap.Name = 'Prop';
        ap.NameVN = 'Thuoc tinh';
        ap.PosOrder = 1;
        ap.ApplyTo = 'ALL';
        ap.Mandatory = true;
        ap.Type_x = 'string';
        ap.AvailableValues = new List<FEC_IntegrationSoapFraudcaseService.AvailableValuesType>();
        System.assertEquals(true, ap.Mandatory);

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoType ai =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoType();
        ai.ID = 'AI1';
        ai.Value = 'val';
        System.assertEquals('AI1', ai.ID);

        FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ae =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element();
        ae.ID = 'AE1';
        ae.Value = 'v';
        System.assertEquals('AE1', ae.ID);

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element ace =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element();
        ace.ID = 'ACE1';
        ace.Value = 'v';
        ace.Type = 'string';
        ace.Mandatory = false;
        System.assertEquals('ACE1', ace.ID);

        FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element ric =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element();
        ric.CaseID = 'RC1';
        ric.CaseType = 'Fraud';
        ric.ProductType = 'Card';
        ric.Category = 'CAT';
        ric.SubCategory = 'SUB';
        ric.SubCode = 'SC';
        ric.Remarks = 'r';
        ric.AdditionalInfo = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element>();
        System.assertEquals('RC1', ric.CaseID);

        FEC_IntegrationSoapFraudcaseService.TasksType task =
            new FEC_IntegrationSoapFraudcaseService.TasksType();
        task.Name = 'T1';
        task.UIC = 'U1';
        task.Deadline = Datetime.now();
        System.assertEquals('T1', task.Name);

        FEC_IntegrationSoapFraudcaseService.InvestigationResultsType ir =
            new FEC_IntegrationSoapFraudcaseService.InvestigationResultsType();
        ir.AppID = 'APP1';
        ir.Conclusion = 'Fraud';
        ir.Tasks = new List<FEC_IntegrationSoapFraudcaseService.TasksType>();
        System.assertEquals('APP1', ir.AppID);

        FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType cdi =
            new FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType();
        cdi.ID = 'CDI1';
        cdi.Value = 'val';
        System.assertEquals('CDI1', cdi.ID);

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType cit =
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        cit.CreatorEmail = 'test@test.com';
        System.assertEquals('test@test.com', cit.CreatorEmail);

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType2 cit2 =
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType2();
        cit2.CreatorEmail = 'test2@test.com';
        System.assertEquals('test2@test.com', cit2.CreatorEmail);

        FEC_IntegrationSoapFraudcaseService.CustomerInfoType cust =
            new FEC_IntegrationSoapFraudcaseService.CustomerInfoType();
        cust.UserType = 'Corp';
        System.assertEquals('Corp', cust.UserType);
    }
}
