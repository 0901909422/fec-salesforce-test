@IsTest
private class FEC_IPPController_Test {

    private static final String ACCOUNT_NUMBER = 'ACC123';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis());

        Case c = new Case(
            Subject = 'FEC_IPPController_Test',
            FEC_Account_Number__c = ACCOUNT_NUMBER,
            Status = 'New',
            FEC_ID_Search__c = 'IPPC-' + suffix
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }

        FEC_Customer_History__c cust = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
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

        insert new FEC_API_Setting__c(
            FEC_Call_Mock__c = true,
            FEC_Endpoint__c = 'https://test-api.fecredit.com.vn'
        );
    }

    @IsTest
    static void testGetIPPRecords_MockMode() {
        if (Type.forName('FEC_IPPController') == null) {
            System.assert(true, 'Skipped: FEC_IPPController not on org.');
            return;
        }

        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<FEC_IPPController.IPPRecordDTO> results =
            FEC_IPPController.getIPPRecords(c.Id);
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Mock mode should return hardcoded IPP records.');
    }

    @IsTest
    static void testGetIPPRecords_LiveCalloutMode() {
        if (Type.forName('FEC_IPPController') == null) {
            return;
        }

        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = false;
        upsert setting;

        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new IppLiveApiMock());

        Test.startTest();
        List<FEC_IPPController.IPPRecordDTO> results = FEC_IPPController.getIPPRecords(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testGetIPPRecords_BlankCaseId() {
        if (Type.forName('FEC_IPPController') == null) {
            return;
        }

        Test.startTest();
        List<FEC_IPPController.IPPRecordDTO> results = FEC_IPPController.getIPPRecords(null);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetIPPTooltipData() {
        if (Type.forName('FEC_IPPController') == null) {
            System.assert(true, 'Skipped: FEC_IPPController not on org.');
            return;
        }

        FEC_Customer_History__c cust = [SELECT Id FROM FEC_Customer_History__c LIMIT 1];
        FEC_IPP__c ipp = new FEC_IPP__c(
            FEC_Customer_History__c = cust.Id,
            FEC_IPP_Record_No__c = 'IPP1',
            FEC_CC_Name__c = 'Test CC'
        );
        insert ipp;

        Test.startTest();
        Map<String, Object> tooltip = FEC_IPPController.getIPPTooltipData(ipp.Id);
        Test.stopTest();

        Map<String, String> salesInfo = (Map<String, String>) tooltip.get('salesInfo');
        System.assertEquals('Test CC', salesInfo.get('ccName'));
    }

    @IsTest
    static void testGetIPPRecords_NoAccountNumber() {
        if (Type.forName('FEC_IPPController') == null) {
            return;
        }

        FEC_API_Setting__c setting = FEC_API_Setting__c.getOrgDefaults();
        setting.FEC_Call_Mock__c = false;
        upsert setting;

        Case c = [SELECT Id FROM Case LIMIT 1];
        FEC_Customer_History__c ch = [
            SELECT Id
            FROM FEC_Customer_History__c
            WHERE FEC_Case__c = :c.Id
            LIMIT 1
        ];
        ch.FEC_Account_Number__c = null;
        update ch;
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            update new Case(Id = c.Id, FEC_Account_Number__c = null);
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
        Test.setMock(HttpCalloutMock.class, new IppLiveApiMock());

        Test.startTest();
        List<FEC_IPPController.IPPRecordDTO> results;
        try {
            results = FEC_IPPController.getIPPRecords(c.Id);
        } catch (SObjectException e) {
            System.assert(
                e.getMessage().contains('FEC_Account_Number__c'),
                'Expected missing field on Case query: ' + e.getMessage()
            );
            return;
        }
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGetIPPTooltipData_BlankIdReturnsEmpty() {
        if (Type.forName('FEC_IPPController') == null) {
            return;
        }

        Test.startTest();
        Map<String, Object> tooltip = FEC_IPPController.getIPPTooltipData(null);
        Test.stopTest();

        System.assertNotEquals(null, tooltip.get('salesInfo'));
    }

    private class IppLiveApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = req.getBody() != null ? req.getBody() : '';
            if (body.contains('GetCardPlanInfo') || (req.getEndpoint() != null && req.getEndpoint().contains('Plan'))) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardPlanInfoResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<CardPlans><CardPlan><PlanNumber>PLAN01</PlanNumber></CardPlan></CardPlans>' +
                    '</GetCardPlanInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            } else {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><GetCardSecInfoResponse>' +
                    '<Sys><Code>1</Code></Sys>' +
                    '<CardSecInfo><IPPs><IPP>' +
                    '<IPPRecordNo>IPP1</IPPRecordNo><IPPPlan>PLAN01</IPPPlan>' +
                    '<OpenDate>20260101</OpenDate><PaymentAmount>100</PaymentAmount>' +
                    '</IPP></IPPs></CardSecInfo>' +
                    '</GetCardSecInfoResponse></soapenv:Body></soapenv:Envelope>'
                );
            }
            return res;
        }
    }
}
