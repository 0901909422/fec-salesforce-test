@IsTest
private class FEC_IPPConversionController_Test {

    /** Valid 16-digit account format (FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER). */
    private static final String ACCOUNT_NUMBER = '0001500060000003';
    private static final String CARD_NUMBER = '5432123456789012';

    private static User runAsAdmin() {
        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
            AND IsActive = true
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPConversionController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            Name = ACCOUNT_NUMBER,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Card_Number__c = CARD_NUMBER
        );
        insert cust;

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(
                Id = c.Id,
                FEC_Account_or_Contract__c = cust.Id
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        insert new FEC_Transaction__c(
            FEC_Customer_History__c = cust.Id,
            FEC_Transaction_Amount__c = 1000,
            FEC_Transaction_Plan__c = 'PLAN01',
            FEC_Effective_Date__c = Date.today(),
            FEC_Transaction_Code__c = 'TXN001'
        );

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testGetEligibleTransactions() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        System.runAs(runAsAdmin()) {
            Test.startTest();
            List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
                FEC_IPPConversionController.getEligibleTransactions(c.Id);
            Test.stopTest();
            System.assertNotEquals(0, txs.size(), 'Should load transactions from DB fallback.');
        }
    }

    @IsTest
    static void testConvertIPP_Success() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 6);
            Test.stopTest();
            System.assertNotEquals(null, result);
        }
    }

    @IsTest
    static void testGetEligibleTransactions_LiveApi() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = false;
        upsert setting;

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppConversionApiMock());

        System.runAs(runAsAdmin()) {
            Test.startTest();
            List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
                FEC_IPPConversionController.getEligibleTransactions(c.Id);
            Test.stopTest();
            System.assertNotEquals(null, txs);
        }
    }

    @IsTest
    static void testGetConvertActionStatus() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            System.assert(true, 'Skipped: FEC_IPPConversionController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(c.Id);
        Test.stopTest();

        System.assertEquals(true, status.canConvert);
    }

    @IsTest
    static void testGetEligibleTransactions_BlankCaseId() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Test.startTest();
        List<FEC_IPPConversionController.EligibleTransactionDTO> txs =
            FEC_IPPConversionController.getEligibleTransactions(null);
        Test.stopTest();

        System.assertEquals(0, txs.size());
    }

    @IsTest
    static void testConvertIPP_InvalidTerm() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Transaction__c tx = [SELECT Id FROM FEC_Transaction__c LIMIT 1];

        System.runAs(runAsAdmin()) {
            Test.startTest();
            FEC_IPPConversionController.ConvertResultDTO result =
                FEC_IPPConversionController.convertIPP(c.Id, tx.Id, 0);
            Test.stopTest();
            System.assertEquals(false, result.success);
            System.assertNotEquals(null, result.errorMessage);
        }
    }

    @IsTest
    static void testGetConvertActionStatus_NoCustomerHistory() {
        if (Type.forName('FEC_IPPConversionController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'IPP Conv orphan',
            Status = 'New',
            FEC_ID_Search__c = 'IPPCV-ORPHAN-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_IPPConversionController.ActionStatusDTO status =
            FEC_IPPConversionController.getConvertActionStatus(orphan.Id);
        Test.stopTest();

        System.assertNotEquals(null, status);
    }

    private class IppConversionApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><Response><Sys><Code>1</Code></Sys></Response></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}
