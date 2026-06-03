@IsTest
private class FEC_FetchCollectDataServiceCallout_Test {

    @IsTest
    static void testFetchCollectionData_Success() {
        // 1. Giả lập JSON trả về từ API
        String jsonResponse = '{' +
            '"Success": "true",' +
            '"AllocationHistory": [{"POS": "1", "AllocationDate": "2026-03-30"}],' +
            '"CommunicationHistory": [{"ContractNumber": "20161129-0006618"}],' +
            '"InteractionHistory": [{"InteractedCode": "C01"}],' +
            '"NFUDetailsList": [{"NFUStatus": "Active"}]' +
        '}';

        // 2. Thiết lập Mock Callout (Cần đảm bảo FEC_CommonUltils.calloutApiWithHeaders hỗ trợ Test.setMock)
        // Nếu FEC_CommonUltils dùng Http.send(), Test.setMock sẽ hoạt động.
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, jsonResponse));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse res = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('20161129', 'COLLECTION');
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals('true', res.Success);
        System.assertEquals(1, res.AllocationHistory.size());
        System.assertEquals('1', res.AllocationHistory[0].POS);
    }

    @IsTest
    static void testFetchCollectionData_Error() {
        // Mock lỗi server
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Internal Server Error'));

        Test.startTest();
        FEC_FetchCollectionDataServiceCallout.CollectionDataResponse res = 
            FEC_FetchCollectionDataServiceCallout.fetchCollectionData('20161129', 'COLLECTION');
        Test.stopTest();

        System.assertEquals('false', res.Success);
    }

    // Helper class để Mock HTTP Response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        Integer code;
        String body;
        MockHttpResponseGenerator(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            res.setBody(this.body);
            return res;
        }
    }
}