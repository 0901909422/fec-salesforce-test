@IsTest
private class FEC_GetLoanSecInfo_Test {

    // =========================================================================
    // MOCK XML DATA
    // =========================================================================
    
    // Mock XML cho trường hợp Thành công (Code = 1) với đầy đủ các node lồng nhau
    private static final String MOCK_XML_SUCCESS = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetLoanSecInfoResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-03-09 10:00:00</DateTime>' +
        '        <Code>1</Code>' +
        '        <Description>Success</Description>' +
        '      </Sys>' +
        '      <LoanSecInfo>' +
        '        <Loan>' +
        '          <TotalInstallmentPaid>1500.00</TotalInstallmentPaid>' +
        '          <TotalPrincipalPaid>1200.00</TotalPrincipalPaid>' +
        '          <TotalInterestPaid>300.00</TotalInterestPaid>' +
        '          <RestExcessAmounts>50.00</RestExcessAmounts>' +
        '          <PrincipalOutstanding>50000.00</PrincipalOutstanding>' +
        '          <AdditionalAmount>10.00</AdditionalAmount>' +
        '        </Loan>' +
        '        <PaymentHistories>' +
        '          <PaymentHistory>' +
        '            <BookingDate>2026-03-01</BookingDate>' +
        '            <PrinciplePaid>500.00</PrinciplePaid>' +
        '            <InterestPaid>100.00</InterestPaid>' +
        '            <RepaymentFeePaid>10.00</RepaymentFeePaid>' +
        '            <PenaltyFee>5.00</PenaltyFee>' +
        '            <PenaltyFeePaid>5.00</PenaltyFeePaid>' +
        '            <ValueDate>2026-03-02</ValueDate>' +
        '            <AmountOfMoney>620.00</AmountOfMoney>' +
        '            <ChkNo>CHK001</ChkNo>' +
        '          </PaymentHistory>' +
        '        </PaymentHistories>' +
        '        <PassDue>' +
        '          <InstallmentsRemaining>24</InstallmentsRemaining>' +
        '          <ResposiblePerson>Nguyen Van B</ResposiblePerson>' +
        '          <DateAssgined>2026-03-05</DateAssgined>' +
        '        </PassDue>' +
        '        <TerminationSimulation>' +
        '          <NetReceivable>1000.00</NetReceivable>' +
        '          <ExcessAmounts>0.00</ExcessAmounts>' +
        '          <PrePaymentPenalty>50.00</PrePaymentPenalty>' +
        '          <CurrentBalancePrincipal>800.00</CurrentBalancePrincipal>' +
        '          <InterestOnTermination>20.00</InterestOnTermination>' +
        '          <TotalDues>1500.00</TotalDues>' +
        '          <InstallmentsOverdue>1</InstallmentsOverdue>' +
        '          <PenaltyFeeOverdue>15.00</PenaltyFeeOverdue>' +
        '          <RepaymentFeeOverdue>10.00</RepaymentFeeOverdue>' +
        '        </TerminationSimulation>' +
        '        <LPI>' +
        '          <PendingPenalInt>25.00</PendingPenalInt>' +
        '          <AppliedLPI>5.00</AppliedLPI>' +
        '        </LPI>' +
        '        <ReversalTransactions>None</ReversalTransactions>' +
        '      </LoanSecInfo>' +
        '    </GetLoanSecInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // Mock XML cho trường hợp Lỗi Logic API (Code != 1)
    private static final String MOCK_XML_API_ERROR = 
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetLoanSecInfoResponse>' +
        '      <Sys>' +
        '        <TransID>TXN12345</TransID>' +
        '        <DateTime>2026-03-09 10:00:00</DateTime>' +
        '        <Code>0</Code>' +
        '        <Description>Contract not found</Description>' +
        '      </Sys>' +
        '    </GetLoanSecInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    // =========================================================================
    // TEST CASES
    // =========================================================================

