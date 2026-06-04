@IsTest
private class FEC_GetDigitalAccountStatus_Test {

    // =========================================================================
    // DỮ LIỆU MOCK XML
    // =========================================================================
    
    // Mock XML cho trường hợp Thành công (Code = 1)
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <ns1:GetDigitalAccountStatusResponse xmlns:ns1="http://fecredit.com.vn/DigitalChannelWS">' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-01-17 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <AccountStatus>' +
        '        <DigitalAccount>' +
        '          <Type>Zalo</Type>' +
        '          <Status>Active</Status>' +
        '        </DigitalAccount>' +
        '        <DigitalAccount>' +
        '          <Type>MoMo</Type>' +
        '          <Status>Inactive</Status>' +
        '        </DigitalAccount>' +
        '      </AccountStatus>' +
        '    </ns1:GetDigitalAccountStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // Mock XML cho trường hợp Lỗi Logic API (Code != 1)
    private static final String MOCK_XML_API_ERROR = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <ns1:GetDigitalAccountStatusResponse xmlns:ns1="http://fecredit.com.vn/DigitalChannelWS">' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-01-17 10:00:00</DateTime>' +
        '        <Code>0</Code>' +
        '        <Description>Customer not found</Description>' +
        '      </Sys>' +
        '    </ns1:GetDigitalAccountStatusResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testCallGetDigitalAccountStatus_Success() {
        // 1. Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        // 2. Gọi hàm
        Test.startTest();
        FEC_GetDigitalAccountStatus.ResponseWrapper res = FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
            'TXN123456789', 
            FEC_ConstantCommon.REQUESTOR_CRM, // Đảm bảo Constant này map với 'CRM' hoặc tương đương trong validRequestorIds
            '2026-01-17 10:00:00',
            '0901234567', // Phone hợp lệ theo Regex
            'CIF999'
        );
        Test.stopTest();

        // 3. Xác thực kết quả
        System.assertNotEquals(null, res, 'Kết quả không được null.');
        System.assertEquals(1, res.Sys.Code, 'Mã Code trả về phải là 1.');
        System.assertEquals('TXN12345', res.Sys.TransID);
        System.assertEquals(2, res.DigitalAccounts.size(), 'Phải parse được 2 tài khoản số.');
        
        System.assertEquals('Zalo', res.DigitalAccounts[0].Type);
        System.assertEquals('Active', res.DigitalAccounts[0].Status);
        
        System.assertEquals('MoMo', res.DigitalAccounts[1].Type);
        System.assertEquals('Inactive', res.DigitalAccounts[1].Status);
    }

    @IsTest
    static void testCallGetDigitalAccountStatus_HttpError() {
        // Giả lập lỗi HTTP 500 từ Server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '0901234567', 'CIF123'
            );
            System.assert(false, 'Phải throw CalloutException khi HTTP Status != 200.');
        } catch (CalloutException e) {
            System.assert(true, 'Bắt đúng Exception.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetDigitalAccountStatus_ApiError() {
        // Giả lập API gọi thành công nhưng trả về Code = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_API_ERROR));

        Test.startTest();
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(
                'TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '0901234567', 'CIF123'
            );
            System.assert(false, 'Phải throw CalloutException khi Sys.Code != 1.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Customer not found'), 'Thông báo lỗi phải chứa Description từ XML.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Test.startTest();
        
        // 1. Lỗi TransId null
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus(null, FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '0901234567', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi TransID rỗng.');
        } catch (CalloutException e) { System.assert(true); }

        // 2. Lỗi DateTime format
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, 'invalid_date', '0901234567', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi DateTime sai định dạng.');
        } catch (CalloutException e) { System.assert(true); }

        // 3. Lỗi Phone (sai regex, ví dụ chứa chữ cái)
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '090123ABCD', 'CIF123');
            System.assert(false, 'Phải báo lỗi khi Phone sai định dạng Regex.');
        } catch (CalloutException e) { System.assert(true); }

        // 4. Lỗi CIFNumber null
        try {
            FEC_GetDigitalAccountStatus.callGetDigitalAccountStatus('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2026-01-17 10:00:00', '0901234567', null);
            System.assert(false, 'Phải báo lỗi khi CIFNumber rỗng.');
        } catch (CalloutException e) { System.assert(true); }

        Test.stopTest();
    }

    // =========================================================================
    // HELPER CLASS MOCK HTTP RESPONSE
    // =========================================================================
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
            return res;
        }
    }
}