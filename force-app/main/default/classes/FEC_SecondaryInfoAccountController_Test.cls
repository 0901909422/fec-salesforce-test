@IsTest
private class FEC_SecondaryInfoAccountController_Test {

    private static final String SOAP_ENV = FEC_ConstantCommon.SOAP_ENV;

    private static final String MOCK_CARD_SEC_XML =
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="' + SOAP_ENV + '">' +
        '<soapenv:Body><GetCardSecInfoResponse>' +
        '<Sys><Code>1</Code><Description>OK</Description></Sys>' +
        '<CardSecInfo>' +
        '<MainCardProduct>' +
        '<DailyRetailLimit>10000</DailyRetailLimit>' +
        '<DailyRetailNumber>5</DailyRetailNumber>' +
        '<DailyCashLimit>2000</DailyCashLimit>' +
        '<DailyCashNumber>3</DailyCashNumber>' +
        '<LastCreditLimit>5000000</LastCreditLimit>' +
        '<LastCreditLimitDate>20260101</LastCreditLimitDate>' +
        '<LastDelinquencyDate>20260201</LastDelinquencyDate>' +
        '<StatementNotificationType>Email</StatementNotificationType>' +
        '</MainCardProduct>' +
        '<MainCardPlastic><EmbossingName>NGUYEN VAN A</EmbossingName></MainCardPlastic>' +
        '<PassDue>' +
        '<ResponsibleUnit>Collection Dept</ResponsibleUnit>' +
        '<ResposiblePerson>Agent One</ResposiblePerson>' +
        '<DateAssgined>20260301</DateAssgined>' +
        '</PassDue>' +
        '</CardSecInfo>' +
        '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>';

    private static final String MOCK_SALE_JSON =
        '{' +
        '"Sys":{"TransID":"TXN-SALE","DateTime":"2026-05-29T10:00:00.000+07:00","Code":1,"Description":"OK"},' +
        '"CustomerSaleInfos":[{' +
        '"APPLICATION_ID":"APP123",' +
        '"CC_CODE":"CC01","CC_NAME":"Credit Center",' +
        '"DSA_CODE":"DS01","DSA_NAME":"Direct Sales",' +
        '"TSA_CODE":"TS01","TSA_NAME":"Tele Sales"' +
        '}]' +
        '}';

    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        upsert apiSetting;

        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'Credit Card',
            FEC_Code__c = 'CC',
            FEC_Active__c = true
        );
        insert pt;

        String suffix = String.valueOf(System.currentTimeMillis());
        Case c = new Case(
            Subject = 'Secondary Info Test',
            Status = 'New',
            FEC_Product_Type__c = pt.Id,
            FEC_Is_Test_API__c = false,
            FEC_ID_Search__c = 'SIA-' + suffix
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c ch = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Account_Number__c = '1234567890123456',
            FEC_Contract_Number__c = '12345678-123456-1234',
            FEC_CIF_Number__c = 'CIF001',
            FEC_Application_ID__c = 'APP123'
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

    private class SecondaryApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            String endpoint = req.getEndpoint() != null ? req.getEndpoint() : '';

            if (body.contains('GetCardSecInfo') || endpoint.contains('CardSec')) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(MOCK_CARD_SEC_XML);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(MOCK_SALE_JSON);
            }
            return res;
        }
    }

    private class FailingCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private static Case getTestCase() {
        return [SELECT Id FROM Case LIMIT 1];
    }

    @IsTest
    static void testLoadSecondaryAccount_Success() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());

        Test.startTest();
        FEC_SecondaryInfoAccountController.SecondaryAccountDTO result =
            FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.helpTexts);
        System.assertEquals('NGUYEN VAN A', result.embossingName);
        System.assertEquals('Email', result.statementNotificationType);
        System.assertEquals('Collection Dept', result.responsibleUnit);
        System.assertEquals('CC01', result.ccCode);
        System.assertEquals('Credit Center', result.ccName);
        System.assertEquals('DS01', result.dsaCode);
        System.assertEquals('TS01', result.tsaCode);
        System.assert(String.isNotBlank(result.dailyRetailLimit));
    }

    @IsTest
    static void testRefreshSecondaryAccount_Success() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());

        Test.startTest();
        FEC_SecondaryInfoAccountController.SecondaryAccountDTO result =
            FEC_SecondaryInfoAccountController.refreshSecondaryAccount(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Tele Sales', result.tsaName);
        System.assertEquals('Direct Sales', result.dsaName);
    }

    @IsTest
    static void testLoadSecondaryAccount_CardApiFailure() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new FailingCalloutMock());

        Test.startTest();
        try {
            FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
            System.assert(false, 'Phải ném AuraHandledException khi Card API lỗi.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadSecondaryAccount_TestApiFlagThrows() {
        Case c = getTestCase();
        c.FEC_Is_Test_API__c = true;
        update c;

        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());

        Test.startTest();
        try {
            FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
            System.assert(false, 'FEC_Is_Test_API__c=true phải fail Card API.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadSecondaryAccount_NoCustomerHistory() {
        Case c = new Case(
            Subject = 'No CH secondary',
            Status = 'New',
            FEC_ID_Search__c = 'SIA-NOCH-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());

        Test.startTest();
        try {
            FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
            System.assert(false, 'Phải throw khi Case không có Customer History.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testLoadSecondaryAccount_PersistsCustomerHistory() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());

        Test.startTest();
        FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
        Test.stopTest();

        Id customerHistoryId = [
            SELECT FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :c.Id
        ].FEC_Account_or_Contract__c;

        FEC_Customer_History__c ch = [
            SELECT
                FEC_Daily_Retail_Limit__c,
                FEC_Embossing_Name__c,
                FEC_CC_Code__c,
                FEC_TSA_Name__c
            FROM FEC_Customer_History__c
            WHERE Id = :customerHistoryId
        ];
        System.assertEquals(10000, ch.FEC_Daily_Retail_Limit__c);
        System.assertEquals('NGUYEN VAN A', ch.FEC_Embossing_Name__c);
        System.assertEquals('CC01', ch.FEC_CC_Code__c);
        System.assertEquals('Tele Sales', ch.FEC_TSA_Name__c);
    }

    @IsTest
    static void testLoadSecondaryAccount_MockMode() {
        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = true;
        upsert setting;

        Case c = getTestCase();
        Test.startTest();
        FEC_SecondaryInfoAccountController.SecondaryAccountDTO result =
            FEC_SecondaryInfoAccountController.loadSecondaryAccount(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testRefreshSecondaryAccount_NoCustomerHistory() {
        Case c = new Case(
            Subject = 'Refresh no CH',
            Status = 'New',
            FEC_ID_Search__c = 'SIA-REF-' + String.valueOf(System.currentTimeMillis())
        );
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        Test.setMock(HttpCalloutMock.class, new SecondaryApiMock());
        Test.startTest();
        try {
            FEC_SecondaryInfoAccountController.refreshSecondaryAccount(c.Id);
            System.assert(false, 'Phải throw khi refresh không có Customer History.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }
}