    @IsTest
    static void testCallGetLoanSecInfo_Success() {
        // Thiết lập Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_SUCCESS));

        Test.startTest();
        // Gọi hàm qua method wrap đơn giản
        FEC_GetLoanSecInfo.ResponseWrapper res = FEC_GetLoanSecInfo.getLoanSecInfo('CON123');
        Test.stopTest();

        // Xác thực kết quả API chung
        System.assertNotEquals(null, res, 'Kết quả API không được null.');
        System.assertEquals(1, res.Sys.Code, 'Sys Code trả về phải là 1.');
        
        // Xác thực dữ liệu Parse Loan
        System.assertEquals(1500.00, res.LoanSecInfo.Loan.TotalInstallmentPaid);
        System.assertEquals(50000.00, res.LoanSecInfo.Loan.PrincipalOutstanding);
        
        // Xác thực dữ liệu Parse PaymentHistory
        System.assertEquals(1, res.LoanSecInfo.PaymentHistories.size());
        System.assertEquals(620.00, res.LoanSecInfo.PaymentHistories[0].AmountOfMoney);
        System.assertEquals('CHK001', res.LoanSecInfo.PaymentHistories[0].ChkNo);
        
        // Xác thực dữ liệu Parse PassDue
        System.assertEquals(24, res.LoanSecInfo.PassDue.InstallmentsRemaining);
        System.assertEquals('Nguyen Van B', res.LoanSecInfo.PassDue.ResponsiblePerson);
        
        // Xác thực dữ liệu Parse TerminationSimulation
        System.assertEquals(1000.00, res.LoanSecInfo.TerminationSimulation.NetReceivable);
        System.assertEquals(1, res.LoanSecInfo.TerminationSimulation.InstallmentsOverdue);
        
        // Xác thực dữ liệu Parse LPI
        System.assertEquals(25.00, res.LoanSecInfo.LPI.PendingPenalInt);
        System.assertEquals('None', res.LoanSecInfo.ReversalTransactions);

        // Phủ hàm log API
        FEC_GetLoanSecInfo.logApiResponse();
    }

    @IsTest
    static void testCallGetLoanSecInfo_HttpError() {
        // Giả lập lỗi HTTP 500
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo(
                'TXN12345', FEC_ConstantCommon.REQUESTOR_CRM, '2026-03-09 10:00:00', 'CON123'
            );
            System.assert(false, 'Phải ném CalloutException khi HTTP Status != 200.');
        } catch (CalloutException e) {
            System.assert(true, 'Bắt đúng Exception của lỗi HTTP.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCallGetLoanSecInfo_ApiError() {
        // Giả lập API gọi thành công nhưng Sys.Code = 0
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_XML_API_ERROR));

        Test.startTest();
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo(
                'TXN12345', FEC_ConstantCommon.REQUESTOR_CRM, '2026-03-09 10:00:00', 'CON123'
            );
            System.assert(false, 'Phải ném CalloutException khi Sys.Code != 1.');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Contract not found'), 'Lỗi phải chứa Description từ XML.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateRequest_Failures() {
        Test.startTest();

        // 1. Lỗi TransID rỗng
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo('', FEC_ConstantCommon.REQUESTOR_CRM, '2026-03-09 10:00:00', 'CON123');
            System.assert(false, 'Phải bắt lỗi TransID null.');
        } catch (CalloutException e) { System.assert(true); }

        // 2. Lỗi RequestorID rỗng/không hợp lệ
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo('TXN123', 'INVALID', '2026-03-09 10:00:00', 'CON123');
            System.assert(false, 'Phải bắt lỗi RequestorID không hợp lệ.');
        } catch (CalloutException e) { System.assert(true); }

        // 3. Lỗi DateTime rỗng hoặc sai định dạng
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, 'sai_dinh_dang', 'CON123');
            System.assert(false, 'Phải bắt lỗi DateTime sai format.');
        } catch (CalloutException e) { System.assert(true); }

        // 4. Lỗi ContractNumber rỗng
        try {
            FEC_GetLoanSecInfo.callGetLoanSecInfo('TXN123', FEC_ConstantCommon.REQUESTOR_CRM, '2026-03-09 10:00:00', '');
            System.assert(false, 'Phải bắt lỗi ContractNumber rỗng.');
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
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}