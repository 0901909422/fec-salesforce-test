@IsTest
private class FEC_SearchByListNIDsServiceCallout_Test {

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

    private static FEC_SearchByListNIDsServiceCallout.NIDsResponse buildSuccessResponse() {
        FEC_SearchByListNIDsServiceCallout.NIDsResponse mockRes =
            new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
        mockRes.pxObjClass = 'Data-Portal-NIDResponse';

        mockRes.sys = new FEC_SearchByListNIDsServiceCallout.Sys();
        mockRes.sys.code = 200;
        mockRes.sys.description = 'Success';
        mockRes.sys.transID = 'TRX-123456';
        mockRes.sys.datetime4 = '2026-04-02T14:12:25Z';

        FEC_SearchByListNIDsServiceCallout.Result resItem =
            new FEC_SearchByListNIDsServiceCallout.Result();
        resItem.agentCode = 'AG-001';
        resItem.agentName = 'Agent Smith';
        resItem.buyerName = 'John Doe';
        resItem.buyerNID = '123456789';
        resItem.policyNumber = 'POL-998877';
        resItem.collectedPremiumFee = '150.50';
        resItem.StatusDisplay = 'Active';
        resItem.effectiveDate = '2026-01-01';
        resItem.expireDate = '2027-01-01';

        mockRes.result = new List<FEC_SearchByListNIDsServiceCallout.Result>{ resItem };
        return mockRes;
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(JSON.serialize(buildSuccessResponse()));
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    @IsTest
    static void testSearchByListNIDs_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_SearchByListNIDsServiceCallout.NIDsResponse result =
            FEC_SearchByListNIDsServiceCallout.searchByListNIDs(
                new List<String>{ '123456789' }
            );
        Test.stopTest();

        System.assertEquals('Data-Portal-NIDResponse', result.pxObjClass);
        System.assertNotEquals(null, result.sys);
        System.assertEquals(200, result.sys.code);
        System.assertEquals(1, result.result.size());
        System.assertEquals('John Doe', result.result[0].buyerName);
        System.assertEquals('123456789', result.result[0].buyerNID);
    }

    @IsTest
    static void testSearchByListNIDs_HttpError() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        FEC_SearchByListNIDsServiceCallout.NIDsResponse result =
            FEC_SearchByListNIDsServiceCallout.searchByListNIDs(
                new List<String>{ '0123' }
            );
        Test.stopTest();

        System.assertNotEquals(null, result.sys);
        System.assertEquals(500, result.sys.code);
        System.assert(String.isNotBlank(result.sys.description));
        System.assertNotEquals(null, result.sys.transID);
        System.assertEquals(null, result.pxObjClass);
    }

    @IsTest
    static void testSearchByListNIDs_EmptyNationalIdList() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_SearchByListNIDsServiceCallout.NIDsResponse result =
            FEC_SearchByListNIDsServiceCallout.searchByListNIDs(new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Data-Portal-NIDResponse', result.pxObjClass);
    }

    @IsTest
    static void testSearchByListNIDs_MultipleNationalIds() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        FEC_SearchByListNIDsServiceCallout.NIDsResponse result =
            FEC_SearchByListNIDsServiceCallout.searchByListNIDs(
                new List<String>{ '111111111', '222222222' }
            );
        Test.stopTest();

        System.assertNotEquals(null, result.sys);
        System.assertNotEquals(null, result.result);
    }
}
