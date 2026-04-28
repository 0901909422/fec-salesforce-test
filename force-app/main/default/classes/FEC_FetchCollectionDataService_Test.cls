@isTest
public with sharing class FEC_FetchCollectionDataService_Test {

    public class FEC_CollectionDataMock implements HttpCalloutMock {
        private Integer statusCode;

        public FEC_CollectionDataMock(Integer code) {
            this.statusCode = code;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);

            if (this.statusCode == 200) {
                // Build a valid response based on your inner classes
                FEC_FetchCollectionDataServiceCallout.CollectionDataResponse mockRes = 
                    new FEC_FetchCollectionDataServiceCallout.CollectionDataResponse();
                mockRes.Success = 'true';
                
                FEC_FetchCollectionDataServiceCallout.AllocationHistory item = 
                    new FEC_FetchCollectionDataServiceCallout.AllocationHistory();
                item.AgentName = 'Test Agent';
                item.CurrentBucket = 'B1';
                item.DPD = '15';
                
                mockRes.AllocationHistory = new List<FEC_FetchCollectionDataServiceCallout.AllocationHistory>{ item };
                res.setBody(JSON.serialize(mockRes));
            } else {
                res.setBody('{"Success": false}');
            }
            return res;
        }
    }

    @isTest
    static void testFetchSuccess() {
        // Set mock for 200 OK
        Test.setMock(HttpCalloutMock.class, new FEC_CollectionDataMock(200));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse result = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('CONT-001', 'Individual');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('true', result.Success, 'Success flag should be true');
        System.assertEquals(1, result.AllocationHistory.size(), 'History list should be populated');
        System.assertEquals('Test Agent', result.AllocationHistory[0].AgentName);
    }

    @isTest
    static void testFetchHttpError() {
        // Set mock for 500 Internal Server Error
        Test.setMock(HttpCalloutMock.class, new FEC_CollectionDataMock(500));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse result = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('CONT-001', 'Individual');
        Test.stopTest();

        System.assertEquals('false', result.Success, 'Success flag should be false on HTTP error');
    }

    @isTest
    static void testMissingParameters() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('', '');
        } catch (CalloutException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw CalloutException if parameters are blank');
    }
}