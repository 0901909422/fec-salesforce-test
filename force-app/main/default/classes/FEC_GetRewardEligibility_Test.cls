@IsTest
private class FEC_GetRewardEligibility_Test {

    // XML mẫu giả lập Response SOAP thành công
    private static final String MOCK_XML_SUCCESS =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
        'xmlns:ns1="http://esbservice.fecredit.org/CMS_RewardWS/">' +
        '  <soapenv:Body>' +
        '    <ns1:GetRewardEligibilityResponse>' +
        '      <SysResponse>' +
        '        <TransID>TXN123</TransID>' +
        '        <DateTime>2025-12-16T10:00:00</DateTime>' +
        '        <Status>0</Status>' +
        '        <Description>Success</Description>' +
        '      </SysResponse>' +
        '      <LMSAccount>ACC001</LMSAccount>' +
        '      <EarnedPoints>500.50</EarnedPoints>' +
        '      <RedemptionOptions>' +
        '        <EvoucherEligible>true</EvoucherEligible>' +
        '        <CashbackEligible>false</CashbackEligible>' +
        '        <MvoucherEligible>false</MvoucherEligible>' +
        '      </RedemptionOptions>' +
        '      <Products>' +
        '        <Product>' +
        '          <ProductCode>P01</ProductCode>' +
        '          <ProductName>Gift</ProductName>' +
        '          <RequiredPoints>100</RequiredPoints>' +
        '        </Product>' +
        '      </Products>' +
        '    </ns1:GetRewardEligibilityResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @IsTest
    static void testCallGetRewardEligibility_Success() {
        // 1. Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        // 2. Gọi phương thức
        Test.startTest();
        FEC_GetRewardEligibility.ResponseWrapper res = FEC_GetRewardEligibility.callGetRewardEligibility(
            'TXN12345678901234567890123456789012', 
            FEC_ConstantCommon.REQUESTOR_CRM, 
            '2025-12-16T10:00:00',
            'ACC123'
        );
        Test.stopTest();

        // 3. Xác thực kết quả
        System.assertEquals(0, res.Sys.Code, 'Mã Status/Code trả về phải là 0 (thành công).');
        System.assertEquals('ACC001', res.LMSAccount);
        System.assertEquals(500.50, res.EarnedPoints);
        System.assertEquals(true, res.RedemptionOptions.EvoucherEligible);
        System.assertEquals(1, res.Products.size());
        System.assertEquals('P01', res.Products[0].ProductCode);
    }

    @IsTest
    static void testValidateRequest_Errors() {
        Test.startTest();
        
        // 1. Test lỗi: TransID quá dài (>36)
        try {
            FEC_GetRewardEligibility.callGetRewardEligibility('A'.repeat(37), FEC_ConstantCommon.REQUESTOR_CRM, '2025-12-16T10:00:00', 'ACC1');
            System.assert(false, 'Phải báo lỗi khi TransID quá dài.');
        } catch (CalloutException e) { System.assert(true); }

        // 2. Test lỗi: AccountNumber trống
        try {
            FEC_GetRewardEligibility.callGetRewardEligibility('TXN1', FEC_ConstantCommon.REQUESTOR_CRM, '2025-12-16T10:00:00', '');
            System.assert(false, 'Phải báo lỗi khi AccountNumber trống.');
        } catch (CalloutException e) { System.assert(true); }

        // 3. Test lỗi: RequestorID không hợp lệ
        try {
            FEC_GetRewardEligibility.callGetRewardEligibility('TXN1', 'INVALID', '2025-12-16T10:00:00', 'ACC1');
            System.assert(false, 'Phải báo lỗi khi RequestorID sai.');
        } catch (CalloutException e) { System.assert(true); }

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
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}