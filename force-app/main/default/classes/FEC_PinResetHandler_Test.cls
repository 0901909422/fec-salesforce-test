@IsTest
private class FEC_PinResetHandler_Test {

    private static final String PIN_SUCCESS_JSON =
        '{"RespCode":"0","TransID":"12345","RespDesc":"Success"}';
    private static final String PIN_FAIL_JSON =
        '{"RespCode":"1","TransID":"12345","RespDesc":"Failed"}';

    @TestSetup
    static void setupData() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);

        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            Case c = new Case(
                FEC_Process_Action_Count__c = 3,
                FEC_Is_PIN_Reset_Success__c = false,
                FEC_Is_Test_API__c = true,
                Status = 'New'
            );
            insert c;

            FEC_Customer_History__c ch = new FEC_Customer_History__c(
                FEC_Case__c = c.Id,
                Name = 'CH-' + suffix,
                FEC_National_ID_Passport_ID__c = '123456789',
                FEC_Primary_Phone__c = '0901234567'
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
        Test.setMock(HttpCalloutMock.class, new PinReissueHttpMock(200, PIN_SUCCESS_JSON));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse resp = FEC_PinResetHandler.resetPin(
            c.Id,
            '123456789',
            '0901234567'
        );
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertNotEquals('1', resp.RespCode);

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
        Test.setMock(HttpCalloutMock.class, new PinReissueHttpMock(200, PIN_FAIL_JSON));

        Test.startTest();
        FEC_PINReissueServiceCallout.PINResponse resp = FEC_PinResetHandler.resetPin(
            c.Id,
            '123456789',
            '0901234567'
        );
        Test.stopTest();

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

    private class PinReissueHttpMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        PinReissueHttpMock(Integer statusCode, String body) {
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
