@IsTest
private class FEC_TransactionsController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private static final String MOCK_UNBILLED_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<ns1:GetUnbilledTransactionsResponse xmlns:ns1="http://esbservice.fecredit.org/EStatementService/">' +
        '<SysResponse>' +
        '<TransID>TXN12345</TransID>' +
        '<DateTime>2026-05-01 10:00:00</DateTime>' +
        '<Status>0</Status>' +
        '<Description>Success</Description>' +
        '</SysResponse>' +
        '<TransactionRecords>' +
        '<TransactionRecord>' +
        '<TransactionDate>2026-05-01</TransactionDate>' +
        '<PostingDate>2026-05-01</PostingDate>' +
        '<Amount>100.00</Amount>' +
        '<TransactionType>Debit</TransactionType>' +
        '<MerchantName>Test Merchant</MerchantName>' +
        '</TransactionRecord>' +
        '</TransactionRecords>' +
        '</ns1:GetUnbilledTransactionsResponse>' +
        '</soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_FINANCIAL_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardFinancialTransactionsResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<Transactions>' +
        '<Transaction>' +
        '<PostingDate>2026-05-01</PostingDate>' +
        '<TRNXAmount>100.00</TRNXAmount>' +
        '<CreditDebitFlag>D</CreditDebitFlag>' +
        '<TransactionCode>TX01</TransactionCode>' +
        '<Plan>Retail</Plan>' +
        '<AuthCode>AUTH001</AuthCode>' +
        '<OTPSent>1</OTPSent>' +
        '</Transaction>' +
        '</Transactions>' +
        '</GetCardFinancialTransactionsResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_VMX_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<WSResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<VMX_AUTH_DETAIL_INQ>' +
        '<VMX_ROOT><VMX_MSGOUT>' +
        '<SVC_RETURN>S</SVC_RETURN>' +
        '<AUTH_GRP>' +
        '<EFF_DATE>2026-05-01</EFF_DATE>' +
        '<AUTHORIZATION_CODE>AUTH001</AUTHORIZATION_CODE>' +
        '<Description>Pending auth</Description>' +
        '</AUTH_GRP>' +
        '</VMX_MSGOUT></VMX_ROOT>' +
        '</VMX_AUTH_DETAIL_INQ>' +
        '</WSResponse>' +
        '</soapenv:Body></soapenv:Envelope>';

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

    @TestSetup
    static void setupData() {
        ensureApiSettings();

        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC' + suffix,
            FEC_Active__c = true
        );
        insert pt;

        Case c = new Case(
            Subject = 'Test Transactions',
            FEC_Product_Type__c = pt.Id
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = 'ACC123'
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

    private class TransactionApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();
            String body = req.getBody() != null ? req.getBody() : '';
            if (endpoint.contains('GetUnbilledTransactions') || body.contains('GetUnbilledTransactions')) {
                res.setBody(MOCK_UNBILLED_XML);
            } else if (
                endpoint.contains('GetCardFinancialTransactions') ||
                body.contains('GetCardFinancialTransactions')
            ) {
                res.setBody(MOCK_FINANCIAL_XML);
            } else {
                res.setBody(MOCK_VMX_XML);
            }
            return res;
        }
    }

    @IsTest
    static void testLoadTransactions_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransactionApiMock());

        Test.startTest();
        FEC_TransactionsController.TransactionsResponse res =
            FEC_TransactionsController.loadTransactions(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.unbilledTransactions.size() > 0, 'Phải tải được unbilled transactions.');
        System.assert(res.pendingTransactions.size() > 0, 'Phải tải được pending transactions.');
    }

    @IsTest
    static void testLoadTransactionDetail() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransactionApiMock());

        Test.startTest();
        FEC_TransactionsController.loadTransactions(c.Id);
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];
        FEC_TransactionsController.TransactionDTO dto =
            FEC_TransactionsController.loadTransactionDetail(tx.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(tx.Id, dto.Id);
    }
}
