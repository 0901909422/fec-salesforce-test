@IsTest
private class FEC_CreateCSCaseRestService_Test {
    private static final String SAMPLE_REQUEST =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<CreateCSCaseRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys>' +
        '<Channel>Inbound</Channel>' +
        '<TransactionID>TXN12345678901234567890123456789012</TransactionID>' +
        '<DateTime>2026-05-25T06:52:33Z</DateTime>' +
        '</Sys>' +
        '<CustomerInfo>' +
        '<Name>Nguyen Van A</Name>' +
        '<PhoneNumber>0901234567</PhoneNumber>' +
        '<UserType>Existing</UserType>' +
        '<NationalID>123456789</NationalID>' +
        '<ContractOrAccountNumber>1234567890123456</ContractOrAccountNumber>' +
        '<EmailAddress>test@fecredit.com.vn</EmailAddress>' +
        '</CustomerInfo>' +
        '<RequestInfo>' +
        '<CaseType>Complaint</CaseType>' +
        '<RequestType>REQ</RequestType>' +
        '<ProductType>CARD</ProductType>' +
        '<Category>Request</Category>' +
        '<SubCategory>SubCat</SubCategory>' +
        '<SubCode>SubCode</SubCode>' +
        '<Remarks>Test Remarks</Remarks>' +
        '</RequestInfo>' +
        '<CreatorInfo>' +
        '<CreatorEmail>' + UserInfo.getUserEmail() + '</CreatorEmail>' +
        '</CreatorInfo>' +
        '</CreateCSCaseRequest>' +
        '</soap:Body>' +
        '</soap:Envelope>';

    private static final String SAMPLE_REQUEST_MULTI_ADDITIONAL_INFO =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soap:Body>' +
        '<CreateCSCaseRequest xmlns="urn:PegaRULES:SOAP:MyCase:Services">' +
        '<Sys><Channel>Inbound</Channel><TransactionID>TXN-MULTI-ADD-001</TransactionID><DateTime>2026-05-25T06:52:33Z</DateTime></Sys>' +
        '<CustomerInfo><Name>Nguyen Van A</Name><PhoneNumber>0901234567</PhoneNumber><UserType>Existing</UserType><NationalID>123456789</NationalID><ContractOrAccountNumber>1234567890123456</ContractOrAccountNumber><EmailAddress>test@fecredit.com.vn</EmailAddress></CustomerInfo>' +
        '<RequestInfo>' +
        '<CaseType>Complaint</CaseType><RequestType>REQ</RequestType><ProductType>CARD</ProductType><Category>Request</Category><SubCategory>SubCat</SubCategory><SubCode>SubCode</SubCode><Remarks>Test Remarks</Remarks>' +
        '<AdditionalInfo><ID>FieldA</ID><Value>ValueA</Value><ID>FieldB</ID><Value>ValueB</Value></AdditionalInfo>' +
        '</RequestInfo>' +
        '<CreatorInfo><CreatorEmail>' + UserInfo.getUserEmail() + '</CreatorEmail></CreatorInfo>' +
        '</CreateCSCaseRequest>' +
        '</soap:Body>' +
        '</soap:Envelope>';

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
        insert new FEC_Channel__c(
            Name = 'Inbound',
            FEC_Channel_ID__c = FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
            FEC_Channel_Vietnamese_name__c = 'Inbound',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = true
        );

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

    @IsTest
    static void testParseCreateCSCaseRequest_mapsFields() {
        FEC_CreateCSCaseService.CaseRequestType req =
            FEC_MyCaseSoapXml.parseCreateCSCaseRequest(SAMPLE_REQUEST);

        System.assertNotEquals(null, req.Sys);
        System.assertEquals('Inbound', req.Sys.Channel);
        System.assertEquals(
            'TXN12345678901234567890123456789012',
            req.Sys.TransactionID
        );
        System.assertNotEquals(null, req.Sys.DateTime_x);
        System.assertEquals('Nguyen Van A', req.CustomerInfo.Name);
        System.assertEquals('Complaint', req.RequestInfo.CaseType);
        System.assertEquals(UserInfo.getUserEmail(), req.CreatorInfo.CreatorEmail);
    }

    @IsTest
    static void testBuildCreateCSCaseSoapResponse_structure() {
        FEC_CreateCSCaseService.CreateCSCaseResponse resp =
            new FEC_CreateCSCaseService.CreateCSCaseResponse();
        resp.Sys = new FEC_CreateCSCaseService.SysType2();
        resp.Sys.TransactionID = 'TXN1';
        resp.Sys.DateTime_x = '2026-05-25T06:52:33Z';
        resp.Sys.Code = '1';
        resp.Sys.Description = 'OK';
        resp.CaseID = 'S-123';

        String xml = FEC_MyCaseSoapXml.buildCreateCSCaseSoapResponse(resp);

        System.assert(xml.contains('CreateCSCaseResponse'));
        System.assert(xml.contains('<CaseID>S-123</CaseID>'));
        System.assert(xml.contains('<Code>1</Code>'));
    }

