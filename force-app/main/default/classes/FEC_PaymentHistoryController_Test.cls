@IsTest
private class FEC_PaymentHistoryController_Test {

    private static final String MOCK_CARD_SEC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetCardSecInfoResponse>' +
        '      <Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '      <CardSecInfo>' +
        '        <FinancialTransactions>' +
        '          <FinancialTransaction>' +
        '            <PaymentFlag>Y</PaymentFlag>' +
        '            <SettlementDate>2026-05-20</SettlementDate>' +
        '            <PostingDate>2026-05-19</PostingDate>' +
        '            <TRNXAmount>200000</TRNXAmount>' +
        '            <RRN>RRN001</RRN>' +
        '          </FinancialTransaction>' +
        '          <FinancialTransaction>' +
        '            <PaymentFlag>N</PaymentFlag>' +
        '            <SettlementDate>2026-05-18</SettlementDate>' +
        '            <TRNXAmount>999</TRNXAmount>' +
        '            <RRN>RRN-SKIP</RRN>' +
        '          </FinancialTransaction>' +
        '        </FinancialTransactions>' +
        '      </CardSecInfo>' +
        '    </GetCardSecInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    private static final String MOCK_PAYMENT_INFO_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <GetPaymentInfoResponse xmlns="http://fecredit.com.vn/RepaymentInfo">' +
        '      <Sys><TransID>TXN1</TransID><Code>1</Code><Description>OK</Description></Sys>' +
        '      <Payments>' +
        '        <Payment>' +
        '          <Amount_Paid>1500000</Amount_Paid>' +
        '          <Transaction_Date>2026-05-24</Transaction_Date>' +
        '          <Username>ZaloPay</Username>' +
        '        </Payment>' +
        '      </Payments>' +
        '    </GetPaymentInfoResponse>' +
        '  </soapenv:Body>' +
        '</soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = FEC_ConstantCommon.PRODUCT_TYPE_LOAN_CASE,
            FEC_Code__c = 'PT' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        Case c;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            c = new Case(
                FEC_Product_Type__c = pt.Id,
                Status = 'New'
            );
            insert c;

