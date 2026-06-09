@IsTest
private class FEC_GetIPPDetailsCallout_Test {

    // =========================================================================
    // MOCK XML DATA
    // =========================================================================
    
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '   <soapenv:Body>' +
        '      <GetIPPDetailsResponse>' +
        '         <SysResponse>' +
        '            <Status>SUCCESS</Status>' +
        '            <Description>Operation completed successfully</Description>' +
        '            <TransID>TXN12345</TransID>' +
        '            <DateTime>2026-05-25T10:00:00Z</DateTime>' +
        '         </SysResponse>' +
        '         <AccountNumber>1234567890</AccountNumber>' +
        '         <IPPTerm>12</IPPTerm>' +
        '         <PrincipalAmount>10000</PrincipalAmount>' +
        '         <InstallmentAmount>1000</InstallmentAmount>' +
        '         <ConversionFee>50</ConversionFee>' +
        '         <EMI>100</EMI>' +
        '         <PlanNumber>PLAN123</PlanNumber>' +
        '         <InterestRate>1.5</InterestRate>' +
        '         <Description>IPP Detail Data</Description>' +
        '      </GetIPPDetailsResponse>' +
        '   </soapenv:Body>' +
        '</soapenv:Envelope>';

    // =========================================================================
    // TEST SETUP
    // =========================================================================
    
    @TestSetup
    static void setupData() {
        // Thiết lập Custom Setting ở môi trường Non-Production để phủ nhánh Hardcode trong code chính
        FEC_API_Setting__c apiSetting = new FEC_API_Setting__c(
            FEC_Enviroment__c = 'Non-Production', // Giả định giá trị ENVIROMENT_NON_PRODUCTION
            FEC_Call_Mock__c = false,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
        insert apiSetting;
    }

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testGetIPPDetails_Success() {
        // Thiết lập HTTP Callout Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        // Chuẩn bị DTO Request hợp lệ
        FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
        req.accountNumber = '0001500060000003944';
        req.effectiveDate = '2026-05-01';
        req.amount = 5000000;
        req.postingDate = '2026-05-01';
        req.planNumber = '97102';
        req.ippTerm = 9;
        req.referenceNumber = 'REF001';

        Test.startTest();
        FEC_GetIPPDetailsCallout.IPPDetailsResponse res = FEC_GetIPPDetailsCallout.getIPPDetails(req);
        Test.stopTest();

        // Xác thực kết quả Parsing XML
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals('SUCCESS', res.status, 'Status phải là SUCCESS.');
        System.assertEquals('1234567890', res.accountNumber);
        System.assertEquals(10000, res.principalAmount);
        System.assertEquals(1.5, res.interestRate);
        System.assertEquals('PLAN123', res.planNumber);
    }

    @IsTest
    static void testGetIPPDetails_MainValidationFail() {
        // Gọi main method nhưng truyền Request bị thiếu field bắt buộc (gây ra lỗi validation)
        FEC_GetIPPDetailsCallout.IPPRequest badReq = new FEC_GetIPPDetailsCallout.IPPRequest();
        // Cố tình không truyền gì để trigger validateRequest = false
        
        Test.startTest();
        FEC_GetIPPDetailsCallout.IPPDetailsResponse res = FEC_GetIPPDetailsCallout.getIPPDetails(badReq);
        Test.stopTest();

        // Class của bạn bắt lỗi Validation và trả về Response với status = 'ERROR' thay vì Exception
        System.assertEquals('ERROR', res.status, 'Lỗi validation phải trả về status ERROR.');
        System.assertNotEquals(null, res.sysMessage, 'Phải có thông báo lỗi chi tiết.');
    }

    @IsTest
    static void testGetIPPDetails_HttpError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        FEC_GetIPPDetailsCallout.IPPRequest req = createValidRequest();

        Test.startTest();
        try {
            FEC_GetIPPDetailsCallout.getIPPDetails(req);
            System.assert(false, 'Phải throw CalloutException khi HTTP status != 200.');
        } catch (CalloutException e) {
            System.assert(
                e.getMessage().contains('HTTP Error'),
                'Lỗi Exception phải chứa FEC_MSG_HTTP_Error. Actual: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetIPPDetails_ParseError() {
        // Trả về XML rác (không có Body) để ép lỗi khi tìm thẻ XML
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '<soapenv:Envelope><Garbage/></soapenv:Envelope>'));

        FEC_GetIPPDetailsCallout.IPPRequest req = createValidRequest();

        Test.startTest();
        try {
            FEC_GetIPPDetailsCallout.getIPPDetails(req);
            System.assert(false, 'Phải throw CalloutException khi không parse được XML.');
        } catch (CalloutException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidationMethods_Directly() {
        Test.startTest();

        // 1. Kiểm tra Null Request
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateRequest(null).isValid);

        FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
        
        // 2. Kiểm tra Account Number rỗng
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateRequest(req).isValid);
        
        // 3. Kiểm tra EffectiveDate lỗi
        req.accountNumber = '0001500060000003944';
        req.effectiveDate = 'sai_format';
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateRequest(req).isValid);
        
        // 4. Kiểm tra Amount lỗi (<= 0)
        req.effectiveDate = '2026-05-01';
        req.amount = -500;
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateRequest(req).isValid);

        // 5. Kiểm tra PostingDate lỗi
        req.amount = 50000;
        req.postingDate = '2026-13-45'; // Invalid real date
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateRequest(req).isValid);

        // 6. Kiểm tra SysHeaders
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateSysRequestHeaders(null, 'Req01', '2026-05-01T10:00:00').isValid, 'Thiếu TransID');
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateSysRequestHeaders('TXN1', null, '2026-05-01T10:00:00').isValid, 'Thiếu RequestorID');
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateSysRequestHeaders('TXN1', 'Req01', 'Sai Format').isValid, 'Sai format DateTime');
        System.assertEquals(false, FEC_GetIPPDetailsCallout.validateSysRequestHeaders('TXN1', 'Req01', '2026-05-01T10:00:00Z').isValid, 'Z suffix không hợp lệ');
        System.assertEquals(true, FEC_GetIPPDetailsCallout.validateSysRequestHeaders('TXN1', 'Req01', '2026-05-01T10:00:00').isValid, 'Hợp lệ');

        Test.stopTest();
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    private static FEC_GetIPPDetailsCallout.IPPRequest createValidRequest() {
        FEC_GetIPPDetailsCallout.IPPRequest req = new FEC_GetIPPDetailsCallout.IPPRequest();
        req.accountNumber = '0001500060000003944';
        req.effectiveDate = '2026-05-01';
        req.amount = 10000;
        req.postingDate = '2026-05-01';
        return req;
    }

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
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Internal Server Error');
            res.setBody(this.responseBody);
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}