    @IsTest
    static void testParseCreateCSCaseRequest_multipleAdditionalInfoPairsInOneNode() {
        FEC_CreateCSCaseService.CaseRequestType req =
            FEC_MyCaseSoapXml.parseCreateCSCaseRequest(SAMPLE_REQUEST_MULTI_ADDITIONAL_INFO);

        System.assertNotEquals(null, req.RequestInfo);
        System.assertNotEquals(null, req.RequestInfo.AdditionalInfo);
        System.assertEquals(2, req.RequestInfo.AdditionalInfo.size());
        System.assertEquals('FieldA', req.RequestInfo.AdditionalInfo[0].ID);
        System.assertEquals('ValueA', req.RequestInfo.AdditionalInfo[0].Value);
        System.assertEquals('FieldB', req.RequestInfo.AdditionalInfo[1].ID);
        System.assertEquals('ValueB', req.RequestInfo.AdditionalInfo[1].Value);
    }

    @IsTest
    static void testRestPost_success() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CreateCSCase';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(SAMPLE_REQUEST);
        RestContext.request = req;
        RestContext.response = res;

        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());
        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('CreateCSCaseResponse'));
        System.assert(body.contains('<Code>1</Code>'), body);

        //Thangtv: Interaction/Customer Case = External/Other; Sys.Channel → FEC_Other_Subchannel__c
        List<Case> cases = [
            SELECT
                FEC_Channel__c,
                FEC_Case_Channel__c,
                FEC_Sub_Channel__c,
                FEC_Interaction_Subchannel__c,
                FEC_Other_Subchannel__c,
                FEC_Is_Submited__c,
                FEC_Interaction_View_Mode__c,
                RecordType.DeveloperName
            FROM Case
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        for (Case c : cases) {
            System.assertEquals(true, c.FEC_Is_Submited__c);
            System.assertEquals(
                FEC_ConstantCommon.INTERACTION_REVIEW_MODE,
                c.FEC_Interaction_View_Mode__c
            );
            System.assertEquals(FEC_ConstantCommon.CHANNEL_EXTERNAL, c.FEC_Channel__c);
            System.assertEquals(
                FEC_ConstantCommon.CHANNEL_INBOUND_NAME,
                c.FEC_Other_Subchannel__c
            );

            if (
                c.RecordType.DeveloperName ==
                FEC_ConstantCommon.CASE_INTERACTION_RECORD_TYPE_DEV_NAME
            ) {
                System.assertEquals(
                    FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME,
                    c.FEC_Interaction_Subchannel__c
                );
            } else if (
                c.RecordType.DeveloperName ==
                FEC_ConstantCommon.CASE_CUSTOMER_RECORD_TYPE_DEV_NAME
            ) {
                System.assertEquals(
                    FEC_ConstantCommon.CHANNEL_EXTERNAL,
                    c.FEC_Case_Channel__c
                );
                System.assertEquals(
                    FEC_ConstantCommon.CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME,
                    c.FEC_Sub_Channel__c
                );
            }
        }
    }

    @IsTest
    static void testRestPost_emptyBody_returnsBadRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CreateCSCase';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('CreateCSCaseResponse')
        );
    }

    @IsTest
    static void testRestPost_channelNotAllowed_returnsError() {
        insert new FEC_Channel__c(
            Name = 'Vtiger',
            FEC_Channel_ID__c = 'Vtiger',
            FEC_Channel_Vietnamese_name__c = 'Vtiger',
            FEC_Channel_Status__c = true,
            FEC_Get_Nature_Of_Case__c = false
        );

        String vtigerRequest = SAMPLE_REQUEST.replace(
            '<Channel>Inbound</Channel>',
            '<Channel>Vtiger</Channel>'
        );

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CreateCSCase';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(vtigerRequest);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(
            res.responseBody.toString().contains(
                FEC_ConstantCommon.MY_CASE_CHANNEL_CREATE_CASE_NOT_ALLOWED_MSG
            )
        );
    }

    @IsTest
    static void testRestPost_invalidXml_returnsErrorEnvelope() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CreateCSCase';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body></soap:Body>' +
            '</soap:Envelope>'
        );
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        System.assertEquals(
            FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST,
            res.statusCode
        );
        System.assert(
            res.responseBody.toString().contains('CreateCSCaseResponse')
        );
    }
}