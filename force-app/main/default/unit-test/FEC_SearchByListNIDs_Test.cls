/**
 * Unit tests for FEC_SearchByListNIDs (Banca insurance search by national ID list).
 */
@IsTest
private class FEC_SearchByListNIDs_Test {

    private static final String NID_1 = '012345678901';
    private static final String NID_2 = '098765432109';

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

    private static String successResponseBody() {
        return '{' +
            '"result": [{' +
            '"userID": "USR001",' +
            '"buyerName": "Nguyen Van A",' +
            '"buyerDOB": "1990-01-01",' +
            '"buyerNID": "' + NID_1 + '",' +
            '"productNameEn": "Life Product",' +
            '"collectedPremiumFee": "5000000",' +
            '"paymentID": "PAY001",' +
            '"effectiveDate": "2026-01-01",' +
            '"StatusDisplay": "Active",' +
            '"policyNumber": "POL123",' +
            '"insurerCompany": "Insurer Co",' +
            '"MarkedBuyerNID": "' + NID_1 + '"' +
            '}]' +
            '}';
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(successResponseBody());
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    private class EmptyBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    private class InvalidJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('not-json');
            return res;
        }
    }

    private class NullResultMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"sys":{"code":1}}');
            return res;
        }
    }

    @IsTest
    static void testSearchByNIDs_NullAndEmpty_ReturnEmpty() {
        System.assertEquals(0, FEC_SearchByListNIDs.searchByNIDs(null).size());
        System.assertEquals(0, FEC_SearchByListNIDs.searchByNIDs(new List<String>()).size());
        System.assertEquals(0, FEC_SearchByListNIDs.searchByNIDsReal(null).size());
        System.assertEquals(0, FEC_SearchByListNIDs.searchByNIDsReal(new List<String>()).size());
    }

    @IsTest
    static void testSearchByNIDsReal_Success_ParsesInsuranceResults() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDsReal(new List<String>{ NID_1 });
        Test.stopTest();

        System.assertEquals(1, results.size());
        FEC_SearchByListNIDs.InsuranceResult row = results[0];
        System.assertEquals('USR001', row.userId);
        System.assertEquals('Nguyen Van A', row.buyerName);
        System.assertEquals('1990-01-01', row.buyerDOB);
        System.assertEquals(NID_1, row.buyerNID);
        System.assertEquals('Life Product', row.productNameEn);
        System.assertEquals('5000000', row.collectedPremiumFee);
        System.assertEquals('PAY001', row.paymentID);
        System.assertEquals('2026-01-01', row.effectiveDate);
        System.assertEquals('Active', row.statusDisplay);
        System.assertEquals('POL123', row.policyNumber);
        System.assertEquals('Insurer Co', row.insurerCompany);
        System.assertEquals(NID_1, row.markedBuyerNID);
    }

    @IsTest
    static void testSearchByNIDs_DelegatesToReal() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDs(new List<String>{ NID_1, NID_2 });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(NID_1, results[0].buyerNID);
    }

    @IsTest
    static void testSearchByNIDsReal_HttpError_ReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDsReal(new List<String>{ NID_1 });
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchByNIDsReal_EmptyBody_ReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDsReal(new List<String>{ NID_1 });
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchByNIDsReal_InvalidJson_ReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new InvalidJsonMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDsReal(new List<String>{ NID_1 });
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchByNIDsReal_MissingResultKey_ReturnsEmpty() {
        Test.setMock(HttpCalloutMock.class, new NullResultMock());

        Test.startTest();
        List<FEC_SearchByListNIDs.InsuranceResult> results =
            FEC_SearchByListNIDs.searchByNIDsReal(new List<String>{ NID_1 });
        Test.stopTest();

        System.assertEquals(0, results.size());
    }
}
