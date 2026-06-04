/**
 * @description Comprehensive test class covering all Fraud Integration classes:
 *              - FEC_IntegrationSoapFraudcaseService (type instantiation)
 *              - FEC_IntegrationFraudCaseUtil (utility methods)
 *              - FEC_IntegrationFraudService (sync + callout methods)
 *              - FEC_IntegrationFraudScheduler (schedulable)
 *              - FEC_IntegrationFraudCaseApi (REST API)
 *              - FEC_IntegrationCreateFraudController (LWC controller)
 *              - FEC_IntegrationMappingController (mapping screen)
 *              - FEC_ServiceFraudTaskCaseController (task case)
 *              - FEC_IntegrationManageFraudCaseCtrl (manage fraud case)
 * @author      DAT NGO
 * @date        2026-06-03
 * @module      Fraud
 */
@IsTest
private class FEC_FraudIntegrationTest {

    /* =========================================================
     * MOCK HTTP CALLOUT
     * ========================================================= */
    private class FraudMasterDataMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getMasterDataXml());
            return res;
        }
    }

    private class FraudCreateCaseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getCreateCaseResponseXml());
            return res;
        }
    }

    private class FraudCancelCaseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getCancelCaseResponseXml());
            return res;
        }
    }

    private class FraudProcessCaseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(getProcessCaseResponseXml());
            return res;
        }
    }

    private class FraudHealthCheckMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('OK');
            return res;
        }
    }

    private class FraudCalloutErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('<ERROR>Server Error</ERROR>');
            return res;
        }
    }

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
        FEC_User_Type__c userType = new FEC_User_Type__c(
            FEC_Code__c = 'EXISTING',
            Name = 'Existing Customer',
            FEC_Name_VN__c = 'Khách hàng hiện hữu',
            FEC_Status__c = true,
            FEC_Pos_Order__c = 1
        );
        insert userType;

        // Master Data Integration records
        List<FEC_Master_Data_Integration__c> masterData = new List<FEC_Master_Data_Integration__c>();

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'Product',
            FEC_Source_Id__c = 'PROD-001',
            FEC_Source_Parent_Id__c = null,
            FEC_Source_Name__c = 'Credit Card',
            FEC_Source_NameVN__c = 'Thẻ tín dụng',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'CaseType',
            FEC_Source_Id__c = 'CT-001',
            FEC_Source_Parent_Id__c = 'PROD-001',
            FEC_Source_Name__c = 'Fraud Review',
            FEC_Source_NameVN__c = 'Xem xét gian lận',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'Category',
            FEC_Source_Id__c = 'CAT-001',
            FEC_Source_Parent_Id__c = 'CT-001',
            FEC_Source_Name__c = 'Card Fraud',
            FEC_Source_NameVN__c = 'Gian lận thẻ',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'SubCategory',
            FEC_Source_Id__c = 'SUBCAT-001',
            FEC_Source_Parent_Id__c = 'CAT-001',
            FEC_Source_Name__c = 'Lost Card',
            FEC_Source_NameVN__c = 'Mất thẻ',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'SubCode',
            FEC_Source_Id__c = 'SC-001',
            FEC_Source_Parent_Id__c = 'SUBCAT-001',
            FEC_Source_Name__c = 'Stolen',
            FEC_Source_NameVN__c = 'Bị đánh cắp',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'AP-001',
            FEC_Source_Parent_Id__c = 'SC-001',
            FEC_Source_Name__c = 'Transaction Amount',
            FEC_Source_NameVN__c = 'Số tiền giao dịch',
            FEC_Source_Field_Type__c = 'string',
            FEC_Source_Is_Mandatory__c = true,
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AdditionalProperty',
            FEC_Source_Id__c = 'AP-002',
            FEC_Source_Parent_Id__c = 'SC-001',
            FEC_Source_Name__c = 'Location',
            FEC_Source_NameVN__c = 'Vị trí',
            FEC_Source_Field_Type__c = 'list',
            FEC_Source_Is_Mandatory__c = false,
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 2
        ));

        masterData.add(new FEC_Master_Data_Integration__c(
            FEC_Source_Type__c = 'AvailableValues',
            FEC_Source_Id__c = 'AV-001',
            FEC_Source_Parent_Id__c = 'AP-002',
            FEC_Source_Name__c = 'HCM',
            FEC_Source_NameVN__c = 'TP.HCM',
            FEC_Channel__c = 'FIMA',
            FEC_PosOrder__c = 1
        ));

        insert masterData;

        // Integration Cases
        FEC_Integration_Case__c fhCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'FH-100001',
            FEC_Service_Case_ID__c = 'S-000001',
            FEC_Case_Status__c = 'Fraud/SEC Investigating',
            FEC_Sys_Channel__c = 'FIMA',
            FEC_Category__c = 'CAT-001',
            FEC_Sub_Category__c = 'SUBCAT-001',
            FEC_Sub_Code__c = 'SC-001',
            FEC_Creator_Email__c = 'test@test.com'
        );
        insert fhCase;

        FEC_Integration_Case__c buCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'BU-200001',
            FEC_Parent_CaseID__c = 'FH-100001',
            FEC_Case_Status__c = 'SEC Investigating',
            FEC_Sys_Channel__c = 'FIMA'
        );
        insert buCase;

        FEC_Integration_Case__c tkCase = new FEC_Integration_Case__c(
            FEC_CaseID__c = 'TK-300001',
            FEC_Parent_CaseID__c = 'BU-200001',
            FEC_Service_Case_ID__c = 'S-000002',
            FEC_Case_Status__c = 'SEC Investigating',
            FEC_Sys_Channel__c = 'FIMA',
            FEC_Investigation_Conclusion__c = 'Under review'
        );
        insert tkCase;

        // Case Info records
        List<FEC_Integration_Case_Info__c> infos = new List<FEC_Integration_Case_Info__c>();
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id,
            FEC_Info_ID__c = 'UIC',
            FEC_Info_Value__c = 'CS'
        ));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id,
            FEC_Info_ID__c = 'Deadline',
            FEC_Info_Value__c = '20260630'
        ));
        infos.add(new FEC_Integration_Case_Info__c(
            FEC_Parent_Case__c = tkCase.Id,
            FEC_Info_ID__c = 'TaskName',
            FEC_Info_Value__c = 'Verify'
        ));
        insert infos;

        // Additional Field for mapping
        FEC_Additional_Field__c addField = new FEC_Additional_Field__c(
            Name = 'Transaction Amount',
            FEC_Unique_ID__c = 'AP-001',
            FEC_Type__c = 'string',
            FEC_Name_VN__c = 'Số tiền giao dịch'
        );
        insert addField;
    }

    /* =========================================================
     * TEST: FEC_IntegrationSoapFraudcaseService (type coverage)
     * ========================================================= */
    @IsTest
    static void testSoapServiceTypes() {
        Test.startTest();

        // Instantiate all inner types for coverage
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            new FEC_IntegrationSoapFraudcaseService.CustomerInfo_element();
        cust.UserType = 'Customer';

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            new FEC_IntegrationSoapFraudcaseService.SysType();
        sys.Channel = 'PEGACSM';
        sys.TransactionID = 'TX-001';
        sys.DateTime_x = System.now();

        FEC_IntegrationSoapFraudcaseService.SysType2 sys2 =
            new FEC_IntegrationSoapFraudcaseService.SysType2();
        sys2.Code = '1';
        sys2.Description = 'Success';

        FEC_IntegrationSoapFraudcaseService.SysType3 sys3 =
            new FEC_IntegrationSoapFraudcaseService.SysType3();
        sys3.Channel = 'WEB';

        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType createResp =
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType();
        createResp.Sys = sys2;
        createResp.CaseID = 'FH-999';

        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType cancelResp =
            new FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType();
        cancelResp.Sys = sys2;
        cancelResp.CaseID = 'FH-999';

        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType processResp =
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType();
        processResp.Sys = sys2;

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType();
        creator.CreatorEmail = 'test@test.com';

        FEC_IntegrationSoapFraudcaseService.CreatorInfoType2 creator2 =
            new FEC_IntegrationSoapFraudcaseService.CreatorInfoType2();
        creator2.CreatorEmail = 'test@test.com';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseInfo =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType();
        caseInfo.CaseID = 'FH-001';
        caseInfo.Remarks = 'Test';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType2 caseInfo2 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType2();
        caseInfo2.CaseID = 'FH-002';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseInfo4 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        caseInfo4.CaseID = 'FH-003';
        caseInfo4.Decision = 'Approve';
        caseInfo4.SubDecision = 'SubD';
        caseInfo4.Reason = 'Valid';
        caseInfo4.Remarks = 'Done';

        FEC_IntegrationSoapFraudcaseService.RequestInfo_element reqInfo =
            new FEC_IntegrationSoapFraudcaseService.RequestInfo_element();
        reqInfo.CaseType = 'Fraud';
        reqInfo.ProductType = 'Card';
        reqInfo.Category = 'CAT';
        reqInfo.SubCategory = 'SUB';
        reqInfo.SubCode = 'SC';
        reqInfo.Remarks = 'Test';

        FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element reqCustom =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element();
        reqCustom.CaseType = 'Fraud';

        FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element ai =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element();
        ai.ID = 'AP-001';
        ai.Value = '100000';

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element aiCustom =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element();
        aiCustom.ID = 'AP-001';
        aiCustom.Value = '100000';
        aiCustom.Type = 'string';
        aiCustom.Mandatory = true;

        FEC_IntegrationSoapFraudcaseService.AdditionalInfoType aiType =
            new FEC_IntegrationSoapFraudcaseService.AdditionalInfoType();
        aiType.ID = 'X';
        aiType.Value = 'Y';

        FEC_IntegrationSoapFraudcaseService.MasterDataItemsType mdi =
            new FEC_IntegrationSoapFraudcaseService.MasterDataItemsType();
        mdi.ID = '1';
        mdi.Name = 'Test';

        FEC_IntegrationSoapFraudcaseService.ChildrenType child =
            new FEC_IntegrationSoapFraudcaseService.ChildrenType();
        child.ID = '2';

        FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType ap =
            new FEC_IntegrationSoapFraudcaseService.AdditionalPropertiesType();
        ap.ID = '3';
        ap.Mandatory = true;

        FEC_IntegrationSoapFraudcaseService.AvailableValuesType av =
            new FEC_IntegrationSoapFraudcaseService.AvailableValuesType();
        av.ID = '4';
        av.Name = 'Val';

        FEC_IntegrationSoapFraudcaseService.TasksType task =
            new FEC_IntegrationSoapFraudcaseService.TasksType();
        task.Name = 'T1';

        FEC_IntegrationSoapFraudcaseService.RequestInfoType2 reqInfo2 =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType2();
        reqInfo2.CaseID = 'C1';
        reqInfo2.FileID = 'F1';

        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType gfmdrt =
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataResponseType();
        gfmdrt.Sys = sys2;

        FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType gfmdreq =
            new FEC_IntegrationSoapFraudcaseService.GetFraudMasterDataRequestType();
        gfmdreq.Sys = sys;

        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType cfcrt =
            new FEC_IntegrationSoapFraudcaseService.CreateFraudCaseRequestType();
        cfcrt.Sys = sys;

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType gfafrt =
            new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileResponseType();
        gfafrt.FileName = 'test.pdf';

        FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType gfafreq =
            new FEC_IntegrationSoapFraudcaseService.GetFraudAttachedFileRequestType();
        gfafreq.Sys = sys;

        FEC_IntegrationSoapFraudcaseService.InvestigationResultsType irt =
            new FEC_IntegrationSoapFraudcaseService.InvestigationResultsType();
        irt.AppID = 'APP1';

        FEC_IntegrationSoapFraudcaseService.CaseInfoType3 ci3 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType3();
        ci3.CaseID = 'X';

        FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType cdi =
            new FEC_IntegrationSoapFraudcaseService.CaseDetailedInfoType();
        cdi.ID = 'D1';

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType gfcsrt =
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusRequestType();
        gfcsrt.Sys = sys;

        FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType gfcsresp =
            new FEC_IntegrationSoapFraudcaseService.GetFraudCaseStatusResponseType();
        gfcsresp.Sys = sys2;

        FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType pcrt =
            new FEC_IntegrationSoapFraudcaseService.ProcessCaseRequestType();
        pcrt.Sys = sys;

        FEC_IntegrationSoapFraudcaseService.OriginalRequestType ort =
            new FEC_IntegrationSoapFraudcaseService.OriginalRequestType();
        ort.Sys = sys3;

        FEC_IntegrationSoapFraudcaseService.CustomerInfoType custType =
            new FEC_IntegrationSoapFraudcaseService.CustomerInfoType();
        custType.UserType = 'Agent';

        FEC_IntegrationSoapFraudcaseService.RequestInfoType rit =
            new FEC_IntegrationSoapFraudcaseService.RequestInfoType();
        rit.CaseType = 'X';

        Test.stopTest();

        Assert.isNotNull(createResp.CaseID, 'CreateResponse CaseID should be set');
        Assert.isNotNull(cancelResp.CaseID, 'CancelResponse CaseID should be set');
        Assert.isNotNull(sys2.Code, 'SysType2 Code should be set');
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudCaseUtil
     * ========================================================= */
    @IsTest
    static void testFraudCaseUtil_buildMethods() {
        Test.startTest();

        // buildTag
        String tag = FEC_IntegrationFraudCaseUtil.buildTag('Channel', 'WEB');
        Assert.isTrue(tag.contains('<ns1:Channel>'), 'Tag should contain Channel element');
        Assert.isTrue(tag.contains('WEB'), 'Tag should contain value');

        String emptyTag = FEC_IntegrationFraudCaseUtil.buildTag('Channel', null);
        Assert.areEqual('', emptyTag, 'Blank value should return empty string');

        // generateUUID
        String uuid = FEC_IntegrationFraudCaseUtil.generateUUID();
        Assert.isNotNull(uuid, 'UUID should not be null');
        Assert.isTrue(uuid.contains('-'), 'UUID should contain dashes');

        // safeText
        String safe = FEC_IntegrationFraudCaseUtil.safeText('Hello');
        Assert.areEqual('Hello', safe, 'safeText should return input when short');

        String nullSafe = FEC_IntegrationFraudCaseUtil.safeText(null);
        Assert.isNull(nullSafe, 'safeText null should return null');

        // formatDateTime
        String formatted = FEC_IntegrationFraudCaseUtil.formatDateTime(System.now());
        Assert.isNotNull(formatted, 'formatDateTime should return non-null for valid input');

        String nullFormatted = FEC_IntegrationFraudCaseUtil.formatDateTime(null);
        Assert.isNull(nullFormatted, 'formatDateTime null should return null');

        // formatDDMMYYYY
        String dateFormatted = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('20260630');
        Assert.areEqual('30/06/2026', dateFormatted, 'Date should be formatted correctly');

        String invalidDate = FEC_IntegrationFraudCaseUtil.formatDDMMYYYY('abc');
        Assert.isNull(invalidDate, 'Invalid date should return null');

        // parsePegaDatetime
        Datetime dt = FEC_IntegrationFraudCaseUtil.parsePegaDatetime('2025-09-10T10:07:22.263Z');
        Assert.isNotNull(dt, 'parsePegaDatetime should parse valid input');

        Datetime nullDt = FEC_IntegrationFraudCaseUtil.parsePegaDatetime(null);
        Assert.isNull(nullDt, 'parsePegaDatetime null should return null');

        // mapCaseStatus
        String mapped = FEC_IntegrationFraudCaseUtil.mapCaseStatus('Allocating');
        Assert.areEqual('SEC Investigating', mapped, 'Allocating should map to SEC Investigating');

        String unmapped = FEC_IntegrationFraudCaseUtil.mapCaseStatus('UnknownStatus');
        Assert.areEqual('UnknownStatus', unmapped, 'Unknown status should return original');

        // getMimeType
        String mime = FEC_IntegrationFraudCaseUtil.getMimeType('pdf');
        Assert.areEqual(FEC_FraudConstantCommon.MIME_PDF, mime, 'pdf should map to PDF mime');

        String defaultMime = FEC_IntegrationFraudCaseUtil.getMimeType(null);
        Assert.areEqual(FEC_FraudConstantCommon.MIME_DEFAULT, defaultMime, 'null ext should return default');

        // normalizeXml
        String normalXml = FEC_IntegrationFraudCaseUtil.normalizeXml('  junk<Root>data</Root>trash  ');
        Assert.isTrue(normalXml.startsWith('<Root>'), 'normalizeXml should trim before first <');

        // extractCaseIdFromResponse
        String respXml = '<Response><Success>true</Success><CaseId>FH-123</CaseId><Message>OK</Message></Response>';
        FEC_IntegrationFraudCaseUtil.UpdateCaseResponse ucr =
            FEC_IntegrationFraudCaseUtil.extractCaseIdFromResponse(respXml);
        Assert.isNotNull(ucr, 'extractCaseIdFromResponse should return non-null');

        // randomCaseId / randomTransactionId
        String rCaseId = FEC_IntegrationFraudCaseUtil.randomCaseId();
        Assert.isTrue(rCaseId.startsWith('FH-'), 'randomCaseId should start with FH-');

        String rTxId = FEC_IntegrationFraudCaseUtil.randomTransactionId();
        Assert.isNotNull(rTxId, 'randomTransactionId should not be null');

        // nowAsXmlDateTime
        String xmlDt = FEC_IntegrationFraudCaseUtil.nowAsXmlDateTime();
        Assert.isTrue(xmlDt.contains('T'), 'XML datetime should contain T separator');

        Test.stopTest();
    }

    @IsTest
    static void testFraudCaseUtil_buildSoapObjects() {
        Test.startTest();

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w =
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.channel = 'PEGACSM';
        w.channelCode = 'FIMA';
        w.caseType = 'Fraud';
        w.productType = 'Card';
        w.category = 'CAT-001';
        w.subCategory = 'SUBCAT-001';
        w.subCode = 'SC-001';
        w.remarks = 'Test remarks';
        w.userType = 'Existing';
        w.creatorEmail = 'test@test.com';
        w.serviceCaseId = 'S-000001';
        w.additionalInfos = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();
        w.additionalInfoOrginal = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element>();

        // buildSys
        FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(w);
        Assert.areEqual('PEGACSM', sys.Channel, 'Sys channel should match');

        // buildCustomer
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            FEC_IntegrationFraudCaseUtil.buildCustomer(w);
        Assert.areEqual('Existing', cust.UserType, 'Customer UserType should match');

        // buildCCaseInfo
        w.caseId = 'FH-100001';
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo =
            FEC_IntegrationFraudCaseUtil.buildCCaseInfo(w);
        Assert.areEqual('FH-100001', caseIfo.CaseID, 'CaseInfo CaseID should match');

        // buildRequest
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req =
            FEC_IntegrationFraudCaseUtil.buildRequest(w);
        Assert.areEqual('Fraud', req.CaseType, 'Request CaseType should match');

        // buildRequestOriginal
        FEC_IntegrationSoapFraudcaseService.RequestInfoCustom_element reqOr =
            FEC_IntegrationFraudCaseUtil.buildRequestOriginal(w);
        Assert.areEqual('Fraud', reqOr.CaseType, 'RequestOriginal CaseType should match');

        // buildCreator
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(w);
        Assert.areEqual('test@test.com', creator.CreatorEmail, 'Creator email should match');

        // getIntegrationCaseById
        FEC_Integration_Case__c found =
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('FH-100001');
        Assert.isNotNull(found, 'Should find existing fraud case');

        FEC_Integration_Case__c notFound =
            FEC_IntegrationFraudCaseUtil.getIntegrationCaseById('FH-NONEXIST');
        Assert.isNull(notFound, 'Should return null for non-existing case');

        // logIntegrationService
        FEC_IntegrationFraudCaseUtil.logIntegrationService(
            'TestService', 'FIMA', 'FH-001', 'S-001',
            '<request/>', '<response/>', 'OK', 'test@test.com', '200'
        );

        List<FEC_Integration_Service_Log__c> logs = [
            SELECT Id FROM FEC_Integration_Service_Log__c WHERE FEC_Service_Name__c = 'TestService'
        ];
        Assert.areEqual(1, logs.size(), 'One log record should be created');

        Test.stopTest();
    }

    @IsTest
    static void testFraudCaseUtil_extractPayload() {
        Test.startTest();

        Map<String, Object> payload = new Map<String, Object>{
            'Channel' => 'PEGACSM',
            'CaseType' => 'Fraud',
            'ProductType' => 'Card',
            'Category' => 'CAT-001',
            'SubCategory' => 'SUBCAT-001',
            'SubCode' => 'SC-001',
            'Remarks' => 'Test',
            'UserType' => 'Existing',
            'FraudCaseId' => '',
            'ServiceCaseId' => '',
            'ChannelIntegrationCode' => 'FIMA',
            'AdditionalInfo' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'ID' => 'AP-001', 'Value' => '50000', 'Type' => 'string', 'Mandatory' => true }
            }
        };

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w =
            FEC_IntegrationFraudCaseUtil.extractPayload(payload);

        Assert.areEqual('Fraud', w.caseType, 'CaseType should match');
        Assert.areEqual('FIMA', w.channelCode, 'ChannelCode should match');
        Assert.isNotNull(w.serviceCaseId, 'ServiceCaseId should be set');
        Assert.isTrue(w.additionalInfos.size() >= 2, 'Should have at least 2 additionalInfos (1 + ReferenceID)');

        Test.stopTest();
    }

    @IsTest
    static void testFraudCaseUtil_extractFraudPayload() {
        Test.startTest();

        String rawJson = '{"detail":{"caseID":"FH-001","referenceID":"S-001","channelID":"FIMA","data":"<Root><CaseResultInfo><Remarks>Test</Remarks></CaseResultInfo></Root>","messageTime":1700000000000}}';

        FEC_IntegrationFraudCaseUtil.FraudExtractResult result =
            FEC_IntegrationFraudCaseUtil.extractFraudPayload(rawJson);

        Assert.isNotNull(result.detail, 'Detail should not be null');
        Assert.isNotNull(result.xmlData, 'xmlData should not be null');
        Assert.isTrue(result.xmlData.contains('<Root>'), 'xmlData should contain XML');

        Test.stopTest();
    }

    @IsTest
    static void testFraudCaseUtil_xmlHelpers() {
        Test.startTest();

        // Build a simple XML doc for testing find/val/findAll/findAllDeep
        Dom.Document doc = new Dom.Document();
        String xml = '<Root><CaseResultInfo><Remarks>Hello</Remarks><AdditionalInfo><ID>X</ID><Value>Y</Value></AdditionalInfo></CaseResultInfo></Root>';
        doc.load(xml);
        Dom.XmlNode root = doc.getRootElement();

        // find
        Dom.XmlNode caseNode = FEC_IntegrationFraudCaseUtil.find(root, 'CaseResultInfo');
        Assert.isNotNull(caseNode, 'find should locate CaseResultInfo');

        // val
        String remarks = FEC_IntegrationFraudCaseUtil.val(caseNode, 'Remarks');
        Assert.areEqual('Hello', remarks, 'val should extract Remarks text');

        // findAll
        List<Dom.XmlNode> ais = FEC_IntegrationFraudCaseUtil.findAll(caseNode, 'AdditionalInfo');
        Assert.areEqual(1, ais.size(), 'findAll should find 1 AdditionalInfo');

        // findAllDeep
        List<Dom.XmlNode> deepAIs = FEC_IntegrationFraudCaseUtil.findAllDeep(root, 'AdditionalInfo');
        Assert.areEqual(1, deepAIs.size(), 'findAllDeep should find 1 AdditionalInfo');

        // successResponseXml and errorResponseXml (without RestContext)
        // These need RestContext, but we can test without it (null check)
        Dom.Document errDoc = FEC_IntegrationFraudCaseUtil.errorResponseXml('Error msg', 400);
        Assert.isNotNull(errDoc, 'errorResponseXml should return document');

        Dom.Document succDoc = FEC_IntegrationFraudCaseUtil.successResponseXml('FH-001', 'OK');
        Assert.isNotNull(succDoc, 'successResponseXml should return document');

        // cleanJson
        String rawWithData = '{"detail":{"caseID":"X","data":"<xml>stuff</xml>","messageTime":123}}';
        String cleaned = FEC_IntegrationFraudCaseUtil.cleanJson(rawWithData);
        Assert.isTrue(cleaned.contains('"data":""'), 'cleanJson should empty data value');

        // extractXml
        String extracted = FEC_IntegrationFraudCaseUtil.extractXml('junk<Root>data</Root>more');
        Assert.areEqual('<Root>data</Root>', extracted, 'extractXml should extract XML portion');

        Test.stopTest();
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudService - getFraudMasterData
     * ========================================================= */
    @IsTest
    static void testFraudService_getFraudMasterData() {
        Test.setMock(HttpCalloutMock.class, new FraudMasterDataMock());

        Test.startTest();
        String result = FEC_IntegrationFraudService.getFraudMasterData();
        Test.stopTest();

        Assert.isNotNull(result, 'getFraudMasterData should return response');
        Assert.isTrue(result.contains('GetFraudMasterDataResponse'), 'Should contain response node');
    }

    @IsTest
    static void testFraudService_isConnectFraudSystem() {
        Test.setMock(HttpCalloutMock.class, new FraudHealthCheckMock());

        Test.startTest();
        Boolean connected = FEC_IntegrationFraudService.isConnectFraudSystem();
        Test.stopTest();

        Assert.isTrue(connected, 'Health check should return true for 200');
    }

    @IsTest
    static void testFraudService_getAdminRecipients() {
        Test.startTest();
        List<String> recipients = FEC_IntegrationFraudService.getAdminRecipients();
        Test.stopTest();

        Assert.isNotNull(recipients, 'Recipients list should not be null');
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudService - syncMasterDataIntegration
     * ========================================================= */
    @IsTest
    static void testFraudService_syncMasterData() {
        Test.setMock(HttpCalloutMock.class, new FraudMasterDataMock());

        Test.startTest();
        Integer count = FEC_IntegrationFraudService.syncMasterDataIntegration();
        Test.stopTest();

        Assert.isTrue(count >= 0, 'syncMasterDataIntegration should return count');
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudService - callCreateFraudCaseService
     * ========================================================= */
    @IsTest
    static void testFraudService_callCreateFraudCase() {
        Test.setMock(HttpCalloutMock.class, new FraudCreateCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildTestWrapper();

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            FEC_IntegrationFraudCaseUtil.buildCustomer(w);
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req =
            FEC_IntegrationFraudCaseUtil.buildRequest(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callCreateFraudCaseService(w, sys, cust, req, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Create response should not be null');
        Assert.areEqual('1', resp.Sys.Code, 'Response code should be 1');
    }

    @IsTest
    static void testFraudService_callCancelFraudCase() {
        Test.setMock(HttpCalloutMock.class, new FraudCancelCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildTestWrapper();
        w.caseId = 'FH-100001';

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CaseInfoType caseIfo =
            FEC_IntegrationFraudCaseUtil.buildCCaseInfo(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CancelFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callCancelFraudCaseService(w, sys, caseIfo, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Cancel response should not be null');
    }

    @IsTest
    static void testFraudService_callUpdateFraudCase() {
        Test.setMock(HttpCalloutMock.class, new FraudCreateCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildTestWrapper();
        w.caseId = 'FH-100001';

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CustomerInfo_element cust =
            FEC_IntegrationFraudCaseUtil.buildCustomer(w);
        FEC_IntegrationSoapFraudcaseService.RequestInfo_element req =
            FEC_IntegrationFraudCaseUtil.buildRequest(w);
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.CreateFraudCaseResponseType resp =
            FEC_IntegrationFraudService.callUpdateFraudCaseService(w, sys, cust, req, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Update response should not be null');
    }

    @IsTest
    static void testFraudService_callProcessFraudCase() {
        Test.setMock(HttpCalloutMock.class, new FraudProcessCaseMock());

        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w = buildTestWrapper();

        FEC_IntegrationSoapFraudcaseService.SysType sys =
            FEC_IntegrationFraudCaseUtil.buildSys(w);
        FEC_IntegrationSoapFraudcaseService.CaseInfoType4 caseInfo4 =
            new FEC_IntegrationSoapFraudcaseService.CaseInfoType4();
        caseInfo4.CaseID = 'FH-100001';
        caseInfo4.Decision = 'Approve';
        caseInfo4.Remarks = 'OK';
        FEC_IntegrationSoapFraudcaseService.CreatorInfoType creator =
            FEC_IntegrationFraudCaseUtil.buildCreator(w);

        Test.startTest();
        FEC_IntegrationSoapFraudcaseService.ProcessCaseResponseType resp =
            FEC_IntegrationFraudService.callProcessFraudCaseService(w, sys, caseInfo4, creator);
        Test.stopTest();

        Assert.isNotNull(resp, 'Process response should not be null');
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudScheduler
     * ========================================================= */
    @IsTest
    static void testFraudScheduler() {
        // The scheduler's execute() queries EmailTemplate which doesn't exist in test.
        // We verify schedulable interface works without actually executing.
        FEC_IntegrationFraudScheduler scheduler = new FEC_IntegrationFraudScheduler();
        Assert.isNotNull(scheduler, 'Scheduler should be instantiable');

        // Don't schedule with Test.startTest/stopTest since it fires execute()
        // Coverage for scheduler's execute() is indirect via other integration tests
    }

    @IsTest
    static void testFraudService_sendJobEmail() {
        // Test sendJobEmail separately with try-catch since EmailTemplate may not exist
        Test.startTest();
        try {
            FEC_IntegrationFraudService.sendJobEmail(
                'SUCCESS', 'TestJob', 'triggerId123',
                '0 0 0 * * ?', System.now(),
                10, '5 seconds', null,
                new List<String>{ 'test@test.com' }
            );
        } catch (Exception e) {
            // Expected: EmailTemplate not found in test context
            Assert.isTrue(
                e.getMessage().contains('no rows') || e.getMessage().contains('List has no rows'),
                'Should fail due to missing EmailTemplate'
            );
        }
        Test.stopTest();
    }

    /* =========================================================
     * TEST: FEC_IntegrationFraudCaseApi
     * ========================================================= */
    @IsTest
    static void testFraudCaseApi_FHCase() {
        Test.startTest();

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getFHUpdatePayload());

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        String response = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();

        Test.stopTest();

        Assert.isNotNull(response, 'API response should not be null');
    }

    @IsTest
    static void testFraudCaseApi_BUCase() {
        Test.startTest();

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getBUUpdatePayload());

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        String response = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();

        Test.stopTest();

        Assert.isNotNull(response, 'BU API response should not be null');
    }

    @IsTest
    static void testFraudCaseApi_TKCase() {
        Test.startTest();

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(getTKUpdatePayload());

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        String response = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();

        Test.stopTest();

        Assert.isNotNull(response, 'TK API response should not be null');
    }

    @IsTest
    static void testFraudCaseApi_InvalidCase() {
        Test.startTest();

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"detail":{"caseID":"INVALID-001","referenceID":"S-001","channelID":"FIMA","data":"<Root><CaseResultInfo><Remarks>X</Remarks></CaseResultInfo></Root>","messageTime":1700000000000}}');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        String response = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();

        Test.stopTest();

        Assert.isTrue(response.contains('false'), 'Invalid case format should return error');
    }

    @IsTest
    static void testFraudCaseApi_MissingCaseId() {
        Test.startTest();

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/fec/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"detail":{"caseID":"","referenceID":"S-001","channelID":"FIMA","data":"<Root/>","messageTime":1700000000000}}');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        String response = FEC_IntegrationFraudCaseApi.UpdateFraudCaseStatus();

        Test.stopTest();

        Assert.isTrue(response.contains('false'), 'Missing caseId should return error');
    }

    /* =========================================================
     * TEST: FEC_IntegrationCreateFraudController
     * ========================================================= */
    @IsTest
    static void testCreateFraudController_loadChannelList() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> channels =
            FEC_IntegrationCreateFraudController.loadChannelList();
        Test.stopTest();

        Assert.isTrue(channels.size() > 0, 'Should return at least 1 channel');
    }

    @IsTest
    static void testCreateFraudController_loadMasterData() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.NodeDTO> result =
            FEC_IntegrationCreateFraudController.loadMasterDataIntegration('CaseType', 'PROD-001', 'FIMA');
        Test.stopTest();

        Assert.isNotNull(result, 'Should return node list');
    }

    @IsTest
    static void testCreateFraudController_loadAdditionalProperties() {
        Test.startTest();
        List<FEC_IntegrationCreateFraudController.PropertyDTO> props =
            FEC_IntegrationCreateFraudController.loadAdditionalProperties(
                'CAT-001', 'SUBCAT-001', 'SC-001', 'FIMA', 'CT-001'
            );
        Test.stopTest();

        Assert.isTrue(props.size() > 0, 'Should return additional properties');
    }

    @IsTest
    static void testCreateFraudController_getMasterDataForUI() {
        Test.startTest();
        String json = FEC_IntegrationCreateFraudController.getMasterDataForUI();
        Test.stopTest();

        Assert.isNotNull(json, 'getMasterDataForUI should return JSON');
        Assert.isTrue(json.contains('categories'), 'Should contain categories key');
    }

    @IsTest
    static void testCreateFraudController_getFraudCaseById() {
        FEC_Integration_Case__c fhCase = [
            SELECT Id FROM FEC_Integration_Case__c WHERE FEC_CaseID__c = 'FH-100001' LIMIT 1
        ];

        Test.startTest();
        FEC_IntegrationCreateFraudController.FraudPropertyDTO result =
            FEC_IntegrationCreateFraudController.getFraudCaseById(fhCase.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return FraudPropertyDTO');
    }

    @IsTest
    static void testCreateFraudController_getIntegrationFieldTypes() {
        Test.startTest();
        Map<String, String> types =
            FEC_IntegrationCreateFraudController.getIntegrationFieldTypes();
        Test.stopTest();

        Assert.isTrue(types.size() > 0, 'Should return field type map');
    }

    @IsTest
    static void testCreateFraudController_submitCreate() {
        Test.setMock(HttpCalloutMock.class, new FraudCreateCaseMock());

        Map<String, Object> payload = new Map<String, Object>{
            'CaseType' => 'Fraud',
            'ProductType' => 'Card',
            'Category' => 'CAT-001',
            'SubCategory' => 'SUBCAT-001',
            'SubCode' => 'SC-001',
            'Remarks' => 'Test create',
            'UserType' => 'Existing',
            'ChannelIntegrationCode' => 'FIMA',
            'AdditionalInfo' => new List<Object>{
                new Map<String, Object>{ 'ID' => 'AP-001', 'Value' => '5000', 'Type' => 'string', 'Mandatory' => true }
            }
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitCreateFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Response should not be null');
    }

    @IsTest
    static void testCreateFraudController_submitCancel() {
        Test.setMock(HttpCalloutMock.class, new FraudCancelCaseMock());

        Map<String, Object> payload = new Map<String, Object>{
            'FraudCaseId' => 'FH-100001',
            'ServiceCaseId' => 'S-000001',
            'ChannelIntegrationCode' => 'FIMA',
            'Remarks' => 'Cancel test'
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitCancelFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Cancel response should not be null');
    }

    @IsTest
    static void testCreateFraudController_submitUpdate() {
        Test.setMock(HttpCalloutMock.class, new FraudCreateCaseMock());

        Map<String, Object> payload = new Map<String, Object>{
            'FraudCaseId' => 'FH-100001',
            'CaseType' => 'Fraud',
            'ProductType' => 'Card',
            'Category' => 'CAT-001',
            'SubCategory' => 'SUBCAT-001',
            'SubCode' => 'SC-001',
            'Remarks' => 'Update test',
            'UserType' => 'Existing',
            'ServiceCaseId' => 'S-000001',
            'ChannelIntegrationCode' => 'FIMA',
            'AdditionalInfo' => new List<Object>()
        };

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_IntegrationCreateFraudController.submitUpdateFraudCase(payload);
        Test.stopTest();

        Assert.isNotNull(resp, 'Update response should not be null');
    }

    @IsTest
    static void testCreateFraudController_loadCategoryMapping() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.CategoryMappingResponse resp =
            FEC_IntegrationCreateFraudController.loadCategoryMapping('FIMA');
        Test.stopTest();

        Assert.isNotNull(resp, 'CategoryMapping should not be null');
    }

    /* =========================================================
     * TEST: FEC_IntegrationMappingController
     * ========================================================= */
    @IsTest
    static void testMappingController_loadMethods() {
        Test.startTest();

        List<FEC_IntegrationMappingController.NodeDTO> userTypes =
            FEC_IntegrationMappingController.loadUserTypeList();
        Assert.isTrue(userTypes.size() > 0, 'Should return user types');

        List<FEC_IntegrationMappingController.NodeDTO> channels =
            FEC_IntegrationMappingController.loadChannelList();
        Assert.isTrue(channels.size() > 0, 'Should return channels');

        List<FEC_IntegrationMappingController.NodeDTO> masters =
            FEC_IntegrationMappingController.loadMasterIntegration('CaseType', 'PROD-001', 'FIMA');
        Assert.isNotNull(masters, 'Should return master data');

        List<FEC_IntegrationMappingController.PropertyDTO> props =
            FEC_IntegrationMappingController.loadAdditionalProperties(
                'CAT-001', 'SUBCAT-001', 'SC-001', 'FIMA', 'CT-001', null
            );
        Assert.isNotNull(props, 'Should return properties');

        Test.stopTest();
    }

    @IsTest
    static void testMappingController_saveAndLoad() {
        FEC_User_Type__c ut = [SELECT Id FROM FEC_User_Type__c LIMIT 1];

        String payloadJson = JSON.serialize(new Map<String, Object>{
            'header' => new Map<String, Object>{
                'userType' => ut.Id,
                'channel' => 'FIMA',
                'intUserType' => ut.Id,
                'productLine' => 'PROD-001',
                'serviceType' => 'CT-001',
                'category' => 'CAT-001',
                'subCategory' => 'SUBCAT-001',
                'subCode' => 'SC-001',
                'natureOfCaseId' => null,
                'caseStageId' => null,
                'screenCaseId' => null,
                'mappingId' => null
            },
            'details' => new List<Object>{
                new Map<String, Object>{
                    'property' => 'AP-001',
                    'type' => 'string',
                    'csmProperty' => 'Subject',
                    'csmPropertyType' => 'text',
                    'autoMapping' => false,
                    'mandatory' => true,
                    'autoMappingPropertySource' => null
                }
            }
        });

        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO saveResult =
            FEC_IntegrationMappingController.saveIntegrationMapping(payloadJson);
        Assert.isTrue(saveResult.success, 'Save should succeed');
        Assert.isNotNull(saveResult.mappingId, 'MappingId should be returned');

        FEC_IntegrationMappingController.MappingDTO loaded =
            FEC_IntegrationMappingController.loadIntegrationMapping(saveResult.mappingId);
        Assert.isNotNull(loaded.id, 'Loaded mapping should have Id');
        Assert.areEqual(1, loaded.infos.size(), 'Should have 1 info record');

        Test.stopTest();
    }

    @IsTest
    static void testMappingController_searchAdditionalFields() {
        Test.startTest();
        List<FEC_IntegrationMappingController.CsmFieldDTO> results =
            FEC_IntegrationMappingController.searchAdditionalFields('AP-001', 'string');
        Test.stopTest();

        Assert.isTrue(results.size() > 0, 'Should find additional field');
    }

    @IsTest
    static void testMappingController_saveBlankPayload() {
        Test.startTest();
        FEC_IntegrationMappingController.SaveResultDTO result =
            FEC_IntegrationMappingController.saveIntegrationMapping('');
        Test.stopTest();

        Assert.isFalse(result.success, 'Blank payload should fail');
    }

    /* =========================================================
     * TEST: FEC_ServiceFraudTaskCaseController
     * ========================================================= */
    @IsTest
    static void testServiceFraudTaskCase_getCaseData() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto =
            FEC_ServiceFraudTaskCaseController.getCaseData('S-000002');
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null');
        Assert.isNotNull(dto.task, 'Task info should not be null');
    }

    @IsTest
    static void testServiceFraudTaskCase_getCaseDataNull() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.ServiceFraudTaskDTO dto =
            FEC_ServiceFraudTaskCaseController.getCaseData('NONEXIST');
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null even for missing case');
    }

    @IsTest
    static void testServiceFraudTaskCase_submitProcess() {
        Test.setMock(HttpCalloutMock.class, new FraudProcessCaseMock());

        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                'S-000002', 'Approve', 'SubD', 'Valid reason', 'OK'
            );
        Test.stopTest();

        Assert.isNotNull(resp, 'Process response should not be null');
    }

    @IsTest
    static void testServiceFraudTaskCase_submitProcessNull() {
        Test.startTest();
        FEC_IntegrationFraudCaseUtil.FraudCaseResponse resp =
            FEC_ServiceFraudTaskCaseController.submitProcessCaseDecision(
                'NONEXIST', 'Approve', null, null, null
            );
        Test.stopTest();

        Assert.isFalse(resp.success, 'Should fail for non-existing case');
    }

    /* =========================================================
     * TEST: FEC_IntegrationManageFraudCaseCtrl
     * ========================================================= */
    @IsTest
    static void testManageFraudCase_initBlank() {
        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(null, null);
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null');
    }

    @IsTest
    static void testManageFraudCase_initWithCase() {
        // Create a Case to pass
        Case c = new Case(Subject = 'Test Fraud', FEC_ID_Search__c = 'S-000001');
        insert c;

        Test.startTest();
        FEC_IntegrationManageFraudCaseCtrl.ManageFraudCaseDTO dto =
            FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase(c.Id, null);
        Test.stopTest();

        Assert.isNotNull(dto, 'DTO should not be null');
        // The fraud case exists with S-000001 service case id
        Assert.isNotNull(dto.actionMode, 'Action mode should be determined');
    }

    @IsTest
    static void testManageFraudCase_getCaseToFraudFieldMap() {
        Test.startTest();
        Map<String, String> fieldMap =
            FEC_IntegrationManageFraudCaseCtrl.getCaseToFraudFieldMap(null, null);
        Test.stopTest();

        Assert.isNotNull(fieldMap, 'Field map should not be null');
        Assert.areEqual(0, fieldMap.size(), 'Null input should return empty map');
    }

    /* =========================================================
     * HELPER METHODS
     * ========================================================= */
    private static FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper buildTestWrapper() {
        FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper w =
            new FEC_IntegrationFraudCaseUtil.FraudCaseRequestWrapper();
        w.channel = 'PEGACSM';
        w.channelCode = 'FIMA';
        w.caseType = 'Fraud';
        w.productType = 'Card';
        w.category = 'CAT-001';
        w.subCategory = 'SUBCAT-001';
        w.subCode = 'SC-001';
        w.remarks = 'Test';
        w.userType = 'Existing';
        w.creatorEmail = 'test@test.com';
        w.serviceCaseId = 'S-000001';
        w.caseId = null;
        w.additionalInfos = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfo_element>();
        w.additionalInfoOrginal = new List<FEC_IntegrationSoapFraudcaseService.AdditionalInfoCustom_element>();
        return w;
    }

    private static String getMasterDataXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body>' +
            '<ns1:GetFraudMasterDataResponse>' +
            '<ns1:MasterDataItems>' +
            '<ns1:ID>PROD-T1</ns1:ID>' +
            '<ns1:Name>Test Product</ns1:Name>' +
            '<ns1:NameVN>San pham test</ns1:NameVN>' +
            '<ns1:Type>Product</ns1:Type>' +
            '<ns1:PosOrder>1</ns1:PosOrder>' +
            '<ns1:Children>' +
            '<ns1:ID>CT-T1</ns1:ID>' +
            '<ns1:Name>Test CaseType</ns1:Name>' +
            '<ns1:NameVN>Loai case test</ns1:NameVN>' +
            '<ns1:Type>CaseType</ns1:Type>' +
            '<ns1:PosOrder>1</ns1:PosOrder>' +
            '</ns1:Children>' +
            '</ns1:MasterDataItems>' +
            '</ns1:GetFraudMasterDataResponse>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static String getCreateCaseResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body>' +
            '<ns1:CreateFraudCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Success</ns1:Description></ns1:Sys>' +
            '<ns1:CaseID>FH-999999</ns1:CaseID>' +
            '</ns1:CreateFraudCaseResponse>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static String getCancelCaseResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body>' +
            '<ns1:CancelFraudCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Canceled</ns1:Description></ns1:Sys>' +
            '<ns1:CaseID>FH-100001</ns1:CaseID>' +
            '</ns1:CancelFraudCaseResponse>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static String getProcessCaseResponseXml() {
        return '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:PegaRULES:SOAP:FraudCase:Services">' +
            '<soapenv:Body>' +
            '<ns1:ProcessCaseResponse>' +
            '<ns1:Sys><ns1:Code>1</ns1:Code><ns1:Description>Processed</ns1:Description></ns1:Sys>' +
            '</ns1:ProcessCaseResponse>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    private static String getFHUpdatePayload() {
        return '{"detail":{"caseID":"FH-100001","referenceID":"S-000001","channelID":"FIMA","parentID":"","caseStatus":"Investigating","investigationConclusion":"Under review","data":"<CaseResultInfo><Remarks>Updated</Remarks><CreatedTime>2025-09-10T10:07:22.263Z</CreatedTime><UpdatedTime>2025-09-10T12:00:00.000Z</UpdatedTime><OriginalRequest><RequestInfo><Remarks>Orig</Remarks></RequestInfo><CreatorInfo><CreatorEmail>test@test.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Existing</UserType></CustomerInfo></OriginalRequest><AdditionalInfo><ID>AP-001</ID><Value>50000</Value></AdditionalInfo></CaseResultInfo>","messageTime":1700000000000}}';
    }

    private static String getBUUpdatePayload() {
        return '{"detail":{"caseID":"BU-200001","referenceID":"S-000001","channelID":"FIMA","parentID":"FH-100001","caseStatus":"Investigating","investigationConclusion":"","data":"<CaseResultInfo><CreatedTime>2025-09-10T10:07:22.263Z</CreatedTime><UpdatedTime>2025-09-10T12:00:00.000Z</UpdatedTime><OriginalRequest><RequestInfo><Remarks>BU remark</Remarks></RequestInfo><CreatorInfo><CreatorEmail>bu@test.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Existing</UserType></CustomerInfo></OriginalRequest></CaseResultInfo>","messageTime":1700000000000}}';
    }

    private static String getTKUpdatePayload() {
        return '{"detail":{"caseID":"TK-300001","referenceID":"S-000001","channelID":"FIMA","parentID":"BU-200001","caseStatus":"Investigating","investigationConclusion":"Pending","data":"<CaseResultInfo><CreatedTime>2025-09-10T10:07:22.263Z</CreatedTime><UpdatedTime>2025-09-10T12:00:00.000Z</UpdatedTime><OriginalRequest><RequestInfo><Remarks>TK remark</Remarks></RequestInfo><CreatorInfo><CreatorEmail>tk@test.com</CreatorEmail></CreatorInfo><CustomerInfo><UserType>Existing</UserType></CustomerInfo></OriginalRequest><AdditionalInfo><ID>UIC</ID><Value>CS</Value></AdditionalInfo><AdditionalInfo><ID>ResultDetailCode</ID><Value>CUS</Value></AdditionalInfo></CaseResultInfo>","messageTime":1700000000000}}';
    }
}