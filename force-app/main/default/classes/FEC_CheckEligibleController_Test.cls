@IsTest
private class FEC_CheckEligibleController_Test {

    private static Id createCaseWithCustomerHistory(String subject, String nationalId, String phone) {
        Case c = new Case(Subject = subject, Status = 'New', Origin = 'Phone');
        insert c;
        FEC_Customer_History__c customer = new FEC_Customer_History__c(
            FEC_Case__c = c.Id,
            FEC_Search_Result_National_ID__c = nationalId,
            FEC_Primary_Phone__c = phone
        );
        insert customer;
        update new Case(Id = c.Id, FEC_Account_or_Contract__c = customer.Id);
        return c.Id;
    }

    private class EligibleSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            System.assert(endpoint.contains('ID_CARD_NUMBER=123456789'), 'National ID should be trimmed before callout.');
            System.assert(endpoint.contains('PHONE_NUMBER=0901234567'), 'Phone should be trimmed before callout.');
            res.setBody('{"Status":"true","Data":{"ID_CARD_NUMBER":"123456789"}}');
            return res;
        }
    }

    private class EligibleDualIdMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            System.assert(
                endpoint.contains('ID_CARD_NUMBER=001234567890'),
                'Dual ID should resolve to CCCD when formats differ.'
            );
            res.setBody('{"Status":"true","Data":{"ID_CARD_NUMBER":"001234567890"}}');
            return res;
        }
    }

    private class EligibleNullPhoneMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            System.assert(endpoint.contains('ID_CARD_NUMBER=123456789'), 'Callout should still run without phone.');
            res.setBody('{"Status":"true","Data":{"ID_CARD_NUMBER":"123456789"}}');
            return res;
        }
    }

    private class EligibleHttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    @IsTest
    static void testCheckCustomerEligibility_NullAndCaseNotFound() {
        Id fakeCaseId = Id.valueOf('500000000000000AAA');

        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse nullResult =
            FEC_CheckEligibleController.checkCustomerEligibility(null);
        FEC_CheckEligibleCallout.CheckEligibleResponse notFoundResult =
            FEC_CheckEligibleController.checkCustomerEligibility(fakeCaseId);
        Test.stopTest();

        System.assertEquals('false', nullResult.Status);
        System.assertEquals('CASE_RESOLUTION', nullResult.errorCode);
        System.assertEquals('false', notFoundResult.Status);
        System.assertEquals('CASE_RESOLUTION', notFoundResult.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_CaseWithoutCustomerHistory() {
        Case c = new Case(Subject = 'No customer history', Status = 'New', Origin = 'Phone');
        insert c;

        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(c.Id);
        Test.stopTest();

        System.assertEquals('false', result.Status);
        System.assertEquals('CASE_RESOLUTION', result.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_MissingNationalId() {
        Id caseId = createCaseWithCustomerHistory('Missing national id', '   ', '0901234567');

        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertEquals('false', result.Status);
        System.assertEquals('CASE_RESOLUTION', result.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_SuccessWithTrimmedInput() {
        Id caseId = createCaseWithCustomerHistory('Eligible success', ' 123456789 ', ' 0901234567 ');

        Test.setMock(HttpCalloutMock.class, new EligibleSuccessMock());
        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertEquals('true', result.Status);
        System.assertEquals(null, result.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_ResolveNationalIdDualId() {
        Id caseId = createCaseWithCustomerHistory(
            'Dual national id',
            '123456789;001234567890',
            '0901234567'
        );

        Test.setMock(HttpCalloutMock.class, new EligibleDualIdMock());
        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertEquals('true', result.Status);
    }

    @IsTest
    static void testCheckCustomerEligibility_NullPhoneStillCalls() {
        Id caseId = createCaseWithCustomerHistory('Null phone', '123456789', null);

        Test.setMock(HttpCalloutMock.class, new EligibleNullPhoneMock());
        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Controller must return a response object.');
        System.assertNotEquals('CASE_RESOLUTION', result.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_DualIdSameFormat() {
        Id caseId = createCaseWithCustomerHistory(
            'Same format dual id',
            '123456789;987654321',
            '0901234567'
        );

        Test.setMock(HttpCalloutMock.class, new EligibleSuccessMock());
        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertEquals('true', result.Status);
        System.assertEquals(null, result.errorCode);
    }

    @IsTest
    static void testCheckCustomerEligibility_OverwriteErrorMessageWhenCalloutFailed() {
        Id caseId = createCaseWithCustomerHistory('Eligible fail', '123456789', '0901234567');

        Test.setMock(HttpCalloutMock.class, new EligibleHttpErrorMock());
        Test.startTest();
        FEC_CheckEligibleCallout.CheckEligibleResponse result =
            FEC_CheckEligibleController.checkCustomerEligibility(caseId);
        Test.stopTest();

        System.assertNotEquals(null, result.errorCode);
        System.assertEquals(System.Label.FEC_MSG_Error_API_Label, result.errorMessage);
    }
}
