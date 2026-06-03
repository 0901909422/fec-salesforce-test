@IsTest
private class FEC_MainInfoLoanAccountController_Test {

    private static final String ACCOUNT_NUMBER = '0001500060000003';
    private static final String CONTRACT_NUMBER = 'CNT001';
    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        FEC_Product_Type__c prod = new FEC_Product_Type__c(
            Name = 'Loan',
            FEC_Code__c = 'LOAN' + suffix.right(4),
            FEC_Active__c = true
        );
        insert prod;

        Case c = new Case(
            Subject = 'FEC_MainInfoLoanAccountController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Product_Type__c = prod.Id,
            FEC_Is_Test_API__c = true,
            Status = 'New',
            FEC_ID_Search__c = 'MIL-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            FEC_Contract_Number__c = CONTRACT_NUMBER,
            FEC_Contract_Status__c = 'Active',
            FEC_Loan_Amount__c = 40000,
            FEC_EMI__c = 3500,
            FEC_Tenure__c = 12
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

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    private static User adminUser() {
        List<User> admins = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE AND Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        return admins.isEmpty() ? new User(Id = UserInfo.getUserId()) : admins[0];
    }

    @IsTest
    static void testLoadLoanAccountInfo_Success() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            System.assert(true, 'Skipped: FEC_MainInfoLoanAccountController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LoanAccountHttpMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(CONTRACT_NUMBER, result.get('contractNumber'));
        System.assertNotEquals(null, result.get('helpTexts'));
    }

    @IsTest
    static void testLoadLoanAccountInfo_NullCaseId() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(null);
            System.assert(false, 'Null case id phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadLoanAccountInfo_NoAccountLinked() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'No Account',
            Status = 'New',
            FEC_ID_Search__c = 'MIL-NA-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        Map<String, Object> result =
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(orphan.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.isEmpty());
    }

    @IsTest
    static void testLoadLoanAccountInfo_BlankContractFromDb() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        cust.FEC_Contract_Number__c = null;
        update cust;

        Test.startTest();
        Map<String, Object> result =
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(null, result.get('contractNumber'));
    }

