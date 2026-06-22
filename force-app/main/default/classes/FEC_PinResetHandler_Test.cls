@IsTest
private class FEC_PinResetHandler_Test {

    private static final String PIN_RESET_SUCCESS_JSON =
        '{"AccountNumber":"ACC123","CardNumber":"4111111111115432","Sys":{"Code":"1","Description":"Success","TransID":"12345"}}';
    private static final String PIN_RESET_FAIL_JSON =
        '{"AccountNumber":"ACC123","CardNumber":"4111111111115432","Sys":{"Code":"99","Description":"Failed","TransID":"12345"}}';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        insert new FEC_API_Setting__c(
            FEC_Endpoint__c = 'https://api-gateway.fecredit.com.vn'
        );

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                FEC_Process_Action_Count__c = 3,
                FEC_Is_PIN_Reset_Success__c = false,
                FEC_Is_Test_API__c = true,
                FEC_Account_Number__c = 'ACC123',
                Status = 'New'
            );
            insert c;

            FEC_Customer_History__c ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CH-' + suffix,
                FEC_National_ID_Passport_ID__c = '123456789',
                FEC_Primary_Phone__c = '0901234567',
                FEC_Card_Number__c = '4111111111115432'
            );
            insert ch;

            c.FEC_Account_or_Contract__c = ch.Id;
            update c;
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testGetCardInfo_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        FEC_PinResetHandler.CardInfoResponse resp = FEC_PinResetHandler.getCardInfo(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals('123456789', resp.nationalId);
        System.assertEquals(3, resp.processActionCount);
    }

    @IsTest
    static void testResetPin_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PinResetCounterHttpMock(200, PIN_RESET_SUCCESS_JSON));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse resp = FEC_PinResetHandler.resetPin(
            c.Id,
            '123456789',
            '0901234567',
            'Reset PIN'
        );
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals('0', resp.RespCode);

        Case updatedCase = [
            SELECT FEC_Is_PIN_Reset_Success__c, FEC_Process_Action_Count__c
            FROM Case
            WHERE Id = :c.Id
        ];
        System.assertEquals(true, updatedCase.FEC_Is_PIN_Reset_Success__c);
        System.assertEquals(2, updatedCase.FEC_Process_Action_Count__c);
    }

    @IsTest
    static void testResetPin_Failure() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PinResetCounterHttpMock(200, PIN_RESET_FAIL_JSON));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse resp = FEC_PinResetHandler.resetPin(
            c.Id,
            '123456789',
            '0901234567',
            'Reset PIN'
        );
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals('1', resp.RespCode);

        Case updatedCase = [SELECT FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(4, updatedCase.FEC_Process_Action_Count__c);
    }

    @IsTest
    static void testGetCardInfo_NotFound() {
        Test.startTest();
        try {
            FEC_PinResetHandler.getCardInfo(UserInfo.getUserId());
            System.assert(false, 'Phải ném AuraHandledException.');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
        Test.stopTest();
    }

    private class PinResetCounterHttpMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        PinResetCounterHttpMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}
