@IsTest
private class FEC_PinReplacementController_Test {

    private static final String PIN_SUCCESS_JSON =
        '{"RespCode":"0","TransID":"12345","RespDesc":"Success"}';

    @TestSetup
    static void setupData() {
        FEC_CaseTriggerHandler.isExecuting = true;
        try {
            insert new Case(
                FEC_National_ID_Passport_ID__c = '123456789',
                FEC_Case_Phone_Number__c = '0901234567',
                FEC_Is_Test_API__c = true,
                Status = 'New'
            );
        } finally {
            FEC_CaseTriggerHandler.isExecuting = false;
        }
    }

    @IsTest
    static void testPinReplacement_Success() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PinReissueHttpMock(200, PIN_SUCCESS_JSON));

        Test.startTest();
        FEC_PinReplacementController.UpdateResult result =
            FEC_PinReplacementController.pinReplacement(c.Id, 'TestMethod');
        Test.stopTest();

        System.assertEquals(true, result.success, 'API success → result.success = true.');
        System.assertEquals(-1, result.actionCount);

        Case updatedCase = [SELECT FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            -1,
            updatedCase.FEC_Process_Action_Count__c,
            'Nếu thành công, action count phải bằng -1.'
        );
    }

    @IsTest
    static void testPinReplacement_FailureAndIncrement() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        c.FEC_National_ID_Passport_ID__c = null;
        update c;

        Test.setMock(HttpCalloutMock.class, new PinReissueHttpMock(500, 'Internal Server Error'));

        Test.startTest();
        FEC_PinReplacementController.UpdateResult result =
            FEC_PinReplacementController.pinReplacement(c.Id, 'TestFail');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals(1, result.actionCount);

        Case updatedCase = [SELECT FEC_Process_Action_Count__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            1,
            updatedCase.FEC_Process_Action_Count__c,
            'Nếu thất bại, action count phải tăng lên 1.'
        );
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
