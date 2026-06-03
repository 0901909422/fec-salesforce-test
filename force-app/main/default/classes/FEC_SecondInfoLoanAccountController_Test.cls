@IsTest
private class FEC_SecondInfoLoanAccountController_Test {

    private static final String MOCK_LOAN_BASIC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><GetLoanBasicInfoResponse>' +
        '<Sys><Code>1</Code></Sys>' +
        '<LoanBasicInfo><Loan><ApplicationID>APP123</ApplicationID></Loan>' +
        '<PassDue><ResponsibleUnit>Collection Dept</ResponsibleUnit></PassDue>' +
        '</LoanBasicInfo></GetLoanBasicInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_LOAN_SEC_XML =
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<soapenv:Body><GetLoanSecInfoResponse>' +
        '<Sys><Code>1</Code></Sys>' +
        '<LoanSecInfo><PassDue>' +
        '<ResposiblePerson>Nguyen Van A</ResposiblePerson>' +
        '<DateAssgined>2026-05-20</DateAssgined>' +
        '</PassDue></LoanSecInfo></GetLoanSecInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_SALE_DISBURSE_JSON =
        '{' +
        '"Sys":{"TransID":"TXN-SD","DateTime":"2026-10-25T10:00:00.000+07:00","Code":1,"Description":"OK"},' +
        '"CustomerSaleInfos":[{' +
        '"APPLICATION_ID":"APP123","CC_CODE":"CC01","CC_NAME":"Credit Center",' +
        '"DSA_CODE":"DS01","DSA_NAME":"Direct Sales","TSA_CODE":"TS01","TSA_NAME":"Tele Sales",' +
        '"BANK_NAME":"VPBank","BRANCH_NAME":"HCM","BANK_ACCOUNT_NUMBER":"123456789",' +
        '"DISB_CHANNEL":"Bank Transfer","DATE_STATUS":"2026-01-01",' +
        '"TOPUP_FLAG":"Y","TOP_UP_LOAN_AMT":50000000,"TOP_UP_OLD_AC_OUSTANDING":10000000,' +
        '"TOP_UP_AGREEMENT_ID":"OLD_APP123"}]}';

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

        Case c1 = new Case(
            Subject = 'Test Loan Info',
            Status = 'New',
            FEC_ID_Search__c = 'SIL-' + suffix + '-1'
        );
        Case c2 = new Case(
            Subject = 'Test Empty Loan Info',
            Status = 'New',
            FEC_ID_Search__c = 'SIL-' + suffix + '-2'
        );
        Case c3 = new Case(
            Subject = 'Test No Account',
            Status = 'New',
            FEC_ID_Search__c = 'SIL-' + suffix + '-3'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new List<Case>{ c1, c2, c3 };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c1.Id,
            FEC_Contract_Number__c = '12345678-123456-1234',
            FEC_Application_ID__c = 'APP123'
        );
        FEC_Customer_History__c chEmpty = new FEC_Customer_History__c(
            FEC_Case__c = c2.Id
        );
        insert new List<FEC_Customer_History__c>{ ch, chEmpty };

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new List<Case>{
                new Case(Id = c1.Id, FEC_Account_or_Contract__c = ch.Id),
                new Case(Id = c2.Id, FEC_Account_or_Contract__c = chEmpty.Id)
            };
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    // =====================================================================
    // MOCK CLASSES
    // =====================================================================
    private class MultiLoanSoapMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';

            if (body.contains('GetLoanBasicInfo')) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(MOCK_LOAN_BASIC_XML);
            } else if (body.contains('GetLoanSecInfo')) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(MOCK_LOAN_SEC_XML);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(MOCK_SALE_DISBURSE_JSON);
            }
            return res;
        }
    }

    // =====================================================================
    // TEST METHODS
    // =====================================================================

    @IsTest
    static void testLoadSecondaryLoanInfo_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Loan Info' LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MultiLoanSoapMock());

        Test.startTest();
        // Gọi loadSecondaryLoanInfo (Nó gọi ngầm loadSecondaryLoanDisbursement)
        Map<String, Object> result = FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('VPBank', result.get('bankName'), 'Phải lấy đúng Bank Name từ API.');
        System.assertEquals('Yes', result.get('isTopUpAccount'), 'Cờ TopUp Y phải đổi thành Yes.');
    }

    @IsTest
    static void testLoadSecondaryLoanCollections_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Loan Info' LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MultiLoanSoapMock());

        Test.startTest();
        Map<String, Object> result = FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanCollections(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Nguyen Van A', result.get('responsiblePerson'), 'Phải lấy đúng Người phụ trách từ API SecInfo.');
    }

    @IsTest
    static void testLoadSecondaryLoanSales_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Loan Info' LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MultiLoanSoapMock());

        Test.startTest();
        Map<String, Object> result = FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanSales(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('CC01', result.get('ccCode'), 'Phải lấy đúng CC Code từ API SaleDisburse.');
    }

    @IsTest
    static void testRefreshSecondaryLoanInfo_Success() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Test Loan Info' LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MultiLoanSoapMock());

        Test.startTest();
        // Refresh thực hiện gọi lại toàn bộ các API
        Map<String, Object> result = FEC_SecondaryInfoLoanAccountController.refreshSecondaryLoanInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('CC01', result.get('ccCode'));
        System.assertEquals('Nguyen Van A', result.get('responsiblePerson'));
    }

    @IsTest
    static void testValidationErrors() {
        Case cNoAccount = [SELECT Id FROM Case WHERE Subject = 'Test No Account' LIMIT 1];
        Case cEmptyAcc = [SELECT Id FROM Case WHERE Subject = 'Test Empty Loan Info' LIMIT 1];

        Test.startTest();

        // 1. Test Null Case ID
        try {
            FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanInfo(null);
            System.assert(false, 'Phải ném Exception khi truyền CaseId null.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 2. Test Case không liên kết Account
        try {
            FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanInfo(cNoAccount.Id);
            System.assert(false, 'Phải ném Exception khi Case không có Account.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 3. Test Load Collections khi không có Contract Number
        try {
            FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanCollections(cEmptyAcc.Id);
            System.assert(false, 'Phải ném Exception khi không có Contract Number cho Collections.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        // 4. Test Load Sales khi không có Application ID (Và logic sync API Basic cũng thất bại vì ko có Contract Number)
        try {
            FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanSales(cEmptyAcc.Id);
            System.assert(false, 'Phải ném Exception khi không có App ID và Contract Number cho Sales.');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Test.stopTest();
    }
}