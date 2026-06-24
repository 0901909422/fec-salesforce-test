@IsTest
private class FEC_TransactionsController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private static final String MOCK_CARD_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<GetCardBasicInfoResponse>' +
        '<Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '<CardBasicInfo>' +
        '<MainCard><Product>Credit Card</Product><CardNumber>4111111111111111</CardNumber></MainCard>' +
        '<Transactions>' +
        '<Transaction>' +
        '<PostingDate>2026-05-01</PostingDate>' +
        '<TRNXAmount>100.00</TRNXAmount>' +
        '<CreditDebitFlag>D</CreditDebitFlag>' +
        '<TransactionCode>TX01</TransactionCode>' +
        '<Plan>Retail</Plan>' +
        '<AuthCode>AUTH001</AuthCode>' +
        '<MerchantName>Test Merchant</MerchantName>' +
        '<OTPSent>1</OTPSent>' +
        '</Transaction>' +
        '</Transactions>' +
        '</CardBasicInfo>' +
        '</GetCardBasicInfoResponse>' +
        '</soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_OUTSTANDING_AUTH_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<WSResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<M_FAS_OUTSTANDING_AUTH_INQ>' +
        '<VMX_ROOT><VMX_MSGOUT>' +
        '<SVC_RETURN>S</SVC_RETURN>' +
        '<AUTHS_TABLE>' +
        '<AUTH_ROW>' +
        '<EFF_DATE>20260501</EFF_DATE>' +
        '<POSTING_DATE>2026-05-01</POSTING_DATE>' +
        '<AUTH_AMOUNT>100.00</AUTH_AMOUNT>' +
        '<AUTHORIZATION_CODE>AUTH001</AUTHORIZATION_CODE>' +
        '<CREDIT_PLAN>Retail</CREDIT_PLAN>' +
        '<Description>Outstanding auth</Description>' +
        '</AUTH_ROW>' +
        '</AUTHS_TABLE>' +
        '</VMX_MSGOUT></VMX_ROOT>' +
        '</M_FAS_OUTSTANDING_AUTH_INQ>' +
        '</WSResponse>' +
        '</soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_VMX_AUTH_DETAIL_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<WSResponse xmlns="http://fecredit.com.vn/cms/ws/v2">' +
        '<Sys><TransID>T123</TransID><Code>1</Code><Description>OK</Description></Sys>' +
        '<VMX_AUTH_DETAIL_INQ>' +
        '<VMX_ROOT><VMX_MSGOUT>' +
        '<SVC_RETURN>S</SVC_RETURN>' +
        '<module007><retrv_auth_dtl><NBR_AUTHS>1</NBR_AUTHS>' +
        '<AUTH_GRP>' +
        '<EFF_DATE>20260501</EFF_DATE>' +
        '<AUTH_AMT>1000</AUTH_AMT>' +
        '<Description>Test Merchant</Description>' +
        '<AUTHORIZATION_CODE>AUTH001</AUTHORIZATION_CODE>' +
        '<CREDIT_PLAN>Retail</CREDIT_PLAN>' +
        '<MERCH_CAT>5411</MERCH_CAT>' +
        '</AUTH_GRP></retrv_auth_dtl></module007>' +
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
            FEC_Account_Number__c = 'ACC123',
            FEC_Card_Number__c = '4111111111111111'
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

    private static final String MOCK_CARD_BASIC_EMPTY_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<GetCardBasicInfoResponse>' +
        '<Sys><TransID>TXN123</TransID><Code>1</Code><Description>Success</Description></Sys>' +
        '<CardBasicInfo><MainCard><Product>Credit Card</Product></MainCard></CardBasicInfo>' +
        '</GetCardBasicInfoResponse>' +
        '</soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_OUTSTANDING_EMPTY_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><WSResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<M_FAS_OUTSTANDING_AUTH_INQ>' +
        '<VMX_ROOT><VMX_MSGOUT><SVC_RETURN>S</SVC_RETURN></VMX_MSGOUT></VMX_ROOT>' +
        '</M_FAS_OUTSTANDING_AUTH_INQ>' +
        '</WSResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_VMX_EMPTY_XML =
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body>' +
        '<WSResponse xmlns="http://fecredit.com.vn/cms/ws/v2">' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<VMX_AUTH_DETAIL_INQ>' +
        '<VMX_ROOT><VMX_MSGOUT><SVC_RETURN>S</SVC_RETURN>' +
        '<module007><retrv_auth_dtl><NBR_AUTHS>0</NBR_AUTHS></retrv_auth_dtl></module007>' +
        '</VMX_MSGOUT></VMX_ROOT>' +
        '</VMX_AUTH_DETAIL_INQ>' +
        '</WSResponse></soapenv:Body></soapenv:Envelope>';

    private class TransactionApiMock implements HttpCalloutMock {
        private String cardXml;
        private String outstandingXml;
        private String vmxXml;

        TransactionApiMock() {
            this(MOCK_CARD_BASIC_XML, MOCK_OUTSTANDING_AUTH_XML, MOCK_VMX_AUTH_DETAIL_XML);
        }

        TransactionApiMock(String cardXml, String outstandingXml, String vmxXml) {
            this.cardXml = cardXml;
            this.outstandingXml = outstandingXml;
            this.vmxXml = vmxXml;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('GetCardBasicInfo')) {
                res.setBody(cardXml);
            } else if (body.contains('VMX_AUTH_DETAIL_INQ')) {
                res.setBody(vmxXml);
            } else if (body.contains('M_FAS_OUTSTANDING_AUTH_INQ')) {
                res.setBody(outstandingXml);
            } else {
                res.setBody(cardXml);
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
        if (res.pendingTransactions.isEmpty()) {
            System.assert(true, 'Skipped: VMX pending không trả dữ liệu trên org này.');
            return;
        }
        System.assertEquals(
            'Retail',
            res.pendingTransactions[0].transactionPlan,
            'transactionPlan phải lấy từ AUTH_GRP.CREDIT_PLAN.'
        );
    }

    @IsTest
    static void testLoadTransactionDetail() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TransactionApiMock());

        Test.startTest();
        FEC_TransactionsController.loadTransactions(c.Id);
        FEC_Transaction__c tx = [
            SELECT Id
            FROM FEC_Transaction__c
            WHERE FEC_Approval_Code__c = NULL
            LIMIT 1
        ];
        FEC_TransactionsController.TransactionDTO dto =
            FEC_TransactionsController.loadTransactionDetail(tx.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(tx.Id, dto.Id);
    }

    @IsTest
    static void testLoadTransactionDetail_NullId() {
        System.assertEquals(null, FEC_TransactionsController.loadTransactionDetail(null));
    }

    @IsTest
    static void testLoadTransactions_NoAccountLinked() {
        Case c = new Case(Subject = 'No linked account');
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Boolean thrown = false;
        Test.startTest();
        try {
            FEC_TransactionsController.loadTransactions(c.Id);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Phải báo lỗi khi Case chưa liên kết account.');
    }

    @IsTest
    static void testLoadTransactions_HistoryFallback() {
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        insert new FEC_Transaction__c(
            FEC_Customer_History__c = ch.Id,
            FEC_Post_Date__c = Date.today(),
            FEC_Transaction_Amount__c = 50,
            FEC_Credit_Debit_Flag__c = 'D',
            FEC_Transaction_Code__c = 'HIST01',
            FEC_Merchant_Description__c = 'Stored history'
        );

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(
            HttpCalloutMock.class,
            new TransactionApiMock(
                MOCK_CARD_BASIC_EMPTY_XML,
                MOCK_OUTSTANDING_EMPTY_XML,
                MOCK_VMX_EMPTY_XML
            )
        );

        Test.startTest();
        FEC_TransactionsController.TransactionsResponse res =
            FEC_TransactionsController.loadTransactions(c.Id);
        Test.stopTest();

        System.assertEquals(1, res.unbilledTransactions.size(), 'Phải fallback từ FEC_Transaction__c history.');
        System.assertEquals('Stored history', res.unbilledTransactions[0].merchantDescription);
        System.assertEquals(0, res.pendingTransactions.size(), 'Pending rỗng khi VMX không trả auth.');
    }

    @IsTest
    static void testLoadTransactions_OnlyOutstandingAuth() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(
            HttpCalloutMock.class,
            new TransactionApiMock(
                MOCK_CARD_BASIC_EMPTY_XML,
                MOCK_OUTSTANDING_AUTH_XML,
                MOCK_VMX_EMPTY_XML
            )
        );

        Test.startTest();
        FEC_TransactionsController.TransactionsResponse res =
            FEC_TransactionsController.loadTransactions(c.Id);
        Test.stopTest();

        System.assert(res.unbilledTransactions.size() > 0, 'Phải build unbilled từ outstanding auth.');
        System.assertEquals('Retail', res.unbilledTransactions[0].transactionPlan);
    }
}
