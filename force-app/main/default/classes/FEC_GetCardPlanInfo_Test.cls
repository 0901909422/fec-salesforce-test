@IsTest
private class FEC_GetCardPlanInfo_Test {

    // XML mẫu giả lập phản hồi SOAP của dịch vụ
    private static final String MOCK_SOAP_RESPONSE = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <cif:GetCardPlanInfoResponse xmlns:cif="http://fecredit.com.vn/CIF_CardInfo">' +
        '      <Sys>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2026-05-22 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <CardPlanInfo>' +
        '        <CardPlans>' +
        '          <CardPlan>' +
        '            <RecordNumber>REC001</RecordNumber>' +
        '            <PlanNumber>PLAN001</PlanNumber>' +
        '            <PlanCurrentBalance>500000</PlanCurrentBalance>' +
        '          </CardPlan>' +
        '        </CardPlans>' +
        '      </CardPlanInfo>' +
        '    </cif:GetCardPlanInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testGetCardPlanInfo_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_SOAP_RESPONSE));
        
        Test.startTest();
        FEC_GetCardPlanInfo.CardPlanResult res = FEC_GetCardPlanInfo.getCardPlanInfo('ACC123456');
        Test.stopTest();
        
        System.assertEquals('TXN123', res.transId);
        System.assertEquals(1, res.plans.size());
        System.assertEquals('PLAN001', res.plans[0].planNumber);
        System.assertEquals(500000, res.plans[0].currentBalance);
    }

    @IsTest
    static void testValidateRequest_EmptyAccount() {
        Test.startTest();
        try {
            FEC_GetCardPlanInfo.getCardPlanInfo('');
            System.assert(false, 'Phải ném AuraHandledException khi AccountNumber rỗng.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetCardPlanInfo_ApiError() {
        // Mock lỗi response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));
        
        Test.startTest();
        try {
            FEC_GetCardPlanInfo.getCardPlanInfo('ACC123');
            System.assert(false, 'Phải ném AuraHandledException khi status code != 200.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code; String body;
        MockHttpResponseGenerator(Integer code, String body) { this.code = code; this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}