            FEC_Customer_History__c ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                FEC_Account_Number__c = 'ACC123',
                FEC_Contract_Number__c = 'CNT-TEMP',
                Name = 'CH-' + suffix
            );
            insert ch;

            ch.FEC_Contract_Number__c = String.valueOf(ch.Id);
            update ch;

            c.FEC_Account_or_Contract__c = ch.Id;
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    private static Case getTestCase() {
        return [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            LIMIT 1
        ];
    }

    @IsTest
    static void testLoadPaymentHistory_MapsDtoFields() {
        Case c = getTestCase();
        Date payDate = Date.today();

        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Payment_Date__c = payDate,
            FEC_Booking_Date__c = payDate.addDays(-1),
            FEC_Payment_Amount__c = 1000000,
            FEC_Particulars__c = 'PART-1',
            FEC_Total_Payment_Amount__c = 1000000
        );

        Test.startTest();
        List<FEC_PaymentHistoryController.PaymentHistoryDTO> result =
            FEC_PaymentHistoryController.loadPaymentHistory(c.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Loan contract = CH Id → load query khớp lookup.');
        System.assertEquals(1, result[0].paymentNo);
        System.assertEquals(1000000, result[0].paymentAmount);
        System.assertEquals('PART-1', result[0].particulars);
        System.assertEquals(1000000, result[0].totalPaymentAmount);
    }

    @IsTest
    static void testLoadRealtimePayment_MapsDtoFields() {
        Case c = getTestCase();

        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Payment_Date__c = Date.today(),
            FEC_Payment_Amount__c = 500000,
            FEC_Payment_Channel__c = 'ZaloPay'
        );

        Test.startTest();
        List<FEC_PaymentHistoryController.RealtimePaymentDTO> result =
            FEC_PaymentHistoryController.loadRealtimePayment(c.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('ZaloPay', result[0].paymentChannel);
        System.assertEquals(500000, result[0].paymentAmount);
    }

    @IsTest
    static void testLoadMethods_NoAccountLinkedReturnEmpty() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        List<FEC_PaymentHistoryController.PaymentHistoryDTO> billing =
            FEC_PaymentHistoryController.loadPaymentHistory(emptyCase.Id);
        List<FEC_PaymentHistoryController.RealtimePaymentDTO> realtime =
            FEC_PaymentHistoryController.loadRealtimePayment(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(0, billing.size());
        System.assertEquals(0, realtime.size());
    }

    @IsTest
    static void testSyncPaymentHistory_WithMockUpsertsRows() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, MOCK_CARD_SEC_XML));

        Test.startTest();
        FEC_PaymentHistoryController.syncPaymentHistory(c.Id);
        Test.stopTest();

        List<FEC_Payment_History__c> rows = [
            SELECT FEC_Payment_Amount__c, FEC_Particulars__c, FEC_Total_Payment_Amount__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
              AND FEC_Payment_Channel__c = NULL
        ];
        System.assertEquals(1, rows.size(), 'Chỉ transaction PaymentFlag=Y được upsert.');
        System.assertEquals(200000, rows[0].FEC_Payment_Amount__c);
        System.assertEquals('RRN001', rows[0].FEC_Particulars__c);
        System.assertEquals(200000, rows[0].FEC_Total_Payment_Amount__c);
    }

    @IsTest
    static void testSyncPaymentHistory_UpdatesExistingRow() {
        Case c = getTestCase();
        Date payDate = Date.newInstance(2026, 5, 20);

        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Payment_Date__c = payDate,
            FEC_Particulars__c = 'RRN001',
            FEC_Payment_Amount__c = 1,
            FEC_Payment_Channel__c = null
        );

        Test.setMock(HttpCalloutMock.class, new HttpMock(200, MOCK_CARD_SEC_XML));

        Test.startTest();
        FEC_PaymentHistoryController.syncPaymentHistory(c.Id);
        Test.stopTest();

        FEC_Payment_History__c row = [
            SELECT FEC_Payment_Amount__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
              AND FEC_Particulars__c = 'RRN001'
            LIMIT 1
        ];
        System.assertEquals(200000, row.FEC_Payment_Amount__c, 'existingMap branch: update row đã có.');
    }

    @IsTest
    static void testSyncPaymentHistory_NoAccountEarlyReturn() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_PaymentHistoryController.syncPaymentHistory(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Payment_History__c]
        );
    }

    @IsTest
    static void testSyncPaymentHistory_EmptyApiResponse() {
        Case c = getTestCase();
        Test.setMock(
            HttpCalloutMock.class,
            new HttpMock(200, MOCK_CARD_SEC_XML.replace('PaymentFlag>Y', 'PaymentFlag>N'))
        );

        Test.startTest();
        FEC_PaymentHistoryController.syncPaymentHistory(c.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM FEC_Payment_History__c
                WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
            ]
        );
    }

    @IsTest
    static void testSyncRealtimePayment_WithMockUpsertsRows() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new HttpMock(200, MOCK_PAYMENT_INFO_XML));

        Test.startTest();
        FEC_PaymentHistoryController.syncRealtimePayment(c.Id);
        Test.stopTest();

        List<FEC_Payment_History__c> rows = [
            SELECT FEC_Payment_Amount__c, FEC_Payment_Channel__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
              AND FEC_Payment_Channel__c != NULL
        ];
        System.assertEquals(1, rows.size());
        System.assertEquals(1500000, rows[0].FEC_Payment_Amount__c);
        System.assertEquals('ZaloPay', rows[0].FEC_Payment_Channel__c);
    }

    @IsTest
    static void testSyncRealtimePayment_UpdatesExistingRow() {
        Case c = getTestCase();
        Date payDate = Date.newInstance(2026, 5, 24);

        insert new FEC_Payment_History__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Payment_Date__c = payDate,
            FEC_Payment_Channel__c = 'ZaloPay',
            FEC_Payment_Amount__c = 1
        );

        Test.setMock(HttpCalloutMock.class, new HttpMock(200, MOCK_PAYMENT_INFO_XML));

        Test.startTest();
        FEC_PaymentHistoryController.syncRealtimePayment(c.Id);
        Test.stopTest();

        FEC_Payment_History__c row = [
            SELECT FEC_Payment_Amount__c
            FROM FEC_Payment_History__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
              AND FEC_Payment_Channel__c = 'ZaloPay'
            LIMIT 1
        ];
        System.assertEquals(1500000, row.FEC_Payment_Amount__c);
    }

    @IsTest
    static void testSyncRealtimePayment_NoAccountEarlyReturn() {
        Case emptyCase;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            emptyCase = new Case(Status = 'New');
            insert emptyCase;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_PaymentHistoryController.syncRealtimePayment(emptyCase.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM FEC_Payment_History__c]);
    }

    private class HttpMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        HttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
}
