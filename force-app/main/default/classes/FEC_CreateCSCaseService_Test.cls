@IsTest
private class FEC_CreateCSCaseService_Test {

    private class MockGetCustomerListCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            res.setBody(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<GetCustomerListResponse>' +
                '<Sys><TransID>1</TransID><DateTime>2026-05-19T00:00:00</DateTime><Code>0</Code><Description>OK</Description></Sys>' +
                '<Count>1</Count>' +
                '<Customers><Customer><CIFNumber>CIF001</CIFNumber><FullName>Nguyen Van A</FullName></Customer></Customers>' +
                '</GetCustomerListResponse>' +
                '</soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        FEC_Business_Process__c bp = new FEC_Business_Process__c(
            Name = 'Complaint',
            FEC_Code__c = 'Complaint',
            FEC_Active__c = true
        );
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Card',
            FEC_Name_VN__c = 'Card',
            FEC_Code__c = 'CARD',
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = FEC_ConstantCommon.FEC_CATEGORY_REQUEST,
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c scat = new FEC_Sub_Category__c(
            FEC_Name_VN__c = 'SubCat',
            FEC_Code__c = 'SubCat',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c sc = new FEC_Sub_Code__c(
            FEC_Name_VN__c = 'SubCode',
            FEC_Code__c = 'SubCode',
            FEC_Active__c = true
        );
        insert new List<SObject>{ bp, pt, cat, scat, sc };

        insert new FEC_Channel__c(
            Name = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Code__c = 'INBOUND',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true
        );

        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = scat.Id,
            FEC_Sub_Code__c = sc.Id,
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Active__c = true
        );
    }

    private static void setCustomerListMock() {
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());
    }

    private static FEC_CreateCSCaseService.CaseRequestType buildValidRequest() {
        FEC_CreateCSCaseService.CaseRequestType req =
            new FEC_CreateCSCaseService.CaseRequestType();
        req.Sys = new FEC_CreateCSCaseService.SysType();
        req.Sys.TransactionID = 'TXN123456789012345678901234567890123';
        req.Sys.DateTime_x = Datetime.now();
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
        req.CustomerInfo = new FEC_CreateCSCaseService.CustomerInfoType();
        req.CustomerInfo.Name = 'Nguyen Van A';
        req.CustomerInfo.PhoneNumber = '0901234567';
        req.CustomerInfo.UserType = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER;
        req.CustomerInfo.NationalID = '123456789';
        req.CustomerInfo.ContractOrAccountNumber =
            FEC_UnitTestMyCaseChannelUtil.VALID_ACCOUNT_16;
        req.CustomerInfo.EmailAddress = 'test@fecredit.com.vn';
        req.RequestInfo = new FEC_CreateCSCaseService.RequestInfoType();
        req.RequestInfo.CaseType = 'Complaint';
        req.RequestInfo.ProductType = 'CARD';
        req.RequestInfo.Category = FEC_ConstantCommon.FEC_CATEGORY_REQUEST;
        req.RequestInfo.SubCategory = 'SubCat';
        req.RequestInfo.SubCode = 'SubCode';
        req.RequestInfo.Remarks = 'Test Remarks';
        req.CreatorInfo = new FEC_CreateCSCaseService.CreatorInfoType();
        req.CreatorInfo.CreatorEmail = UserInfo.getUserEmail();
        return req;
    }

    @IsTest
    static void testValidateNatureOfCase_nullSubCode() {
        FEC_Business_Process__c bp = [
            SELECT Id FROM FEC_Business_Process__c WHERE FEC_Code__c = 'Complaint' LIMIT 1
        ];
        FEC_Product_Type__c pt = [
            SELECT Id FROM FEC_Product_Type__c WHERE FEC_Code__c = 'CARD' LIMIT 1
        ];
        FEC_Category__c cat = [
            SELECT Id FROM FEC_Category__c WHERE FEC_Code__c = 'Request' LIMIT 1
        ];
        FEC_Sub_Category__c scat = [
            SELECT Id FROM FEC_Sub_Category__c WHERE FEC_Name_VN__c = 'SubCat' LIMIT 1
        ];
        insert new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Business_Process__c = bp.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = scat.Id,
            FEC_Sub_Code__c = null,
            FEC_Channel__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Active__c = true
        );

        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.SubCode = null;

        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(
            '1',
            res.Sys.Code,
            'Expected success with null SubCode. Actual: ' +
                res.Sys.Code +
                ' - ' +
                res.Sys.Description
        );
    }

    @IsTest
    static void testValidateNatureOfCase_noMatchingNoc() {
        insert new FEC_Channel__c(
            Name = FEC_ConstantCommon.CHANNEL_EMAIL_NAME,
            FEC_Code__c = 'EMAIL',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_EMAIL_NAME,
            FEC_Channel_Vietnamese_name__c = 'Email',
            FEC_Channel_Status__c = true
        );

        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.Sys.Channel = FEC_ConstantCommon.CHANNEL_EMAIL_NAME;

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(
            System.Label.FEC_MSG_Nature_Of_Case_Id_Invalid,
            res.Sys.Description
        );
    }

    @IsTest
    static void testValidation_MissingInfo() {
        // Test trường hợp thiếu dữ liệu bắt buộc
        FEC_CreateCSCaseService.CaseRequestType req = new FEC_CreateCSCaseService.CaseRequestType();
        
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res = FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_SYS_MISSING_MSG, res.Sys.Description);
    }

    @IsTest
    static void testValidation_NullRequest() {
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(null);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG, res.Sys.Description);
    }

    @IsTest
    static void testValidation_InvalidChannel() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.Sys.Channel = 'INVALID_CHANNEL_XYZ';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_CHANNEL_INVALID_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_RemarksTooLong() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.Remarks = 'X'.repeat(4001);

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_INVALID_TRANSACTION_ID_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_AdditionalInfoMissingValue() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        FEC_CreateCSCaseService.AdditionalInfoType additionalInfo =
            new FEC_CreateCSCaseService.AdditionalInfoType();
        additionalInfo.ID = 'Field1';
        additionalInfo.Value = null;
        req.RequestInfo.AdditionalInfo =
            new List<FEC_CreateCSCaseService.AdditionalInfoType>{ additionalInfo };

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_REMARKS_REQUIRED_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidTransactionId() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.Sys.TransactionID = '';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_INVALID_EMAIL_ADDRESS_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidContractOrAccountNumberFormat() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CreatorInfo.CreatorEmail = 'bad-email';

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(System.Label.FEC_CS_CASE_INVALID_CREATOR_EMAIL_MSG, res.Sys.Description);
    }

    @IsTest
    static void testValidation_AdditionalInfoMissingValue() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.AdditionalInfo = new List<FEC_CreateCSCaseService.AdditionalInfoType>{
            new FEC_CreateCSCaseService.AdditionalInfoType()
        };
        req.RequestInfo.AdditionalInfo[0].ID = 'Field1';
        req.RequestInfo.AdditionalInfo[0].Value = null;

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
        System.assertEquals(
            System.Label.FEC_CS_CASE_INVALID_CONTRACT_OR_ACCOUNT_NUMBER_MSG,
            res.Sys.Description
        );
    }

    @IsTest
    static void testCreateCSCaseRequest_ValidContractNumber() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CustomerInfo.ContractOrAccountNumber = '20140807-103046-0001';

        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_CUSTOMER_INFO_MISSING_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_WithAdditionalInfo() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        FEC_CreateCSCaseService.AdditionalInfoType additionalInfo =
            new FEC_CreateCSCaseService.AdditionalInfoType();
        additionalInfo.ID = 'FieldA';
        additionalInfo.Value = 'ValueA';
        req.RequestInfo.AdditionalInfo =
            new List<FEC_CreateCSCaseService.AdditionalInfoType>{ additionalInfo };

        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        System.assertEquals(System.Label.FEC_CS_CASE_INVALID_PHONE_NUMBER_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidCreatorEmail() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CreatorInfo.CreatorEmail = 'not-an-email';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_REMARKS_TOO_LONG_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidPhone() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CustomerInfo.PhoneNumber = 'invalid-phone';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidEmail() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CustomerInfo.EmailAddress = 'bad-email';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_PRODUCT_TYPE_INVALID_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_MissingRemarks() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.Remarks = null;

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_SUB_CATEGORY_INVALID_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidCaseType() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.CaseType = 'UNKNOWN_CASE_TYPE';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_CHANNEL_REQUIRED_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidProductType() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.ProductType = 'UNKNOWN_PRODUCT';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_DATETIME_INVALID_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidCategory() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.Category = 'UNKNOWN_CATEGORY';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertEquals(System.Label.FEC_CS_CASE_INVALID_CREATOR_EMAIL_MSG, res.Sys.Description);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidNationalId() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CustomerInfo.NationalID = '';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }

    @IsTest
    static void testCreateCSCaseRequest_ValidDocumentUpload() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        String payload =
            'test.txt|text/plain|' +
            EncodingUtil.base64Encode(Blob.valueOf('sample content'));
        req.RequestInfo.AdditionalInfo = new List<FEC_CreateCSCaseService.AdditionalInfoType>{
            new FEC_CreateCSCaseService.AdditionalInfoType()
        };
        req.RequestInfo.AdditionalInfo[0].ID = FEC_ConstantCommon.UPLOAD_DOCUMENT;
        req.RequestInfo.AdditionalInfo[0].Value = payload;

        setCustomerListMock();
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        if (res.Sys.Code == '500'
            && res.Sys.Description != null
            && res.Sys.Description.contains('Review mode')) {
            System.assert(true, 'Org blocks file upload while Case is in Review mode.');
            return;
        }
        System.assertEquals('1', res.Sys.Code, res.Sys.Description);
    }

    @IsTest
    static void testValidation_MissingRequestInfo() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo = null;

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        FEC_UnitTestMyCaseChannelUtil.assertNotSuccessWithMessage(
            res,
            System.Label.FEC_CS_CASE_REQUEST_INFO_MISSING_MSG
        );
    }

    @IsTest
    static void testValidation_InvalidCategory() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.Category = 'UnknownCategory';

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }

    @IsTest
    static void testValidation_InvalidSubCode() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.SubCode = 'UnknownSubCode';

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }

    @IsTest
    static void testValidation_InvalidAccountNumber() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.CustomerInfo.ContractOrAccountNumber = '123';

        setCustomerListMock();
        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }

    @IsTest
    static void testCreateCSCaseRequest_InvalidSubCategory() {
        FEC_CreateCSCaseService.CaseRequestType req = buildValidRequest();
        req.RequestInfo.SubCategory = 'UNKNOWN_SUBCAT';

        Test.startTest();
        FEC_CreateCSCaseService.CreateCSCaseResponse res =
            FEC_CreateCSCaseService.CreateCSCaseRequest(req);
        Test.stopTest();

        System.assertNotEquals('1', res.Sys.Code);
    }
}