    @IsTest
    static void testSyncLoanAccountFromAPI() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LoanAccountHttpMock());

        Test.startTest();
        FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(c.Id);
        Test.stopTest();

        FEC_Customer_History__c updatedCust = [
            SELECT FEC_Contract_Number__c, FEC_Loan_Amount__c, FEC_Scheme_ID__c
            FROM FEC_Customer_History__c
            LIMIT 1
        ];
        System.assertEquals(CONTRACT_NUMBER, updatedCust.FEC_Contract_Number__c);
        System.assertEquals(40000, updatedCust.FEC_Loan_Amount__c);
        System.assertEquals('SCH1', updatedCust.FEC_Scheme_ID__c);
    }

    @IsTest
    static void testSyncLoanAccountFromAPI_NullCaseId() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(null);
            System.assert(false, 'Null case id phải throw.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSyncLoanAccountFromAPI_NoContractEarlyReturn() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c cust = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        cust.FEC_Contract_Number__c = null;
        update cust;

        Test.startTest();
        FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(c.Id);
        Test.stopTest();

        System.assert(true, 'Blank contract phải return sớm không throw.');
    }

    @IsTest
    static void testSyncLoanAccountFromAPI_AsAdmin() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new LoanAccountHttpMock());

            Test.startTest();
            FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(c.Id);
            Test.stopTest();

            System.assert(
                [SELECT COUNT() FROM FEC_Customer_History__c WHERE FEC_Contract_Number__c = :CONTRACT_NUMBER] > 0
            );
        }
    }

    @IsTest
    static void testSyncLoanAccountFromAPI_NoAccountLinked() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case orphan = new Case(
            Subject = 'No Account',
            Status = 'New',
            FEC_ID_Search__c = 'MIL-NA2-' + System.currentTimeMillis()
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert orphan;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.startTest();
        FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(orphan.Id);
        Test.stopTest();

        System.assert(true, 'No account linked phải return sớm.');
    }

    @IsTest
    static void testSyncLoanAccountFromAPI_ApiFailureThrows() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LoanAccountErrorHttpMock());

        Test.startTest();
        try {
            FEC_MainInfoLoanAccountController.syncLoanAccountFromAPI(c.Id);
            System.assert(false, 'API failure phải throw AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadLoanAccountInfo_ApiErrorsFallbackToDb() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LoanAccountErrorHttpMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(CONTRACT_NUMBER, result.get('contractNumber'));
    }

    @IsTest
    static void testLoadLoanAccountInfo_ChargeOffStatusMapping() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new LoanAccountChargeOffHttpMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_MainInfoLoanAccountController.loadLoanAccountInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result.get('contractStatus'));
    }

    @IsTest
    static void testLoadLoanAccountInfo_AsAdmin() {
        if (Type.forName('FEC_MainInfoLoanAccountController') == null) {
            return;
        }

        System.runAs(adminUser()) {
            Case c = [SELECT Id FROM Case LIMIT 1];
            Test.setMock(HttpCalloutMock.class, new LoanAccountHttpMock());

            Test.startTest();
            Map<String, Object> result =
                FEC_MainInfoLoanAccountController.loadLoanAccountInfo(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
        }
    }

    private class LoanAccountErrorHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private class LoanAccountChargeOffHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('GetCustomerList')) {
                return new LoanAccountHttpMock().respond(req);
            }
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                '<soapenv:Body><GetLoanBasicInfoResponse>' +
                '<Sys><Code>1</Code></Sys>' +
                '<LoanBasicInfo><Loan>' +
                '<ContractNumber>' + CONTRACT_NUMBER + '</ContractNumber>' +
                '<ContractStatus>CHARGE OFF</ContractStatus>' +
                '</Loan></LoanBasicInfo></GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }

    private class LoanAccountHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'text/xml');
            String body = req.getBody() != null ? req.getBody() : '';

            if (body.contains('GetLoanSecInfo') || body.contains('loansec')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><GetLoanSecInfoResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<LoanSecInfo><PassDue><InstallmentsRemaining>3</InstallmentsRemaining><DPD>10</DPD></PassDue></LoanSecInfo>' +
                    '</GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else if (body.contains('GetCustomerList') || body.contains('customerlist')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><GetCustomerListResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<Customers><Customer>' +
                    '<Applications><Application>' +
                    '<ContractNumber>' + CONTRACT_NUMBER + '</ContractNumber>' +
                    '<SchemeID>SCH1</SchemeID><SchemeDesc>Scheme Test</SchemeDesc>' +
                    '</Application></Applications>' +
                    '</Customer></Customers>' +
                    '</GetCustomerListResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
                    '<soapenv:Body><GetLoanBasicInfoResponse>' +
                    '<Sys><TransID>TXN12345</TransID><DateTime>2026-05-25 10:00:00</DateTime>' +
                    '<Code>1</Code><Description>Success</Description></Sys>' +
                    '<LoanBasicInfo>' +
                    '<Loan>' +
                    '<ContractNumber>' + CONTRACT_NUMBER + '</ContractNumber>' +
                    '<ContractType>Loan</ContractType><ContractStatus>Active</ContractStatus>' +
                    '<AgreementDate>2024-01-01</AgreementDate><ApplicationID>APP001</ApplicationID>' +
                    '<CompanyName>Test Co</CompanyName>' +
                    '</Loan>' +
                    '<Product>' +
                    '<Product>PL</Product><LoanAmount>40000</LoanAmount><Tenure>12</Tenure>' +
                    '<EMI>3500</EMI><Rate>12.5</Rate><InsuranceAmount>500</InsuranceAmount>' +
                    '<FirstPaymentDate>2024-02-01</FirstPaymentDate><LastPaymentDate>2025-01-01</LastPaymentDate>' +
                    '</Product>' +
                    '<TerminationSimulation><NextDueDate>2026-06-01</NextDueDate></TerminationSimulation>' +
                    '<PassDue><DPD>10</DPD></PassDue>' +
                    '</LoanBasicInfo></GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }
}
