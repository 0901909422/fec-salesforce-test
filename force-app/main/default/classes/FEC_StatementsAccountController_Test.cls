@IsTest
private class FEC_StatementsAccountController_Test {

    private static final String CONTRACT_NUMBER = '12345678-123456-1234';
    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;
    private static final Date PERIOD_STMT_DATE = Date.newInstance(2026, 5, 10);

    private static String accountNumber() {
        return '123456' + String.valueOf(System.currentTimeMillis()).right(10);
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

    private static Case getTestCase() {
        return [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE FEC_ID_Search__c LIKE 'STMT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static FEC_Statement__c getPeriodStatement(Id customerHistoryId) {
        return [
            SELECT Id, FEC_Statement_Date__c, FEC_Customer_History__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :customerHistoryId
                AND FEC_Statement_Date__c = :PERIOD_STMT_DATE
            LIMIT 1
        ];
    }

    /**
     * Org: billed rows are synced via API then read from FEC_Transaction__c (FEC_Statement__c).
     * Financial API errors are caught inside sync and do not propagate to getBilledTransactions.
     */
    private static void syncBilledTransactionsFromApi(Id statementId) {
        FEC_StatementsAccountController.syncBilledTransactionsFromAPI(statementId);
    }

    private static final String MOCK_CARD_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardBasicInfoResponse>' +
        '<Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '<CardBasicInfo>' +
        '<MainCard><BillingCycle>15</BillingCycle><Status>Active</Status></MainCard>' +
        '<Statement><StatemenBalance>50000</StatemenBalance></Statement>' +
        '</CardBasicInfo>' +
        '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_CARD_SEC_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardSecInfoResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<CardSecInfo>' +
        '<CardStatements>' +
        '<CardStatement>' +
        '<STATMENT_DATE>20260515</STATMENT_DATE>' +
        '<QualGraceBal>50000</QualGraceBal>' +
        '<TotalPaymentDue>50000</TotalPaymentDue>' +
        '<BalanceForBeginningOfPeriod>10000</BalanceForBeginningOfPeriod>' +
        '<BalanceForEndOfPeriod>40000</BalanceForEndOfPeriod>' +
        '</CardStatement>' +
        '</CardStatements>' +
        '</CardSecInfo>' +
        '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_FIN_TXN_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardFinancialTransactionsResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<Transactions>' +
        '<Transaction>' +
        '<TRNXDateAndTime>2026-05-08 10:00:00</TRNXDateAndTime>' +
        '<PostingDate>2026-05-10</PostingDate>' +
        '<TRNXAmount>500.00</TRNXAmount>' +
        '<MerchantName>Test Merchant</MerchantName>' +
        '<Description>Test Merchant</Description>' +
        '<CreditDebitFlag>D</CreditDebitFlag>' +
        '<Plan>Retail</Plan>' +
        '<TransactionCode>TX01</TransactionCode>' +
        '<AuthCode>AUTH123</AuthCode>' +
        '<MCC>5411</MCC>' +
        '<TRNX_Currency_Code>VND</TRNX_Currency_Code>' +
        '<OTPSent>1</OTPSent>' +
        '</Transaction>' +
        '<Transaction>' +
        '<TRNXDateAndTime>2026-03-01 10:00:00</TRNXDateAndTime>' +
        '<PostingDate>2026-03-01</PostingDate>' +
        '<TRNXAmount>99.00</TRNXAmount>' +
        '<MerchantName>Out of cycle</MerchantName>' +
        '<CreditDebitFlag>D</CreditDebitFlag>' +
        '<Plan>Retail</Plan>' +
        '<TransactionCode>TX99</TransactionCode>' +
        '<AuthCode>AUTH999</AuthCode>' +
        '</Transaction>' +
        '</Transactions>' +
        '</GetCardFinancialTransactionsResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_CARD_BASIC_FAIL_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardBasicInfoResponse>' +
        '<Sys><Code>0</Code><Description>API Error</Description></Sys>' +
        '</GetCardBasicInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_FIN_TXN_FAIL_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardFinancialTransactionsResponse>' +
        '<Sys><Code>0</Code><Description>Fin API Error</Description></Sys>' +
        '</GetCardFinancialTransactionsResponse></soapenv:Body></soapenv:Envelope>';

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        String acctNum = accountNumber();
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert pt;

        String suffix = String.valueOf(System.currentTimeMillis());
        Case c = new Case(
            Subject = 'Test Statements Account',
            Status = 'New',
            FEC_ID_Search__c = 'STMT-' + suffix,
            FEC_Product_Type__c = pt.Id,
            FEC_Is_Test_API__c = false
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'STMT-' + suffix,
            FEC_Account_Number__c = acctNum,
            FEC_Contract_Number__c = CONTRACT_NUMBER
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

        insert new List<FEC_Statement__c>{
            new FEC_Statement__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Statement_Date__c = null,
                FEC_Total_Payment_Due__c = 1000
            ),
            new FEC_Statement__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Statement_Date__c = PERIOD_STMT_DATE,
                FEC_Total_Payment_Due__c = 1000,
                FEC_Beginning_Balance__c = 500,
                FEC_End_Balance__c = 1500
            ),
            new FEC_Statement__c(
                FEC_Customer_History__c = ch.Id,
                FEC_Statement_Date__c = PERIOD_STMT_DATE.addMonths(-1),
                FEC_Total_Payment_Due__c = 500
            )
        };
    }

