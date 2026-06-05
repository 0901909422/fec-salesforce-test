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

    private static void setRestContext(String body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/MyCase/v1/CreateCSCase';
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = res;
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

    @IsTest
    static void testRestPost_success() {
        setRestContext(SAMPLE_REQUEST);
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        RestResponse res = RestContext.response;
        String body = res.responseBody.toString();
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_OK, res.statusCode);
        System.assert(body.contains('CreateCSCaseResponse'), body);
        System.assert(body.contains('<Code>1</Code>'), body);
    }

    @IsTest
    static void testRestPost_nullBody() {
        setRestContext(null);

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, res.statusCode);
        System.assert(res.responseBody.toString().contains('CreateCSCaseResponse'));
    }

    @IsTest
    static void testRestPost_emptyBody() {
        setRestContext('   ');

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, res.statusCode);
        System.assert(res.responseBody.toString().contains('CreateCSCaseResponse'));
    }

    @IsTest
    static void testRestPost_missingCreateCSCaseRequest_returnsBadRequest() {
        String invalidRequest =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><OtherRequest/></soap:Body></soap:Envelope>';
        setRestContext(invalidRequest);

        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST, res.statusCode);
        System.assert(res.responseBody.toString().contains('CreateCSCaseResponse'));
    }

    @IsTest
    static void testRestPost_setsContentTypeHeader() {
        setRestContext(SAMPLE_REQUEST);
        Test.setMock(HttpCalloutMock.class, new MockGetCustomerListCallout());

        FEC_CaseTriggerHandler.isExecuting = true;
        Test.startTest();
        FEC_CreateCSCaseRestService.doPost();
        Test.stopTest();
        FEC_CaseTriggerHandler.isExecuting = false;

        RestResponse res = RestContext.response;
        System.assertNotEquals(null, res.headers.get(FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE));
    }
}
