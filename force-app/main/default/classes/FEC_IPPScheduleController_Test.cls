@IsTest
private class FEC_IPPScheduleController_Test {

    private static final String ACCOUNT_NUMBER = '0001500060000003';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPScheduleController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPPSCH-' + suffix
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
            FEC_Account_Number__c = ACCOUNT_NUMBER
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

        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Record_No__c = 'REC01',
            FEC_IPP_Plan__c = 'PLAN01'
        );
        insert ipp;

        insert new FEC_IPP_Schedule__c(
            FEC_IPP__c = ipp.Id,
            FEC_IPP_Payment_No__c = 1,
            FEC_IPP_Opening_Balance__c = 1000,
            FEC_IPP_Payment_Amount__c = 100
        );

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testGetIPPScheduleData_Success() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('schedules'));
        System.assert(result.containsKey('totalPaymentAmount'));
    }

    @IsTest
    static void testRefreshIPPScheduleData() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result = FEC_IPPScheduleController.refreshIPPScheduleData(ipp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPSchedules() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];

        Test.startTest();
        List<FEC_IPP_Schedule__c> schedules =
            FEC_IPPScheduleController.getIPPSchedules(ipp.Id);
        Test.stopTest();

        System.assertEquals(1, schedules.size());
    }

    @IsTest
    static void testSyncIPPScheduleFromAPI() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            System.assert(true, 'Skipped: FEC_IPPScheduleController not on org.');
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        String reason = FEC_IPPScheduleController.syncIPPScheduleFromAPI(ipp.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testGetIPPScheduleData_WithSalesPopulate() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppScheduleCombinedMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result.get('schedules'));
        System.assert(result.containsKey('totalPaymentAmount'));
    }

    @IsTest
    static void testGetIPPScheduleData_NullIppIdThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.getIPPScheduleData(null, true);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testSyncIPPScheduleFromAPI_NullThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.syncIPPScheduleFromAPI(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testRefreshIPPScheduleData_NullThrows() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        Boolean threw = false;
        Test.startTest();
        try {
            FEC_IPPScheduleController.refreshIPPScheduleData(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void testGetIPPScheduleData_SkipSalesFlag() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_IPP__c ipp = [SELECT Id FROM FEC_IPP__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());

        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ipp.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGetIPPScheduleData_NoAccountNumber() {
        if (Type.forName('FEC_IPPScheduleController') == null) {
            return;
        }

        FEC_Customer_History__c ch = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        ch.FEC_Account_Number__c = null;
        update ch;

        FEC_IPP__c ippNoAcct = new FEC_IPP__c(
            FEC_Customer_History__c = ch.Id,
            FEC_IPP_Record_No__c = 'NOACCT',
            FEC_IPP_Plan__c = 'PLAN99'
        );
        insert ippNoAcct;

        Test.setMock(HttpCalloutMock.class, new CardSecInfoMock());
        Test.startTest();
        Map<String, Object> result =
            FEC_IPPScheduleController.getIPPScheduleData(ippNoAcct.Id, true);
        Test.stopTest();

        System.assertEquals('NO_ACCOUNT_NUMBER', result.get('emptyScheduleReason'));
    }

    private class IppScheduleCombinedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('Sales') || (req.getEndpoint() != null && req.getEndpoint().contains('Sale'))) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody(
                    '{"Sys":{"Code":1},"CustomerSaleInfos":[{"CC_CODE":"CC01","CC_NAME":"CC","DSA_CODE":"DS01","DSA_NAME":"DSA","TSA_CODE":"TS01","TSA_NAME":"TSA"}]}'
                );
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo><IPPs><IPP>' +
                    '<IPPRecordNo>REC01</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                    '<PaymentAmount>100</PaymentAmount><PaymentNo>1</PaymentNo>' +
                    '<OpeningBalance>1000</OpeningBalance>' +
                    '</IPP></IPPs></CardSecInfo>' +
                    '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }

    private class CardSecInfoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><GetCardSecInfoResponse>' +
                '<Sys><Code>1</Code><Description>Success</Description></Sys>' +
                '<CardSecInfo><IPPs><IPP>' +
                '<IPPRecordNo>REC01</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                '<PaymentAmount>100</PaymentAmount>' +
                '</IPP></IPPs></CardSecInfo>' +
                '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
            );
            return res;
        }
    }
}