    private class StatementSoapMock implements HttpCalloutMock {
        private String basicXml;
        private String secXml;
        private String finXml;

        StatementSoapMock() {
            this(MOCK_CARD_BASIC_XML, MOCK_CARD_SEC_XML, MOCK_FIN_TXN_XML);
        }

        StatementSoapMock(String basicXml, String secXml, String finXml) {
            this.basicXml = basicXml;
            this.secXml = secXml;
            this.finXml = finXml;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('GetCardFinancialTransactions')) {
                res.setBody(finXml);
            } else if (body.contains('GetCardSecInfo')) {
                res.setBody(secXml);
            } else if (body.contains('GetCardBasicInfo')) {
                res.setBody(basicXml);
            } else {
                res.setBody(basicXml);
            }
            return res;
        }
    }

    @IsTest
    static void testSyncStatementFromAPI_Success() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new StatementSoapMock());

        Test.startTest();
        FEC_StatementsAccountController.syncStatementFromAPI(c.Id);
        Test.stopTest();

        Id chId = c.FEC_Account_or_Contract__c;
        FEC_Statement__c header = [
            SELECT FEC_Total_Payment_Due__c, FEC_Billing_Cycle__c
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :chId
                AND FEC_Statement_Date__c = null
            LIMIT 1
        ];
        System.assertEquals(50000, header.FEC_Total_Payment_Due__c);
        System.assertEquals(15, header.FEC_Billing_Cycle__c);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM FEC_Statement__c
                WHERE FEC_Customer_History__c = :chId
                    AND FEC_Statement_Date__c = 2026-05-15
            ]
        );
    }

    @IsTest
    static void testSyncStatementFromAPI_BasicInfoApiError() {
        Case c = getTestCase();
        Test.setMock(
            HttpCalloutMock.class,
            new StatementSoapMock(MOCK_CARD_BASIC_FAIL_XML, MOCK_CARD_SEC_XML, MOCK_FIN_TXN_XML)
        );

        Test.startTest();
        try {
            FEC_StatementsAccountController.syncStatementFromAPI(c.Id);
            System.assert(false, 'Expected AuraHandledException when basic info API fails.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetLatestStatementId() {
        Case c = getTestCase();

        Test.startTest();
        Id stmtId = FEC_StatementsAccountController.getLatestStatementId(c.Id);
        Test.stopTest();

        FEC_Statement__c headerStmt = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                AND FEC_Statement_Date__c = null
            LIMIT 1
        ];
        System.assertEquals(headerStmt.Id, stmtId);
    }

    @IsTest
    static void testGetLatestStatementId_NoStatements() {
        Case c = getTestCase();
        delete [SELECT Id FROM FEC_Statement__c WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c];

        Test.startTest();
        Id stmtId = FEC_StatementsAccountController.getLatestStatementId(c.Id);
        Test.stopTest();

        System.assertEquals(null, stmtId);
    }

    @IsTest
    static void testLoadGeneralStatementInfo() {
        Case c = getTestCase();
        FEC_Statement__c header = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                AND FEC_Statement_Date__c = null
            LIMIT 1
        ];

        Test.startTest();
        FEC_StatementsAccountController.GeneralStatementInfoDTO result =
            FEC_StatementsAccountController.loadGeneralStatementInfo(header.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1000, result.totalPaymentDue);
        System.assertEquals(header.Id, result.statementId);
    }

    @IsTest
    static void testLoadStatementDetails() {
        Case c = getTestCase();
        FEC_Statement__c detail = getPeriodStatement(c.FEC_Account_or_Contract__c);

        Test.startTest();
        List<FEC_StatementsAccountController.StatementPeriodDTO> results =
            FEC_StatementsAccountController.loadStatementDetails(detail.Id);
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(1000, results[0].totalPaymentDue);
        System.assertEquals(PERIOD_STMT_DATE, results[0].statementDate);
    }

    @IsTest
    static void testGetBilledTransactions_Success() {
        ensureApiSettings();
        Case c = getTestCase();
        FEC_Statement__c stmt = getPeriodStatement(c.FEC_Account_or_Contract__c);

        Test.setMock(HttpCalloutMock.class, new StatementSoapMock());

        Test.startTest();
        syncBilledTransactionsFromApi(stmt.Id);
        List<FEC_StatementsAccountController.BilledTransactionDTO> results =
            FEC_StatementsAccountController.getBilledTransactions(stmt.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only in-cycle billed transaction should remain.');
        System.assertEquals('Test Merchant', results[0].merchantDescription);
        System.assertEquals(500.00, results[0].transactionAmount);
        System.assertEquals('D', results[0].creditDebitFlag);
        System.assertEquals(Date.newInstance(2026, 5, 10), results[0].postDate);
        System.assertNotEquals(null, results[0].Id, 'Transaction record should be upserted.');

        FEC_Transaction__c persisted = [
            SELECT FEC_Merchant_Description__c, FEC_Transaction_Amount__c
            FROM FEC_Transaction__c
            WHERE Id = :results[0].Id
        ];
        System.assertEquals('Test Merchant', persisted.FEC_Merchant_Description__c);
    }

    @IsTest
    static void testGetBilledTransactions_ExistingRecordUpsert() {
        ensureApiSettings();
        Case c = getTestCase();
        FEC_Statement__c stmt = getPeriodStatement(c.FEC_Account_or_Contract__c);

        insert new FEC_Transaction__c(
            FEC_Customer_History__c = c.FEC_Account_or_Contract__c,
            FEC_Statement__c = stmt.Id,
            FEC_Post_Date__c = PERIOD_STMT_DATE,
            FEC_Transaction_Amount__c = 500.00,
            FEC_Credit_Debit_Flag__c = 'D',
            FEC_Transaction_Code__c = 'TX01',
            FEC_Authorization_Code__c = 'AUTH123',
            FEC_Transaction_Plan__c = 'Retail',
            FEC_Merchant_Description__c = 'Old Merchant'
        );

        Test.setMock(HttpCalloutMock.class, new StatementSoapMock());

        Test.startTest();
        syncBilledTransactionsFromApi(stmt.Id);
        List<FEC_StatementsAccountController.BilledTransactionDTO> results =
            FEC_StatementsAccountController.getBilledTransactions(stmt.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Merchant', results[0].merchantDescription);
    }

    @IsTest
    static void testGetBilledTransactions_NoPreviousStatement() {
        ensureApiSettings();
        Case c = getTestCase();
        delete [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                AND FEC_Statement_Date__c < :PERIOD_STMT_DATE
        ];
        FEC_Statement__c stmt = getPeriodStatement(c.FEC_Account_or_Contract__c);

        Test.setMock(HttpCalloutMock.class, new StatementSoapMock());

        Test.startTest();
        syncBilledTransactionsFromApi(stmt.Id);
        List<FEC_StatementsAccountController.BilledTransactionDTO> results =
            FEC_StatementsAccountController.getBilledTransactions(stmt.Id);
        Test.stopTest();

        System.assert(
            results.size() >= 1,
            'Without a prior statement period, sync should still persist in-window billed rows.'
        );
        Boolean hasInCycleMerchant = false;
        for (FEC_StatementsAccountController.BilledTransactionDTO dto : results) {
            if (dto.merchantDescription == 'Test Merchant') {
                hasInCycleMerchant = true;
                break;
            }
        }
        System.assert(hasInCycleMerchant, 'Expected in-cycle Test Merchant transaction.');
    }

    @IsTest
    static void testGetBilledTransactions_HeaderReturnsEmpty() {
        Case c = getTestCase();
        FEC_Statement__c header = [
            SELECT Id
            FROM FEC_Statement__c
            WHERE FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
                AND FEC_Statement_Date__c = null
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new StatementSoapMock());

        Test.startTest();
        List<FEC_StatementsAccountController.BilledTransactionDTO> results =
            FEC_StatementsAccountController.getBilledTransactions(header.Id);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetBilledTransactions_ApiError() {
        ensureApiSettings();
        Case c = getTestCase();
        FEC_Statement__c stmt = getPeriodStatement(c.FEC_Account_or_Contract__c);

        Test.setMock(
            HttpCalloutMock.class,
            new StatementSoapMock(MOCK_CARD_BASIC_XML, MOCK_CARD_SEC_XML, MOCK_FIN_TXN_FAIL_XML)
        );

        Test.startTest();
        syncBilledTransactionsFromApi(stmt.Id);
        List<FEC_StatementsAccountController.BilledTransactionDTO> results =
            FEC_StatementsAccountController.getBilledTransactions(stmt.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            results.size(),
            'Financial API failure must not persist billed transactions for the statement.'
        );
    }

    @IsTest
    static void testValidationErrors() {
        Test.startTest();

        try {
            FEC_StatementsAccountController.syncStatementFromAPI(null);
            System.assert(false, 'Must throw when CaseId is null.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        System.assertEquals(null, FEC_StatementsAccountController.loadGeneralStatementInfo(null));
        System.assertEquals(0, FEC_StatementsAccountController.loadStatementDetails(null).size());
        System.assertEquals(0, FEC_StatementsAccountController.getBilledTransactions(null).size());

        Test.stopTest();
    }
}
