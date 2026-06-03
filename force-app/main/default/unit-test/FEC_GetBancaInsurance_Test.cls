@IsTest
private class FEC_GetBancaInsurance_Test {
    @TestSetup
    static void setupData() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        if (apiSetting == null) {
            apiSetting = new FEC_API_Setting__c();
        }
        apiSetting.FEC_Endpoint__c = 'https://test-api.fecredit.com.vn';
        apiSetting.FEC_Call_Mock__c = false;
        upsert apiSetting;
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody().contains('nationalID'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"result":[{"userID":"U001","buyerName":"John Doe","buyerDOB":"1990-01-01","buyerNID":"123456789","productNameEn":"Product A","collectedPremiumFee":"100.5","paymentID":"PAY-001","effectiveDate":"2026-01-01","StatusDisplay":"Active","policyNumber":"POL-001","insurerCompany":"Insurer A","MarkedBuyerNID":"***6789"}]}'
            );
            return res;
        }
    }

    private class ErrorStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal"}');
            return res;
        }
    }

    private class InvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{invalid-json');
            return res;
        }
    }

    @IsTest
    static void testSearchByNIDs_nullAndEmptyInput() {
        Test.startTest();
        List<FEC_GetBancaInsurance.InsuranceResult> resNull = FEC_GetBancaInsurance.searchByNIDs(null);
        List<FEC_GetBancaInsurance.InsuranceResult> resEmpty = FEC_GetBancaInsurance.searchByNIDs(new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, resNull);
        System.assertEquals(0, resNull.size());
        System.assertEquals(0, resEmpty.size());
    }

    @IsTest
    static void testSearchByNIDs_success200_parseResult() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<FEC_GetBancaInsurance.InsuranceResult> results =
            FEC_GetBancaInsurance.searchByNIDs(new List<String>{ '123456789' });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should parse one result item.');
        System.assertEquals('U001', results[0].userId);
        System.assertEquals('John Doe', results[0].buyerName);
        System.assertEquals('Active', results[0].statusDisplay);
        System.assertEquals('***6789', results[0].markedBuyerNID);
    }

    @IsTest
    static void testSearchByNIDs_non200_returnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new ErrorStatusMock());

        Test.startTest();
        List<FEC_GetBancaInsurance.InsuranceResult> results =
            FEC_GetBancaInsurance.searchByNIDs(new List<String>{ '111111111' });
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size(), 'Non-200 response should return empty list.');
    }

    @IsTest
    static void testSearchByNIDs_invalidJson_returnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new InvalidJsonMock());

        Test.startTest();
        List<FEC_GetBancaInsurance.InsuranceResult> results =
            FEC_GetBancaInsurance.searchByNIDs(new List<String>{ '222222222' });
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size(), 'Parse errors should be swallowed and return empty list.');
    }
}
