@IsTest
private class FEC_GetCSCaseStatusRestService_Test {
    private static final String VALID_CHANNEL = FEC_ConstantCommon.CHANNEL_INBOUND_NAME;
    private static final String TEST_ACCOUNT =
        FEC_UnitTestMyCaseChannelUtil.VALID_ACCOUNT_16;

    private static Id customerCaseRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDev =
            Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (byDev.containsKey(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME)) {
            return byDev.get(FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME).getRecordTypeId();
        }
        return null;
    }

    private static String sampleGetStatusRequest() {
        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<GetCSCaseStatusRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
            '<Sys>' +
            '<Channel>Inbound</Channel>' +
            '<TransactionID>TXN-GET-STATUS-2026-99999999999</TransactionID>' +
            '<DateTime>2026-05-25T06:52:33.616Z</DateTime>' +
            '</Sys>' +
            '<CaseRequestInfo>' +
            '<ContractOrAccountInfos>' +
            '<ContractOrAccountNumber>' + TEST_ACCOUNT + '</ContractOrAccountNumber>' +
            '<ProductType>CreditCard</ProductType>' +
            '</ContractOrAccountInfos>' +
            '<UserType>EXISTING</UserType>' +
            '<CaseID>CASE123</CaseID>' +
            '<IncludeFinishedRequest>true</IncludeFinishedRequest>' +
            '<NationalID>123456789012</NationalID>' +
            '</CaseRequestInfo>' +
            '</GetCSCaseStatusRequest>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    @TestSetup
    static void setupData() {
        FEC_UnitTestMyCaseChannelUtil.ensureInboundMyCaseChannel();

        FEC_Business_Process__c proc = new FEC_Business_Process__c(
            Name = 'Fraud Process',
            FEC_Code__c = 'FRAUDPROC',
            FEC_Active__c = true
        );
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'CreditCard',
            FEC_Code__c = 'CREDITCARD',
            FEC_Name_VN__c = 'CreditCard',
            FEC_Active__c = true
        );
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Request',
            FEC_Code__c = 'Request',
            FEC_Active__c = true
        );
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SubCat',
            FEC_Code__c = 'SubCat',
            FEC_Active__c = true
        );
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SubCode',
            FEC_Code__c = 'SubCode',
            FEC_Active__c = true
        );
        insert new List<SObject>{ proc, pt, cat, subCat, subCode };

        FEC_CaseTriggerHandler.isExecuting = true;
        Case statusCase;
        try {
            statusCase = new Case(
                Subject = 'REST Get Status Test',
                Status = 'New',
                FEC_ID_Search__c = 'CASE123',
                FEC_Customer_Name__c = 'Test Customer',
                FEC_Customer_Type__c = FEC_ConstantCommon.CASE_EXISTING_CUSTOMER,
                FEC_Business_Process__c = proc.Id,
                FEC_Product_Type__c = pt.Id,
                FEC_Category__c = cat.Id,
                FEC_SubCategory__c = subCat.Id,
                FEC_SubCode__c = subCode.Id
            );
            Id rtId = customerCaseRecordTypeId();
            if (rtId != null) {
                statusCase.RecordTypeId = rtId;
            }
            insert statusCase;

            FEC_Customer_History__c accountHist = new FEC_Customer_History__c(
                Name = TEST_ACCOUNT,
                FEC_Case__c = statusCase.Id,
                FEC_Account_Number__c = TEST_ACCOUNT,
                FEC_Contract_Number__c = TEST_ACCOUNT,
                FEC_Email__c = 'customer@example.com',
                FEC_National_ID_Passport_ID__c = '123456789012'
            );
            insert accountHist;

            update new Case(
                Id = statusCase.Id,
                FEC_Account_or_Contract__c = accountHist.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testParseGetCSCaseStatusRequest_mapsFields() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusRequest parsed =
            FEC_MyCaseSoapXml.parseGetCSCaseStatusRequest(sampleGetStatusRequest());

        System.assertNotEquals(null, parsed.Sys);
        System.assertEquals(VALID_CHANNEL, parsed.Sys.Channel);
        System.assertEquals('TXN-GET-STATUS-2026-99999999999', parsed.Sys.TransactionID);
        System.assertEquals('2026-05-25T06:52:33.616Z', parsed.Sys.DateTime_x);

        System.assertNotEquals(null, parsed.CaseRequestInfo);
        System.assertEquals('CASE123', parsed.CaseRequestInfo.CaseID);
        System.assertEquals('123456789012', parsed.CaseRequestInfo.NationalID);
        System.assertEquals(
            FEC_ConstantCommon.REQUEST_EXISTING_USER_TYPE,
            parsed.CaseRequestInfo.UserType
        );
        System.assertEquals(true, parsed.CaseRequestInfo.IncludeFinishedRequest);
        System.assertEquals(
            TEST_ACCOUNT,
            parsed.CaseRequestInfo.ContractOrAccountInfos.ContractOrAccountNumber
        );
        System.assertEquals(
            'CreditCard',
            parsed.CaseRequestInfo.ContractOrAccountInfos.ProductType
        );
    }

    @IsTest
    static void testBuildGetCSCaseStatusSoapResponse_structure() {
        FEC_GetCSCaseStatusService.GetCSCaseStatusResponse resp =
            new FEC_GetCSCaseStatusService.GetCSCaseStatusResponse();
        resp.Sys = new FEC_GetCSCaseStatusService.SysType2();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = String.valueOf(System.now());
        resp.Sys.Code = 1;
        resp.Sys.Description = 'Success';

        resp.CaseResultInfos = new List<FEC_GetCSCaseStatusService.CaseResultInfoType>();
        FEC_GetCSCaseStatusService.CaseResultInfoType caseResult =
            new FEC_GetCSCaseStatusService.CaseResultInfoType();
        caseResult.CaseID = '500xx0000000001';
        caseResult.CaseStatus = 'Open';
        caseResult.Remarks = 'Test remarks';

        caseResult.OriginalRequest = new FEC_GetCSCaseStatusService.OriginalRequestType();
        caseResult.OriginalRequest.Sys = new FEC_GetCSCaseStatusService.SysType();
        caseResult.OriginalRequest.Sys.Channel = VALID_CHANNEL;
        caseResult.OriginalRequest.CustomerInfo =
            new FEC_GetCSCaseStatusService.CustomerInfoType();
        caseResult.OriginalRequest.CustomerInfo.Name = 'Customer A';
        caseResult.OriginalRequest.RequestInfo =
            new FEC_GetCSCaseStatusService.RequestInfoType();
        caseResult.OriginalRequest.RequestInfo.CaseType = 'Complaint';
        caseResult.OriginalRequest.CreatorInfo =
            new FEC_GetCSCaseStatusService.CreatorInfoType();
        caseResult.OriginalRequest.CreatorInfo.CreatorEmail = 'user@example.com';
        resp.CaseResultInfos.add(caseResult);

        String xml = FEC_MyCaseSoapXml.buildGetCSCaseStatusSoapResponse(resp);

        System.assert(xml.contains('GetCSCaseStatusResponse'));
        System.assert(xml.contains('<CaseResultInfo>'));
        System.assert(xml.contains('<OriginalRequest>'));
        System.assert(xml.contains('<Code>1</Code>'));
        System.assert(xml.contains('<CaseID>500xx0000000001</CaseID>'));
        System.assert(xml.contains('<CreatorEmail>user@example.com</CreatorEmail>'));
    }

    @IsTest
    static void testRestPost_getStatusSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSCaseStatus';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(sampleGetStatusRequest());
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSCaseStatusRestService.doPost();
        Test.stopTest();

        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('GetCSCaseStatusResponse'));
        System.assert(body.contains('<Code>1</Code>'), body);
        System.assert(body.contains('<CaseResultInfo>'));
        System.assert(body.contains('<OriginalRequest>'));
    }

    @IsTest
    static void testBuildGetCSCaseStatusErrorSoapResponse() {
        String xml = FEC_MyCaseSoapXml.buildGetCSCaseStatusErrorSoapResponse(
            'TXN-ERR',
            '2',
            'Case not found'
        );

        System.assert(xml.contains('GetCSCaseStatusResponse'));
        System.assert(xml.contains('<Code>2</Code>'));
        System.assert(xml.contains('Case not found'));
    }

    @IsTest
    static void testRestPost_emptyBody_returnsBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSCaseStatus';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSCaseStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSCaseStatusResponse')
        );
    }

    @IsTest
    static void testRestPost_missingRequestElement_returnsErrorEnvelope() {
        String invalidEnvelope =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><UnknownRequest /></soap:Body></soap:Envelope>';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/GetCSCaseStatus';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(invalidEnvelope);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_GetCSCaseStatusRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('GetCSCaseStatusResponse')
        );
    }
}