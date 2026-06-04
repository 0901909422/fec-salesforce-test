@IsTest
private class FEC_SalesInfoController_Test {

    private static final String ACCOUNT_NUMBER = '1234567890123456';

    private static final String MOCK_CUSTOMER_LIST_SOAP =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
        '      <Sys><Code>1</Code><Description>Success</Description></Sys>' +
        '      <Customers><Customer><Applications>' +
        '        <Application><ApplicationID>APP_API_123</ApplicationID></Application>' +
        '      </Applications></Customer></Customers>' +
        '    </cif:GetCustomerListResponse>' +
        '  </soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_SALE_DISBURSE_JSON =
        '{' +
        '  "Sys": {"TransID": "TXN-SD", "DateTime": "2026-10-25T10:00:00.000+07:00", "Code": 1, "Description": "OK"},' +
        '  "CustomerSaleInfos": [{' +
        '    "APPLICATION_ID": "APP_API_123",' +
        '    "CC_CODE": "CC_TEST", "CC_NAME": "CC Name",' +
        '    "DSA_CODE": "DSA_TEST", "DSA_NAME": "DSA Name",' +
        '    "TSA_CODE": "TSA_TEST", "TSA_NAME": "TSA Name",' +
        '    "DISB_CHANNEL": "CASH"' +
        '  }]' +
        '}';

    private static final String MOCK_APP_STATUS_JSON =
        '{' +
        '  "Sys": {"Code": "1", "Description": "Success", "TransID": "TXN-AS"},' +
        '  "Applications": [{' +
        '    "Application": {"OriginalChannel": "TELESALES", "AppID": "APP_API_123"}' +
        '  }]' +
        '}';

    private static final String MOCK_EMPTY_CUSTOMER_LIST_SOAP =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '  <soapenv:Body>' +
        '    <cif:GetCustomerListResponse xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
        '      <Sys><Code>1</Code></Sys><Customers></Customers>' +
        '    </cif:GetCustomerListResponse>' +
        '  </soapenv:Body></soapenv:Envelope>';

    private class MultiSalesInfoMock implements HttpCalloutMock {
        private Boolean emptyCustomerList;

        MultiSalesInfoMock() {
            this(false);
        }

        MultiSalesInfoMock(Boolean emptyCustomerList) {
            this.emptyCustomerList = emptyCustomerList;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';
            String body = req.getBody() != null ? req.getBody() : '';

            if (body.contains('GetCustomerList') || endpoint.contains('CustomerList')) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(emptyCustomerList ? MOCK_EMPTY_CUSTOMER_LIST_SOAP : MOCK_CUSTOMER_LIST_SOAP);
            } else if (req.getMethod() == 'POST') {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(MOCK_APP_STATUS_JSON);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(MOCK_SALE_DISBURSE_JSON);
            }
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        if (String.isBlank(apiSetting.FEC_Endpoint__c)) {
            apiSetting.FEC_Endpoint__c = 'https://mock-api.fecredit.com.vn';
            apiSetting.FEC_Call_Mock__c = false;
            upsert apiSetting;
        }

        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_SalesInfoController_Test',
            Status = 'New',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_ID_Search__c = 'SIC-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'CUST_001',
            FEC_Account_Number__c = ACCOUNT_NUMBER
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

        insert new FEC_IPP__c(FEC_Customer_History__c = ch.Id);
    }

    @IsTest
    static void testGetSalesInfoByIPPRecord_API_Flow() {
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_Application_ID__c = null
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByIPPRecord(ipp.Id);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess, 'API flow phải thành công.');
        System.assertEquals('APP_API_123', result.applicationId);
        System.assertEquals('CC_TEST', result.ccCode);
        System.assertEquals('CASH', result.disbursementChannel);

