@IsTest
private class FEC_TerminationLoanController_Test {

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        Case c = new Case(
            Subject = 'Test Termination',
            FEC_Is_Test_API__c = true
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Contract_Number__c = 'CNT123'
        );
        insert ch;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = ch.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static void ensureApiSettings() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        apiSetting.FEC_Enviroment__c = 'Production';
        upsert apiSetting;
    }

    // =====================================================================
    // MOCK API (SOAP)
    // =====================================================================
    private static final String MOCK_LOAN_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
        '<soapenv:Body><GetLoanBasicInfoResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<LoanBasicInfo><Loan>' +
        '<SysCalcChargeAmount>100</SysCalcChargeAmount>' +
        '<ChargeAmtCollected>50</ChargeAmtCollected>' +
        '<ChargeWaived>10</ChargeWaived>' +
        '<OutstandingChargeAmount>40</OutstandingChargeAmount>' +
        '</Loan></LoanBasicInfo>' +
        '</GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_LOAN_SEC_XML =
        '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '">' +
        '<soapenv:Body><GetLoanSecInfoResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<LoanSecInfo>' +
        '<Loan><TotalInstallmentPaid>1</TotalInstallmentPaid></Loan>' +
        '<TerminationSimulation><NetReceivable>500000</NetReceivable></TerminationSimulation>' +
        '<LPI><PendingPenalInt>0</PendingPenalInt></LPI>' +
        '</LoanSecInfo>' +
        '</GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>';

    private class TerminationApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('GetLoanSecInfo')) {
                res.setBody(MOCK_LOAN_SEC_XML);
            } else {
                res.setBody(MOCK_LOAN_BASIC_XML);
            }
            return res;
        }
    }

    private class TerminationApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('API Timeout');
        }
    }

    // =====================================================================
    // TEST METHODS
    // =====================================================================

    @IsTest
    static void testGetTerminationData_Success() {
        ensureApiSettings();
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TerminationApiMock());

        Test.startTest();
        FEC_TerminationLoanController.TerminationDataDTO dto = FEC_TerminationLoanController.getTerminationData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO không được null.');
        System.assertEquals(null, dto.error, 'Không nên có lỗi.');
        System.assert(dto.earlyTermination.size() > 0, 'Phải có dữ liệu early termination.');
        
        // Kiểm tra xem dữ liệu đã được lưu vào Database chưa
        FEC_Customer_History__c ch = [SELECT FEC_Termination_Amount__c, FEC_Assessed_Amount__c FROM FEC_Customer_History__c LIMIT 1];
        System.assertEquals(500000, ch.FEC_Termination_Amount__c, 'Termination Amount phải được lưu.');
        System.assertEquals(100, ch.FEC_Assessed_Amount__c, 'Assessed Amount phải được lưu.');
    }

    @IsTest
    static void testGetTerminationData_ValidationErrors() {
        // 1. Case Id null
        Test.startTest();
        FEC_TerminationLoanController.TerminationDataDTO res1 = FEC_TerminationLoanController.getTerminationData(null);
        System.assertNotEquals(null, res1.error);

        // 2. Case không liên kết Account
        Case c2 = new Case(Subject = 'Orphan Case');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c2;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        FEC_TerminationLoanController.TerminationDataDTO res2 = FEC_TerminationLoanController.getTerminationData(c2.Id);
        System.assertNotEquals(null, res2.error);
        Test.stopTest();
    }

    @IsTest
    static void testGetTerminationData_ApiError() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new TerminationApiErrorMock());

        Test.startTest();
        FEC_TerminationLoanController.TerminationDataDTO dto = FEC_TerminationLoanController.getTerminationData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto.error, 'Phải trả về thông báo lỗi API.');
    }
}