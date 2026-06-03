@IsTest
private class FEC_GetMRCInfo_Test {

    // XML mẫu giả lập phản hồi SOAP
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetMRCInfoResponse>' +
        '      <Sys><Code>1</Code><Description>Success</Description></Sys>' +
        '      <ContractNumber>CON123</ContractNumber>' +
        '      <MRCZone>ZoneA</MRCZone>' +
        '      <Status>Active</Status>' +
        '      <ModifiedDate>2026-05-25</ModifiedDate>' +
        '    </GetMRCInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Subject = 'FEC_GetMRCInfo_Test',
                FEC_Contract_Number__c = 'CON123',
                FEC_ID_Search__c = 'MRC-' + String.valueOf(System.currentTimeMillis())
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c history = new FEC_Customer_History__c(
            Name = 'Test History',
            FEC_Case__c = c.Id
        );
        insert history;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = history.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetMRCInfo_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));
        
        FEC_GetMRCInfo.MRCInfoRequest req = new FEC_GetMRCInfo.MRCInfoRequest();
        req.ContractNumber = 'CON123';

        Test.startTest();
        FEC_GetMRCInfo.MRCInfoResult res = FEC_GetMRCInfo.getMRCInfo(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('ZoneA', res.data.mrcZone);
    }

    @IsTest
    static void testUpdateMRCRecord_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));
        
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_Customer_History__c updatedHist = FEC_GetMRCInfo.updateMRCRecord(c.Id);
        Test.stopTest();

        // Kiểm tra dữ liệu được update từ API vào History object
        System.assertEquals('ZoneA', updatedHist.FEC_MRC_Zone__c);
        System.assertEquals('Active', updatedHist.FEC_MRC_Status__c);
        System.assertEquals(Date.valueOf('2026-05-25'), updatedHist.FEC_Modified_Date__c);
    }

    @IsTest
    static void testValidation_Errors() {
        // Test trường hợp Case Id không tồn tại
        Test.startTest();
        try {
            FEC_GetMRCInfo.updateMRCRecord('000000000000000000');
            System.assert(false, 'Phải báo lỗi Case Id không tồn tại.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer statusCode;
        String responseBody;
        
        MockHttpResponseGenerator(Integer statusCode, String responseBody) { 
            this.statusCode = statusCode; 
            this.responseBody = responseBody; 
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}