        FEC_IPP__c updated = [
            SELECT FEC_Application_ID__c, FEC_Origination_Channel__c, FEC_CC_Code__c
            FROM FEC_IPP__c
            WHERE Id = :ipp.Id
        ];
        System.assertEquals('APP_API_123', updated.FEC_Application_ID__c);
        System.assertEquals('CC_TEST', updated.FEC_CC_Code__c);
    }

    @IsTest
    static void testGetSalesInfoByIPPRecord_DB_Flow() {
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Account_Number__c = :ACCOUNT_NUMBER
            LIMIT 1
        ];
        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Application_ID__c = 'APP_EXISTING',
            FEC_Origination_Channel__c = 'DIGITAL',
            FEC_Customer_History__c = ch.Id
        );
        insert ipp;

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByIPPRecord(ipp.Id);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('APP_EXISTING', result.applicationId);
        System.assertEquals('DIGITAL', result.originationChannel);
    }

    @IsTest
    static void testGetSalesInfoByAccountNumber_Success() {
        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByAccountNumber(ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('APP_API_123', result.applicationId);
        System.assertEquals('DSA_TEST', result.dsaCode);
        System.assertEquals('TSA Name', result.tsaName);
    }

    @IsTest
    static void testGetSalesInfoByAccountNumber_Invalid() {
        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult resultNull =
            FEC_SalesInfoController.getSalesInfoByAccountNumber(null);
        System.assertEquals(false, resultNull.isSuccess);
        System.assertEquals('VALIDATION_ERROR', resultNull.errorCode);

        FEC_SalesInfoController.SalesInfoResult resultFormat =
            FEC_SalesInfoController.getSalesInfoByAccountNumber('ABC');
        System.assertEquals(false, resultFormat.isSuccess);
        System.assertEquals('VALIDATION_ERROR', resultFormat.errorCode);
        Test.stopTest();
    }

    @IsTest
    static void testGetSalesInfoByAccountNumber_NoApplicationId() {
        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock(true));

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByAccountNumber(ACCOUNT_NUMBER);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('NO_DATA', result.errorCode);
    }

    @IsTest
    static void testGetSalesInfoByAccountNumber_PartialIppCallsApi() {
        String partialAccount = '5555666677778888';
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'Partial IPP',
            Status = 'New',
            FEC_ID_Search__c = 'SIC-PT-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'CUST_PT',
            FEC_Account_Number__c = partialAccount
        );
        insert ch;

        insert new FEC_IPP__c(
            FEC_Application_ID__c = 'APP_PARTIAL',
            FEC_Customer_History__c = ch.Id
        );

        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByAccountNumber(partialAccount);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('CC_TEST', result.ccCode);
    }

    @IsTest
    static void testGetSalesInfoByIPPRecord_CaseFallbackAccount() {
        String suffix = String.valueOf(System.currentTimeMillis());
        String fallbackAccount = '9876543210987654';

        Case c = new Case(
            Subject = 'Fallback Account',
            Status = 'New',
            FEC_Account_Number__c = fallbackAccount,
            FEC_ID_Search__c = 'SIC-FB-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'CUST_FB'
        );
        insert ch;

        FEC_IPP__c ipp = new FEC_IPP__c(FEC_Customer_History__c = ch.Id);
        insert ipp;

        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByIPPRecord(ipp.Id);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('APP_API_123', result.applicationId);
    }

    @IsTest
    static void testGetSalesInfoByIPPRecord_NoAccount() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'No Account',
            Status = 'New',
            FEC_ID_Search__c = 'SIC-NA-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'CUST_NA'
        );
        insert ch;

        FEC_IPP__c ipp = new FEC_IPP__c(FEC_Customer_History__c = ch.Id);
        insert ipp;

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByIPPRecord(ipp.Id);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('NO_DATA', result.errorCode);
    }

    @IsTest
    static void testGetSalesInfoByIPPRecord_InvalidId() {
        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByIPPRecord('not-a-valid-id');
        Test.stopTest();

        System.assertEquals(false, result.isSuccess);
        System.assertEquals('QUERY_ERROR', result.errorCode);
    }

    @IsTest
    static void testFetchSalesInfoAsync() {
        FEC_IPP__c ipp = [
            SELECT Id
            FROM FEC_IPP__c
            WHERE FEC_Application_ID__c = null
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.fetchSalesInfoAsync(new Set<Id>{ ipp.Id });
        FEC_SalesInfoController.fetchSalesInfoAsync(new Set<Id>());
        Test.stopTest();

        FEC_IPP__c updated = [
            SELECT FEC_Application_ID__c, FEC_CC_Code__c
            FROM FEC_IPP__c
            WHERE Id = :ipp.Id
        ];
        System.assertEquals('APP_API_123', updated.FEC_Application_ID__c);
        System.assertEquals('CC_TEST', updated.FEC_CC_Code__c);
    }

    @IsTest
    static void testFetchSalesInfoAsync_SkipHasAppId() {
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Application_ID__c = 'APP_EXISTING',
            FEC_Origination_Channel__c = 'DIGITAL',
            FEC_Customer_History__c = ch.Id
        );
        insert ipp;

        Test.startTest();
        FEC_SalesInfoController.fetchSalesInfoAsync(new Set<Id>{ ipp.Id });
        Test.stopTest();

        System.assertEquals('APP_EXISTING', [
            SELECT FEC_Application_ID__c FROM FEC_IPP__c WHERE Id = :ipp.Id
        ].FEC_Application_ID__c);
    }

    @IsTest
    static void testGetSalesInfoByApplicationId_NoData_API() {
        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByApplicationId('NEW_APP_999');
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        System.assertEquals('NEW_APP_999', result.applicationId);
        System.assertEquals('CC_TEST', result.ccCode);
    }

    @IsTest
    static void testGetSalesInfoByApplicationId_NewAccountSave() {
        String newAccount = '1111222233334444';
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'New Account Save',
            Status = 'New',
            FEC_ID_Search__c = 'SIC-NS-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = 'CUST_NS',
            FEC_Account_Number__c = newAccount
        );

        Test.setMock(HttpCalloutMock.class, new MultiSalesInfoMock());

        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult result =
            FEC_SalesInfoController.getSalesInfoByAccountNumber(newAccount);
        Test.stopTest();

        System.assertEquals(true, result.isSuccess);
        Integer ippCount = [
            SELECT COUNT()
            FROM FEC_IPP__c
            WHERE FEC_Customer_History__r.FEC_Account_Number__c = :newAccount
        ];
        System.assert(ippCount > 0, 'Phải tạo IPP mới khi chưa có record.');
    }

    @IsTest
    static void testValidationErrors() {
        Test.startTest();
        FEC_SalesInfoController.SalesInfoResult res1 =
            FEC_SalesInfoController.getSalesInfoByIPPRecord(null);
        System.assertEquals('VALIDATION_ERROR', res1.errorCode);

        FEC_SalesInfoController.SalesInfoResult res2 =
            FEC_SalesInfoController.getSalesInfoByApplicationId('');
        System.assertEquals('VALIDATION_ERROR', res2.errorCode);

        FEC_SalesInfoController.SalesInfoResult res3 =
            FEC_SalesInfoController.getSalesInfoByAccountNumber('');
        System.assertEquals('VALIDATION_ERROR', res3.errorCode);
        Test.stopTest();
    }
}
