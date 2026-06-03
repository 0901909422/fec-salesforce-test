@IsTest
private class FEC_RepaySchedPayHistController_Test {

    private static final String MOCK_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body><GetLoanBasicInfoResponse>' +
        '    <Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '    <LoanBasicInfo>' +
        '      <RepaymentSchedules>' +
        '        <RepaymentSchedule>' +
        '          <InstallmentNo>1</InstallmentNo>' +
        '          <DueDate>2026-06-01</DueDate>' +
        '          <OpeningPrincipal>10000</OpeningPrincipal>' +
        '          <EMI>1500</EMI>' +
        '          <RepaymentFee>50</RepaymentFee>' +
        '          <InstallmentAmount>1550</InstallmentAmount>' +
        '          <Principal>1200</Principal>' +
        '          <Interest>300</Interest>' +
        '          <ClosingPrincipal>8800</ClosingPrincipal>' +
        '        </RepaymentSchedule>' +
        '      </RepaymentSchedules>' +
        '      <PaymentHistories>' +
        '        <PaymentHistory>' +
        '          <ValueDate>2026-05-01</ValueDate>' +
        '          <AmountOfMoney>500</AmountOfMoney>' +
        '        </PaymentHistory>' +
        '      </PaymentHistories>' +
        '    </LoanBasicInfo>' +
        '  </GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_SEC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body><GetLoanSecInfoResponse>' +
        '    <Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '    <LoanSecInfo>' +
        '      <PaymentHistories>' +
        '        <PaymentHistory>' +
        '          <BookingDate>2026-05-02</BookingDate>' +
        '          <ValueDate>2026-05-03</ValueDate>' +
        '          <AmountOfMoney>620</AmountOfMoney>' +
        '          <ChkNo>CHK001</ChkNo>' +
        '        </PaymentHistory>' +
        '      </PaymentHistories>' +
        '    </LoanSecInfo>' +
        '  </GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_PAYMENT_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetPaymentInfoResponse xmlns="http://fecredit.com.vn/RepaymentInfo">' +
        '      <Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '      <Payments>' +
        '        <Payment>' +
        '          <Amount_Paid>1500000</Amount_Paid>' +
        '          <Transaction_Date>2026-05-24</Transaction_Date>' +
        '          <Username>ZaloPay</Username>' +
        '        </Payment>' +
        '      </Payments>' +
        '    </GetPaymentInfoResponse>' +
        '  </soapenv:Body></soapenv:Envelope>';

    private class MultiSoapMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String reqBody = req.getBody() != null ? req.getBody() : '';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            if (reqBody.contains('GetLoanSecInfo')) {
                res.setBody(MOCK_SEC_XML);
            } else if (reqBody.contains('GetPaymentInfo')) {
                res.setBody(MOCK_PAYMENT_XML);
            } else {
                res.setBody(MOCK_BASIC_XML);
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        if (String.isBlank(apiSetting.FEC_Endpoint__c)) {
            apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;
        }

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                Status = 'New',
                FEC_Is_Test_API__c = false,
                FEC_ID_Search__c = 'RSPH-' + suffix
            );
            insert c;

            FEC_Customer_History__c ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CH-' + suffix,
                FEC_Contract_Number__c = 'CNT123'
            );
            insert ch;

            c.FEC_Account_or_Contract__c = ch.Id;
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getTestCase() {
        return [SELECT Id, FEC_Account_or_Contract__c FROM Case LIMIT 1];
    }

    @IsTest
    static void testGetSectionData_WithMockCallouts() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new MultiSoapMock());

        Test.startTest();
        FEC_RepaySchedPayHistController.SectionDataResult res =
            FEC_RepaySchedPayHistController.getSectionData(c.Id);
        Test.stopTest();

        System.assertEquals(null, res.errorMessage);
        System.assertEquals(false, res.repaymentScheduleError);
        System.assert(res.repaymentScheduleTable.size() >= 1, 'Cần có ít nhất 1 dòng repayment schedule.');
        System.assert(res.paymentHistoryTable.size() >= 1, 'Cần có ít nhất 1 dòng payment history.');
        System.assert(res.realTimePaymentTable.size() >= 1, 'Cần có ít nhất 1 dòng real-time payment.');
        System.assert(res.repaymentSchedulePaymentHistory.size() > 0);
        System.assertNotEquals(null, res.helpTexts);

        Integer scheduleCount = [
            SELECT COUNT()
            FROM FEC_RePayment_Schedule__c
            WHERE FEC_Case__c = :c.Id
        ];
        System.assert(scheduleCount >= 1, 'FEC_RePayment_Schedule__c phải được lưu.');
    }

    @IsTest
    static void testGetSectionData_ReplacesExistingSchedules() {
        Case c = getTestCase();
        insert new FEC_RePayment_Schedule__c(
            FEC_Case__c = c.Id,
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Installment_No__c = 99
        );

        Test.setMock(HttpCalloutMock.class, new MultiSoapMock());

        Test.startTest();
        FEC_RepaySchedPayHistController.getSectionData(c.Id);
        Test.stopTest();

        List<FEC_RePayment_Schedule__c> rows = [
            SELECT FEC_Installment_No__c
            FROM FEC_RePayment_Schedule__c
            WHERE FEC_Case__c = :c.Id
        ];
        System.assertEquals(1, rows.size());
        System.assertEquals(1, rows[0].FEC_Installment_No__c);
    }

    @IsTest
    static void testGetSectionData_TestApiFlagSetsScheduleError() {
        Case c = getTestCase();
        c.FEC_Is_Test_API__c = true;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new MultiSoapMock());

        Test.startTest();
        FEC_RepaySchedPayHistController.SectionDataResult res =
            FEC_RepaySchedPayHistController.getSectionData(c.Id);
        Test.stopTest();

        System.assertEquals(true, res.repaymentScheduleError);
        System.assertEquals(null, res.errorMessage);
    }

    @IsTest
    static void testGetSectionData_NoContractNumber() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New', FEC_Is_Test_API__c = false);
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_RepaySchedPayHistController.SectionDataResult res =
            FEC_RepaySchedPayHistController.getSectionData(emptyCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, res.errorMessage);
    }

    @IsTest
    static void testGetSectionData_FallbackCaseContractNumber() {
        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                Status = 'New',
                FEC_Is_Test_API__c = false,
                FEC_Contract_Number__c = 'CNT-FALLBACK'
            );
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new MultiSoapMock());

        Test.startTest();
        FEC_RepaySchedPayHistController.SectionDataResult res =
            FEC_RepaySchedPayHistController.getSectionData(c.Id);
        Test.stopTest();

        System.assertEquals(null, res.errorMessage);
    }

    @IsTest
    static void testRefreshRealTimePayment_WithMock() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new MultiSoapMock());

        Test.startTest();
        List<FEC_RepaySchedPayHistController.RealTimePaymentRowDTO> rows =
            FEC_RepaySchedPayHistController.refreshRealTimePayment(c.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('ZaloPay', rows[0].paymentChannel);
    }

    @IsTest
    static void testErrorCases() {
        Test.startTest();

        FEC_RepaySchedPayHistController.SectionDataResult resNull =
            FEC_RepaySchedPayHistController.getSectionData(null);
        System.assertNotEquals(null, resNull.errorMessage);

        try {
            FEC_RepaySchedPayHistController.refreshRealTimePayment(null);
            System.assert(false, 'Phải ném AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        try {
            FEC_RepaySchedPayHistController.refreshRealTimePayment(emptyCase.Id);
            System.assert(false, 'Phải ném AuraHandledException khi không có contract');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Test.stopTest();
    }
}
