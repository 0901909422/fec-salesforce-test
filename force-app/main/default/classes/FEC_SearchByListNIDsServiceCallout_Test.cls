@isTest
global with sharing class FEC_SearchByListNIDsServiceCallout_Test {
    
    @isTest
    static void testCalloutShouldWork() {
        // Assign the mock implementation to the test context
        Test.setMock(HttpCalloutMock.class, new FEC_SearchByListNIDsMock());
        // This should be the class/method that performs the WebService callout
        Test.startTest();
         FEC_SearchByListNIDsServiceCallout.NIDsResponse resItem = FEC_SearchByListNIDsServiceCallout.searchByListNIDs(new List<String> {'0123'});
        Test.stopTest();

        System.Assert.areEqual('Data-Portal-NIDResponse', resItem.pxObjClass, 'Response shoul be not null');
    }

    @isTest
    static void testCalloutShouldReturnError() {
        // Assign the mock implementation to the test context
        Test.setMock(HttpCalloutMock.class, new FEC_SearchByListNIDsMockError());
        // This should be the class/method that performs the WebService callout
        Test.startTest();
        FEC_SearchByListNIDsServiceCallout.NIDsResponse resItem;
        try {
            resItem = FEC_SearchByListNIDsServiceCallout.searchByListNIDs(new List<String> {'0123'});
            
        } catch (Exception ex) {
            System.Assert.areEqual('', resItem.pxObjClass, 'Response shoul be  null');
        }
        Test.stopTest();
    }

    global class FEC_SearchByListNIDsMock implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            // Create the top-level response object
            FEC_SearchByListNIDsServiceCallout.NIDsResponse mockRes = new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
            mockRes.pxObjClass = 'Data-Portal-NIDResponse';
            
            // Populate Sys2 (Metadata/Status)
            mockRes.sys2 = new FEC_SearchByListNIDsServiceCallout.Sys2();
            mockRes.sys2.code2 = '200';
            mockRes.sys2.description2 = 'Success';
            mockRes.sys2.transID2 = 'TRX-123456';
            mockRes.sys2.datetime4 = '2026-04-02T14:12:25Z';
            
            // Populate Results (The data list)
            FEC_SearchByListNIDsServiceCallout.Result resItem = new FEC_SearchByListNIDsServiceCallout.Result();
            resItem.agentCode = 'AG-001';
            resItem.agentName = 'Agent Smith';
            resItem.buyerName = 'John Doe';
            resItem.buyerNID = '123456789';
            resItem.policyNumber = 'POL-998877';
            resItem.collectedPremiumFee = 150.50;
            resItem.StatusDisplay = 'Active';
            resItem.effectiveDate = '2026-01-01';
            resItem.expireDate = '2027-01-01';
            
            mockRes.result = new List<FEC_SearchByListNIDsServiceCallout.Result>{ resItem };

            // Create the HTTP Response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(mockRes)); // Serializes the object into a JSON string
            res.setStatusCode(200);
            
            return res;
        }
    }

    global class FEC_SearchByListNIDsMockError implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            // Create the top-level response object
            FEC_SearchByListNIDsServiceCallout.NIDsResponse mockRes = new FEC_SearchByListNIDsServiceCallout.NIDsResponse();
            // Populate Sys2 (Metadata/Status)
            mockRes.sys2 = new FEC_SearchByListNIDsServiceCallout.Sys2();
            mockRes.sys2.code2 = '200';
            mockRes.sys2.description2 = 'Success';
            mockRes.sys2.transID2 = 'TRX-123456';
            mockRes.sys2.datetime4 = '2026-04-02T14:12:25Z';
            
            // Create the HTTP Response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(mockRes)); // Serializes the object into a JSON string
            res.setStatusCode(500);
            
            return res;
        }
    }
}