@IsTest
private class FEC_GetLoanBasicInfo_Test {

    // =========================================================================
    // MOCK XML DATA
    // =========================================================================
    
    // Mock XML cho trường hợp Thành công (Code = 1) có chứa đầy đủ các phân nhánh
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetLoanBasicInfoResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-05-25 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <LoanBasicInfo>' +
        '        <Loan>' +
        '          <ApplicationID>APP123</ApplicationID>' +
        '          <ContractNumber>CON123</ContractNumber>' +
        '          <ContractType>Loan</ContractType>' +
        '          <SoldStatus>true</SoldStatus>' +
        '          <AgreementDate>2026-01-01</AgreementDate>' +
        '          <AssetCost>50000.00</AssetCost>' +
        '        </Loan>' +
        '        <InterestOnOverdueInterest>' +
        '          <AssessedAmount>100.50</AssessedAmount>' +
        '        </InterestOnOverdueInterest>' +
        '        <Product>' +
        '          <LoanAmount>40000</LoanAmount>' +
        '          <Tenure>12</Tenure>' +
        '        </Product>' +
        '        <TerminationSimulation>' +
        '          <ExcessAmounts>0</ExcessAmounts>' +
        '          <NextDueDate>2026-06-01</NextDueDate>' +
        '        </TerminationSimulation>' +
        '        <PassDue>' +
        '          <DPD>5</DPD>' +
        '          <TotalOverdueAmount>500.25</TotalOverdueAmount>' +
        '        </PassDue>' +
        '        <PaymentHistories>' +
        '          <PaymentHistory>' +
        '            <ValueDate>2026-05-01</ValueDate>' +
        '            <AmountOfMoney>1000</AmountOfMoney>' +
        '          </PaymentHistory>' +
        '        </PaymentHistories>' +
        '        <RepaymentSchedules>' +
        '          <RepaymentSchedule>' +
        '            <InstallmentNo>1</InstallmentNo>' +
        '            <EMI>1500</EMI>' +
        '          </RepaymentSchedule>' +
        '        </RepaymentSchedules>' +
        '      </LoanBasicInfo>' +
        '    </GetLoanBasicInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // Mock XML cho trường hợp Lỗi Logic API (Code != 1)
    private static final String MOCK_XML_API_ERROR = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetLoanBasicInfoResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-05-25 10:00:00</DateTime>' +
        '        <Code>0</Code>' +
        '        <Description>Contract not found</Description>' +
        '      </Sys>' +
        '    </GetLoanBasicInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testCallGetLoanBasicInfo_Success() {
        // Thiết lập Mock HTTP Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        // Gọi hàm chính
        FEC_GetLoanBasicInfo.ResponseWrapper res = FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
            'TXN12345', 
            FEC_ConstantCommon.REQUESTOR_CRM, 
            '2026-05-25 10:00:00',
            'CON123'
        );
        Test.stopTest();

        // Xác thực logic parser cho các node lồng nhau
        System.assertNotEquals(null, res, 'Kết quả API không được null.');
        System.assertEquals(1, res.Sys.Code, 'Mã Sys Code trả về phải là 1.');
        System.assertNotEquals(null, res.LoanBasicInfo, 'Dữ liệu LoanBasicInfo không được null.');
        
        System.assertEquals('APP123', res.LoanBasicInfo.Loan.ApplicationID);
        System.assertEquals(true, res.LoanBasicInfo.Loan.SoldStatus);
        System.assertEquals(50000.00, res.LoanBasicInfo.Loan.AssetCost);
        
        System.assertEquals(100.50, res.LoanBasicInfo.InterestOnOverdueInterest.AssessedAmount);
        System.assertEquals(40000, res.LoanBasicInfo.Product.LoanAmount);
        System.assertEquals(5, res.LoanBasicInfo.PassDue.DPD);
        
        System.assertEquals(1, res.LoanBasicInfo.PaymentHistories.size());
        System.assertEquals(1000, res.LoanBasicInfo.PaymentHistories[0].AmountOfMoney);
        
        System.assertEquals(1, res.LoanBasicInfo.RepaymentSchedules.size());
        System.assertEquals(1500, res.LoanBasicInfo.RepaymentSchedules[0].EMI);

        // Kích hoạt hàm log để phủ mã
        FEC_GetLoanBasicInfo.logApiResponse();
    }

    @IsTest
    static void testCallGetLoanBasicInfo_HttpError() {
        // Giả lập lỗi máy chủ 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                'TXN12345', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', 'CON123'
            );
            System.assert(false, 'Phải ném CalloutException khi HTTP Status != 200.');
        } catch (CalloutException e) {
            System.assert(true, 'Bắt đúng CalloutException lỗi HTTP.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetLoanBasicInfo_ApiError() {
        // Giả lập API gọi thành công nhưng Sys.Code = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_API_ERROR));

        Test.startTest();
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                'TXN12345', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', 'CON123'
            );
            System.assert(false, 'Phải ném CalloutException khi Sys.Code != 1.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Contract not found'), 'Lỗi phải chứa Description từ XML.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetLoanBasicInfo_IsTestApiTrue() {
        // Test kiểm tra cờ isTestApi = true
        Test.startTest();
        try {
            // Cờ thứ 5 = true
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo(
                'TXN12345', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', 'CON123', true
            );
            System.assert(false, 'Phải ném CalloutException ngay lập tức khi isTestApi = true.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('GetLoanBasicInfo'), 'Lỗi do bypass API kích hoạt thành công.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Failures() {
        Test.startTest();

        // 1. TransID rỗng
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo('', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', 'CON123');
            System.assert(false);
        } catch (CalloutException e) { System.assert(true); }

        // 2. RequestorID không hợp lệ
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo('TXN123', 'INVALID', '2026-05-25 10:00:00', 'CON123');
            System.assert(false);
        } catch (CalloutException e) { System.assert(true); }

        // 3. DateTime rỗng hoặc sai format
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, 'invalid_date', 'CON123');
            System.assert(false);
        } catch (CalloutException e) { System.assert(true); }

        // 4. ContractNumber rỗng
        try {
            FEC_GetLoanBasicInfo.callGetLoanBasicInfo('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-05-25 10:00:00', '');
            System.assert(false);
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